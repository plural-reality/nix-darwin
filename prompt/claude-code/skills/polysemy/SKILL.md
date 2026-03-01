# Polysemy — Higher-Order Effect System for Haskell

Polysemy is a library for writing high-power, low-boilerplate domain-specific languages via algebraic effects. It separates business logic from implementation details by encoding effects as GADTs and providing composable interpreters. Unlike `mtl`, polysemy has no functional dependencies (allowing multiple copies of the same effect), composes without O(n^2) instances, and supports higher-order effects (`bracket`, `local`) as first-class citizens.

## When to use this skill

- Defining custom effects as GADTs and generating smart constructors with `makeSem`
- Writing interpreters (`interpret`, `reinterpret`, `interceptH`, etc.) for polysemy effects
- Composing effect stacks with `Member`/`Members` constraints and `Sem r a`
- Using built-in effects: `State`, `Error`, `Reader`, `Writer`, `Input`, `Output`, `Resource`, `Async`, `Trace`, `NonDet`, `Embed`, `Final`, `Scoped`, `Tagged`, `Bundle`, `AtomicState`, `Fixpoint`, `Fail`, `Opaque`
- Running effect stacks with `run`, `runM`, `runFinal`
- Writing higher-order interpreters using `Tactical`/`Strategic` DSLs
- Debugging effect resolution issues or understanding polysemy internals (`Union`, `Weaving`, `ElemOf`)
- Integrating polysemy with `IO`, `MonadIO`, or `MonadFix` via `Embed`/`Final`

---

## Package Overview

- [polysemy-1.9.2.0.md](polysemy-1.9.2.0.md) — Package README: overview, features, examples (Teletype, Resource), necessary language extensions, GHC options, Nix build instructions, and performance notes.

---

## API Documentation (`docs/`)

Haddock-generated module documentation for polysemy 1.9.2.0.

### Core

- [Polysemy](docs/Polysemy.html) — Top-level re-export: `Sem r a`, `Member`/`Members`, `run`/`runM`/`runFinal`, `Embed`/`embed`, `Final`/`embedFinal`, row-lifting functions, `InterpreterFor`.
- [Polysemy-Final](docs/Polysemy-Final.html) — `Final m` effect for low-level interop with a final monad; `withStrategicToFinal`, `interpretFinal`, `Strategic` DSL (`pureS`, `liftS`, `runS`, `bindS`).
- [Polysemy-IO](docs/Polysemy-IO.html) — `embedToMonadIO`: reinterpret `Embed IO` into any `MonadIO m`.
- [Polysemy-Membership](docs/Polysemy-Membership.html) — `ElemOf` membership proofs: `membership`, `sameMember`, `tryMembership`, `subsumeUsing`, `interceptUsing`.

### Effects

- [Polysemy-Async](docs/Polysemy-Async.html) — `Async` effect: `async`, `await`, `cancel`, `sequenceConcurrently`, `asyncToIOFinal`.
- [Polysemy-AtomicState](docs/Polysemy-AtomicState.html) — `AtomicState s` effect: atomic read/modify/write via `IORef`/`TVar`, `atomicStateToState`.
- [Polysemy-Bundle](docs/Polysemy-Bundle.html) — `Bundle r` effect: group multiple effects under one; `sendBundle`, `runBundle`, `subsumeBundle`.
- [Polysemy-Embed](docs/Polysemy-Embed.html) — `Embed m` effect: lift a raw monad into `Sem`; `embed`, `runEmbedded`.
- [Polysemy-Embed-Type](docs/Polysemy-Embed-Type.html) — Type definition for `newtype Embed m z a`.
- [Polysemy-Error](docs/Polysemy-Error.html) — `Error e` effect: `throw`, `catch`, `fromEither`, `fromException`, `note`, `try`, `runError`, `mapError`, `errorToIOFinal`.
- [Polysemy-Fail](docs/Polysemy-Fail.html) — `Fail` effect: `runFail`, `failToError`, `failToNonDet`, `failToEmbed`.
- [Polysemy-Fail-Type](docs/Polysemy-Fail-Type.html) — Type definition for `newtype Fail m a = Fail String`.
- [Polysemy-Fixpoint](docs/Polysemy-Fixpoint.html) — `Fixpoint` effect: `MonadFix`-like recursive bindings; `fixpointToFinal`.
- [Polysemy-Input](docs/Polysemy-Input.html) — `Input i` effect: `input`, `inputs`, `runInputConst`, `runInputList`, `runInputSem`.
- [Polysemy-NonDet](docs/Polysemy-NonDet.html) — `NonDet` effect (`Alternative`): `runNonDet`, `runNonDetMaybe`, `nonDetToError`.
- [Polysemy-Opaque](docs/Polysemy-Opaque.html) — `Opaque e` newtype wrapper: prevent polymorphic effect variables from interfering with `Member` resolution.
- [Polysemy-Output](docs/Polysemy-Output.html) — `Output o` effect: `output`, `runOutputList`, `runOutputMonoid`, lazy/IORef/TVar variants, `outputToIOMonoid`.
- [Polysemy-Reader](docs/Polysemy-Reader.html) — `Reader i` effect: `ask`, `asks`, `local`, `runReader`, `inputToReader`.
- [Polysemy-Resource](docs/Polysemy-Resource.html) — `Resource` effect: `bracket`, `bracketOnError`, `finally`, `onException`, `runResource`, `resourceToIOFinal`.
- [Polysemy-Scoped](docs/Polysemy-Scoped.html) — `Scoped param effect`: per-scope resource management; `scoped`, `rescope`, `interpretScopedH`, `runScopedNew`, `runScopedAs`.
- [Polysemy-State](docs/Polysemy-State.html) — `State s` effect: `get`, `put`, `modify`, strict/lazy `runState`/`evalState`/`execState`, IORef/STRef-backed interpreters.
- [Polysemy-Tagged](docs/Polysemy-Tagged.html) — `Tagged k e`: disambiguate multiple copies of the same effect via phantom tag; `tag`, `tagged`, `untag`, `retag`.
- [Polysemy-Trace](docs/Polysemy-Trace.html) — `Trace` effect: `trace`, `traceToStdout`, `traceToStderr`, `traceToHandle`, `runTraceList`, `ignoreTrace`, `traceToOutput`.
- [Polysemy-Writer](docs/Polysemy-Writer.html) — `Writer o` effect: `tell`, `listen`, `pass`, `censor`, `runWriter`, `runLazyWriter`, `runWriterAssocR`, `runWriterTVar`, `writerToIOFinal`.

### Internals

- [Polysemy-Internal](docs/Polysemy-Internal.html) — Core `Sem` newtype, `send`/`sendUsing`, `run`/`runM`, row-manipulation (`raise`, `raiseUnder`, `subsume`, `insertAt`), `Raise`/`Subsume` typeclasses.
- [Polysemy-Internal-Bundle](docs/Polysemy-Internal-Bundle.html) — `extendMembership`, `subsumeMembership` for `ElemOf` proof manipulation across appended effect rows.
- [Polysemy-Internal-Combinators](docs/Polysemy-Internal-Combinators.html) — Interpreter combinators: `interpret`, `intercept`, `reinterpret`/`reinterpret2`/`reinterpret3`, `transform`, and higher-order `H` variants.
- [Polysemy-Internal-CustomErrors](docs/Polysemy-Internal-CustomErrors.html) — Type-level `WhenStuck`, `FirstOrder` for producing friendly GHC error messages on effect misuse.
- [Polysemy-Internal-CustomErrors-Redefined](docs/Polysemy-Internal-CustomErrors-Redefined.html) — `IfStuck`/`WhenStuck`/`UnlessStuck` redefined from `type-errors` for GHC compatibility.
- [Polysemy-Internal-Fixpoint](docs/Polysemy-Internal-Fixpoint.html) — Internal `Fixpoint` constructor and `bomb` error helper for failed recursive computations.
- [Polysemy-Internal-Index](docs/Polysemy-Internal-Index.html) — `InsertAtIndex` typeclass for type-level effect row partitioning.
- [Polysemy-Internal-Kind](docs/Polysemy-Internal-Kind.html) — Kind aliases: `type Effect`, `type EffectRow`, `type family Append`.
- [Polysemy-Internal-NonDet](docs/Polysemy-Internal-NonDet.html) — Internal `NonDet` data type: `Empty`, `Choose`.
- [Polysemy-Internal-Scoped](docs/Polysemy-Internal-Scoped.html) — Internal `Scoped param effect` and `OuterRun` type definitions.
- [Polysemy-Internal-Sing](docs/Polysemy-Internal-Sing.html) — `SList` singleton, `KnownList`/`ListOfLength` for type-level list reification.
- [Polysemy-Internal-Strategy](docs/Polysemy-Internal-Strategy.html) — `Strategy` GADT and `Strategic`/`WithStrategy` types for `Final`-based interpreters.
- [Polysemy-Internal-TH-Common](docs/Polysemy-Internal-TH-Common.html) — TH utilities: `ConLiftInfo`, `getEffectMetadata`, `makeSemType`, `makeInterpreterType`.
- [Polysemy-Internal-TH-Effect](docs/Polysemy-Internal-TH-Effect.html) — `makeSem` / `makeSem_` TH macros: auto-generate smart constructors from effect GADTs.
- [Polysemy-Internal-Tactics](docs/Polysemy-Internal-Tactics.html) — `Tactics` GADT, `Tactical`/`WithTactics`: `runT`, `bindT`, `pureT`, `liftT`, `getInitialStateT`, `getInspectorT`, `Inspector`.
- [Polysemy-Internal-Union](docs/Polysemy-Internal-Union.html) — `Union r m a`, `Weaving e m a`, `ElemOf` (`Here`/`There`), `Member`, `inj`/`prj`/`decomp`/`weaken`/`extract`/`absurdU`.
- [Polysemy-Internal-Writer](docs/Polysemy-Internal-Writer.html) — Internal `Writer o` GADT (`Tell`/`Listen`/`Pass`), `writerToEndoWriter`, STM-backed writer implementations.

---

## Source Code (`src/`)

Annotated Haskell source for each module.

### Core

- [Polysemy](src/Polysemy.html) — Top-level re-export module source.
- [Polysemy.Final](src/Polysemy.Final.html) — `Final` effect, `Strategic` DSL, `interpretFinal`, `runFinal`.
- [Polysemy.IO](src/Polysemy.IO.html) — `embedToMonadIO` implementation.
- [Polysemy.Membership](src/Polysemy.Membership.html) — `ElemOf` re-exports and membership-based interpreter helpers.

### Effects

- [Polysemy.Async](src/Polysemy.Async.html) — `Async` effect GADT, `async`/`await`/`cancel`, `sequenceConcurrently`, `asyncToIOFinal`.
- [Polysemy.AtomicState](src/Polysemy.AtomicState.html) — `AtomicState` GADT, `atomicGet`/`atomicState'`, IORef/TVar runners.
- [Polysemy.Bundle](src/Polysemy.Bundle.html) — `Bundle` effect, `injBundle`/`sendBundle`, `runBundle`/`subsumeBundle`.
- [Polysemy.Embed](src/Polysemy.Embed.html) — `Embed` re-export and `runEmbedded`.
- [Polysemy.Embed.Type](src/Polysemy.Embed.Type.html) — `Embed m` newtype definition.
- [Polysemy.Error](src/Polysemy.Error.html) — `Error e` GADT (`Throw`/`Catch`), interpreters and combinators.
- [Polysemy.Fail](src/Polysemy.Fail.html) — `Fail` interpreters: `runFail`, `failToError`, `failToNonDet`, `failToEmbed`.
- [Polysemy.Fail.Type](src/Polysemy.Fail.Type.html) — `Fail` newtype definition.
- [Polysemy.Fixpoint](src/Polysemy.Fixpoint.html) — `Fixpoint` effect and `fixpointToFinal`.
- [Polysemy.Input](src/Polysemy.Input.html) — `Input i` GADT, `input`/`inputs`, runners.
- [Polysemy.NonDet](src/Polysemy.NonDet.html) — `NonDet` interpreters: `runNonDet`, `runNonDetMaybe`, `nonDetToError`.
- [Polysemy.Opaque](src/Polysemy.Opaque.html) — `Opaque e` newtype, `toOpaque`/`fromOpaque`.
- [Polysemy.Output](src/Polysemy.Output.html) — `Output o` GADT, list/monoid/IORef/TVar/batched runners.
- [Polysemy.Reader](src/Polysemy.Reader.html) — `Reader i` GADT (`Ask`/`Local`), `runReader`, `inputToReader`.
- [Polysemy.Resource](src/Polysemy.Resource.html) — `Resource` GADT (`Bracket`/`BracketOnError`), `runResource`, `resourceToIOFinal`.
- [Polysemy.Scoped](src/Polysemy.Scoped.html) — `Scoped` interpreters: `interpretScoped*`, `runScoped*`.
- [Polysemy.State](src/Polysemy.State.html) — `State s` GADT (`Get`/`Put`), strict/lazy runners, IORef/STRef backends.
- [Polysemy.Tagged](src/Polysemy.Tagged.html) — `Tagged k e` newtype, `tag`/`tagged`/`untag`/`retag`.
- [Polysemy.Trace](src/Polysemy.Trace.html) — `Trace` GADT, handle/stdout/stderr/list/ignore interpreters.
- [Polysemy.Writer](src/Polysemy.Writer.html) — `Writer o` GADT (`Tell`/`Listen`/`Pass`), strict/lazy/assocR/TVar runners.

### Internals

- [Polysemy.Internal](src/Polysemy.Internal.html) — `Sem` newtype, `Member`/`Members`, `send`/`embed`/`run`/`runM`, row manipulation.
- [Polysemy.Internal.Bundle](src/Polysemy.Internal.Bundle.html) — `extendMembership`/`subsumeMembership` for `ElemOf` proofs.
- [Polysemy.Internal.Combinators](src/Polysemy.Internal.Combinators.html) — `interpret`, `reinterpret*`, `intercept*`, `transform`, `stateful`, `lazilyStateful`.
- [Polysemy.Internal.CustomErrors](src/Polysemy.Internal.CustomErrors.html) — `FirstOrder`, `WhenStuck`, error message type operators.
- [Polysemy.Internal.CustomErrors.Redefined](src/Polysemy.Internal.CustomErrors.Redefined.html) — `IfStuck`/`WhenStuck`/`UnlessStuck` GHC-compatible redefinitions.
- [Polysemy.Internal.Fixpoint](src/Polysemy.Internal.Fixpoint.html) — `Fixpoint` constructor and `bomb` error.
- [Polysemy.Internal.Index](src/Polysemy.Internal.Index.html) — `InsertAtIndex` for type-level row insertion.
- [Polysemy.Internal.Kind](src/Polysemy.Internal.Kind.html) — `Effect`/`EffectRow` kind aliases, `Append` type family.
- [Polysemy.Internal.NonDet](src/Polysemy.Internal.NonDet.html) — `NonDet` data type (`Empty`/`Choose`).
- [Polysemy.Internal.PluginLookup](src/Polysemy.Internal.PluginLookup.html) — `PluginLookup` typeclass and `Plugin` type for GHC plugin module discovery.
- [Polysemy.Internal.Scoped](src/Polysemy.Internal.Scoped.html) — `Scoped param effect` and `OuterRun` internal types.
- [Polysemy.Internal.Sing](src/Polysemy.Internal.Sing.html) — `SList` singleton, `KnownList`/`ListOfLength`.
- [Polysemy.Internal.Strategy](src/Polysemy.Internal.Strategy.html) — `Strategy` GADT, `Strategic`/`WithStrategy`, `runStrategy`.
- [Polysemy.Internal.TH.Common](src/Polysemy.Internal.TH.Common.html) — TH utilities: `ConLiftInfo`, metadata extraction, type builders.
- [Polysemy.Internal.TH.Effect](src/Polysemy.Internal.TH.Effect.html) — `makeSem`/`makeSem_` TH code generators.
- [Polysemy.Internal.Tactics](src/Polysemy.Internal.Tactics.html) — `Tactics` GADT, `Tactical`/`WithTactics`, `runT`/`bindT`/`pureT`/`liftT`/`Inspector`.
- [Polysemy.Internal.Union](src/Polysemy.Internal.Union.html) — `Union`/`Weaving`/`ElemOf`, `inj`/`prj`/`decomp`/`weave`/`hoist`/`weaken`.
- [Polysemy.Internal.Writer](src/Polysemy.Internal.Writer.html) — Internal `Writer` GADT, `writerToEndoWriter`, STM-backed implementations.

### Build

- [Paths_polysemy](src/Paths_polysemy.html) — Auto-generated Cabal paths module: `version`, `getBinDir`, `getDataDir`.
