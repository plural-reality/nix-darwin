# Project:M36 — Relational Algebra DBMS

Project:M36 is a relational-algebra-based database management system implemented in Haskell. It adheres strictly to the mathematics of the relational algebra — no NULL, no SQL compromises. Key differentiators:

- **Transaction Graph**: Git-like branching/merging for database transactions (not a linear log)
- **Pure Relational Algebra**: Type-safe, composable operators with algebraic optimization
- **Native Haskell Integration**: Any `Atomable` type can be a database value; Haskell functions run inside the DB
- **TutorialD**: Chris Date's teaching language as the primary interactive interface

## When to use this skill

Invoke this skill when the user asks about:
- Project:M36 architecture, setup, or usage
- Relational algebra concepts (in the context of Project:M36)
- TutorialD syntax or operations
- Haskell ↔ Project:M36 integration (Tupleable, AtomFunctions, custom types)
- Transaction graph operations (branching, merging, time-travel)
- SQLegacy (SQL compatibility layer)

---

## Additional Resources

### Getting Started

- [Introduction to Project:M36](introduction_to_projectm36.markdown) — Overview, installation (Docker/source), and feature summary
- [Introduction to the Relational Algebra](introduction_to_the_relational_algebra.markdown) — Mathematical foundations underpinning the system
- [15-Minute Tutorial](15_minute_tutorial.markdown) — Quick hands-on walkthrough
- [TutorialD Tutorial](tutd_tutorial.markdown) — Comprehensive TutorialD language guide
- [TutorialD Cheatsheet](tutd_cheatsheet.markdown) — Quick reference for TutorialD syntax
- [Developer Setup](dev_setup.markdown) — Building from source and development environment

### Architecture & Theory

- [ACID Assessment](acid_assessment.markdown) — How Project:M36 satisfies ACID properties
- [Data Independence](data_independence.markdown) — Towards an architecture for data independence
- [On NULL](on_null.markdown) — Why Project:M36 rejects NULL and what replaces it
- [Reaching Out of the Tarpit](reaching_out_of_the_tarpit.markdown) — Philosophical design rationale (cf. "Out of the Tar Pit")
- [Commits in O(1)](commits_in_constant_time.markdown) — Constant-time transactional commits
- [Merkle Transaction Graph](merkle_transaction_graph.markdown) — Merkle hashing for transaction integrity
- [Filesystem Persistence](filesystem-persistence.markdown) — Persistence layer design proposal

### Transaction Graph

- [Transaction Graph Operators](transaction_graph_operators.markdown) — Branching, jumping, and graph navigation
- [Merge Transactions](merge_transactions.markdown) — Merging divergent branches
- [Merge Notes](merge_notes.markdown) — Automatic merge conflict resolution details
- [Trans-Graph Relational Expressions](transgraphrelationalexpr.markdown) — Querying across transaction graph nodes

### Client Libraries & Access

- [Haskell Client Library](projectm36_client_library.markdown) — Native `ProjectM36.Client` API
- [Simple Client API](simple_api.markdown) — Simplified client interface
- [JavaScript Driver](javascript_driver.markdown) — JS/Node.js driver
- [WebSocket Server](websocket_server.markdown) — WebSocket-based access layer
- [Server Mode](server_mode.markdown) — Running as a network server

### Haskell Integration

- [Tupleable](tupleable.markdown) — Marshaling Haskell data types to/from database tuples
- [Atom Functions](atomfunctions.markdown) — Extendable functions operating on atomic values
- [Database Context Functions](database_context_functions.markdown) — Functions that modify database context
- [Creating New Data Types](new_datatypes.markdown) — Defining custom algebraic data types in the DB
- [Haskell Integration Guide](cartographer_integration.md) — End-to-end Haskell application integration

### Schema & DDL

- [Isomorphic Schemas](isomorphic_schemas.markdown) — Schema transformations preserving information content
- [Handling DDL Changes](Handling_DDL_Changes.markdown) — Managing data definition language changes

### Features

- [DataFrames](dataframes.markdown) — DataFrame-style ordered/limited result sets
- [CSV Import/Export](import_export_csv.markdown) — Importing and exporting relations as CSV
- [Notifications](using_notifications.markdown) — Event-driven notification system
- [Replication](replication.markdown) — Multi-node replication architecture
- [Jupyter Kernel](jupyter_kernel.markdown) — TutorialD kernel for Jupyter notebooks

### SQL Compatibility

- [SQLegacy](sqlegacy.markdown) — SQL frontend on the relational algebra engine
- [Why SQLegacy?](why_sqlegacy.markdown) — Rationale for providing SQL compatibility

### Assets

- `basic_benchmarks.html` — Criterion benchmark report
- `committed_database_state.dot` / `initial_database_state.dot` — Graphviz diagrams of database state
- `sample_session.asciinema.json` — Terminal session recording
