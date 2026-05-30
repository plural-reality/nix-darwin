# 3. Project:M36 Schema Design

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

