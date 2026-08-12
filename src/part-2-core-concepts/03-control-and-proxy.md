# Chapter 6 `control.py` and `proxy.py`

*The client/server foundation.*

## Why this chapter follows Settings, Setup, and env

Chapters 4 and 5 covered *what* configuration exists and *where* it lives. This chapter is about what actually *uses* that configuration at runtime: every device in a Setup — a hexapod, a temperature controller, a power supply — is operated through a **Control Server** process that owns the physical connection to the hardware, and every test script or GUI that wants to talk to that device does so through a **Proxy** object that looks, to calling code, almost exactly like the device itself.

`egse/control.py` (in `cgse-core`) defines `ControlServer`, the abstract base every device control server inherits from. `egse/proxy.py` defines `Proxy` (and its relatives), the client-side counterpart. Between them, they define the one architectural pattern that essentially all of CGSE's runtime behavior is built on top of. Everything from here on — device drivers, the GUI clients, the Storage and Configuration Managers themselves (which are *also* `ControlServer` subclasses, Section 2) — assumes this chapter's vocabulary.

We're covering this pair before the newer `egse/registry` module deliberately (see the closing note): understanding the "classic" model here first is what will make the registry's added value legible later, rather than the other way around.


## 1. One Process per Device, Many Clients per Process

A test facility has physical devices that can only safely be talked to by one thing at a time — you don't want a GUI and a test script independently opening a serial connection to the same hexapod. CGSE's answer is a strict separation:

- **One long-running server process per device (or per service)** owns the actual connection — serial port, Ethernet socket, GPIB, whatever the hardware needs — and is the only thing that ever talks to it directly.
- **Any number of client processes** — test scripts, GUIs, monitoring dashboards — talk to that server process over ZeroMQ, never to the device directly.

This buys the two things a shared, hands-on test facility actually needs: exclusivity (the device can't be commanded from two places at once and get confused) and location transparency (a test script doesn't care, and doesn't need to know, whether the hexapod control server is running on the same machine or across the lab network — it's just an endpoint string).

`ControlServer` is the shared machinery for the server side of that relationship, and it's reused far beyond individual device drivers: the **Storage Manager** and **Configuration Manager** — CGSE's own infrastructure services — are themselves `ControlServer` subclasses. The same request/reply, registration, and monitoring machinery that runs a hexapod control server runs the service that decides where housekeeping data gets written. That reuse is a strong signal of how central this one base class is.


## 2. Three sockets, three concerns

```python
self.dev_ctrl_service_sock = self.zcontext.socket(zmq.REP)  # "how are you, what are your ports"
self.dev_ctrl_mon_sock = self.zcontext.socket(zmq.PUB)  # periodic status/HK broadcast
self.dev_ctrl_cmd_sock = self.zcontext.socket(zmq.REP)  # the actual device commands
```

`ControlServer.__init__` sets up three distinct ZeroMQ sockets, each with a different pattern, because they solve three genuinely different problems:

- `dev_ctrl_cmd_sock` **(REQ/REP)** — the device commands themselves (`homing()`, `set_temperature()`, whatever the device protocol defines). REQ/REP is a strict synchronous request-then-reply pattern: exactly one command in flight at a time, which matches "the device can only do one thing at a time" from Section 1. This socket is left unbound in the base class — "the device protocol shall bind the socket in the subclass" (from the class docstring) — because binding requires knowing the commanding port, and that's something only a concrete subclass knows (`get_commanding_port()`, an abstract method, Section 4).
- `dev_ctrl_service_sock` **(REQ/REP)** — a *separate* request/reply channel for questions about the server itself rather than the device: "what's your monitoring port," "are you alive" (`Ping`), service-level configuration. Keeping this separate from the command socket means a client asking "are you there?" never has to compete with, or get queued behind, in-flight device commands — and vice versa, a slow device command can't make the server unable to answer a basic liveness check.
- `dev_ctrl_mon_sock` **(PUB)** — periodic status and housekeeping broadcast. PUB is the right pattern here specifically because monitoring is fundamentally different in shape from commanding: any number of listeners (a GUI, a logging process, a second GUI opened for debugging) can subscribe without the server needing to track who's listening or reply to each one individually — publish once, however many subscribers get it. Trying to serve monitoring data over a REQ/REP socket would mean the server tracking a client list and iterating it on every tick; PUB/SUB gets that fan-out from ZeroMQ for free.

### A self-flagged rough edge, worth reading in the source, not just this book

```python
self.poller.register(self.dev_ctrl_mon_sock, zmq.POLLIN)  # FIXME: I think this should not be registered
```

This is left in the source as-is, and it's worth explaining *why* it's suspicious rather than just repeating the FIXME: `dev_ctrl_mon_sock` is a `PUB` socket — it only ever sends, never receives — so registering it for `POLLIN` (readability) in the poller is very likely inert: ZeroMQ shouldn't report a `PUB` socket as readable in any normal flow, meaning this line probably does nothing harmful, but also nothing useful. It's flagged in the Pitfalls appendix (P-007) as "verify and remove if confirmed inert" rather than fixed outright in this book, since removing a poller registration in a 24/7 running control server is exactly the kind of change you want backed by a deliberate test and a real deployment window, not a silent edit while writing documentation.


## 3. `serve()` as a Single-Threaded Reactor, Not a Thread per Socket

```python
while True:
    self.signaling.process_pending_commands()
    socks = dict(self.poller.poll(50))  # timeout in milliseconds, do not block

    if self.dev_ctrl_cmd_sock in socks:
        self.device_protocol.execute()
    if self.dev_ctrl_service_sock in socks:
        self.service_protocol.execute()
    if self.event_subscription.socket in socks:
        self.event_subscription.handle_event()

    if time_in_ms() - last_time >= self.mon_delay:
        ...  # send monitoring status
    if time_in_ms() - last_time_hk >= self.hk_delay:
        ...  # collect + store + propagate housekeeping

    self.handle_scheduled_tasks()

    if self.interrupted or killer.term_signal_received:
        break
    if not self.device_protocol.is_alive():
        break
```

**Design decision — one thread, one loop, polling with a short timeout, rather than one thread per socket.** This is the single most consequential design choice in the whole class, and it's worth being explicit about the trade-off rather than treating it as an obvious default:

- **What it buys:** there is exactly one place where device state can change, so there's no need for locks around device access, no risk of two threads racing to send two ZeroMQ messages on the same socket at the same time (ZeroMQ sockets are famously not thread-safe to share), and the entire server's behavior for a given tick is describable as "poll, then handle whatever's ready, then check the clocks, then run scheduled tasks" — a sequential story a person can hold in their head and step through in a debugger.
- **What it costs, and why the docstring warns about it explicitly:** *"the* `callback` *function is executed in the* `serve()` *event loop, it shall not block!"* (from `schedule_task`'s docstring). Because everything happens on one thread, one slow operation — a device command that takes three seconds, a scheduled task that blocks on network I/O — stalls *every other concern* of this server for that same duration: no other commands get processed, no monitoring gets published, no housekeeping gets collected. This isn't a hidden gotcha; it's the direct, unavoidable consequence of choosing simplicity-through-single-threading, and it's the reason `schedule_task` exists at all as an escape hatch (Section 3.2) rather than calling blocking code directly from `before_serve` or a subclass override.
- **The 50ms poll timeout** is the tuning knob that balances "responsive to new events" against "don't spin the CPU for no reason." It's not configurable per-instance — it's a literal `50` in the `serve()` method — which is a reasonable simplification given that every control server has the same basic responsiveness requirement (sub-100ms reaction to a new command), and no server built on this base class so far has needed a different value.

### 3.1 Why `serve()` explicitly tells you Ctrl-C won't work

```python
except KeyboardInterrupt:
    self.logger.warning("Keyboard interrupt caught!")
    self.logger.warning(
        "The ControlServer can not be interrupted with CTRL-C, send a quit command to the server instead."
    )
    continue
```

This is a deliberate operational policy, not a missing feature. A control server owns a live connection to physical hardware — if a `KeyboardInterrupt` were allowed to unwind the Python stack at an arbitrary point inside `serve()`'s loop, it could do so in the middle of a device command, skip `after_serve()`, skip storage manager de-registration, and leave sockets and the device connection in an undefined state. The `quit()` method (Section 3.2) and the `interrupted` flag give the loop a chance to reach the `break` at the top of the loop body on its own terms, run the cleanup sequence at the bottom of `serve()` in order (unregister from storage manager, run `after_serve()`, close every socket explicitly, deregister from the service registry, terminate the ZeroMQ context), and exit cleanly. `SIGTERM` (via `killer.term_signal_received`, from `egse.system.SignalCatcher`) is still honored — this isn't "ignore all signals," it's specifically "don't let an interactive Ctrl-C interrupt at an arbitrary instruction," while still allowing an orchestrated shutdown signal to be checked at a safe point in the loop.

### 3.2 `schedule_task` and `handle_scheduled_tasks` as Explicit Cooperative Multitasking

```python
def schedule_task(self, callback: Callable, after: float = 0.0, when: Callable = None):
    ...
    self.scheduled_tasks.append({"task": callback, "name": name, "after": scheduled_time, "when": when})
```

Given Section 3's single-thread constraint, `schedule_task` is how a device protocol defers work to a later tick of the loop instead of blocking the current one — explicitly documented as a deadlock-avoidance mechanism ("this function is intended to be used in order to prevent a deadlock"). `handle_scheduled_tasks` processes the list once per loop iteration: overdue and condition-satisfied tasks run immediately (wrapped in `try/except` so one failing task can't take down the server — it gets rescheduled instead of propagating), tasks whose `after` time hasn't arrived, or whose `when` condition isn't yet true, get put back on the list for the next check.

The reverse-then-pop-from-the-end pattern (`self.scheduled_tasks.reverse()` followed by `.pop()` in a `while` loop) is a slightly unusual way to process a list in original order while also being able to append newly-rescheduled tasks without disturbing the ones still to be processed in *this* pass — routine once you see the trick, not worth more than this one sentence.


## 4. The Abstract Contract of Four Methods, One Theme

```python
@abc.abstractmethod
def get_communication_protocol(self) -> str: ...
@abc.abstractmethod
def get_commanding_port(self) -> int: ...
@abc.abstractmethod
def get_service_port(self) -> int: ...
@abc.abstractmethod
def get_monitoring_port(self) -> int: ...
```

Every concrete control server must supply its protocol and its three ports. This is a small, deliberately narrow abstract contract — `ControlServer` doesn't force subclasses to structure their device commanding any particular way, only to be explicit about *how to reach this server at all*. And this is exactly where Chapter 4's `CONSTANT`/`Settings`/`Setup` framework earns its keep in practice: a concrete implementation (e.g. the PUNA hexapod control server) typically implements these four methods as one-liners returning module-level names loaded once from `Settings.load(...)` at import time —

```python
def get_commanding_port(self):
    return COMMANDING_PORT
```

— because a commanding port is a textbook `Settings` value by Chapter 4's own rule of thumb: it's fixed per site/deployment, not per test, and changing it means editing a YAML file, not the code.


## 5. Registry integration and the `can_operate_without_registry()` policy hook

```python
def register_service(self, service_type: str) -> None:
    self._service_id = self.registry.register(
        name=self.service_name,
        host=get_host_ip() or "127.0.0.1",
        port=get_port_number(self.dev_ctrl_cmd_sock),
        service_type=self.service_type,
        metadata={"service_port": ..., "monitoring_port": ...},
    )
    if self._service_id:
        self.registry.start_heartbeat()
    elif self.can_operate_without_registry():
        self.logger.warning(f"Failed to register '{self.service_name}' ... Continuing because ...")
    else:
        raise ServiceRegistrationError(...)
```

```python
def can_operate_without_registry(self) -> bool:
    """... The default is strict: registration is required. Subclasses with explicitly
    configured, externally known endpoints may override this policy hook."""
    return False
```

By default, a control server that can't register itself with the service registry treats that as fatal (`ServiceRegistrationError`). But look at how a concrete hexapod control server overrides the hook:

```python
def can_operate_without_registry(self) -> bool:
    return bool(COMMANDING_PORT and SERVICE_PORT and MONITORING_PORT)
```

The override isn't "always tolerate a missing registry" — it's specifically "tolerate it *when this server's ports are statically configured in Settings rather than dynamically assigned* (a non-zero, explicitly set port, as opposed to `0`/OS-assigned)." That condition is the whole point: if a device's ports are fixed, well-known values from a YAML file, a client can in principle be told that endpoint directly and connect without ever asking the registry — so losing the registry is a degraded, not a broken, situation for that server. A server relying on OS-assigned (`0`) ports has no such fallback: without the registry, nobody could discover which port it ended up on, so for *that* server, a failed registration really is fatal. `can_operate_without_registry()` is a Template Method-style policy hook precisely because the right answer depends on a per-server fact (static vs. dynamic ports) that only the concrete subclass knows — `ControlServer` provides the mechanism (what to do with the answer) without hardcoding the policy (what the answer should be).


## 6. `is_control_server_active()` as a Raw, Low-Level Ping, Separate From the Proxy

```python
def is_control_server_active(endpoint: str = None, timeout: float = 0.5) -> bool:
    ctx = zmq.Context.instance()
    socket = ctx.socket(zmq.REQ)
    socket.connect(endpoint)
    socket.send(pickle.dumps("Ping"))
    rlist, _, _ = zmq.select([socket], [], [], timeout=timeout)
    if socket in rlist:
        response = pickle.loads(socket.recv())
        return_code = response == "Pong"
    socket.close(linger=0)
    return return_code
```

This module-level function duplicates, in miniature, what `Proxy.ping()` does (Section 8) — open a `REQ` socket, send `"Ping"`, expect `"Pong"` back within a timeout. It exists as a standalone function, separate from any `Proxy` instance, specifically so that code that only wants to *check* whether something is listening at an endpoint doesn't need to construct a full `Proxy` object (which, per Section 8, immediately tries to load the entire command set on construction). It's a liveness check with no side effects and a short-lived, disposable socket — appropriate for, say, a startup script probing several endpoints in sequence before deciding what to launch.


## 7. Why `ControlServer` is not a `Proxy`, and what's shared instead

Notice `ControlServer` and `Proxy`/`BaseProxy` don't share a common base class — they're two independent hierarchies that happen to agree on a wire protocol (pickled Python objects over ZeroMQ `REQ`/`REP`, with the literal strings `"Ping"`/`"Pong"` as the handshake). What *is* shared is the vocabulary of `get_commanding_port` / `get_service_port` / `get_monitoring_port` — both sides need to agree on what a "commanding port" means, but the server's job (own the socket, bind, serve requests, own the device) and the client's job (connect, send, wait for reply, degrade gracefully on timeout) are different enough in shape that forcing them into one hierarchy would buy nothing.


## 8. `BaseProxy` and `Proxy`, the Client Side

### 8.1 Three sequential responsibilities, three classes

```python
class ControlServerConnectionInterface:      # the connect/disconnect/reconnect contract
class BaseProxy(ControlServerConnectionInterface):   # the actual ZeroMQ REQ socket + send()/ping()
class Proxy(BaseProxy, ControlServerConnectionInterface):  # + dynamic command loading
```

`ControlServerConnectionInterface` defines connection-lifecycle methods as `@dynamic_interface` stubs that raise `NotImplementedError` — this is the same `dynamic_interface` marker mechanism used elsewhere in device protocol classes (Section 8.3 touches why this matters for `DynamicProxy`): it marks a method as "this name is reserved for connection management and must not be silently overwritten by a dynamically loaded device command of the same name" — the docstring is explicit about this: the interface "guarantees that connection commands do not interfere with the commands defined in the `DeviceConnectionInterface` (which will be loaded from the control server)." `BaseProxy` implements the actual socket handling. `Proxy` adds the mechanism that makes a Proxy object able to grow new methods at runtime, one per command the connected control server actually offers (Section 8.4) — which is the single most distinctive thing about this class.

### 8.2 `send()`, Retry, Reconnect, and the Meaning of "Connected" in ZeroMQ

```python
def send(self, data, retries=REQUEST_RETRIES, timeout=None):
    ...
    if self._socket.closed:
        self.reconnect_cs()
    self._socket.send(pickle_string)
    while True:
        socks = dict(self._poller.poll(timeout_ms))
        if self._socket in socks and socks[self._socket] == zmq.POLLIN:
            return pickle.loads(self._socket.recv())
        else:
            self.disconnect_cs()
            if retries_left == 0:
                return Failure(f"Control Server seems to be off-line, abandoning ({data})")
            retries_left -= 1
            self.reconnect_cs()
            self._socket.send(pickle_string)
```

The comment right above this method's retry logic states the key fact that makes all of this necessary: *"we are using ZeroMQ where the connect method returns gracefully even when no server is available."* `zmq.Socket.connect()` doesn't fail just because nothing is listening yet — ZeroMQ handles reconnection at the transport level transparently, which means a `Proxy` can be constructed and appear to "connect" successfully even before its control server has started. The real liveness test only happens the first time you actually try to exchange a message and either get a reply or don't. That's why `send()`, not `connect_cs()`, is where the retry/reconnect logic lives: a timeout on `poll()` is ambiguous between "the server is slow" and "the server was never there," and the only sound response to that ambiguity, given ZeroMQ's REQ socket semantics (a REQ socket that has sent a request and not yet received a reply is in a strict alternating state and can't just resend on the same socket), is to close the socket, open a fresh one, and try again — which is exactly what `disconnect_cs()` / `reconnect_cs()` / re-`send()` does here.

`REQUEST_RETRIES = 0` as the module default is worth noting explicitly: **by default,** `send()` **does not retry at all** — one attempt, and a timeout becomes an immediate `Failure`. Retrying is opt-in per call (`send(data, retries=2)`), which keeps the default behavior predictable for callers that want to fail fast (e.g. an interactive GUI that shouldn't hang) while still allowing scripted code that expects transient network blips to ask for retries explicitly.

### 8.3 `DynamicProxy` vs `Proxy`, and an acknowledged bit of debt

```python
class DynamicProxy(BaseProxy, DynamicClientCommandMixin):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)


# TODO (rik): remove all methods from Proxy that are also define in the BaseProxy


class Proxy(BaseProxy, ControlServerConnectionInterface): ...
```

`DynamicProxy` composes `BaseProxy` with a different mixin (`DynamicClientCommandMixin`, from `egse.mixin`) than `Proxy` does — a second, apparently parallel mechanism for building dynamically-commandable client objects, existing alongside `Proxy`'s own `load_commands()` approach (Section 8.4). The `# TODO (rik): remove all methods from Proxy that are also define in the BaseProxy` comment, left in the source, is a first-person acknowledgment (worth taking at face value, given its author) that `Proxy` accumulated some duplication with `BaseProxy` over time — methods like `get_monitoring_port`/`get_commanding_port`/`get_service_port` are defined on `BaseProxy` (Section 8.5) and `Proxy` inherits them without needing to redeclare anything, but the comment suggests that wasn't always tidy historically. This is flagged in the Pitfalls appendix (P-008) as a "confirm `DynamicProxy` vs `Proxy`'s actual relationship and either consolidate or document why both exist" item — exactly the kind of thing worth an explicit decision before a handover, rather than leaving two "the dynamic one" classes for a successor to have to reverse-engineer the difference between.

### 8.4 `load_commands()`, a Proxy That Grows Its Own Interface at Runtime

```python
def _request_commands(self):
    response = self.send("send_commands")
    self._commands = response


def _add_commands(self):
    for key in self._commands:
        if hasattr(self, key):
            attribute = getattr(self, key)
            if isinstance(attribute, types.MethodType) and not hasattr(attribute, "__dynamic_interface"):
                self._logger.warning(f"... already has an attribute '{key}', not overwriting.")
                continue
        command = self._commands[key]
        new_method = MethodType(command.client_call, self)
        new_method = set_docstring(new_method, command)
        setattr(self, key, new_method)
```

This is the mechanism that makes `hexapod_proxy.homing()` work without a `homing` method ever being written by hand anywhere in `Proxy` or its subclasses: on construction (assuming the ping handshake succeeds), the `Proxy` asks its control server for its full command dictionary (`send("send_commands")` — the server side of this exchange is the device protocol's command registry, out of scope for this chapter, but the shape of what comes back is a dict of `Command` objects, covered when we reach `egse/command.py`), and for every command name that isn't already claimed by something else on the instance, it binds that command's `client_call` as a genuine bound method on `self` using `types.MethodType`. From the calling code's perspective, there is no visible difference between a "real" method and one of these dynamically attached ones — that's the whole point, and it's why device-specific Proxy subclasses across the codebase can stay almost empty: most of their public interface doesn't exist as written Python at all, it's populated at `__init__` time from whatever the connected control server reports it supports.

**The collision guard is the one piece of this worth reading closely.** If the Proxy already has an attribute of the given name, it's only overwritten if that attribute is *not* already a method carrying the `__dynamic_interface` marker (Section 8.1) — i.e., connection-management methods like `connect_cs` are protected from being silently replaced by a same-named device command, but a regular Python method a subclass author happened to define (without the marker) is also protected, with a warning logged rather than a silent, confusing override. This is the direct, practical payoff of the `ControlServerConnectionInterface`/`@dynamic_interface` split from Section 8.1 — it's not there to enable to `Proxy`'s connection lifecycle, it's there specifically to survive contact with `_add_commands()`.

### 8.5 `get_service_proxy()`, a Proxy That Can Hand You a Different Kind of Proxy

```python
def get_service_proxy(self):
    from egse.services import ServiceProxy  # prevent circular import problem

    transport, address, _ = split_address(self._endpoint)
    response = self.send("get_service_port")  # FIXME: Check if this is still returning the proper port
    ...
    return ServiceProxy(protocol=transport, hostname=address, port=response)
```

Recall Section 2's three sockets: a `Proxy` normally only ever talks to the *commanding* socket. `get_service_proxy()` is the bridge to the *service* socket — given a device Proxy already connected to a control server's commanding endpoint, this method asks that same server (over the commanding channel) what its service port is, then constructs and returns a brand-new `ServiceProxy` object pointed at that different port. This is a convenience specifically for code that's holding a device Proxy and suddenly needs to ask a service-level question (e.g. "what's your process status") without the caller having to independently know or reconstruct the service endpoint by hand. The inline `# FIXME: Check if this is still returning the proper port` is left as-is here too — noted in the Pitfalls appendix (P-008, same entry as the `DynamicProxy` question, since both point at the same general area of the file needing a maintenance pass) rather than resolved silently, since verifying it means actually exercising a live control server connection, not just reading source.


## 9. `self.service_id` vs `self._service_id`, a Real Confirmed Bug

```python
# in ControlServer.__init__:
self.service_id: str | None = None
"""The service ID of this Control Server, as registered in the Service Registry."""
```

```python
# in ControlServer.register_service:
self._service_id = self.registry.register(...)
...
if self._service_id:
    self.registry.start_heartbeat()
```

```python
# in ControlServer.deregister_service:
if self._service_id:
    self.registry.stop_heartbeat()
    self.registry.deregister()
```

Read closely: `__init__` declares and documents a **public** attribute, `self.service_id` (no leading underscore), explicitly described as "The service ID of this Control Server, as registered in the Service Registry." But `register_service()` — the only place that ever assigns a value after a successful registration — sets `self._service_id` (**with** a leading underscore), a *different* attribute that was never declared in `__init__` at all. `deregister_service()` and the `elif`/`if` checks inside `register_service()` all consistently read `self._service_id`, so the internal logic is self-consistent — but the publicly documented `self.service_id` attribute is never updated by anything, ever. It stays `None` for the entire lifetime of the object, even after a fully successful registration.

I didn't take this on faith — I checked how the same pattern is used elsewhere in `cgse-core`, since "service ID after registration" is a recurring need across several server classes in this package:

```
egse/registry/service.py:   self.service_id = await self.registry_client.register(...)
egse/metricshub/server.py:  self.service_id = await self.registry_client.register(...)
egse/notifyhub/server.py:   self.service_id = await self.registry_client.register(...)
egse/control.py:            self._service_id = self.registry.register(...)   # <- the odd one out
```

Every sibling server class in the package — the registry service base itself, the metrics hub server, the notify hub server — assigns the *public*, undocumented-underscore `self.service_id`. `ControlServer` is the only one using `self._service_id`. That consistency across three other classes makes it very likely that `self.service_id` was the intended name here too, and the leading underscore in `control.py` is a copy-paste-era typo that's simply never been exercised by anything that reads the public name.

**Practical consequence:** any code — a subclass, a monitoring tool, a test — that reads `control_server.service_id` expecting to find the registered ID (which is exactly what the attribute's own docstring promises) will always get `None`, silently, even when registration genuinely succeeded and the heartbeat is running. Only code that happens to know about the undocumented `_service_id` name gets the real value. This is logged as **P-006** in the appendix, flagged as the single highest-value fix to come out of this chapter — it's a one-line change (rename `_service_id` to `service_id` in `register_service`), but worth a deliberate look at every call site across the monorepo before touching it, precisely because "silently always `None`" is the kind of bug that other code may have already, unknowingly, worked around.


## What carries forward

Two real, evidence-checked findings came out of this chapter (P-006, the `service_id` mismatch, confirmed by cross-referencing three sibling classes; P-007, the self-flagged PUB-in-poller FIXME, formalized rather than silently fixed) plus one open question worth a deliberate decision (P-008, `DynamicProxy` vs `Proxy`'s relationship). None of them are described here in a way that tells a reader *how* to go looking for this class of bug in general — that's deliberately left implicit in the "read closely, then verify against siblings" method itself, which is the real takeaway for whoever inherits this codebase: when a name is *this* close to another name doing the same conceptual job elsewhere, it's worth five minutes with grep before trusting either one.

*(Next:* `egse/protocol.py`*,* `egse/command.py`*, and* `egse/mixin.py` *— the pieces that define what a "command" actually is, how* `Command.client_call` *turns into a real ZeroMQ round trip, and how a device protocol class turns a* `Command` *registry into the dictionary that* `Proxy._request_commands()` *receives. Then* `egse/dummy.py` *as the smallest complete worked example tying control.py, proxy.py, command.py, and protocol.py together end to end — before finally turning to* `egse/registry/` *and what problem it was introduced to solve on top of the static-port model covered here.)*
