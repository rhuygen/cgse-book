# Chapter 20 The Log Server and Listener Notifications

*Centralized logging, and how components tell each other things changed.*

Modules: `egse/logger/__init__.py`, `egse/logger/log_cs.py`, `egse/listener.py`, `egse/connect.py` (all in `cgse-core`)

## 1. The Log Server

`log_cs.py`: the Log Server that receives log messages and events from control servers and client applications, and `logger/__init__.py`'s root-logger configuration — the centralized counterpart to the local `log.py` from Chapter 15.

TBW.

## 2. Listeners Notifying Clients of Change

`listener.py`'s Listener mechanism between control servers, part of the broader change-notification system this chapter surveys.

TBW.

## 3. `connect.py` and Bootstrapping a Connection

What `connect.py` does to establish a connection before the Listener/notification machinery takes over.

TBW.
