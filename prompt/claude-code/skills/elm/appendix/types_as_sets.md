
---- https://guide.elm-lang.org/appendix/types_as_sets ----
Types as Sets
We have seen primitive types like Bool
and String
. We have made our own custom types like this:
type Color = Red | Yellow | Green
One of the most important techniques in Elm programming is to make the possible values in code exactly match the valid values in real life. This leaves no room for invalid data, and this is why I always encourage folks to focus on custom types and data structures.
In pursuit of this goal, I have found it helpful to understand the relationship between types and sets. It sounds like a stretch, but it really helps develop your mindset!
Sets
You can think of types as a set of values.
Bool
is the set{ True, False }
Color
is the set{ Red, Yellow, Green }
Int
is the set{ ... -2, -1, 0, 1, 2 ... }
Float
is the set{ ... 0.9, 0.99, 0.999 ... 1.0 ... }
String
is the set{ "", "a", "aa", "aaa" ... "hello" ... }
So when you say x : Bool
it is like saying x
is in the { True, False }
set.
Cardinality
Some interesting things happen when you start figuring out how many values are in these sets. For example the Bool
set { True, False }
contains two values. So math people would say that Bool
has a cardinality of two. So conceptually:
- cardinality(
Bool
) = 2 - cardinality(
Color
) = 3 - cardinality(
Int
) = ∞ - cardinality(
Float
) = ∞ - cardinality(
String
) = ∞
This gets more interesting when we start thinking about types like (Bool, Bool)
that combine sets together.
Note: The cardinality for
Int
andFloat
are actually smaller than infinity. Computers need to fit the numbers into a fixed amount of bits (as described here) so it is more like cardinality(Int32
) = 2^32 and cardinality(Float32
) = 2^32. The point is just that it is a lot.
Multiplication (Tuples and Records)
When you combine types with tuples, the cardinalities get multiplied:
- cardinality(
(Bool, Bool)
) = cardinality(Bool
) × cardinality(Bool
) = 2 × 2 = 4 - cardinality(
(Bool, Color)
) = cardinality(Bool
) × cardinality(Color
) = 2 × 3 = 6
To make sure you believe this, try listing all the possible values of (Bool, Bool)
and (Bool, Color)
. Do they match the numbers we predicted? How about for (Color, Color)
?
But what happens when we use infinite sets like Int
and String
?
- cardinality(
(Bool, String)
) = 2 × ∞ - cardinality(
(Int, Int)
) = ∞ × ∞
I personally really like the idea of having two infinities. One wasn’t enough? And then seeing infinite infinities. Aren’t we going to run out at some point?
Note: So far we have used tuples, but records work exactly the same way:
- cardinality(
(Bool, Bool)
) = cardinality({ x : Bool, y : Bool }
)- cardinality(
(Bool, Color)
) = cardinality({ active : Bool, color : Color }
)And if you define
type Point = Point Float Float
then cardinality(Point
) is equivalent to cardinality((Float, Float)
). It is all multiplication!
Addition (Custom Types)
When figuring out the cardinality of a custom type, you add together the cardinality of each variant. Let’s start by looking at some Maybe
and Result
types:
- cardinality(
Result Bool Color
) = cardinality(Bool
) + cardinality(Color
) = 2 + 3 = 5 - cardinality(
Maybe Bool
) = 1 + cardinality(Bool
) = 1 + 2 = 3 - cardinality(
Maybe Int
) = 1 + cardinality(Int
) = 1 + ∞
To persuade yourself that this is true, try listing out all the possible values in the Maybe Bool
and Result Bool Color
sets. Does it match the numbers we got?
Here are some other examples:
type Height
= Inches Int
| Meters Float
-- cardinality(Height)
-- = cardinality(Int) + cardinality(Float)
-- = ∞ + ∞
type Location
= Nowhere
| Somewhere Float Float
-- cardinality(Location)
-- = 1 + cardinality((Float, Float))
-- = 1 + cardinality(Float) × cardinality(Float)
-- = 1 + ∞ × ∞
Looking at custom types this way helps us see when two types are equivalent. For example, Location
is equivalent to Maybe (Float, Float)
. Once you know that, which one should you use? I prefer Location
for two reasons:
- The code becomes more self-documenting. No need to wonder if
Just (1.6, 1.8)
is a location or a pair of heights. - The
Maybe
module may expose functions that do not make sense for my particular data. For example, combining two locations probably should not work likeMaybe.map2
. Should oneNowhere
mean that everything isNowhere
? Seems weird!
In other words, I write a couple lines of code that are similar to other code, but it gives me a level of clarity and control that is extremely valuable for large code bases and teams.
Who Cares?
Thinking of “types as sets” helps explain an important class of bugs: invalid data. For example, say we want to represent the color of a traffic light. The set of valid values are { red, yellow, green } but how do we represent that in code? Here are three different approaches:
type alias Color = String
— We could decide that"red"
,"yellow"
,"green"
are the three strings we will use, and that all the other ones are invalid data. But what happens if invalid data is produced? Maybe someone makes a typo like"rad"
. Maybe someone types"RED"
instead. Should all functions have checks for incoming color arguments? Should all functions have tests to make sure color results are valid? The root issue is that cardinality(Color
) = ∞, meaning there are (∞ - 3) invalid values. We will need to do a lot of checking to make sure none of them ever show up!type alias Color = { red : Bool, yellow : Bool, green : Bool }
— The idea here is that the idea of “red” is represented byColor True False False
. But what aboutColor True True True
? What does it mean for it to be all the colors at once? This is invalid data. Just like with theString
representation, we end up writing checks in our code and tests to make sure there are no mistakes. In this case, cardinality(Color
) = 2 × 2 × 2 = 8, so there are only 5 invalid values. There are definitely fewer ways to mess up, but we should still have some checks and tests.type Color = Red | Yellow | Green
— In this case, invalid data is impossible. cardinality(Color
) = 1 + 1 + 1 = 3, exactly corresponding to the set of three values in real life. So there is no point checking for invalid color data in our code or tests. It cannot exist!
So the whole point here is that ruling out invalid data makes your code shorter, simpler, and more reliable. By making sure the set of possible values in code exactly matches the set of valid values in real life, many problems just go away. This is a sharp knife!
As your program changes, the set of possible values in code may start to diverge from the set of valid values in real life. I highly recommend revisiting your types periodically to make them match again. This is like noticing your knife has become dull and sharpening it with a whetstone. This kind of maintenance is a core part of programming in Elm.
When you start thinking this way, you end up needing fewer tests, yet having more reliable code. You start using fewer dependencies, yet accomplishing things more quickly. Similarly, someone skilled with a knife probably will not buy a SlapChop. There is definitely a place for blenders and food processors, but it is smaller than you might think. No one runs ads about how you can be independent and self-sufficient without any serious downsides. No money in that!
Aside on Language Design
Thinking of types as sets like this can also be helpful in explaining why a language would feel “easy” or “restrictive” or “error-prone” to some people. For example:
Java — There are primitive values like
Bool
andString
. From there, you can create classes with a fixed set of fields of different types. This is much like records in Elm, allowing you to multiply cardinalities. But it is quite difficult to do addition. You can do it with subtyping, but it is quite an elaborate process. So whereResult Bool Color
is easy in Elm, it is pretty tough in Java. I think some people find Java “restrictive” because designing a type with cardinality 5 is quite difficult, often seeming like it is not worth the trouble.JavaScript — Again, there are primitive values like
Bool
andString
. From there you can create objects with a dynamic set of fields, allowing you to multiply cardinalities. This is much more lightweight than creating classes. But like Java, doing addition is not particularly easy. For example, you can simulateMaybe Int
with objects like{ tag: "just", value: 42 }
and{ tag: "nothing" }
, but this is really still multiplication of cardinality. This makes it quite difficult to exactly match the set of valid values in real life. So I think people find JavaScript “easy” because designing a type with cardinality (∞ × ∞ × ∞) is super easy and that can cover pretty much anything, but other people find it “error-prone” because designing a type with cardinality 5 is not really possible, leaving lots of space for invalid data.Interestingly, some imperative languages have custom types! Rust is a great example. They call them enums to build on the intuition folks may have from C and Java. So in Rust, addition of cardinalities is just as easy as in Elm, and it brings all the same benefits!
I think the point here is that “addition” of types is extraordinarily underrated in general, and thinking of “types as sets” helps clarify why certain language designs would produce certain frustrations.

