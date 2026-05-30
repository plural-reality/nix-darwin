# 2. Polysemy Effects

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

