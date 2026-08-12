# Chapter 9 `dummy.py`

*A worked example, start to finish.*

Module: `egse/dummy.py` (`cgse-core`)

Chapters 6 through 8 introduced the control server, proxy, protocol, command, and mixin machinery piece by piece. This chapter ties all of it together through the smallest complete worked example in the codebase — a fake device with no real hardware behind it — so the whole chain can be read end to end in one place before moving on to the service registry.

## 1. Why a Dummy Device

What `dummy.py` is for as a teaching and testing fixture, and why a framework this size benefits from keeping one deliberately trivial, fully wired example around.

TBW.

## 2. The Dummy Control Server

Walking `DummyControlServer` (or equivalent) against the abstract `ControlServer` contract from Chapter 6.

TBW.

## 3. The Dummy Protocol, Commands, and Proxy

Walking the matching protocol/command/proxy trio against Chapters 7 and 8.

TBW.

## 4. Reading the Whole Chain Together

A single request traced from a client-side method call through the proxy, over ZeroMQ, through the protocol, to the command dictionary, and back — the payoff for chapters 6 through 9.

TBW.
