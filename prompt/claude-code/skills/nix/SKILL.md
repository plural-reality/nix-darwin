# Nix — Purely Functional Package Manager

Nix is a purely functional package manager that treats packages as values in a functional programming language — built by pure functions with no side effects, never overwritten after creation. This skill covers the complete Nix manual: language reference, store internals, command-line tools, and protocols.

Key properties:
- **Reproducible**: Hermetic builds via pure function semantics — same inputs always produce the same outputs
- **Declarative**: Package descriptions are Nix expressions, not imperative scripts
- **Reliable**: Atomic upgrades/rollbacks, multiple versions coexist, garbage collection for unused paths
- **Multi-user**: Unprivileged users can install packages securely without root

## When to use this skill

Invoke when the user asks about:
- Nix language syntax, builtins, derivations, or evaluation semantics
- Nix store concepts (store paths, content addressing, file system objects)
- Nix CLI commands (`nix-build`, `nix-env`, `nix-store`, `nix-shell`, etc.)
- Package management (profiles, channels, garbage collection, binary caches)
- Distributed/remote builds, build reproducibility, caching strategies
- Nix protocols (NAR format, store path calculation, JSON formats)
- Nix internals, architecture, or contributing to Nix development

---

## Additional Resources

### Overview

- [Introduction](introduction.md) — What Nix is and its core features
- [Quick Start](quick-start.md) — Minimal getting-started guide (install, run, search, GC)
- [Glossary](glossary.md) — Definitions of Nix terminology (derivation, store path, closure, etc.)
- [Table of Contents](SUMMARY.md.in) — Master hierarchical index of the entire manual

### Installation

- [Installation Overview](installation/index.md) — Recommended installation methods
- [Installing a Binary Distribution](installation/installing-binary.md) — Install via official script (`curl | sh`)
- [Using Nix within Docker](installation/installing-docker.md) — Running Nix in Docker containers
- [Supported Platforms](installation/supported-platforms.md) — Linux (i686, x86_64, aarch64) and macOS
- [Multi-User Mode](installation/multi-user.md) — Shared store with build user isolation
- [Single-User Mode](installation/single-user.md) — Single-user store ownership
- [Security](installation/nix-security.md) — Security models and threat prevention
- [Environment Variables](installation/env-variables.md) — PATH setup and `nix.sh` sourcing
- [Upgrading](installation/upgrading.md) — Version upgrades via channels
- [Uninstalling](installation/uninstall.md) — Removal steps for Linux/macOS
- Building from source: [Prerequisites](installation/prerequisites-source.md) | [Obtaining Source](installation/obtaining-source.md) | [Building](installation/building-source.md) | [Installing](installation/installing-source.md)

### Nix Language

- [Language Overview](language/index.md) — Domain-specific, declarative, pure, lazy, dynamically typed
- [Syntax](language/syntax.md) — Expression syntax and semantics
- [Data Types](language/types.md) — Integer, Float, Boolean, String, Path, Null, Attrset, List, Function
- [Variables](language/variables.md) — Variable binding and usage
- [Identifiers](language/identifiers.md) — Naming rules and reserved keywords
- [Scoping Rules](language/scope.md) — `let`, `rec`, `with`, and function scopes
- [String Literals](language/string-literals.md) — Quoted strings, indented strings, URI literals
- [String Interpolation](language/string-interpolation.md) — `${ }` syntax in strings, paths, and attribute names
- [String Context](language/string-context.md) — Derivation dependency tracking via string contexts
- [Operators](language/operators.md) — Full operator reference with precedence and associativity
- [Language Constructs](language/constructs.md) — Expression forms and control flow
  - [Lookup Path](language/constructs/lookup-path.md) — `<name>` resolution via `builtins.nixPath`
- [Derivations](language/derivations.md) — The `derivation` builtin and store derivation creation
- [Evaluation](language/evaluation.md) — How expressions become values (lazy evaluation)
- [Import From Derivation](language/import-from-derivation.md) — When expression values depend on build outputs
- [Advanced Attributes](language/advanced-attributes.md) — Infrequent derivation attributes (`exportReferencesGraph`, etc.)
- [Built-in Functions](language/builtins-prefix.md) — Reference for all `builtins.*` functions

### Nix Store

- [Store Overview](store/index.md) — Immutable file system abstraction for packages and dependencies
- [Store Object](store/store-object.md) — FSO data + reference set forming a directed graph
- [Store Path](store/store-path.md) — Opaque unique identifiers (e.g. `/nix/store/a040m110...-git-2.38.1`)
- [File System Object](store/file-system-object.md) — Simplified FS model (files, directories, symlinks)
- [Building](store/building.md) — How derivations are built (input normalization, builder execution)
- [Build Trace](store/build-trace.md) — Memoization table for content-addressed derivation outputs
- [Secrets](store/secrets.md) — Why secrets must not be embedded in store objects
- [Derivation Resolution](store/resolution.md) — Replacing inputs with simplest equivalent paths
- Derivation outputs: [Overview](store/derivation/index.md) | [Output Types](store/derivation/outputs/index.md) | [Content-Addressed](store/derivation/outputs/content-address.md) | [Input-Addressed](store/derivation/outputs/input-address.md)
- Content addressing: [FSO](store/file-system-object/content-address.md) | [Store Object](store/store-object/content-address.md)
- [Math Notation Appendix](store/math-notation.md) — Formal notation for store path grammar

### Package Management

- [Package Management Overview](package-management/index.md) — Obtaining, installing, upgrading, and erasing packages
- [Profiles](package-management/profiles.md) — Per-user configurations with atomic upgrades/rollbacks
- [Garbage Collection](package-management/garbage-collection.md) — Removing unused packages
- [Garbage Collector Roots](package-management/garbage-collector-roots.md) — Symlinks protecting store paths from GC
- [Binary Cache (HTTP)](package-management/binary-cache-substituter.md) — Serving a Nix store as a binary cache
- [SSH Substituter](package-management/ssh-substituter.md) — Fetching binaries from remote stores via SSH
- [Sharing Packages](package-management/sharing-packages.md) — Copying packages between machines

### Command Reference

- [Command Reference Overview](command-ref/index.md) — Index of all Nix commands
- [Common Options](command-ref/opt-common.md) — Universal CLI options (`--help`, etc.)
- [Common Environment Variables](command-ref/env-common.md) — `NIX_PATH`, `IN_NIX_SHELL`, etc.
- [Configuration File (`nix.conf`)](command-ref/conf-file-prefix.md) — Settings and format
- [Build Failure Exit Codes](command-ref/status-build-failure.md) — Exit codes 100 (generic), 101 (timeout), etc.

#### Main Commands

- [`nix-build`](command-ref/nix-build.md) — Build a Nix expression
- [`nix-shell`](command-ref/nix-shell.md) — Interactive shell from Nix expression
- [`nix-store`](command-ref/nix-store.md) — Manipulate/query the store
- [`nix-env`](command-ref/nix-env.md) — Manage user environments
- [`nix-channel`](command-ref/nix-channel.md) — Manage Nix channels
- [`nix-collect-garbage`](command-ref/nix-collect-garbage.md) — Delete unreachable store objects
- [`nix-instantiate`](command-ref/nix-instantiate.md) — Instantiate store derivations from expressions
- [`nix-hash`](command-ref/nix-hash.md) — Compute cryptographic hashes
- [`nix-prefetch-url`](command-ref/nix-prefetch-url.md) — Download URL to store and print hash
- [`nix-copy-closure`](command-ref/nix-copy-closure.md) — Copy closures to/from remote machines
- [`nix-daemon`](command-ref/nix-daemon.md) — Multi-user support daemon

#### `nix-env` Subcommands

- [install](command-ref/nix-env/install.md) | [uninstall](command-ref/nix-env/uninstall.md) | [upgrade](command-ref/nix-env/upgrade.md) | [query](command-ref/nix-env/query.md) | [set](command-ref/nix-env/set.md) | [set-flag](command-ref/nix-env/set-flag.md) | [rollback](command-ref/nix-env/rollback.md) | [switch-generation](command-ref/nix-env/switch-generation.md) | [switch-profile](command-ref/nix-env/switch-profile.md) | [list-generations](command-ref/nix-env/list-generations.md) | [delete-generations](command-ref/nix-env/delete-generations.md)

#### `nix-store` Subcommands

- [realise](command-ref/nix-store/realise.md) | [gc](command-ref/nix-store/gc.md) | [delete](command-ref/nix-store/delete.md) | [query](command-ref/nix-store/query.md) | [add](command-ref/nix-store/add.md) | [add-fixed](command-ref/nix-store/add-fixed.md) | [verify](command-ref/nix-store/verify.md) | [verify-path](command-ref/nix-store/verify-path.md) | [repair-path](command-ref/nix-store/repair-path.md) | [dump](command-ref/nix-store/dump.md) | [dump-db](command-ref/nix-store/dump-db.md) | [restore](command-ref/nix-store/restore.md) | [export](command-ref/nix-store/export.md) | [import](command-ref/nix-store/import.md) | [optimise](command-ref/nix-store/optimise.md) | [read-log](command-ref/nix-store/read-log.md) | [print-env](command-ref/nix-store/print-env.md) | [generate-binary-cache-key](command-ref/nix-store/generate-binary-cache-key.md) | [serve](command-ref/nix-store/serve.md) | [load-db](command-ref/nix-store/load-db.md)

#### Files

- [Profiles](command-ref/files/profiles.md) | [Channels](command-ref/files/channels.md) | [Default Nix Expression](command-ref/files/default-nix-expression.md) | [manifest.json](command-ref/files/manifest.json.md) | [manifest.nix](command-ref/files/manifest.nix.md)

- [Experimental Commands](command-ref/experimental-commands.md) — Unstable commands subject to change
- [Utilities](command-ref/utilities.md) — Additional utility tools

### Advanced Topics

- [Advanced Topics Overview](advanced-topics/index.md) — Build performance and advanced build features
- [Tuning Cores and Jobs](advanced-topics/cores-vs-jobs.md) — Configuring `cores` and `max-jobs` for CPU utilization
- [Verifying Build Reproducibility](advanced-topics/diff-hook.md) — Using `diff-hook` to compare builds
- [Remote/Distributed Builds](advanced-topics/distributed-builds.md) — Forwarding builds to other machines
- [Evaluation Profiler](advanced-topics/eval-profiler.md) — Flamegraph-compatible profiling of Nix evaluation
- [Post-Build Hook](advanced-topics/post-build-hook.md) — Auto-running scripts after builds (e.g. upload to cache)

### Protocols

- [Protocols Overview](protocols/index.md) — Developer-facing interfaces provided by Nix
- [Store Path Calculation](protocols/store-path.md) — Full EBNF spec for computing store paths
- [Derivation ATerm Format](protocols/derivation-aterm.md) — On-disk serialization (`Derive(...)`)
- [Tarball Fetcher Protocol](protocols/tarball-fetcher.md) — Lockable HTTP tarball serving via `Link` header
- [Nix Archive (NAR) Format](protocols/nix-archive/index.md) — EBNF spec for FSO tree serialization
- JSON formats: [Index](protocols/json/index.md) | [Build Result](protocols/json/build-result.md) | [Store Path](protocols/json/store-path.md) | [Store](protocols/json/store.md) | [Store Object Info](protocols/json/store-object-info.md) | [Content Address](protocols/json/content-address.md) | [Hash](protocols/json/hash.md) | [Deriving Path](protocols/json/deriving-path.md) | [FSO](protocols/json/file-system-object.md) | [Build Trace Entry](protocols/json/build-trace-entry.md) | [Derivation](protocols/json/derivation/index.md) | [Derivation Options](protocols/json/derivation/options.md)

### Architecture

- [Architecture](architecture/architecture.md) — Internal component hierarchy and concept map

### Development (Contributing to Nix)

- [Development Overview](development/index.md) — Entry points for contributing
- [Building Nix](development/building.md) — Cloning and building from source
- [Testing](development/testing.md) — Coverage analysis and test execution
- [Debugging](development/debugging.md) — Debug symbols and debugging in tests
- [Contributing](development/contributing.md) — Release note format and PR conventions
- [CLI Guideline](development/cli-guideline.md) — UX design guidelines for `nix` commands
- [JSON Guideline](development/json-guideline.md) — Consistent JSON interface practices
- [C++ Style Guide](development/cxx.md) — C++ conventions and `*-impl.hh` pattern
- [Documentation](development/documentation.md) — Contributing docs, building the manual
- [Experimental Features](development/experimental-features.md) — Feature flag system for unstable functionality
- [Benchmarking](development/benchmarking.md) — Google Benchmark framework usage

### C API

- [C API](c-api.md) — In-development stable C API with auto-generated documentation

### Release Notes

- [Release Notes Index](release-notes/index.md) — All release notes from Nix 0.5 through 2.33

### Assets

- `figures/user-environments.png` — User environments diagram
- `figures/user-environments.sxd` — Source for user environments diagram
