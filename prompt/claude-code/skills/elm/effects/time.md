
---- https://guide.elm-lang.org/effects/time ----
Time
Now we are going to make a digital clock. (Analog will be an exercise!)
So far we have focused on commands. With the HTTP and randomness examples, we commanded Elm to do specific work immediately, but that is sort of a weird pattern for a clock. We always want to know the current time. This is where subscriptions come in!
Start by clicking the blue "Edit" button and looking through the code a bit in the online editor.
import Browser
import Html exposing (..)
import Task
import Time
-- MAIN
main =
Browser.element
{ init = init
, view = view
, update = update
, subscriptions = subscriptions
}
-- MODEL
type alias Model =
{ zone : Time.Zone
, time : Time.Posix
}
init : () -> (Model, Cmd Msg)
init _ =
( Model Time.utc (Time.millisToPosix 0)
, Task.perform AdjustTimeZone Time.here
)
-- UPDATE
type Msg
= Tick Time.Posix
| AdjustTimeZone Time.Zone
update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
case msg of
Tick newTime ->
( { model | time = newTime }
, Cmd.none
)
AdjustTimeZone newZone ->
( { model | zone = newZone }
, Cmd.none
)
-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model =
Time.every 1000 Tick
-- VIEW
view : Model -> Html Msg
view model =
let
hour = String.fromInt (Time.toHour model.zone model.time)
minute = String.fromInt (Time.toMinute model.zone model.time)
second = String.fromInt (Time.toSecond model.zone model.time)
in
h1 [] [ text (hour ++ ":" ++ minute ++ ":" ++ second) ]
The new stuff is all coming from the elm/time
package. Let’s go through these parts!
Time.Posix
and Time.Zone
To work with time successfully in programming, we need three different concepts:
Human Time — This is what you see on clocks (8am) or on calendars (May 3rd). Great! But if my phone call is at 8am in Boston, what time is it for my friend in Vancouver? If it is at 8am in Tokyo, is that even the same day in New York? (No!) So between time zones based on ever-changing political boundaries and inconsistent use of daylight saving time, human time should basically never be stored in your
Model
or database! It is only for display!POSIX Time — With POSIX time, it does not matter where you live or what time of year it is. It is just the number of seconds elapsed since some arbitrary moment (in 1970). Everywhere you go on Earth, POSIX time is the same.
Time Zones — A “time zone” is a bunch of data that allows you to turn POSIX time into human time. This is not just
UTC-7
orUTC+3
though! Time zones are way more complicated than a simple offset! Every time Florida switches to DST forever or Samoa switches from UTC-11 to UTC+13, some poor soul adds a note to the IANA time zone database. That database is loaded onto every computer, and between POSIX time and all the corner cases in the database, we can figure out human times!
So to show a human being a time, you must always know Time.Posix
and Time.Zone
. That is it! So all that “human time” stuff is for the view
function, not the Model
. In fact, you can see that in our view
:
view : Model -> Html Msg
view model =
let
hour = String.fromInt (Time.toHour model.zone model.time)
minute = String.fromInt (Time.toMinute model.zone model.time)
second = String.fromInt (Time.toSecond model.zone model.time)
in
h1 [] [ text (hour ++ ":" ++ minute ++ ":" ++ second) ]
The Time.toHour
function takes Time.Zone
and Time.Posix
gives us back an Int
from 0
to 23
indicating what hour it is in your time zone.
There is a lot more info about handling times in the README of elm/time
. Definitely read it before doing more with time! Especially if you are working with scheduling, calendars, etc.
subscriptions
Okay, well how should we get our Time.Posix
though? With a subscription!
subscriptions : Model -> Sub Msg
subscriptions model =
Time.every 1000 Tick
We are using the Time.every
function:
every : Float -> (Time.Posix -> msg) -> Sub msg
It takes two arguments:
- A time interval in milliseconds. We said
1000
which means every second. But we could also say60 * 1000
for every minute, or5 * 60 * 1000
for every five minutes. - A function that turns the current time into a
Msg
. So every second, the current time is going to turn into aTick <time>
for ourupdate
function.
That is the basic pattern of any subscription. You give some configuration, and you describe how to produce Msg
values. Not too bad!
Task.perform
Getting Time.Zone
is a bit trickier. Our program created a command with:
Task.perform AdjustTimeZone Time.here
Reading through the Task
docs is the best way to understand that line. The docs are written to actually explain the new concepts, and I think it would be too much of a digression to include a worse version of that info here. The point is just that we command the runtime to give us the Time.Zone
wherever the code is running.
Exercises:

