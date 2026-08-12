# Chapter 14 Messaging Primitives

*The small shared vocabulary that every client/server exchange is built from.*

Modules: `egse/response.py`, `egse/zmq_ser.py`, `egse/observer.py`, `egse/state.py`, `egse/signal.py`, `egse/heartbeat.py` (all in `cgse-common`)

Chapters 6 through 10 described the client/server architecture at the level of control servers, proxies, and commands. This chapter drops one level lower, to the primitives those layers are built from: how a response is shaped, how a ZeroMQ message is serialized, and how components observe and signal each other.

## 1. Response Envelopes

`response.py` and how control servers report success, failure, and returned data in a consistent shape.

TBW.

## 2. ZeroMQ Serialization Helpers

`zmq_ser.py` and the (de)serialization conventions shared by every socket introduced in Chapter 6.

TBW.

## 3. Observer and Observable

`observer.py`'s standard Observer/Observable pattern and where it's used to decouple state changes from the code that reacts to them.

TBW.

## 4. State and Signals

`state.py` and `signal.py`, and how they complement the Observer pattern above.

TBW.

## 5. Heartbeats

`heartbeat.py` and how liveness is communicated between long-running components, including its relationship to the registry's own heartbeat mechanism (Chapter 10).

TBW.
