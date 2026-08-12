# Chapter 22 Monitoring, Observations and the Async Control Server

*What operators watch while a test runs, and an async take on Chapter 6's control server.*

Modules: `egse/monitoring.py`, `egse/observation.py`, `egse/async_control.py`, `egse/async_dummy.py`, `egse/async_temp.py`, `egse/temperature_profile.py`, `egse/_setup_core.py` (all in `cgse-core`)

## 1. Monitoring

`monitoring.py` and how live device state reaches whoever is watching, as distinct from the housekeeping/metrics pipelines of Chapter 13.

TBW.

## 2. Observations

`observation.py` and how an observation is represented and tracked, tying back to the OBSID convention from Chapter 16.

TBW.

## 3. An Async Take on the Control Server

`async_control.py` and `async_dummy.py` next to Chapter 6's `ControlServer` and Chapter 9's `dummy.py`: what changes when the reactor loop becomes `asyncio`-based, and whether this is a parallel design or a migration path.

TBW.

## 4. Temperature Profiles as a Worked Async Example

`async_temp.py` as a template DAQ control server implementation, and `temperature_profile.py`'s shared helpers for simulation and test scripts. `_setup_core.py`'s role in wiring an async control server's Setup.

TBW.
