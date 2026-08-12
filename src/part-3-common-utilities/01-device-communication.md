# Chapter 11 Talking to Hardware

*The device abstraction and communication layer.*

Modules: `egse/device.py`, `egse/socketdevice.py`, `egse/scpi.py` (all in `cgse-common`)

Part II covered the client/server framework in the abstract, without reference to any real transport to an instrument. This chapter covers the layer directly below it: the generic device interface every controller implements, and the two concrete communication patterns built on top of it.

## 1. The Generic Device Interface

What `device.py` defines as the minimal contract for "a thing you connect to, command, and query," and how it relates to (but stays independent from) the `CommandProtocol` layer from Chapter 7.

TBW.

## 2. Socket-Based Devices

`socketdevice.py`'s base classes and generic functions for devices reachable over a raw socket connection.

TBW.

## 3. SCPI: A Common Instrument Language

`scpi.py` and the SCPI command/response convention shared by many lab instruments, and how much of a new device driver this buys for free versus what still needs custom handling.

TBW.
