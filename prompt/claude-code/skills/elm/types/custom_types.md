
---- https://guide.elm-lang.org/types/custom_types ----
Note: Custom types used to be referred to as “union types” in Elm. Names from other communities include tagged unions and ADTs.
Custom Types
So far we have seen a bunch of types like Bool
, Int
, and String
. But how do we define our own?
Say we are making a chat room. Everyone needs a name, but maybe some users do not have a permanent account. They just give a name each time they show up.
We can describe this situation by defining a UserStatus
type, listing all the possible variations:
type UserStatus = Regular | Visitor
The UserStatus
type has two variants. Someone can be a Regular
or a Visitor
. So we could represent a user as a record like this:
type UserStatus
= Regular
| Visitor
type alias User =
{ status : UserStatus
, name : String
}
thomas = { status = Regular, name = "Thomas" }
kate95 = { status = Visitor, name = "kate95" }
So now we can track if someone is a Regular
with an account or a Visitor
who is just passing through. It is not too tough, but we can make it simpler!
Rather than creating a custom type and a type alias, we can represent all this with just a single custom type. The Regular
and Visitor
variants each have an associated data. In our case, the associated data is a String
value:
type User
= Regular String
| Visitor String
thomas = Regular "Thomas"
kate95 = Visitor "kate95"
The data is attached directly to the variant, so there is no need for the record anymore.
Another benefit of this approach is that each variant can have different associated data. Say that Regular
users gave their age when they signed up. There is no nice way to capture that with records, but when you define your own custom type it is no problem. Let's add some associated data to the Regular
variant in an interactive example:
Try defining a Regular
visitor with a name and age ⬆️
We only added an age, but variants of a type can diverge quite dramatically. For example, maybe we want to add location for Regular
users so we can suggest regional chat rooms. Add more associated data! Or maybe we want to have anonymous users. Add a third variant called Anonymous
. Maybe we end up with:
type User
= Regular String Int Location
| Visitor String
| Anonymous
No problem! Let’s see some other examples now.
Messages
In the architecture section, we saw a couple of examples of defining a Msg
type. This sort of type is extremely common in Elm. In our chat room, we might define a Msg
type like this:
type Msg
= PressedEnter
| ChangedDraft String
| ReceivedMessage { user : User, message : String }
| ClickedExit
We have four variants. Some variants have no associated data, others have a bunch. Notice that ReceivedMessage
actually has a record as associated data. That is totally fine. Any type can be associated data! This allows you to describe interactions in your application very precisely.
Modeling
Custom types become extremely powerful when you start modeling situations very precisely. For example, if you are waiting for some data to load, you might want to model it with a custom type like this:
type Profile
= Failure
| Loading
| Success { name : String, description : String }
So you can start in the Loading
state and then transition to Failure
or Success
depending on what happens. This makes it really simple to write a view
function that always shows something reasonable when data is loading.
Now we know how to create custom types, the next section will show how to use them!
Note: Custom types are the most important feature in Elm. They have a lot of depth, especially once you get in the habit of trying to model scenarios more precisely. I tried to share some of this depth in Types as Sets and Types as Bits in the appendix. I hope you find them helpful!

