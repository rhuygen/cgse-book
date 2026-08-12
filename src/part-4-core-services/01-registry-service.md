# Chapter 17 The Registry Service

*Running the discovery layer everything else in this Part depends on.*

Modules: `egse/registry/server.py`, `egse/registry/backend.py` (`cgse-core`)

Chapter 10 covered the registry as a mechanism — why dynamic discovery replaces static ports, and how `ControlServer` and `Proxy` opt into it. This chapter covers the same code from the other direction: the Registry as one of the deployed services in Part IV, the one every other service in this Part (Storage Manager, Configuration Manager, Process Manager, and the rest) registers itself with on startup. It opens Part IV deliberately, ahead of the services that depend on it.

## 1. Why This Chapter Is Separate From Chapter 10

What belongs here versus there: Chapter 10 is the client/server design and API; this chapter is the operator's view — running it, configuring its backend, and knowing when it's healthy. Cross-references Chapter 10 rather than repeating it.

TBW.

## 2. Choosing and Running a Backend

`backend.py`'s pluggable backend implementations, the trade-offs between them, and what a site needs to decide before deploying the registry for real.

TBW.

## 3. The Registry in the Startup Sequence

Why the Registry Server has to be up before the other services covered later in this Part, and how that ordering shows up in the `cgse` CLI (Chapter 24).

TBW.

## 4. Operating the Registry

Health checks, what a degraded or unreachable registry looks like from the services depending on it, and recovery.

TBW.
