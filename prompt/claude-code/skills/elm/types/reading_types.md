
---- https://guide.elm-lang.org/types/reading_types ----
Reading Types
In the Core Language section of this book, we went through a bunch of interactive examples to get a feeling for the language. Well, we are going to do it again, but with a new question in mind. What type of value is that?
Primitives and Lists
Let's enter some simple expressions and see what happens:
Click on this black box ⬆️ and the cursor should start blinking. Type in 3.1415
and press the ENTER key. It should print out 3.1415
followed by the type Float
.
Okay, but what is going on here exactly? Each entry shows value along with what type of value it happens to be. You can read these examples out loud like this:
- The value
"hello"
is aString
. - The value
False
is aBool
. - The value
3
is anInt
. - The value
3.1415
is aFloat
.
Elm is able to figure out the type of any value you enter! Let's see what happens with lists:
You can read these types as:
- We have a
List
filled withString
values. - We have a
List
filled withFloat
values.
The type is a rough description of the particular value we are looking at.
Functions
Let's see the type of some functions:
Try entering round
or sqrt
to see some other function types ⬆️
The String.length
function has type String -> Int
. This means it must take in a String
argument, and it will definitely return an Int
value. So let's try giving it an argument:
So we start with a String -> Int
function and give it a String
argument. This results in an Int
.
What happens when you do not give a String
though? Try entering String.length [1,2,3]
or String.length True
to see what happens ⬆️
You will find that a String -> Int
function must get a String
argument!
Note: Functions that take multiple arguments end up having more and more arrows. For example, here is a function that takes two arguments:
[ { "input": "String.repeat", "value": "\u001b[36m<function>\u001b[0m", "type_": "Int -> String -> String" } ]Giving two arguments like
String.repeat 3 "ha"
will produce"hahaha"
. It works to think of->
as a weird way to separate arguments, but I explain the real reasoning here. It is pretty neat!
Type Annotations
So far we have just let Elm figure out the types, but it also lets you write a type annotation on the line above a definition. So when you are writing code, you can say things like this:
half : Float -> Float
half n =
n / 2
-- half 256 == 128
-- half "3" -- error!
hypotenuse : Float -> Float -> Float
hypotenuse a b =
sqrt (a^2 + b^2)
-- hypotenuse 3 4 == 5
-- hypotenuse 5 12 == 13
checkPower : Int -> String
checkPower powerLevel =
if powerLevel > 9000 then "It's over 9000!!!" else "Meh"
-- checkPower 9001 == "It's over 9000!!!"
-- checkPower True -- error!
Adding type annotations is not required, but it is definitely recommended! Benefits include:
- Error Message Quality — When you add a type annotation, it tells the compiler what you are trying to do. Your implementation may have mistakes, and now the compiler can compare against your stated intent. “You said argument
powerLevel
was anInt
, but it is getting used as aString
!” - Documentation — When you revisit code later (or when a colleague visits it for the first time) it can be really helpful to see exactly what is going in and out of the function without having to read the implementation super carefully.
People can make mistakes in type annotations though, so what happens if the annotation does not match the implementation? The compiler figures out all the types on its own, and it checks that your annotation matches the real answer. In other words, the compiler will always verify that all the annotations you add are correct. So you get better error messages and documentation always stays up to date!
Type Variables
As you look through more Elm code, you will start to see type annotations with lower-case letters in them. A common example is the List.length
function:
Notice that lower-case a
in the type? That is called a type variable. It can vary depending on how List.length
is used:
We just want the length, so it does not matter what is in the list. So the type variable a
is saying that we can match any type. Let’s look at another common example:
Again, the type variable a
can vary depending on how List.reverse
is used. But in this case, we have an a
in the argument and in the result. This means that if you give a List Int
you must get a List Int
as well. Once we decide what a
is, that’s what it is everywhere.
Note: Type variables must start with a lower-case letter, but they can be full words. We could write the type of
List.length
asList value -> Int
and we could write the type ofList.reverse
asList element -> List element
. It is fine as long as they start with a lower-case letter. Type variablesa
andb
are used by convention in many places, but some type annotations benefit from more specific names.
Constrained Type Variables
There is a special variant of type variables in Elm called constrained type variables. The most common example is the number
type. The negate
function uses it:
Try expressions like negate 3.1415
and negate (round 3.1415)
and negate "hi"
⬆️
Normally type variables can get filled in with anything, but number
can only be filled in by Int
and Float
values. It constrains the possibilities.
The full list of constrained type variables is:
number
permitsInt
andFloat
appendable
permitsString
andList a
comparable
permitsInt
,Float
,Char
,String
, and lists/tuples ofcomparable
valuescompappend
permitsString
andList comparable
These constrained type variables exist to make operators like (+)
and (<)
a bit more flexible.
By now we have covered types for values and functions pretty well, but what does this look like when we start wanting more complex data structures?

