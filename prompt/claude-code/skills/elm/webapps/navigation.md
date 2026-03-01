
---- https://guide.elm-lang.org/webapps/navigation ----
Navigation
We just saw how to serve one page, but say we are making a website like package.elm-lang.org
. It has a bunch of pages (e.g. search, README, docs) that all work differently. How does it do that?
Multiple Pages
The simple way would be to serve a bunch of different HTML files. Going to the home page? Load new HTML. Going to elm/core
docs? Load new HTML. Going to elm/json
docs? Load new HTML.
Until Elm 0.19, that is exactly what the package website did! It works. It is simple. But it has some weaknesses:
- Blank Screens. The screen goes white every time you load new HTML. Can we do a nice transition instead?
- Redundant Requests. Each package has a single
docs.json
file, but it gets loaded each time you visit a module likeString
orMaybe
. Can we share the data between pages somehow? - Redundant Code. The home page and the docs share a lot of functions, like
Html.text
andHtml.div
. Can this code be shared between pages?
We can improve all three cases! The basic idea is to only load HTML once, and then be a bit tricky to handle URL changes.
Single Page
Instead of creating our program with Browser.element
or Browser.document
, we can create a Browser.application
to avoid loading new HTML when the URL changes:
application :
{ init : flags -> Url -> Key -> ( model, Cmd msg )
, view : model -> Document msg
, update : msg -> model -> ( model, Cmd msg )
, subscriptions : model -> Sub msg
, onUrlRequest : UrlRequest -> msg
, onUrlChange : Url -> msg
}
-> Program flags model msg
It extends the functionality of Browser.document
in three important scenarios.
When the application starts, init
gets the current Url
from the browsers navigation bar. This allows you to show different things depending on the Url
.
When someone clicks a link, like <a href="/home">Home</a>
, it is intercepted as a UrlRequest
. So instead of loading new HTML with all the downsides, onUrlRequest
creates a message for your update
where you can decide exactly what to do next. You can save scroll position, persist data, change the URL yourself, etc.
When the URL changes, the new Url
is sent to onUrlChange
.
The resulting message goes to update
where you can decide how to show the new page.
So rather than loading new HTML, these three additions give you full control over URL changes. Let’s see it in action!
Example
We will start with the baseline Browser.application
program. It just keeps track of the current URL. Skim through the code now! Pretty much all of the new and interesting stuff happens in the update
function, and we will get into those details after the code:
import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Url
-- MAIN
main : Program () Model Msg
main =
Browser.application
{ init = init
, view = view
, update = update
, subscriptions = subscriptions
, onUrlChange = UrlChanged
, onUrlRequest = LinkClicked
}
-- MODEL
type alias Model =
{ key : Nav.Key
, url : Url.Url
}
init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
( Model key url, Cmd.none )
-- UPDATE
type Msg
= LinkClicked Browser.UrlRequest
| UrlChanged Url.Url
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
case msg of
LinkClicked urlRequest ->
case urlRequest of
Browser.Internal url ->
( model, Nav.pushUrl model.key (Url.toString url) )
Browser.External href ->
( model, Nav.load href )
UrlChanged url ->
( { model | url = url }
, Cmd.none
)
-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions _ =
Sub.none
-- VIEW
view : Model -> Browser.Document Msg
view model =
{ title = "URL Interceptor"
, body =
[ text "The current URL is: "
, b [] [ text (Url.toString model.url) ]
, ul []
[ viewLink "/home"
, viewLink "/profile"
, viewLink "/reviews/the-century-of-the-self"
, viewLink "/reviews/public-opinion"
, viewLink "/reviews/shah-of-shahs"
]
]
}
viewLink : String -> Html msg
viewLink path =
li [] [ a [ href path ] [ text path ] ]
The update
function can handle either LinkClicked
or UrlChanged
messages. There is a lot of new stuff in the LinkClicked
branch, so we will focus on that first!
UrlRequest
Whenever someone clicks a link like <a href="/home">/home</a>
, it produces a UrlRequest
value:
type UrlRequest
= Internal Url.Url
| External String
The Internal
variant is for any link that stays on the same domain. So if you are browsing https://example.com
, internal links include things like settings#privacy
, /home
, https://example.com/home
, and //example.com/home
.
The External
variant is for any link that goes to a different domain. Links like https://elm-lang.org/examples
, https://static.example.com
, and http://example.com/home
all go to a different domain. Notice that changing the protocol from https
to http
is considered a different domain!
Whichever link someone presses, our example program is going to create a LinkClicked
message and send it to the update
function. That is where we see most of the interesting new code!
LinkClicked
Most of our update
logic is deciding what to do with these UrlRequest
values:
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
case msg of
LinkClicked urlRequest ->
case urlRequest of
Browser.Internal url ->
( model, Nav.pushUrl model.key (Url.toString url) )
Browser.External href ->
( model, Nav.load href )
UrlChanged url ->
( { model | url = url }
, Cmd.none
)
The particularly interesting functions are Nav.load
and Nav.pushUrl
. These are both from the Browser.Navigation
module which is all about changing the URL in different ways. We are using the two most common functions from that module:
load
loads all new HTML. It is equivalent to typing the URL into the URL bar and pressing enter. So whatever is happening in yourModel
will be thrown out, and a whole new page is loaded.pushUrl
changes the URL, but does not load new HTML. Instead it triggers aUrlChanged
message that we handle ourselves! It also adds an entry to the “browser history” so things work normal when people press theBACK
orFORWARD
buttons.
So looking back at the update
function, we can understand how it all fits together a bit better now. When the user clicks a https://elm-lang.org
link, we get an External
message and use load
to load new HTML from those servers. But when the user clicks a /home
link, we get an Internal
message and use pushUrl
to change the URL without loading new HTML!
Note 1: Both
Internal
andExternal
links are producing commands immediately in our example, but that is not required! When someone clicks anExternal
link, maybe you want to save textbox content to your database before navigating away. Or when someone clicks anInternal
link, maybe you want to usegetViewport
to save the scroll position in case they navigateBACK
later. That is all possible! It is a normalupdate
function, and you can delay the navigation and do whatever you want.Note 2: If you want to restore “what they were looking at” when they come
BACK
, scroll position is not perfect. If they resize their browser or reorient their device, it could be off by quite a lot! So it is probably better to save “what they were looking at” instead. Maybe that means usinggetViewportOf
to figure out exactly what is on screen at the moment. The particulars depend on how your application works exactly, so I cannot give exact advice!
UrlChanged
There are a couple ways to get UrlChanged
messages. We just saw that pushUrl
produces them, but pressing the browser BACK
and FORWARD
buttons produce them as well. And like I was saying in the notes a second ago, when you get a LinkClicked
message, the pushUrl
command may not be given immediately.
So the nice thing about having a separate UrlChanged
message is that it does not matter how or when the URL changed. All you need to know is that it did!
We are just storing the new URL in our example here, but in a real web app, you need to parse the URL to figure out what content to show. That is what the next page is all about!
Note: I skipped talking about
Nav.Key
to try to focus on more important concepts. But I will explain here for those who are interested!A navigation
Key
is needed to create navigation commands (likepushUrl
) that change the URL. You only get access to aKey
when you create your program withBrowser.application
, guaranteeing that your program is equipped to detect these URL changes. IfKey
values were available in other kinds of programs, unsuspecting programmers would be sure to run into some annoying bugs and learn a bunch of techniques the hard way!As a result of all that, we have a line in our
Model
for ourKey
. A relatively low price to pay to help everyone avoid an extremely subtle category of problems!

