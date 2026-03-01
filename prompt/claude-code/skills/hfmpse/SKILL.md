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

## 1. Servant API Definition

### Type-Level API

Define the entire API as a Haskell type. This type drives both the server implementation and the Elm client generation.

```haskell
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}

module MyApp.Api (MyAppAPI) where

import Servant

type MyAppAPI =
       -- Public endpoints
       "api" :> "items" :> Get '[JSON] [Item]
  :<|> "api" :> "items" :> ReqBody '[JSON] CreateItemReq :> Post '[JSON] ItemId
  :<|> "api" :> "items" :> Capture "id" ItemId :> Get '[JSON] Item

       -- Protected endpoints (authentication required)
  :<|> AuthProtect "jwt" :> "api" :> "admin" :> "items" :> Get '[JSON] [ItemAdmin]

       -- SPA fallback (serves index.html for all unmatched routes)
  :<|> Raw
```

### Request/Response Types

Every type that crosses the API boundary must derive `Generic`, `ToJSON`, `FromJSON`, and `Elm`.

```haskell
module MyApp.Api.Types where

import GHC.Generics (Generic)
import Data.Aeson (ToJSON, FromJSON)
import Servant.Elm (Elm)

-- Newtypes for all identifiers — never use raw UUID/Int/Text in API types
newtype ItemId = ItemId UUID
  deriving (Generic, ToJSON, FromJSON, Elm, Eq, Show, FromHttpApiData)

-- Request types: *Req suffix
data CreateItemReq = CreateItemReq
  { cirName        :: Text
  , cirDescription :: Text
  } deriving (Generic, ToJSON, FromJSON, Elm)

-- Response types: domain-appropriate names
data Item = Item
  { itemId          :: ItemId
  , itemName        :: Text
  , itemDescription :: Text
  , itemCreatedAt   :: UTCTime
  } deriving (Generic, ToJSON, FromJSON, Elm)
```

### Rules

- **Never use primitive types directly in API signatures.** Wrap `UUID` in `ItemId`, `Int` in `BatchIndex`, etc. This prevents argument transposition bugs.
- **Request types get `*Req` suffix.** `CreateItemReq`, `UpdateItemReq`.
- **All API types live in a single module** (`Api.Types`) so servant-elm can find them.
- **Servant handlers must be thin.** They only translate HTTP concerns to Polysemy effect calls. No business logic in handlers.

```haskell
-- ✅ Correct: handler delegates to effect
createItemHandler :: Members '[ItemEffect, Error AppError] r
                  => CreateItemReq -> Sem r ItemId
createItemHandler = createItem  -- just calls the effect

-- ❌ Wrong: handler contains logic
createItemHandler req = do
  validate req           -- logic leaking into handler
  existingItems <- query -- direct DB access
  if length existingItems > 100 then throwError LimitReached
  else insertItem req
```

---

## 2. Polysemy Effects

### Effect Definition Pattern

Each domain concept gets its own effect. Effects define WHAT operations are available, not HOW they are implemented.

```haskell
{-# LANGUAGE GADTs #-}
{-# LANGUAGE TemplateHaskell #-}

module MyApp.Effects.Item where

import Polysemy

data ItemEffect m a where
  CreateItem   :: CreateItemReq -> ItemEffect m ItemId
  GetItem      :: ItemId -> ItemEffect m Item
  ListItems    :: ItemEffect m [Item]
  UpdateItem   :: ItemId -> UpdateItemReq -> ItemEffect m Item
  DeleteItem   :: ItemId -> ItemEffect m ()

makeSem ''ItemEffect
```

`makeSem` generates lowercase functions: `createItem`, `getItem`, `listItems`, etc.

### Interpreter Pattern

Write separate interpreters for production and testing:

```haskell
-- Production: M36 backend
module MyApp.Interpreters.M36 where

runItemEffectM36
  :: Member (Embed IO) r
  => Connection
  -> Sem (ItemEffect ': r) a
  -> Sem r a
runItemEffectM36 conn = interpret $ \case
  CreateItem req -> embed $ m36CreateItem conn req
  GetItem iid    -> embed $ m36GetItem conn iid
  ListItems      -> embed $ m36ListItems conn
  UpdateItem iid req -> embed $ m36UpdateItem conn iid req
  DeleteItem iid -> embed $ m36DeleteItem conn iid

-- Testing: in-memory
module MyApp.Interpreters.InMemory where

runItemEffectInMemory
  :: Member (State (Map ItemId Item)) r
  => Sem (ItemEffect ': r) a
  -> Sem r a
runItemEffectInMemory = interpret $ \case
  CreateItem req -> do
    let iid = ItemId someUUID
    modify (Map.insert iid (fromReq iid req))
    pure iid
  GetItem iid -> do
    items <- get
    case Map.lookup iid items of
      Just item -> pure item
      Nothing   -> error "not found"  -- or use Error effect
  -- ...
```

### Composing Effects

Stack effects for the full application:

```haskell
type AppEffects =
  '[ ItemEffect
   , UserEffect
   , AuthEffect
   , PersistenceEffect
   , Error AppError
   , Embed IO
   , Final IO
   ]

runApp :: AppConfig -> Sem AppEffects a -> IO (Either AppError a)
runApp cfg = runFinal
  . embedToFinal
  . runError
  . runPersistenceM36 (cfgConnection cfg)
  . runAuthJwt (cfgJwtSecret cfg)
  . runUserEffectReal
  . runItemEffectReal
```

### Error Handling

Define a sum type for all application errors. Never use `String` errors.

```haskell
data AppError
  = ItemNotFound ItemId
  | UserNotFound UserId
  | Unauthorized
  | ValidationError ValidationFailure
  | DatabaseError Text              -- M36 errors can be Text
  deriving (Generic, Show)

-- Use in effects:
getItemOrFail :: Members '[ItemEffect, Error AppError] r
              => ItemId -> Sem r Item
getItemOrFail iid = do
  result <- getItem iid
  case result of
    Nothing -> throw (ItemNotFound iid)
    Just item -> pure item
```

---

## 3. Project:M36 Schema Design

### Core Concepts

Project:M36 is a relational algebra database that stores Haskell ADTs directly as attribute values. No ORM, no JSON serialization for storage — the Haskell type IS the database type.

```haskell
-- This ADT is stored directly in M36 — not serialized to JSON
data Priority = Low | Medium | High | Critical
  deriving (Generic, Atomable, Eq, Show)

-- Stored as-is, including the list
data Tags = Tags [Text]
  deriving (Generic, Atomable, Eq, Show)
```

### Event Sourcing Pattern

Structure the database into three categories of relation variables (relvars):

```
┌─────────────────────────────────┐
│  Event Store (append-only)      │  ← Primary data. Never update/delete.
│  domain_events                  │
├─────────────────────────────────┤
│  Projections (derived state)    │  ← Rebuilt from events. Updated in same tx.
│  items, users, summaries, ...   │
├─────────────────────────────────┤
│  Master Data (CRUD)             │  ← Config, templates, reference data.
│  categories, settings, ...      │
└─────────────────────────────────┘
```

### Event Type Design

Define domain events as a sum type. Include all information needed to reconstruct state.

```haskell
-- All types must derive Atomable for M36 storage
data DomainEvent
  = EItem    ItemEvent
  | EUser    UserEvent
  | EOrder   OrderEvent
  deriving (Generic, Atomable, Eq, Show)

data ItemEvent
  = ItemCreated
      { ieItemId      :: ItemId
      , ieName        :: Text
      , ieDescription :: Text
      }
  | ItemUpdated
      { ieItemId      :: ItemId
      , ieOldName     :: Text      -- always store previous value
      , ieNewName     :: Text
      }
  | ItemDeleted
      { ieItemId :: ItemId }
  deriving (Generic, Atomable, Eq, Show)
```

**Rule: Revision events must include the previous value.** This enables audit trails and undo without replaying the entire event stream.

### Event Store Relvar

```
-- TutorialD (M36's query language)
domain_events : relation {
  event_id    EventId,
  aggregate_id AggregateId,   -- groups related events (e.g., all events for one item)
  event       DomainEvent,    -- the ADT, stored directly
  occurred_at UTCTime
} key {event_id}
```

```haskell
data EventRecord = EventRecord
  { erEventId     :: EventId
  , erAggregateId :: AggregateId
  , erEvent       :: DomainEvent
  , erOccurredAt  :: UTCTime
  } deriving (Generic, Atomable, Eq, Show)
```

### Projection Relvars

Projections represent the current state derived from events. They exist for query performance.

```haskell
-- Current state of items (derived from ItemCreated/ItemUpdated/ItemDeleted events)
data ItemProjection = ItemProjection
  { ipItemId      :: ItemId
  , ipName        :: Text
  , ipDescription :: Text
  , ipIsDeleted   :: Bool        -- soft delete via event
  , ipCreatedAt   :: UTCTime
  , ipUpdatedAt   :: UTCTime
  } deriving (Generic, Atomable, Eq, Show)
```

### Transaction Pattern

**Critical rule: Event insertion and projection update must happen in the same M36 transaction.**

```haskell
createItemTx :: ItemId -> Text -> Text -> UTCTime -> DatabaseContextExpr
createItemTx iid name desc now = MultipleExpr
  [ -- 1. Append event (never modify existing events)
    Insert "domain_events" $ ExistingRelation $ mkRelationFromList eventAttrs
      [[ eventIdAtom (EventId newUUID)
       , aggregateIdAtom (AggregateId (unItemId iid))
       , domainEventAtom (EItem (ItemCreated iid name desc))
       , utcTimeAtom now
       ]]
  , -- 2. Update projection (upsert = delete + insert)
    Insert "items" $ ExistingRelation $ mkRelationFromList itemAttrs
      [[ itemIdAtom iid
       , textAtom name
       , textAtom desc
       , boolAtom False
       , utcTimeAtom now
       , utcTimeAtom now
       ]]
  ]

-- Update: delete old projection row, insert new one, append event
updateItemTx :: ItemId -> Text -> Text -> Text -> UTCTime -> DatabaseContextExpr
updateItemTx iid oldName newName desc now = MultipleExpr
  [ Insert "domain_events" $ ...  -- EvItemUpdated with old and new
  , Delete "items" (restrictEq "item_id" iid)
  , Insert "items" $ ...           -- updated projection
  ]
```

### Projection Rebuilding

Always provide a rebuild function for disaster recovery:

```haskell
-- Rebuild all projections for an aggregate from its event stream
rebuildProjection :: AggregateId -> DatabaseContextExpr
rebuildProjection aid =
  -- 1. Query domain_events WHERE aggregate_id = aid ORDER BY occurred_at
  -- 2. Fold events into current state
  -- 3. Delete existing projection rows for this aggregate
  -- 4. Insert rebuilt state
```

### M36 Transaction Graph ≠ Event Sourcing

M36's commit-based history tracks DATABASE STATE snapshots (like git commits). Event sourcing tracks DOMAIN EVENTS (what happened and why). They are complementary:

- M36 transaction graph: "At commit 42, the database looked like this"
- Domain events: "User revised their answer from A to B because..."

**Always model domain events explicitly. Do not rely on M36's transaction graph as a substitute.**

---

## 4. servant-elm Code Generation

### Setup

```haskell
-- backend/codegen/Main.hs
module Main where

import Servant.Elm
  ( defElmImports
  , defElmOptions
  , generateElmModuleWith
  )
import MyApp.Api (MyAppAPI)
import Data.Proxy (Proxy(..))

main :: IO ()
main = generateElmModuleWith
  defElmOptions
  ["Api", "Generated"]           -- Elm module name: Api.Generated
  defElmImports
  "frontend/src"                  -- output directory
  (Proxy :: Proxy MyAppAPI)
```

### What Gets Generated

servant-elm produces an Elm module containing:

1. **Type definitions** matching all Haskell request/response types
2. **JSON decoders** for all response types
3. **JSON encoders** for all request types
4. **HTTP request functions** for every API endpoint

```elm
-- frontend/src/Api/Generated.elm (AUTO-GENERATED — DO NOT EDIT)

module Api.Generated exposing (..)

type alias Item =
    { itemId : String
    , itemName : String
    , itemDescription : String
    , itemCreatedAt : String
    }

type alias CreateItemReq =
    { cirName : String
    , cirDescription : String
    }

getApiItems : Cmd (Result Http.Error (List Item))
getApiItems = ...

postApiItems : CreateItemReq -> Cmd (Result Http.Error String)
postApiItems body = ...
```

### Rules

| Rule | Why |
|------|-----|
| **Never hand-edit `Api/Generated.elm`** | It will be overwritten on next codegen run |
| **Run `cabal run codegen` after ANY Haskell API type change** | Keeps Elm client in sync |
| **CI must verify no diff after codegen** | Catches forgotten regeneration |
| **Wrap generated types in `Domain/` modules** | Add app-specific helpers, defaults, conversions |

### Build Integration

```bash
# Regenerate + verify Elm compiles
nix run .#codegen
cd frontend && elm make src/Main.elm --output=/dev/null

# CI: nix flake check runs checks.codegen-consistent automatically
nix flake check
```

### Domain Wrapper Pattern

Don't use generated types directly in page modules. Wrap them:

```elm
-- frontend/src/Domain/Item.elm
module Domain.Item exposing (Item, fromApi, itemName)

import Api.Generated as Api

type alias Item =
    { id : String
    , name : String
    , description : String
    }

-- Convert from generated API type to domain type
fromApi : Api.Item -> Item
fromApi apiItem =
    { id = apiItem.itemId
    , name = apiItem.itemName
    , description = apiItem.itemDescription
    }

-- Domain-specific helpers that don't belong in generated code
itemName : Item -> String
itemName item =
    if String.isEmpty item.name then "(untitled)" else item.name
```

---

## 5. Elm Frontend

### Application Structure

Always use `Browser.application` for SPA routing:

```elm
main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }
```

### Routing

```elm
module Route exposing (Route(..), fromUrl, toPath)

import Url.Parser exposing (Parser, (</>), map, oneOf, s, string, top)

type Route
    = Home
    | ItemList
    | ItemDetail String
    | NotFound

routeParser : Parser (Route -> a) a
routeParser =
    oneOf
        [ map Home top
        , map ItemList (s "items")
        , map ItemDetail (s "items" </> string)
        ]

fromUrl : Url -> Route
fromUrl url =
    Url.Parser.parse routeParser url
        |> Maybe.withDefault NotFound

toPath : Route -> String
toPath route =
    case route of
        Home -> "/"
        ItemList -> "/items"
        ItemDetail id -> "/items/" ++ id
        NotFound -> "/404"
```

### Module Structure

```
frontend/src/
├── Main.elm                    -- Browser.application entry point
├── Route.elm                   -- URL type + parser
├── Flags.elm                   -- Init flags from JavaScript
│
├── Page/                       -- Each page is an independent TEA module
│   ├── Home.elm                --   init, update, view, Model, Msg
│   ├── ItemList.elm
│   └── ItemDetail.elm
│
├── UI/                         -- Shared elm-ui components
│   ├── Theme.elm               -- Colors, fonts, spacing constants
│   ├── Button.elm              -- Button variants
│   ├── Card.elm
│   ├── Layout.elm              -- Page shells, navigation
│   └── MediaQuery.elm          -- elm-css escape hatches (print, dark mode)
│
├── Domain/                     -- Wrappers around generated API types
│   └── Item.elm
│
├── Api/
│   └── Generated.elm           -- servant-elm output (DO NOT EDIT)
│
└── Ports.elm                   -- JavaScript interop
```

### Page Module Pattern

Each page exports a consistent interface:

```elm
module Page.ItemList exposing (Model, Msg, init, update, view, subscriptions)

import Element exposing (..)
import UI.Theme as Theme

type alias Model =
    { items : List Item
    , loading : Bool
    , error : Maybe String
    }

type Msg
    = GotItems (Result Http.Error (List Api.Item))
    | ItemClicked String

init : ( Model, Cmd Msg )
init =
    ( { items = [], loading = True, error = Nothing }
    , Api.Generated.getApiItems |> Cmd.map GotItems  -- generated function
    )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model = ...

view : Model -> Element Msg
view model = ...   -- returns Element, not Html

subscriptions : Model -> Sub Msg
subscriptions _ = Sub.none
```

---

## 6. elm-ui Styling

### Core Rules

```elm
-- ✅ ALWAYS: Use elm-ui for layout and styling
view model =
    column [ spacing 24, padding 24, width fill ]
        [ el [ Region.heading 1, Font.size 24, Font.bold ]
            (text "Items")
        , itemList model.items
        ]

-- ❌ NEVER: Tailwind class strings
view model =
    div [ class "flex flex-col gap-6 p-6" ] [ ... ]

-- ❌ NEVER: Inline style strings
view model =
    div [ style "display" "flex" ] [ ... ]
```

### Theme Module

Centralize all design tokens:

```elm
module UI.Theme exposing (..)

import Element exposing (Color, rgb255)
import Element.Font as Font

-- Colors
primary : Color
primary = rgb255 59 130 246

primaryHover : Color
primaryHover = rgb255 37 99 235

danger : Color
danger = rgb255 239 68 68

textPrimary : Color
textPrimary = rgb255 17 24 39

textSecondary : Color
textSecondary = rgb255 107 114 128

bgPage : Color
bgPage = rgb255 255 255 255

bgCard : Color
bgCard = rgb255 249 250 251

-- Spacing scale (multiples of 4)
spaceXs : Int
spaceXs = 4

spaceSm : Int
spaceSm = 8

spaceMd : Int
spaceMd = 16

spaceLg : Int
spaceLg = 24

spaceXl : Int
spaceXl = 32

-- Font
bodyFont : Font.Font
bodyFont = Font.typeface "system-ui"

headingFont : Font.Font
headingFont = Font.typeface "system-ui"
```

### Responsive Design

elm-ui does responsive via `classifyDevice`:

```elm
import Element exposing (Device, DeviceClass(..), classifyDevice)

view : { width : Int, height : Int } -> Model -> Element Msg
view windowSize model =
    let
        device = classifyDevice windowSize
    in
    case device.class of
        Phone ->
            column [ width fill, padding spaceMd ] [ pageContent model ]

        Tablet ->
            column [ width (maximum 600 fill), centerX, padding spaceLg ] [ pageContent model ]

        _ ->
            column [ width (maximum 800 fill), centerX, padding spaceXl ] [ pageContent model ]
```

### Reusable Components

Build components as functions returning `Element msg`:

```elm
module UI.Button exposing (primary, secondary, danger)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import UI.Theme as Theme

primary : { onPress : Maybe msg, label : String } -> Element msg
primary { onPress, label } =
    Input.button
        [ Background.color Theme.primary
        , Font.color (rgb255 255 255 255)
        , Border.rounded 8
        , paddingXY 16 10
        , Font.size 14
        , Font.semiBold
        , pointer
        , mouseOver [ Background.color Theme.primaryHover ]
        ]
        { onPress = onPress
        , label = text label
        }

secondary : { onPress : Maybe msg, label : String } -> Element msg
secondary { onPress, label } =
    Input.button
        [ Border.width 1
        , Border.color Theme.primary
        , Border.rounded 8
        , Font.color Theme.primary
        , paddingXY 16 10
        , Font.size 14
        ]
        { onPress = onPress
        , label = text label
        }
```

### When to Use elm-css (Escape Hatches)

elm-ui cannot express CSS media queries, keyframe animations, or pseudo-elements. For these cases ONLY, use elm-css:

```elm
module UI.MediaQuery exposing (printHidden, darkModeAware, reducedMotion)

import Css
import Css.Media
import Html.Styled
import Html.Styled.Attributes exposing (css)

-- Hide elements when printing
printHidden : Html.Styled.Attribute msg
printHidden =
    css
        [ Css.Media.withMedia [ Css.Media.print ]
            [ Css.display Css.none ]
        ]

-- Dark mode color override
darkModeColors : Html.Styled.Attribute msg
darkModeColors =
    css
        [ Css.Media.withMedia
            [ Css.Media.all
                [ Css.Media.prefersColorScheme Css.Media.dark ]
            ]
            [ Css.backgroundColor (Css.hex "1a1a2e")
            , Css.color (Css.hex "e0e0e0")
            ]
        ]

-- Respect reduced motion preference
reducedMotion : Html.Styled.Attribute msg
reducedMotion =
    css
        [ Css.Media.withMedia
            [ Css.Media.all
                [ Css.Media.prefersReducedMotion ]
            ]
            [ Css.property "animation" "none"
            , Css.property "transition" "none"
            ]
        ]
```

**Restriction: elm-css is ONLY for these four cases:**
1. `@media print`
2. `prefers-color-scheme`
3. `@keyframes` / `transition` / `animation`
4. `prefers-reduced-motion`

All other styling uses elm-ui.

### Mixing elm-ui and elm-css

When you need elm-css attributes on an elm-ui element, use `Element.htmlAttribute`:

```elm
import Element
import Html.Styled.Attributes

viewPrintableCard : Item -> Element msg
viewPrintableCard item =
    el
        [ -- elm-ui styling
          padding 16
        , Border.rounded 8
        , Background.color Theme.bgCard
          -- elm-css escape hatch
        , Element.htmlAttribute (Html.Styled.Attributes.css [ ... ])
        ]
        (text item.name)
```

---

## 7. Ports (JavaScript Interop)

### Pattern

```elm
-- src/Ports.elm
port module Ports exposing (..)

-- Outgoing (Elm → JS)
port saveToLocalStorage : { key : String, value : String } -> Cmd msg
port copyToClipboard : String -> Cmd msg
port shareViaWebShare : { title : String, url : String } -> Cmd msg

-- Incoming (JS → Elm)
port onLocalStorageLoaded : ({ key : String, value : String } -> msg) -> Sub msg
port onClipboardResult : (Bool -> msg) -> Sub msg
port onWindowResize : ({ width : Int, height : Int } -> msg) -> Sub msg
port onDarkModeChange : (Bool -> msg) -> Sub msg
```

```javascript
// index.html / main.js
const app = Elm.Main.init({ flags: { ... } });

app.ports.saveToLocalStorage.subscribe(({ key, value }) => {
  localStorage.setItem(key, value);
});

app.ports.copyToClipboard.subscribe((text) => {
  navigator.clipboard.writeText(text).then(
    () => app.ports.onClipboardResult.send(true),
    () => app.ports.onClipboardResult.send(false)
  );
});

// Dark mode detection
const mq = window.matchMedia('(prefers-color-scheme: dark)');
app.ports.onDarkModeChange.send(mq.matches);
mq.addEventListener('change', (e) => app.ports.onDarkModeChange.send(e.matches));

// Window resize for elm-ui classifyDevice
app.ports.onWindowResize.send({ width: window.innerWidth, height: window.innerHeight });
window.addEventListener('resize', () => {
  app.ports.onWindowResize.send({ width: window.innerWidth, height: window.innerHeight });
});
```

### Rules

- Ports are the ONLY way to interact with JavaScript. Never use `Html.Events.on` with `Json.Decode.value` hacks.
- Every outgoing port that expects a result must have a corresponding incoming port.
- Port names use camelCase matching Elm conventions.

---

## 8. Build System (haskell-flake + flake-parts)

### flake.nix

```nix
{
  description = "HFMPSE full-stack application";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
    project-m36-src = {
      url = "github:agentm/project-m36/<commit>";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      imports = [ inputs.haskell-flake.flakeModule ];

      perSystem = { self', pkgs, lib, system, ... }: {

        # ── Haskell ──────────────────────────────────────
        haskellProjects.default = {
          projectRoot = ./backend;
          settings = {
            project-m36-base.source = inputs.project-m36-src;
            # project-m36-base.jailbreak = true;  # if needed
          };
          devShell = {
            tools = hp: {
              inherit (hp) cabal-install haskell-language-server fourmolu;
            };
            mkShellArgs.buildInputs = with pkgs; [
              elmPackages.elm elmPackages.elm-format elmPackages.elm-test
              just
            ];
          };
        };

        # ── Elm ──────────────────────────────────────────
        packages.frontend = pkgs.stdenv.mkDerivation {
          pname = "myapp-frontend";
          version = "0.1.0";
          src = ./frontend;
          nativeBuildInputs = [ pkgs.elmPackages.elm ];
          buildPhase = ''
            export HOME=$TMPDIR
            elm make src/Main.elm --optimize --output=main.js
          '';
          installPhase = ''
            mkdir -p $out
            cp main.js $out/
            cp index.html $out/ 2>/dev/null || true
          '';
        };

        # ── servant-elm codegen ──────────────────────────
        # Exposed as: nix run .#codegen
        apps.codegen = {
          type = "app";
          program = "${self'.packages.default}/bin/myapp-codegen";
        };

        # ── Combined package (build output contract) ─────
        # Contains: bin/myapp-server + static/
        packages.myapp = pkgs.symlinkJoin {
          name = "myapp";
          paths = [ self'.packages.default ];
          postBuild = ''
            mkdir -p $out/static
            cp ${self'.packages.frontend}/* $out/static/
          '';
        };

        # ── CI: codegen consistency ──────────────────────
        checks.codegen-consistent = pkgs.runCommand "codegen-check" {
          nativeBuildInputs = [ self'.packages.default pkgs.diffutils ];
        } ''
          cp -r ${./frontend/src/Api} $TMPDIR/before
          myapp-codegen --output-dir $TMPDIR/generated
          diff -r $TMPDIR/before $TMPDIR/generated/Api || {
            echo "ERROR: Generated.elm is out of date. Run: nix run .#codegen"
            exit 1
          }
          touch $out
        '';
      };
    };
}
```

### cabal Structure

The `.cabal` file must define three targets sharing a common library:

```cabal
cabal-version: 3.0
name:          myapp
version:       0.1.0

-- Shared types: Api, Domain, Effects (imported by both server and codegen)
library
  exposed-modules:
    MyApp.Api
    MyApp.Api.Types
    MyApp.Domain.Types
    MyApp.Domain.Events
    -- all modules needed by both server and codegen
  build-depends:
    , base, servant, polysemy, project-m36-base
    , aeson, text, uuid, time, servant-elm
  default-language: GHC2021

-- Warp server (the deployable binary)
executable myapp-server
  main-is:       Main.hs
  hs-source-dirs: app
  build-depends:  base, myapp, servant-server, warp, polysemy
  default-language: GHC2021

-- servant-elm code generator
executable myapp-codegen
  main-is:       Main.hs
  hs-source-dirs: codegen
  build-depends:  base, myapp, servant-elm, servant
  default-language: GHC2021
```

The **library** is the critical piece — it contains the Servant API type and all request/response types. Both `myapp-server` and `myapp-codegen` depend on it, guaranteeing they reference the same types.

### haskell-flake with Project:M36

If M36 is not on Hackage or needs a pinned version, add it as a non-flake input and reference it in `settings`:

```nix
# In flake inputs:
project-m36-src = { url = "github:agentm/project-m36/<commit>"; flake = false; };

# In haskellProjects.default.settings:
project-m36-base.source = inputs.project-m36-src;
```

### devShell

haskell-flake auto-generates a devShell with GHC, cabal, and HLS. The `mkShellArgs.buildInputs` extension adds Elm tools. `nix develop` gives you everything needed for both Haskell and Elm development.

### Build Commands (justfile)

```just
dev:       nix develop
build:     nix build .#myapp
codegen:   nix run .#codegen && cd frontend && elm make src/Main.elm --output=/dev/null
test:      cd backend && cabal test && cd ../frontend && elm-test
check:     nix flake check
run:       cd backend && cabal run myapp-server
```

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
