# Chapter 8 Mixin and Dynamics

*Wiring the command dictionary into client classes.*

Module: `egse/mixin.py` (`cgse-core`)

Chapter 7 covered how a `CommandProtocol` builds the command dictionary on the server side. This chapter covers the client-side counterpart: how that dictionary turns into real, callable methods on a `Proxy` instance at runtime, via the mixin classes defined here.

## 1. Why a Mixin, Not Hand-Written Methods

The problem this solves: a `Proxy` subclass would otherwise need one hand-written wrapper method per device command, duplicating what's already declared in the command dictionary.

TBW.

## 2. The Mixin Classes

The mixin classes `mixin.py` defines, how they attach methods and properties to a client object, and how `load_commands()` (Chapter 6) and `_add_commands()` fit together with them.

TBW.

## 3. Where This Meets `DynamicProxy`

Cross-reference to the open question logged as P-008 in the Pitfalls appendix: `Proxy`'s `load_commands()` mechanism versus `DynamicProxy`'s `DynamicClientCommandMixin`, and whether this chapter is the place to resolve it.

TBW.
