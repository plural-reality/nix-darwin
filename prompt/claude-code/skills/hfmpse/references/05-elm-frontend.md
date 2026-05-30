# 5. Elm Frontend

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

