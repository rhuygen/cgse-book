# Chapter 10 `egse/registry/`

*From static ports to dynamic discovery.*

Modules: `egse/registry/backend.py`, `egse/registry/client.py`, `egse/registry/server.py`, `egse/registry/service.py` (all in `cgse-core`)

Every control server discussed so far has been reachable at a well-known, statically configured port. This chapter covers the service registry, deliberately placed last in the Part II arc so its value is legible by contrast with the static-port model already established in Chapters 6 through 9.

## 1. Why a Registry, and Why It Comes Last

What problem dynamic discovery solves that static ports don't, and why understanding the static model first makes the registry's design easier to motivate.

TBW.

## 2. Registry Server and Backend

The registry server and its pluggable backend abstraction.

TBW.

## 3. Registering and Discovering Services

The client-side registration and lookup API, and how a service's lifecycle (register, heartbeat, deregister) is tracked. Cross-reference to P-006 in the Pitfalls appendix: `ControlServer.service_id` vs `self._service_id`, surfaced by comparing `register_service()`/`deregister_service()` against the registry's own sibling implementations.

TBW.

## 4. What Changes for Control Servers and Proxies

How `ControlServer` and `Proxy` opt into registry-based discovery, and `can_operate_without_registry()` from Chapter 6 as the policy hook that makes this optional rather than mandatory.

TBW.
