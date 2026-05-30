# 1. Servant API Definition

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

