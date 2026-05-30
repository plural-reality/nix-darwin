# 6. elm-ui Styling

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

