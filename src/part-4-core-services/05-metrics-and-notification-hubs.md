# Chapter 21 Metrics Hub and Notification Hub

*Two async services for two kinds of fan-out: measurements, and events.*

Modules: `egse/metricshub/` (all files), `egse/notifyhub/` (all files) (both in `cgse-core`)

## 1. The Metrics Hub

`metricshub/server.py` and `metricshub/client.py`: the async Metrics Hub, and how it relates to the `cgse-common` metrics backends from Chapter 13.

TBW.

## 2. Measurement Schemas

`metricshub/schemas.py`'s built-in measurement schema definitions.

TBW.

## 3. The Notification Hub

`notifyhub/server.py`, `notifyhub/client.py`, and `notifyhub/services.py`: event-based messaging, and how it differs in purpose from the Listener mechanism in Chapter 20.

TBW.

## 4. Events and Subscriptions

`notifyhub/event.py` and the subscription model clients use to receive only the events they care about.

TBW.
