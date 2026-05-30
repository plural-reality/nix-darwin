# 4. servant-elm Code Generation

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

