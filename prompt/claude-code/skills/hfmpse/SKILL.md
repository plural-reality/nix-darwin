---
name: hfmpse
description: "Use this skill when building full-stack web applications with haskell-flake + Project:M36 + Polysemy + Servant + servant-elm + elm-ui. Triggers include: any mention of Servant, Polysemy, Project:M36, elm-ui, elm-css, servant-elm, haskell-flake, or requests to build type-safe full-stack Haskell/Elm applications. Also use when: defining Servant API types, writing Polysemy effects/interpreters, designing M36 schemas with event sourcing, generating Elm client code from Servant, building Elm UIs with elm-ui, or configuring haskell-flake builds with Elm and servant-elm codegen. Covers the entire stack from database schema through API boundary to frontend rendering, including Nix-based build integration. Do NOT use for: React/Vue/Angular frontends, REST frameworks other than Servant, ORMs like persistent/esqueleto, non-Haskell backends, or deployment concerns (use sktc-deploy for SOPS/Terraform/Colmena/NixOS)."
---

# HFMPSE: Type-Safe Full-Stack with Haskell + Elm

**H**askell-**F**lake + **M**36 + **P**olysemy + **S**ervant-**E**lm (+ elm-ui)

Build full-stack web applications where type errors are caught at compile time across every layer — from database through API to UI. The core principle: **if it compiles, the layers agree**.

## Stack Overview

```
Elm (Browser.application)
  UI:     elm-ui (layout/styling) + elm-css (media queries only)
  API:    servant-elm auto-generated client
  ─── HTTP JSON (types guaranteed by servant-elm) ───
Haskell Backend
  Web:    Servant (type-level API)
  Logic:  Polysemy (algebraic effects)
  ─── Haskell ADT direct persistence ───
Project:M36
  Storage:  Event store + projections
  Safety:   Transaction graph as additional safety net
  ─── Build ───
haskell-flake (flake-parts)
  Haskell:  haskellProjects.default
  Elm:      stdenv derivation
  Codegen:  servant-elm as flake app + CI check
  Output:   packages.<name> = bin/<name>-server + static/
```

### Build Output Contract

This stack produces a single Nix package containing:
- `bin/<name>-server` — the Haskell Warp binary (Servant + Polysemy)
- `static/` — compiled Elm frontend (`main.js`, `index.html`)

Any deployment skill (e.g., sktc-deploy) can consume this package by passing it as `appPackage` to a NixOS service definition.

## Architecture Principles

1. **Types are the specification.** The Servant API type IS the API contract. Elm code is generated from it. M36 stores Haskell ADTs directly. No hand-written JSON serialization crosses boundaries.
2. **Events are primary data.** Domain events are append-only. Projections (current state views) are derived caches that can be rebuilt from events.
3. **Effects separate what from how.** Business logic is written against Polysemy effect interfaces. Infrastructure (M36, HTTP, AI services) is injected via interpreters.
4. **elm-ui for layout, elm-css only for escape hatches.** All layout and styling uses elm-ui's type-safe primitives. elm-css is restricted to CSS features elm-ui cannot express (media queries, keyframe animations).

---

## Implementation Guides (load on demand)

各セクションは独立した reference ファイルに分離されている。該当する作業を始めるときだけ読み込むこと。

- [1. Servant API Definition](references/01-servant-api.md) — type-level API 型・request/response 型・thin handler を書くとき
- [2. Polysemy Effects](references/02-polysemy-effects.md) — effect 定義・interpreter（M36/in-memory）・effect 合成・error handling を書くとき
- [3. Project:M36 Schema Design](references/03-m36-schema.md) — relvar 設計・event sourcing・event/projection・atomic transaction・projection rebuild を書くとき
- [4. servant-elm Code Generation](references/04-servant-elm-codegen.md) — Servant API から Elm クライアントを生成し、codegen consistency を担保するとき
- [5. Elm Frontend](references/05-elm-frontend.md) — Browser.application・routing・module 構成・page module パターンを書くとき
- [6. elm-ui Styling](references/06-elm-ui-styling.md) — elm-ui によるレイアウト/スタイリング・Theme・レスポンシブ・再利用コンポーネント・elm-css escape hatch を書くとき
- [7. Ports (JavaScript Interop)](references/07-ports.md) — Elm と JavaScript を ports 経由で連携させるとき
- [8. Build System (haskell-flake + flake-parts)](references/08-build-system.md) — flake.nix・cabal 構成・haskell-flake と Project:M36・devShell・build コマンドを設定するとき

---

## 9. Project Directory Layout

```
project/
├── flake.nix                        -- haskell-flake + Elm + codegen + combined package
├── flake.lock
├── justfile
│
├── backend/                         -- Haskell (haskell-flake projectRoot)
│   ├── myapp.cabal                  -- library + myapp-server + myapp-codegen
│   ├── app/
│   │   └── Main.hs                  -- Warp entry point (myapp-server)
│   ├── codegen/
│   │   └── Main.hs                  -- servant-elm generator (myapp-codegen)
│   ├── src/
│   │   └── MyApp/
│   │       ├── Api.hs               -- Servant API type (drives everything)
│   │       ├── Api/
│   │       │   ├── Types.hs         -- Request/response types (Generic, ToJSON, FromJSON, Elm)
│   │       │   └── Handlers.hs      -- Thin Servant handlers
│   │       ├── Domain/
│   │       │   ├── Types.hs         -- ADTs, newtypes (Atomable)
│   │       │   └── Events.hs        -- Domain event types
│   │       ├── Effects/             -- Polysemy effect definitions
│   │       │   ├── Item.hs
│   │       │   ├── Persistence.hs
│   │       │   └── ...
│   │       ├── Interpreters/        -- Effect implementations
│   │       │   ├── M36.hs           -- Production: Project:M36
│   │       │   ├── InMemory.hs      -- Testing: in-memory
│   │       │   └── ...
│   │       ├── M36/
│   │       │   ├── Schema.hs        -- Relvar definitions
│   │       │   ├── Transactions.hs  -- Transaction builders
│   │       │   └── Rebuild.hs       -- Projection rebuilding
│   │       ├── Config.hs
│   │       └── Server.hs            -- Warp setup (imported by app/Main.hs)
│   └── test/
│
├── frontend/                        -- Elm
│   ├── elm.json
│   ├── index.html
│   ├── src/
│   │   ├── Main.elm                 -- Browser.application entry point
│   │   ├── Route.elm                -- URL type + parser
│   │   ├── Ports.elm                -- JavaScript interop
│   │   ├── Page/                    -- Each page is an independent TEA module
│   │   ├── UI/                      -- Shared elm-ui components
│   │   │   ├── Theme.elm
│   │   │   ├── Button.elm
│   │   │   ├── Card.elm
│   │   │   ├── Layout.elm
│   │   │   └── MediaQuery.elm       -- elm-css escape hatches only
│   │   ├── Domain/                  -- Wrappers around Api.Generated types
│   │   └── Api/
│   │       └── Generated.elm        -- AUTO-GENERATED by servant-elm (DO NOT EDIT)
│   └── tests/
│
└── static/                          -- Additional static assets (images, etc.)
```

---

## 10. Prohibitions

These rules exist to maintain type safety across the full stack. Violating them creates holes that bypass compile-time checking.

| Category | ❌ Prohibited | ✅ Instead |
|----------|-------------|-----------|
| **Types** | Raw `UUID`, `Int`, `Text` in API signatures | `ItemId`, `BatchIndex`, `UserName` newtypes |
| **Types** | `String` in Haskell | `Text` (from `Data.Text`) |
| **Types** | `Any`, `Dynamic`, untyped JSON values | Proper ADTs |
| **Types** | Partial functions: `head`, `!!`, `fromJust` | Pattern matching, `Maybe`, `NonEmpty` |
| **Serialization** | Hand-written JSON encoders/decoders in Elm | servant-elm generated code |
| **Serialization** | Manual `parseJSON`/`toJSON` for API types | Derive via `Generic` |
| **Architecture** | Business logic in Servant handlers | Polysemy effect calls |
| **Architecture** | Direct M36 queries in handlers | `PersistenceEffect` |
| **Architecture** | Editing `Api/Generated.elm` | Run `nix run .#codegen` |
| **Events** | UPDATE or DELETE on event store relvar | Append only |
| **Events** | Projection update without event in same tx | `MultipleExpr` atomic tx |
| **Styling** | Tailwind CSS class strings | elm-ui typed attributes |
| **Styling** | Inline `style` attributes | elm-ui typed attributes |
| **Styling** | elm-css for layout/colors/spacing | elm-ui (elm-css only for media queries) |
| **JS Interop** | `Json.Decode.value` hacks | Proper Ports |

---

## 11. Verification Checklist

Before considering any feature complete:

- [ ] All new types derive required instances (`Generic`, `Atomable`, `ToJSON`, `FromJSON`, `Elm` as needed)
- [ ] `nix flake check` passes (builds Haskell, builds Elm, codegen consistency)
- [ ] `nix run .#codegen` produces no diff in `Api/Generated.elm`
- [ ] `nix build .#myapp` succeeds (combined package: `bin/myapp-server` + `static/`)
- [ ] New domain events are appended (not inserted by overwriting)
- [ ] Event insertion and projection update are in same `MultipleExpr`
- [ ] Projection rebuild function updated if new event types added
- [ ] No primitive types in API boundaries
- [ ] No Tailwind or inline styles in Elm code
- [ ] elm-css usage is limited to media query escape hatches
- [ ] Tests pass: `cd backend && cabal test && cd ../frontend && elm-test`
