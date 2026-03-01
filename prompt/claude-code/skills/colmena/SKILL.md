# Colmena — Stateless NixOS Deployment Tool

Colmena is a simple, stateless NixOS deployment tool written in Rust, modeled after NixOps and morph. It acts as a thin wrapper over Nix commands (`nix-instantiate`, `nix-copy-closure`) and supports parallel deployment to multiple hosts. Configuration is defined declaratively via a `hive.nix` file or Nix Flakes (`colmenaHive` output), with no external state database required.

## When to use this skill

- Deploying NixOS configurations to one or more remote hosts over SSH
- Setting up a multi-node NixOS cluster with shared and per-node configurations
- Writing `hive.nix` or Flake-based Colmena configurations (`colmena.lib.makeHive`)
- Deploying secrets (`deployment.keys`) that must not enter the Nix store
- Filtering deployment targets by node tags (`--on @tag`) or name globs
- Building configurations locally or remotely (`deployment.buildOnTarget`)
- Running ad hoc Nix expressions against the full hive (`colmena eval`)
- Performing local deployment on the Colmena host itself (`colmena apply-local`)
- Migrating existing NixOps or morph configurations to Colmena
- Configuring multi-architecture deployments (e.g., x86_64 building for aarch64 via binfmt)
- Tuning parallelism for evaluation and deployment (`--limit`, `--eval-node-limit`, `--evaluator streaming`)

---

## Additional Resources

### Manual
- [manual.md](manual.md) — Full Colmena manual covering installation, configuration (classic and Flakes), features (node tagging, local deployment, secrets, ad hoc evaluation, parallelism, remote builds), deployment/meta option reference, all CLI subcommand help, release notes, and migration guides
