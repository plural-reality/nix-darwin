**Learn You a**

**Haskell for**

**Great Good!**

**A Beginner’s Guide**

**Miran Lipovacˇ a**

(^)



**LEARN YOU AHASKELL FOR
GREAT GOOD!**



**Learn You a**

**Haskell for**

**Great Good!**

**A Beginner’s Guide**

**Miran Lipovacˇ a**

```
San Francisco
```

**LEARNYOU A HASKELL FOR GREAT GOOD!.** Copyright © 2011 Miran Lipovacaˇ

All rights reserved. No part of this work may be reproduced or transmitted in any form or by any means, electronic
or mechanical, including photocopying, recording, or by any information storage or retrieval system, without the
prior written permission of the copyright owner and the publisher.

15 14 13 12 11 123456789

ISBN-10: 1-59327-283-
ISBN-13: 978-1-59327-283-

Publisher: William Pollock
Production Editors: Ansel Staton and Serena Yang
Cover and Interior Design: Octopod Studios
Developmental Editor: Keith Fancher
Technical Reviewer: Samuel Hughes
Copyeditor: Marilyn Smith
Compositor: Alison Law
Proofreader: Ellen Brink
Indexer: Valerie Haynes Perry

For information on book distributors or translations, please contact No Starch Press, Inc. directly:

No Starch Press, Inc.
38 Ringold Street, San Francisco, CA 94103
phone: 415.863.9900; fax: 415.863.9950; info@nostarch.com; [http://www.nostarch.com](http://www.nostarch.com)

_Library of Congress Cataloging-in-Publication Data_
Lipovaca, Miran.
Learn you a Haskell for great good! : a beginner’s guide / by Miran Lipovaca.
p. cm.
ISBN-13: 978-1-59327-283-
ISBN-10: 1-59327-283-

1. Haskell (Computer program language) I. Title.
QA76.73.H37L69 2012
005.13’3-dc
    2011000790

No Starch Press and the No Starch Press logo are registered trademarks of No Starch Press, Inc. Other product and
company names mentioned herein may be the trademarks of their respective owners. Rather than use a trademark
symbol with every occurrence of a trademarked name, we are using the names only in an editorial fashion and to the
benefit of the trademark owner, with no intention of infringement of the trademark.

The information in this book is distributed on an “As Is” basis, without warranty. While every precaution has been
taken in the preparation of this work, neither the author nor No Starch Press, Inc. shall have any liability to any
person or entity with respect to any loss or damage caused or alleged to be caused directly or indirectly by the infor-
mation contained in it.


## BRIEF CONTENTS



## CONTENTS IN DETAIL

```
INTRODUCTION xv
```
So, What’s Haskell?.............................................................. xv
What You Need to Dive In........................................................xvii







- Chapter 1: Starting Out Introduction xv
- Chapter 2: Believe the Type
- Chapter 3: Syntax in Functions........................................................
- Chapter 4: Hello Recursion!
- Chapter 5: Higher-Order Functions
- Chapter 6: Modules
- Chapter 7: Making Our Own Types and Type Classes ..................................
- Chapter 8: Input and Output..........................................................
- Chapter 9: More Input and More Output ...............................................
- Chapter 10: Functionally Solving Problems .............................................
- Chapter 11: Applicative Functors......................................................
- Chapter 12: Monoids ................................................................
- Chapter 13: A Fistful of Monads ......................................................
- Chapter 14: For a Few Monads More .................................................
- Chapter 15: Zippers .................................................................
- Index...............................................................................
- Acknowledgments................................................................xviii
- STARTING OUT
- Calling Functions.................................................................
- Baby’s First Functions.............................................................
- An Intro to Lists...................................................................
- Concatenation...........................................................
- Accessing List Elements...................................................
- Lists Inside Lists..........................................................
- Comparing Lists.........................................................
- More List Operations.....................................................
- Texas Ranges....................................................................
- I’m a List Comprehension..........................................................
- Tuples...........................................................................
- Using Tuples.............................................................
- Using Pairs..............................................................
- Finding the Right Triangle.................................................
-
- BELIEVE THE TYPE
- Explicit Type Declaration..........................................................
- Common Haskell Types...........................................................
- Type Variables...................................................................
- Type Classes 101................................................................
- The Eq Type Class.......................................................
- The Ord Type Class......................................................
- The Show Type Class.....................................................
- The Read Type Class.....................................................
- The Enum Type Class.....................................................
- The Bounded Type Class..................................................
- The Num Type Class.....................................................
- The Floating Type Class..................................................
- The Integral Type Class...................................................
- Some Final Notes on Type Classes
-
- SYNTAX IN FUNCTIONS
- Pattern Matching.................................................................
- Pattern Matching with Tuples..............................................
- Pattern Matching with Lists and List Comprehensions.........................
- As-patterns..............................................................
- Guards, Guards!.................................................................
- where?!.........................................................................
- where’s Scope...........................................................
- Pattern Matching with where..............................................
- Functions in where Blocks.................................................
- let It Be..........................................................................
- let in List Comprehensions
- let in GHCi..............................................................
- case Expressions.................................................................
-
- HELLO RECURSION!
- Maximum Awesome..............................................................
- A Few More Recursive Functions...................................................
- replicate................................................................
- take....................................................................
- reverse..................................................................
- repeat..................................................................
- zip.....................................................................
- elem....................................................................
- Quick, Sort!.....................................................................
- The Algorithm...........................................................
- The Code...............................................................
- Thinking Recursively..............................................................
-
- HIGHER-ORDER FUNCTIONS
- Curried Functions.................................................................
- Sections.................................................................
- Printing Functions........................................................
- Some Higher-Orderism Is in Order.................................................
- Implementing zipWith....................................................
- Implementing flip
- The Functional Programmer’s Toolbox..............................................
- The map Function........................................................
- The filter Function........................................................
- More Examples of map and filter..........................................
- Mapping Functions with Multiple Parameters
- Lambdas........................................................................
- IFold You So....................................................................
- Left Folds with foldl.......................................................
- Right Folds with foldr.....................................................
- The foldl and foldr1 Functions.............................................
- Some Fold Examples.....................................................
- Another Way to Look at Folds.............................................
- Folding Infinite Lists......................................................
- Scans...................................................................
- Function Application with $.......................................................
- Function Composition.............................................................
- Function Composition with Multiple Parameters.............................
- Point-Free Style..........................................................
-
- MODULES
- Importing Modules...............................................................
- Solving Problems with Module Functions............................................
- Counting Words.........................................................
- Needle in the Haystack...................................................
- Caesar Cipher Salad.....................................................
- On Strict Left Folds.......................................................
- Let’s Find Some Cool Numbers............................................
- Mapping Keys to Values..........................................................
- Almost As Good: Association Lists.........................................
- Enter Data.Map.........................................................
- Making Our Own Modules........................................................
- A Geometry Module.....................................................
- Hierarchical Modules
-
- MAKING OUR OWN TYPES AND TYPE CLASSES
- Defining a New Data Type........................................................
- Shaping Up......................................................................
- Improving Shape with the Point Data Type..................................
- Exporting Our Shapes in a Module........................................
- Record Syntax...................................................................
- Type Parameters.................................................................
- Should We Parameterize Our Car?........................................
- Vector von Doom........................................................
- Derived Instances.................................................................
- Equating People.........................................................
- Show Me How to Read...................................................
- Order in the Court!......................................................
- Any Day of the Week....................................................
- TypeSynonyms..................................................................
- Making Our Phonebook Prettier...........................................
- Parameterizing Type Synonyms
- Go Left, Then Right.......................................................
- Recursive Data Structures..........................................................
- Improving Our List.......................................................
- Let’s Plant a Tree.........................................................
- Type Classes 102................................................................
- Inside the Eq Type Class..................................................
- A Traffic Light Data Type.................................................
- Subclassing.............................................................
- Parameterized Types As Instances of Type Classes..........................
- A Yes-No Type Class.............................................................
- The Functor Type Class............................................................
- Maybe As a Functor.....................................................
- Trees Are Functors, Too...................................................
- Either a As a Functor.....................................................
- Kinds and Some Type-Foo.........................................................
-
- INPUT AND OUTPUT
- Separating the Pure from the Impure................................................
- Hello, World!....................................................................
- Gluing I/O Actions Together......................................................
- Using let Inside I/O Actions...............................................
- Putting It in Reverse......................................................
- Some Useful I/O Functions........................................................
- putStr...................................................................
- putChar.................................................................
- print....................................................................
- when...................................................................
- sequence
- mapM..................................................................
- forever..................................................................
- forM....................................................................
- I/O Action Review...............................................................
-
- MORE INPUT AND MORE OUTPUT
- Files and Streams.................................................................
- Input Redirection.........................................................
- Getting Strings from Input Streams.........................................
- Transforming Input.......................................................
- Readingand Writing Files.........................................................
- Using the withFile Function................................................
- It’s Bracket Time.........................................................
- Grab the Handles!.......................................................
- To-Do Lists.......................................................................
- Deleting Items...........................................................
- Cleaning Up
- Command-Line Arguments.........................................................
- More Fun with To-Do Lists.........................................................
- A Multitasking Task List...................................................
- Dealing with Bad Input...................................................
- Randomness.....................................................................
- Tossing a Coin..........................................................
- More Random Functions..................................................
- Randomness and I/O....................................................
- Bytestrings.......................................................................
- Strict and Lazy Bytestrings................................................
- Copying Files with Bytestrings.............................................
-
- FUNCTIONALLY SOLVING PROBLEMS
- Reverse Polish Notation Calculator.................................................
- Calculating RPN Expressions..............................................
- Writing an RPN Function.................................................
- Adding More Operators..................................................
- Heathrow to London..............................................................
- Calculating the Quickest Path.............................................
- Representing the Road System in Haskell...................................
- Writing the Optimal Path Function.........................................
- Getting a Road System from the Input......................................
-
- APPLICATIVE FUNCTORS
- Functors Redux...................................................................
- I/O Actions As Functors..................................................
- Functions As Functors.....................................................
- Functor Laws.....................................................................
- Law 1..................................................................
- Law 2..................................................................
- Breaking the Law........................................................
- Using Applicative Functors........................................................
- Say Hello to Applicative..................................................
- Maybe the Applicative Functor............................................
- The Applicative Style.....................................................
- Lists
- IO Is An Applicative Functor, Too..........................................
- Functions As Applicatives.................................................
- Zip Lists.................................................................
- Applicative Laws.........................................................
- Useful Functions for Applicatives...................................................
-
- MONOIDS
- Wrapping an Existing Type into a New Type.......................................
- Using newtype to Make Type Class Instances...............................
- On newtype Laziness.....................................................
- type vs. newtype vs. data
- About Those Monoids.............................................................
- The Monoid Type Class..................................................
- The Monoid Laws........................................................
- Meet Some Monoids..............................................................
- Lists Are Monoids........................................................
- Product and Sum.........................................................
- Any and All.............................................................
- The Ordering Monoid....................................................
- Maybe the Monoid......................................................
- Folding with Monoids.............................................................
-
- AFISTFULOFMONADS
- Upgrading Our Applicative Functors...............................................
- Getting Your Feet Wet with Maybe
- The Monad Type Class
- Walk the Line....................................................................
- Code, Code, Code......................................................
- I’ll Fly Away.............................................................
- Banana on a Wire.......................................................
- do Notation.....................................................................
- Do As I Do..............................................................
- Pierre Returns............................................................
- Pattern Matching and Failure..............................................
- The List Monad...................................................................
- do Notation and List Comprehensions......................................
- MonadPlus and the guard Function........................................
- A Knight’s Quest.........................................................
- Monad Laws.....................................................................
- Left Identity..............................................................
- Right Identity............................................................
- Associativity.............................................................
-
- FORAFEWMONADSMORE
- Writer? I Hardly Knew Her!.......................................................
- Monoids to the Rescue...................................................
- The Writer Type.........................................................
- Using do Notation with Writer............................................
- Adding Logging to Programs..............................................
- Inefficient List Construction................................................
- Using Difference Lists.....................................................
- Comparing Performance..................................................
- Reader? Ugh, Not This Joke Again.................................................
- Functions As Monads.....................................................
- The Reader Monad......................................................
- Tasteful Stateful Computations.....................................................
- Stateful Computations....................................................
- Stacks and Stones........................................................
- The State Monad
- Getting and Setting State.................................................
- Randomness and the State Monad.........................................
- Error Error on the Wall............................................................
- Some Useful Monadic Functions...................................................
- liftM and Friends.........................................................
- The join Function.........................................................
- filterM..................................................................
- foldM...................................................................
- Making a Safe RPN Calculator....................................................
- Composing Monadic Functions....................................................
- Making Monads.................................................................
-
- ZIPPERS
- Taking a Walk...................................................................
- A Trail of Breadcrumbs...................................................
- Going Back Up..........................................................
- Manipulating Trees Under Focus..........................................
- Going Straight to the Top, Where the Air Is Fresh and Clean!................
- Focusing on Lists.................................................................
- A Very Simple Filesystem..........................................................
- Making a Zipper for Our Filesystem.......................................
- Manipulating a Filesystem................................................
- Watch Your Step.................................................................
- Thanks for Reading!..............................................................
- INDEX



## INTRODUCTION

```
Haskell is fun, and that’s what it’s all about!
This book is aimed at people who have experience programming in im-
perative languages—such as C++, Java, and Python—and now want to try out
Haskell. But even if you don’t have any significant programming experience,
I’ll bet a smart person like you will be able to follow along and learn Haskell.
My first reaction to Haskell was that the language was just too weird. But
after getting over that initial hurdle, it was smooth sailing. Even if Haskell
seems strange to you at first, don’t give up. Learning Haskell is almost like
learning to program for the first time all over again. It’s fun, and it forces
you to think differently.
```
```
NOTE If you ever get really stuck, the IRC channel #haskell on the freenode network is a
great place to ask questions. The people there tend to be nice, patient, and understand-
ing. They’re a great resource for Haskell newbies.
```
**So, What’s Haskell?**

```
Haskell is a purely functional programming language.
In imperative programming languages, you give the computer a sequence
of tasks, which it then executes. While executing them, the computer can
change state. For instance, you can set the variableato 5 and then do some
stuff that might change the value ofa. There are also flow-control structures
for executing instructions several times, such asforandwhileloops.
```

```
Purelyfunctional programming is differ-
ent. You don’t tell the computer what to do—
you tell it what stuff is. For instance, you can tell
the computer that the factorial of a number
is the product of every integer from 1 to that
number or that the sum of a list of numbers is
the first number plus the sum of the remaining
numbers. You can express both of these opera-
tions as functions.
In functional programming, you can’t set a
variable to one value and then set it to some-
thing else later on. If you sayais 5, you can’t just change your mind and
say it’s something else. After all, you said it was 5. (What are you, some kind
of liar?)
In purely functional languages, a function has no side effects. The only
thing a function can do is calculate something and return the result. At
first, this seems limiting, but it actually has some very nice consequences. If
a function is called twice with the same parameters, it’s guaranteed to return
the same result both times. This property is called referential transparency. It
lets the programmer easily deduce (and even prove) that a function is cor-
rect. You can then build more complex functions by gluing these simple
functions together.
Haskellis lazy. This means that
unless specifically told otherwise,
Haskell won’t execute functions
until it needs to show you a result.
This is made possible by referential
transparency. If you know that the
result of a function depends only
on the parameters that function is
given, it doesn’t matter when you
actually calculate the result of the
function. Haskell, being a lazy lan-
guage, takes advantage of this fact
and defers actually computing re-
sults for as long as possible. Once
you want your results to be displayed, Haskell will do just the bare minimum
computation required to display them. Laziness also allows you to make
seemingly infinite data structures, because only the parts of the data struc-
tures that you choose to display will actually be computed.
Let’s look at an example of Haskell’s laziness. Say you have a list of num-
bers,xs = [1,2,3,4,5,6,7,8], and a function calleddoubleMethat doubles every
element and returns the result as a new list. If you want to multiply your list
by 8, your code might look something like this:
```
```
doubleMe(doubleMe(doubleMe(xs)))
```
**xvi** Introduction


```
Animperative language would probably pass through the list once, make
a copy, and then return it. It would then pass through the list another two
times, making copies each time, and return the result.
In a lazy language, callingdoubleMeon a list without forcing it to show
you the result just makes the program tell you, “Yeah yeah, I’ll do it later!”
Once you want to see the result, the firstdoubleMecalls the second one and
says it wants the result immediately. Then the second one says the same
thing to the third one, and the third one reluctantly gives back a doubled
1, which is 2. The seconddoubleMereceives that and returns 4 to the first
one. The firstdoubleMethen doubles this result and tells you that the first ele-
ment in the final resulting list is 8. Because of Haskell’s laziness, thedoubleMe
calls pass through the list just once, and only when you really need that to
happen.
Haskellis statically typed. This means that
when you compile your program, the compiler
knows which piece of code is a number, which
is a string, and so on. Static typing means that a
lot of possible errors can be caught at compile
time. If you try to add together a number and
a string, for example, the compiler will whine
at you.
Haskell uses a very good type system that
has type inference. This means that you don’t
need to explicitly label every piece of code with a type, because Haskell’s
type system can intelligently figure it out. For example, if you saya=5+4,
you don’t need to tell Haskell thatais a number—it can figure that out by
itself. Type inference makes it easier for you to write code that’s more gen-
eral. If you write a function that takes two parameters and adds them to-
gether, but you don’t explicitly state their type, the function will work on
any two parameters that act like numbers.
Haskell is elegant and concise. Because it uses a lot of high-level con-
cepts, Haskell programs are usually shorter than their imperative equiva-
lents. Shorter programs are easier to maintain and have fewer bugs.
Haskell was made by some really smart guys (with PhDs). Work on
Haskell began in 1987 when a committee of researchers got together to
design a kick-ass language. The Haskell Report, which defines a stable ver-
sion of the language, was published in 1999.
```
**What You Need to Dive In**

```
In short, to get started with Haskell, you need a text editor and a Haskell
compiler. You probably already have your favorite text editor installed, so we
won’t waste time on that. The most popular Haskell compiler is the Glasgow
Haskell Compiler (GHC), which we will be using throughout this book.
The best way to get what you need is to download the Haskell Platform.
The Haskell Platform includes not only the GHC compiler but also a bunch
of useful Haskell libraries! To get the Haskell Platform for your system, go to
```
```
Introduction xvii
```

```
http://hackage.haskell.org/platform/ and follow the instructions for your oper-
ating system.
GHC can compile Haskell scripts (usually with an .hs extension), and
it also has an interactive mode. From there, you can load functions from
scripts and then call them directly to see immediate results. Especially when
you’re learning, it’s much easier to use the interactive mode than it is to
compile and run your code every time you make a change.
Once you’ve installed the Haskell Platform, open a new terminal win-
dow, assuming you’re on a Linux or Mac OS X system. If your operating sys-
tem of choice is Windows, go to the command prompt. Once there, type
ghci and press ENTER to start the interactive mode. (If your system fails to
find the GHCi program, you can try rebooting your computer.)
If you’ve defined some functions in a script—for example, myfunctions.hs —
you can load these functions into GHCi by typing:l myfunctions. (Make sure
that myfunctions.hs is in the same folder from which you started GHCi.)
If you change the .hs script, run:l myfunctionsto load the file again or
run:r, which reloads the current script. My usual workflow is to define some
functions in an .hs file, load it into GHCi, mess around with it, change the
file, and repeat. This is what we’ll be doing in this book.
```
```
Acknowledgments
Thanks to everyone who sent in corrections, suggestions, and words of en-
couragement. Also thanks to Keith, Sam, and Marilyn for making me look
like a real writer.
```
**xviii** Introduction


# 1

## STARTING OUT

```
If you’re the horrible sort of person who doesn’t read
introductions, you might want to go back and read the
last section anyway—it explains how to use this book,
as well as how to load functions with GHC.
First, let’s start GHC’s interactive mode and call some functions, so we
can get a very basic feel for Haskell. Open a terminal and type ghci. You will
be greeted with something like this:
```
```
GHCi,version 6.12.3: http://www.haskell.org/ghc/ :? for help
Loading package ghc-prim ... linking ... done.
Loading package integer-gmp ... linking ... done.
Loading package base ... linking ... done.
Loading package ffi-1.0 ... linking ... done.
```
**NOTE** _GHCi’s default prompt isPrelude>, but we’ll be usingghci>as our prompt for the ex-
amples in this book. To make your prompt match the book’s, enter_ **:set prompt "ghci> "**
_into GHCi. If you don’t want to do this every time you run GHCi, create a file called_
.ghci _in your home folder and set its contents to_ **:set prompt "ghci> "**_._


```
Congratulations,you’re in GHCi! Now let’s try some simple arithmetic:
```
```
ghci>2 + 15
17
ghci> 49* 100
4900
ghci> 1892 - 1472
420
ghci> 5 / 2
2.5
```
```
Ifwe use several operators in one expression,
Haskell will execute them in an order that takes
into account the precedence of the operators.
For instance,*has higher precedence than-, so
```
(^50) *100 - 4999is treated as(50*100) - 4999.
We can also use parentheses to explicitly specify
the order of operations, like this:
ghci>(50*100) - 4999
1
ghci> 50*100 - 4999
1
ghci> 50*(100 - 4999)
-244950
Prettycool, huh? (Yeah, I know it’s not, yet, but bear with me.)
One pitfall to watch out for is negative number constants. It’s always
best to surround these with parentheses wherever they occur in an arith-
metic expression. For example, entering (^5) *-3will make GHCi yell at you,
but entering (^5) *(-3)will work just fine.
Boolean algebra is also straightforward in Haskell. Like many other pro-
gramming languages, Haskell has the Boolean valuesTrueandFalse, and
uses the&&operator for conjunction (Boolean _and_ ), the||operator for dis-
junction (Boolean _or_ ), and thenotoperator to negate aTrueorFalsevalue:
ghci>True && False
False
ghci> True && True
True
ghci> False || True
True
ghci> not False
True
ghci> not (True && True)
False
**2** Chapter 1


```
Wecan test two values for equality or inequality with the==and/=opera-
tors, like this:
```
```
ghci>5 == 5
True
ghci> 1 == 0
False
ghci> 5 /= 5
False
ghci> 5 /= 4
True
ghci> "hello" == "hello"
True
```
```
Watchout when mixing and matching values, however! If we enter some-
thing like5 + "llama", we get the following error message:
```
```
Noinstance for (Num [Char])
arising from a use of `+' at <interactive>:1:0-9
Possible fix: add an instance declaration for (Num [Char])
In the expression: 5 + "llama"
In the definition of `it': it = 5 + "llama"
```
```
WhatGHCi is telling us here is that"llama"is not a number, so it does
not know how to add it to 5. The+operator expects both of its inputs to be
numbers.
On the other hand, the==operator works on any two items that can
be compared, with one catch: they both have to be of the same type. For
instance, if we tried enteringTrue == 5, GHCi would complain.
```
```
NOTE 5 + 4.0is a valid expression, because although4.0isn’t an integer, 5 is sneaky and
can act like either an integer or a floating-point number. In this case, 5 adapts to
match the type of the floating-point value4.0.
```
```
We’ll take a closer look at types a bit later.
```
## Calling Functions.................................................................

```
Youmay not have realized it, but we’ve actually
been using functions this whole time. For in-
stance,*is a function that takes two numbers
and multiplies them. As you’ve seen, we apply
(or call ) it by sandwiching it between the two
numbers we want to multiply. This is called an
infix function.
Most functions, however, are prefix func-
tions. When calling prefix functions in Haskell,
the function name comes first, then a space,
```
```
Starting Out 3
```

```
thenits parameters (also separated by spaces). As an example, we’ll try call-
ing one of the most boring functions in Haskell,succ:
```
```
ghci>succ 8
9
```
```
Thesuccfunctiontakes one parameter that can be anything that has a
well-defined successor, and returns that value. The successor of an integer
value is just the next higher number.
Now let’s call two prefix functions that take multiple parameters,min
andmax:
```
```
ghci>min 9 10
9
ghci> min 3.4 3.2
3.2
ghci> max 100 101
101
```
```
Theminandmaxfunctionseach take two parameters that can be put
in some order (like numbers!), and they return the one that’s smaller or
larger, respectively.
Function application has the highest precedence of all the operations in
Haskell. In other words, these two statements are equivalent.
```
```
ghci>succ 9 + max 5 4 + 1
16
ghci> (succ 9) + (max 5 4) + 1
16
```
Thismeans that if we want to get the successor of (^9) * 10 , we couldn’t
simply write
ghci>succ 9* 10
Becauseof the precedence of operations, this would evaluate as the suc-
cessor of 9 (which is 10) multiplied by 10, yielding 100. To get the result we
want, we need to instead enter
ghci>succ (9*10)
Thisreturns 91.
If a function takes two parameters, we can also call it as an infix function
by surrounding its name with backticks (`). For instance, thedivfunction
takes two integers and executes an integral division, as follows:
ghci>div 92 10
9
**4** Chapter 1


```
However,when we call it like that, there may be some confusion as to
which number is being divided by which. By using backticks, we can call it as
an infix function, and suddenly it seems much clearer:
```
```
ghci>92 `div` 10
9
```
```
Manyprogrammers who are used to imperative languages tend to stick
to the notion that parentheses should denote function application, and they
have trouble adjusting to the Haskell way of doing things. Just remember,
if you see something likebar (bar 3), it means that we’re first calling thebar
function with 3 as the parameter, then passing that result to thebarfunction
again. The equivalent expression in C would be something likebar(bar(3)).
```
## Baby’s First Functions.............................................................

```
Thesyntax of a function definition is similar
to that of a function call: the function name is
followed by parameters, which are separated by
spaces. But then the parameter list is followed
by the=operator, and the code that makes up
the body of the function follows that.
As an example, we’ll write a simple func-
tion that takes a number and multiplies it by
two. Open up your favorite text editor and type
in the following:
```
```
doubleMex=x+x
```
```
Savethis file as baby.hs. Now runghci, mak-
ing sure that baby.hs is in your current directory.
Once in GHCi, enter :l baby to load the file.
Now we can play with our new function:
```
```
ghci>:l baby
[1 of 1] Compiling Main ( baby.hs, interpreted )
Ok, modules loaded: Main.
ghci> doubleMe 9
18
ghci> doubleMe 8.3
16.6
```
```
Because+workson integers as well as on floating point numbers (in-
deed, on anything that can be considered a number), our function also
works with any of these types.
```
```
Starting Out 5
```

```
Nowlet’s make a function that takes two numbers, multiplies each by
two, then adds them together. Append the following code to baby.hs :
```
```
doubleUsxy=x*2+y* 2
```
```
NOTE Functionsin Haskell don’t have to be defined in any particular order, so it doesn’t
matter which function comes first in the baby.hs file.
```
```
Now save the file, and enter :l baby in GHCi to load your new function.
Testing this function yields predictable results:
```
```
ghci>doubleUs 4 9
26
ghci> doubleUs 2.3 34.2
73.0
ghci> doubleUs 28 88 + doubleMe 123
478
```
```
Functionsthat you define can also call each other. With that in mind,
we could redefinedoubleUsin the following way:
```
```
doubleUsx y = doubleMe x + doubleMe y
```
```
Thisis a very simple example of a common pattern you will see when
using Haskell: Basic, obviously correct functions can be combined to form
more complex functions. This is a great way to avoid code repetition. For
example, what if one day mathematicians figure out that 2 and 3 are actually
the same, and you have to change your program? You could just redefine
doubleMeto bex+x+x, and sincedoubleUscallsdoubleMe, it would now also
automatically work correctly in this strange new world where 2 is equal to 3.
Now let’s write a function that multiplies a number by 2, but only if that
number is less than or equal to 100 (because numbers bigger than 100 are
big enough as it is!).
```
```
doubleSmallNumberx = if x > 100
then x
else x* 2
```
```
Thisexample introduces Haskell’sifstatement. You’re probably already
familiar with if statements from other languages, but what makes Haskell’s
unique is that theelsepart is mandatory.
Programs in imperative languages are essentially a series of steps that
the computer executes when the program is run. When there is anifstate-
ment that doesn’t have a correspondingelse, and the condition isn’t met,
then the steps that fall under theifstatement don’t get executed. Thus, in
imperative languages, anifstatement can just do nothing.
On the other hand, a Haskell program is a collection of functions. Func-
tions are used to transform data values into result values, and every function
```
**6** Chapter 1


```
shouldreturn some value, which can in turn be used by another function.
Since every function has to return something, this implies that everyifhas
to have a correspondingelse. Otherwise, you could write a function that has
a return value when a certain condition is met but doesn’t have one when
that condition isn’t met! Briefly: Haskell’sifis an expression that must return
a value, and not a statement.
Let’s say we want a function that adds one to every number that would
be produced by our previousdoubleSmallNumberfunction. The body of this
new function would look like this:
```
```
doubleSmallNumber'x = (if x > 100 then x else x*2) + 1
```
```
Notethe placement of the parentheses. If we had omitted them, the
function would only add one ifxis less than or equal to 100. Also note the
apostrophe (') at the end of the function’s name. The apostrophe doesn’t
have any special meaning in Haskell’s syntax, which means it’s a valid char-
acter to use in a function name. We usually use'to denote either a strict ver-
sion of a function (i.e., one that isn’t lazy), or a slightly modified version of a
function or variable with a similar name.
Since'is a valid character for function names, we can write a function
that looks like this:
```
```
conanO'Brien= "It's a-me, Conan O'Brien!"
```
```
Thereare two things to note here. The first is that we didn’t capitalize
Conan in the name of the function. In Haskell, functions can’t begin with
capital letters. (We’ll see why a bit later.) The second thing to note is that
this function doesn’t take any parameters. When a function doesn’t take
any parameters, we usually call it a definition or a name. Because we cannot
change what names (or functions) mean once we have defined them, the
functionconanO'Brienand the string"It's a-me, Conan O'Brien!"can be used
interchangeably.
```
## An Intro to Lists...................................................................

```
Listsin Haskell are homogeneous data structures,
which means they store several elements of the same
type. We can have a list of integers or a list of charac-
ters, for example, but we can’t have a list made up of
both integers and characters.
Lists are surrounded by square brackets, and the
list values are separated by commas:
```
```
ghci>let lostNumbers = [4,8,15,16,23,42]
ghci> lostNumbers
[4,8,15,16,23,42]
```
```
Starting Out 7
```

```
NOTE Usetheletkeyword to define a name in GHCi. Enteringlet a = 1in GHCi is equiv-
alent to writinga=1in a script, then loading it with:l.
```
## Concatenation...........................................................

```
One of the most common operations when working with lists is concatena-
tion. In Haskell, this is done using the++operator:
```
```
ghci>[1,2,3,4] ++ [9,10,11,12]
[1,2,3,4,9,10,11,12]
ghci> "hello" ++ " " ++ "world"
"hello world"
ghci> ['w','o'] ++ ['o','t']
"woot"
```
```
NOTE InHaskell, strings are really just lists of characters. For example, the string"hello"is
actually the same as the list['h','e','l','l','o']. Because of this, we can use list
functions on strings, which is really handy.
```
```
Be careful when repeatedly using the++operator on long strings. When
you put together two lists, Haskell has to walk through the entire first list
(the one on the left side of++). That’s not a problem when dealing with
smaller lists, but appending something to the end of a list with fifty million
entries is going to take a while.
However, adding something to the beginning of a list is a nearly in-
stantaneous operation. We do this with the:operator (also called the cons
operator):
```
```
ghci>'A':" SMALL CAT"
"A SMALL CAT"
ghci> 5:[1,2,3,4,5]
[5,1,2,3,4,5]
```
```
Noticehow in the first example,:takes a character and a list of charac-
ters (a string) as its arguments. Similarly, in the second example,:takes a
number and a list of numbers. The first argument to the:operator always
needs to be a single item of the same type as the values in the list it’s being
added to.
The++operator, on the other hand, always takes two lists as arguments.
Even if you’re only adding a single element to the end of a list with++, you
still have to surround that item with square brackets, so Haskell will treat it
like a list:
```
```
ghci>[1,2,3,4] ++ [5]
[1,2,3,4,5]
```
```
Writing[1,2,3,4]++ 5is wrong, because both parameters to++should be
lists, and 5 isn’t a list; it’s a number.
```
**8** Chapter 1


```
Interestingly,in Haskell,[1,2,3]is just syntactic sugar for1:2:3:[].[]is
an empty list. If we prepend 3 to that, it becomes[3]. Then if we prepend 2
to that, it becomes[2,3], and so on.
```
**NOTE** _[],[[]]and[[],[],[]]are all different things. The first is an empty list, the second
is a list that contains one empty list, and the third is a list that contains three empty
lists._

## Accessing List Elements...................................................

```
If you want to get an element of a list by index, use the!!operator. As with
most programming languages, the indices start at 0:
```
```
ghci>"Steve Buscemi" !! 6
'B'
ghci> [9.4,33.2,96.2,11.2,23.25] !! 1
33.2
```
```
However,if you try (say) to get the sixth element from a list that only has
four elements, you’ll get an error, so be careful!
```
## Lists Inside Lists..........................................................

```
Lists can contain lists as elements, and lists can contain lists that contain lists,
and so on....
```
```
ghci>let b = [[1,2,3,4],[5,3,3,3],[1,2,2,3,4],[1,2,3]]
ghci> b
[[1,2,3,4],[5,3,3,3],[1,2,2,3,4],[1,2,3]]
ghci> b ++ [[1,1,1,1]]
[[1,2,3,4],[5,3,3,3],[1,2,2,3,4],[1,2,3],[1,1,1,1]]
ghci> [6,6,6]:b
[[6,6,6],[1,2,3,4],[5,3,3,3],[1,2,2,3,4],[1,2,3]]
ghci> b !! 2
[1,2,2,3,4]
```
```
Listswithin a list can be of different lengths, but they can’t be of differ-
ent types. Just like you can’t have a list that has some characters and some
numbers as elements, you also can’t have a list that contains some lists of
characters and some lists of numbers.
```
## Comparing Lists.........................................................

```
Lists can be compared if the items they contain can be compared. When
using<,<=,>=and>to compare two lists, they are compared in lexicograph-
ical order. This means that first the two list heads are compared, and if
they’re equal, the second elements are compared. If the second elements
are also equal, the third elements are compared, and so on, until differing
```
```
Starting Out 9
```

```
elementsare found. The order of the two lists is determined by the order of
the first pair of differing elements.
For example, when we evaluate[3,4,2] < [3,4,3], Haskell sees that 3 and
3 are equal, so it compares 4 and 4. Those two are also equal, so it compares
2 and 3. 2 is smaller than 3 , so it comes to the conclusion that the first list is
smaller than the second one. The same goes for<=,>=, and>.
```
```
ghci>[3,2,1] > [2,1,0]
True
ghci> [3,2,1] > [2,10,100]
True
ghci> [3,4,2] < [3,4,3]
True
ghci> [3,4,2] > [2,4]
True
ghci> [3,4,2] == [3,4,2]
True
```
```
Also,a nonempty list is always considered to be greater than an empty
one. This makes the ordering of two lists well defined in all cases, including
when one is a proper initial segment of the other.
```
## More List Operations.....................................................

```
Here are some more basic list functions, followed by examples of their
usage.
Theheadfunction takes a list and returns its head, or first element:
```
```
ghci>head [5,4,3,2,1]
5
```
```
Thetailfunctiontakes a list and returns its tail. In other words, it chops
off a list’s head:
```
```
ghci>tail [5,4,3,2,1]
[4,3,2,1]
```
```
Thelastfunctionreturns a list’s last element:
```
```
ghci>last [5,4,3,2,1]
1
```
```
Theinitfunctiontakes a list and returns everything except its last
element:
```
```
ghci>init [5,4,3,2,1]
[5,4,3,2]
```
**10** Chapter 1


Tohelp us visualize these functions, we can think of a list as a monster,
like this:

```
Butwhat happens if we try to get the head of an empty list?
```
ghci>head []

***Exception: Prelude.head: empty list

Ohmy—it blows up in our face! If there’s no monster, it doesn’t have
a head. When usinghead,tail,last, andinit, be careful not to use them on
empty lists. This error cannot be caught at compile time, so it’s always good
practice to take precautions against accidentally telling Haskell to give you
elements from an empty list.
Thelengthfunction takes a list and returns its length:

ghci>length [5,4,3,2,1]
5

Thenullfunctionchecks if a list is empty. If it is, it returnsTrue, other-
wise it returnsFalse.

ghci>null [1,2,3]
False
ghci> null []
True

```
Thereversefunctionreverses a list:
```
ghci>reverse [5,4,3,2,1]
[1,2,3,4,5]

```
Starting Out 11
```

```
Thetakefunctiontakes a number and a list. It extracts the specified
number elements from the beginning of the list, like this:
```
```
ghci>take 3 [5,4,3,2,1]
[5,4,3]
ghci> take 1 [3,9,3]
[3]
ghci> take 5 [1,2]
[1,2]
ghci> take 0 [6,6,6]
[]
```
```
Ifwe try totakemore elements than there are in the list, Haskell just
returns the entire list. If wetake0 elements, we get an empty list.
Thedropfunction works in a similar way, only it drops (at most) the
specified number of elements from the beginning of a list:
```
```
ghci>drop 3 [8,4,2,1,5,6]
[1,5,6]
ghci> drop 0 [1,2,3,4]
[1,2,3,4]
ghci> drop 100 [1,2,3,4]
[]
```
```
Themaximumfunctiontakes a list of items that can be put in some kind of
order and returns the largest element. Theminimumfunction is similar, but it
returns the smallest item:
```
```
ghci>maximum [1,9,2,3,4]
9
ghci> minimum [8,4,2,1,5,6]
1
```
```
Thesumfunctiontakes a list of numbers and returns their sum. The
productfunction takes a list of numbers and returns their product:
```
```
ghci>sum [5,2,1,6,3,2,5,7]
31
ghci> product [6,2,1,2]
24
ghci> product [1,2,5,6,7,9,2,0]
0
```
```
Theelemfunctiontakes an item and a list of items and tells us if that
item is an element of the list. It’s usually called as an infix function because
it’s easier to read that way.
```
**12** Chapter 1


```
ghci> 4 `elem`[3,4,5,6]
True
ghci> 10 `elem` [3,4,5,6]
False
```
## Texas Ranges....................................................................

```
What if weneed a list made up of the num-
bers between 1 and 20? Sure, we could just
type them all out, but that’s not a solution
for gentlemen who demand excellence from
their programming languages. Instead, we’ll
use ranges. Ranges are used to make lists
composed of elements that can be enumer-
ated , or counted off in order.
For example, numbers can be enu-
merated: 1, 2, 3, 4, and so on. Characters
can also be enumerated: the alphabet is
an enumeration of characters from A to
Z. Names, however, can’t be enumerated.
(What comes after “John?” I don’t know!)
To make a list containing all the natu-
ral numbers from 1 to 20, you can just type
[1..20]. In Haskell, this is exactly the same as typing
[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]. The only difference be-
tween the two is that writing out long enumeration sequences manually is
stupid.
Here are a few more examples:
```
```
ghci> [1..20]
[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]
ghci> ['a'..'z']
"abcdefghijklmnopqrstuvwxyz"
ghci>['K'..'Z']
"KLMNOPQRSTUVWXYZ"
```
```
You can alsospecify a step between items in your range. What if we want
a list of every even number between 1 and 20? Or every third number be-
tween 1 and 20? It’s simply a matter of separating the first two elements with
a comma and specifying the upper limit:
```
```
ghci> [2,4..20]
[2,4,6,8,10,12,14,16,18,20]
ghci> [3,6..20]
[3,6,9,12,15,18]
```
```
Starting Out 13
```

```
Whilethey are pretty convenient, ranges with steps aren’t always as smart
as people expect them to be. For example, you can’t enter[1,2,4,8,16..100]
and expect to get all the powers of 2 that are no greater than 100. For one
thing, you can only specify a single step size. Also, some sequences that aren’t
arithmetic can’t be specified unambiguously by giving only their first few
terms.
```
```
NOTE To make a list with all the numbers from 20 down to 1, you can’t just type[20..1],
you have to type[20,19..1]. When you use a range without steps (like[20..1]),
Haskell will start with an empty list and then keep increasing the starting element
by one until it reaches or surpasses the end element in the range. Because 20 is
already greater than 1, the result will just be an empty list.
```
```
You can also use ranges to make infinite lists by not specifying an upper
limit. For example, let’s create a list containing the first 24 multiples of 13.
Here’s one way to do it:
```
```
ghci>[13,26..24*13]
[13,26,39,52,65,78,91,104,117,130,143,156,169,182,195,208,221,234,247,260,273,286,299,312]
```
```
Butthere’s actually a better way—using an infinite list:
```
```
ghci>take 24 [13,26..]
[13,26,39,52,65,78,91,104,117,130,143,156,169,182,195,208,221,234,247,260,273,286,299,312]
```
```
BecauseHaskell is lazy , it won’t try to evaluate the entire infinite list im-
mediately (which is good because it would never finish anyway). Instead, it
will wait to see which elements you need to get from that infinite list. In the
above example, it sees that you just want the first 24 elements, and it gladly
obliges.
Here are a few functions that can be used to produce long or infinite
lists:
```
- cycletakes a list and replicates its elements indefinitely to form an infi-
    nite list. If you try to display the result, it will go on forever, so make sure
    to slice it off somewhere:

```
ghci>take 10 (cycle [1,2,3])
[1,2,3,1,2,3,1,2,3,1]
ghci> take 12 (cycle "LOL ")
"LOL LOL LOL "
```
- repeattakesan element and produces an infinite list of just that element.
    It’s like cycling a list with only one element:

```
ghci>take 10 (repeat 5)
[5,5,5,5,5,5,5,5,5,5]
```
**14** Chapter 1


- replicateisan easier way to create a list composed of a single item. It
    takes the length of the list and the item to replicate, as follows:

```
ghci>replicate 3 10
[10,10,10]
```
```
Onefinal note about ranges: watch out when using them with floating-
point numbers! Because floating-point numbers, by their nature, only have
finite precision, using them in ranges can yield some pretty funky results, as
you can see here:
```
```
ghci>[0.1, 0.3 .. 1]
[0.1,0.3,0.5,0.7,0.8999999999999999,1.0999999999999999]
```
## I’m a List Comprehension..........................................................

```
Listcomprehensions are a way to filter,
transform, and combine lists.
They’re very similar to the mathe-
matical concept of set comprehensions.
Set comprehensions are normally used
for building sets out of other sets. An
example of a simple set comprehension
is:{ 2 ·x|x 2 N,x 10 }. The exact
syntax used here isn’t crucial—what’s
important is that this statement says,
“take all the natural numbers less than
or equal to 10, multiply each one by 2,
and use these results to create a new set.”
If we wanted to write the same thing in Haskell, we could do something
like this with list operations:take 10 [2,4..]. However, we could also do the
same thing using list comprehensions, like this:
```
```
ghci>[x*2 | x <- [1..10]]
[2,4,6,8,10,12,14,16,18,20]
```
```
Let’stake a closer look at the list comprehension in this example to bet-
ter understand list comprehension syntax.
In[x*2 | x <- [1..10]], we say that we draw our elements from the list
[1..10].[x <- [1..10]]means thatxtakes on the value of each element that
is drawn from[1..10]. In other words, we bind each element from[1..10]to
x. The part before the vertical pipe (|) is the output of the list comprehen-
sion. The output is the part where we specify how we want the elements that
we’ve drawn to be reflected in the resulting list. In this example, we say that
we want each element that is drawn from the list[1..10]to be doubled.
```
```
Starting Out 15
```

```
Thismay seem longer and more complicated than the first example,
but what if we want to do something more complex than just doubling these
numbers? This is where list comprehensions really come in handy.
For example, let’s add a condition (also called a predicate ) to our com-
prehension. Predicates go at the end of the list comprehension and are sep-
arated from the rest of the comprehension by a comma. Let’s say we want
only the elements which, after being doubled, are greater than or equal
to 12:
```
```
ghci>[x*2 | x <- [1..10], x*2 >= 12]
[12,14,16,18,20]
```
```
Whatif we want all numbers from 50 to 100 whose remainder when
divided by 7 is 3? Easy:
```
```
ghci>[ x | x <- [50..100], x `mod` 7 == 3]
[52,59,66,73,80,87,94]
```
```
NOTE Weeding out parts of lists using predicates is also called filtering.
```
```
Now for another example. Let’s say we want a comprehension that
replaces every odd number greater than 10 with"BANG!", and every odd num-
ber less than 10 with"BOOM!". If a number isn’t odd, we throw it out of our
list. For convenience, we’ll put that comprehension inside a function so we
can easily reuse it:
```
```
boomBangsxs = [ if x < 10 then "BOOM!" else "BANG!" | x <- xs, odd x]
```
```
NOTE Remember, if you’re trying to define this function inside GHCi, you have to include a
letbefore the function name. However, if you’re defining this function inside a script
and then loading that script into GHCi, you don’t have to mess around withlet.
```
```
Theoddfunction returnsTruewhen passed an odd number, otherwise
it returnsFalse. The element is included in the list only if all the predicates
evaluate toTrue.
```
```
ghci>boomBangs [7..13]
["BOOM!","BOOM!","BANG!","BANG!"]
```
```
Wecan include as many predicates as we want, all separated by commas.
For instance, if we wanted all numbers from 10 to 20 that are not 13, 15 or
19, we’d do:
```
```
ghci>[ x | x <- [10..20], x /= 13, x /= 15, x /= 19]
[10,11,12,14,16,17,18,20]
```
**16** Chapter 1


Notonly can we have multiple predicates in list comprehensions, we can
also draw values from several lists. When drawing values from several lists, ev-
ery combination of elements from these lists is reflected in the resulting list:

ghci>[x+y | x <- [1,2,3], y <- [10,100,1000]]
[11,101,1001,12,102,1002,13,103,1003]

Here,xisdrawn from[1,2,3]andyis drawn from[10,100,1000]. These
two lists are combined in the following way. First,xbecomes 1 , and whilex
is 1 ,ytakes on every value from[10,100,1000]. Because the output of the list
comprehension isx+y, the values 11 , 101 , and 1001 are added to the beginning
of the resulting list ( 1 is added to 10 , 100 , and 1000 ). After that,xbecomes
2 and the same thing happens, resulting in the elements 12 , 102 , and 1002
being added to the resulting list. The same goes whenxdraws the value 3.
In this manner, each elementxfrom[1,2,3]is combined with each
elementyfrom[10,100,1000]in all possible ways, andx+yis used to make
the resulting list from those combinations.
Here’s another example: if we have two lists,[2,5,10]and[8,10,11], and
we want to get the products of all possible combinations of numbers in those
lists, we could use the following comprehension:

ghci>[x*y | x <- [2,5,10], y <- [8,10,11]]
[16,20,22,40,50,55,80,100,110]

Asexpected, the length of the new list is 9. Now, what if we wanted all
possible products that are more than 50? We can just add another predicate:

ghci>[x*y | x <- [2,5,10], y <- [8,10,11], x*y > 50]
[55,80,100,110]

Forepic hilarity, let’s make a list comprehension that combines a list of
adjectives and a list of nouns.

ghci>let nouns = ["hobo","frog","pope"]
ghci> let adjectives = ["lazy","grouchy","scheming"]
ghci> [adjective ++ " " ++ noun | adjective <- adjectives, noun <- nouns]
["lazy hobo","lazy frog","lazy pope","grouchy hobo","grouchy frog",
"grouchy pope","scheming hobo","scheming frog","scheming pope"]

Wecan even use list comprehensions to write our own version of the
lengthfunction! We’ll call itlength'. This function will replace every element
in a list with 1 , then add them all up withsum, yielding the length of the list.

length'xs = sum [1 | _ <- xs]

```
Starting Out 17
```

```
Herewe use underscore (_) as a temporary variable to store the items
as we draw them from the input list, since we don’t actually care about the
values.
Remember, strings are lists too, so we can use list comprehensions to
process and produce strings. Here’s an example of a function that takes a
string and removes all the lowercase letters from it:
```
```
removeNonUppercasest = [ c | c <- st, c `elem` ['A'..'Z']]
```
```
Thepredicate here does all the work. It says that the character will be
included in the new list only if it’s an element of the list['A'..'Z']. We can
load the function in GHCi and test it out:
```
```
ghci>removeNonUppercase "Hahaha! Ahahaha!"
"HA"
ghci> removeNonUppercase "IdontLIKEFROGS"
"ILIKEFROGS"
```
```
Youcan also create nested list comprehensions if you’re operating on
lists that contain lists. For example, let’s take a list that contains several lists
of numbers and remove all the odd numbers without flattening the list:
```
```
ghci>let xxs = [[1,3,5,2,3,1,2,4,5],[1,2,3,4,5,6,7,8,9],[1,2,4,2,1,6,3,1,3,2,3,6]]
ghci> [ [ x | x <- xs, even x ] | xs <- xxs]
[[2,2,4],[2,4,6,8],[2,4,2,6,2,6]]
```
```
Herethe output of the outer list comprehension is another list compre-
hension. A list comprehension always results in a list of something, so we
know that the result here will be a list of lists of numbers.
```
```
NOTE You can split list comprehensions across several lines to improve their readability. If
you’re not in GHCi, this can be a great help, especially when dealing with nested
comprehensions.
```
## Tuples...........................................................................

```
Tuples are used to store several heterogeneous
elements as a single value.
In some ways, tuples are a lot like lists. How-
ever, there are some fundamental differences.
First, as mentioned, tuples are heterogeneous.
This means that a single tuple can store elements
of several different types. Second, tuples have
a fixed size—you need to know how many ele-
ments you’ll be storing ahead of time.
```
**18** Chapter 1


Tuplesare surrounded by parentheses, and their components are sepa-
rated by commas:

ghci>(1, 3)
(1,3)
ghci> (3, 'a', "hello")
(3,'a',"hello")
ghci> (50, 50.4, "hello", 'b')
(50,50.4,"hello",'b')

## Using Tuples.............................................................

As an example of when tuples would be useful, let’s think about how we’d
represent a two-dimensional vector in Haskell. One way would be to use a
two item list, in the form of[x,y]. But suppose we wanted to make a list of
vectors, to represent the corners of a two-dimensional shape in a coordinate
plane. We could just create a list of lists, like this:[[1,2],[8,11],[4,5]].
The problem with this method, however, is that we could also make a
list like[[1,2],[8,11,5],[4,5]]and try to use it in the place of a list of vectors.
Even though it doesn’t make sense as a list of vectors, Haskell has no prob-
lem with this list appearing wherever the previous list can, since both are of
the same type (a list of lists of numbers). This could make it more compli-
cated to write functions to manipulate vectors and shapes.
In contrast, a tuple of size two (also called a _pair_ ) and a tuple of size
three (also called a _triple_ ) are treated as two distinct types, which means a list
can’t be composed of both pairs and triples. This makes tuples much more
useful for representing vectors.
We can change our vectors to tuples by surrounding them with paren-
theses instead of square brackets, like this:[(1,2),(8,11),(4,5)]. Now, if we
try to mix pairs and triples, we get an error, like this:

ghci>[(1,2),(8,11,5),(4,5)]
Couldn't match expected type `(t, t1)'
against inferred type `(t2, t3, t4)'
In the expression: (8, 11, 5)
In the expression: [(1, 2), (8, 11, 5), (4, 5)]
In the definition of `it': it = [(1, 2), (8, 11, 5), (4, 5)]

Haskellalso considers tuples that have the same length but contain
different types of data to be distinct types of tuples. For example, you can’t
make a list of tuples like[(1,2),("One",2)], because the first is a pair of num-
bers, and the second is a pair containing a string followed by a number.
Tuples can be used to easily represent a wide variety of data. For in-
stance, if we wanted to represent someone’s name and age in Haskell, we
could use a triple:("Christopher", "Walken", 55).
Remember, tuples are of a fixed size—you should only use them when
you know in advance how many elements you’ll need. The reason tuples are

```
Starting Out 19
```

```
sorigid in this way is that, as mentioned, the size of a tuple is treated as part
of its type. Unfortunately, this means that you can’t write a general function
to append an element to a tuple—you’d have to write a function for append-
ing to a pair (to produce a triple), another one for appending to a triple (to
produce a 4-tuple), another one for appending to a 4-tuple, and so on.
Like lists, tuples can be compared with each other if their components
can be compared. However, unlike lists, you can’t compare two tuples of
different sizes.
Although there are singleton lists, there’s no such thing as a singleton
tuple. It makes sense when you think about it: a singleton tuple’s properties
would simply be those of the value it contains, so distinguishing a new type
wouldn’t give us any benefit.
```
## Using Pairs..............................................................

```
Storing data in pairs is very common in Haskell, and there are some useful
functions in place to manipulate them. Here are two functions that operate
on pairs:
```
- fsttakes a pair and returns its first component:

```
ghci>fst (8, 11)
8
ghci> fst ("Wow", False)
"Wow"
```
- sndtakesa pair and—surprise!—returns its second component:

```
ghci>snd (8, 11)
11
ghci> snd ("Wow", False)
False
```
```
NOTE Thesefunctions only operate on pairs. They won’t work on triples, 4-tuples, 5-tuples,
etc. We’ll go over extracting data from tuples in different ways a bit later.
```
```
Thezipfunction is a cool way to produce a list of pairs. It takes two lists,
then “zips” them together into one list by joining the matching elements
into pairs. It’s a really simple function, but it can be very useful when you
want to combine two lists in a particular way or traverse two lists simultane-
ously. Here’s a demonstration:
```
```
ghci>zip [1,2,3,4,5] [5,5,5,5,5]
[(1,5),(2,5),(3,5),(4,5),(5,5)]
ghci> zip [1..5] ["one", "two", "three", "four", "five"]
[(1,"one"),(2,"two"),(3,"three"),(4,"four"),(5,"five")]
```
**20** Chapter 1


Noticethat because pairs can have different types in them,zipcan take
two lists that contain elements of different types. But what happens if the
lengths of the lists don’t match?

ghci>zip [5,3,2,6,2,7,2,5,4,6,6] ["im","a","turtle"]
[(5,"im"),(3,"a"),(2,"turtle")]

Asyou can see in the above example, only as much of the longer list is
used as needed—the rest is simply ignored. And because Haskell uses lazy
evaluation, we can even zip finite lists with infinite lists:

ghci>zip [1..] ["apple", "orange", "cherry", "mango"]
[(1,"apple"),(2,"orange"),(3,"cherry"),(4,"mango")]

## Finding the Right Triangle.................................................

Let’s wrap things up with a problem that combines tuples and list com-
prehensions. We’ll use Haskell to find a right triangle that fits all of these
conditions:

- The lengths of the three sides are all integers.
- The length of each side is less than or equal to 10.
- The triangle’s perimeter (the sum of the side lengths) is equal to 24.

Atriangle is a right triangle if one of its
angles is a right angle (a 90-degree angle).
Right triangles have the useful property
that if you square the lengths of the sides
forming the right angle and then add those
squares, that sum is equal to the square of
the length of the side that’s opposite the
right angle. In the picture, the sides that lie
next to the right angle are labeledaandb,
and the side opposite the right angle is la-
beledc. We call that side the _hypotenuse_.
As a first step, let’s generate all possible triples with elements that are
less than or equal to 10:

ghci>let triples = [ (a,b,c) | c <- [1..10], a <- [1..10], b <- [1..10] ]

We’redrawing from three lists on the right-hand side of the compre-
hension, and the output expression on the left combines them into a list of
triples. If you evaluatetriplesin GHCi, you’ll get a list that is 1,000 entries
long, so we won’t show it here.
Next, we’ll filter out triples that don’t represent right triangles by adding
a predicate that checks to see if the Pythagorean theorem (a^2 + b^2 == c^2)

```
Starting Out 21
```

```
holds.We’ll also modify the function to ensure that sideaisn’t larger than
the hypotenusec, and that sidebisn’t larger than sidea:
```
```
ghci>let rightTriangles = [ (a,b,c) | c <- [1..10], a <- [1..c], b <- [1..a],
a^2 + b^2 == c^2]
```
```
Noticehow we changed the ranges in the lists that we draw values from.
This ensures that we don’t check unnecessary triples, such as ones where
sidebis larger than the hypotenuse (in a right triangle, the hypotenuse is
always the longest side). We also assumed that sidebis never larger than
sidea. This doesn’t harm anything, because for every triple(a,b,c)with
a^2 + b^2 == c^2andb>athat is left out of consideration, the triple(b,a,c)
is included—and is the same triangle, just with the legs reversed. (Other-
wise, our list of results would contain pairs of triangles that are essentially
the same.)
```
```
NOTE In GHCi, you can’t break up definitions and expressions across multiple lines. In this
book, however, we occasionally need to break up a single line so the code can all fit on
the page. (Otherwise the book would have to be really wide, and it wouldn’t fit on any
normal shelf—and then you’d have to buy bigger shelves!)
```
```
We’re almost done. Now, we just need to modify the function to only
output the triangles whose perimeter equals 24:
```
```
ghci>let rightTriangles' = [ (a,b,c) | c <- [1..10], a <- [1..c], b <- [1..a],
a^2 + b^2 == c^2, a+b+c == 24]
ghci> rightTriangles'
[(6,8,10)]
```
```
Andthere’s our answer! This is a common pattern in functional pro-
gramming: you start with a certain set of candidate solutions, and succes-
sively apply transformations and filters to them until you’ve narrowed the
possibilities down to the one solution (or several solutions) that you’re
after.
```
**22** Chapter 1


# 2

## BELIEVE THE TYPE

Oneof Haskell’s greatest
strengths is its powerful type
system.
In Haskell, every expression’s type
is known at compile time, which leads
to safer code. If you write a program
that tries to divide a Boolean type with
a number, it won’t compile. This is
good because it’s better to catch those
kinds of errors at compile time, rather than having your program crash later
on. Everything in Haskell has a type, so the compiler can reason quite a lot
about your program before compiling it.
Unlike Java or Pascal, Haskell has type inference. If we write a number,
for example, we don’t need to tell Haskell it’s a number, because it can infer
that on its own.
So far, we’ve covered some of the basics of Haskell with only a very su-
perficial glance at types, but understanding the type system is a very impor-
tant part of learning Haskell.


## Explicit Type Declaration..........................................................

```
We can use GHCi to examine the types of some expressions. We’ll do that
by using the:tcommand which, followed by any valid expression, tells us its
type. Let’s give it a whirl:
```
```
ghci>:t 'a'
'a' :: Char
ghci> :t True
True :: Bool
ghci> :t "HELLO!"
"HELLO!" :: [Char]
ghci> :t (True, 'a')
(True, 'a') :: (Bool, Char)
ghci> :t 4 == 5
4 == 5 :: Bool
```
```
The::operatorhere is read as “has
type of.” Explicit types are always de-
noted with the first letter in uppercase.
'a'has a type ofChar, which stands for
character .Trueis aBool, or a Boolean
type."HELLO!", which is a string, shows
its type as[Char]. The square brack-
ets denote a list, so we read that as it
being a list of characters. Unlike lists,
each tuple length has its own type.
So the tuple(True, 'a')has a type of
(Bool, Char), and('a','b','c')has a
type of(Char, Char, Char).4 == 5will
always returnFalse, so its type isBool.
Functions also have types. When writing our own functions, we can choose
to give them an explicit type declaration. This is generally considered to be
good practice (except when writing very short functions). From here on,
we’ll give all the functions that we make type declarations.
Remember the list comprehension we made in Chapter 1—the one
that filters out a string’s lowercase letters? Here’s how it looks with a type
declaration:
```
```
removeNonUppercase:: [Char] -> [Char]
removeNonUppercase st = [ c | c <- st, c `elem` ['A'..'Z']]
```
```
TheremoveNonUppercasefunctionhas a type of[Char] -> [Char], meaning
that it takes one string as a parameter and returns another as a result.
```
**24** Chapter 2


```
Buthow do we specify the type of a function that takes several param-
eters? Here’s a simple function that takes three integers and adds them
together:
```
```
addThree:: Int -> Int -> Int -> Int
addThree x y z = x + y + z
```
```
Theparameters and the return type are separated by->characters, with
the return type always coming last in the declaration. (In Chapter 5, you’ll
see why they’re all separated with->, instead of having a more explicit
distinction.)
If you want to give your function a type declaration, but are unsure as to
what it should be, you can always just write the function without it, and then
check it with:t. Since functions are expressions,:tworks on them in the
same way as you saw at the beginning of this section.
```
## Common Haskell Types...........................................................

```
Let’s take a look at some common Haskell types, which are used for repre-
senting basic things like numbers, characters, and Boolean values. Here’s an
overview:
```
- Intstands for integer. It’s used for whole numbers. 7 can be anInt, but
    7.2cannot.Intis _bounded_ , which means that it has a minimum value and
    a maximum value.

```
NOTE We’re using the GHC compiler, where the range ofIntis determined by the size of
a machine word on your computer. So if you have a 64-bit CPU, it’s likely that the
lowestInton your system is  263 , and the highest is 263.
```
- Integeris also used to store integers, but it’s not bounded, so it can be
    used to represent really big numbers. (And I mean _really_ big!) However,
    Intis more efficient. As an example, try saving the following function to
    a file:

```
factorial:: Integer -> Integer
factorial n = product [1..n]
```
```
Thenload it into GHCi with:land test it:
```
```
ghci>factorial 50
30414093201713378043612608166064768844377641568960512000000000000
```
- Floatisa real floating-point number with single precision. Add the fol-
    lowing function to the file you’ve been working in:

```
circumference:: Float -> Float
circumference r = 2*pi*r
```
```
Believe the Type 25
```

```
Thenload and test it:
```
```
ghci>circumference 4.0
25.132742
```
- Doubleisa real floating-point number with double the precision. Double-
    precision numeric types use twice as many bits to represent numbers.
    The extra bits increase their precision at the cost of hogging more mem-
    ory. Here’s another function to add to your file:

```
circumference':: Double -> Double
circumference' r = 2*pi*r
```
```
Nowload and test it. Pay particular attention to the difference in
precision betweencircumferenceandcircumference'.
```
```
ghci>circumference' 4.0
25.132741228718345
```
- Boolisa Boolean type. It can have only two values:TrueandFalse.
- Charrepresents a Unicode character. It’s denoted by single quotes. A list
    of characters is a string.
- Tuples are types, but their definition depends on their length as well as
    the types of their components. So, theoretically, there is an infinite num-
    ber of tuple types. (In practice, tuples can have at most 62 elements—far
    more than you’ll ever need.) Note that the empty tuple()is also a type,
    which can have only a single value:().

## Type Variables...................................................................

```
It makes sense for some functions to be able to operate on various types. For
instance, theheadfunction takes a list and returns the head element of that
list. It doesn’t really matter if the list contains numbers, characters, or even
more lists! The function should be able to work with lists that contain just
about anything.
What do you think the type of theheadfunction is? Let’s check with the
:tfunction:
```
```
ghci>:t head
head :: [a] -> a
```
```
Whatis thisa? Remember that type names start with capital letters, so
it can’t be a type. This is actually an example of a type variable , which means
thatacan be of any type.
```
**26** Chapter 2


```
Typevariables allow functions to operate
on values of various types in a type-safe manner.
This is a lot like generics in other programming
languages. However, Haskell’s version is much
more powerful, since it allows us to easily write
very general functions.
Functions that use type variables are called
polymorphic functions. The type declaration of
headstates that it takes a list of any type and returns one element of that type.
```
```
NOTE Although type variables can have names that are longer than one character, we usually
give them names likea,b,c,d, and so on.
```
```
Rememberfst? It returns the first item in a pair. Let’s examine its type:
```
```
ghci>:t fst
fst :: (a, b) -> a
```
```
Youcan see thatfsttakes a tuple and returns an element that is of the
same type as its first item. That’s why we can usefston a pair that contains
items of any two types. Note that even thoughaandbare different type vari-
ables, they don’t necessarily need to be different types. This just means that
the first item’s type and the return value’s type will be the same.
```
## Type Classes 101................................................................

```
A typeclass is an interface that de-
fines some behavior. If a type is an
instance of a type class, then it sup-
ports and implements the behavior
the type class describes.
More specifically, a type class
specifies a bunch of functions, and
when we decide to make a type
an instance of a type class, we de-
fine what those functions mean for
that type.
A type class that defines equality is a good example. The values of many
types can be compared for equality by using the==operator. Let’s check the
type signature of this operator:
```
```
ghci>:t (==)
(==) :: (Eq a) => a -> a -> Bool
```
```
Notethat the equality operator (==) is actually a function. So are+,*,
```
- ,/, and almost every other operator. If a function is composed of only
special characters, it’s considered an infix function by default. If we want

```
Believe the Type 27
```

```
to examine itstype, pass it to another function, or call it as a prefix function,
we need to surround it in parentheses, as in the preceding example.
This example shows something new: the=>symbol. Everything before
this symbol is called a class constraint. We can read this type declaration like
this: The equality function takes any two values that are of the same type and
returns aBool. The type of those two values must be an instance of theEq
class.
TheEqtype class provides an interface for testing for equality. If it makes
sense for two items of a particular type to be compared for equality, then
that type can be an instance of theEqtype class. All standard Haskell types
(except for input/output types and functions) are instances ofEq.
```
```
NOTE It’s important to note that type classes are not the same as classes in object-oriented
programming languages.
```
```
Let’s look at some of the most common Haskell type classes, which en-
able our types to be easily compared for equality and order, printed as strings,
and so on.
```
## The Eq Type Class.......................................................

```
As we’ve discussed,Eqis used for types that support equality testing. The
functions its instances implement are==and/=. This means that if there’s
anEqclass constraint for a type variable in a function, it uses==or/=some-
where inside its definition. When a type implements a function, that means
it defines what the function does when used with that particular type. Here
are some examples of performing these operations on various instances
ofEq:
```
```
ghci> 5 == 5
True
ghci> 5 /= 5
False
ghci> 'a' == 'a'
True
ghci> "Ho Ho" == "Ho Ho"
True
ghci> 3.432 == 3.432
True
```
## The Ord Type Class......................................................

```
Ordis a type class for types whose values can be put in some order. For exam-
ple, let’s look at the type of the greater-than (>) operator:
```
```
ghci> :t (>)
(>):: (Ord a) => a -> a -> Bool
```
**28** Chapter 2


Thetype of>is similar to the type of==. It takes two items as parameters
and returns aBool, which tells us if some relation between those two things
holds or not.
All the types we’ve covered so far (again, except for functions) are in-
stances ofOrd.Ordcovers all the standard comparison functions such as>,<,
>=, and<=.
Thecomparefunction takes two values whose type is anOrdinstance and
returns anOrdering.Orderingis a type that can beGT,LT, orEQ, which repre-
sent greater than, lesser than, or equal, respectively.

ghci>"Abrakadabra" < "Zebra"
True
ghci> "Abrakadabra" `compare` "Zebra"
LT
ghci> 5 >= 2
True
ghci> 5 `compare` 3
GT
ghci> 'b' > 'a'
True

## The Show Type Class.....................................................

Values whose types are instances of theShowtype class can be represented
as strings. All the types we’ve covered so far (except for functions) are in-
stances ofShow. The most commonly used function that operates on instances
of this type class isshow, which prints the given value as a string:

ghci>show 3
"3"
ghci> show 5.334
"5.334"
ghci> show True
"True"

## The Read Type Class.....................................................

Readcan be considered the opposite type class ofShow. Again, all the types
we’ve covered so far are instances of this type class. Thereadfunction takes a
string and returns a value whose type is an instance ofRead:

ghci>read "True" || False
True
ghci> read "8.2" + 3.8
12.0
ghci> read "5" - 2
3

```
Believe the Type 29
```

```
ghci>read "[1,2,3,4]" ++ [3]
[1,2,3,4,3]
```
```
Sofar so good. But what happens if we try enteringread "4"?
```
```
ghci>read "4"
<interactive>:1:0:
Ambiguous type variable 'a' in the constraint:
'Read a' arising from a use of 'read' at <interactive>:1:0-7
Probable fix: add a type signature that fixes these type variable(s)
```
```
GHCiis telling us that it doesn’t know what we want in return. Notice
that in the previous uses ofread, we did something with the result afterward,
which let GHCi infer the kind of result we wanted. If we used it as a Boolean,
for example, it knew it had to return aBool. But now it knows we want some
type that is part of theReadclass, but it doesn’t know which one. Let’s take a
look at the type signature ofread:
```
```
ghci>:t read
read :: (Read a) => String -> a
```
```
NOTE Stringisjust another name for[Char].Stringand[Char]can be used interchange-
ably, but we’ll mostly be sticking toStringfrom now on because it’s easier to write and
more readable.
```
```
We can see that thereadfunction returns a value whose type is an in-
stance ofRead, but if we use that result in some way, it has no way of knowing
which type. To solve this problem, we can use type annotations.
Type annotations are a way to explicitly tell Haskell what the type of an
expression should be. We do this by adding::to the end of the expression
and then specifying a type:
```
```
ghci>read "5" :: Int
5
ghci> read "5" :: Float
5.0
ghci> (read "5" :: Float)* 4
20.0
ghci> read "[1,2,3,4]" :: [Int]
[1,2,3,4]
ghci> read "(3, 'a')" :: (Int, Char)
(3, 'a')
```
```
Thecompiler can infer the type of most expressions by itself. However,
sometimes the compiler doesn’t know whether to return a value of type
IntorFloatfor an expression likeread "5". To see what the type is, Haskell
would need to actually evaluateread "5". But since Haskell is a statically
```
**30** Chapter 2


typedlanguage, it needs to know all the types before the code is compiled
(or in the case of GHCi, evaluated). So we need to tell Haskell, “Hey, this
expression should have this type, in case you didn’t know!”
We can give Haskell only the minimum amount of information it needs
to figure out which type of valuereadshould return. For instance, if we’re
usingreadand then cramming its result into a list, Haskell can use the list to
figure out which type we want by looking at the other elements of the list:

ghci>[read "True", False, True, False]
[True, False, True, False]

Sincewe usedread "True"as an element in a list ofBoolvalues, Haskell
sees that the type ofread "True"must also beBool.

## The Enum Type Class.....................................................

Enuminstances are sequentially ordered types—their values can be enumer-
ated. The main advantage of theEnumtype class is that we can use its values
in list ranges. They also have defined successors and predecessors, which we
can get with thesuccandpredfunctions. Some examples of types in this class
are(),Bool,Char,Ordering,Int,Integer,Float, andDouble.

ghci>['a'..'e']
"abcde"
ghci> [LT .. GT]
[LT,EQ,GT]
ghci> [3 .. 5]
[3,4,5]
ghci> succ 'B'
'C'

## The Bounded Type Class..................................................

Instances of theBoundedtype class have an upper bound and a lower bound,
which can be checked by using theminBoundandmaxBoundfunctions:

ghci>minBound :: Int
-2147483648
ghci> maxBound :: Char
'\1114111'
ghci> maxBound :: Bool
True
ghci> minBound :: Bool
False

TheminBoundandmaxBoundfunctionsare interesting because they have a
type of(Bounded a) => a. In a sense, they are polymorphic constants.

```
Believe the Type 31
```

```
Notethat tuples whose components are all instances ofBoundedare also
considered to be instances ofBoundedthemselves:
```
```
ghci>maxBound :: (Bool, Int, Char)
(True,2147483647,'\1114111')
```
## The Num Type Class.....................................................

```
Numis a numeric type class. Its instances can act like numbers. Let’s examine
the type of a number:
```
```
ghci>:t 20
20 :: (Num t) => t
```
```
Itappears that whole numbers are also polymorphic constants. They can
act like any type that’s an instance of theNumtype class (Int,Integer,Float, or
Double):
```
```
ghci>20 :: Int
20
ghci> 20 :: Integer
20
ghci> 20 :: Float
20.0
ghci> 20 :: Double
20.0
```
```
Forexample, we can examine the type of the*operator:
```
```
ghci>:t (*)
(*) :: (Num a) => a -> a -> a
```
```
Thisshows that*accepts two numbers and returns a number of the
same type. Because of this type constraint,(5 :: Int)*(6 :: Integer)will
```
result in a type error, while (^5) *(6 :: Integer)will work just fine. 5 can act
like either anIntegeror anInt, but not both at the same time.
To be an instance ofNum, a type must already be inShowandEq.

## The Floating Type Class..................................................

```
TheFloatingtype class includes theFloatandDoubletypes, which are used to
store floating-point numbers.
Functions that take and return values that are instances of theFloating
type class need their results to be represented with floating-point numbers in
order to do meaningful computations. Some examples aresin,cos, andsqrt.
```
**32** Chapter 2


## The Integral Type Class...................................................

```
Integralis another numeric type class. WhileNumincludes all numbers, in-
cluding real number integers, theIntegralclass includes only integral (whole)
numbers. This type class includes theIntandIntegertypes.
One particularly useful function for dealing with numbers isfromIntegral.
It has the following type declaration:
```
```
fromIntegral:: (Num b, Integral a) => a -> b
```
**NOTE** _NoticethatfromIntegralhas several class constraints in its type signature. That’s
completely valid—multiple class constraints are separated by commas inside the
parentheses._

```
From its type signature, we can see thatfromIntegraltakes an integral
number and turns it into a more general number. This is very useful when
you want integral and floating-point types to work together nicely. For in-
stance, thelengthfunction has this type declaration:
```
```
length:: [a] -> Int
```
```
Thismeans that if we try to get the length of a list and add it to3.2, we’ll
get an error (because we tried to add anIntto a floating-point number).
To get around this, we can usefromIntegral, like this:
```
```
ghci>fromIntegral (length [1,2,3,4]) + 3.2
7.2
```
## Some Final Notes on Type Classes

```
Because a type class defines an abstract interface, one type can be an in-
stance of many type classes, and one type class can have many types as in-
stances. For example, theChartype is an instance of many type classes, two
of them beingEqandOrd, because we can check if two characters are equal
as well as compare them in alphabetical order.
Sometimes a type must first be an instance of one type class to be al-
lowed to become an instance of another. For example, to be an instance
ofOrd, a type must first be an instance ofEq. In other words, being an in-
stance ofEqis a prerequisite for being an instance ofOrd. This makes sense if
you think about it, because if you can compare two things for ordering, you
should also be able to tell if those things are equal.
```
```
Believe the Type 33
```


# 3

## SYNTAX IN FUNCTIONS

```
In this chapter, we’ll take a look at the syntax that en-
ables you to write Haskell functions in a readable and
sensible manner. We’ll look at how to quickly decon-
struct values, avoid bigif elsechains, and store the
results of intermediate computations so that you can
reuse them multiple times.
```
## Pattern Matching.................................................................

```
Pattern matching is used to specify patterns to which
some data should conform and to deconstruct the
data according to those patterns.
When defining functions in Haskell, you can
create separate function bodies for different pat-
terns. This leads to simple, readable code. You
can pattern match on pretty much any data type—
```

```
numbers,characters, lists, tuples, and so on. For example, let’s write a sim-
ple function that checks if the number we pass to it is a 7:
```
```
lucky:: Int -> String
lucky 7 = "LUCKY NUMBER SEVEN!"
lucky x = "Sorry, you're out of luck, pal!"
```
```
Whenyou calllucky, the patterns will be checked from top to bottom.
When the passed argument conforms to a specified pattern, the correspond-
ing function body will be used. The only way a number can conform to the
first pattern here is if it is a 7. In that case, the function body"LUCKY NUMBER
SEVEN!"is used. If it’s not a 7, it falls through to the second pattern, which
matches anything and binds it tox.
When we use a name that starts with a lowercase letter (likex,y, or
myNumber) in our pattern instead of an actual value (like 7 ), it will act as a
catchall pattern. That pattern will always match the supplied value, and we
will be able to refer to that value by the name that we used for the pattern.
The sample function could have also been easily implemented by using
anifexpression. However, what if we wanted to write a function that takes a
number and prints it out as a word if it’s between 1 and 5; otherwise, it prints
"Not between 1 and 5"? Without pattern matching, we would need to make a
pretty convolutedif/then/elsetree. However, pattern matching makes this a
simple function to write:
```
```
sayMe:: Int -> String
sayMe 1 = "One!"
sayMe 2 = "Two!"
sayMe 3 = "Three!"
sayMe 4 = "Four!"
sayMe 5 = "Five!"
sayMe x = "Not between 1 and 5"
```
```
Notethat if we moved the last pattern (sayMe x) to the top, the function
would always print"Not between 1 and 5", because the numbers wouldn’t have
a chance to fall through and be checked for any other patterns.
Remember the factorial function we implemented in the previous chap-
ter? We defined the factorial of a numbernasproduct [1..n]. We can also
define a factorial function recursively. A function is defined recursively if it
calls itself inside its own definition. The factorial function is usually defined
this way in mathematics. We start by saying that the factorial of 0 is 1. Then
we state that the factorial of any positive integer is that integer multiplied by
the factorial of its predecessor. Here’s how that looks translated into Haskell
terms:
```
```
factorial:: Int -> Int
factorial 0 = 1
factorial n = n*factorial (n - 1)
```
**36** Chapter 3


```
Thisis the first time we’ve defined a function recursively. Recursion is
important in Haskell, and we’ll take a closer look at it in Chapter 4.
Pattern matching can also fail. For instance, we can define a function
like this:
```
```
charName:: Char -> String
charName 'a' = "Albert"
charName 'b' = "Broseph"
charName 'c' = "Cecil"
```
```
Thisfunction seems to work fine at first. However, if we try to call it with
an input that it didn’t expect, we get an error:
```
ghci>charName 'a'
"Albert"
ghci> charName 'b'
"Broseph"
ghci> charName 'h'
"***Exception: tut.hs:(53,0)-(55,21): Non-exhaustive patterns in function charName

```
Itcomplains that we have “non-exhaustive patterns,” and rightfully so.
When making patterns, we should always include a catchall pattern at the
end so our program doesn’t crash if we get some unexpected input.
```
## Pattern Matching with Tuples..............................................

```
Pattern matching can also be used on tuples. What if we wanted to write a
function that takes two vectors in 2D space (represented as pairs) and adds
them together? (To add two vectors, we add their x components separately
and their y components separately.) Here’s how we might have done this if
we didn’t know about pattern matching:
```
```
addVectors:: (Double, Double) -> (Double, Double) -> (Double, Double)
addVectors a b = (fst a + fst b, snd a + snd b)
```
```
Well,that works, but there’s a better way to do it. Let’s modify the func-
tion so that it uses pattern matching:
```
```
addVectors:: (Double, Double) -> (Double, Double) -> (Double, Double)
addVectors (x1, y1) (x2, y2) = (x1 + x2, y1 + y2)
```
```
Thisis much better. It makes it clear that the parameters are tuples, and
increases readability by giving names to the tuple components right away.
Note that this is already a catchall pattern. The type ofaddVectorsis the same
in both cases, so we are guaranteed to get two pairs as parameters:
```
```
ghci>:t addVectors
addVectors :: (Double, Double) -> (Double, Double) -> (Double, Double)
```
```
Syntax in Functions 37
```

```
fstandsndextractthe components of pairs. But what about triples?
Well, there are no provided functions to extract the third component in a
triple, but we can make our own:
```
```
first:: (a, b, c) -> a
first (x, _, _) = x
```
```
second :: (a, b, c) -> b
second (_, y, _) = y
```
```
third :: (a, b, c) -> c
third (_, _, z) = z
```
```
The_charactermeans the same thing it does in list comprehensions.
We really don’t care about that part, so we just use a_to represent a generic
variable.
```
## Pattern Matching with Lists and List Comprehensions.........................

```
You can also use pattern matching in list comprehensions, like this:
```
```
ghci>let xs = [(1,3),(4,3),(2,4),(5,3),(5,6),(3,1)]
ghci> [a+b | (a, b) <- xs]
[4,7,6,8,11,4]
```
```
Ifa pattern match fails, the list comprehension will just move on to the
next element, and the element that failed won’t be included in the result-
ing list.
Regular lists can also be used in pattern matching. You can match with
the empty list[]or any pattern that involves:and the empty list. (Remem-
ber that[1,2,3]is just syntactic sugar for1:2:3:[].) A pattern likex:xswill
bind the head of the list toxand the rest of it toxs. If the list has only a sin-
gle element, thenxswill simply be the empty list.
```
```
NOTE Haskell programmers use thex:xspattern often, especially with recursive functions.
However, patterns that include the:character will match only against lists of length
one or more.
```
```
Now that we’ve looked at how to pattern match against lists, let’s make
our own implementation of theheadfunction:
```
```
head':: [a] -> a
head' [] = error "Can't call head on an empty list, dummy!"
head' (x:_) = x
```
**38** Chapter 3


```
Afterloading the function, we can test it, like this:
```
ghci>head' [4,5,6]
4
ghci> head' "Hello"
'H'

Noticethat if we want to bind something to several variables (even if
one of them is just_), we must surround them in parentheses so Haskell can
properly parse them.
Also notice the use of theerrorfunction. This function takes a string as
an argument and generates a runtime error using that string. It essentially
crashes your program, so it’s not good to use it too much. (But callinghead
on an empty list just doesn’t make sense!)
As another example, let’s write a simple function that takes a list and
prints its elements out in a wordy, inconvenient format:

tell:: (Show a) => [a] -> String
tell [] = "The list is empty"
tell (x:[]) = "The list has one element: " ++ show x
tell (x:y:[]) = "The list has two elements: " ++ show x ++ " and " ++ show y
tell (x:y:_) = "This list is long. The first two elements are: " ++ show x
++ " and " ++ show y

Notethat(x:[])and(x:y:[])could be rewritten as[x]and[x,y]. How-
ever, we can’t rewrite(x:y:_)using square brackets, because it matches any
list of length 2 or more.
Here are some examples of using this function:

ghci>tell [1]
"The list has one element: 1"
ghci> tell [True,False]
"The list has two elements: True and False"
ghci> tell [1,2,3,4]
"This list is long. The first two elements are: 1 and 2"
ghci> tell []
"The list is empty"

Thetellfunctionis safe to use because it can match to the empty list,
a singleton list, a list with two elements, and a list with more than two ele-
ments. It knows how to handle lists of any length, and so it will always return
a useful value.

```
Syntax in Functions 39
```

```
Howabout if instead we defined a function that only knows how to han-
dle lists with three elements? Here’s an example of such a function:
```
```
badAdd:: (Num a) => [a] -> a
badAdd (x:y:z:[]) = x + y + z
```
```
Here’swhat happens when we give it a list that it doesn’t expect:
```
```
ghci>badAdd [100,20]
***Exception: examples.hs:8:0-25: Non-exhaustive patterns in function badAdd
```
```
Yikes!Not cool! If this happened inside a compiled program instead of
in GHCi, the program would crash.
One final thing to note about pattern matching with lists: You can’t
use the++operator in pattern matches. (Remember that the++operator
joins two lists into one.) For instance, if you tried to pattern match against
(xs ++ ys), Haskell wouldn’t be able to tell what would be in thexslist and
what would be in theyslist. Though it seems logical to match stuff against
(xs ++ [x,y,z]), or even just(xs ++ [x]), because of the nature of lists, you
can’t.
```
## As-patterns..............................................................

```
There’s also a special type of pattern called an as-pattern. As-patterns allow
you to break up an item according to a pattern, while still keeping a refer-
ence to the entire original item. To create an as-pattern, precede a regular
pattern with a name and an@character.
For instance, we can create the following as-pattern:xs@(x:y:ys). This
pattern will match exactly the same lists thatx:y:yswould, but you can easily
access the entire original list usingxs, instead of needing to type outx:y:ys
every time. Here’s an example of a simple function that uses an as-pattern:
```
```
firstLetter:: String -> String
firstLetter "" = "Empty string, whoops!"
firstLetter all@(x:xs) = "The first letter of " ++ all ++ " is " ++ [x]
```
```
Afterloading the function, we can test it as follows:
```
```
ghci>firstLetter "Dracula"
"The first letter of Dracula is D"
```
## Guards, Guards!.................................................................

```
We use patterns to check if the values passed to our functions are constructed
in a certain way. We use guards when we want our function to check if some
property of those passed values is true or false. That sounds a lot like anif
```
**40** Chapter 3


```
expression,and it is very similar. However, guards are a lot
more readable when you have several conditions, and they
play nicely with patterns.
Let’s dive in and write a function that uses guards. This
function will berate you in different ways depending on
your body mass index (BMI). Your BMI is calculated by di-
viding your weight (in kilograms) by your height (in me-
ters) squared. If your BMI is less than 18.5, you’re consid-
ered underweight. If it’s anywhere from 18.5 to 25, you’re
considered normal. A BMI of 25 to 30 is overweight, and
more than 30 is obese. (Note that this function won’t actu-
ally calculate your BMI; it just takes it as an argument and
then tells you off.) Here’s the function:
```
```
bmiTell:: => Double -> String
bmiTell bmi
| bmi <= 18.5 = "You're underweight, you emo, you!"
| bmi <= 25.0 = "You're supposedly normal. Pffft, I bet you're ugly!"
| bmi <= 30.0 = "You're fat! Lose some weight, fatty!"
| otherwise = "You're a whale, congratulations!"
```
```
Aguard is indicated by a pipe character (|), followed by a Boolean ex-
pression, followed by the function body that will be used if that expression
evaluates toTrue. If the expression evaluates toFalse, the function drops
through to the next guard, and the process repeats. Guards must be in-
dented by at least one space. (I like to indent them by four spaces so that
the code is more readable.)
For instance, if we call this function with a BMI of 24.3, it will first check
if that’s less than or equal to 18.5. Because it isn’t, it falls through to the next
guard. The check is carried out with the second guard, and because 24.3 is
less than 25.0, the second string is returned.
Guards are very reminiscent of a bigif/elsetree in imperative languages,
though they’re far more readable. While bigif/elsetrees are usually frowned
upon, sometimes a problem is defined in such a discrete way that you can’t
get around them. Guards are a very nice alternative in these cases.
Many times, the last guard in a function isotherwise, which catches ev-
erything. If all the guards in a function evaluate toFalse, and we haven’t
provided anotherwisecatchall guard, evaluation falls through to the next
pattern. (This is how patterns and guards play nicely together.) If no suit-
able guards or patterns are found, an error is thrown.
Of course, we can also use guards with functions that take multiple pa-
rameters. Let’s modifybmiTellso that it takes a height and weight, and calcu-
lates the BMI for us:
```
bmiTell:: Double -> Double -> String
bmiTell weight height
| weight / height ^ 2 <= 18.5 = "You're underweight, you emo, you!"
| weight / height ^ 2 <= 25.0 = "You're supposedly normal. Pffft, I bet you're ugly!"

```
Syntax in Functions 41
```

```
|weight / height ^ 2 <= 30.0 = "You're fat! Lose some weight, fatty!"
| otherwise = "You're a whale, congratulations!"
```
```
Now,let’s see if I’m fat:
```
```
ghci>bmiTell 85 1.90
"You're supposedly normal. Pffft, I bet you're ugly!"
```
```
Yay!I’m not fat! But Haskell just called me ugly. Whatever!
```
```
NOTE A common newbie mistake is to put an equal sign (=) after the function name and
parameters, before the first guard. This will cause a syntax error.
```
```
As another simple example, let’s implement our ownmaxfunction to
compare two items and return the larger one:
```
```
max':: (Ord a) => a -> a -> a
max' a b
| a <= b = b
| otherwise = a
```
```
Wecan also implement our owncomparefunction using guards:
```
```
myCompare:: (Ord a) => a -> a -> Ordering
a `myCompare` b
| a == b = EQ
| a <= b = LT
| otherwise = GT
```
```
ghci>3 `myCompare` 2
GT
```
```
NOTE Notonly can we call functions as infix with backticks, we can also define them using
backticks. Sometimes this makes them easier to read.
```
## where?!.........................................................................

```
When programming, we usually want to avoid calculating the same value
over and over again. It’s much easier to calculate something only once and
store the result. In imperative programming languages, you would solve this
problem by storing the result of a computation in a variable. In this section,
you’ll learn how to use Haskell’swherekeyword to store the results of inter-
mediate computations, which provides similar functionality.
```
**42** Chapter 3


```
Inthe previous section, we defined a BMI calculator function like this:
```
bmiTell:: Double -> Double -> String
bmiTell weight height
| weight / height ^ 2 <= 18.5 = "You're underweight, you emo, you!"
| weight / height ^ 2 <= 25.0 = "You're supposedly normal. Pffft, I bet you're ugly!"
| weight / height ^ 2 <= 30.0 = "You're fat! Lose some weight, fatty!"
| otherwise = "You're a whale, congratulations!"

```
Noticethat we repeat the BMI calculation three times in this code. We
can avoid this by using thewherekeyword to bind that value to a variable and
then using that variable in place of the BMI calculation, like this:
```
```
bmiTell:: Double -> Double -> String
bmiTell weight height
| bmi <= 18.5 = "You're underweight, you emo, you!"
| bmi <= 25.0 = "You're supposedly normal. Pffft, I bet you're ugly!"
| bmi <= 30.0 = "You're fat! Lose some weight, fatty!"
| otherwise = "You're a whale, congratulations!"
where bmi = weight / height ^ 2
```
```
Weput thewherekeyword after the guards and then use it to define
one or more variables or functions. These names are visible across all the
guards. If we decide that we want to calculate BMI a bit differently, we need
to change it only once. This technique also improves readability by giving
names to things, and it can even make our programs faster, since our values
are calculated just once.
If we wanted to, we could even go a bit overboard and write our function
like this:
```
```
bmiTell:: Double -> Double -> String
bmiTell weight height
| bmi <= skinny = "You're underweight, you emo, you!"
| bmi <= normal = "You're supposedly normal. Pffft, I bet you're ugly!"
| bmi <= fat = "You're fat! Lose some weight, fatty!"
| otherwise = "You're a whale, congratulations!"
where bmi = weight / height ^ 2
skinny = 18.5
normal = 25.0
fat = 30.0
```
```
NOTE Noticethat all the variable names are aligned in a single column. If you don’t align
them like this, Haskell will get confused, and it won’t know that they’re all part of the
same block.
```
```
Syntax in Functions 43
```

## where’s Scope...........................................................

```
The variables we define in thewheresection of a function are visible only to
that function, so we don’t need to worry about them polluting the name-
space of other functions. If we want to use a variable like this in several dif-
ferent functions, we must define it globally.
Also,wherebindings are not shared across function bodies of different
patterns. For instance, suppose we want to write a function that takes a name
and greets the person nicely if it recognizes that name, but not so nicely if it
doesn’t. We might define it like this:
```
```
greet:: String -> String
greet "Juan" = niceGreeting ++ " Juan!"
greet "Fernando" = niceGreeting ++ " Fernando!"
greet name = badGreeting ++ " " ++ name
where niceGreeting = "Hello! So very nice to see you,"
badGreeting = "Oh! Pfft. It's you."
```
```
Thisfunction won’t work as written. Becausewherebindings aren’t shared
across function bodies of different patterns, only the last function body sees
the greetings defined by thewherebinding. To make this function work cor-
rectly,badGreetingandniceGreetingmust be defined globally, like this:
```
```
badGreeting:: String
badGreeting = "Oh! Pfft. It's you."
```
```
niceGreeting :: String
niceGreeting = "Hello! So very nice to see you,"
```
```
greet :: String -> String
greet "Juan" = niceGreeting ++ " Juan!"
greet "Fernando" = niceGreeting ++ " Fernando!"
greet name = badGreeting ++ " " ++ name
```
## Pattern Matching with where..............................................

```
You can also usewherebindings to pattern match. We could have written the
wheresection of our BMI function like this:
```
```
...
wherebmi = weight / height ^ 2
(skinny, normal, fat) = (18.5, 25.0, 30.0)
```
```
Asan example of this technique, let’s write a function that gets a first
name and last name, and returns the initials:
```
```
initials:: String -> String -> String
initials firstname lastname = [f] ++ ". " ++ [l] ++ "."
```
**44** Chapter 3


```
where(f:_) = firstname
(l:_) = lastname
```
```
Wecould have also done this pattern matching directly in the function’s
parameters (it would have been shorter and more readable), but this exam-
ple shows that it’s possible to do it in thewherebindings as well.
```
## Functions in where Blocks.................................................

```
Just as we’ve defined constants inwhereblocks, we can also define functions.
Staying true to our healthy programming theme, let’s make a function that
takes a list of weight/height pairs and returns a list of BMIs:
```
```
calcBmis:: [(Double, Double)] -> [Double]
calcBmis xs = [bmi w h | (w, h) <- xs]
where bmi weight height = weight / height ^ 2
```
```
Andthat’s all there is to it! The reason we needed to introducebmias
a function in this example is that we can’t just calculate one BMI from the
function’s parameters. We need to examine the list passed to the function,
and there’s a different BMI for every pair in there.
```
## let It Be..........................................................................

```
letexpressionsare very similar towhere
bindings.whereallows you bind to vari-
ables at the end of a function, and those
variables are visible to the entire function,
including all its guards.letexpressions,
on the other hand, allow you to bind to
variables anywhere and are expressions
themselves. However, they’re very local,
and they don’t span across guards. Just
like any Haskell construct that’s used to
bind values to names,letexpressions can
be used in pattern matching.
Now let’s seeletin action. The following function returns a cylinder’s
surface area, based on its height and radius:
```
```
cylinder:: Double -> Double -> Double
cylinder r h =
let sideArea = 2*pi*r*h
topArea = pi*r^2
in sideArea + 2*topArea
```
```
letexpressionstake the form oflet <bindings> in <expression>. The vari-
ables that you define withletare visible within the entireletexpression.
```
```
Syntax in Functions 45
```

```
Yes,we could have also defined this with awherebinding. So what’s the
difference between the two? At first, it seems that the only difference is that
letputs the bindings first and the expression later, whereas it’s the other
way around withwhere.
Really, the main difference between the two is thatletexpressions
are... well... expressions, whereaswherebindings aren’t. If something is
an expression, then it has a value."boo!"is an expression, as are3+5and
head [1,2,3]. This means that you can useletexpressions almost anywhere
in your code, like this:
```
ghci> (^4) *(let a = 9 in a + 1) + 2
42
Hereare a few other useful ways to useletexpressions:

- They can be used to introduce functions in a local scope:

```
ghci>[let square x = x*x in (square 5, square 3, square 2)]
[(25,9,4)]
```
- They can be separated with semicolons, which is helpful when you want
    to bind several variables inline and can’t align them in columns:

```
ghci>(let a = 100; b = 200; c = 300 in a*b*c, let foo="Hey "; bar = "there!" in foo ++ bar)
(6000000,"Hey there!")
```
- Pattern matching withletexpressions can be very useful for quickly dis-
    mantling a tuple into components and binding those components to
    names, like this:

```
ghci>(let (a, b, c) = (1, 2, 3) in a+b+c)* 100
600
```
```
Here,we use aletexpression with a pattern match to deconstruct
the triple(1,2,3). We call its first componenta, its second component
b, and its third componentc. Thein a+b+cpart says that the wholelet
expression will have the value ofa+b+c. Finally, we multiply that value
by 100.
```
- You can useletexpressions inside list comprehensions. We’ll take a
    closer look at this next.

```
Ifletexpressions are so cool, why not use them all the time? Well, since
letexpressions are expressions, and are fairly local in their scope, they can’t
be used across guards. Also, some people preferwherebindings because their
variables are defined after the function they’re being used in, rather than
before. This allows the function body to be closer to its name and type dec-
laration, which can make for more readable code.
```
**46** Chapter 3


## let in List Comprehensions

Let’s rewrite our previous example of calculating lists of weight/height pairs,
but we’ll use aletexpression inside a list comprehension instead of defining
an auxiliary function withwhere:

calcBmis:: [(Double, Double)] -> [Double]
calcBmis xs = [bmi | (w, h) <- xs, let bmi = w / h ^ 2]

Eachtime the list comprehension takes a tuple from the original list and
binds its components towandh, theletexpression bindsw/h^2to the
namebmi. Then we just presentbmias the output of the list comprehension.
We include aletinside a list comprehension much as we would use a
predicate, but instead of filtering the list, it only binds values to names. The
names defined in thisletare visible to the output (the part before the|)
and everything in the list comprehension that comes after thelet. So, us-
ing this technique, we could make our function return only the BMIs of fat
people, like this:

calcBmis:: [(Double, Double)] -> [Double]
calcBmis xs = [bmi | (w, h) <- xs, let bmi = w / h ^ 2, bmi > 25.0]

The(w,h) <- xspart of the list comprehension is called the _generator_.
We can’t refer to thebmivariable in the generator, because that is defined
prior to theletbinding.

## let in GHCi..............................................................

Theinpart of the binding can also be omitted when defining functions
and constants directly in GHCi. If we do that, then the names will be visible
throughout the entire interactive session:

ghci>let zoot x y z = x*y+z
ghci> zoot 3 9 2
29
ghci> let boot x y z = x*y + z in boot 3 4 2
14
ghci> boot
<interactive>:1:0: Not in scope: `boot'

Becausewe omitted theinpart in our first line, GHCi knows that we’re
not usingzootin that line, so it remembers it for the rest of the session. How-
ever, in the secondletexpression, we included theinpart and calledboot
immediately with some parameters. Aletexpression that doesn’t leave out
theinpart is an expression in itself and represents a value, so GHCi just
printed that value.

```
Syntax in Functions 47
```

## case Expressions.................................................................

```
caseexpressions allow youto execute blocks of
code for specific values of a particular variable.
Essentially, they are a way to use pattern match-
ing almost anywhere in your code. Many lan-
guages (like C, C++, and Java) have some kind
of case statement, so you may already be familiar
with the concept.
Haskell takes that concept and one-ups it.
As the name implies,caseexpressions are expres-
sions, much likeif elseexpressions andletexpressions. Not only can we
evaluate expressions based on the possible cases of the value of a variable,
we can also do pattern matching.
This is very similar to performing pattern matching on parameters in
function definitions, where you take a value, pattern match it, and evaluate
pieces of code based on that value. In fact, that kind of pattern matching
is just syntactic sugar forcaseexpressions. For example, the following two
pieces of code do the same thing and are interchangeable:
```
```
head' :: [a]-> a
head' [] = error "No head for empty lists!"
head' (x:_) = x
```
```
head' :: [a]-> a
head' xs = case xs of [] -> error "No head for empty lists!"
(x:_) -> x
```
```
Here’s the syntaxfor acaseexpression:
```
```
case expression of pattern -> result
pattern -> result
pattern -> result
...
```
```
This is prettysimple. The first pattern that matches the expression is
used. If it falls through the wholecaseexpression and no suitable pattern is
found, a runtime error occurs.
Pattern matching on function parameters can be done only when defin-
ing functions, butcaseexpressions can be used anywhere. For instance, you
can use them to perform pattern matching in the middle of an expression,
like this:
```
```
describeList :: [a]-> String
describeList ls = "The list is " ++ case ls of [] -> "empty."
[x] -> "a singleton list."
xs -> "a longer list."
```
**48** Chapter 3


Here,thecaseexpression works like this:lsis first checked against the
pattern of an empty list. Iflsis empty, the wholecaseexpression then as-
sumes the value of"empty". Iflsis not an empty list, then it’s checked against
the pattern of a list with a single element. If the pattern match succeeds, the
caseexpression then has the value of"a singleton list". If neither of those
two patterns match, then the catchall pattern,xs, applies. Finally, the re-
sult of thecaseexpression is joined together with the string"The list is".
Eachcaseexpression represents a value. That’s why we were able to use++
between the string"The list is"and ourcaseexpression.
Because pattern matching in function definitions is the same as us-
ingcaseexpressions, we could have also defined thedescribeListfunction
like this:

describeList:: [a] -> String
describeList ls = "The list is " ++ what ls
where what [] = "empty."
what [x] = "a singleton list."
what xs = "a longer list."

Thisfunction acts just like the one in the previous example, although we
used a different syntactic construct to define it. The functionwhatgets called
withls, and then the usual pattern-matching action takes place. Once this
function returns a string, it’s joined with"The list is".

```
Syntax in Functions 49
```


# 4

## HELLO RECURSION!

In this chapter, we’ll take a look at recursion. We’ll

learn why it’s important in Haskell programming and

how we can find very concise and elegant solutions to

problems by thinking recursively.

Recursionis a way of defining func-
tions in which a function is applied in-
side its own definition. In other words,
the function calls itself. If you still don’t
know what recursion is, read this sen-
tence. (Haha! Just kidding!)
Kidding aside, the strategy of a re-
cursively defined function is to break
down the problem at hand into smaller
problems of the same kind and then
try to solve those subproblems, breaking them down further if necessary.
Eventually we reach the _base case_ (or base cases) of the problem, which can’t
be broken down any more and whose solutions need to be explicitly (non-
recursively) defined by the programmer.
Definitions in mathematics are often recursive. For instance, we can
specify the _Fibonacci sequence_ recursively as follows: We define the first two
Fibonacci numbers directly by saying thatF(0) = 0andF(1) = 1, meaning


```
thatthe zeroth and first Fibonacci numbers are 0 and 1, respectively. These
are our base cases.
Then we specify that for any natural number other than 0 or 1, the cor-
responding Fibonacci number is the sum of the previous two Fibonacci num-
bers. In other words,F(n)=F(n1) +F(n2). For example,F(3)is
F(2) +F(1), which in turn breaks down as(F(1) +F(0)) +F(1). Because
we’ve now come down to nothing but nonrecursively defined Fibonacci
numbers, we can safely say that the value ofF(3)is 2.
Recursion is important in Haskell because, unlike with imperative lan-
guages, you do computations in Haskell by declaring what something is
rather than specifying how you compute it. That’s why Haskell isn’t about
issuing your computer a sequence of steps to execute, but rather about di-
rectly defining what the desired result is, often in a recursive manner.
```
## Maximum Awesome..............................................................

```
Let’s take a look at an existing Haskell function and see how we can
write the function ourselves if we shift our brains into the “R” gear (for
“recursion”).
Themaximumfunction takes a list of things that can be put in order (i.e.,
instances of theOrdtype class) and returns the largest of them. It can be ex-
pressed very elegantly using recursion.
Before we discuss a recursive solution, think about how you might imple-
ment themaximumfunction imperatively. You’d probably set up a variable to
hold the current maximum value, then you’d loop through every element
of the list. If the current element is bigger than the current maximum value,
you’d replace the maximum value with that element. The maximum value
that remains at the end of the loop would be the final result.
Now let’s see how we’d define it recursively. First, we need to define a
base case: We say that the maximum of a singleton list is equal to the only
element in it. But what if the list has more than one element? Well, then we
check which is bigger: the first element (the head) or the maximum of the
rest of the list (the tail). Here’s the code for our recursivemaximum'function:
```
```
maximum':: (Ord a) => [a] -> a
maximum' [] = error "maximum of empty list!"
maximum' [x] = x
maximum' (x:xs) = max x (maximum' xs)
```
```
Asyou can see here, pattern matching is really useful for defining re-
cursive functions. Being able to match and deconstruct values makes it easy
to break down the maximum-finding problem into the relevant cases and
recursive subproblems.
The first pattern says that if the list is empty, the program should crash.
This makes sense, because we just can’t say what the maximum of an empty
list is. The second pattern says that ifmaximum'is passed a singleton list, it
should just return that list’s only element.
```
**52** Chapter 4


```
Ourthird pattern represents the meat of the recursion. The list is split
into a head and a tail. We call the headxand the tailxs. Then, we make use
of our old friend, themaxfunction. Themaxfunction takes two things and re-
turns whichever of them is larger. Ifxis larger than the largest element inxs,
our function will returnx, otherwise it will return the largest element inxs.
But how does ourmaximum'find the largest element inxs? Simple—by calling
itself, recursively!
```
```
Let’swork through this code with a specific example, just in case you’re
having trouble visualizing howmaximum'works. If we callmaximum'on[2,5,1],
the first two patterns don’t match the function call. However, the third pat-
tern does, so the list value is split into 2 and[5,1], andmaximum'is called
with[5,1].
For this new call tomaximum',[5,1]matches the third pattern, and once
again the input list is split—this time into 5 and[1]—andmaximum'is recur-
sively called on[1]. This is a singleton list, so the newest call now matches
one of our base cases and returns 1 as a result.
Now, we go up a level, comparing 5 to 1 with the use of themaxfunction.
1 was the result of our last recursive call. Since 5 is larger, we now know that
the maximum of[5,1]is 5.
Finally, comparing 2 to the maximum of[5,1], which we now know is 5 ,
we obtain the answer to the original problem. Since 5 is greater than 2 , we
can now say that 5 is the maximum of[2,5,1].
```
## A Few More Recursive Functions...................................................

```
Now that we’ve seen how to think recursively, let’s implement a few more
functions this way. Likemaximum, these functions already exist in Haskell, but
we’re going to write our own versions to exercise the recursive muscle fibers
in the recursive muscles of our recursive muscle groups. Let’s get buff!
```
## replicate................................................................

```
First off, we’ll implementreplicate. Remember thatreplicatetakes anInt
and a value, and returns a list that has several repetitions of that value (namely,
however many theIntspecifies). For instance,replicate 3 5returns a list of
three fives:[5,5,5].
```
```
Hello Recursion! 53
```

```
Let’sthink about the base cases. We immediately know what to return if
we’re asked to replicate something zero or fewer times. If we try to replicate
something zero times, we should get an empty list. And we declare that the
result should be the same for negative numbers, because replicating an item
fewer than zero times doesn’t make sense.
In general, a list withnrepetitions ofxis a list withxas its head and a tail
consisting ofxreplicatedn-1times. We get the following code:
```
```
replicate':: Int -> a -> [a]
replicate' n x
| n <= 0 = []
| otherwise = x : replicate' (n-1) x
```
```
Weused guards here instead of patterns because we’re testing for a
Boolean condition.
```
## take....................................................................

```
Next up, we’ll implementtake. This function returns a specified number of
elements from a specified list. For instance,take 3 [5,4,3,2,1]will return
[5,4,3]. If we try to take zero or fewer elements from a list, we should get an
empty list, and if we try to take anything at all from an empty list, we should
get an empty list. Notice that those are our two base cases. Now let’s write
the function:
```
```
take':: (Num i, Ord i) => i -> [a] -> [a]
take' n _
| n <= 0 = []
take' _ [] = []
take' n (x:xs) = x : take' (n-1) xs
```
```
Noticethat in the first pat-
tern, which specifies that we get
an empty list if we try to take
zero or fewer elements from a
list, we use the_placeholder
to match the list value, because
we don’t really care what it is
in this case. Also notice that
we use a guard, but without an
otherwisepart. That means that
ifnturns out to be more than 0,
the matching will fall through
to the next pattern.
The second pattern indicates that if we try to take any number of things
at all from an empty list, we get an empty list.
The third pattern breaks the list into a head and a tail. We call the head
xand the tailxs. Then we state that takingnelements from a list is the same
```
**54** Chapter 4


ascreating a list that hasxas its first element andn-1elements fromxsas its
remaining elements.

## reverse..................................................................

Thereversefunction takes a list and returns a list with the same elements,
but in the reverse order. Once again, the empty list is the base case, since
trying to reverse an empty list just results in the empty list. What about the
rest of the function? Well, if we split the original list into its head and tail,
the reversed list that we want is the reverse of the tail, with the head stuck
at the end:

reverse':: [a] -> [a]
reverse' [] = []
reverse' (x:xs) = reverse' xs ++ [x]

## repeat..................................................................

Therepeatfunctiontakes an element and returns an infinite list composed
of that element. A recursive implementation ofrepeatis really easy:

repeat':: a -> [a]
repeat' x = x:repeat' x

Callingrepeat 3 will give us a list that starts with 3 as the head and has an
infinite amount of 3 s as the tail. So callingrepeat 3evaluates to3:repeat 3,
which evaluates to3:(3:repeat 3), which evaluates to3:(3:(3:repeat 3)), and
so on.repeat 3will never finish evaluating. However,take 5 (repeat 3)will
give us a list of five 3 s. Essentially, it’s like callingreplicate 5 3.
This is a nice example of how we can successfully use recursion that
doesn’t have a base case to make infinite lists—we just have to be sure to
chop them off somewhere along the way.

## zip.....................................................................

zipis another function for working with lists that we’ve met in Chapter 1. It
takes two lists and zips them together. For instance, callingzip [1,2,3] [7,8]
returns[(1,7),(2,8)](the function truncates the longer list to match the
length of the shorter one).
Zipping something with an empty list just returns an empty list, which
gives us our base case. However,ziptakes two lists as parameters, so there
are actually two base cases:

zip':: [a] -> [b] -> [(a,b)]
zip' _ [] = []
zip' [] _ = []
zip' (x:xs) (y:ys) = (x,y):zip' xs ys

```
Hello Recursion! 55
```

```
Thefirst two patterns are our base cases: If the first or second list is
empty, we return an empty list. The third pattern says that zipping two lists
together is equivalent to pairing up their heads, then appending their zip-
ped tails to that.
For example, if we callzip'with[1,2,3]and['a','b'], the function will
form(1,'a')as the first element of the result, then zip together[2,3]and[b]
to obtain the rest of the result. After one more recursive call, the function
will try to zip[3]with[], which matches one of the base case patterns. The
final result is then computed directly as(1,'a'):((2,'b'):[]), which is just
[(1,'a'),(2,'b')].
```
## elem....................................................................

```
Let’s implement one more standard library function:elem. This function
takes a value and a list, and checks whether the value is a member of the list.
Once again, the empty list is a base case—an empty list contains no values, so
it certainly can’t have the one we’re looking for. In general, the value we’re
looking for might be at the head of the list if we’re lucky; otherwise, we have
to check whether it’s in the tail. Here’s the code:
```
```
elem':: (Eq a) => a -> [a] -> Bool
elem' a [] = False
elem' a (x:xs)
| a == x = True
| otherwise = a `elem'` xs
```
## Quick, Sort!.....................................................................

```
Theproblem of sorting a list containing
elements that can be put in order (like
numbers) naturally lends itself to a recur-
sive solution. There are many approaches
to recursively sorting lists, but we’ll look at
one of the coolest ones: quicksort. First we’ll
go over how the algorithm works, and then
we’ll implement it in Haskell.
```
## The Algorithm...........................................................

```
The quicksort algorithm works like this.
You have a list that you want to sort, say
[5,1,9,4,6,7,3]. You select the first element,
which is 5 , and put all the other list elements
that are less than or equal to 5 on its left side. Then you take the ones that
are greater than 5 and put them on its right side. If you did this, you’d have
a list that looks like this:[1,4,3,5,9,6,7]. In this example, 5 is called the pivot ,
because we chose to compare the other elements to it and move them to its
```
**56** Chapter 4


leftand right sides. The only reason we chose the first element as the pivot
is because it will be easy to snag using pattern matching. But really, any ele-
ment can be the pivot.
Now, we recursively sort all the elements that are on the left and right
sides of the pivot by calling the same function on them. The final result is a
completely sorted list!

Theabove diagram illustrates how quicksort works on our example.
When we want to sort[5,1,9,4,6,7,3], we decide that the first element is our
pivot. Then we sandwich it in between[1,4,3]and[9,6,7]. Once we’ve done
that, we sort[1,4,3]and[9,6,7]by using the same approach.
To sort[1,4,3], we choose the first element, 1 , as the pivot and we make
a list of elements that are less than or equal to 1. That turns out to be the
empty list,[], because 1 is the smallest element in[1,4,3]. The elements
larger than 1 go to its right, so that’s[4,3]. Again,[4,3]is sorted in the same
way. It too will eventually be broken up into empty lists and put back together.
The algorithm then returns to the right side of 1 , which has the empty
list on its left side. Suddenly, we have[1,3,4], which is sorted. This is kept on
the left side of the 5.
Once the elements on the right side of the 5 are sorted in the same way,
we will have a completely sorted list:[1,3,4,5,6,7,9].

## The Code...............................................................

Now that we’re familiar with the quicksort algorithm, let’s dive into its imple-
mentation in Haskell:

quicksort:: (Ord a) => [a] -> [a]
quicksort [] = []
quicksort (x:xs) =
let smallerOrEqual = [a | a <- xs, a <= x]
larger = [a | a <- xs, a > x]
in quicksort smallerOrEqual ++ [x] ++ quicksort larger

```
Hello Recursion! 57
```

```
Thetype signature of our function isquicksort :: (Ord a) => [a] -> [a],
and the empty list is the base case, as we just saw.
Remember, we’ll put all the elements less than or equal tox(our
pivot) to its left. To retrieve those elements, we use the list comprehension
[a | a <- xs, a <= x]. This list comprehension will draw fromxs(all the el-
ements that aren’t our pivot) and keep only those that satisfy the condition
a <= x, meaning those elements that are less than or equal tox. We then get
the list of elements larger thanxin a similar fashion.
We useletbindings to give the two lists handy names:smallerOrEqualand
larger. Finally, we use the list concatenation operator (++) and a recursive
application of ourquicksortfunction to express that we want our final list to
be made of a sortedsmallerOrEquallist, followed by our pivot, followed by a
sortedlargerlist.
Let’s give our function a test drive to see if it behaves correctly:
```
```
ghci>quicksort [10,2,5,3,1,6,7,4,2,3,4,8,9]
[1,2,2,3,3,4,4,5,6,7,8,9,10]
ghci> quicksort "the quick brown fox jumps over the lazy dog"
" abcdeeefghhijklmnoooopqrrsttuuvwxyz"
```
```
Nowthat’s what I’m talking about!
```
## Thinking Recursively..............................................................

```
We’ve used recursion quite a bit in this chapter, and as you’ve probably
noticed, there’s a pattern to it. You start by defining a base case: simple,
nonrecursive solution that holds when the input is trivial. For example,
the result of sorting an empty list is the empty list, because—well, what
else could it be?
Then, you break your problem down into one or many subproblems
and recursively solve those by applying the same function to them. You then
build up your final solution from those solved subproblems. For instance,
when sorting, we broke our list into two lists, plus a pivot. We sorted each of
those lists separately by applying the same function to them. When we got
the results, we joined them into one big sorted list.
Thebest way to approach recursion is to
identify base cases and think about how you
can break the problem at hand into something
similar, but smaller. If you’ve correctly chosen
the base cases and subproblems, you don’t even
have to think about the details of how everything
will happen. You can just trust that the solutions
of the subproblems are correct, and then you
can just build up your final solutions from those
smaller solutions.
```
**58** Chapter 4


# 5

## HIGHER-ORDER FUNCTIONS

```
Haskell functions can take functions as parameters and
return functions as return values. A function that does
either of these things is called a higher-order function.
Higher-order functions are a really powerful way of
solving problems and thinking about programs, and
they’re indispensable when using a functional program-
ming language like Haskell.
```
## Curried Functions.................................................................

```
Everyfunction in Haskell officially takes
only one parameter. But we have de-
fined and used several functions that
take more than one parameter so far—
how is that possible?
Well, it’s a clever trick! All the func-
tions we’ve used so far that accepted
multiple parameters have been curried
functions. A curried function is a function
that, instead of taking several parame-
ters, always takes exactly one parameter.
```

```
Thenwhen it’s called with that parameter, it returns a function that takes
the next parameter, and so on.
This is best explained with an example. Let’s take our good friend, the
maxfunction. It looks as if it takes two parameters and returns the one that’s
bigger. For instance, consider the expressionmax 4 5. We call the function
maxwith two parameters: 4 and 5. First,maxis applied to the value 4. When
we applymaxto 4 , the value that is returned is actually another function,
which is then applied to the value 5. The act of applying this function to 5
finally returns a number value. As a consequence, the following two calls
are equivalent:
```
```
ghci>max 4 5
5
ghci> (max 4) 5
5
```
```
Tounderstand how this works, let’s examine the type of themaxfunction:
```
```
ghci>:t max
max :: (Ord a) => a -> a -> a
```
```
Thiscan also be written as follows:
```
```
max:: (Ord a) => a -> (a -> a)
```
```
Wheneverwe have a type signature that fea-
tures the arrow->, that means it’s a function that
takes whatever is on the left side of the arrow and
returns a value whose type is indicated on the right
side of the arrow. When we have something like
a -> (a -> a), we’re dealing with a function that
takes a value of typea, and it returns a function
that also takes a value of typeaand returns a value
of typea.
So how is that beneficial to us? Simply speaking, if we call a function
with too few parameters, we get back a partially applied function, which is a
function that takes as many parameters as we left out. For example, when
we didmax 4, we got back a function that takes one parameter. Using partial
application (calling functions with too few parameters, if you will) is a neat
way to create functions on the fly, so we can pass them to other functions.
Take a look at this simple little function:
```
```
multThree:: Int -> Int -> Int -> Int
multThree x y z = x*y*z
```
**60** Chapter 5


Whatreally happens when we callmultThree 3 5 9, or((multThree 3) 5) 9?
First,multThreeis applied to 3 , because they’re separated by a space. That cre-
ates a function that takes one parameter and returns a function. Then that
function is applied to 5 , which creates a function that will take one param-
eter, multiply 3 and 5 together, and then multiply that by the parameter.
That function is applied to 9 , and the result is 135.
You can think of functions as tiny factories that take some materials
and produce something. Using that analogy, we feed ourmultThreefactory
the number 3 , but instead of producing a number, it churns out a slightly
smaller factory. That factory receives the number 5 and also spits out a fac-
tory. The third factory receives the number 9 , and then produces our result-
ing number, 135.
Remember that this function’s type can also be written as follows:

multThree:: Int -> (Int -> (Int -> Int))

Thetype (or type variable) before the->is the type of the values that
a function takes, and the type after it is the type of the values it returns.
So our function takes a value of typeIntand returns a function of type
(Int -> (Int -> Int). Similarly, _this_ function takes a value of typeIntand
returns a function of typeInt -> Int. And finally, _this_ function just takes a
value of typeIntand returns another value of typeInt.
Let’s look at an example of how we can create a new function by calling
a function with too few parameters:

ghci>let multTwoWithNine = multThree 9
ghci> multTwoWithNine 2 3
54

Inthis example, the expressionmultThree 9results in a function that
takes two parameters. We name that functionmultTwoWithNine, because
multThree 9is a function that takes two parameters. If both parameters
are supplied, it will multiply the two parameters between them, and then
multiply that by 9 , because we got themultTwoWithNinefunction by applying
multThreeto 9.
What if we wanted to create a function that takes anIntand compares it
to 100? We could do something like this:

compareWithHundred:: Int -> Ordering
compareWithHundred x = compare 100 x

```
Asan example, let’s try calling the function with 99 :
```
ghci>compareWithHundred 99
GT

```
Higher-Order Functions 61
```

```
100 isgreater than 99 , so the function returnsGT, or greater than.
Now let’s think about whatcompare 100would return: a function that
takes a number and compares it with 100 , which is exactly what we were
trying to get in our example. In other words, the following definition and
the previous one are equivalent:
```
```
compareWithHundred:: Int -> Ordering
compareWithHundred = compare 100
```
```
Thetype declaration stays the same, becausecompare 100returns a func-
tion.comparehas a type of(Ord a) => a -> (a -> Ordering). When we apply it
to 100 , we get a function that takes a number and returns anOrdering.
```
## Sections.................................................................

```
Infix functions can also be partially applied by using sections. To section an
infix function, simply surround it with parentheses and supply a parameter
on only one side. That creates a function that takes one parameter and then
applies it to the side that’s missing an operand. Here’s an insultingly trivial
example:
```
```
divideByTen:: (Floating a) => a -> a
divideByTen = (/10)
```
```
Asyou can see in the following code, callingdivideByTen 200is equivalent
to calling200 / 10or(/10) 200:
```
```
ghci>divideByTen 200
20.0
ghci> 200 / 10
20.0
ghci> (/10) 200
20.0
```
```
Let’slook at another example. This function checks if a character sup-
plied to it is an uppercase letter:
```
```
isUpperAlphanum:: Char -> Bool
isUpperAlphanum = (`elem` ['A'..'Z'])
```
```
Theonly thing to watch out for with sections is when you’re using the
```
- (negative or minus) operator. From the definition of sections,(-4)would
result in a function that takes a number and subtracts 4 from it. However,
for convenience,(-4)means negative four. So if you want to make a function
that subtracts 4 from the number it gets as a parameter, you can partially
apply thesubtractfunction like so:(subtract 4).

**62** Chapter 5


## Printing Functions........................................................

```
So far, we’ve bound our partially applied functions to names and then sup-
plied the remaining parameters to view the results. However, we never tried
to print the functions themselves to the terminal. Let’s give that a go then,
shall we? What happens if we try enteringmultThree 3 4into GHCi, instead of
binding it to a name with aletor passing it to another function?
```
```
ghci>multThree 3 4
<interactive>:1:0:
No instance for (Show (a -> a))
arising from a use of `print' at <interactive>:1:0-12
Possible fix: add an instance declaration for (Show (a -> a))
In the expression: print it
In a 'do' expression: print it
```
```
GHCiis telling us that the expression produced a function of typea -> a,
but it doesn’t know how to print it to the screen. Functions aren’t instances
of theShowtype class, so we can’t get a neat string representation of a func-
tion. This is different, for example, than when we enter1+1at the GHCi
prompt. In that case, GHCi calculates 2 as the result, and then callsshowon 2
to get a textual representation of that number. The textual representation of
2 is just the string"2", which is then printed to the screen.
```
```
NOTE Make sure you thoroughly understand how curried functions and partial application
work, because they’re really important!
```
## Some Higher-Orderism Is in Order.................................................

```
In Haskell, functions can take other functions as parameters, and as you’ve
seen, they can also return functions as return values. To demonstrate this
concept, let’s write a function that takes a function, and then applies it twice
to some value:
```
```
applyTwice:: (a -> a) -> a -> a
applyTwice f x = f (f x)
```
```
Noticethe type declaration. For our ear-
lier examples, we didn’t need parentheses when
declaring function types, because->is naturally
right-associative. However, here parentheses
are mandatory. They indicate that the first pa-
rameter is a function that takes one parameter
and returns a value of the same type (a -> a).
The second parameter is something of typea,
and the return value’s type is alsoa. Notice that
it doesn’t matter what typeais—it can beInt,
String, or whatever—but all the values must be
the same type.
Higher-Order Functions 63
```

```
NOTE You now know that under the hood, functions that seem to take multiple parameters
are actually taking a single parameter and returning a partially applied function.
However, to keep things simple, I’ll continue to say that a given function takes multi-
ple parameters.
```
```
The body of theapplyTwicefunction is very simple. We just use the pa-
rameterfas a function, applyingxto it by separating thefandxwith a space.
We then apply the result tofagain. Here are some examples of the function
in action:
```
```
ghci>applyTwice (+3) 10
16
ghci> applyTwice (++ " HAHA") "HEY"
"HEY HAHA HAHA"
ghci> applyTwice ("HAHA " ++) "HEY"
"HAHA HAHA HEY"
ghci> applyTwice (multThree 2 2) 9
144
ghci> applyTwice (3:) [1]
[3,3,1]
```
```
Theawesomeness and usefulness of partial application is evident. If our
function requires us to pass it a function that takes only one parameter, we
can just partially apply a function to the point where it takes only one param-
eter and then pass it. For instance, the+function takes two parameters, and
in this example, we partially applied it so that it takes only one parameter by
using sections.
```
## Implementing zipWith....................................................

```
Now we’re going to use higher-order programming to implement a really
useful function in the standard library calledzipWith. It takes a function and
two lists as parameters, and then joins the two lists by applying the function
between corresponding elements. Here’s how we’ll implement it:
```
```
zipWith':: (a -> b -> c) -> [a] -> [b] -> [c]
zipWith' _ [] _ = []
zipWith' _ _ [] = []
zipWith' f (x:xs) (y:ys) = f x y : zipWith' f xs ys
```
```
Firstlet’s look at the type declaration. The first parameter is a function
that takes two arguments and returns one value. They don’t have to be of
the same type, but they can be. The second and third parameters are lists,
and the final return value is also a list.
The first list must be a list of typeavalues, because the joining function
takesatypes as its first argument. The second must be a list ofbtypes, be-
cause the second parameter of the joining function is of typeb. The result is
a list of typecelements.
```
**64** Chapter 5


**NOTE** _Rememberthat if you’re writing a function (especially a higher-order function), and
you’re unsure of the type, you can try omitting the type declaration and checking what
Haskell infers it to be by using:t._

```
This function is similar to the normalzipfunction. The base cases are
the same, although there’s an extra argument (the joining function). How-
ever, that argument doesn’t matter in the base cases, so we can just use the
_character for it. The function body in the last pattern is also similar tozip,
though instead of doing(x, y), it doesfxy.
Here’s a little demonstration of all the different things ourzipWith'func-
tion can do:
```
```
ghci>zipWith' (+) [4,2,5,6] [2,6,2,3]
[6,8,7,9]
ghci> zipWith' max [6,3,2,1] [7,3,1,5]
[7,3,2,5]
ghci> zipWith' (++) ["foo ", "bar ", "baz "] ["fighters", "hoppers", "aldrin"]
["foo fighters","bar hoppers","baz aldrin"]
ghci> zipWith' (*) (replicate 5 2) [1..]
[2,4,6,8,10]
ghci> zipWith' (zipWith' (*)) [[1,2,3],[3,5,6],[2,3,4]] [[3,2,2],[3,4,5],[5,4,3]]
[[3,4,6],[9,20,30],[10,12,12]]
```
```
Asyou can see, a single higher-order function can be used in very versa-
tile ways.
```
## Implementing flip

```
Now we’ll implement another function in the standard library, calledflip.
Theflipfunction takes a function and returns a function that is like our
original function, but with the first two arguments flipped. We can imple-
ment it like this:
```
```
flip':: (a -> b -> c) -> (b -> a -> c)
flip' f = g
where g x y = f y x
```
```
Youcan see from the type declaration thatflip'takes a function that
takesaandbtypes, and returns a function that takesbandatypes. But
because functions are curried by default, the second pair of parentheses
actually is not necessary. The arrow->is right-associative by default, so
(a -> b -> c) -> (b -> a -> c)is the same as(a -> b -> c) -> (b -> (a -> c)),
which is the same as(a -> b -> c) -> b -> a -> c. We wrote thatgxy=fyx.
If that’s true, thenfyx=gxymust also hold, right? Keeping that in mind,
we can define this function in an even simpler manner:
```
```
flip':: (a -> b -> c) -> b -> a -> c
flip' f y x = f x y
```
```
Higher-Order Functions 65
```

```
Inthis new version offlip', we take advantage of the fact that functions
are curried. When we callflip' fwithout the parametersyandx, it will re-
turn anfthat takes those two parameters but calls them flipped.
Even though flipped functions are usually passed to other functions,
we can take advantage of currying when making higher-order functions by
thinking ahead and writing what their end result would be if they were fully
applied.
```
```
ghci>zip [1,2,3,4,5] "hello"
[(1,'h'),(2,'e'),(3,'l'),(4,'l'),(5,'o')]
ghci> flip' zip [1,2,3,4,5] "hello"
[('h',1),('e',2),('l',3),('l',4),('o',5)]
ghci> zipWith div [2,2..] [10,8,6,4,2]
[0,0,0,0,1]
ghci> zipWith (flip' div) [2,2..] [10,8,6,4,2]
[5,4,3,2,1]
```
```
Ifweflip'thezipfunction, we get a function that is likezip, except that
the items from the first list are placed into the second components of the
tuples and vice versa. Theflip' divfunction takes its second parameter and
divides that by its first, so when the numbers 2 and 10 are passed toflip' div,
the result is the same as usingdiv 10 2.
```
## The Functional Programmer’s Toolbox..............................................

```
As functional programmers, we seldom want to operate on just one value.
We usually want to take a bunch of numbers, letters, or some other type of
data, and transform the set to produce our results. In this section, we’ll look
at some useful functions that can help us work with multiple values.
```
## The map Function........................................................

```
Themapfunction takes a function and a list, and applies that function to ev-
ery element in the list, producing a new list. Here is its definition:
```
```
map:: (a -> b) -> [a] -> [b]
map _ [] = []
map f (x:xs) = f x : map f xs
```
```
Thetype signature says thatmaptakes a function fromatoband a list ofa
values, and returns a list ofbvalues.
mapis a versatile higher-order function that can be used in many differ-
ent ways. Here it is in action:
```
```
ghci>map (+3) [1,5,3,1,6]
[4,8,6,4,9]
ghci> map (++ "!") ["BIFF", "BANG", "POW"]
["BIFF!","BANG!","POW!"]
```
**66** Chapter 5


```
ghci> map (replicate3) [3..6]
[[3,3,3],[4,4,4],[5,5,5],[6,6,6]]
ghci> map (map (^2)) [[1,2],[3,4,5,6],[7,8]]
[[1,4],[9,16,25,36],[49,64]]
ghci> map fst [(1,2),(3,5),(6,3),(2,6),(2,5)]
[1,3,6,2,2]
```
```
You’ve probably noticedthat each of these examples could also be
achieved with a list comprehension. For instance,map (+3) [1,5,3,1,6]is
technically the same as[x+3 | x <- [1,5,3,1,6]]. However, using themap
function tends to make your code much more readable, especially once
you start dealing with maps of maps.
```
## The filter Function........................................................

```
Thefilterfunction takes a predicate and a list, and returns the list of ele-
ments that satisfy that predicate. (Remember that a predicate is a function
that tells whether something is true or false; that is, a function that returns
a Boolean value.) The type signature and implementation look like this:
```
```
filter :: (a-> Bool) -> [a] -> [a]
filter _ [] = []
filter p (x:xs)
| p x = x : filter p xs
| otherwise = filter p xs
```
```
Ifpxevaluates toTrue, the element is included in the new list. If it doesn’t
evaluate toTrue, it isn’t included in the new list.
Here are somefilterexamples:
```
ghci> filter (>3)[1,5,3,2,1,6,4,3,2,1]
[5,6,4]
ghci> filter (==3) [1,2,3,4,5]
[3]
ghci> filter even [1..10]
[2,4,6,8,10]
ghci> let notNull x = not (null x) in filter notNull [[1,2,3],[],[3,4,5],[2,2],[],[],[]]
[[1,2,3],[3,4,5],[2,2]]
ghci> filter (`elem` ['a'..'z']) "u LaUgH aT mE BeCaUsE I aM diFfeRent"
"uagameasadifeent"
ghci> filter (`elem` ['A'..'Z']) "i LAuGh at you bEcause u R all the same"
"LAGER"

```
As with themapfunction,all of these examples could also be achieved
by using comprehensions and predicates. There’s no set rule for when to
usemapandfilterversus using list comprehensions. You just need to decide
what’s more readable depending on the code and the context.
```
```
Higher-Order Functions 67
```

```
Thefilterequivalentof applying several predicates in a list comprehen-
sion is either filtering something several times or joining the predicates with
the logical&&function. Here’s an example:
```
```
ghci>filter (<15) (filter even [1..20])
[2,4,6,8,10,12,14]
```
```
Inthis example, we take the list[1..20]and filter it so that only even
numbers remain. Then we pass that list tofilter (<15)to get rid of numbers
15 and up. Here’s the list comprehension version:
```
```
ghci>[x | x <- [1..20], x < 15, even x]
[2,4,6,8,10,12,14]
```
```
Weuse a list comprehension where we draw from the list[1..20], and
then say what conditions need to hold for a number to be in the resulting list.
Remember ourquicksortfunction from Chapter 4? We used list com-
prehensions to filter out the list elements that were less than (or equal to)
or greater than the pivot. We can achieve the same functionality in a more
readable way by usingfilter:
```
```
quicksort:: (Ord a) => [a] -> [a]
quicksort [] = []
quicksort (x:xs) =
let smallerOrEqual = filter (<= x) xs
larger = filter (> x) xs
in quicksort smallerOrEqual ++ [x] ++ quicksort larger
```
## More Examples of map and filter..........................................

```
Asanother example, let’s find the largest num-
ber under 100,000 that’s divisible by 3,829. To do
that, we’ll just filter a set of possibilities in which
we know the solution lies:
```
```
largestDivisible:: Integer
largestDivisible = head (filter p [100000,99999..])
where p x = x `mod` 3829 == 0
```
```
First,we make a descending list of all numbers less than 100,000. Then
we filter it by our predicate. Because the numbers are sorted in a descending
manner, the largest number that satisfies our predicate will be the first ele-
ment of the filtered list. And because we end up using only the head of the
filtered list, it doesn’t matter if the filtered list is finite or infinite. Haskell’s
laziness causes the evaluation to stop when the first adequate solution is
found.
```
**68** Chapter 5


Asour next example, we’ll find the sum of all odd squares that are smaller
than 10,000. In our solution, we’ll use thetakeWhilefunction. This function
takes a predicate and a list. Starting at the beginning of the list, it returns
the list’s elements as long as the predicate holds true. Once an element is
found for which the predicate doesn’t hold true, the function stops and re-
turns the resulting list. For example, to get the first word of a string, we can
do the following:

ghci>takeWhile (/=' ') "elephants know how to party"
"elephants"

Tofind the sum of all odd squares that are less than 10,000, we begin
by mapping the(^2)function over the infinite list[1..]. Then we filter this
list so we get only the odd elements. Next, usingtakeWhile, we take elements
from that list only while they are smaller than 10,000. Finally, we get the sum
of that list (using thesumfunction). We don’t even need to define a function
for this example, because we can do it all in one line in GHCi:

ghci>sum (takeWhile (<10000) (filter odd (map (^2) [1..])))
166650

Awesome!We start with some initial data (the infinite list of all natu-
ral numbers), and then we map over it, filter it, and cut it until it suits our
needs. Finally, we just sum it up!
We could have also written this example using list comprehensions,
like this:

ghci>sum (takeWhile (<10000) [m | m <- [n^2 | n <- [1..]], odd m])
166650

Forour next problem, we’ll be dealing with Collatz sequences. A _Collatz
sequence_ (also known as a _Collatz chain_ ) is defined as follows:

- Start with any natural number.
- If the number is 1, stop.
- If the number is even, divide it by 2.
- If the number is odd, multiply it by 3 and add 1.
- Repeat the algorithm with the resulting number.

In essence, this gives us a chain of numbers. Mathematicians theorize
that for all starting numbers, the chain will finish at the number 1. For ex-
ample, if we start with the number 13, we get this sequence: 13, 40, 20, 10,
5, 16, 8, 4, 2, 1. (13⇥3 + 1 equals 40. 40 divided by 2 equals 20, and so on.)
We can see that the chain that starts with 13 has 10 terms.

```
Higher-Order Functions 69
```

```
Hereis the problem we want to solve: For all starting numbers between
1 and 100, how many Collatz chains have a length greater than 15?
Our first step will be to write a function that produces a chain:
```
```
chain:: Integer -> [Integer]
chain 1 = [1]
chain n
| even n = n:chain (n `div` 2)
| odd n = n:chain (n*3 + 1)
```
```
Thisis a pretty standard recursive function. The base case is one, be-
cause all our chains will end at one. We can test the function to see if it’s
working correctly:
```
```
ghci>chain 10
[10,5,16,8,4,2,1]
ghci> chain 1
[1]
ghci> chain 30
[30,15,46,23,70,35,106,53,160,80,40,20,10,5,16,8,4,2,1]
```
```
Nowwe can write thenumLongChainsfunction, which actually answers our
question:
```
```
numLongChains:: Int
numLongChains = length (filter isLong (map chain [1..100]))
where isLong xs = length xs > 15
```
```
Wemap thechainfunction to[1..100]to get a list of chains, which are
themselves represented as lists. Then we filter them by a predicate that checks
whether a list’s length is longer than 15. Once we’ve done the filtering, we
see how many chains are left in the resulting list.
```
```
NOTE This function has a type ofnumLongChains :: Intbecauselengthreturns anIntin-
stead of aNum a. If we wanted to return a more generalNum a, we could have used
fromIntegralon the resulting length.
```
## Mapping Functions with Multiple Parameters

```
So far, we’ve mapped functions that take only one parameter (likemap (*2)
[0..]). However, we can also map functions that take multiple parameters.
For example, we could do something likemap (*) [0..]. In this case, the
function*, which has a type of(Num a) => a -> a -> a, is applied to each
number in the list.
As you’ve seen, giving only one parameter to a function that takes two
parameters will cause it to return a function that takes one parameter. So if
we map*to the list[0..], we will get back a list of functions that take only
one parameter.
```
**70** Chapter 5


```
Here’san example:
```
```
ghci>let listOfFuns = map (*) [0..]
ghci> (listOfFuns !! 4) 5
20
```
```
Gettingthe element with the index 4 from our list returns a function
that’s equivalent to(4*). Then we just apply 5 to that function, which is the
```
same as(4*)5, or just (^4) * 5.

## Lambdas........................................................................

```
Lambdas areanonymous functions
that we use when we need a function
only once.
Normally, we make a lambda with
the sole purpose of passing it to a
higher-order function. To declare a
lambda, we write a\(because it kind of
looks like the Greek letter lambda ()
if you squint hard enough), and then
we write the function’s parameters, sep-
arated by spaces. After that comes a->,
and then the function body. We usually
surround lambdas with parentheses.
In the previous section, we used
awherebinding in ournumLongChains
function to make theisLongfunction for the sole purpose of passing it to
filter. Instead of doing that, we can also use a lambda, like this:
```
```
numLongChains:: Int
numLongChains = length (filter (\xs -> length xs > 15) (map chain [1..100]))
```
```
Lambdasare expressions, which is why we can
just pass them to functions like this. The expres-
sion(\xs -> length xs > 15)returns a function that
tells us whether the length of the list passed to it is
greater than 15.
People who don’t understand how currying and
partial application work often use lambdas where they are not necessary. For
instance, the following expressions are equivalent:
```
```
ghci>map (+3) [1,6,3,2]
[4,9,6,5]
ghci> map (\x -> x + 3) [1,6,3,2]
[4,9,6,5]
```
```
Higher-Order Functions 71
```

```
Both(+3)and(\x-> x + 3)are functions that take a number and add 3
to it, so these expressions yield the same results. However, we don’t want to
make a lambda in this case, because using partial application is much more
readable.
Like normal functions, lambdas can take any number of parameters:
```
```
ghci>zipWith (\a b -> (a*30 + 3) / b) [5,4,3,2,1] [1,2,3,4,5]
[153.0,61.5,31.0,15.75,6.6]
```
```
Andlike normal functions, you can pattern match in lambdas. The only
difference is that you can’t define several patterns for one parameter (like
making a[]and a(x:xs)pattern for the same parameter and then having
values fall through).
```
```
ghci>map (\(a,b) -> a + b) [(1,2),(3,5),(6,3),(2,6),(2,5)]
[3,8,9,8,7]
```
```
NOTE Ifa pattern match fails in a lambda, a runtime error occurs, so be careful!
```
```
Let’s look at another interesting example:
```
```
addThree:: Int -> Int -> Int -> Int
addThree x y z = x + y + z
```
```
addThree :: Int -> Int -> Int -> Int
addThree' = \x -> \y -> \z -> x + y + z
```
```
Dueto the way functions are curried by default, these two functions are
equivalent. Yet the firstaddThreefunction is far more readable. The second
one is little more than a gimmick to illustrate currying.
```
```
NOTE Notice that in the second example, the lambdas are not surrounded with parentheses.
When you write a lambda without parentheses, it assumes that everything to the right
of the arrow->belongs to it. So in this case, omitting the parentheses saves some typ-
ing. Of course, you can include the parentheses if you prefer them.
```
```
However, there are times when using the currying notation instead is
useful. I think that theflipfunction is the most readable when it’s defined
like this:
```
```
flip':: (a -> b -> c) -> b -> a -> c
flip' f = \x y -> f y x
```
```
Eventhough this is the same as writingflip' f x y = f y x, our new no-
tation makes it obvious that this will often be used for producing a new func-
tion.The most common use case withflipis calling it with just the function
```
**72** Chapter 5


```
parameter,or the function parameter and one extra parameter, and then
passing the resulting function on to amapor azipWith:
```
```
ghci>zipWith (flip (++)) ["love you", "love me"] ["i ", "you "]
["i love you","you love me"]
ghci> map (flip subtract 20) [1,2,3,4]
[19,18,17,16]
```
```
Youcan use lambdas this way in your own functions when you want to
make it explicit that your functions are meant to be partially applied and
then passed on to other functions as a parameter.
```
## IFold You So....................................................................

```
Backwhen we were dealing with
recursion in Chapter 4, many of
the recursive functions that op-
erated on lists followed the same
pattern. We had a base case for
the empty list, we introduced the
x:xspattern, and then we per-
formed some action involving a
single element and the rest of the
list. It turns out this is a very com-
mon pattern, so the creators of
Haskell introduced some useful
functions, called folds , to encapsu-
late it. Folds allow you to reduce
a data structure (like a list) to a
single value.
Folds can be used to implement any function where you traverse a list
once, element by element, and then return something based on that. When-
ever you want to traverse a list to return something, chances are you want
a fold.
A fold takes a binary function (one that takes two parameters, such as+or
div), a starting value (often called the accumulator ), and a list to fold up.
Lists can be folded up from the left or from the right. The fold function
calls the given binary function, using the accumulator and the first (or last)
element of the list as parameters. The resulting value is the new accumula-
tor. Then the fold function calls the binary function again with the new ac-
cumulator and the new first (or last) element of the list, resulting in another
new accumulator. This repeats until the function has traversed the entire list
and reduced it down to a single accumulator value.
```
```
Higher-Order Functions 73
```

## Left Folds with foldl.......................................................

```
First, let’s look at thefoldlfunction. This is called a left fold , since it folds the
list up from the left side. In this case, the binary function is applied between
the starting accumulator and the head of the list. That produces a new accu-
mulator value, and the binary function is called with that value and the next
element, and so on.
Let’s implement thesumfunction again, this time using a fold instead of
explicit recursion:
```
```
sum':: (Num a) => [a] -> a
sum' xs = foldl (\acc x -> acc + x) 0 xs
```
```
Nowwe can test it:
```
```
ghci>sum' [3,5,2,1]
11
```
```
Let’stake an in-depth look at how this fold
happens.\acc x -> acc + xis the binary function.
0 is the starting value, andxsis the list to be folded
up. First, 0 and 3 are passed to the binary function
as theaccandxparameters, respectively. In this
case, the binary function is simply an addition, so
the two values are added, which produces 3 as the
new accumulator value. Next, 3 and the next list
value ( 5 ) are passed to the binary function, and
they are added together to produce 8 as the new
accumulator value. In the same way, 8 and 2 are
added together to produce 10 , and then 10 and 1
are added together to produce the final value of
11. Congratulations, you’ve folded your first list!
The diagram on the left illustrates how a fold
happens, step by step. The number that’s on the
left side of the+is the accumulator value. You
can see how the list is consumed up from the left
side by the accumulator. (Om nom nom nom!)
If we take into account that functions are curried,
we can write this implementation even more suc-
cinctly, like so:
```
```
sum':: (Num a) => [a] -> a
sum' = foldl (+) 0
```
```
Thelambda function(\acc x -> acc + x)is the same as(+). We can omit
thexsas the parameter because callingfoldl (+) 0will return a function that
takes a list. Generally, if you have a function likefoo a = bar b a, you can
rewrite it asfoo = bar bbecause of currying.
```
**74** Chapter 5


## Right Folds with foldr.....................................................

The right fold function,foldr, is similar to the left fold, except the accumu-
lator eats up the values from the right. Also, the order of the parameters in
the right fold’s binary function is reversed: The current list value is the first
parameter, and the accumulator is the second. (It makes sense that the right
fold has the accumulator on the right, since it folds from the right side.)
The accumulator value (and hence, the result) of a fold can be of any
type. It can be a number, a Boolean, or even a new list. As an example, let’s
implement themapfunction with a right fold. The accumulator will be a list,
and we’ll be accumulating the mapped list element by element. Of course,
our starting element will need to be an empty list:

map':: (a -> b) -> [a] -> [b]
map' f xs = foldr (\x acc -> f x : acc) [] xs

Ifwe’re mapping(+3)to[1,2,3], we approach the list from the right
side. We take the last element, which is 3 , and apply the function to it, which
gives 6. Then we prepend it to the accumulator, which was[].6:[]is[6], so
that’s now the accumulator. We then apply(+3)to 2 , yielding 5 , and prepend
(:) that to the accumulator. Our new accumulator value is now[5,6]. We
then apply(+3)to 1 and prepend the result to the accumulator again, giving
a final result of[4,5,6].
Of course, we could have implemented this function with a left fold in-
stead, like this:

map':: (a -> b) -> [a] -> [b]
map' f xs = foldl (\acc x -> acc ++ [f x]) [] xs

However,the++function is much slower than:, so we usually use right
folds when we’re building up new lists from a list.
One big difference between the two types of folds is that right folds work
on infinite lists, whereas left ones don’t!
Let’s implement one more function with a right fold. As you know, the
elemfunction checks whether a value is part of a list. Here’s how we can use
foldrto implement it:

elem':: (Eq a) => a -> [a] -> Bool
elem' y ys = foldr (\x acc -> if x == y then True else acc) False ys

Here,the accumulator is a Boolean value. (Remember that the type of
the accumulator value and the type of the end result are always the same
when dealing with folds.) We start with a value ofFalse, since we’re assuming
the value isn’t in the list to begin with. This also gives us the correct value if
we call it on the empty list, since calling a fold on an empty list just returns
the starting value.

```
Higher-Order Functions 75
```

```
Next,we check if the current element
is the element we want. If it is, we set the
accumulator toTrue. If it’s not, we just
leave the accumulator unchanged. If it
wasFalsebefore, it stays that way because
this current element is not the one we’re
seeking. If it wasTrue, it stays that way as
the rest of the list is folded up.
```
## The foldl and foldr1 Functions.............................................

```
Thefoldl1andfoldr1functions work much likefoldlandfoldr, except that
you don’t need to provide them with an explicit starting accumulator. They
assume the first (or last) element of the list to be the starting accumulator,
and then start the fold with the element next to it. With that in mind, the
maximumfunction can be implemented like so:
```
```
maximum':: (Ord a) => [a] -> a
maximum' = foldl1 max
```
```
Weimplementedmaximumby using afoldl1. Instead of providing a starting
accumulator,foldl1just assumes the first element as the starting accumula-
tor and moves on to the second one. So allfoldl1needs is a binary function
and a list to fold up! We start at the beginning of the list and then compare
each element with the accumulator. If it’s greater than our accumulator, we
keep it as the new accumulator; otherwise, we keep the old one. We passed
maxtofoldl1as the binary function because it does exactly that: takes two val-
ues and returns the one that’s larger. By the time we’ve finished folding our
list, only the largest element remains.
Because they depend on the lists they’re called with having at least one
element, these functions cause runtime errors if called with empty lists.foldl
andfoldr, on the other hand, work fine with empty lists.
```
```
NOTE When making a fold, think about how it acts on an empty list. If the function doesn’t
make sense when given an empty list, you can probably use afoldl1orfoldr1to im-
plement it.
```
## Some Fold Examples.....................................................

```
To demonstrate how powerful folds are, let’s implement some standard li-
brary functions using folds. First, we’ll write our own version ofreverse:
```
```
reverse':: [a] -> [a]
reverse' = foldl (\acc x -> x : acc) []
```
```
Here,we reverse a list by using the empty list as a starting accumulator
and then approaching our original list from the left and placing the current
element at the start of the accumulator.
```
**76** Chapter 5


Thefunction\acc x -> x : accis just like the:function, except that
the parameters are flipped. That’s why we could have also writtenreverse'
like so:

reverse':: [a] -> [a]
reverse' = foldl (flip (:)) []

```
Next,we’ll implementproduct:
```
product':: (Num a) => [a] -> a
product' = foldl (*)1

Tocalculate the product of all the numbers in the list, we start with 1
as the accumulator. Then we fold left with the*function, multiplying each
element with the accumulator.
Now we’ll implementfilter:

filter':: (a -> Bool) -> [a] -> [a]
filter' p = foldr (\x acc -> if p x then x : acc else acc) []

Here,we use an empty list as the starting accumulator. Then we fold
from the right and inspect each element.pis our predicate. IfpxisTrue—
meaning that if the predicate holds for the current element—we put it at the
beginning of the accumulator. Otherwise, we just reuse our old accumulator.
Finally, we’ll implementlast:

last':: [a] -> a
last' = foldl1 (\_ x -> x)

Toget the last element of a list, we use afoldl1. We start at the first el-
ement of the list, and then use a binary function that disregards the accu-
mulator and always sets the current element as the new accumulator. Once
we’ve reached the end, the accumulator—that is, the last element—will be
returned.

## Another Way to Look at Folds.............................................

Another way to picture right and left folds is as successive applications of
some function to elements in a list. Say we have a right fold, with a binary
functionfand a starting accumulatorz. When we right fold over the list
[3,4,5,6], we’re essentially doing this:

f3 (f 4 (f 5 (f 6 z)))

fiscalled with the last element in the list and the accumulator, then
that value is given as the accumulator to the next-to-last value, and so on.

```
Higher-Order Functions 77
```

```
Ifwe takefto be+and the starting accumulator value to be 0 , we’re do-
ing this:
```
```
3 + (4 + (5 + (6 + 0)))
```
```
Orif we write+as a prefix function, we’re doing this:
```
```
(+)3 ((+) 4 ((+) 5 ((+) 6 0)))
```
```
Similarly,doing a left fold over that list withgas the binary function and
zas the accumulator is the equivalent of this:
```
```
g(g (g (g z 3) 4) 5) 6
```
```
Ifwe useflip (:)as the binary function and[]as the accumulator (so
we’re reversing the list), that’s the equivalent of the following:
```
```
flip(:) (flip (:) (flip (:) (flip (:) [] 3) 4) 5) 6
```
```
Andsure enough, if you evaluate that expression, you get[6,5,4,3].
```
## Folding Infinite Lists......................................................

```
Viewing folds as successive function applications on values of a list can give
you insight as to whyfoldrsometimes works perfectly fine on infinite lists.
Let’s implement theandfunction with afoldr, and then write it out as a se-
ries of successive function applications, as we did with our previous exam-
ples. You’ll see howfoldrworks with Haskell’s laziness to operate on lists
that have infinite length.
Theandfunction takes a list ofBoolvalues and returnsFalseif one or
more elements areFalse; otherwise, it returnsTrue. We’ll approach the list
from the right and useTrueas the starting accumulator. We’ll use&&as the
binary function, because we want to end up withTrueonly if all the elements
areTrue. The&&function returnsFalseif either of its parameters isFalse, so
if we come across an element in the list that isFalse, the accumulator will be
set asFalseand the final result will also beFalse, even if all the remaining
elements areTrue:
```
```
and':: [Bool] -> Bool
and' xs = foldr (&&) True xs
```
```
Knowinghowfoldrworks, we see that the expressionand' [True,False,True]
will be evaluated like this:
```
```
True&& (False && (True && True))
```
**78** Chapter 5


ThelastTruerepresents our starting accumulator, whereas the first three
Boolvalues are from the list[True,False,True]. If we try to evaluate the previ-
ous expression, we will getFalse.
Now what if we try this with an infinite list, sayrepeat False, which has an
infinite number of elements, all of which areFalse? If we write that out, we
get something like this:

False&& (False && (False && (False ...

Haskellis lazy, so it will compute only what it really must. And the&&
function works in such a way that if its first parameter isFalse, it disregards
its second parameter, because the&&function returnsTrueonly if both of its
parameters areTrue:

(&&):: Bool -> Bool -> Bool
True && x = x
False && _ = False

Inthe case of the endless list ofFalsevalues, the second pattern matches,
andFalseis returned without Haskell needing to evaluate the rest of the infi-
nite list:

ghci>and' (repeat False)
False

foldrwillwork on infinite lists when the binary function that we’re pass-
ing to it doesn’t always need to evaluate its second parameter to give us some
sort of answer. For instance,&&doesn’t care what its second parameter is if
its first parameter isFalse.

## Scans...................................................................

Thescanlandscanrfunctions are likefoldlandfoldr, except they report
all the intermediate accumulator states in the form of a list. Thescanl1and
scanr1functions are analogous tofoldl1andfoldr1. Here are some examples
of these functions in action:

ghci>scanl (+) 0 [3,5,2,1]
[0,3,8,10,11]
ghci> scanr (+) 0 [3,5,2,1]
[11,8,3,1,0]
ghci> scanl1 (\acc x -> if x > acc then x else acc) [3,4,5,3,7,9,2,1]
[3,4,5,5,7,9,9,9]
ghci> scanl (flip (:)) [] [3,2,1]
[[],[3],[2,3],[1,2,3]]

Whenusing ascanl, the final result will be in the last element of the re-
sulting list.scanrwill place the result in the head of the list.

```
Higher-Order Functions 79
```

```
Scansare used to monitor the progress of a function that can be imple-
mented as a fold. As an exercise in using scans, let’s try answering this ques-
tion: How many elements does it take for the sum of the square roots of all
natural numbers to exceed 1,000?
To get the square roots of all natural numbers, we just callmap sqrt [1..].
To get the sum, we could use a fold. However, because we’re interested in
how the sum progresses, we’ll use a scan instead. Once we’ve done the scan,
we can check how many sums are under 1,000.
```
```
sqrtSums:: Int
sqrtSums = length (takeWhile (<1000) (scanl1 (+) (map sqrt [1..]))) + 1
```
```
WeusetakeWhilehere instead offilterbecausefilterwouldn’t cut off
the resulting list once a number that’s equal to or over 1,000 is found; it
would keep searching. Even though we know the list is ascending,filter
doesn’t, so we usetakeWhileto cut off the scan list at the first occurrence of
a sum greater than 1,000.
The first sum in the scan list will be 1. The second will be 1 plus the
square root of 2. The third will be that plus the square root of 3. If there are
x sums under 1,000, then it takes x +1 elements for the sum to exceed 1,000:
```
```
ghci>sqrtSums
131
ghci> sum (map sqrt [1..131])
1005.0942035344083
ghci> sum (map sqrt [1..130])
993.6486803921487
```
```
Andbehold, our answer is correct! If we sum the first 130 square roots,
the result is just below 1,000, but if we add another one to that, we go over
our threshold.
```
## Function Application with $.......................................................

```
Now we’ll look at the$function, also called the function application operator.
First, let’s see how it’s defined:
```
```
($):: (a -> b) -> a -> b
f$x=fx
```
```
Whatthe heck? What is this useless function? It’s
just function application! Well, that’s almost true,
but not quite. Whereas normal function application
(putting a space between two things) has a really high
precedence, the$function has the lowest precedence.
Function application with a space is left-associative (so
fabcis the same as((f a) b) c), while function ap-
plication with$is right-associative.
```
**80** Chapter 5


Sohow does this help us? Most of the time, it’s a convenience function
that lets us write fewer parentheses. For example, consider the expression
sum (map sqrt [1..130]). Because$has such a low precedence, we can rewrite
that expression assum $ map sqrt [1..130]. When a$is encountered, the ex-
pression on its right is applied as the parameter to the function on its left.
How aboutsqrt 3 + 4 + 9? This adds together 9, 4, and the square root
of 3. However, if we wanted the square root of 3 + 4 + 9, we would need to
writesqrt (3 + 4 + 9). With$, we can also write this assqrt $ 3 + 4 + 9. You
can imagine$as almost being the equivalent of writing an opening paren-
thesis and then writing a closing parenthesis on the far right side of the
expression.
Let’s look at another example:

ghci>sum (filter (> 10) (map (*2) [2..10]))
80

Whoa,that’s a lot of parentheses! It looks kind of ugly. Here,(*2)is
mapped onto[2..10], then we filter the resulting list to keep only those
numbers that are larger than 10 , and finally those numbers are added
together.
We can use the$function to rewrite our previous example and make it
a little easier on the eyes:

ghci>sum $ filter (> 10) (map (*2) [2..10])
80

The$functionis right-associative, meaning that something likef$g$x
is equivalent tof $ (g $ x). With that in mind, the preceding example can
once again be rewritten as follows:

ghci>sum $ filter (> 10) $ map (*2) [2..10]
80

Apartfrom getting rid of parentheses,$lets us treat function applica-
tion like just another function. This allows us to, for instance, map function
application over a list of functions, like this:

ghci>map ($ 3) [(4+), (10*), (^2), sqrt]
[7.0,30.0,9.0,1.7320508075688772]

Here,the function($ 3)gets mapped over the list. If you think about
what the($ 3)function does, you’ll see that it takes a function and then ap-
plies that function to 3. So every function in the list gets applied to 3 , which
is evident in the result.

```
Higher-Order Functions 81
```

## Function Composition.............................................................

```
In mathematics, function composition is defined like this:(fg)(x)=f(g(x)).
This means that composing two functions is the equivalent of calling one
function with some value and then calling another function with the result
of the first function.
In Haskell, function composition is pretty much the same thing. We do
function composition with the.function, which is defined like this:
```
```
(.):: (b -> c) -> (a -> b) -> a -> c
f. g = \x -> f (g x)
```
```
Noticethe type declaration.fmust
take as its parameter a value that has the
same type asg’s return value. So the result-
ing function takes a parameter of the same
type thatgtakes and returns a value of the
same type thatfreturns. For example, the
expressionnegate. (*3)returns a function
that takes a number, multiplies it by 3, and
then negates it.
One use for function composition is
making functions on the fly to pass to other
functions. Sure, we can use lambdas for
that, but many times, function composition is clearer and more concise.
For example, say we have a list of numbers and we want to turn them all
into negative numbers. One way to do that would be to get each number’s
absolute value and then negate it, like so:
```
```
ghci>map (\x -> negate (abs x)) [5,-3,-6,7,-3,2,-19,24]
[-5,-3,-6,-7,-3,-2,-19,-24]
```
```
Noticethe lambda and how it looks like the result of function composi-
tion. Using function composition, we can rewrite that as follows:
```
```
ghci>map (negate. abs) [5,-3,-6,7,-3,2,-19,24]
[-5,-3,-6,-7,-3,-2,-19,-24]
```
```
Fabulous!Function composition is right-associative, so we can com-
pose many functions at a time. The expressionf (g (z x))is equivalent to
(f. g. z) x. With that in mind, we can turn something messy, like this:
```
```
ghci>map (\xs -> negate (sum (tail xs))) [[1..5],[3..6],[1..7]]
[-14,-15,-27]
```
**82** Chapter 5


intosomething much cleaner, like this:

ghci>map (negate. sum. tail) [[1..5],[3..6],[1..7]]
[-14,-15,-27]

negate. sum. tailis a function that takes a list, applies thetailfunction
to it, then applies thesumfunction to the result of that, and finally applies
negateto the previous result. So it’s equivalent to the preceding lambda.

## Function Composition with Multiple Parameters.............................

But what about functions that take several parameters? Well, if we want to
use them in function composition, we usually must partially apply them so
that each function takes just one parameter. Consider this expression:

sum(replicate 5 (max 6.7 8.9))

```
Thisexpression can be rewritten as follows:
```
(sum. replicate 5) max 6.7 8.9

whichis equivalent to this:

sum. replicate 5 $ max 6.7 8.9

Thefunctionreplicate 5is applied to the result ofmax 6.7 8.9, and then
sumis applied to that result. Notice that we partially applied thereplicate
function to the point where it takes only one parameter, so that when the
result ofmax 6.7 8.9gets passed toreplicate 5, the result is a list of numbers,
which is then passed tosum.
If we want to rewrite an expression with a lot of parentheses using func-
tion composition, we can start by first writing out the innermost function
and its parameters. Then we put a$before it and compose all the functions
that came before by writing them without their last parameter and putting
dots between them. Say we have this expression:

replicate2 (product (map (*3) (zipWith max [1,2] [4,5])))

```
Wecan write this as follows:
```
replicate2. product. map (*3) $ zipWith max [1,2] [4,5]

Howdid we turn the first example into the second one? Well, first we
look at the function on the far right and its parameters, just before the bunch

```
Higher-Order Functions 83
```

```
of closing parentheses.That function iszipWith max [1,2] [4,5]. We’re going
to keep that as it is, so now we have this:
```
```
zipWith max [1,2][4,5]
```
```
Then we lookat which function was applied tozipWith max [1,2] [4,5]
and see that it wasmap (*3). So we put a$between it and what we had before:
```
```
map (*3) $zipWith max [1,2] [4,5]
```
```
Now we startthe compositions. We check which function was applied to
all this, and we see that it wasproduct, so we compose it withmap (*3):
```
```
product. map(*3) $ zipWith max [1,2] [4,5]
```
```
And finally, wesee that the functionreplicate 2was applied to all this,
and we can write the expression as follows:
```
```
replicate 2 .product. map (*3) $ zipWith max [1,2] [4,5]
```
```
If the expressionends with three parentheses, chances are that if you
translate it into function composition by following this procedure, it will
have two composition operators.
```
## Point-Free Style..........................................................

```
Another common use of function composition is defining functions in the
point-free style. For example, consider a function we wrote earlier:
```
```
sum' :: (Numa) => [a] -> a
sum' xs = foldl (+) 0 xs
```
```
Thexsis on thefar right on both sides of the equal sign. Because of cur-
rying, we can omit thexson both sides, since callingfoldl (+) 0creates a
function that takes a list. In this way, we are writing the function in point-
free style:
```
```
sum' :: (Numa) => [a] -> a
sum' = foldl (+) 0
```
```
As another example,let’s try writing the following function in point-free
style:
```
```
fn x =ceiling (negate (tan (cos (max 50 x))))
```
```
We can’t justget rid of thexon both right sides, since thexin the func-
tion body is surrounded by parentheses.cos (max 50)wouldn’t make sense—
```
**84** Chapter 5


youcan’t get the cosine of a function. What we _can_ do is expressfnas a com-
position of functions, like this:

fn= ceiling. negate. tan. cos. max 50

Excellent!Many times, a point-free style is more readable and concise,
because it makes you think about functions and what kinds of functions
composing them results in, instead of thinking about data and how it’s shuf-
fled around. You can take simple functions and use composition as glue to
form more complex functions.
However, if a function is too complex, writing it in point-free style can
actually be less readable. For this reason, making long chains of function
composition is discouraged. The preferred style is to useletbindings to give
labels to intermediary results or to split the problem into subproblems that
are easier for someone reading the code to understand.
Earlier in the chapter, we solved the problem of finding the sum of all
odd squares that are smaller than 10,000. Here’s what the solution looks like
when put into a function:

oddSquareSum:: Integer
oddSquareSum = sum (takeWhile (<10000) (filter odd (map (^2) [1..])))

Withour knowledge of function composition, we can also write the func-
tion like this:

oddSquareSum:: Integer
oddSquareSum = sum. takeWhile (<10000). filter odd $ map (^2) [1..]

Itmay seem a bit weird at first, but you will get used to this style quickly.
There’s less visual noise because we removed the parentheses. When reading
this, you can just say thatfilter oddis applied to the result ofmap (^2) [1..],
thentakeWhile (<10000)is applied to the result of that, and finallysumis ap-
plied to that result.

```
Higher-Order Functions 85
```


# 6

## MODULES

AHaskell _module_ is essen-

tially a file that defines

some functions, types,

and type classes. A Has-

kell _program_ is a collection

of modules.

A module can have many func-
tions and types defined inside it, and
it _exports_ some of them. This means
that it makes them available for the outside world to see and use.
Having code split up into several modules has many advantages. If a
module is generic enough, the functions it exports can be used in a multi-
tude of different programs. If your own code is separated into self-contained
modules that don’t rely on each other too much (we also say they are _loosely
coupled_ ), you can reuse them later. Your code is more manageable when you
split it into several parts.
The Haskell standard library is split into modules, and each of them
contains functions and types that are somehow related and serve some com-
mon purpose. There are modules for manipulating lists, concurrent pro-
gramming, dealing with complex numbers, and so on. All the functions,


```
types,and type classes that we’ve dealt with so far are part of thePrelude
module, which is imported by default.
In this chapter, we’re going to examine a few useful modules and their
functions. But first, you need to know how to import modules.
```
## Importing Modules...............................................................

```
The syntax for importing modules in a Haskell script isimport ModuleName.
This must be done before defining any functions, so imports are usually at
the top of the file. One script can import several modules—just put each
importstatement on a separate line.
An example of a useful module isData.List, which has a bunch of func-
tions for working with lists. Let’s import that module and use one of its
functions to create our own function that tells us how many unique ele-
ments a list has.
```
```
importData.List
```
```
numUniques :: (Eq a) => [a] -> Int
numUniques = length. nub
```
```
Whenyou importData.List, all the functions thatData.Listexports be-
come available; you can call them from anywhere in the script. One of those
functions isnub, which takes a list and weeds out duplicate elements. Com-
posinglengthandnubwithlength. nubproduces a function that’s the equiva-
lent of\xs -> length (nub xs).
```
```
NOTE To search for functions or to find out where they’re located, use Hoogle, which can
be found at http://www.haskell.org/hoogle/. It’s a really awesome Haskell
search engine that allows you to search by function name, module name, or even
type signature.
```
```
You can also get access to functions of modules when using GHCi. If
you’re in GHCi and you want to be able to call the functions exported by
Data.List, enter this:
```
```
ghci>:m + Data.List
```
```
Ifyou want to access several modules from GHCi, you don’t need to
enter:m + several times. You can load several modules at once, as in this
example:
```
```
ghci>:m + Data.List Data.Map Data.Set
```
```
However,if you’ve loaded a script that already imports a module, you
don’t need to use:m +to access that module. If you need only a couple of
```
**88** Chapter 6


```
functionsfrom a module, you can selectively import just those functions. For
example, here’s how you could import only thenubandsortfunctions from
Data.List:
```
```
importData.List (nub, sort)
```
```
Youcan also choose to import all of the functions of a module except a
few select ones. That’s often useful when several modules export functions
with the same name and you want to get rid of the offending ones. Say you
already have your own function callednuband you want to import all the
functions fromData.Listexcept thenubfunction. Here’s how to do that:
```
```
importData.List hiding (nub)
```
```
Anotherway of dealing with name clashes is to do qualified imports. Con-
sider theData.Mapmodule, which offers a data structure for looking up val-
ues by key. This module exports a lot of functions with the same name as
Preludefunctions, such asfilterandnull. So if we importedData.Mapand
then calledfilter, Haskell wouldn’t know which function to use. Here’s
how we solve this:
```
```
importqualified Data.Map
```
```
Nowif we want to referenceData.Map’sfilterfunction, we must use
Data.Map.filter. Entering justfilterstill refers to the normalfilterwe all
know and love. But typingData.Mapin front of every function from that mod-
ule is kind of tedious. That’s why we can rename the qualified import to
something shorter:
```
```
importqualified Data.Map as M
```
```
Nowto referenceData.Map’sfilterfunction, we just useM.filter.
As you’ve seen, the.symbol is used to reference functions from mod-
ules that have been imported as qualified, such asM.filter. We also use it to
perform function composition. So how does Haskell know what we mean
when we use it? Well, if we place it between a qualified module name and a
function, without whitespace, it’s regarded as just referring to the imported
function; otherwise, it’s treated as function composition.
```
**NOTE** _A great way to pick up new Haskell knowledge is to just click through the standard
library documentation and explore the modules and their functions. You can also view
the Haskell source code for each module. Reading the source code of some modules will
give you a solid feel for Haskell._

```
Modules 89
```

## Solving Problems with Module Functions............................................

```
The modules in the standard libraries provide many functions that can make
our lives easier when coding in Haskell. Let’s look at some examples of how
to use functions from various Haskell modules to solve problems.
```
## Counting Words.........................................................

```
Suppose we have a string that contains a bunch of words, and we want to
know how many times each word appears in the string. The first module
function we’ll use iswordsfromData.List. Thewordsfunction converts a
string into a list of strings where each string is one word. Here’s a quick
demonstration:
```
```
ghci>words "hey these are the words in this sentence"
["hey","these","are","the","words","in","this","sentence"]
ghci> words "hey these are the words in this sentence"
["hey","these","are","the","words","in","this","sentence"]
```
```
Thenwe’ll use thegroupfunction, which also lives inData.List, to group
together words that are identical. This function takes a list and groups adja-
cent elements into sublists if they are equal:
```
```
ghci>group [1,1,1,1,2,2,2,2,3,3,2,2,2,5,6,7]
[[1,1,1,1],[2,2,2,2],[3,3],[2,2,2],[5],[6],[7]]
```
```
Butwhat happens if the elements that are equal aren’t adjacent in
our list?
```
```
ghci>group ["boom","bip","bip","boom","boom"]
[["boom"],["bip","bip"],["boom","boom"]]
```
```
Weget two lists that contain the string"boom", even though we want all
occurrences of some word to end up in the same list. What are we to do?
Well, we could sort our list of words beforehand! For that, we’ll use thesort
function, which hangs its hat inData.List. It takes a list of things that can
be ordered and returns a new list that is like the old one, but ordered from
smallest to largest:
```
```
ghci>sort [5,4,3,7,2,1]
[1,2,3,4,5,7]
ghci> sort ["boom","bip","bip","boom","boom"]
["bip","bip","boom","boom","boom"]
```
```
Noticethat the strings are put in an alphabetical order.
We have all the ingredients for our recipe. Now we just need to write it
down. We’ll take a string, break it down into a list of words, sort those words,
```
**90** Chapter 6


andthen group them. Finally, we’ll use some mapping magic to get tuples
like("boom", 3), meaning that the word"boom"occurs three times.

importData.List

wordNums :: String -> [(String,Int)]
wordNums = map (\ws -> (head ws, length ws)). group. sort. words

Weused function composition to make our final function. It takes
a string, such as"wa wa wee wa", and then applieswordsto that string, re-
sulting in["wa","wa","wee","wa"]. Thensortis applied to that, and we get
["wa","wa","wa","wee"]. Applyinggroupto this result groups adjacent words
that are equal, so we get a list of lists of strings:[["wa","wa","wa"],["wee"]].
Then we map a function that takes a list and returns a tuple, where the first
component is the head of the list and the second component is its length,
over the grouped words. Our final result is[("wa",3),("wee",1)].
Here’s how we could write this function without function composition:

wordNumsxs = map (\ws -> (head ws,length ws)) (group (sort (words xs)))

Wow,parentheses overload! I think it’s easy to see how function compo-
sition makes this function more readable.

## Needle in the Haystack...................................................

For our next mission, should we choose to accept it, we will make a function
that takes two lists and tells us if the first list is wholly contained anywhere in
the second list. For instance, the list[3,4]is contained in[1,2,3,4,5], whereas
[2,5]isn’t. We’ll refer to the list that’s being searched as the _haystack_ and the
list that we’re searching for as the _needle_.
For this escapade, we’ll use thetailsfunction, which dwells inData.List.
tailstakes a list and successively applies thetailfunction to that list. Here’s
an example:

ghci>tails "party"
["party","arty","rty","ty","y",""]
ghci> tails [1,2,3]
[[1,2,3],[2,3],[3],[]]

Atthis point, it may not be obvious why we needtailsat all. Another
example will clarify this.
Let’s say that we’re searching for the string"art"inside the string"party".
First, we usetailsto get all the tails of the list. Then we examine each tail,
and if any one starts with the string"art", we’ve found the needle in our
haystack! If we were looking for"boo"inside"party", no tail would start with
the string"boo".

```
Modules 91
```

```
Tosee if one string starts with another, we’ll use theisPrefixOffunction,
which is also found inData.List. It takes two lists and tells us if the second
one starts with the first one.
```
```
ghci>"hawaii" `isPrefixOf` "hawaii joe"
True
ghci> "haha" `isPrefixOf` "ha"
False
ghci> "ha" `isPrefixOf` "ha"
True
```
```
Nowwe just need to check if any tail of our haystack starts with our nee-
dle. For that, we can use theanyfunction fromData.List. It takes a predicate
and a list, and it tells us if any element from the list satisfies the predicate.
Behold:
```
```
ghci>any (> 4) [1,2,3]
False
ghci> any (=='F') "Frank Sobotka"
True
ghci> any (\x -> x > 5 && x < 10) [1,4,11]
False
```
```
Let’sput these functions together:
```
```
importData.List
```
```
isIn :: (Eq a) => [a] -> [a] -> Bool
needle `isIn` haystack = any (needle `isPrefixOf`) (tails haystack)
```
```
That’sall there is to it! We usetailsto generate a list of tails of our
haystack and then see if any of them starts with our needle. Let’s give it a
test run:
```
```
ghci>"art" `isIn` "party"
True
ghci> [1,2] `isIn` [1,3,5]
False
```
```
Oh,wait a minute! It turns out that the function that we just made is
already inData.List! Curses! It’s calledisInfixOf, and it does the same work
as ourisInfunction.
```
## Caesar Cipher Salad.....................................................

```
Gaius Julius Caesar has entrusted upon us an important task. We must trans-
port a top-secret message to Mark Antony in Gaul. Just in case we get captured,
```
**92** Chapter 6


we’regoing to use some functions fromData.Char
to be a bit sneaky and encode messages by using
the _Caesar cipher_.
The Caesar cipher is a primitive method of
encoding messages by shifting each character
by a fixed number of positions in the alphabet.
We can easily create a sort of Caesar cipher of
our own, and we won’t constrict ourselves to the
alphabet—we’ll use the whole range of Unicode
characters.
To shift characters forward and backward
in the alphabet, we’re going to use theData.Char
module’sordandchrfunctions, which convert
characters to their corresponding numbers and
vice versa:

ghci>ord 'a'
97
ghci> chr 97
'a'
ghci> map ord "abcdefgh"
[97,98,99,100,101,102,103,104]

ord'a'returns 97 because'a'is the ninety-seventh character in the Uni-
code table of characters.
The difference between theordvalues of two characters is equal to how
far apart they are in the Unicode table.
Let’s write a function that takes a number of positions to shift and a
string, and returns that string where every character is shifted forward in the
alphabet by that many positions.

importData.Char

encode :: Int -> String -> String
encode offset msg = map (\c -> chr $ ord c + offset) msg

Encodinga string is as simple as taking our message and mapping over
it a function that takes a character, converts it to its corresponding number,
adds an offset, and then converts it back to a character. A composition cow-
boy would write this function as(chr. (+ offset). ord).

ghci>encode 3 "hey mark"
"kh|#pdun"
ghci> encode 5 "please instruct your men"
"uqjfxj%nsxywzhy%~tzw%rjs"
ghci> encode 1 "to party hard"
"up!qbsuz!ibse"

```
Modules 93
```

```
That’sdefinitely encoded!
Decoding a message is basically just shifting it back by the number of
places it was shifted by in the first place.
```
```
decode:: Int -> String -> String
decode shift msg = encode (negate shift) msg
```
```
Nowwe can test it by decoding Caesar’s message:
```
```
ghci>decode 3 "kh|#pdun"
"hey mark"
ghci> decode 5 "uqjfxj%nsxywzhy%~tzw%rjs"
"please instruct your men"
ghci> decode 1 "up!qbsuz!ibse"
"to party hard"
```
## On Strict Left Folds.......................................................

```
In the previous chapter, you saw howfoldlworks and how you can use it to
implement all sorts of cool functions. However, there’s a catch tofoldlthat
we haven’t yet explored: Usingfoldlcan sometimes lead to so-called stack
overflow errors, which occur when your program uses too much space in a
specific part of your computer’s memory. To demonstrate, let’s usefoldl
with the+function to sum a list that consists of a hundred 1 s:
```
```
ghci>foldl (+) 0 (replicate 100 1)
100
```
```
Thisseems to work. What if we want to usefoldlto sum a list that has, as
Dr. Evil would put it, one million 1 s?
```
```
ghci>foldl (+) 0 (replicate 1000000 1)
***Exception: stack overflow
```
```
Ooh,that is truly evil! Now why does this
happen? Haskell is lazy, and so it defers actual
computation of values for as long as possible.
When we usefoldl, Haskell doesn’t compute
(that is, evaluate) the actual accumulator on
every step. Instead, it defers its evaluation. In
the next step, it again doesn’t evaluate the accu-
mulator, but defers the evaluation. It also keeps
the old deferred computation in memory, be-
cause the new one often refers to its result. So as
the fold merrily goes along its way, it builds up a
bunch of deferred computations, each taking a not insignificant amount of
memory. Eventually, this can cause a stack overflow error.
```
**94** Chapter 6


```
Here’show Haskell evaluates the expressionfoldl (+) 0 [1,2,3]:
```
foldl(+) 0 [1,2,3] =
foldl (+) (0 + 1) [2,3] =
foldl (+) ((0 + 1) + 2) [3] =
foldl (+) (((0 + 1) + 2) + 3) [] =
((0 + 1) + 2) + 3 =
(1 + 2) + 3 =
3+3=
6

Asyou can see, it first builds up a big stack of deferred computations.
Then, once it reaches the empty list, it goes about actually evaluating those
deferred computations. This isn’t a problem for small lists, but for large lists
that contain upward of a million elements, you get a stack overflow, because
evaluating all these deferred computations is done recursively. Wouldn’t it
be nice if there was a function named, say,foldl', that didn’t defer computa-
tions? It would work like this:

foldl'(+) 0 [1,2,3] =
foldl' (+) 1 [2,3] =
foldl' (+) 3 [3] =
foldl' (+) 6 [] =
6

Computationswouldn’t be deferred between steps offoldl, but would
get evaluated immediately. Well, we’re in luck, becauseData.Listoffers this
stricter version offoldl, and it is indeed calledfoldl'. Let’s try to compute
the sum of a million 1 s withfoldl':

ghci>foldl' (+) 0 (replicate 1000000 1)
1000000

Greatsuccess! So, if you get stack overflow errors when usingfoldl, try
switching tofoldl'. There’s also a stricter version offoldl1, namedfoldl1'.

## Let’s Find Some Cool Numbers............................................

You’rewalking along the street, and an old lady
comes up to you and says, “Excuse me, what’s the
first natural number such that the sum of its digits
equals 40?”
Well, what now, hotshot? Let’s use some Has-
kell magic to find such a number. For instance, if
we sum the digits of the number 123, we get 6, be-
cause 1 + 2 + 3 equals 6. So, what is the first num-
ber that has such a property that its digits add up
to 40?

```
Modules 95
```

```
First,let’s make a function that takes a number and tells us the sum of
its digits. We’re going to use a cool trick here. First, we’ll convert our num-
ber to a string by using theshowfunction. Once we have a string, we’ll turn
each character in that string into a number and then just sum that list of
numbers. To turn a character into a number, we’ll use a handy function
fromData.CharcalleddigitToInt. It takes aCharand returns anInt:
```
```
ghci>digitToInt '2'
2
ghci> digitToInt 'F'
15
ghci> digitToInt 'z'
***Exception: Char.digitToInt: not a digit 'z'
```
```
Itworks on the characters in the range from'0'to'9'and from'A'to
'F'(they can also be in lowercase).
Here’s our function that takes a number and returns the sum of its digits:
```
```
importData.Char
import Data.List
```
```
digitSum :: Int -> Int
digitSum = sum. map digitToInt. show
```
```
Weconvert it to a string, mapdigitToIntover that string, and then sum
the resulting list of numbers.
Now we need to find the first natural number such that when we apply
digitSumto it, we get 40 as the result. To do that, we’ll use thefindfunction,
which resides inData.List. It takes a predicate and a list and returns the first
element of the list that matches the predicate. However, it has a rather pecu-
liar type declaration:
```
```
ghci>:t find
find :: (a -> Bool) -> [a] -> Maybe a
```
```
Thefirst parameter is a predicate, and the
second parameter is a list—no big deal here.
But what about the return value? It saysMaybe a.
That’s a type you haven’t met before. A value
with a type ofMaybe ais sort of like a list of type
[a]. Whereas a list can have zero, one, or many
elements, aMaybe atyped value can have ei-
ther zero elements or just one element. We
use it when we want to represent possible fail-
ure. To make a value that holds nothing, we
just useNothing. This is analogous to the empty
```
**96** Chapter 6


list.To construct a value that holds something, say the string"hey", we write
Just "hey". Here’s a quick demonstration:

ghci>Nothing
Nothing
ghci> Just "hey"
Just "hey"
ghci> Just 3
Just 3
ghci> :t Just "hey"
Just "hey" :: Maybe [Char]
ghci> :t Just True
Just True :: Maybe Bool

Asyou can see, a value ofJust Truehas a type ofMaybe Bool, kind of like
how a list that holds Booleans would have a type of[Bool].
Iffindfinds an element that satisfies the predicate, it will return that
element wrapped in aJust. If it doesn’t, it will return aNothing:

ghci>find (> 4) [3,4,5,6,7]
Just 5
ghci> find odd [2,4,6,8,9]
Just 9
ghci> find (=='z') "mjolnir"
Nothing

Nowlet’s get back to making our function. We have ourdigitSumfunc-
tion and know howfindworks, so all that’s left to do is put these two to-
gether. Remember that we want to find the first number whose digits add
up to 40.

firstTo40:: Maybe Int
firstTo40 = find (\x -> digitSum x == 40) [1..]

Wejust take the infinite list[1..], and then find the first number whose
digitSumis 40.

ghci>firstTo40
Just 49999

There’sour answer! If we want to make a more general function that is
not fixed on 40 but takes our desired sum as the parameter, we can change
it like so:

firstTo:: Int -> Maybe Int
firstTo n = find (\x -> digitSum x == n) [1..]

```
Modules 97
```

```
Here’sa quick test:
```
```
ghci>firstTo 27
Just 999
ghci> firstTo 1
Just 1
ghci> firstTo 13
Just 49
```
## Mapping Keys to Values..........................................................

```
When dealing with data in some sort of collection, we often don’t care if it’s
in some kind of order; we just want to be able to access it by a certain key.
For example, if we want to know who lives at a certain address, we want to
look up the name based on the address. When doing such things, we say that
we looked up our desired value (someone’s name) by some sort of key (that
person’s address).
```
## Almost As Good: Association Lists.........................................

```
There are many ways to achieve key/value mappings. One of them is the as-
sociation list. Association lists (also called dictionaries ) are lists that are used to
store key/value pairs where ordering doesn’t matter. For instance, we might
use an association list to store phone numbers, where phone numbers would
be the values and people’s names would be the keys. We don’t care in which
order they’re stored; we just want to get the right phone number for the
right person.
The most obvious way to represent association lists in Haskell would be
by having a list of pairs. The first component in the pair would be the key,
and the second component would be the value. Here’s an example of an
association list with phone numbers:
```
```
phoneBook=
[("betty", "555-2938")
,("bonnie", "452-2928")
,("patsy", "493-2928")
,("lucille", "205-2928")
,("wendy", "939-8282")
,("penny", "853-2492")
]
```
```
Despitethis seemingly odd indentation, this is just a list of pairs of strings.
The most common task when dealing with association lists is looking
up some value by key. Let’s make a function that looks up some value given
a key.
```
**98** Chapter 6


```
findKey:: (Eq k) => k -> [(k, v)] -> v
findKey key xs = snd. head. filter (\(k, v) -> key == k) $ xs
```
```
Thisis pretty simple. The function takes a key and a list, filters the list so
that only matching keys remain, gets the first key/value pair that matches,
and returns the value.
But what happens if the key we’re looking for isn’t in the association list?
Hmm. Here, if a key isn’t in the association list, we’ll end up trying to get
the head of an empty list, which throws a runtime error. We should avoid
making our programs so easy to crash, so let’s use theMaybedata type. If
we don’t find the key, we’ll return aNothing. If we find it, we’ll returnJust
something , where something is the value corresponding to that key.
```
```
findKey:: (Eq k) => k -> [(k, v)] -> Maybe v
findKey key [] = Nothing
findKey key ((k,v):xs)
| key == x = Just v
| otherwise = findKey key xs
```
```
Lookat the type declaration. It takes a key that can be equated and an
association list, and then it maybe produces a value. Sounds about right.
This is a textbook recursive function that operates on a list. Base case,
splitting a list into a head and a tail, recursive calls—they’re all there. This is
the classic fold pattern, so let’s see how this would be implemented as a fold.
```
findKey:: (Eq k) => k -> [(k, v)] -> Maybe v
findKey key xs = foldr (\(k, v) acc -> if key == k then Just v else acc) Nothing xs

```
NOTE It’s usually better to use folds for this standard list recursion pattern, rather than ex-
plicitly writing the recursion, because they’re easier to read and identify. Everyone
knows it’s a fold when they see thefoldrcall, but it takes some more thinking to read
explicit recursion.
```
```
ghci>findKey "penny" phoneBook
Just "853-2492"
ghci> findKey "betty" phoneBook
Just "555-2938"
ghci> findKey "wilma" phoneBook
Nothing
```
```
Thisworks like a charm! If we have the girl’s phone number, weJustget
the number; otherwise, we getNothing.
```
```
Modules 99
```

## Enter Data.Map.........................................................

```
Wejust implemented thelookupfunction
fromData.List. If we want the value that cor-
responds to a key, we need to traverse all the
elements of the list until we find it.
It turns out that theData.Mapmodule of-
fers association lists that are much faster, and
it also provides a lot of utility functions. From
now on, we’ll say we’re working with maps in-
stead of association lists.
BecauseData.Mapexports functions that
clash with thePreludeandData.Listones, we’ll
do a qualified import.
```
```
importqualified Data.Map as Map
```
```
Putthisimportstatement into a script, and then load the script via GHCi.
We’re going to turn an association list into a map by using thefromList
function fromData.Map.fromListtakes an association list (in the form of a
list) and returns a map with the same associations. Let’s play around a bit
withfromListfirst:
```
```
ghci>Map.fromList [(3,"shoes"),(4,"trees"),(9,"bees")]
fromList [(3,"shoes"),(4,"trees"),(9,"bees")]
ghci> Map.fromList [("kima","greggs"),("jimmy","mcnulty"),("jay","landsman")]
fromList [("jay","landsman"),("jimmy","mcnulty"),("kima","greggs")]
```
```
Whena map fromData.Mapis displayed on the terminal, it’s shown as
fromListand then an association list that represents the map, even though
it’s not a list anymore.
If there are duplicate keys in the original association list, the duplicates
are just discarded:
```
```
ghci>Map.fromList [("MS",1),("MS",2),("MS",3)]
fromList [("MS",3)]
```
```
Thisis the type signature offromList:
```
```
Map.fromList:: (Ord k) => [(k, v)] -> Map.Map k v
```
```
Itsays that it takes a list of pairs of typekandv, and returns a map that
maps from keys of typekto values of typev. Notice that when we were do-
ing association lists with normal lists, the keys only needed to be equatable
(their type belonging to theEqtype class), but now they must be orderable.
That’s an essential constraint in theData.Mapmodule. It needs the keys to be
orderable so it can arrange and access them more efficiently.
```
**100** Chapter 6


Nowwe can modify our originalphoneBookassociation list to be a map.
We’ll also add a type declaration, just because we can:

importqualified Data.Map as Map

phoneBook :: Map.Map String String
phoneBook = Map.fromList $
[("betty", "555-2938")
,("bonnie", "452-2928")
,("patsy", "493-2928")
,("lucille", "205-2928")
,("wendy", "939-8282")
,("penny", "853-2492")
]

Cool!Let’s load this script into GHCi and play around with ourphoneBook.
First, we’ll uselookupto search for some phone numbers.lookuptakes a key
and a map, and tries to find the corresponding value in the map. If it suc-
ceeds, it returns the value wrapped in aJust; otherwise, it returns aNothing:

ghci>:t Map.lookup
Map.lookup :: (Ord k) => k -> Map.Map k a -> Maybe a
ghci> Map.lookup "betty" phoneBook
Just "555-2938"
ghci> Map.lookup "wendy" phoneBook
Just "939-8282"
ghci> Map.lookup "grace" phoneBook
Nothing

Forour next trick, we’ll make a new map fromphoneBookby inserting a
number.inserttakes a key, a value, and a map, and returns a new map that’s
just like the old one, but with the key and value inserted:

ghci>:t Map.insert
Map.insert :: (Ord k) => k -> a -> Map.Map k a -> Map.Map k a
ghci> Map.lookup "grace" phoneBook
Nothing
ghci> let newBook = Map.insert "grace" "341-9021" phoneBook
ghci> Map.lookup "grace" newBook
Just "341-9021"

Let’scheck how many numbers we have. We’ll use thesizefunction
fromData.Map, which takes a map and returns its size. This is pretty straight-
forward:

ghci>:t Map.size
Map.size :: Map.Map k a -> Int

```
Modules 101
```

```
ghci>Map.size phoneBook
6
ghci> Map.size newBook
7
```
```
Thenumbers in our phone book are rep-
resented as strings. Suppose we would rather
use lists ofInts to represent phone numbers.
So, instead of having a number like"939-8282",
we want to have[9,3,9,8,2,8,2]. First, we’re
going to make a function that converts a
phone number string to a list ofInts. We can
try to mapdigitToIntfromData.Charover our
string, but it won’t know what to do with the
dash! That’s why we need to get rid of any-
thing in that string that isn’t a number. To do
this, we’ll seek help from theisDigitfunction
fromData.Char, which takes a character and
tells us if it represents a digit. Once we’ve filtered our string, we’ll just map
digitToIntover it.
```
```
string2digits:: String -> [Int]
string2digits = map digitToInt. filter isDigit
```
```
Oh,be sure toimport Data.Char, if you haven’t already.
Let’s try this out:
```
```
ghci>string2digits "948-9282"
[9,4,8,9,2,8,2]
```
```
Verycool! Now, let’s use themapfunction fromData.Mapto map
string2digitsover ourphoneBook:
```
```
ghci>let intBook = Map.map string2digits phoneBook
ghci> :t intBook
intBook :: Map.Map String [Int]
ghci> Map.lookup "betty" intBook
Just [5,5,5,2,9,3,8]
```
```
ThemapfromData.Maptakesa function and a map, and applies that func-
tion to each value in the map.
Let’s extend our phone book. Say that a person can have several num-
bers, and we have an association list set up like this:
```
```
phoneBook=
[("betty", "555-2938")
,("betty", "342-2492")
,("bonnie", "452-2928")
```
**102** Chapter 6


```
,("patsy", "493-2928")
,("patsy", "943-2929")
,("patsy","827-9162")
,("lucille", "205-2928")
,("wendy", "939-8282")
,("penny", "853-2492")
,("penny", "555-2111")
]
```
```
If we justusefromListto put that into a map, we’ll lose a few numbers!
Instead, we’ll use another function found inData.Map:fromListWith. This
function acts likefromList, but instead of discarding duplicate keys, it uses
a function supplied to it to decide what to do with them.
```
```
phoneBookToMap :: (Ordk) => [(k, String)] -> Map.Map k String
phoneBookToMap xs = Map.fromListWith add xs
where add number1 number2 = number1 ++ ", " ++ number2
```
```
IffromListWithfinds that thekey is already there, it uses the function sup-
plied to it to join those two values into one and replaces the old value with
the one it got by passing the conflicting values to the function:
```
```
ghci> Map.lookup "patsy"$ phoneBookToMap phoneBook
"827-9162, 943-2929, 493-2928"
ghci> Map.lookup "wendy" $ phoneBookToMap phoneBook
"939-8282"
ghci> Map.lookup "betty" $ phoneBookToMap phoneBook
"342-2492, 555-2938"
```
```
We could alsofirst make all the values in the association list singleton
lists and then use++to combine the numbers:
```
```
phoneBookToMap :: (Ordk) => [(k, a)] -> Map.Map k [a]
phoneBookToMap xs = Map.fromListWith (++) $ map (\(k, v) -> (k, [v])) xs
```
```
Let’s test thisin GHCi:
```
```
ghci> Map.lookup "patsy"$ phoneBookToMap phoneBook
["827-9162","943-2929","493-2928"]
```
```
Pretty neat!
Now supposewe’re making a map from an association list of numbers,
and when a duplicate key is found, we want the biggest value for the key to
be kept. We can do that like so:
```
ghci> Map.fromListWith max[(2,3),(2,5),(2,100),(3,29),(3,22),(3,11),(4,22),(4,15)]
fromList [(2,100),(3,29),(4,22)]

```
Modules 103
```

```
Orwe could choose to add together values that share keys:
```
```
ghci>Map.fromListWith (+) [(2,3),(2,5),(2,100),(3,29),(3,22),(3,11),(4,22),(4,15)]
fromList [(2,108),(3,62),(4,37)]
```
```
So,you’ve seen thatData.Mapand the other modules provided by Haskell
are pretty cool. Next, we’ll look at how to make your own module.
```
## Making Our Own Modules........................................................

```
AsI said at the beginning of this chapter,
when you’re writing programs, it’s good
practice to take functions and types that
work toward a similar purpose and put
them in a separate module. That way,
you can easily reuse those functions in
other programs by just importing your
module.
We say that a module exports functions. When you import a module, you
can use the functions that it exports. A module can also define functions
that it uses internally, but we can see and use only the ones that it exports.
```
## A Geometry Module.....................................................

```
To demonstrate, we’ll create a little module that provides some functions for
calculating the volume and area of a few geometrical objects. We’ll start by
creating a file called Geometry.hs.
At the beginning of a module, we specify the module name. If we have a
file called Geometry.hs , then we should name our moduleGeometry. We specify
the functions that it exports, and then we can add the functions. So we’ll
start with this:
```
```
moduleGeometry
( sphereVolume
, sphereArea
, cubeVolume
, cubeArea
, cuboidArea
, cuboidVolume
) where
```
```
Asyou can see, we’ll be doing areas and volumes for spheres, cubes, and
cuboids. A sphere is a round thing like a grapefruit, a cube is like a game die,
and a (rectangular) cuboid is like a box of cigarettes. (Kids, don’t smoke!)
```
**104** Chapter 6


```
Nowlet’s define our functions:
```
moduleGeometry
( sphereVolume
, sphereArea
, cubeVolume
, cubeArea
, cuboidArea
, cuboidVolume
) where

sphereVolume :: Float -> Float
sphereVolume radius = (4.0 / 3.0)*pi*(radius ^ 3)

sphereArea :: Float -> Float
sphereArea radius = 4*pi*(radius ^ 2)

cubeVolume :: Float -> Float
cubeVolume side = cuboidVolume side side side

cubeArea :: Float -> Float
cubeArea side = cuboidArea side side side

cuboidVolume :: Float -> Float -> Float -> Float
cuboidVolume a b c = rectArea a b*c

cuboidArea :: Float -> Float -> Float -> Float
cuboidArea a b c = rectArea a b*2 + rectArea a c*2+
rectArea c b* 2

rectArea :: Float -> Float -> Float
rectArea a b = a*b

Thisis pretty standard geometry, but there are a few items to note. One
is that because a cube is only a special case of a cuboid, we define its area
and volume by treating it as a cuboid whose sides are all of the same length.
We also define a helper function calledrectArea, which calculates a rectan-
gle’s area based on the lengths of its sides. It’s rather trivial because it’s just
multiplication. Notice that we used it in our functions in the module (in
cuboidAreaandcuboidVolume), but we didn’t export it! This is because we want
our module to present just functions for dealing with three-dimensional
objects.
When making a module, we usually export only those functions that act
as a sort of interface to our module so that the implementation is hidden.
People who use ourGeometrymodule don’t need to concern themselves with
functions that we don’t export. We can decide to change those functions
completely or delete them in a newer version (we could deleterectAreaand

```
Modules 105
```

```
justuse*instead), and no one will mind, because we didn’t export them in
the first place.
To use our module, we just do this:
```
```
importGeometry
```
```
However, Geometry.hs must be in the same folder as the module that’s
importing it.
```
## Hierarchical Modules

```
Modules can also be given a hierarchical structure. Each module can have
a number of submodules, which can have submodules of their own. Let’s
section our geometry functions so thatGeometryis a module that has three
submodules: one for each type of object.
First, we’ll make a folder called Geometry. In it, we’ll place three files:
Sphere.hs , Cuboid.hs , and Cube.hs. Let’s look at what each of the files contains.
Here are the contents of Sphere.hs :
```
```
moduleGeometry.Sphere
( volume
, area
) where
```
```
volume :: Float -> Float
volume radius = (4.0 / 3.0)*pi*(radius ^ 3)
```
```
area :: Float -> Float
area radius = 4*pi*(radius ^ 2)
```
```
The Cuboid.hs filelooks like this:
```
```
moduleGeometry.Cuboid
( volume
, area
) where
```
```
volume :: Float -> Float -> Float -> Float
volume a b c = rectArea a b*c
```
```
area :: Float -> Float -> Float -> Float
area a b c = rectArea a b*2 + rectArea a c*2 + rectArea c b* 2
```
```
rectArea :: Float -> Float -> Float
rectArea a b = a*b
```
**106** Chapter 6


```
Andour last file, Cube.hs , has these contents:
```
moduleGeometry.Cube
( volume
, area
) where

import qualified Geometry.Cuboid as Cuboid

volume :: Float -> Float
volume side = Cuboid.volume side side side

area :: Float -> Float
area side = Cuboid.area side side side

```
Noticehow we placed Sphere.hs in a folder call-
ed Geometry , and then defined the module name as
Geometry.Sphere. We did the same for the cube and
cuboid objects. Also notice how in all three sub-
modules, we defined functions with the same names.
We can do this because they’re in separate modules.
So, now we can do this:
```
```
importGeometry.Sphere
```
Andthen we can callareaandvolume, and they’ll
give us the area and volume for a sphere.
If we want to juggle two or more of these modules, we need to do quali-
fied imports because they export functions with the same names. Here’s an
example:

importqualified Geometry.Sphere as Sphere
import qualified Geometry.Cuboid as Cuboid
import qualified Geometry.Cube as Cube

Andthen we can callSphere.area,Sphere.volume,Cuboid.area, and so on,
and each will calculate the area or volume for its corresponding object.
The next time you find yourself writing a file that’s really big and has a
lot of functions, look for functions that serve some common purpose and
consider putting them in their own module. Then you’ll be able to just im-
port your module the next time you’re writing a program that requires some
of the same functionality.

```
Modules 107
```


# 7

## MAKING OUR OWN TYPES AND TYPE CLASSES

```
Sofar, we’ve run into a lot of
data types:Bool,Int,Char,Maybe,
and so on. But how do we make
our own? In this chapter, you’ll
learn how to create custom
types and put them to work!
```
## Defining a New Data Type........................................................

```
One way to make our own type is to use thedatakeyword. Let’s see how the
Booltype is defined in the standard library.
```
```
dataBool = False | True
```
```
Usingthedatakeyword like this means that a new data type is being de-
fined. The part before the equal sign denotes the type, which in this case is
Bool. The parts after the equal sign are value constructors. They specify the
different values that this type can have. The|is read as or. So we can read
this as saying that theBooltype can have a value ofTrueorFalse. Note that
```

```
boththe type name and the value constructors must start with an uppercase
letter.
In a similar fashion, we can think of theInttype as being defined like this:
```
```
dataInt = -2147483648 | -2147483647 | ... | -1 | 0 | 1 | 2 | ... | 2147483647
```
```
Thefirst and last value constructors are the minimum and maximum
possible values ofInt. It’s not actually defined like this—you can see I’ve
omitted a bunch of numbers—but this is useful for illustrative purposes.
Now let’s think about how we would represent a shape in Haskell. One
way would be to use tuples. A circle could be denoted as(43.1, 55.0, 10.4),
where the first and second fields are the coordinates of the circle’s center
and the third field is the radius. The problem is that those could also repre-
sent a 3D vector or anything else that could be identified by three numbers.
A better solution would be to make our own type to represent a shape.
```
## Shaping Up......................................................................

```
Let’s say that a shape can be a circle or a rectangle. Here’s one possible
definition:
```
```
dataShape = Circle Float Float Float | Rectangle Float Float Float Float
```
```
Whatdoes it mean? Think of it like this: TheCirclevalue constructor
has three fields, which take floats. So when we write a value constructor, we
can optionally add some types after it, and those types define the types of
values it will contain. Here, the first two fields are the coordinates of its cen-
ter, and the third one is its radius. TheRectanglevalue constructor has four
fields that accept floats. The first two act as the coordinates to its upper-left
corner, and the second two act as coordinates to its lower-right corner.
Value constructors are actually functions that ultimately return a value
of a data type. Let’s take a look at the type signatures for these two value
constructors.
```
```
ghci>:t Circle
Circle :: Float -> Float -> Float -> Shape
ghci> :t Rectangle
Rectangle :: Float -> Float -> Float -> Float -> Shape
```
```
Sovalue constructors are functions like everything else. Who would have
thought? The fields that are in the data type act as parameters to its value
constructors.
```
**110** Chapter 7


```
Nowlet’s make a function that takes aShapeand returns its area.
```
area:: Shape -> Float
area (Circle _ _ r) = pi*r^2
area (Rectangle x1 y1 x2 y2) = (abs $ x2 - x1)*(abs $ y2 - y1)

First,note the type declaration. It says that the function takes aShape
and returns aFloat. We couldn’t write a type declaration ofCircle -> Float,
becauseCircleis not a type, whileShapeis (just as we can’t write a function
with a type declaration ofTrue -> Int, for example).
Next, notice that we can pattern match against constructors. We’ve al-
ready done this against values like[],False, and 5 , but those values didn’t
have any fields. In this case, we just write a constructor and then bind its
fields to names. Because we’re interested in only the radius, we don’t actu-
ally care about the first two fields, which tell us where the circle is.

ghci>area $ Circle 10 20 10
314.15927
ghci> area $ Rectangle 0 0 100 100
10000.0

Yay,it works! But if we try to just print outCircle 10 20 5from the prompt,
we’ll get an error. That’s because Haskell doesn’t know how to display our
data type as a string (yet). Remember that when we try to print a value out
from the prompt, Haskell first applies theshowfunction to it to get the string
representation of our value, and then it prints that to the terminal.
To make ourShapetype part of theShowtype class, we modify it like this:

dataShape = Circle Float Float Float | Rectangle Float Float Float Float
deriving (Show)

Wewon’t concern ourselves withderivingtoo much for now. Let’s just
say that if we addderiving (Show)at the end of a data declaration (it can go
on the same line or the next one—it doesn’t matter), Haskell automatically
makes that type part of theShowtype class. We’ll be taking a closer look at
derivingin “Derived Instances” on page 122.
So now we can do this:

ghci>Circle 10 20 5
Circle 10.0 20.0 5.0
ghci> Rectangle 50 230 60 90
Rectangle 50.0 230.0 60.0 90.0

```
Making Our Own Types and Type Classes 111
```

```
Valueconstructors are functions, so we can map them, partially apply
them, and so on. If we want a list of concentric circles with different radii,
we can do this:
```
```
ghci>map (Circle 10 20) [4,5,6,6]
[Circle 10.0 20.0 4.0,Circle 10.0 20.0 5.0,Circle 10.0 20.0 6.0,Circle 10.0
20.0 6.0]
```
## Improving Shape with the Point Data Type..................................

```
Our data type is good, but it could be better. Let’s make an intermediate
data type that defines a point in two-dimensional space. Then we can use
that to make our shapes more understandable.
```
```
dataPoint = Point Float Float deriving (Show)
data Shape = Circle Point Float | Rectangle Point Point deriving (Show)
```
```
Noticethat when defining a point, we used the same name for the data
type and the value constructor. This has no special meaning, although it’s
common if there’s only one value constructor. So now theCirclehas two
fields: One is of typePointand the other of typeFloat. This makes it easier
to understand what’s what. The same goes forRectangle. Now we need to
adjust ourareafunction to reflect these changes.
```
```
area:: Shape -> Float
area (Circle _ r) = pi*r^2
area (Rectangle (Point x1 y1) (Point x2 y2)) = (abs $ x2 - x1)*(abs $ y2 - y1)
```
```
Theonly thing we needed to change were the patterns. We disregarded
the whole point in theCirclepattern. In theRectanglepattern, we just used
nested pattern matching to get the fields of the points. If we wanted to refer-
ence the points themselves for some reason, we could have used as-patterns.
Now we can test our improved version:
```
```
ghci>area (Rectangle (Point 0 0) (Point 100 100))
10000.0
ghci> area (Circle (Point 0 0) 24)
1809.5574
```
```
Howabout a function that nudges a shape? It takes a shape, the amount
to move it on the x axis, and the amount to move it on the y axis. It returns a
new shape that has the same dimensions but is located somewhere else.
```
```
nudge:: Shape -> Float -> Float -> Shape
nudge (Circle (Point x y) r) a b = Circle (Point (x+a) (y+b)) r
nudge (Rectangle (Point x1 y1) (Point x2 y2)) a b
= Rectangle (Point (x1+a) (y1+b)) (Point (x2+a) (y2+b))
```
**112** Chapter 7


Thisis pretty straightforward. We add the nudge amounts to the points
that denote the position of the shape. Let’s test it:

ghci>nudge (Circle (Point 34 34) 10) 5 10
Circle (Point 39.0 44.0) 10.0

Ifwe don’t want to deal with points directly, we can make some auxiliary
functions that create shapes of some size at the zero coordinates and then
nudge those.
First, let’s make a function that takes a radius and makes a circle that is
located at the origin of the coordinate system, with the radius we supplied:

baseCircle:: Float -> Shape
baseCircle r = Circle (Point 0 0) r

Nowlet’s make a function that takes a width and a height and makes
a rectangle with those dimensions and its bottom-left corner located at the
origin:

baseRect:: Float -> Float -> Shape
baseRect width height = Rectangle (Point 0 0) (Point width height)

Nowwe can use these functions to make shapes that are located at the
origin of the coordinate system and then nudge them to where we want
them to be, which makes it easier to create shapes:

ghci>nudge (baseRect 40 100) 60 23
Rectangle (Point 60.0 23.0) (Point 100.0 123.0)

## Exporting Our Shapes in a Module........................................

You can also export your data types in your custom modules. To do that, just
write your type along with the functions you are exporting, and then add
some parentheses that specify the value constructors that you want to export,
separated by commas. If you want to export all the value constructors for a
given type, just write two dots (..).
Suppose we want to export our shape functions and types in a module.
We start off like this:

moduleShapes
( Point(..)
, Shape(..)
, area
, nudge
, baseCircle
, baseRect
) where

```
Making Our Own Types and Type Classes 113
```

```
ByusingShape(..), we export all the value constructors forShape.
This means that people who import our module can make shapes by us-
ing theRectangleandCirclevalue constructors. It’s the same as writing
Shape (Rectangle, Circle), but shorter.
Also, if we decide to add some value constructors to our type later on,
we don’t need to modify the exports. That’s because using..automatically
exports all value constructors for a given type.
Alternatively, we could opt to not export any value constructors forShape
by just writingShapein the export statement, without the parentheses. That
way, people who import our module could make shapes only by using the
auxiliary functionsbaseCircleandbaseRect.
Remember that value constructors are just functions that take the fields
as parameters and return a value of some type (likeShape). So when we
choose not to export them, we prevent the person importing our module
from using those value constructors directly. Not exporting the value con-
structors of our data types makes them more abstract, since we’re hiding
their implementation. Also, whoever uses our module can’t pattern match
against the value constructors. This is good if we want people who import
our module to be able to interact with our type only via the auxiliary func-
tions that we supply in our module. That way, they don’t need to know about
the internal details of our module, and we can change those details when-
ever we want, as long as the functions that we export act the same.
Data.Mapuses this approach. You can’t create a map by directly using its
value constructor, whatever it may be, because it’s not exported. However,
you can make a map by using one of the auxiliary functions likeMap.fromList.
The people in charge ofData.Mapcan change the way that maps are inter-
nally represented without breaking existing programs.
But for simpler data types, exporting the value constructors is perfectly
fine, too.
```
## Record Syntax...................................................................

```
Nowlet’s look at how we can create an-
other kind of data type. Say we’ve been
tasked with creating a data type that
describes a person. The information
that we want to store about that person
is first name, last name, age, height,
phone number, and favorite ice cream
flavor. (I don’t know about you, but
that’s all I ever want to know about a
person.) Let’s give it a go!
```
```
dataPerson = Person String String Int Float String String deriving (Show)
```
**114** Chapter 7


Thefirst field is the first name, the second is the last name, the third is
the age, and so on. Now let’s make a person.

ghci>let guy = Person "Buddy" "Finklestein" 43 184.2 "526-2928" "Chocolate"
ghci> guy
Person "Buddy" "Finklestein" 43 184.2 "526-2928" "Chocolate"

That’skind of cool, although slightly unreadable.
Now what if we want to create functions to get specific pieces of infor-
mation about a person? We need a function that gets some person’s first
name, a function that gets some person’s last name, and so on. Well, we
would need to define them like this:

firstName:: Person -> String
firstName (Person firstname _ _ _ _ _) = firstname

lastName :: Person -> String
lastName (Person _ lastname _ _ _ _) = lastname

age :: Person -> Int
age (Person _ _ age _ _ _) = age

height :: Person -> Float
height (Person _ _ _ height _ _) = height

phoneNumber :: Person -> String
phoneNumber (Person _ _ _ _ number _) = number

flavor :: Person -> String
flavor (Person _ _ _ _ _ flavor) = flavor

Whew!I certainly did not enjoy writing that! But despite being very
cumbersome and _boring_ to write, this method works.

ghci>let guy = Person "Buddy" "Finklestein" 43 184.2 "526-2928" "Chocolate"
ghci> firstName guy
"Buddy"
ghci> height guy
184.2
ghci> flavor guy
"Chocolate"

```
“Still,there must be a better way!” you say. Well, no, there isn’t, sorry.
Just kidding—there is. Hahaha!
```
```
Making Our Own Types and Type Classes 115
```

```
Haskellgives us an alternative way to write data types. Here’s how we
could achieve the same functionality with record syntax :
```
```
dataPerson = Person { firstName :: String
, lastName :: String
, age :: Int
, height :: Float
, phoneNumber :: String
, flavor :: String } deriving (Show)
```
```
Soinstead of just naming the field types one after another and separat-
ing them with spaces, we use curly brackets. First, we write the name of the
field (for instance,firstName), followed by a double colon (::), and then the
type. The resulting data type is exactly the same. The main benefit of us-
ing this syntax is that it creates functions that look up fields in the data type.
By using record syntax to create this data type, Haskell automatically makes
these functions:firstName,lastName,age,height,phoneNumber, andflavor. Take
a look:
```
```
ghci>:t flavor
flavor :: Person -> String
ghci> :t firstName
firstName :: Person -> String
```
```
There’sanother benefit to using record syntax. When we deriveShow
for the type, it displays it differently if we use record syntax to define and
instantiate the type.
Say we have a type that represents a car. We want to keep track of the
company that made it, the model name, and its year of production. We can
define this type without using record syntax, like so:
```
```
dataCar = Car String String Int deriving (Show)
```
```
Acar is displayed like this:
```
```
ghci>Car "Ford" "Mustang" 1967
Car "Ford" "Mustang" 1967
```
```
Nowlet’s see what happens when we define it using record syntax:
```
```
dataCar = Car { company :: String
, model :: String
, year :: Int
} deriving (Show)
```
**116** Chapter 7


```
Wecan make a car like this:
```
```
ghci>Car {company="Ford", model="Mustang", year=1967}
Car {company = "Ford", model = "Mustang", year = 1967}
```
```
Whenmaking a new car, we don’t need to put the fields in the proper
order, as long as we list all of them. But if we don’t use record syntax, we
must specify them in order.
Use record syntax when a constructor has several fields and it’s not
obvious which field is which. If we make a 3D vector data type by doing
data Vector = Vector Int Int Int, it’s pretty obvious that the fields are the
components of a vector. However, in ourPersonandCartypes, the fields
are not so obvious, and we greatly benefit from using record syntax.
```
## Type Parameters.................................................................

```
A value constructor can take some parameters and then produce a new
value. For instance, theCarconstructor takes three values and produces a
carvalue. In a similar manner, type constructors can take types as parame-
ters to produce new types. This might sound a bit too meta at first, but it’s
not that complicated. (If you’re familiar with templates in C++, you’ll see
some parallels.) To get a clear picture of how type parameters work in ac-
tion, let’s take a look at how a type we’ve already met is implemented.
```
```
dataMaybe a = Nothing | Just a
```
```
Theahereis the type parameter.
And because there’s a type parameter
involved, we callMaybea type construc-
tor. Depending on what we want this
data type to hold when it’s notNothing,
this type constructor can end up pro-
ducing a type ofMaybe Int,Maybe Car,
Maybe String, and so on. No value can
have a type of justMaybe, because that’s
not a type—it’s a type constructor. In
order for this to be a real type that a
value can be part of, it must have all its
type parameters filled up.
So if we passCharas the type pa-
rameter toMaybe, we get a type of
Maybe Char. The valueJust 'a'has a
type ofMaybe Char, for example.
Most of the time, we don’t pass types as parameters to type constructors
explicitly. That’s because Haskell has type inference. So when we make a
valueJust 'a', for example, Haskell figures out that it’s aMaybe Char.
```
```
Making Our Own Types and Type Classes 117
```

```
Ifwe want to explicitly pass a type as a type parameter, we must do it in
the type part of Haskell, which is usually after the::symbol. This can come
in handy if, for example, we want a value ofJust 3to have the typeMaybe Int.
By default, Haskell will infer the type(Num a) => Maybe afor that value. We
can use an explicit type annotation to restrict the type a bit:
```
```
ghci>Just 3 :: Maybe Int
Just 3
```
```
Youmight not know it, but we used a type that has a type parameter be-
fore we usedMaybe: the list type. Although there’s some syntactic sugar in
play, the list type takes a parameter to produce a concrete type. Values can
have an[Int]type, a[Char]type, or a[[String]]type, but you can’t have a
value that just has a type of[].
```
```
NOTE We say that a type is concrete if it doesn’t take any type parameters at all (likeIntor
Bool), or if it takes type parameters and they’re all filled up (likeMaybe Char). If you
have some value, its type is always a concrete type.
```
```
Let’s play around with theMaybetype:
```
```
ghci>Just "Haha"
Just "Haha"
ghci> Just 84
Just 84
ghci> :t Just "Haha"
Just "Haha" :: Maybe [Char]
ghci> :t Just 84
Just 84 :: (Num a) => Maybe a
ghci> :t Nothing
Nothing :: Maybe a
ghci> Just 10 :: Maybe Double
Just 10.0
```
```
Typeparameters are useful because they allow us to make data types
that can hold different things. For instance, we could make a separateMaybe-
like data type for every type that it could contain, like so:
```
```
dataIntMaybe = INothing | IJust Int
```
```
data StringMaybe = SNothing | SJust String
```
```
data ShapeMaybe = ShNothing | ShJust Shape
```
```
Buteven better, we could use type parameters to make a genericMaybe
that can contain values of any type at all!
```
**118** Chapter 7


Noticethat the type ofNothingisMaybe a. Its type is _polymorphic_ , which
means that it features type variables, namely theainMaybe a. If some func-
tion requires aMaybe Intas a parameter, we can give it aNothing, because
aNothingdoesn’t contain a value anyway, so it doesn’t matter. TheMaybe a
type can act like aMaybe Intif it must, just as 5 can act like anIntor aDouble.
Similarly, the type of the empty list is[a]. An empty list can act like a list of
anything. That’s why we can do[1,2,3] ++ []and["ha","ha","ha"] ++ [].

## Should We Parameterize Our Car?........................................

When does using type parameters make sense? Usually, we use them when
our data type would work regardless of the type of the value it then holds, as
with ourMaybe atype. If our type acts as some kind of box, it’s good to use
parameters.
Consider ourCardata type:

dataCar = Car { company :: String
, model :: String
, year :: Int
} deriving (Show)

```
Wecould change it to this:
```
dataCar a b c = Car { company :: a
, model :: b
, year :: c
} deriving (Show)

Butwould we really benefit? Probably not, because we would just end
up defining functions that work on only theCar String String Inttype. For
instance, given our first definition ofCar, we could make a function that dis-
plays the car’s properties in an easy-to-read format.

tellCar:: Car -> String
tellCar (Car {company = c, model = m, year = y}) =
"This " ++ c ++ " " ++ m ++ " was made in " ++ show y

```
Wecould test it like this:
```
ghci>let stang = Car {company="Ford", model="Mustang", year=1967}
ghci> tellCar stang
"This Ford Mustang was made in 1967"

It’sa good little function! The type declaration is cute, and it works
nicely.

```
Making Our Own Types and Type Classes 119
```

```
Nowwhat ifCarwasCar a b c?
```
```
tellCar:: (Show a) => Car String String a -> String
tellCar (Car {company = c, model = m, year = y}) =
"This " ++ c ++ " " ++ m ++ " was made in " ++ show y
```
```
Wewould need to force this function to take aCartype of(Show a) =>
Car String String a. You can see that the type signature is more complicated,
and the only actual benefit would be that we could use any type that’s an
instance of theShowtype class as the type forc:
```
```
ghci>tellCar (Car "Ford" "Mustang" 1967)
"This Ford Mustang was made in 1967"
ghci> tellCar (Car "Ford" "Mustang" "nineteen sixty seven")
"This Ford Mustang was made in \"nineteen sixty seven\""
ghci> :t Car "Ford" "Mustang" 1967
Car "Ford" "Mustang" 1967 :: (Num t) => Car [Char] [Char] t
ghci> :t Car "Ford" "Mustang" "nineteen sixty seven"
Car "Ford" "Mustang" "nineteen sixty seven" :: Car [Char] [Char] [Char]
```
```
Inreal life though, we would end up usingCar String String Intmost of
the time. So, parameterizing theCartype isn’t worth it.
We usually use type parameters when the type that’s contained inside the
data type’s various value constructors isn’t really that important for the type
to work. A list of stuff is a list of stuff, and it doesn’t matter what the type of
that stuff is. If we need to sum a list of numbers, we can specify later in the
summing function that we specifically want a list of numbers. The same goes
forMaybe, which represents an option of either having nothing or having one
of something. It doesn’t matter what the type of that something is.
Another example of a parameterized type that you’ve already met is
Map k vfromData.Map. Thekis the type of the keys in a map, andvis the type
of the values. This is a good example of where type parameters are very use-
ful. Having maps parameterized enables us to have mappings from any type
to any other type, as long as the type of the key is part of theOrdtype class. If
we were defining a mapping type, we could add a type class constraint in the
data declaration:
```
```
data(Ord k) => Map k v = ...
```
```
However,it’s a very strong convention in Haskell to never add type class
constraints in data declarations. Why? Well, because it doesn’t provide much
benefit, and we end up writing more class constraints, even when we don’t
need them. If we put theOrd kconstraint in the data declaration forMap k v,
we still need to put the constraint into functions that assume the keys in a
map can be ordered. If we don’t put the constraint in the data declaration,
then we don’t need to put(Ord k) =>in the type declarations of functions
that don’t care whether the keys can be ordered. An example of such a func-
tion istoList, which just takes a mapping and converts it to an associative list.
```
**120** Chapter 7


Its type signatureistoList :: Map k a -> [(k, a)]. IfMap k vhad a type con-
straint in its data declaration, the type fortoListwould need to betoList ::
(Ord k) => Map k a -> [(k, a)], even though the function doesn’t compare
keys by order.
So don’t put type constraints into data declarations, even if it seems to
make sense. You’ll need to put them into the function type declarations ei-
ther way.

## Vector von Doom........................................................

Let’s implement a 3D vector type and add some operations for it. We’ll
make it a parameterized type, because even though it will usually contain
numeric types, it will still support several of them, likeInt,Integer, and
Double, to name a few.

data Vector a= Vector a a a deriving (Show)

vplus :: (Num a) => Vector a -> Vector a -> Vector a
(Vector i j k) `vplus` (Vector l m n) = Vector (i+l) (j+m) (k+n)

dotProd :: (Num a) => Vector a -> Vector a -> a
(Vector i j k) `dotProd` (Vector l m n) = i*l+j*m+k*n

vmult :: (Num a) => Vector a -> a -> Vector a
(Vector i j k) `vmult` m = Vector (i*m) (j*m) (k*m)

Imagine a vectoras an arrow in space—a line that points somewhere.
The vectorVector 3 4 5would be a line that starts at the coordinates (0,0,0)
in 3D space and ends at (and points to) the coordinates (3,4,5).
The vector functions work as follows:

- Thevplusfunction adds two vectors together. This is done just by adding
    their corresponding components. When you add two vectors, you get a
    vector that’s the same as putting the second vector at the end of the first
    one and then drawing a vector from the beginning of the first one to the
    end of the second one. So adding two vectors together results in a third
    vector.
- ThedotProdfunction gets the dot product of two vectors. The result
    of a dot product is a number, and we get it by multiplying the compo-
    nents of a vector pairwise and then adding all that together. The dot
    product of two vectors is useful when we want to figure out the angle
    between two vectors.
- Thevmultfunction multiplies a vector with a number. If we multiply a
    vector with a number, we multiply every component of the vector with
    that number, effectively elongating (or shortening it), but it keeps on
    pointing in the same general direction.

```
Making Our Own Types and Type Classes 121
```

```
Thesefunctions can operate on any type in the form ofVector a, as long
as theais an instance of theNumtype class. For instance, they can operate on
values of typeVector Int,Vector Integer,Vector Float, and so on, becauseInt,
Integer, andFloatare all instances of theNumtype class. However, they won’t
work on values of typeVector CharorVector Bool.
Also, if you examine the type declaration for these functions, you’ll see
that they can operate only on vectors of the same type, and the numbers in-
volved must also be of the type that is contained in the vectors. We can’t add
together aVector Intand aVector Double.
Notice that we didn’t put aNumclass constraint in the data declaration.
As explained in the previous section, even if we put it there, we would still
need to repeat it in the functions.
Once again, it’s very important to distinguish between the type construc-
tor and the value constructor. When declaring a data type, the part before
the=is the type constructor, and the constructors after it (possibly separated
by|characters) are value constructors. For instance, giving a function the
following type would be wrong:
```
```
Vectora a a -> Vector a a a -> a
```
```
Thisdoesn’t work because the type of our vector isVector a, and not
Vector a a a. It takes only one type parameter, even though its value con-
structor has three fields.
Now, let’s play around with our vectors.
```
```
ghci>Vector 3 5 8 `vplus` Vector 9 2 8
Vector 12 7 16
ghci> Vector 3 5 8 `vplus` Vector 9 2 8 `vplus` Vector 0 2 3
Vector 12 9 19
ghci> Vector 3 9 7 `vmult` 10
Vector 30 90 70
ghci> Vector 4 9 5 `dotProd` Vector 9.0 2.0 4.0
74.0
ghci> Vector 2 9 3 `vmult` (Vector 4 9 5 `dotProd` Vector 9 2 4)
Vector 148 666 222
```
## Derived Instances.................................................................

```
In“Type Classes 101” on page 27, you learned that a type class
is a sort of an interface that defines some behavior, and that a
type can be made an instance of a type class if it supports that
behavior. For example, theInttype is an instance of theEq
type class because theEqtype class defines behavior for stuff
that can be equated. And because integers can be equated,Int
was made a part of theEqtype class. The real usefulness comes
with the functions that act as the interface forEq, namely==
and/=. If a type is a part of theEqtype class, we can use the
```
**122** Chapter 7


==functionswith values of that type. That’s why expressions like4 == 4and
"foo" == "bar"type check.
Haskell type classes are often confused with classes in languages like
Java, Python, C++ and the like, which trips up a lot of programmers. In those
languages, classes are a blueprint from which we create objects that can do
some actions. But we don’t make data from Haskell type classes. Instead, we
first make our data type, and then we think about how it can act. If it can act
like something that can be equated, we make it an instance of theEqtype
class. If it can act like something that can be ordered, we make it an instance
of theOrdtype class.
Let’s see how Haskell can automatically make our type an instance of
any of the following type classes:Eq,Ord,Enum,Bounded,Show, andRead. Haskell
can derive the behavior of our types in these contexts if we use thederiving
keyword when making our data type.

## Equating People.........................................................

Consider this data type:

dataPerson = Person { firstName :: String
, lastName :: String
, age :: Int
}

Itdescribes a person. Let’s assume that no two people have the same
combination of first name, last name, and age. If we have records for two
people, does it make sense to see if they represent the same person? Sure
it does. We can try to equate them to see if they are equal. That’s why it
would make sense for this type to be part of theEqtype class. We’ll derive
the instance.

dataPerson = Person { firstName :: String
, lastName :: String
, age :: Int
} deriving (Eq)

Whenwe derive theEqinstance for a type and then try to compare two
values of that type with==or/=, Haskell will see if the value constructors
match (there’s only one value constructor here though), and then it will
check if all the data contained inside matches by testing each pair of fields
with==. However, there’s a catch: The types of all the fields also must be
part of theEqtype class. But since that’s the case with bothStringandInt,
we’re okay.
First, let’s make a few people. Put the following in a script:

mikeD= Person {firstName = "Michael", lastName = "Diamond", age = 43}
adRock = Person {firstName = "Adam", lastName = "Horovitz", age = 41}
mca = Person {firstName = "Adam", lastName = "Yauch", age = 44}

```
Making Our Own Types and Type Classes 123
```

```
Nowlet’s test ourEqinstance:
```
```
ghci>mca == adRock
False
ghci> mikeD == adRock
False
ghci> mikeD == mikeD
True
ghci> mikeD == Person {firstName = "Michael", lastName = "Diamond", age = 43}
True
```
```
Ofcourse, sincePersonis now inEq, we can use it as theafor all func-
tions that have a class constraint ofEq ain their type signature, such aselem.
```
```
ghci>let beastieBoys = [mca, adRock, mikeD]
ghci> mikeD `elem` beastieBoys
True
```
## Show Me How to Read...................................................

```
TheShowandReadtype classes are for things that can be converted to or from
strings, respectively. As withEq, if a type’s constructors have fields, their type
must be a part ofShoworReadif we want to make our type an instance of
them.
Let’s make ourPersondata type a part ofShowandReadas well.
```
```
dataPerson = Person { firstName :: String
, lastName :: String
, age :: Int
} deriving (Eq, Show, Read)
```
```
Nowwe can print a person out to the terminal.
```
```
ghci>mikeD
Person {firstName = "Michael", lastName = "Diamond", age = 43}
ghci> "mikeD is: " ++ show mikeD
"mikeD is: Person {firstName = \"Michael\", lastName = \"Diamond\", age = 43}"
```
```
Ifwe had tried to print a person on the terminal before making the
Persondata type part ofShow, Haskell would have complained, claiming it
didn’t know how to represent a person as a string. But since we first derived
aShowinstance for the data type, we didn’t get any complaints.
Readis pretty much the inverse type class ofShow. It’s for converting
strings to values of our type. Remember though, that when we use theread
function, we might need to use an explicit type annotation to tell Haskell
```
**124** Chapter 7


whichtype we want to get as a result. To demonstrate this, let’s put a string
that represents a person in a script and then load that script in GHCi:

mysteryDude= "Person { firstName =\"Michael\"" ++
", lastName =\"Diamond\"" ++
", age = 43}"

Wewrote our string across several lines like this for increased readabil-
ity. If we want toreadthat string, we need to tell Haskell which type we ex-
pect in return:

ghci>read mysteryDude :: Person
Person {firstName = "Michael", lastName = "Diamond", age = 43}

Ifwe use the result of ourreadlater in a way that Haskell can infer that it
should read it as a person, we don’t need to use type annotation.

ghci>read mysteryDude == mikeD
True

Wecan also read parameterized types, but we must give Haskell enough
information so that it can figure out which type we want. If we try the follow-
ing, we’ll get an error:

ghci>read "Just 3" :: Maybe a

Inthis case, Haskell doesn’t know which type to use for the type parame-
tera. But if we tell it that we want it to be anInt, it works just fine:

ghci>read "Just 3" :: Maybe Int
Just 3

## Order in the Court!......................................................

We can derive instances for theOrdtype class, which is for types that have
values that can be ordered. If we compare two values of the same type that
were made using different constructors, the value that was defined first is
considered smaller. For instance, consider theBooltype, which can have a
value of eitherFalseorTrue. For the purpose of seeing how it behaves when
compared, we can think of it as being implemented like this:

dataBool = False | True deriving (Ord)

BecausetheFalsevalue constructor is specified first and theTruevalue
constructor is specified after it, we can considerTrueas greater thanFalse.

```
Making Our Own Types and Type Classes 125
```

```
ghci>True `compare` False
GT
ghci> True > False
True
ghci> True < False
False
```
```
Iftwo values were made using the same constructor, they are considered
to be equal, unless they have fields. If they have fields, the fields are com-
pared to see which is greater. (Note that in this case, the types of the fields
also must be part of theOrdtype class.)
In theMaybe adata type, theNothingvalue constructor is specified before
theJustvalue constructor, so the value ofNothingis always smaller than the
value ofJust something, even if that something is minus one billion trillion.
But if we specify twoJustvalues, then it will compare what’s inside them.
```
```
ghci>Nothing < Just 100
True
ghci> Nothing > Just (-49999)
False
ghci> Just 3 `compare` Just 2
GT
ghci> Just 100 > Just 50
True
```
```
However,we can’t do something likeJust (*3) > Just (*2), because(*3)
and(*2)are functions, which are not instances ofOrd.
```
## Any Day of the Week....................................................

```
We can easily use algebraic data types to make enumerations, and theEnum
andBoundedtype classes help us with that. Consider the following data type:
```
```
dataDay = Monday | Tuesday | Wednesday | Thursday | Friday | Saturday | Sunday
```
```
Becauseall the type’s value constructors are nullary (that is, they don’t
have any fields), we can make it part of theEnumtype class. TheEnumtype
class is for things that have predecessors and successors. We can also make
it part of theBoundedtype class, which is for things that have a lowest possible
value and highest possible value. And while we’re at it, let’s also make it an
instance of all the other derivable type classes.
```
```
dataDay = Monday | Tuesday | Wednesday | Thursday | Friday | Saturday | Sunday
deriving (Eq, Ord, Show, Read, Bounded, Enum)
```
**126** Chapter 7


```
Nowlet’s see what we can do with our newDaytype. Because it’s part of
theShowandReadtype classes, we can convert values of this type to and from
strings.
```
```
ghci>Wednesday
Wednesday
ghci> show Wednesday
"Wednesday"
ghci> read "Saturday" :: Day
Saturday
```
```
Becauseit’s part of theEqandOrdtype classes, we can compare or
equate days.
```
```
ghci>Saturday == Sunday
False
ghci> Saturday == Saturday
True
ghci> Saturday > Friday
True
ghci> Monday `compare` Wednesday
LT
```
```
It’salso part ofBounded, so we can get the lowest and highest day.
```
```
ghci>minBound :: Day
Monday
ghci> maxBound :: Day
Sunday
```
```
Asit’s an instance ofEnum, we can get predecessors and successors of days
and make list ranges from them!
```
```
ghci>succ Monday
Tuesday
ghci> pred Saturday
Friday
ghci> [Thursday .. Sunday]
[Thursday,Friday,Saturday,Sunday]
ghci> [minBound .. maxBound] :: [Day]
[Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday]
```
## TypeSynonyms..................................................................

```
As mentioned earlier, when writing types, the[Char]andStringtypes are
equivalent and interchangeable. That’s implemented with type synonyms.
```
```
Making Our Own Types and Type Classes 127
```

```
Typesynonyms don’t really do anything per se—
they’re just about giving some types different names
so that they make more sense to someone reading our
code and documentation. Here’s how the standard li-
brary definesStringas a synonym for[Char]:
```
```
typeString = [Char]
```
```
Thetypekeywordhere might be misleading, be-
cause a new type is not being created (that’s done with thedatakeyword).
Rather, this defines a synonym for an existing type.
If we make a function that converts a string to uppercase and call it
toUpperString, we can give it a type declaration of this:
```
```
toUpperString:: [Char] -> [Char]
```
```
Alternatively,we can use this type declaration:
```
```
toUpperString:: String -> String.
```
```
Thetwo are essentially the same, but the latter is nicer to read.
```
## Making Our Phonebook Prettier...........................................

```
When we were dealing with theData.Mapmodule, we first represented a
phonebook with an association list (a list of key/value pairs) before con-
verting it into a map. Here’s that version:
```
```
phoneBook:: [(String, String)]
phoneBook =
[("betty", "555-2938")
,("bonnie", "452-2928")
,("patsy", "493-2928")
,("lucille", "205-2928")
,("wendy", "939-8282")
,("penny", "853-2492")
]
```
```
Thetype ofphoneBookis[(String, String)]. That tells us that it’s an asso-
ciation list that maps from strings to strings, but not much else. Let’s make a
type synonym to convey some more information in the type declaration.
```
```
typePhoneBook = [(String,String)]
```
```
Nowthe type declaration for our phonebook can bephoneBook ::
PhoneBook. Let’s make a type synonym forStringas well.
```
**128** Chapter 7


typePhoneNumber = String
type Name = String
type PhoneBook = [(Name, PhoneNumber)]

Haskellprogrammers give type synonyms to theStringtype when they
want to convey more information about the strings in their functions—what
they actually represent.
So now, when we implement a function that takes a name and a number
and checks if that name and number combination is in our phonebook, we
can give it a very pretty and descriptive type declaration.

inPhoneBook:: Name -> PhoneNumber -> PhoneBook -> Bool
inPhoneBook name pnumber pbook = (name, pnumber) `elem` pbook

Ifwe decided not to use type synonyms, our function would have this
type:

inPhoneBook:: String -> String -> [(String, String)] -> Bool

Inthis case, the type declaration that takes advantage of type synonyms
is easier to understand. However, you shouldn’t go overboard with these syn-
onyms. We introduce type synonyms either to describe what some existing
type represents in our functions (and thus our type declarations become bet-
ter documentation) or when something has a longish type that’s repeated a
lot (like[(String, String)]) but represents something more specific in the
context of our functions.

## Parameterizing Type Synonyms

Type synonyms can also be parameterized. If we want a type that represents
an association list type, but still want it to be general so it can use any type as
the keys and values, we can do this:

typeAssocList k v = [(k, v)]

Nowa function that gets the value by a key in an association list can
have a type of(Eq k) => k -> AssocList k v -> Maybe v.AssocListis a type con-
structor that takes two types and produces a concrete type—for instance,
AssocList Int String.
Just as we can partially apply functions to get new functions, we can par-
tially apply type parameters and get new type constructors from them. When
we call a function with too few parameters, we get back a new function. In
the same way, we can specify a type constructor with too few type parame-
ters and get back a partially applied type constructor. If we wanted a type

```
Making Our Own Types and Type Classes 129
```

```
thatrepresents a map (fromData.Map) from integers to something, we could
do this:
```
```
typeIntMap v = Map Int v
```
```
Orwe could do it like this:
```
```
typeIntMap = Map Int
```
```
Eitherway, theIntMaptype constructor takes one parameter, and that is
the type of what the integers will point to.
If you’re going to try to implement this, you probably will want to do a
qualified import ofData.Map. When you do a qualified import, type construc-
tors also need to be preceded with a module name.
```
```
typeIntMap = Map.Map Int
```
```
Makesure that you really understand the distinction between type con-
structors and value constructors. Just because we made a type synonym call-
edIntMaporAssocListdoesn’t mean that we can do stuff likeAssocList [(1,2),
(4,5),(7,9)]. All it means is that we can refer to its type by using different
names. We can do[(1,2),(3,5),(8,9)] :: AssocList Int Int, which will make
the numbers inside assume a type ofInt. However, we can still use that list
in the same way that we would use any normal list that has pairs of integers.
Type synonyms (and types generally) can be used only in the type por-
tion of Haskell. Haskell’s type portion includes data and type declarations,
as well as after a::in type declarations or type annotations.
```
## Go Left, Then Right.......................................................

```
Another cool data type that takes two types as its parameters is theEither a b
type. This is roughly how it’s defined:
```
```
dataEither a b = Left a | Right b deriving (Eq, Ord, Read, Show)
```
```
Ithas two value constructors. IfLeftis used, then its contents are of type
a; ifRightis used, its contents are of typeb. So we can use this type to en-
capsulate a value of one type or another. Then when we get a value of type
Either a b, we usually pattern match on bothLeftandRight, and we do dif-
ferent stuff based on which one matches.
```
```
ghci>Right 20
Right 20
ghci> Left "w00t"
Left "w00t"
ghci> :t Right 'a'
Right 'a' :: Either a Char
```
**130** Chapter 7


ghci>:t Left True
Left True :: Either Bool b

Inthis code, when we examine the type ofLeft True, we see that the type
isEither Bool b. The first type parameter isBool, because we made our value
with theLeftvalue constructor, whereas the second type parameter remains
polymorphic. This is similar to how aNothingvalue has the typeMaybe a.
So far, you’ve seenMaybe amostly used to represent the results of com-
putations that could have failed. But sometimes,Maybe aisn’t good enough,
becauseNothingdoesn’t convey much information other than that something
has failed. That’s fine for functions that can fail in only one way, or if we’re
not interested in how or why they failed. For instance, aData.Maplookup fails
only if the key wasn’t in the map, so we know exactly what happened.
However, when we’re interested in how or why some function failed,
we usually use the result type ofEither a b, whereais a type that can tell us
something about the possible failure, andbis the type of a successful compu-
tation. Hence, errors use theLeftvalue constructor, and results useRight.
As an example, suppose that a high school has lockers so that students
have some place to put their Guns N’ Roses posters. Each locker has a code
combination. When students need to be assigned a locker, they tell the
locker supervisor which locker number they want, and he gives them the
code. However, if someone is already using that locker, the student needs to
pick a different one. We’ll use a map fromData.Mapto represent the lockers.
It will map from locker numbers to a pair that indicates whether the locker
is in use and the locker code.

importqualified Data.Map as Map

data LockerState = Taken | Free deriving (Show, Eq)

type Code = String

type LockerMap = Map.Map Int (LockerState, Code)

Weintroduce a new data type to represent whether a locker is taken
or free, and we make a type synonym for the locker code. We also make a
type synonym for the type that maps from integers to pairs of locker state
and code.
Next, we’ll make a function that searches for the code in a locker map.
We’ll use anEither String Codetype to represent our result, because our
lookup can fail in two ways: The locker can be taken, in which case we can’t
tell the code, or the locker number might not exist. If the lookup fails, we’re
just going to use aStringto indicate what happened.

lockerLookup:: Int -> LockerMap -> Either String Code
lockerLookup lockerNumber map = case Map.lookup lockerNumber map of
Nothing -> Left $ "Locker " ++ show lockerNumber ++ " doesn't exist!"
Just (state, code) -> if state /= Taken

```
Making Our Own Types and Type Classes 131
```

```
thenRight code
else Left $ "Locker " ++ show lockerNumber
++ " is already taken!"
```
```
Wedo a normal lookup in the map. If we get aNothing, we return a
value of typeLeft String, saying that the locker doesn’t exist. If we do find
it, then we do an additional check to see if the locker is in use. If it is, we
return aLeftsaying that it’s already taken. If it isn’t, we return a value
of typeRight Code, in which we give the student the correct code for the
locker. It’s actually aRight String(which is aRight [Char]), but we added
that type synonym to introduce some additional documentation into the
type declaration.
Here’s an example map:
```
```
lockers:: LockerMap
lockers = Map.fromList
[(100,(Taken, "ZD39I"))
,(101,(Free, "JAH3I"))
,(103,(Free, "IQSA9"))
,(105,(Free, "QOTSA"))
,(109,(Taken, "893JJ"))
,(110,(Taken, "99292"))
]
```
```
Nowlet’s try looking up some locker codes.
```
```
ghci>lockerLookup 101 lockers
Right "JAH3I"
ghci> lockerLookup 100 lockers
Left "Locker 100 is already taken!"
ghci> lockerLookup 102 lockers
Left "Locker number 102 doesn't exist!"
ghci> lockerLookup 110 lockers
Left "Locker 110 is already taken!"
ghci> lockerLookup 105 lockers
Right "QOTSA"
```
```
Wecould have used aMaybe ato represent the result, but then we
wouldn’t know why we couldn’t get the code. But now we have informa-
tion about the failure in our result type.
```
## Recursive Data Structures..........................................................

```
As you’ve seen, a constructor in an algebraic data type can have several fields
(or none at all), and each field must be of some concrete type. So we can
make types that have themselves as types in their fields! And that means we
```
**132** Chapter 7


cancreate recursive data types, where one value of some type contains values
of that type, which in turn contain more values of the same type, and so on.
Thinkabout this list:[5]. That’s just syntactic
sugar for5:[]. On the left side of the:, there’s a
value; on the right side, there’s a list. In this case,
it’s an empty list. Now how about the list[4,5]? Well,
that desugars to4:(5:[]). Looking at the first:, we
see that it also has an element on its left side and a
list,(5:[]), on its right side. The same goes for a list
like3:(4:(5:6:[])), which could be written either like
that or like3:4:5:6:[](because:is right-associative)
or[3,4,5,6].
A list can be an empty list, or it can be an ele-
ment joined together with a:with another list (that
might be an empty list).
Let’s use algebraic data types to implement our
own list!

dataList a = Empty | Cons a (List a) deriving (Show, Read, Eq, Ord)

Thisfollows our definition of lists. It’s either an
empty list or a combination of a head with some value and a list. If you’re
confused about this, you might find it easier to understand in record syntax.

dataList a = Empty | Cons { listHead :: a, listTail :: List a}
deriving (Show, Read, Eq, Ord)

Youmight also be confused about theConsconstructor here. Informally
speaking,Consis another word for:. In lists,:is actually a constructor that
takes a value and another list and returns a list. In other words, it has two
fields: One field is of the type ofa, and the other is of the typeList a.

ghci>Empty
Empty
ghci> 5 `Cons` Empty
Cons 5 Empty
ghci> 4 `Cons` (5 `Cons` Empty)
Cons 4 (Cons 5 Empty)
ghci> 3 `Cons` (4 `Cons` (5 `Cons` Empty))
Cons 3 (Cons 4 (Cons 5 Empty))

Wecalled ourConsconstructor in an infix manner so you can see how
it’s just like:.Emptyis like[], and4 `Cons` (5 `Cons` Empty)is like4:(5:[]).

## Improving Our List.......................................................

We can define functions to be automatically infix by naming them using
only special characters. We can also do the same with constructors, since

```
Making Our Own Types and Type Classes 133
```

```
they’rejust functions that return a data type. There is one restriction how-
ever: Infix constructors must begin with a colon. So check this out:
```
```
infixr5 :-:
data List a = Empty | a :-: (List a) deriving (Show, Read, Eq, Ord)
```
```
First,notice a new syntactic construct: the fixity declaration, which is the
line above our data declaration. When we define functions as operators, we
can use that to give them a fixity (but we don’t have to). A fixity states how
tightly the operator binds and whether it’s left-associative or right-associative.
For instance, the*operator’s fixity isinfixl 7*, and the+operator’s fixity
isinfixl 6. That means that they’re both left-associative (in other words,
```
(^4) * (^3) * 2 is the same as(4*3)* 2 ), but*binds tighter than+, because it
has a greater fixity. So (^5) *4+3is equivalent to(5*4) + 3.
Otherwise, we just wrotea :-: (List a)instead ofCons a (List a). Now,
we can write out lists in our list type like so:
ghci>3 :-: 4 :-: 5 :-: Empty
3 :-: (4 :-: (5 :-: Empty))
ghci> let a = 3 :-: 4 :-: 5 :-: Empty
ghci> 100 :-: a
100 :-: (3 :-: (4 :-: (5 :-: Empty)))
Let’smake a function that adds two of our lists together. This is how++
is defined for normal lists:
infixr5 ++
(++) :: [a] -> [a] -> [a]
[] ++ ys = ys
(x:xs) ++ ys = x : (xs ++ ys)
We’lljust steal that for our own list. We’ll name the function^++.
infixr5 ^++
(^++) :: List a -> List a -> List a
Empty ^++ ys = ys
(x :-: xs) ^++ ys = x :-: (xs ^++ ys)
Nowlet’s see try it:
ghci>let a = 3 :-: 4 :-: 5 :-: Empty
ghci> let b = 6 :-: 7 :-: Empty
ghci> a ^++ b
3 :-: (4 :-: (5 :-: (6 :-: (7 :-: Empty))))
Ifwe wanted, we could implement all of the functions that operate on
lists on our own list type.
**134** Chapter 7


```
Noticehow we pattern matched on(x :-: xs). That works because pat-
tern matching is actually about matching constructors. We can match on:-:
because it is a constructor for our own list type, and we can also match on
:because it is a constructor for the built-in list type. The same goes for[].
Because pattern matching works (only) on constructors, we can match for
normal prefix constructors or stuff like 8 or'a', which are basically construc-
tors for the numeric and character types, respectively.
```
## Let’s Plant a Tree.........................................................

```
Toget a better feel for recursive data
structures in Haskell, we’re going to im-
plement a binary search tree.
In a binary search tree, an element
points to two elements—one on its left
and one on its right. The element to the
left is smaller; the element to the right is
bigger. Each of those elements can also
point to two elements (or one or none).
In effect, each element has up to two
subtrees.
A cool thing about binary search trees is that we know that all the ele-
ments at the left subtree of, say, 5, will be smaller than 5. Elements in the
right subtree will be bigger. So if we need to find if 8 is in our tree, we start
at 5, and then because 8 is greater than 5, we go right. We’re now at 7, and
because 8 is greater than 7, we go right again. And we’ve found our element
in three hops! If this were a normal list (or a tree, but really unbalanced), it
would take us seven hops to see if 8 is in there.
```
**NOTE** _Sets and maps fromData.SetandData.Mapare implemented using trees, but instead of
normal binary search trees, they use_ balanced _binary search trees. A tree is balanced
if its left and right subtrees are of approximately the same height. This makes searching
through the tree faster. But for our examples, we’ll just be implementing normal binary
search trees._

```
Here’s what we’re going to say: A tree is either an empty tree or it’s an
element that contains some value and two trees. Sounds like a perfect fit for
an algebraic data type!
```
```
dataTree a = EmptyTree | Node a (Tree a) (Tree a) deriving (Show)
```
```
Insteadof manually building a tree, we’ll make a function that takes a
tree and an element and inserts an element. We do this by comparing the
new value to the tree’s root node. If it’s smaller than the root, we go left; if
it’s larger, we go right. We then do the same for every subsequent node until
we reach an empty tree. Once we’ve reached an empty tree, we insert a node
with our new value.
```
```
Making Our Own Types and Type Classes 135
```

```
Inlanguages like C, we would do this by modifying the pointers and
values inside the tree. In Haskell, we can’t modify our tree directly, so we
need to make a new subtree each time we decide to go left or right. In the
end, the insertion function returns a completely new tree, because Haskell
doesn’t have a concept of pointers, just values. Hence, the type for our in-
sertion function will be something likea -> Tree a - > Tree a. It takes an el-
ement and a tree and returns a new tree that has that element inside. This
might seem like it’s inefficient, but Haskell makes it possible to share most
of the subtrees between the old tree and the new tree.
Here are two functions for building the tree:
```
```
singleton:: a -> Tree a
singleton x = Node x EmptyTree EmptyTree
```
```
treeInsert :: (Ord a) => a -> Tree a -> Tree a
treeInsert x EmptyTree = singleton x
treeInsert x (Node a left right)
| x == a = Node x left right
| x < a = Node a (treeInsert x left) right
| x > a = Node a left (treeInsert x right)
```
```
singletonisa utility function for making a singleton tree (a tree with just
one node). It’s just a shortcut for creating a node that has something set as
its root, and two empty subtrees.
ThetreeInsertfunction is to insert an element into a tree. Here, we
first have the base case as a pattern. If we’ve reached an empty subtree, that
means we’re where we want to go, and we insert a singleton tree with our el-
ement. If we’re not inserting into an empty tree, then we need to do some
checking. First, if the element we’re inserting is equal to the root element,
we just return a tree that’s the same. If it’s smaller, we return a tree that has
the same root value and the same right subtree, but instead of its left sub-
tree, we put a tree that has our value inserted into it. We do the same if our
value is bigger than the root element, but the other way around.
Next up, we’re going to make a function that checks if some element is
in the tree:
```
```
treeElem:: (Ord a) => a -> Tree a -> Bool
treeElem x EmptyTree = False
treeElem x (Node a left right)
| x == a = True
| x < a = treeElem x left
| x > a = treeElem x right
```
```
First,we define the base case. If we’re looking for an element in an
empty tree, then it’s certainly not there. Notice how this is the same as the
base case when searching for elements in lists. If we’re not looking for an
element in an empty tree, then we check some things. If the element in the
root node is what we’re looking for, great! If it’s not, what then? Well, we
```
**136** Chapter 7


```
cantake advantage of knowing that all the left elements are smaller than the
root node. If the element we’re looking for is smaller than the root node, we
check to see if it’s in the left subtree. If it’s bigger, we check to see if it’s in
the right subtree.
Now let’s have some fun with our trees! Instead of manually creating
one (although we could), we’ll use a fold to build a tree from a list. Remem-
ber that pretty much everything that traverses a list one item at a time and
returns a value can be implemented with a fold! We’re going to start with
the empty tree and then approach a list from the right and insert element
after element into our accumulator tree.
```
```
ghci>let nums = [8,6,4,1,7,3,5]
ghci> let numsTree = foldr treeInsert EmptyTree nums
ghci> numsTree
Node 5
(Node 3
(Node 1 EmptyTree EmptyTree)
(Node 4 EmptyTree EmptyTree)
)
(Node 7
(Node 6 EmptyTree EmptyTree)
(Node 8 EmptyTree EmptyTree)
)
```
**NOTE** _Ifyou run this in GHCi, the result fromnumsTreewill be printed in one long line.
Here, it’s broken up into many lines; otherwise, it would run off the page!_

```
In thisfoldr,treeInsertis the folding binary function (it takes a tree and
a list element and produces a new tree), andEmptyTreeis the starting accu-
mulator.nums, of course, is the list we’re folding over.
When we print our tree to the console, it’s not very readable, but we can
still make out its structure. We see that the root node is 5 and that it has two
subtrees: one with a root node of 3 and the other with a root node of 7.
We can also check if certain values are contained in the tree, like this:
```
```
ghci>8 `treeElem` numsTree
True
ghci> 100 `treeElem` numsTree
False
ghci> 1 `treeElem` numsTree
True
ghci> 10 `treeElem` numsTree
False
```
```
Asyou can see, algebraic data structures are a really cool and powerful
concept in Haskell. We can use them to make anything from Boolean values
and weekday enumerations to binary search trees, and more!
```
```
Making Our Own Types and Type Classes 137
```

## Type Classes 102................................................................

```
So far, you’ve learned about some of the standard Haskell type classes and
seen which types they contain. You’ve also learned how to automatically
make your own type instances of the standard type classes by asking Haskell
to derive the instances. This section explains how to make your own type
classes and how to make type instances of them by hand.
A quick typeclass recap: Type classes are sort
of like interfaces. A type class defines some behav-
ior (such as comparing for equality, comparing for
ordering, and enumeration). Types that can be-
have in that way are made instances of that type
class. The behavior of type classes is achieved by
defining functions or just type declarations that
we then implement. So when we say that a type is
an instance of a type class, we mean that we can
use the functions that the type class defines with
that type.
```
```
NOTE Remember that type classes have nothing to do with
classes in languages like Java or Python. This confuses
many people, so I want you to forget everything you know
about classes in imperative languages right now!
```
## Inside the Eq Type Class..................................................

```
As an example, let’s look at theEqtype class. Re-
member thatEqis for values that can be equated. It
defines the functions==and/=. If we have the type
Carand comparing two cars with the equality func-
tion==makes sense, then it makes sense forCarto
be an instance ofEq.
This is how theEqclass is defined in the standard library:
```
```
class Eq awhere
(==) :: a -> a -> Bool
(/=) :: a -> a -> Bool
x == y = not (x /= y)
x /= y = not (x == y)
```
```
Whoa! Some strangesyntax and keywords here!
class Eq a wheremeans a new type class calledEqis being defined. Thea
is the type variable, soawill play the role of the type that will soon be made
an instance ofEq. (It doesn’t need to be calleda, and it doesn’t even need to
be one letter—it just must be in all lowercase.)
Next, several functions are defined. Note that it’s not mandatory to
implement the function bodies themselves; just their type declarations are
required. Here, the function bodies for the functions thatEqdefines are
```
**138** Chapter 7


implemented—definedin terms of mutual recursion. It says that two values
whose types are instances ofEqare equal if they are not different, and they
are different if they are not equal. You’ll see how this helps us soon.
The final type of the functions that we define in a type class is also worth
noting. If we have, say,class Eq a where, and then define a type declaration
within that class like(==) :: a -> a -> Bool, when we examine the type of
that function later, it will have the type of(Eq a) => a -> a -> Bool.

## A Traffic Light Data Type.................................................

So once we have a class, what can we do with it? We can make type instances
of that class and get some nice functionality. Check out this type, for instance:

dataTrafficLight = Red | Yellow | Green

Itdefines the states of a traffic light. Notice how we didn’t derive any
class instances for it. That’s because we’re going to write some instances by
hand. Here’s how we make it an instance ofEq:

instanceEq TrafficLight where
Red == Red = True
Green == Green = True
Yellow == Yellow = True
_ == _ = False

Wedid it by using theinstancekeyword. Soclassis for defining new
type classes, andinstanceis for making our types instances of type classes.
When we were definingEq, we wroteclass Eq a where, and we said thataplays
the role of whichever type will be made an instance later. We can see that
clearly here, because when we’re making an instance, we writeinstance Eq
TrafficLight where. We replace theawith the actual type.
Because==was defined in terms of/=and vice versa in the class declara-
tion, we needed to overwrite only one of them in the instance declaration.
That’s called the _minimal complete definition_ for the type class—the minimum
of functions that we must implement so that our type can behave as the class
advertises. To fulfill the minimal complete definition forEq, we need to over-
write either==or/=. IfEqwere defined simply like this:

classEq a where
(==) :: a -> a -> Bool
(/=) :: a -> a -> Bool

wewould need to implement both of these functions when making a type an
instance ofEq, because Haskell wouldn’t know how these two functions are
related. The minimal complete definition would then be both==and/=.
You can see that we implemented==simply by doing pattern matching.
Since there are many more cases where two lights aren’t equal, we specified

```
Making Our Own Types and Type Classes 139
```

```
theones that are equal, and then just did a catchall pattern saying that if it’s
none of the previous combinations, then two lights aren’t equal.
Let’s make this an instance ofShowby hand, too. To satisfy the minimal
complete definition forShow, we just need to implement itsshowfunction,
which takes a value and turns it into a string:
```
```
instanceShow TrafficLight where
show Red = "Red light"
show Yellow = "Yellow light"
show Green = "Green light"
```
```
Onceagain, we used pattern matching to achieve our goals. Let’s see
how it works in action:
```
```
ghci>Red == Red
True
ghci> Red == Yellow
False
ghci> Red `elem` [Red, Yellow, Green]
True
ghci> [Red, Yellow, Green]
[Red light,Yellow light,Green light]
```
```
Wecould have just derivedEq, and it would have had the same effect (but
we didn’t for educational purposes). However, derivingShowwould have just
directly translated the value constructors to strings. If we want our lights to
appear asRed light, we need to make the instance declaration by hand.
```
## Subclassing.............................................................

```
You can also make type classes that are subclasses of other type classes. The
class declaration forNumis a bit long, but here’s the first part:
```
```
class(Eq a) => Num a where
...
```
```
Asmentioned previously, there are a lot of places where we can cram in
class constraints. So this is just like writingclass Num a where, but we state that
our typeamust be an instance ofEq. We’re essentially saying that we need
to make a type an instance ofEqbefore we can make it an instance ofNum.
Before some type can be considered a number, it makes sense that we can
determine whether values of that type can be equated.
That’s all there is to subclassing—it’s just a class constraint on a class
declaration! When defining function bodies in the class declaration or in
instance declarations, we can assume thatais a part ofEq, so we can use==
on values of that type.
```
**140** Chapter 7


## Parameterized Types As Instances of Type Classes..........................

But how are theMaybeor list types made as instances of type classes? What
makesMaybedifferent from, say,TrafficLightis thatMaybein itself isn’t a con-
crete type—it’s a type constructor that takes one type parameter (likeChar)
to produce a concrete type (likeMaybe Char). Let’s take a look at theEqtype
class again:

classEq a where
(==) :: a -> a -> Bool
(/=) :: a -> a -> Bool
x == y = not (x /= y)
x /= y = not (x == y)

Fromthe type declarations, we see thatais used as a concrete type be-
cause all the types in functions must be concrete. Remember that you can’t
have a function of the typea -> Maybe, but you _can_ have a function of the
typea -> Maybe aorMaybe Int -> Maybe String. That’s why we can’t do some-
thing like this:

instanceEq Maybe where
...

Theamustbe a concrete type, andMaybeis not; it’s a type constructor
that takes one parameter and then _produces_ a concrete type.
It would also be tedious if we needed to make a separate instance for
every possible type thatMaybe’s type parameter could take on. If we needed
to writeinstance Eq (Maybe Int) where,instance Eq (Maybe Char) where, and so
on for every type, we would get nowhere. That’s why we can just leave the
parameter as a type variable, like so:

instanceEq (Maybe m) where
Just x == Just y = x == y
Nothing == Nothing = True
_ == _ = False

Thisis like saying that we want to make all types of the formMaybe something
an instance ofEq. We actually could have written(Maybe something), but using
single letters conforms to the Haskell style.
The(Maybe m)here plays the role of theafromclass Eq a where. While
Maybeisn’t a concrete type,Maybe mis. By specifying a type parameter as a type
variable (m, which is in lowercase), we said that we want all types that are in
the form ofMaybe m, wheremis any type, to be an instance ofEq.
There’s one problem with this though. Can you spot it? We use==on
the contents of theMaybe, but we have no assurance that what theMaybe

```
Making Our Own Types and Type Classes 141
```

```
containscan be used withEq! That’s why we modify our instance declaration
like this:
```
```
instance(Eq m) => Eq (Maybe m) where
Just x == Just y = x == y
Nothing == Nothing = True
_ == _ = False
```
```
Weneeded to add a class constraint! With this instance declaration, we
say that we want all types of the formMaybe mto be part of theEqtype class,
but only those types where them(what’s contained inside theMaybe) is also a
part ofEq. This is actually how Haskell would derive the instance.
Most of the time, class constraints in class declarations are used for mak-
ing a type class a subclass of another type class, and class constraints in in-
stance declarations are used to express requirements about the contents of
some type. For instance, here we required the contents of theMaybeto also
be part of theEqtype class.
When making instances, if you see that a type is used as a concrete type
in the type declarations (like theaina -> a -> Bool), you need to supply
type parameters and add parentheses so that you end up with a concrete type.
Take into account that the type you’re trying to make an instance of will
replace the parameter in the class declaration. Theafromclass Eq a where
will be replaced with a real type when you make an instance, so try to men-
tally put your type into the function type declarations as well. The following
type declaration really doesn’t make much sense:
```
```
(==):: Maybe -> Maybe -> Bool
```
```
Butthis does:
```
```
(==):: (Eq m) => Maybe m -> Maybe m -> Bool
```
```
Thisis just something to think about, because==will always have a type
of(==) :: (Eq a) => a -> a -> Bool, no matter what instances we make.
Oh, and one more thing: If you want to see what the instances of a type
class are, just type:info YourTypeClassin GHCi. For instance, typing:info Num
will show which functions the type class defines, and it will give you a list of
the types in the type class.:infoworks for types and type constructors, too.
If you do:info Maybe, it will show you all the type classes thatMaybeis an in-
stance of. Here’s an example:
```
```
ghci>:info Maybe
data Maybe a = Nothing | Just a -- Defined in Data.Maybe
instance (Eq a) => Eq (Maybe a) -- Defined in Data.Maybe
instance Monad Maybe -- Defined in Data.Maybe
instance Functor Maybe -- Defined in Data.Maybe
```
**142** Chapter 7


```
instance(Ord a) => Ord (Maybe a) -- Defined in Data.Maybe
instance (Read a) => Read (Maybe a) -- Defined in GHC.Read
instance (Show a) => Show (Maybe a) -- Defined in GHC.Show
```
## A Yes-No Type Class.............................................................

```
In JavaScript and some other weakly typed languages, you can put almost
anything inside anifexpression. For example, in JavaScript, you can do
something like this:
```
```
if(0) alert("YEAH!") else alert("NO!")
```
```
Orlike this:
```
```
if("") alert ("YEAH!") else alert("NO!")
```
```
Orlike this:
```
```
if(false) alert("YEAH!") else alert("NO!")
```
```
Allof these will throw an alert ofNO!.
However, the following code will give an alert ofYEAH!, since JavaScript
considers any nonempty string to be a true value:
```
```
if("WHAT") alert ("YEAH!") else alert("NO!")
```
```
Eventhough strictly usingBoolfor Boolean semantics works better in
Haskell, let’s try to implement this JavaScript-like behavior, just for fun!
We’ll start out with a class declaration:
```
```
classYesNo a where
yesno :: a -> Bool
```
```
Thisis pretty simple. TheYesNotype class defines one function. That
function takes one value of a type that can be considered to hold some con-
cept of trueness and tells us for sure if it’s true or not. Notice that from the
way we useain the function thatamust be a concrete type.
Next up, let’s define some instances. For numbers, we’ll assume that (as
in JavaScript) any number that isn’t 0 is true in a Boolean context and 0 is
false.
```
```
instanceYesNo Int where
yesno 0 = False
yesno _ = True
```
```
Making Our Own Types and Type Classes 143
```

```
Emptylists (and by extension, strings) are a no-ish value, while nonempty
lists are a yes-ish value.
```
```
instanceYesNo [a] where
yesno [] = False
yesno _ = True
```
```
Noticehow we just put a type parameterain there to make the list a
concrete type, even though we don’t make any assumptions about the type
that’s contained in the list.
Boolitself also holds trueness and falseness, and it’s pretty obvious which
is which:
```
```
instanceYesNo Bool where
yesno = id
```
```
Butwhat’sid? It’s just a standard library function that takes a parameter
and returns the same thing, which is what we would be writing here anyway.
Let’s makeMaybe aan instance, too:
```
```
instanceYesNo (Maybe a) where
yesno (Just _) = True
yesno Nothing = False
```
```
Wedidn’t need a class constraint, be-
cause we made no assumptions about the
contents of theMaybe. We just said that it’s
true-ish if it’s aJustvalue and false-ish if
it’s aNothing. We still need to write out
(Maybe a)instead of justMaybe. If you think
about it, aMaybe -> Boolfunction can’t ex-
ist (becauseMaybeisn’t a concrete type),
whereas aMaybe a -> Boolis fine and dandy.
Still, this is really cool, because now any type of the formMaybe somethingis
part ofYesNo, and it doesn’t matter what that something is.
Previously, we defined aTree atype that represented a binary search
tree. We can say an empty tree is false-ish, and anything that’s not an empty
tree is true-ish:
```
```
instanceYesNo (Tree a) where
yesno EmptyTree = False
yesno _ = True
```
```
Cana traffic light be a yes or no value? Sure. If it’s red, you stop. If it’s
green, you go. (If it’s yellow? Eh, I usually run the yellows because I live for
adrenaline.)
```
**144** Chapter 7


instanceYesNo TrafficLight where
yesno Red = False
yesno _ = True

```
Nowthat we have some instances, let’s go play!
```
ghci>yesno $ length []
False
ghci> yesno "haha"
True
ghci> yesno ""
False
ghci> yesno $ Just 0
True
ghci> yesno True
True
ghci> yesno EmptyTree
False
ghci> yesno []
False
ghci> yesno [0,0,0]
True
ghci> :t yesno
yesno :: (YesNo a) => a -> Bool

Itworks!
Now let’s make a function that mimics theifstatement, but that works
withYesNovalues.

yesnoIf:: (YesNo y) => y -> a -> a -> a
yesnoIf yesnoVal yesResult noResult =
if yesno yesnoVal
then yesResult
else noResult

Thistakes aYesNovalue and two values of any type. If the yes-no–ish
value is more of a yes, it returns the first of the two values; otherwise, it
returns the second of them. Let’s try it:

ghci>yesnoIf [] "YEAH!" "NO!"
"NO!"
ghci> yesnoIf [2,3,4] "YEAH!" "NO!"
"YEAH!"
ghci> yesnoIf True "YEAH!" "NO!"
"YEAH!"
ghci> yesnoIf (Just 500) "YEAH!" "NO!"
"YEAH!"

```
Making Our Own Types and Type Classes 145
```

```
ghci>yesnoIf Nothing "YEAH!" "NO!"
"NO!"
```
## The Functor Type Class............................................................

```
Sofar, we’ve encountered a lot of the type classes
in the standard library. We’ve played withOrd,
which is for stuff that can be ordered. We’ve
palled around withEq, which is for things that
can be equated. We’ve seenShow, which presents
an interface for types whose values can be dis-
played as strings. Our good friendReadis there
whenever we need to convert a string to a value
of some type. And now, we’re going to take a
look at theFunctortype class, which is for things
that can be mapped over.
You’re probably thinking about lists now,
since mapping over lists is such a dominant id-
iom in Haskell. And you’re right, the list type is
part of theFunctortype class.
What better way to get to know theFunctor
type class than to see how it’s implemented? Let’s
take a peek.
```
```
classFunctor f where
fmap :: (a -> b) -> f a -> f b
```
```
Wesee that it defines one function,fmap, and doesn’t provide any de-
fault implementation for that function. The type offmapis interesting. In the
definitions of type classes so far, the type variable that played the role of the
type in the type class was a concrete type, like theain(==) :: (Eq a) => a ->
a -> Bool. But now, thefis not a concrete type (a type that a value can hold,
likeInt,Bool, orMaybe String), but a type constructor that takes one type pa-
rameter. (A quick refresher example:Maybe Intis a concrete type, butMaybe
is a type constructor that takes one type as the parameter.)
We see thatfmaptakes a function from one type to another and a functor
value applied with one type and returns a functor value applied with another
type. If this sounds a bit confusing, don’t worry—all will be revealed soon
when we check out a few examples.
Hmm... the type declaration forfmapreminds me of something. Let’s
look at the type signature of themapfunction:
```
```
map:: (a -> b) -> [a] -> [b]
```
```
Ah,interesting! It takes a function from one type to another and a list
of one type and returns a list of another type. My friends, I think we have
```
**146** Chapter 7


ourselvesa functor! In fact,mapis just afmapthat works only on lists. Here’s
how the list is an instance of theFunctortype class:

instanceFunctor [] where
fmap = map

That’sit! Notice how we didn’t writeinstance Functor [a] where. This is
becausefmust be a type constructor that takes one type, which we can see in
the following type declaration:

fmap:: (a -> b) -> f a -> f b

[a]isalready a concrete type (of a list with any type inside it), while[]is
a type constructor that takes one type and can produce types such as[Int],
[String], or even[[String]].
Since for lists,fmapis justmap, we get the same results when using these
functions on lists:

ghci>fmap (*2) [1..3]
[2,4,6]
ghci> map (*2) [1..3]
[2,4,6]

Whathappens when wemaporfmapover an empty list? Well, of course,
we get an empty list. It turns an empty list of type[a]into an empty list of
type[b].

## Maybe As a Functor.....................................................

Types that can act like a box can be functors. You can think of a list as a box
that can be empty or have something inside it, including another box. That
box can also be empty or contain something and another box, and so on.
So, what else has the properties of being like a box? For one, theMaybe a
type. In a way, it’s like a box that can hold nothing (in which case it has the
value ofNothing), or it can contain one item (like"HAHA", in which case it has
a value ofJust "HAHA").
Here’s howMaybeis a functor:

instanceFunctor Maybe where
fmap f (Just x) = Just (f x)
fmap f Nothing = Nothing

Again,notice how we wroteinstance Functor Maybe whereinstead of
instance Functor (Maybe m) where, as we did when we were dealing with
YesNo.Functorwants a type constructor that takes one type, and not a
concrete type. If you mentally replace thefs withMaybes,fmapacts like
a(a -> b) -> Maybe a -> Maybe bfor this particular type, which looks
okay. But if you replacefwith(Maybe m), then it would seem to act like a

```
Making Our Own Types and Type Classes 147
```

```
(a-> b) -> Maybe m a -> Maybe m b, which doesn’t make sense, becauseMaybe
takes just one type parameter.
Thefmapimplementation is pretty simple. If it’s an empty value ofNothing,
then just return aNothing. If we map over an empty box, we get an empty
box. If we map over an empty list, we get an empty list. If it’s not an empty
value, but rather a single value packed in aJust, then we apply the function
on the contents of theJust:
```
```
ghci>fmap (++ " HEY GUYS IM INSIDE THE JUST") (Just "Something serious.")
Just "Something serious. HEY GUYS IM INSIDE THE JUST"
ghci> fmap (++ " HEY GUYS IM INSIDE THE JUST") Nothing
Nothing
ghci> fmap (*2) (Just 200)
Just 400
ghci> fmap (*2) Nothing
Nothing
```
## Trees Are Functors, Too...................................................

```
Another thing that can be mapped over and made an instance ofFunctoris
ourTree atype. It can be thought of as a box (it holds several or no values),
and theTreetype constructor takes exactly one type parameter. If you look
atfmapas if it were a function made only forTree, its type signature would
look like this:(a -> b) -> Tree a -> Tree b.
We’re going to use recursion on this one. Mapping over an empty tree
will produce an empty tree. Mapping over a nonempty tree will produce a
tree consisting of our function applied to the root value, and its left and
right subtrees will be the previous subtrees, but with our function mapped
over them. Here’s the code:
```
```
instanceFunctor Tree where
fmap f EmptyTree = EmptyTree
fmap f (Node x left right) = Node (f x) (fmap f left) (fmap f right)
```
```
Nowlet’s test it:
```
```
ghci>fmap (*2) EmptyTree
EmptyTree
ghci> fmap (*4) (foldr treeInsert EmptyTree [5,7,3])
Node 20 (Node 12 EmptyTree EmptyTree) (Node 28 EmptyTree EmptyTree)
```
```
Becareful though! If you use theTree atype to represent a binary search
tree, there is no guarantee that it will remain a binary search tree after map-
ping a function over it. For something to be considered a binary search tree,
all the elements to the left of some node must be smaller than the element
in the node, and all the elements to the right must be greater. But if you
map a function likenegateover a binary search tree, the elements to the
```
**148** Chapter 7


leftof the node suddenly become greater than its element, and your binary
search tree becomes just a normal binary tree.

## Either a As a Functor.....................................................

How aboutEither a b? Can this be made a functor? TheFunctortype class
wants a type constructor that takes only one type parameter, butEithertakes
two. Hmmm... I know, we’ll partially applyEitherby feeding it only one
parameter, so that it has one free parameter.
Here’s howEither ais a functor in the standard libraries, more specifi-
cally in theControl.Monad.Instancesmodule:

instanceFunctor (Either a) where
fmap f (Right x) = Right (f x)
fmap f (Left x) = Left x

Wellwell, what do we have here? You can see howEither awas made an
instance instead of justEither. That’s becauseEither ais a type constructor
that takes one parameter, whereasEithertakes two. Iffmapwere specifically
forEither a, the type signature would be this:

(b-> c) -> Either a b -> Either a c

```
Becausethat’s the same as the following:
```
(b-> c) -> (Either a) b -> (Either a) c

Thefunction is mapped in the case of aRightvalue constructor, but it
isn’t mapped in the case of aLeft. Why is that? Well, looking back at how the
Either a btype is defined, we see this:

dataEither a b = Left a | Right b

Ifwe wanted to map one function over both of them,aandbwould
need to be the same type. Think about it: If we try to map a function that
takes a string and returns a string, andbis a string butais a number, it won’t
really work out. Also, considering whatfmap’s type would be if it operated
only onEither a bvalues, we can see that the first parameter must remain
the same, while the second one can change, and the first parameter is actual-
ized by theLeftvalue constructor.
This also goes nicely with our box analogy if we think of theLeftpart as
sort of an empty box with an error message written on the side telling us why
it’s empty.
Maps fromData.Mapcan also be made into functor values, because they
hold values (or not!). In the case ofMap k v,fmapwill map a functionv -> v'
over a map of typeMap k vand return a map of typeMap k v'.

```
Making Our Own Types and Type Classes 149
```

```
NOTE The'characterhas no special meaning in types, just as it has no special meaning
when naming values. It’s just used to denote things that are similar, but slightly
changed.
```
```
As an exercise, you can try to figure out howMap kis made an instance of
Functorby yourself!
As you’ve seen from the examples, withFunctor, type classes can repre-
sent pretty cool higher-order concepts. You’ve also had some more practice
with partially applying types and making instances. In Chapter 11, we’ll take
a look at some laws that apply for functors.
```
## Kinds and Some Type-Foo.........................................................

```
Typeconstructors take other types as param-
eters to eventually produce concrete types.
This behavior is similar to that of functions,
which take values as parameters to produce
values. Also like functions, type construc-
tors can be partially applied. For example,
Either Stringis a type constructor that takes
one type and produces a concrete type, like
Either String Int.
In this section, we’ll take a look at for-
mally defining how types are applied to
type constructors. You don’t really need to
read this section to continue on your mag-
ical Haskell quest, but it may help you to
see how Haskell’s type system works. And if
you don’t quite understand everything right
now, that’s okay, too.
Values like 3 ,"YEAH", ortakeWhile(functions are also values—we can pass
them around and such) each has their own types. Types are little labels that
values carry so that we can reason about the values. But types have their own
little labels called kinds. A kind is more or less the type of a type. This may
sound a bit weird and confusing, but it’s actually a really cool concept.
What are kinds, and what are they good for? Well, let’s examine the
kind of a type by using the:kcommand in GHCi:
```
```
ghci>:k Int
Int ::*
```
```
Whatdoes that*mean? It indicates that the type is a concrete type. A
concrete type is a type that doesn’t take any type parameters. Values can
have only types that are concrete types. If I had to read*out loud (I haven’t
had to do that yet), I would say “star,” or just “type.”
```
**150** Chapter 7


```
Okay,now let’s see what the kind ofMaybeis:
```
ghci>:k Maybe
Maybe ::*->*

Thiskind tells us that theMaybetype constructor takes one concrete
type (likeInt) and returns a concrete type (likeMaybe Int). Just asInt -> Int
means that a function takes anIntand returns anInt,*->*means that the
type constructor takes one concrete type and returns a concrete type. Let’s
apply the type parameter toMaybeand see what the kind of that type is:

ghci>:k Maybe Int
Maybe Int ::*

Justas you might have expected, we applied the type parameter toMaybe
and got back a concrete type (that’s what*->*means). A parallel (although
not equivalent—types and kinds are two different things) to this is if we call
:t isUpperand:t isUpper 'A'. TheisUpperfunction has a type ofChar -> Bool,
andisUpper 'A'has a type ofBool, because its value is basicallyFalse. Both
those types, however, have a kind of*.
We used:kon a type to get its kind, in the same way as we can use:ton
a value to get its type. Again, types are the labels of values, and kinds are the
labels of types, and there are parallels between the two.
Now let’s look at the kind ofEither:

ghci>:k Either
Either ::*->*->*

Thistells us thatEithertakes two concrete types as type parameters to
produce a concrete type. It also looks somewhat like the type declaration of
a function that takes two values and returns something. Type constructors
are curried (just like functions), so we can partially apply them, as you can
see here:

ghci>:k Either String
Either String ::*->*
ghci> :k Either String Int
Either String Int ::*

Whenwe wanted to makeEither apart of theFunctortype class, we
needed to partially apply it, becauseFunctorwants types that take only one
parameter, whileEithertakes two. In other words,Functorwants types of kind
*->*, so we needed to partially applyEitherto get this instead of its original
kind,*->*->*.

```
Making Our Own Types and Type Classes 151
```

```
Lookingat the definition ofFunctoragain, we can see that theftype
variable is used as a type that takes one concrete type to produce a con-
crete type:
```
```
classFunctor f where
fmap :: (a -> b) -> f a -> f b
```
```
Weknow it must produce a concrete type, because it’s used as the type
of a value in a function. And from that, we can deduce that types that want
to be friends withFunctormust be of kind*->*.
```
**152** Chapter 7


# 8

## INPUT AND OUTPUT

```
In this chapter, you’re going to learn how to receive
input from the keyboard and print stuff to the screen.
But first, we’ll cover the basics of input and output (I/O):
```
- What are I/O actions?
- How do I/O actions enable us to do I/O?
- When are I/O actions actually performed?

```
Dealing with I/O brings up the issue of constraints on how Haskell func-
tions can work, so we’ll look at how we get around that first.
```
## Separating the Pure from the Impure................................................

```
By now, you’re used to the fact that Haskell is a purely functional language.
Instead of giving the computer a series of steps to execute, you give it def-
initions of what certain things are. In addition, a function isn’t allowed to
have side effects. A function can give us back only some result based on the
parameters we supplied to it. If a function is called two times with the same
parameters, it must return the same result.
```

```
Whilethis may seem a bit limiting at first,
it’s actually really cool. In an imperative lan-
guage, you have no guarantee that a simple
function that should just crunch some num-
bers won’t burn down your house or kidnap
your dog while crunching those numbers.
For instance, when we were making a binary
search tree in the previous chapter, we didn’t
insert an element into a tree by modifying
the tree itself; instead, our function actually
returned a new tree with the new element in-
serted into that.
The fact that functions cannot change
state—like updating global variables, for
example—is good, because it helps us reason
about our programs. However, there’s one
problem with this: If a function can’t change anything in the world, how is it
supposed to tell us what it calculated? To do that, it must change the state of
an output device (usually the state of the screen), which then emits photons
that travel to our brain, which changes the state of our mind, man.
But don’t despair, all is not lost. Haskell has a really clever system for
dealing with functions that have side effects. It neatly separates the part of
our program that is pure and the part of our program that is impure, which
does all the dirty work like talking to the keyboard and the screen. With
those two parts separated, we can still reason about our pure program and
take advantage of all the things that purity offers—like laziness, robustness,
and composability—while easily communicating with the outside world.
You’ll see this at work in this chapter.
```
## Hello, World!....................................................................

```
Untilnow, we’ve always loaded our functions into
GHCi to test them. We’ve also explored the stan-
dard library functions in that way. Now we’re
finally going to write our first real Haskell pro-
gram! Yay! And sure enough, we’re going to do
the good old Hello, world! schtick.
For starters, punch the following into your
favorite text editor:
```
```
main= putStrLn "hello, world"
```
```
Wejust definedmain, and in it we call a function calledputStrLnwith the
parameter"hello, world". Save that file as helloworld.hs.
We’re going to do something we’ve never done before: compile our
program, so that we get an executable file that we can run! Open your
```
**154** Chapter 8


```
terminal,navigate to the directory where helloworld.hs is located, and enter
the following:
```
```
$ghc --make helloworld
```
```
Thisinvokes the GHC compiler and tells it to compile our program. It
should report something like this:
```
```
[1of 1] Compiling Main ( helloworld.hs, helloworld.o )
Linking helloworld ...
```
```
Nowyou can run your program by entering the following at the
terminal:
```
```
$./helloworld
```
**NOTE** _Ifyou’re using Windows, instead of doing./helloworld, just type in_ **helloworld.exe**
_to run your program._

```
Our program prints out the following:
```
```
hello,world
```
```
Andthere you go—our first compiled program that prints something to
the terminal. How extraordinarily boring!
Let’s examine what we wrote. First, let’s look at the type of the function
putStrLn:
```
```
ghci>:t putStrLn
putStrLn :: String -> IO ()
ghci> :t putStrLn "hello, world"
putStrLn "hello, world" :: IO ()
```
```
Wecan read the type ofputStrLnlike this:putStrLntakes a string and re-
turns an I/O action that has a result type of()(that is, the empty tuple, also
known as unit ).
An I/O action is something that, when performed, will carry out an ac-
tion with a side effect (such as reading input or printing stuff to the screen
or a file) and will also present some result. We say that an I/O action yields
this result. Printing a string to the terminal doesn’t really have any kind of
meaningful return value, so a dummy value of()is used.
```
**NOTE** _The empty tuple is the value(), and it also has a type of()._

```
So when will an I/O action be performed? Well, this is wheremaincomes
in. An I/O action will be performed when we give it a name ofmainand then
run our program.
```
```
Input and Output 155
```

## Gluing I/O Actions Together......................................................

```
Having your whole program be just one I/O action seems kind of limiting.
That’s why we can usedosyntax to glue together several I/O actions into
one. Take a look at the following example:
```
```
main= do
putStrLn "Hello, what's your name?"
name <- getLine
putStrLn ("Hey " ++ name ++ ", you rock!")
```
```
Ah,interesting—new syntax! And this reads pretty much like an impera-
tive program. If you compile and run it, it will behave just as you expect.
Notice that we saiddoand then we laid out a series of steps, as we would
in an imperative program. Each of these steps is an I/O action. By putting
them together withdosyntax, we glued them into one I/O action. The ac-
tion that we got has a type ofIO (), as that’s the type of the last I/O action
inside. Because of that,mainalways has a type signature ofmain :: IO something ,
where something is some concrete type. We don’t usually specify a type decla-
ration formain.
How about that third line, which statesname <- getLine? It looks like it
reads a line from the input and stores it into a variable calledname. Does it
really? Well, let’s examine the type ofgetLine.
```
```
ghci>:t getLine
getLine :: IO String
```
```
Wesee thatgetLineis an I/O action that
yields aString. That makes sense, because it
will wait for the user to input something at
the terminal, and then that something will
be represented as a string.
So what’s up withname <- getLinethen?
You can read that piece of code like this:
perform the I/O actiongetLine, and then
bind its result value toname.getLinehas a
type ofIO String, sonamewill have a type of
String.
You can think of an I/O action as a box
with little feet that will go out into the real world and do something there
(like write some graffiti on a wall) and maybe bring back some data. Once it
has fetched that data for you, the only way to open the box and get the data
inside it is to use the<-construct. And if we’re taking data out of an I/O
action, we can take it out only when we’re inside another I/O action. This
is how Haskell manages to neatly separate the pure and impure parts of our
code.getLineis impure, because its result value is not guaranteed to be the
same when performed twice.
```
**156** Chapter 8


Whenwe doname <- getLine,nameis just a normal string, because it rep-
resents what’s inside the box. For example, we can have a really complicated
function that takes your name (a normal string) as a parameter and tells you
your fortune based on your name, like this:

main= do
putStrLn "Hello, what's your name?"
name <- getLine
putStrLn $ "Zis is your future: " ++ tellFortune name

ThetellFortunefunction(or any of the functions it passesnameto) does
not need to know anything about I/O—it’s just a normalString -> String
function!
To see how normal values differ from I/O actions, consider the follow-
ing line. Is it valid?

nameTag= "Hello, my name is " ++ getLine

Ifyou said no, go eat a cookie. If you said yes, drink a bowl of molten
lava. (Just kidding—don’t!) This doesn’t work because++requires both its
parameters to be lists over the same type. The left parameter has a type of
String(or[Char], if you will), whilegetLinehas a type ofIO String. Remember
that you can’t concatenate a string and an I/O action. First, you need to get
the result out of the I/O action to get a value of typeString, and the only
way to do that is to do something likename <- getLineinside some other I/O
action.
If we want to deal with impure data, we must do it in an impure environ-
ment. The taint of impurity spreads around much like the undead scourge,
and it’s in our best interest to keep the I/O parts of our code as small as
possible.
Every I/O action that is performed yields a result. That’s why our previ-
ous example could also have been written like this:

main= do
foo <- putStrLn "Hello, what's your name?"
name <- getLine
putStrLn ("Hey " ++ name ++ ", you rock!")

However,foowouldjust have a value of(), so doing that would be kind
of moot. Notice that we didn’t bind the lastputStrLnto anything. That’s be-
cause in adoblock, the last action cannot be bound to a name as the first
two were. You’ll see exactly why that is so when we venture off into the world
of monads, starting in Chapter 13. For now, the important point is that the
doblock automatically extracts the value from the last action and yields that
as its own result.
Except for the last line, every line in adoblock that doesn’t bind can
also be written with a bind. SoputStrLn "BLAH"can be written as_ <- putStrLn

```
Input and Output 157
```

```
"BLAH".But that’s useless, so we leave out the<-for I/O actions that don’t
yield an important result, likeputStrLn.
What do you think will happen when we do something like the following?
```
```
myLine= getLine
```
```
Doyou think it will read from the input and then bind the value of that
toname? Well, it won’t. All this does is give thegetLineI/O action a differ-
ent name calledmyLine. Remember that to get the value out of an I/O ac-
tion, you must perform it inside another I/O action by binding it to a name
with<-.
I/O actions will be performed when they are given a name ofmainor
when they’re inside a bigger I/O action that we composed with adoblock.
We can also use adoblock to glue together a few I/O actions, and then we
can use that I/O action in anotherdoblock, and so on. They will be per-
formed if they eventually fall intomain.
There’s also one more case when I/O actions will be performed: when
we type out an I/O action in GHCi and pressENTER.
```
```
ghci>putStrLn "HEEY"
HEEY
```
```
Evenwhen we just punch in a number or call a function in GHCi and
pressENTER, GHCi will applyshowto the resulting value, and then it will
print it to the terminal by usingputStrLn.
```
## Using let Inside I/O Actions...............................................

```
When usingdosyntax to glue together I/O actions, we can useletsyntax
to bind pure values to names. Whereas<-is used to perform I/O actions
and bind their results to names,letis used when we just want to give names
to normal values inside I/O actions. It’s similar to theletsyntax in list
comprehensions.
Let’s take a look at an I/O action that uses both<-andletto bind names.
```
```
importData.Char
```
```
main = do
putStrLn "What's your first name?"
firstName <- getLine
putStrLn "What's your last name?"
lastName <- getLine
let bigFirstName = map toUpper firstName
bigLastName = map toUpper lastName
putStrLn $ "hey " ++ bigFirstName ++ " "
++ bigLastName
++ ", how are you?"
```
**158** Chapter 8


Seehow the I/O actions in thedoblock are lined up? Also notice how
theletis lined up with the I/O actions, and the names of theletare lined
up with each other? That’s good practice, because indentation is important
in Haskell.
We wrotemap toUpper firstName, which turns something like"John"into a
much cooler string like"JOHN". We bound that uppercased string to a name
and then used it in a string that we printed to the terminal.
You may be wondering when to use<-and when to useletbindings.
<-is for performing I/O actions and binding their results to names.
map toUpper firstName, however, isn’t an I/O action—it’s a pure expression
in Haskell. So you can use<-when you want to bind the results of I/O ac-
tions to names, and you can useletbindings to bind pure expressions to
names. Had we done something likelet firstName = getLine, we would have
just called thegetLineI/O action a different name, and we would still need
to run it through a<-to perform it and bind its result.

## Putting It in Reverse......................................................

To get a better feel for doing I/O in Haskell, let’s make a simple program
that continuously reads a line and prints out the same line with the words re-
versed. The program’s execution will stop when we input a blank line. This
is the program:

main= do
line <- getLine
if null line
then return ()
else do
putStrLn $ reverseWords line
main

reverseWords :: String -> String
reverseWords = unwords. map reverse. words

Toget a feel for what it does, save it as _reverse.hs_ , and then compile and
run it:

$ghc --make reverse.hs
[1 of 1] Compiling Main ( reverse.hs, reverse.o )
Linking reverse ...
$ ./reverse
clean up on aisle number nine
naelc pu no elsia rebmun enin
the goat of error shines a light upon your life
eht taog fo rorre senihs a thgil nopu ruoy efil
it was all a dream
ti saw lla a maerd

```
Input and Output 159
```

```
OurreverseWordsfunctionis just a normal function. It takes a string
like"hey there man"and applieswordsto it to produce a list of words like
["hey","there","man"]. We mapreverseover the list, getting["yeh","ereht",
"nam"], and then we put that back into one string by usingunwords. The final
result is"yeh ereht nam".
What aboutmain? First, we get a line from the terminal by performing
getLineand call that lineline. Next we have a conditional expression. Re-
member that in Haskell, everyifmust have a correspondingelse, because
every expression must have some sort of value. Ourifsays that when a con-
dition is true (in our case, the line that we entered is blank), we perform one
I/O action; when it isn’t true, the I/O action under theelseis performed.
Because we need to have exactly one I/O action after theelse, we use a
doblock to glue together two I/O actions into one. We could also write that
part as follows:
```
```
else(do
putStrLn $ reverseWords line
main)
```
```
Thismakes it clearer that thedoblock can be viewed as one I/O action,
but it’s uglier.
Inside thedoblock, we applyreverseWordsto the line that we got from
getLineand then print that to the terminal. After that, we just performmain.
It’s performed recursively, and that’s okay, becausemainis itself an I/O ac-
tion. So in a sense, we go back to the start of the program.
Ifnull lineisTrue, the code after thethenis executed:return (). You
might have used areturnkeyword in other languages to return from a sub-
routine or function. Butreturnin Haskell is nothing like thereturnin most
other languages.
In Haskell (and in I/O actions specifically),returnmakes an I/O action
out of a pure value. Returning to the box analogy for I/O actions,return
takes a value and wraps it up in a box. The resulting I/O action doesn’t ac-
tually do anything; it just yields that value as its result. So in an I/O context,
return "haha"will have a type ofIO String.
What’s the point of just transforming a pure value into an I/O action
that doesn’t do anything? Well, we needed some I/O action to carry out in
the case of an empty input line. That’s why we made a bogus I/O action that
doesn’t do anything by writingreturn ().
Unlike in other languages, usingreturndoesn’t cause the I/Odoblock
to end in execution. For instance, this program will quite happily continue
all the way to the last line:
```
```
main= do
return ()
return "HAHAHA"
line <- getLine
return "BLAH BLAH BLAH"
```
**160** Chapter 8


```
return 4
putStrLn line
```
```
Again, all theseuses ofreturndo is make I/O actions that yield a result,
which is then thrown away because it isn’t bound to a name.
We can usereturnin combination with<-to bind stuff to names:
```
```
main = do
a<- return "hell"
b <- return "yeah!"
putStrLn $ a ++ " " ++ b
```
```
So you see,returnissort of the opposite of<-. Whilereturntakes a value
and wraps it up in a box,<-takes a box (and performs it) and takes the value
out of it, binding it to a name. But doing this is kind of redundant, especially
since you can useletindoblocks to bind to names, like so:
```
```
main = do
leta = "hell"
b = "yeah"
putStrLn $ a ++ " " ++ b
```
```
When dealing withI/Odoblocks, we mostly usereturneither because we
need to create an I/O action that doesn’t do anything or because we don’t
want the I/O action that’s made up from adoblock to have the result value
of its last action. When we want it to have a different result value, we use
returnto make an I/O action that always yields our desired result, and we
put it at the end.
```
## Some Useful I/O Functions........................................................

```
Haskell comes with a bunch of useful functions and I/O actions. Let’s take a
look at some of them to see how they’re used.
```
## putStr...................................................................

```
putStris much likeputStrLn, in that it takes a string as a parameter and re-
turns an I/O action that will print that string to the terminal. However,
putStrdoesn’t jump into a new line after printing out the string, whereas
putStrLndoes. For example, look at this code:
```
```
main = do
putStr"Hey, "
putStr "I'm "
putStrLn "Andy!"
```
```
Input and Output 161
```

```
Ifwe compile and run this, we get the following output:
```
```
Hey,I'm Andy!
```
## putChar.................................................................

```
TheputCharfunctiontakes a character and returns an I/O action that will
print it to the terminal:
```
```
main= do
putChar 't'
putChar 'e'
putChar 'h'
```
```
putStrcanbe defined recursively with the help ofputChar. The base case
ofputStris the empty string, so if we’re printing an empty string, we just re-
turn an I/O action that does nothing by usingreturn (). If it’s not empty,
then we print the first character of the string by doingputCharand then print
the rest of them recursively:
```
```
putStr:: String -> IO ()
putStr [] = return ()
putStr (x:xs) = do
putChar x
putStr xs
```
```
Noticehow we can use recursion in I/O, just as we can use it in pure
code. We define the base case and then think what the result actually is. In
this case, it’s an action that first outputs the first character and then outputs
the rest of the string.
```
## print....................................................................

```
printtakes a value of any type that’s an instance ofShow(meaning that
we know how to represent it as a string), appliesshowto that value to
“stringify” it, and then outputs that string to the terminal. Basically, it’s
justputStrLn. show. It first runsshowon a value, and then feeds that to
putStrLn, which returns an I/O action that will print out our value.
```
```
main= do
print True
print 2
print "haha"
print 3.2
print [3,4,3]
```
**162** Chapter 8


```
Compilingthis and running it, we get the following output:
```
True
2
"haha"
3.2
[3,4,3]

Asyou can see, it’s a very handy function. Remember how we talked
about how I/O actions are performed only when they fall intomainor when
we try to evaluate them at the GHCi prompt? When we type out a value (like
3 or[1,2,3]) and pressENTER, GHCi actually usesprinton that value to dis-
play it on the terminal!

ghci> 3
3
ghci> print 3
3
ghci> map (++"!") ["hey","ho","woo"]
["hey!","ho!","woo!"]
ghci> print $ map (++"!") ["hey","ho","woo"]
["hey!","ho!","woo!"]

Whenwe want to print out strings, we usually useputStrLnbecause we
don’t want the quotes around them. However, for printing out values of
other types to the terminal,printis used the most often.

## when...................................................................

Thewhenfunction is found inControl.Monad(to access it, useimport
Control.Monad). It’s interesting because in adoblock, it looks like a flow-
control statement, but it’s actually a normal function.
whentakes aBooland an I/O action, and if thatBoolvalue isTrue, it re-
turns the same I/O action that we supplied to it. However, if it’sFalse, it
returns thereturn ()action, which doesn’t do anything.
Here’s a small program that asks for some input and prints it back to the
terminal, but only if that input isSWORDFISH:

importControl.Monad

main = do
input <- getLine
when (input == "SWORDFISH") $ do
putStrLn input

```
Input and Output 163
```

```
Withoutwhen,we would need to write the program like this:
```
```
main= do
input <- getLine
if (input == "SWORDFISH")
then putStrLn input
else return ()
```
```
Asyou can see, thewhenfunction is useful when we want to perform
some I/O actions when a condition is met, but do nothing otherwise.
```
## sequence

```
Thesequencefunction takes a list of I/O actions and returns an I/O action
that will perform those actions one after the other. The result that this I/O
action yields will be a list of the results of all the I/O actions that were per-
formed. For instance, we could do this:
```
```
main= do
a <- getLine
b <- getLine
c <- getLine
print [a,b,c]
```
```
Orwe could do this:
```
```
main= do
rs <- sequence [getLine, getLine, getLine]
print rs
```
```
Theresults of both these versions are exactly the same.sequence
[getLine, getLine, getLine]makes an I/O action that will performgetLine
three times. If we bind that action to a name, the result is a list of all the re-
sults. So in this case, the result would be a list of three things that the user
entered at the prompt.
A common pattern withsequenceis when we map functions likeprintor
putStrLnover lists. Executingmap print [1,2,3,4]won’t create an I/O action,
but instead will create a list of I/O actions. Effectively, this is the same as
writing this:
```
```
[print1, print 2, print 3, print 4]
```
```
Ifwe want to transform that list of I/O actions into an I/O action, we
must sequence it:
```
```
ghci>sequence $ map print [1,2,3,4,5]
1
2
```
**164** Chapter 8


3
4
5
[(),(),(),(),()]

Butwhat’s with the[(),(),(),(),()]at the end of the output? Well,
when we evaluate an I/O action in GHCi, that action is performed, and
then its result is printed out, unless that result is(). That’s why evaluating
putStrLn "hehe"in GHCi just prints outhehe—putStrLn "hehe"yields(). But
when we entergetLinein GHCi, the result of that I/O action is printed out,
becausegetLinehas a type ofIO String.

## mapM..................................................................

Because mapping a function that returns an I/O action over a list and then
sequencing it is so common, the utility functionsmapMandmapM_were intro-
duced.mapMtakes a function and a list, maps the function over the list, and
then sequences it.mapM_does the same thing, but it throws away the result
later. We usually usemapM_when we don’t care what result our sequenced
I/O actions have. Here’s an example ofmapM:

ghci>mapM print [1,2,3]
1
2
3
[(),(),()]

Butwe don’t care about the list of three units at the end, so it’s better to
use this form:

ghci>mapM_ print [1,2,3]
1
2
3

## forever..................................................................

Theforeverfunctiontakes an I/O action and returns an I/O action that just
repeats the I/O action it got forever. It’s located inControl.Monad. The fol-
lowing little program will indefinitely ask the user for some input and spit it
back in all uppercase characters:

importControl.Monad
import Data.Char

main = forever $ do
putStr "Give me some input: "

```
Input and Output 165
```

```
l<- getLine
putStrLn $ map toUpper l
```
## forM....................................................................

```
forM(locatedinControl.Monad) is likemapM, but its parameters are switched
around. The first parameter is the list, and the second is the function to map
over that list, which is then sequenced. Why is that useful? Well, with some
creative use of lambdas anddonotation, we can do stuff like this:
```
```
importControl.Monad
```
```
main = do
colors <- forM [1,2,3,4] (\a -> do
putStrLn $ "Which color do you associate with the number "
++ show a ++ "?"
color <- getLine
return color)
putStrLn "The colors that you associate with 1, 2, 3 and 4 are: "
mapM putStrLn colors
```
```
Here’swhat we get when we try this out:
```
```
Whichcolor do you associate with the number 1?
white
Which color do you associate with the number 2?
blue
Which color do you associate with the number 3?
red
Which color do you associate with the number 4?
orange
The colors that you associate with 1, 2, 3 and 4 are:
white
blue
red
orange
```
```
The(\a-> do ... )lambda is a function that takes a number and re-
turns an I/O action. Notice that we callreturn colorin the insidedoblock.
We do that so that the I/O action that thedoblock defines yields the string
that represents our color of choice. We actually did not have to do that
though, sincegetLinealready yields our chosen color, and it’s the last line
in thedoblock. Doingcolor <- getLineand thenreturn coloris just unpack-
ing the result fromgetLineand then repacking it—it’s the same as just call-
inggetLine.
TheforMfunction (called with its two parameters) produces an I/O
action, whose result we bind tocolors.colorsis just a normal list that holds
```
**166** Chapter 8


```
strings.At the end, we print out all those colors by callingmapM putStrLn
colors.
You can think offorMas saying, “Make an I/O action for every element
in this list. What each I/O action will do can depend on the element that
was used to make the action. Finally, perform those actions and bind their
results to something.” (Although we don’t need to bind it; we could also just
throw it away.)
We could have actually achieve the same result withoutforM, but us-
ingforMmakes the code more readable. Normally, we useforMwhen we
want to map and sequence some actions that we define on the spot using
donotation.
```
## I/O Action Review...............................................................

```
Let’s run through a quick review of the I/O basics. I/O actions are values
much like any other value in Haskell. We can pass them as parameters to
functions, and functions can return I/O actions as results.
What’s special about I/O actions is that if they fall into themainfunction
(or are the result in a GHCi line), they are performed. And that’s when they
get to write stuff on your screen or play “Yakety Sax” through your speakers.
Each I/O action can also yield a result to tell you what it got from the real
world.
```
```
Input and Output 167
```


# 9

## MORE INPUT AND MORE OUTPUT

```
Now that you understand the concepts behind Has-
kell’s I/O, we can start doing fun stuff with it. In this
chapter, we’ll interact with files, make random num-
bers, deal with command-line arguments, and more.
Stay tuned!
```
## Files and Streams.................................................................

```
Armedwith the knowledge about
how I/O actions work, we can move
on to reading and writing files with
Haskell. But first, let’s take a look
at how we can use Haskell to easily
process streams of data. A stream is
a succession of pieces of data enter-
ing or exiting a program over time.
For instance, when you’re inputting
characters into a program via the
keyboard, those characters can be
thought of as a stream.
```

## Input Redirection.........................................................

```
Many interactive programs get the user’s input via the keyboard. However,
it’s often more convenient to get the input by feeding the contents of a text
file to the program. To achieve this, we use input redirection.
Input redirection will come in handy with our Haskell programs, so let’s
take a look at how it works. To begin, create a text file that contains the fol-
lowing little haiku, and save it as haiku.txt :
```
```
I'ma lil' teapot
What's with that airplane food, huh?
It's so small, tasteless
```
```
Yeah,the haiku sucks—what of it? If anyone knows of any good haiku
tutorials, let me know.
Now we’ll write a little program that continuously gets a line from the
input and then prints it back in all uppercase:
```
```
importControl.Monad
import Data.Char
```
```
main = forever $ do
l <- getLine
putStrLn $ map toUpper l
```
```
Savethis program as capslocker.hs and compile it.
Instead of inputting lines via the keyboard, we’ll have haiku.txt be the
input by redirecting it into our program. To do that, we add a<character
after our program name and then specify the file that we want to act as the
input. Check it out:
```
```
$ghc --make capslocker
[1 of 1] Compiling Main ( capslocker.hs, capslocker.o )
Linking capslocker ...
$ ./capslocker < haiku.txt
I'M A LIL' TEAPOT
WHAT'S WITH THAT AIRPLANE FOOD, HUH?
IT'S SO SMALL, TASTELESS
capslocker <stdin>: hGetLine: end of file
```
```
Whatwe’ve done is pretty much equivalent to runningcapslocker, typing
our haiku at the terminal, and then issuing an end-of-file character (usu-
ally done by pressingCTRL-D). It’s like runningcapslockerand saying, “Wait,
don’t read from the keyboard. Take the contents of this file instead!”
```
**170** Chapter 9


## Getting Strings from Input Streams.........................................

Let’s take a look at an I/O action that makes processing input streams easier
by allowing us to treat them as normal strings:getContents.getContentsreads
everything from the standard input until it encounters an end-of-file charac-
ter. Its type isgetContents :: IO String. What’s cool aboutgetContentsis that
it does lazy I/O. This means that when we dofoo <- getContents,getContents
doesn’t read all of the input at once, store it in memory, and then bind it to
foo. No,getContentsis lazy! It will say, “Yeah yeah, I’ll read the input from the
terminal later as we go along, when you really need it!”
In our _capslocker.hs_ example, we usedforeverto read the input line by
line and then print it back in uppercase. If we opt to usegetContents, it takes
care of the I/O details for us, such as when to read input and how much
of that input to read. Because our program is about taking some input and
transforming it into some output, we can make it shorter by usinggetContents:

importData.Char

main = do
contents <- getContents
putStr $ map toUpper contents

Werun thegetContentsI/O action and name the string it produces
contents. Then we maptoUpperover that string and print that result to the
terminal. Keep in mind that because strings are basically lists, which are lazy,
andgetContentsis I/O lazy; it won’t try to read all of the content at once and
store that into memory before printing out the caps-locked version. Rather,
it will print out the caps-locked version as it reads, because it will read a line
from the input only when it must.
Let’s test it:

$./capslocker < haiku.txt
I'M A LIL' TEAPOT
WHAT'S WITH THAT AIRPLANE FOOD, HUH?
IT'S SO SMALL, TASTELESS

So,it works. What if we just runcapslockerand try to type in the lines
ourselves? (To exit the program, just pressCTRL-D.)

$./capslocker
hey ho
HEY HO
lets go
LETS GO

```
More Input and More Output 171
```

```
Prettynice! As you can see, it prints our caps-locked input line by line.
When the result ofgetContentsis bound tocontents, it’s not represented
in memory as a real string, but more like a promise that the string will be
produced eventually. When we maptoUpperovercontents, that’s also a pro-
mise to map that function over the eventual contents. Finally, whenputStr
happens, it says to the previous promise, “Hey, I need a caps-locked line!”
It doesn’t have any lines yet, so it says tocontents, “How about getting a line
from the terminal?” And that’s whengetContentsactually reads from the ter-
minal and gives a line to the code that asked it to produce something tangi-
ble. That code then mapstoUpperover that line and gives it toputStr, which
prints the line. And thenputStrsays, “Hey, I need the next line—come on!”
This repeats until there’s no more input, which is signified by an end-of-file
character.
Now let’s make a program that takes some input and prints out only
those lines that are shorter than 10 characters:
```
```
main= do
contents <- getContents
putStr (shortLinesOnly contents)
```
```
shortLinesOnly :: String -> String
shortLinesOnly = unlines. filter (\line -> length line < 10). lines
```
```
We’vemade the I/O part of our program as short as possible. Because
our program is supposed to print something based on some input, we can
implement it by reading the input contents, running a function on them,
and then printing out what that function gives back.
TheshortLinesOnlyfunction takes a string, like"short\nlooooooong\nbort".
In this example, that string has three lines: two of them are short, and the
middle one is long. It applies thelinesfunction to that string, which con-
verts it to["short", "looooooong", "bort"]. That list of strings is then filtered
so that only those lines that are shorter than 10 characters remain in the
list, producing["short", "bort"]. Finally,unlinesjoins that list into a single
newline-delimited string, giving"short\nbort".
Let’s give it a go. Save the following text as shortlines.txt.
```
```
i'mshort
so am i
i am a loooooooooong line!!!
yeah i'm long so what hahahaha!!!!!!
short line
loooooooooooooooooooooooooooong
short
```
**172** Chapter 9


```
Andnow we’ll compile our program, which we saved as shortlinesonly.hs :
```
$ghc --make shortlinesonly
[1 of 1] Compiling Main ( shortlinesonly.hs, shortlinesonly.o )
Linking shortlinesonly ...

Totest it, we’re going to redirect the contents of _shortlines.txt_ into our
program, as follows:

$./shortlinesonly < shortlines.txt
i'm short
so am i
short

```
Youcan see that only the short lines were printed to the terminal.
```
## Transforming Input.......................................................

The pattern of getting some string from the input, transforming it with a
function, and outputting the result is so common that there is a function
that makes that job even easier, calledinteract.interacttakes a function of
typeString -> Stringas a parameter and returns an I/O action that will take
some input, run that function on it, and then print out the function’s result.
Let’s modify our program to useinteract:

main= interact shortLinesOnly

shortLinesOnly :: String -> String
shortLinesOnly = unlines. filter (\line -> length line < 10). lines

Wecan use this program either by redirecting a file into it or by running
it and then giving it input from the keyboard, line by line. Its output is the
same in both cases, but when we’re doing input via the keyboard, the output
is interspersed with what we typed in, just as when we manually typed in our
input to ourcapslockerprogram.
Let’s make a program that continuously reads a line and then outputs
whether or not that line is a palindrome. We could just usegetLineto read
a line, tell the user if it’s a palindrome, and then runmainall over again.
But it’s simpler if we useinteract. When usinginteract, think about what
you need to do to transform some input into the desired output. In our
case, we want to replace each line of the input with either"palindrome"or
"not a palindrome".

```
More Input and More Output 173
```

```
respondPalindromes:: String -> String
respondPalindromes =
unlines.
map (\xs -> if isPal xs then "palindrome" else "not a palindrome").
lines
```
```
isPal :: String -> Bool
isPal xs = xs == reverse xs
```
```
Thisprogram is pretty straightforward. First, it turns a string like this:
```
```
"elephant\nABCBA\nwhatever"
```
```
intoan array like this:
```
```
["elephant","ABCBA", "whatever"]
```
```
Thenit maps the lambda over it, giving the results:
```
```
["nota palindrome", "palindrome", "not a palindrome"]
```
```
Next,unlinesjoinsthat list into a single, newline-delimited string. Now
we just make a main I/O action:
```
```
main= interact respondPalindromes
```
```
Let’stest it:
```
```
$./palindromes
hehe
not a palindrome
ABCBA
palindrome
cookie
not a palindrome
```
```
Eventhough we created a program that transforms one big string of
input into another, it acts as if we made a program that does it line by line.
That’s because Haskell is lazy, and it wants to print the first line of the result
string, but it can’t because it doesn’t have the first line of the input yet. So as
soon as we give it the first line of input, it prints the first line of the output.
We get out of the program by issuing an end-of-line character.
```
**174** Chapter 9


```
Wecan also use this program by just redirecting a file into it. Create the
following file and save it as words.txt.
```
```
dogaroo
radar
rotor
madam
```
```
Thisis what we get by redirecting it into our program:
```
```
$./palindrome < words.txt
not a palindrome
palindrome
palindrome
palindrome
```
```
Again,we get the same output as if we had run our program and put in
the words ourselves at the standard input. We just don’t see the input that
our program gets because that input came from the file.
So now you see how lazy I/O works and how we can use it to our advan-
tage. You can just think in terms of what the output is supposed to be for
some given input and write a function to do that transformation. In lazy
I/O, nothing is eaten from the input until it absolutely must be, because
what we want to print right now depends on that input.
```
## Readingand Writing Files.........................................................

```
So far, we’ve worked with I/O by printing stuff to the terminal and reading
from it. But what about reading and writing files? Well, in a way, we’ve al-
ready been doing that.
One way to think about reading from the terminal is that it’s like reading
from a (somewhat special) file. The same goes for writing to the terminal—
it’s kind of like writing to a file. We can call these two files stdout and stdin ,
meaning standard output and standard input, respectively. Writing to and
reading from files is very much like writing to the standard output and read-
ing from the standard input.
We’ll start off with a really simple program that opens a file called
girlfriend.txt , which contains a verse from Avril Lavigne’s hit song “Girlfriend,”
and just prints out to the terminal. Here’s girlfriend.txt :
```
```
Hey!Hey! You! You!
I don't like your girlfriend!
No way! No way!
I think you need a new one!
```
```
More Input and More Output 175
```

```
Andhere’s our program:
```
```
importSystem.IO
```
```
main = do
handle <- openFile "girlfriend.txt" ReadMode
contents <- hGetContents handle
putStr contents
hClose handle
```
```
Ifwe compile and run it, we get the expected result:
```
```
$./girlfriend
Hey! Hey! You! You!
I don't like your girlfriend!
No way! No way!
I think you need a new one!
```
```
Let’sgo over this line by line. The first line is just four exclamations, to
get our attention. In the second line, Avril tells us that she doesn’t like our
current partner of the female persuasion. The third line serves to emphasize
that disapproval, and the fourth line suggests we should go about finding a
suitable replacement.
Let’s also go over the program line by line. Our program is several I/O
actions glued together with adoblock. In the first line of thedoblock is a
new function calledopenFile. It has the following type signature:
```
```
openFile:: FilePath -> IOMode -> IO Handle
```
```
openFiletakesa file path and anIOModeand returns an I/O action that
will open a file and yield the file’s associated handle as its result.FilePathis
just a type synonym forString, defined as follows:
```
```
typeFilePath = String
```
```
IOModeisa type that’s defined like this:
```
```
dataIOMode = ReadMode | WriteMode | AppendMode | ReadWriteMode
```
```
Justlike our type that represents the seven possible values for the days
of the week, this type is an enumeration that represents what we want to do
with our opened file. Notice that this type isIOModeand notIO Mode.IO Mode
would be the type of I/O action that yields a value of some typeModeas its
result.IOModeis just a simple enumeration.
```
**176** Chapter 9


Finally,openFilereturnsan I/O action
that will open the specified file in the speci-
fied mode. If we bind that action’s result to
something, we get aHandle, which represents
where our file is. We’ll use that handle so we
know which file to read from.
In the next line, we have a function
calledhGetContents. It takes aHandle, so it
knows which file to get the contents from,
and returns anIO String—an I/O action
that holds contents of the file as its result.
This function is pretty much likegetContents.
The only difference is thatgetContentswill
automatically read from the standard in-
put (that is, from the terminal), whereas
hGetContentstakes a file handle that tells
it which file to read from. In all other re-
spects, they work the same.
Just likegetContents,hGetContentswon’t attempt to read all the file at
once and store it in memory but will read the content only as needed. This
is really cool because we can treatcontentsas the whole content of the file,
but it’s not really loaded in memory. So if this were a really huge file, doing
hGetContentswouldn’t choke up our memory.
Note the difference between a handle and the actual contents of the
file. A handle just points to our current position in the file. The contents
are what’s actually in the file. If you imagine your whole filesystem as a really
big book, the handle is like a bookmark that shows where you’re currently
reading (or writing).
WithputStr contents, we print the contents out to the standard output,
and then we dohClose, which takes a handle and returns an I/O action
that closes the file. You need to close the file yourself after opening it with
openFile! Your program may terminate if you try to open a file whose handle
hasn’t been closed.

## Using the withFile Function................................................

Another way of working with the contents of a file as we just did is to use the
withFilefunction, which has the following type signature:

withFile:: FilePath -> IOMode -> (Handle -> IO a) -> IO a

Ittakes a path to a file, anIOMode, and a function that takes a handle and
returns some I/O action. Then it returns an I/O action that will open that
file, do something with the file, and close it. Furthermore, if anything goes
wrong while we’re operating on our file,withFilemakes sure that the file
handle gets closed. This might sound a bit complicated, but it’s really sim-
ple, especially if we use lambdas.

```
More Input and More Output 177
```

```
Here’sour previous example rewritten to usewithFile:
```
```
importSystem.IO
```
```
main = do
withFile "girlfriend.txt" ReadMode (\handle -> do
contents <- hGetContents handle
putStr contents)
```
```
(\handle-> ...)is the function that takes a handle and returns an I/O
action, and it’s usually done like this, with a lambda. It needs to take a func-
tion that returns an I/O action, rather than just taking an I/O action to do
and then closing the file, because the I/O action that we would pass to it
wouldn’t know on which file to operate. This way,withFileopens the file
and then passes the handle to the function we gave it. It gets an I/O action
back from that function and then makes an I/O action that’s just like the
original action, but it also makes sure that the file handle gets closed, even
if something goes awry.
```
## It’s Bracket Time.........................................................

```
Usually,if a piece of code callserror(such
as when we try to applyheadto an empty list)
or if something goes very wrong when doing
input and output, our program terminates,
and we see some sort of error message. In
such circumstances, we say that an exception
gets raised. ThewithFilefunction makes sure
that despite an exception being raised, the
file handle is closed.
This sort of scenario comes up often.
We acquire some resource (like a file han-
dle), and we want to do something with it,
but we also want to make sure that the re-
source gets released (for example, the file
handle is closed). Just for such cases, the
Control.Exceptionmodule offers thebracket
function. It has the following type signature:
```
```
bracket:: IO a -> (a -> IO b) -> (a -> IO c) -> IO c
```
```
Itsfirst parameter is an I/O action that acquires a resource, such as a
file handle. Its second parameter is a function that releases that resource.
This function gets called even if an exception has been raised. The third
parameter is a function that also takes that resource and does something
with it. The third parameter is where the main stuff happens, like reading
from a file or writing to it.
```
**178** Chapter 9


Becausebracketisall about acquiring a resource, doing something with
it, and making sure it gets released, implementingwithFileis really easy:

withFile:: FilePath -> IOMode -> (Handle -> IO a) -> IO a
withFile name mode f = bracket (openFile name mode)
(\handle -> hClose handle)
(\handle -> f handle)

Thefirst parameter that we pass tobracketopens the file, and its result is
a file handle. The second parameter takes that handle and closes it.bracket
makes sure that this happens even if an exception is raised. Finally, the third
parameter tobrackettakes a handle and applies the functionfto it, which
takes a file handle and does stuff with that handle, like reading from or writ-
ing to the corresponding file.

## Grab the Handles!.......................................................

Just ashGetContentsworks likegetContentsbut for a specific file, functions like
hGetLine,hPutStr,hPutStrLn,hGetChar, and so on work just like their counter-
parts without thehbut take only a handle as a parameter and operate on
that specific file instead of on standard input or standard output. For exam-
ple,putStrLntakes a string and returns an I/O action that will print out that
string to the terminal and a newline after it.hPutStrLntakes a handle and
a string and returns an I/O action that will write that string to the file as-
sociated with the handle and then put a newline after it. In the same vein,
hGetLinetakes a handle and returns an I/O action that reads a line from
its file.
Loading files and then treating their contents as strings is so com-
mon that we have three nice little functions to make our work even easier:
readFile,writeFile, andappendFile.
ThereadFilefunction has a type signature ofreadFile :: FilePath ->
IO String. (Remember thatFilePathis just a fancy name forString.)readFile
takes a path to a file and returns an I/O action that will read that file (lazily,
of course) and bind its contents to something as a string. It’s usually more
handy than callingopenFileand then callinghGetContentswith the result-
ing handle. Here’s how we could have written our previous example with
readFile:

importSystem.IO

main = do
contents <- readFile "girlfriend.txt"
putStr contents

Becausewe don’t get a handle with which to identify our file, we can’t
close it manually, so Haskell does that for us when we usereadFile.
ThewriteFilefunction has a type ofwriteFile :: FilePath -> String ->
IO (). It takes a path to a file and a string to write to that file and returns

```
More Input and More Output 179
```

```
anI/O action that will do the writing. If such a file already exists, it will be
stomped down to zero length before being written to. Here’s how to turn
girlfriend.txt into a caps-locked version and write it to girlfriendcaps.txt :
```
```
importSystem.IO
import Data.Char
```
```
main = do
contents <- readFile "girlfriend.txt"
writeFile "girlfriendcaps.txt" (map toUpper contents)
```
```
TheappendFilefunctionhas the same type signature aswriteFileand acts
almost the same way. The only difference is thatappendFiledoesn’t truncate
the file to zero length if it already exists. Instead, it appends stuff to the end
of that file.
```
## To-Do Lists.......................................................................

```
Let’s put theappendFilefunction to use by making a program that adds a task
to a text file that lists stuff that we have to do. We’ll assume that the file is
named todo.txt and that it contains one task per line. Our program will take
a line from the standard input and add it to our to-do list:
```
```
importSystem.IO
```
```
main = do
todoItem <- getLine
appendFile "todo.txt" (todoItem ++ "\n")
```
```
Noticethat we added the"\n"to the end of each line, becausegetLine
doesn’t give us a newline character at the end.
Save the file as appendtodo.hs , compile it, and then run it a few times and
give it some to-do items.
```
```
$./appendtodo
Iron the dishes
$ ./appendtodo
Dust the dog
$ ./appendtodo
Take salad out of the oven
$ cat todo.txt
Iron the dishes
Dust the dog
Take salad out of the oven
```
**180** Chapter 9


**NOTE** _catis a program on Unix-type systems that can be used to print text files to the termi-
nal. On Windows systems, you can use your favorite text editor to see what’s inside_
todo.txt _at any given time._

## Deleting Items...........................................................

```
We already made a program to add a new item to our to-do list in todo.txt.
Now let’s make a program to remove an item. We’ll use a few new functions
fromSystem.Directoryand one new function fromSystem.IO, which will all be
explained after the code listing.
```
```
import System.IO
import System.Directory
importData.List
```
```
main = do
contents <- readFile "todo.txt"
let todoTasks = lines contents
numberedTasks = zipWith (\n line -> show n ++ " - " ++ line)
[0..] todoTasks
putStrLn "These are your TO-DO items:"
mapM_ putStrLn numberedTasks
putStrLn "Which one do you want to delete?"
numberString <- getLine
let number = read numberString
newTodoItems = unlines $ delete (todoTasks !! number) todoTasks
(tempName, tempHandle) <- openTempFile "." "temp"
hPutStr tempHandle newTodoItems
hClose tempHandle
removeFile "todo.txt"
renameFile tempName "todo.txt"
```
```
First, we read todo.txt andbind its contents tocontents. Then we split the
contents into a list of strings, with one line for each string. SotodoTasksis
now something like this:
```
```
["Iron the dishes","Dust the dog", "Take salad out of the oven"]
```
```
We zip thenumbers from 0 onward and that list with a function that
takes a number (like 3 ) and a string (like"hey") and returns a new string
(like"3 - hey"). NownumberedTaskslooks like this:
```
```
["0 - Ironthe dishes"
,"1 - Dust the dog"
,"2 - Take salad out of the oven"
]
```
```
MoreInputandMoreOutput 181
```

```
Wethen usemapM_ putStrLn numberedTasksto print each task on a separate
line, ask the user which one to delete, and wait for the user to enter a num-
ber. Let’s say we want to delete number 1 (Dust the dog), so we punch in 1.
numberStringis now"1", and because we want a number rather than a string,
we applyreadto that to get 1 and use aletto bind that tonumber.
Remember thedeleteand!!functions fromData.List?!!returns an
element from a list with some index.deletedeletes the first occurrence
of an element in a list and returns a new list without that occurrence.
(todoTasks !! number)results in"Dust the dog". We delete the the first oc-
currence of"Dust the dog"fromtodoTasksand then join that into a single
line withunlinesand name thatnewTodoItems.
Then we use a function that we haven’t met before, fromSystem.IO:
openTempFile. Its name is pretty self-explanatory. It takes a path to a tempo-
rary directory and a template name for a file and opens a temporary file.
We used"."for the temporary directory, because.denotes the current di-
rectory on just about any operating system. We used"temp"as the template
name for the temporary file, which means that the temporary file will be
named temp plus some random characters. It returns an I/O action that
makes the temporary file, and the result in that I/O action is a pair of val-
ues: the name of the temporary file and a handle. We could just open a nor-
mal file called todo2.txt or something like that, but it’s better practice to use
openTempFileso you know you’re probably not overwriting anything.
Now that we have a temporary file opened, we writenewTodoItemsto it.
The old file is unchanged, and the temporary file contains all the lines that
the old one does, except the one we deleted.
After that, we close both the original and the temporary files, and remove
the original one withremoveFile, which takes a path to a file and deletes it.
After deleting the old todo.txt , we userenameFileto rename the temporary file
to todo.txt .removeFileandrenameFile(which are both inSystem.Directory) take
file paths, not handles, as their parameters.
Save this as deletetodo.hs , compile it, and try it:
```
```
$./deletetodo
These are your TO-DO items:
0 - Iron the dishes
1 - Dust the dog
2 - Take salad out of the oven
Which one do you want to delete?
1
```
```
Nowlet’s see which items remain:
```
```
$cat todo.txt
Iron the dishes
Take salad out of the oven
```
**182** Chapter 9


```
Ah,cool! Let’s delete one more item:
```
$./deletetodo
These are your TO-DO items:
0 - Iron the dishes
1 - Take salad out of the oven
Which one do you want to delete?
0

```
Andexamining the file, we see that only one item remains:
```
$cat todo.txt
Take salad out of the oven

So,everything is working. However, there’s one thing that about this
program that’s kind of off. If something goes wrong after we open our
temporary file, the program terminates, but the temporary file doesn’t get
cleaned up. Let’s remedy that.

## Cleaning Up

To make sure our temporary file is cleaned up in case of a problem, we’re
going to use thebracketOnErrorfunction fromControl.Exception. It’s very simi-
lar tobracket, but whereas thebracketwill acquire a resource and then make
sure that some cleanup always gets done after we’ve used it,bracketOnError
performs the cleanup only if an exception has been raised. Here’s the code:

importSystem.IO
import System.Directory
import Data.List
import Control.Exception

main = do
contents <- readFile "todo.txt"
let todoTasks = lines contents
numberedTasks = zipWith (\n line -> show n ++ " - " ++ line)
[0..] todoTasks
putStrLn "These are your TO-DO items:"
mapM_ putStrLn numberedTasks
putStrLn "Which one do you want to delete?"
numberString <- getLine
let number = read numberString
newTodoItems = unlines $ delete (todoTasks !! number) todoTasks
bracketOnError (openTempFile "." "temp")
(\(tempName, tempHandle) -> do
hClose tempHandle
removeFile tempName)

```
More Input and More Output 183
```

```
(\(tempName,tempHandle) -> do
hPutStr tempHandle newTodoItems
hClose tempHandle
removeFile "todo.txt"
renameFile tempName "todo.txt")
```
```
Insteadof just usingopenTempFilenormally, we use it withbracketOnError.
Next, we write what we want to happen if an error occurs; that is, we want
to close the temporary handle and remove the temporary file. Finally, we
write what we want to do with the temporary file while things are going well,
and these lines are the same as they were before. We write the new items,
close the temporary handle, remove our current file, and rename the tem-
porary file.
```
## Command-Line Arguments.........................................................

```
Dealingwith command-line argu-
ments is pretty much a necessity if
you want to make a script or applica-
tion that runs on a terminal. Luckily,
Haskell’s standard library has a nice
way of getting command-line argu-
ments for a program.
In the previous section, we made
one program for adding an item to
our to-do list and one program for
removing an item. A problem with
them is that we just hardcoded the
name of our to-do file. We decided that the file will be named todo.txt and
that users will never have a need for managing several to-do lists.
One solution is to always ask the users which file they want to use as their
to-do list. We used that approach when we wanted to know which item to
delete. It works, but it’s not the ideal solution because it requires the users
to run the program, wait for the program to ask them something, and then
give the program some input. That’s called an interactive program.
The difficult bit with interactive command-line programs is this: What
if you want to automate the execution of that program, as with a script?
It’s harder to make a script that interacts with a program than a script that
just calls one or more programs. That’s why we sometimes want users to
tell a program what they want when they run the program, instead of hav-
ing the program ask the user once it’s running. And what better way to have
the users tell the program what they want it to do when they run it than via
command-line arguments?
TheSystem.Environmentmodule has two cool I/O actions that are useful
for getting command-line arguments:getArgsandgetProgName.getArgshas
a type ofgetArgs :: IO [String]and is an I/O action that will get the argu-
ments that the program was run with and yield a list of those arguments.
```
**184** Chapter 9


```
getProgNamehasa type ofgetProgName :: IO Stringand is an I/O action that
yields the program name. Here’s a small program that demonstrates how
these two work:
```
```
importSystem.Environment
import Data.List
```
```
main = do
args <- getArgs
progName <- getProgName
putStrLn "The arguments are:"
mapM putStrLn args
putStrLn "The program name is:"
putStrLn progName
```
```
First,we bind the command-line arguments toargsand program name
toprogName. Next, we useputStrLnto print all the program’s arguments and
then the name of the program itself. Let’s compile this asarg-testand try
it out:
```
```
$./arg-test first second w00t "multi word arg"
The arguments are:
first
second
w00t
multi word arg
The program name is:
arg-test
```
## More Fun with To-Do Lists.........................................................

```
In the previous examples, we made one program for adding tasks and an
entirely separate program for deleting them. Now we’re going to join that
into a single program, and whether it adds or deletes items will depend on
the command-line arguments we pass to it. We’ll also make it able to operate
on different files, not just todo.txt.
We’ll call our programtodo, and it will be able to do three different
things:
```
- View tasks
- Add tasks
- Delete tasks

```
To add a task to the todo.txt file, we enter it at the terminal:
```
```
$./todo add todo.txt "Find the magic sword of power"
```
```
More Input and More Output 185
```

```
Toview the tasks, we enter theviewcommand:
```
```
$./todo view todo.txt
```
```
Toremove a task, we use its index:
```
```
$./todo remove todo.txt 2
```
## A Multitasking Task List...................................................

```
We’ll start by making a function that takes a command in the form of a
string, like"add"or"view", and returns a function that takes a list of argu-
ments and returns an I/O action that does what we want:
```
```
importSystem.Environment
import System.Directory
import System.IO
import Data.List
```
```
dispatch :: String -> [String] -> IO ()
dispatch "add" = add
dispatch "view" = view
dispatch "remove" = remove
```
```
We’lldefinemainlike this:
```
```
main= do
(command:argList) <- getArgs
dispatch command argList
```
```
First,we get the arguments and bind them to(command:argList). This
means that the first argument will be bound tocommand, and the rest of the
arguments will be bound toargList. In the next line of ourmainblock, we ap-
ply thedispatchfunction to the command, which results in theadd,view, or
removefunction. We then apply that function toargList.
Suppose we call our program like this:
```
```
$./todo add todo.txt "Find the magic sword of power"
```
```
commandis"add",andargListis["todo.txt", "Find the magic sword of power"].
That way, the second pattern match of thedispatchfunction will succeed, and
it will return theaddfunction. Finally, we apply that toargList, which results
in an I/O action that adds the item to our to-do list.
Now let’s implement theadd,view, andremovefunctions. Let’s start
withadd:
```
```
add:: [String] -> IO ()
add [fileName, todoItem] = appendFile fileName (todoItem ++ "\n")
```
**186** Chapter 9


```
Wemight call our program like so:
```
./todoadd todo.txt "Find the magic sword of power"

The"add"willbe bound tocommandin the first pattern match in themain
block, whereas["todo.txt", "Find the magic sword of power"]will be passed to
the function that we get from thedispatchfunction. So, because we’re not
dealing with bad input right now, we just pattern match against a list with
those two elements immediately and return an I/O action that appends that
line to the end of the file, along with a newline character.
Next, let’s implement the list-viewing functionality. If we want to view
the items in a file, we do./todo view todo.txt. So in the first pattern match,
commandwill be"view", andargListwill be["todo.txt"]. Here’s the function
in full:

view:: [String] -> IO ()
view [fileName] = do
contents <- readFile fileName
let todoTasks = lines contents
numberedTasks = zipWith (\n line -> show n ++ " - " ++ line)
[0..] todoTasks
putStr $ unlines numberedTasks

Whenwe made ourdeletetodoprogram, which could only delete items
from a to-do list, it had the ability to display the items in a to-do list, so this
code is very similar to that part of the previous program.
Finally, we’re going to implementremove. It’s very similar to the pro-
gram that only deleted the tasks, so if you don’t understand how deleting
an item here works, review “Deleting Items” on page 181. The main differ-
ence is that we’re not hardcoding the filename as _todo.txt_ but instead getting
it as an argument. We’re also getting the target task number as an argument,
rather than prompting the user for it.

remove:: [String] -> IO ()
remove [fileName, numberString] = do
contents <- readFile fileName
let todoTasks = lines contents
numberedTasks = zipWith (\n line -> show n ++ " - " ++ line)
[0..] todoTasks
putStrLn "These are your TO-DO items:"
mapM_ putStrLn numberedTasks
let number = read numberString
newTodoItems = unlines $ delete (todoTasks !! number) todoTasks
bracketOnError (openTempFile "." "temp")
(\(tempName, tempHandle) -> do
hClose tempHandle
removeFile tempName)

```
More Input and More Output 187
```

```
(\(tempName,tempHandle) -> do
hPutStr tempHandle newTodoItems
hClose tempHandle
removeFile "todo.txt"
renameFile tempName "todo.txt")
```
```
Weopened the file based onfileNameand opened a temporary file, de-
leted the line with the index that the user wants to delete, wrote that to the
temporary file, removed the original file, and renamed the temporary file
back tofileName.
Here’s the whole program in all its glory:
```
```
importSystem.Environment
import System.Directory
import System.IO
import Data.List
```
```
dispatch :: String -> [String] -> IO ()
dispatch "add" = add
dispatch "view" = view
dispatch "remove" = remove
```
```
main = do
(command:argList) <- getArgs
dispatch command argList
```
```
add :: [String] -> IO ()
add [fileName, todoItem] = appendFile fileName (todoItem ++ "\n")
```
```
view :: [String] -> IO ()
view [fileName] = do
contents <- readFile fileName
let todoTasks = lines contents
numberedTasks = zipWith (\n line -> show n ++ " - " ++ line)
[0..] todoTasks
putStr $ unlines numberedTasks
```
```
remove :: [String] -> IO ()
remove [fileName, numberString] = do
contents <- readFile fileName
let todoTasks = lines contents
numberedTasks = zipWith (\n line -> show n ++ " - " ++ line)
[0..] todoTasks
putStrLn "These are your TO-DO items:"
mapM_ putStrLn numberedTasks
let number = read numberString
newTodoItems = unlines $ delete (todoTasks !! number) todoTasks
```
**188** Chapter 9


```
bracketOnError(openTempFile "." "temp")
(\(tempName, tempHandle) -> do
hClose tempHandle
removeFile tempName)
(\(tempName, tempHandle) -> do
hPutStr tempHandle newTodoItems
hClose tempHandle
removeFile "todo.txt"
renameFile tempName "todo.txt")
```
Tosummarize our solution, we made adispatchfunction that maps from
commands to functions that take some command-line arguments in the form
of a list and return an I/O action. We see what thecommandis, and based on
that, we get the appropriate function from thedispatchfunction. We call
that function with the rest of the command-line arguments to get back an
I/O action that will do the appropriate thing, and then just perform that ac-
tion. Using higher-order functions allows us to just tell thedispatchfunction
to give us the appropriate function, and then tell that function to give us an
I/O action for some command-line arguments.
Let’s try our app!

$./todo view todo.txt
0 - Iron the dishes
1 - Dust the dog
2 - Take salad out of the oven

$ ./todo add todo.txt "Pick up children from dry cleaners"

$ ./todo view todo.txt
0 - Iron the dishes
1 - Dust the dog
2 - Take salad out of the oven
3 - Pick up children from dry cleaners

$ ./todo remove todo.txt 2

$ ./todo view todo.txt
0 - Iron the dishes
1 - Dust the dog
2 - Pick up children from dry cleaners :

Anothercool thing about using thedispatchfunction is that it’s easy to
add functionality. Just add an extra pattern todispatchand implement the
corresponding function, and you’re laughing! As an exercise, you can try im-
plementing abumpfunction that will take a file and a task number and return
an I/O action that bumps that task to the top of the to-do list.

```
More Input and More Output 189
```

## Dealing with Bad Input...................................................

```
We could extend this program to make it fail a bit more gracefully in the
case of bad input, instead of printing out an ugly error message from Has-
kell. We can start by adding a catchall pattern at the end thedispatchfunc-
tion and making it return a function that ignores the argument list and tells
us that such a command doesn’t exist:
```
```
dispatch:: String -> [String] -> IO ()
dispatch "add" = add
dispatch "view" = view
dispatch "remove" = remove
dispatch command = doesntExist command
```
```
doesntExist :: String -> [String] -> IO ()
doesntExist command _ =
putStrLn $ "The " ++ command ++ " command doesn't exist"
```
```
Wemight also add catchall patterns to theadd,view, andremovefunc-
tions, so that the program tells users if they have supplied the wrong number
of arguments to a given command. Here’s an example:
```
```
add:: [String] -> IO ()
add [fileName, todoItem] = appendFile fileName (todoItem ++ "\n")
add _ = putStrLn "The add command takes exactly two arguments"
```
```
Ifaddisapplied to a list that doesn’t have exactly two elements, the first
pattern match will fail, but the second one will succeed, helpfully informing
users of their erronous ways. We can add a catchall pattern like this toview
andremoveas well.
Note that we haven’t covered all of the cases where our input is bad. For
instance, suppose we run our program like this:
```
```
./todo
```
```
Inthis case, it will crash, because we use the(command:argList)pattern
in ourdoblock, but that doesn’t consider the possibility that there are no
arguments at all! We also don’t check to see if the file we’re operating on
exists before trying to open it. Adding these precautions isn’t hard, but it
is a bit tedious, so making this program completely idiot-proof is left as an
exercise to the reader.
```
## Randomness.....................................................................

```
Many times while programming, you need to get some random data (well,
pseudo -random data, since we all know that the only true source of random-
ness is a monkey on a unicycle with cheese in one hand and its butt in the
other). For example, you may be making a game where a die needs to be
```
**190** Chapter 9


thrown,or you need to generate some
data to test your program. In this sec-
tion, we’ll take a look at how to make
Haskell generate seemingly random
data and why we need external input
to generate values that are random
enough.
Most programming languages
have functions that give you back
some random number. Each time you
call that function, you retrieve a dif-
ferent random number. How about
Haskell? Well, remember that Haskell
is a purely functional language. That
means it has referential transparency. And _that_ means a function, if given
the same parameters twice, must produce the same result twice. That’s really
cool, because it allows us to reason about programs, and it enables us to de-
fer evaluation until we really need it. However, this makes it a bit tricky for
getting random numbers.
Suppose we have a function like this:

randomNumber:: Int
randomNumber = 4

It’snot very useful as a random number function, because it will always
return 4. (Even though I can assure you that the 4 is completely random,
because I used a die to determine it.)
How do other languages make seemingly random numbers? Well,
they take some initial data, like the current time, and based on that, gen-
erate numbers that are seemingly random. In Haskell, we can generate ran-
dom numbers by making a function that takes as its parameter some initial
data, or randomness, and produces a random number. We use I/O to bring
randomness into our program from outside.
Enter theSystem.Randommodule. It has all the functions that satisfy our
need for randomness. Let’s just dive into one of the functions it exports:
random. Here is its type signature:

random:: (RandomGen g, Random a) => g -> (a, g)

Whoa!We have some new type classes in this type declaration! The
RandomGentype class is for types that can act as sources of randomness. The
Randomtype class is for types whose values can be random. We can generate
random Boolean values by randomly producing eitherTrueorFalse. We can
also generate numbers that are random. Can a function take on a random
value? I don’t think so! If we try to translate the type declaration ofrandom
to English, we get something like this: It takes a random generator (that’s
our source of randomness) and returns a random value and a new random

```
More Input and More Output 191
```

```
generator.Why does it also return a new generator as well as a random value?
Well, you’ll see in a moment.
To use ourrandomfunction, we need to get our hands on one of those
random generators. TheSystem.Randommodule exports a cool type, namely
StdGen, which is an instance of theRandomGentype class. We can make aStdGen
manually, or we can tell the system to give us one based on a multitude of
(sort of) random stuff.
To manually make a random generator, use themkStdGenfunction. It
has a type ofmkStdGen :: Int -> StdGen. It takes an integer, and based on that,
gives us a random generator. Okay then, let’s try usingrandomandmkStdGenin
tandem to get a (hardly) random number.
```
```
ghci>random (mkStdGen 100)
<interactive>:1:0:
Ambiguous type variable `a' in the constraint:
`Random a' arising from a use of `random' at <interactive>:1:0-20
Probable fix: add a type signature that fixes these type variable(s)
```
```
What’sthis? Ah, right, therandomfunction can return a value of any type
that’s part of theRandomtype class, so we need to inform Haskell which type
we want. Also let’s not forget that it returns a random value and a random
generator in a pair.
```
```
ghci>random (mkStdGen 100) :: (Int, StdGen)
(-1352021624,651872571 1655838864)
```
```
Finally,a number that looks kind of random! The first component of
the tuple is our number, and the second component is a textual representa-
tion of our new random generator. What happens if we call random with the
same random generator again?
```
```
ghci>random (mkStdGen 100) :: (Int, StdGen)
(-1352021624,651872571 1655838864)
```
```
Ofcourse, we get the same result for the same parameters. So let’s try
giving it a different random generator as a parameter:
```
```
ghci>random (mkStdGen 949494) :: (Int, StdGen)
(539963926,466647808 1655838864)
```
```
Great,a different number! We can use the type annotation to get differ-
ent types back from that function.
```
```
ghci>random (mkStdGen 949488) :: (Float, StdGen)
(0.8938442,1597344447 1655838864)
```
**192** Chapter 9


ghci> random (mkStdGen949488) :: (Bool, StdGen)
(False,1485632275 40692)
ghci> random (mkStdGen 949488) :: (Integer, StdGen)
(1691547873,1597344447 1655838864)

## Tossing a Coin..........................................................

Let’s make a function that simulates tossing a coin three times. Ifrandom
didn’t return a new generator along with a random value, we would need
to make this function take three random generators as a parameter and re-
turn coin tosses for each of them. But if one generator can make a random
value of typeInt(which can take on a load of different values), it should be
able to make three coin tosses (which can have only eight different end re-
sults). So this is whererandomreturning a new generator along with a value
comes in handy.
We’ll represent a coin with a simpleBool:Trueis tails, andFalseis heads.

threeCoins :: StdGen-> (Bool, Bool, Bool)
threeCoins gen =
let (firstCoin, newGen) = random gen
(secondCoin, newGen') = random newGen
(thirdCoin, newGen'') = random newGen'
in (firstCoin, secondCoin, thirdCoin)

We callrandomwith thegenerator we got as a parameter to get a coin
and a new generator. Then we call it again, only this time with our new
generator, to get the second coin. We do the same for the third coin.
Had we called it with the same generator every time, all the coins would
have had the same value, so we would get only(False, False, False)or
(True, True, True)as a result.

ghci> threeCoins (mkStdGen21)
(True,True,True)
ghci> threeCoins (mkStdGen 22)
(True,False,True)
ghci> threeCoins (mkStdGen 943)
(True,False,True)
ghci> threeCoins (mkStdGen 944)
(True,True,True)

Notice that wedidn’t need to callrandom gen :: (Bool, StdGen). Since
we already specified that we want Booleans in the type declaration of the
function, Haskell can infer that we want a Boolean value in this case.

```
More Input and More Output 193
```

## More Random Functions..................................................

```
What if we want to flip more coins? For that, there’s a function calledrandoms,
which takes a generator and returns an infinite sequence of values based on
that generator.
```
```
ghci>take 5 $ randoms (mkStdGen 11) :: [Int]
[-1807975507,545074951,-1015194702,-1622477312,-502893664]
ghci> take 5 $ randoms (mkStdGen 11) :: [Bool]
[True,True,True,True,False]
ghci> take 5 $ randoms (mkStdGen 11) :: [Float]
[7.904789e-2,0.62691015,0.26363158,0.12223756,0.38291094]
```
```
Whydoesn’trandomsreturn a new generator as well as a list? We could
implement therandomsfunction very easily like this:
```
```
randoms':: (RandomGen g, Random a) => g -> [a]
randoms' gen = let (value, newGen) = random gen in value:randoms' newGen
```
```
Thisis a recursive definition. We get a random value and a new genera-
tor from the current generator, and then make a list that has the value as its
head and random numbers based on the new generator as its tail. Because
we need to be able to potentially generate an infinite amount of numbers, we
can’t give the new random generator back.
We could make a function that generates a finite stream of numbers and
a new generator like this:
```
```
finiteRandoms:: (RandomGen g, Random a, Num n) => n -> g -> ([a], g)
finiteRandoms 0 gen = ([], gen)
finiteRandoms n gen =
let (value, newGen) = random gen
(restOfList, finalGen) = finiteRandoms (n-1) newGen
in (value:restOfList, finalGen)
```
```
Again,this is a recursive definition. We say that if we want zero numbers,
we just return an empty list and the generator that was given to us. For any
other number of random values, we first get one random number and a new
generator. That will be the head. Then we say that the tail will ben-1num-
bers generated with the new generator. Then we return the head and the
rest of the list joined and the final generator that we got from getting the
n-1random numbers.
What if we want a random value in some sort of range? All the random
integers so far were outrageously big or small. What if we want to throw a
die? Well, we userandomRfor that purpose. It has this type:
```
```
randomR:: (RandomGen g, Random a) :: (a, a) -> g -> (a, g)
```
**194** Chapter 9


Thismeans that it’s kind of likerandom, but it takes as its first parameter
a pair of values that set the lower and upper bounds, and the final value pro-
duced will be within those bounds.

ghci>randomR (1,6) (mkStdGen 359353)
(6,1494289578 40692)
ghci> randomR (1,6) (mkStdGen 35935335)
(3,1250031057 40692)

There’salsorandomRs, which produces a stream of random values within
our defined ranges. Check this out:

ghci>take 10 $ randomRs ('a','z') (mkStdGen 3) :: [Char]
"ndkxbvmomg"

```
Itlooks like a super secret password, doesn’t it?
```
## Randomness and I/O....................................................

You may be wondering what this section has to do with I/O. We haven’t
done anything concerning I/O so far. We’ve always made our random num-
ber generator manually by creating it with some arbitrary integer. The prob-
lem is that if we do that in our real programs, they will always return the same
random numbers, which is no good for us. That’s whySystem.Randomoffers
thegetStdGenI/O action, which has a type ofIO StdGen. It asks the system
for some initial data and uses it to jump-start the _global generator_ .getStdGen
fetches that global random generator when you bind it to something.
Here’s a simple program that generates a random string:

importSystem.Random

main = do
gen <- getStdGen
putStrLn $ take 20 (randomRs ('a','z') gen)

```
Nowlet’s test it:
```
$./random_string
pybphhzzhuepknbykxhe
$ ./random_string
eiqgcxykivpudlsvvjpg
$ ./random_string
nzdceoconysdgcyqjruo
$ ./random_string
bakzhnnuzrkgvesqplrx

```
More Input and More Output 195
```

```
Butyou need to be careful. Just performinggetStdGentwice will ask the
system for the same global generator twice. Suppose we do this:
```
```
importSystem.Random
```
```
main = do
gen <- getStdGen
putStrLn $ take 20 (randomRs ('a','z') gen)
gen2 <- getStdGen
putStr $ take 20 (randomRs ('a','z') gen2)
```
```
Wewill get the same string printed out twice!
The best way to get two different strings is to use thenewStdGenaction,
which splits our current random generator into two generators. It updates
the global random generator with one of them and yields the other as its
result.
```
```
importSystem.Random
```
```
main = do
gen <- getStdGen
putStrLn $ take 20 (randomRs ('a','z') gen)
gen' <- newStdGen
putStr $ take 20 (randomRs ('a','z') gen')
```
```
Notonly do we get a new random generator when we bindnewStdGento
something, but the global one gets updated as well. This means that if we do
getStdGenagain and bind it to something, we’ll get a generator that’s not the
same asgen.
Here’s a little program that will make the user guess which number it’s
thinking of:
```
```
importSystem.Random
import Control.Monad(when)
```
```
main = do
gen <- getStdGen
askForNumber gen
```
```
askForNumber :: StdGen -> IO ()
askForNumber gen = do
let (randNumber, newGen) = randomR (1,10) gen :: (Int, StdGen)
putStrLn "Which number in the range from 1 to 10 am I thinking of? "
numberString <- getLine
when (not $ null numberString) $ do
let number = read numberString
```
**196** Chapter 9


```
ifrandNumber == number
then putStrLn "You are correct!"
else putStrLn $ "Sorry, it was " ++ show randNumber
askForNumber newGen
```
```
Wemake a functionaskForNumber,
which takes a random number genera-
tor and returns an I/O action that will
prompt you for a number, and then tell
you if you guessed it right.
InaskForNumber, we first generate a
random number and a new generator
based on the generator that we got as
a parameter and call themrandNumber
andnewGen. (For this example, let’s say
that the number generated was 7.) Then
we tell the user to guess which number
we’re thinking of. We performgetLine
and bind its result tonumberString. When the user enters 7 ,numberStringbe-
comes"7". Next, we usewhento check if the string the user entered is an
empty string. If it isn’t, the action consisting of thedoblock that is passed
towhenis performed. We usereadonnumberStringto convert it to a number,
sonumberis now 7.
```
**NOTE** _If the user enters some input thatreadcan’t parse (like"haha"), our program will
crash with an ugly error message. If you don’t want your program to crash on erronous
input, usereads, which returns an empty list when it fails to read a string. When it
succeeds, it returns a singleton list with a tuple that has your desired value as one com-
ponent and a string with what it didn’t consume as the other. Try it!_

```
We check if the number that we entered is equal to the one generated
randomly and give the user the appropriate message. Then we perform
askForNumberrecursively, but this time with the new generator that we got.
This gives us an I/O action that’s just like the one we performed, except
that it depends on a different generator.
mainconsists of just getting a random generator from the system and call-
ingaskForNumberwith it to get the initial action.
Here’s our program in action:
```
```
$./guess_the_number
Which number in the range from 1 to 10 am I thinking of?
4
Sorry, it was 3
Which number in the range from 1 to 10 am I thinking of?
10
You are correct!
```
```
More Input and More Output 197
```

```
Whichnumber in the range from 1 to 10 am I thinking of?
2
Sorry, it was 4
Which number in the range from 1 to 10 am I thinking of?
5
Sorry, it was 10
Which number in the range from 1 to 10 am I thinking of?
```
```
Here’sanother way to make this same program:
```
```
importSystem.Random
import Control.Monad(when)
```
```
main = do
gen <- getStdGen
let (randNumber, _) = randomR (1,10) gen :: (Int, StdGen)
putStrLn "Which number in the range from 1 to 10 am I thinking of? "
numberString <- getLine
when (not $ null numberString) $ do
let number = read numberString
if randNumber == number
then putStrLn "You are correct!"
else putStrLn $ "Sorry, it was " ++ show randNumber
newStdGen
main
```
```
It’svery similar to the previous version, but instead of making a function
that takes a generator and then calls itself recursively with the new updated
generator, we do all the work inmain. After telling the user whether he was
correct in his guess, we update the global generator and then callmainagain.
Both approaches are valid, but I like the first one more since it does less stuff
inmainand also provides a function I can reuse easily.
```
## Bytestrings.......................................................................

```
Listsare certainly useful. So far, we’ve used
them pretty much everywhere. There are
a multitude of functions that operate on
them, and Haskell’s laziness allows us to
exchange theforandwhileloops of other
languages for filtering and mapping over
lists. Since evaluation will happen only
when it really needs to, things like infinite
lists (and even infinite lists of infinite lists!)
are no problem for us. That’s why lists can
also be used to represent streams, either
when reading from the standard input or
```
**198** Chapter 9


whenreading from files. We can just open a file and read it as a string, even
though it will be accessed only when the need arises.
However, processing files as strings has one drawback: It tends to be
slow. Lists are really lazy. Remember that a list like[1,2,3,4]is syntactic
sugar for1:2:3:4:[]. When the first element of the list is forcibly evaluated
(say by printing it), the rest of the list2:3:4:[]is still just a promise of a list,
and so on. We call that promise a _thunk_.
A thunk is basically a deferred computation. Haskell achieves its lazi-
ness by using thunks and computing them only when it must, instead of
computing everything up front. So you can think of lists as promises that
the next element will be delivered once it really has to be, and along with
it, the promise of the element after it. It doesn’t take a big mental leap to
conclude that processing a simple list of numbers as a series of thunks might
not be the most efficient technique in the world.
That overhead doesn’t bother us most of the time, but it turns out to be
a liability when reading big files and manipulating them. That’s why Haskell
has _bytestrings_. Bytestrings are sort of like lists, only each element is one byte
(or 8 bits) in size. The way they handle laziness is also different.

## Strict and Lazy Bytestrings................................................

Bytestrings come in two flavors: strict and lazy. Strict bytestrings reside in
Data.ByteString, and they do away with the laziness completely. There are no
thunks involved. A strict bytestring represents a series of bytes in an array.
You can’t have things like infinite strict bytestrings. If you evaluate the first
byte of a strict bytestring, you must evaluate the whole thing.
The other variety of bytestrings resides inData.ByteString.Lazy. They’re
lazy, but not quite as lazy as lists. Since there are as many thunks in a list as
there are elements, they are kind of slow for some purposes. Lazy bytestrings
take a different approach. They are stored in chunks (not to be confused
with thunks!), and each chunk has a size of 64KB. So if you evaluate a byte
in a lazy bytestring (by printing it, for example), the first 64KB will be evalu-
ated. After that, it’s just a promise for the rest of the chunks. Lazy bytestrings
are kind of like lists of strict bytestrings, with a size of 64KB. When you pro-
cess a file with lazy bytestrings, it will be read chunk by chunk. This is cool
because it won’t cause the memory usage to skyrocket, and the 64KB proba-
bly fits neatly into your CPU’s L2 cache.
If you look through the documentation forData.ByteString.Lazy, you
will see that it has a lot of functions with the same names as the ones from
Data.List, but the type signatures haveByteStringinstead of[a]andWord8
instead ofa. These functions are similar to the ones that work on lists. Be-
cause the names are the same, we’re going to do a qualified import in a
script and then load that script into GHCi to play with bytestrings:

importqualified Data.ByteString.Lazy as B
import qualified Data.ByteString as S

```
More Input and More Output 199
```

```
Bhaslazy bytestring types and functions, whereasShas strict ones. We’ll
mostly be using the lazy versions.
Thepackfunction has the type signaturepack :: [Word8] -> ByteString.
This means that it takes a list of bytes of typeWord8and returns aByteString.
You can think of it as taking a list, which is lazy, and making it less lazy, so
that it’s lazy only at 64KB intervals.
TheWord8type is likeInt, but it represents an unsigned 8-bit number.
This means that it has a much smaller range of only 0 to 255. And just like
Int, it’s in theNumtype class. For instance, we know that the value 5 is poly-
morphic in that it can act like any numeric type, includingWord8.
Here’s how we pack lists of numbers into bytestrings:
```
```
ghci>B.pack [99,97,110]
Chunk "can" Empty
ghci> B.pack [98..120]
Chunk "bcdefghijklmnopqrstuvwx" Empty
```
```
Wepacked only a handful of values into a bytestring, so they fit inside
one chunk.Emptyis like[]for lists—they both represent an empty sequence.
As you can see, you don’t need to specify that your numbers are of type
Word8, because the type system can make numbers choose that type. If you try
to use a big number like 336 as aWord8, it will just wrap around to 80.
When we need to examine a bytestring byte by byte, we need to unpack
it. Theunpackfunction is the inverse ofpack. It takes a bytestring and turns it
into a list of bytes. Here’s an example:
```
```
ghci>let by = B.pack [98,111,114,116]
ghci> by
Chunk "bort" Empty
ghci> B.unpack by
[98,111,114,116]
```
```
Youcan also go back and forth between strict and lazy bytestrings. The
toChunksfunction takes a lazy bytestring and converts it to a list of strict ones.
ThefromChunksfunction takes a list of strict bytestrings and converts it to a
lazy bytestring:
```
```
ghci>B.fromChunks [S.pack [40,41,42], S.pack [43,44,45], S.pack [46,47,48]]
Chunk "()*" (Chunk "+,-" (Chunk "./0" Empty))
```
```
Thisis good if you have a lot of small strict bytestrings and you want to
process them efficiently without joining them into one big strict bytestring in
memory first.
The bytestring version of:is calledcons. It takes a byte and a bytestring
and puts the byte at the beginning.
```
**200** Chapter 9


```
ghci>B.cons 85 $ B.pack [80,81,82,84]
Chunk "U" (Chunk "PQRT" Empty)
```
```
Thebytestring modules have a load of functions that are analogous to
those inData.List, including, but not limited to,head,tail,init,null,length,
map,reverse,foldl,foldr,concat,takeWhile,filter, and so on. For a complete
listing of bytestring functions, check out the documentation for the byte-
string package at http://hackage.haskell.org/package/bytestring/.
The bytestring modules also have functions that have the same name
and behave the same as some functions found inSystem.IO, butStringsare
replaced withByteStrings. For instance, thereadFilefunction inSystem.IOhas
this type:
```
```
readFile:: FilePath -> IO String
```
```
ThereadFilefunctionfrom the bytestring modules has the following type:
```
```
readFile:: FilePath -> IO ByteString
```
**NOTE** _Ifyou’re using strict bytestrings and you attempt to read a file, all of that file will be
read into memory at once! With lazy bytestrings, the file will be read in neat chunks._

## Copying Files with Bytestrings.............................................

```
Let’s make a program that takes two filenames as command-line arguments
and copies the first file into the second file. Note thatSystem.Directoryal-
ready has a function calledcopyFile, but we’re going to implement our own
file-copying function and program anyway. Here’s the code:
```
```
importSystem.Environment
import System.Directory
import System.IO
import Control.Exception
import qualified Data.ByteString.Lazy as B
```
```
main = do
(fileName1:fileName2:_) <- getArgs
copy fileName1 fileName2
```
```
copy source dest = do
contents <- B.readFile source
bracketOnError
(openTempFile "." "temp")
(\(tempName, tempHandle) -> do
hClose tempHandle
removeFile tempName)
(\(tempName, tempHandle) -> do
```
```
More Input and More Output 201
```

```
B.hPutStrtempHandle contents
hClose tempHandle
renameFile tempName dest)
```
```
Tobegin, inmain, we just get the command-line arguments and call
ourcopyfunction, which is where the magic happens. One way to do this
would be to just read from one file and write to another. But if something
goes wrong (such as we don’t have enough disk space to copy the file), we’ll
be left with a messed-up file. So we’ll write to a temporary file first. Then if
something goes wrong, we can just delete that file.
First, we useB.readFileto read the contents of our source file. Then we
usebracketOnErrorto set up our error handling. We acquire the resource
withopenTempFile "." "temp", which yields a tuple that consists of a tempo-
rary filename and a handle. Next, we say what we want to happen if an error
occurs. If something goes wrong, we close the handle and remove the tem-
porary file. Finally, we do the copying itself. We useB.hPutStrto write the
contents to our temporary file. We close the temporary file and rename it
to what we want it to be in the end.
Notice that we just usedB.readFileandB.hPutStrinstead of their reg-
ular variants. We didn’t need to use special bytestring functions for open-
ing, closing, and renaming files. We just need to use the bytestring functions
when reading and writing.
Let’s test it:
```
```
$./bytestringcopy bart.txt bort.txt
```
```
Aprogram that doesn’t use bytestrings could look just like this. The only
difference is that we usedB.readFileandB.writeFileinstead ofreadFileand
writeFile.
Many times, you can convert a program that uses normal strings to a
program that uses bytestrings just by doing the necessary imports and then
putting the qualified module names in front of some functions. Sometimes,
you need to convert functions that you wrote to work on strings so that they
work on bytestrings, but that’s not hard.
Whenever you need better performance in a program that reads a lot
of data into strings, give bytestrings a try. Chances are you’ll get some good
performance boosts with very little effort on your part. I usually write pro-
grams using normal strings and then convert them to use bytestrings if the
performance is not satisfactory.
```
**202** Chapter 9


# 10

## FUNCTIONALLY SOLVING PROBLEMS

```
In this chapter, we’ll look at a couple of interesting
problems, and we’ll think about how to solve them as
elegantly as possible using functional programming
techniques. This will give you the opportunity to flex
your newly acquired Haskell muscles and practice your
coding skills.
```
## Reverse Polish Notation Calculator.................................................

```
Usually, when we work with algebraic expressions in school, we write them
in an infix manner. For instance, we write10 - (4 + 3)* 2. Addition (+),
multiplication (*), and subtraction (-) are infix operators, just like the in-
fix functions in Haskell (+ `elem`, and so on). As humans, we can parse this
form easily in our minds. The downside is that we need to use parentheses
to denote precedence.
Another way to write algebraic expressions is to use reverse polish nota-
tion , or RPN. In RPN, the operator comes after the numbers, rather than
being sandwiched between them. So, instead of writing4+3, we write43+.
But how do we write expressions that contain several operators? For exam-
ple, how would we write an expression that adds 4 and 3 and then multiplies
```

```
thatby 10? It’s simple:4 3 + 10*. Because43+is equivalent to 7 , that whole
expression is the same as7 10*.
```
## Calculating RPN Expressions..............................................

```
To get a feel for how to calculate RPN expressions, think of a stack of num-
bers. We go over the expression from left to right. Every time a number is
encountered, put it on top of the stack ( push it onto the stack). When we en-
counter an operator, we take the two numbers that are on top of the stack
( pop them), use the operator with those two, and then push the resulting
number back onto the stack. When we reach the end of the expression, we
should be left with a single number that represents the result (assuming the
expression was well formed).
Let’s see how we would calculate the RPN expression10 4 3 + 2*-:
```
1. We push 10 onto the stack, so the stack consists of 10.
2. The next item is 4 , so we push it onto the stack as well. The stack is now
    10, 4.
3. We do the same with 3 , and the stack is now10, 4, 3.
4. We encounter an operator:+. We pop the two top numbers from the
    stack (so now the stack is just 10 ), add those numbers together, and push
    that result to the stack. The stack is now10, 7.
5. We push 2 to the stack, and the stack becomes10, 7, 2.
6. We encounter another operator. We pop 7 and 2 off the stack, multiply
    them, and push that result to the stack. Multiplying 7 and 2 produces 14 ,
    so the stack is now10, 14.
7. Finally, there’s a-. We pop 10 and 14 from the stack, subtract 14 from 10 ,
    and push that back.
8. The number on the stack is now-4. Because there are no more numbers
    or operators in our expression, that’s our result!

```
So,that’s how to calculate an RPN expression by hand. Now let’s think
about how to make a Haskell function to do the same thing.
```
**204** Chapter 10


## Writing an RPN Function.................................................

```
Our function will take a string that contains an RPN expression as its param-
eter (like"10 4 3 + 2*-") and give us back that expression’s result.
What would the type of that function be? We want it to take a string as
a parameter and produce a number as its result. Let’s say that we want the
result to be a floating-point number of double precision, because we want to
include division as well. So its type will probably be something like this:
```
```
solveRPN:: String -> Double
```
**NOTE** _Itreally helps to first think what the type declaration of a function should be before
dealing with the implementation. In Haskell, a function’s type declaration tells you a
whole lot about the function, due to the very strong type system._

```
Whenimplementing a solution to a
problem in Haskell, it can be helpful to
consider how you did it by hand. For our
RPN expression calculation, we treated
every number or operator that was sep-
arated by a space as a single item. So it
might help us if we start by breaking a
string like"10 4 3 + 2*-"into a list of
items, like this:
```
```
["10","4","3","+","2","*","-"].
```
```
Nextup, what did we do with that list
of items in our head? We went over it from left to right and kept a stack as
we did that. Does that process remind you of anything? In “I Fold You So”
on page 73, you saw that pretty much any function where you traverse a list
element by element, and build up ( accumulate ) some result—whether it’s a
number, a list, a stack, or something else—can be implemented with a fold.
In this case, we’re going to use a left fold, because we go over the list
from left to right. The accumulator value will be our stack, so the result
from the fold will also be a stack (though as we’ve seen, it will contain only
one item).
One more thing to think about is how we will represent the stack. Let’s
use a list and keep the top of our stack at the head of the list. Adding to the
head (beginning) of a list is much faster than adding to the end of it. So if
we have a stack of, say,10, 4, 3, we’ll represent that as the list[3,4,10].
Now we have enough information to roughly sketch our function. It’s
going to take a string like"10 4 3 + 2*-"and break it down into a list of
items by usingwords. Next, we’ll do a left fold over that list and end up with
a stack that has a single item (in this example,[-4]). We take that single
item out of the list, and that’s our final result!
```
```
Functionally Solving Problems 205
```

```
Here’sa sketch of that function:
```
```
solveRPN:: String -> Double
solveRPN expression = head (foldl foldingFunction [] (words expression))
where foldingFunction stack item = ...
```
```
Wetake the expression and turn it into a list of items. Then we fold over
that list of items with the folding function. Notice the[], which represents
the starting accumulator. The accumulator is our stack, so[]represents an
empty stack, which is what we start with. After getting the final stack with a
single item, we applyheadto that list to get the item out.
All that’s left now is to implement a folding function that will take a
stack, like[4,10], and an item, like"3", and return a new stack[3,4,10]. If the
stack is[4,10]and the item is"*", then the function will need to return[40].
Before we write the folding function, let’s turn our function into point-
free style, because it has a lot of parentheses that are kind of freaking me out:
```
```
solveRPN:: String -> Double
solveRPN = head. foldl foldingFunction []. words
where foldingFunction stack item = ...
```
```
That’smuch better.
The folding function will take a stack and an item and return a new
stack. We’ll use pattern matching to get the top items of a stack and to pat-
tern match against operators like"*"and"-". Here it is with the folding
function implemented:
```
```
solveRPN:: String -> Double
solveRPN = head. foldl foldingFunction []. words
where foldingFunction (x:y:ys) "*" = (y*x):ys
foldingFunction (x:y:ys) "+" = (y + x):ys
foldingFunction (x:y:ys) "-" = (y - x):ys
foldingFunction xs numberString = read numberString:xs
```
```
Welaid this out as four patterns. The patterns will be tried from top
to bottom. First, the folding function will see if the current item is"*". If
it is, then it will take a list like[3,4,9,3]and name its first two elementsx
andy, respectively. So in this case,xwould be 3 , andywould be 4 .yswould
be[9,3]. It will return a list that’s just likeys, but withxandymultiplied
as its head. With this, we pop the two topmost numbers off the stack, mul-
tiply them, and push the result back onto the stack. If the item is not"*",
the pattern matching will fall through,"+"will be checked, and so on.
If the item is none of the operators, we assume it’s a string that repre-
sents a number. If it’s a number, we just applyreadto that string to get a
number from it and return the previous stack but with that number pushed
to the top.
For the list of items["2","3","+"], our function will start folding from the
left. The initial stack will be[]. It will call the folding function with[]as the
```
**206** Chapter 10


stack(accumulator) and"2"as the item. Because that item is not an opera-
tor, it will be read and then added to the beginning of[]. So the new stack
is now[2]. The folding function will be called with[2]as the stack and"3"as
the item, producing a new stack of[3,2]. Then it’s called for the third time
with[3,2]as the stack and"+"as the item. This causes these two numbers to
be popped off the stack, added together, and pushed back. The final stack is
[5], which is the number that we return.
Let’s play around with our function:

ghci>solveRPN "10 4 3 + 2*-"
-4.0
ghci> solveRPN "2 3.5 +"
5.5
ghci> solveRPN "90 34 12 33 55 66 +*- +"
-3947.0
ghci> solveRPN "90 34 12 33 55 66 +*- + -"
4037.0
ghci> solveRPN "90 3.8 -"
86.2

```
Cool,it works!
```
## Adding More Operators..................................................

One nice thing about this solution is that it can be easily modified to sup-
port various other operators. They don’t even need to be binary operators.
For instance, we can make an operator"log"that just pops one number off
the stack and pushes back its logarithm. We can also make operators that
operate on several numbers, like"sum", which pops off all the numbers and
pushes back their sum.
Let’s modify our function to accept a few more operators.

solveRPN:: String -> Double
solveRPN = head. foldl foldingFunction []. words
where foldingFunction (x:y:ys) "*" = (y*x):ys
foldingFunction (x:y:ys) "+" = (y + x):ys
foldingFunction (x:y:ys) "-" = (y - x):ys
foldingFunction (x:y:ys) "/" = (y / x):ys
foldingFunction (x:y:ys) "^" = (y**x):ys
foldingFunction (x:xs) "ln" = log x:xs
foldingFunction xs "sum" = [sum xs]
foldingFunction xs numberString = read numberString:xs

The/isdivision, of course, and**is exponentiation. With the logarithm
operator, we just pattern match against a single element and the rest of the
stack, because we need only one element to perform its natural logarithm.
With the sum operator, we return a stack that has only one element, which is
the sum of the stack so far.

```
Functionally Solving Problems 207
```

```
ghci> solveRPN "2.7ln"
0.9932517730102834
ghci> solveRPN "10 10 10 10 sum 4 /"
10.0
ghci> solveRPN "10 10 10 10 10 sum 4 /"
12.5
ghci> solveRPN "10 2 ^"
100.0
```
```
I think thatmaking a function that can calculate arbitrary floating-point
RPN expressions and has the option to be easily extended in 10 lines is pretty
awesome.
```
```
NOTE This RPN calculation solution is not really fault tolerant. When given input that
doesn’t make sense, it might result in a runtime error. But don’t worry, you’ll learn
how to make this function more robust in Chapter 14.
```
## Heathrow to London..............................................................

```
Suppose that we’re on a business trip. Our plane has just landed in England,
and we rent a car. We have a meeting really soon, and we need to get from
Heathrow Airport to London as fast as we can (but safely!).
There are two main roads going from Heathrow to London, and a num-
ber of regional roads cross them. It takes a fixed amount of time to travel
from one crossroad to another. It’s up to us to find the optimal path to take
so that we get to our meeting in London on time. We start on the left side
and can either cross to the other main road or go forward.
```
```
As you cansee in the picture, the quickest path from Heathrow to Lon-
don in this case is to start on main road B, cross over, go forward on A, cross
over again, and then go forward twice on B. If we take this path, it takes us
75 minutes. Had we chosen any other path, it would take longer.
```
**208** Chapter 10


Ourjob is to make a program that takes input that represents a road sys-
tem and prints out the quickest path across it. Here’s what the input would
look like for this case:

50
10
30
5
90
20
40
2
25
10
8
0

Tomentally parse the input file, read it in threes and mentally split the
road system into sections. Each section is composed of roadA, roadB, and a
crossing road. To have it neatly fit into threes, we say that there’s a last cross-
ing section that takes 0 minutes to drive over. That’s because we don’t care
where we arrive in London, as long as we’re in London, mate!
Just as we did when considering the RPN calculator problem, we’ll solve
this problem in three steps:

1. Forget Haskell for a minute and think about how to solve the problem
    by hand. In the RPN calculator section, we first figured out that when
    calculating an expression by hand, we keep a sort of stack in our minds
    and then go over the expression one item at a time.
2. Think about how we’re going to represent our data in Haskell. For
    our RPN calculator, we decided to use a list of strings to represent our
    expression.
3. Figure out how to operate on that data in Haskell so that we produce a
    solution. For the calculator, we used a left fold to walk over the list of
    strings, while keeping a stack to produce a solution.

## Calculating the Quickest Path.............................................

So how do we figure out the quickest path from Heathrow to London by
hand? Well, we can just look at the whole picture and try to guess what the
quickest path is and hope our guess is correct. That solution works for very
small inputs, but what if we have a road that has 10,000 sections? Yikes! We
also won’t be able to say for certain that our solution is the optimal one; we
can just say that we’re pretty sure. So, that’s not a good solution.

```
Functionally Solving Problems 209
```

```
Here’sa simplified picture of our road system:
```
```
Canwe figure out the quickest path to the first crossroads (the first dot
onA, markedA1) on roadA? That’s pretty trivial. We just see if it’s faster to
go directly forward onAor to go forward onBand then cross over. Obvi-
ously, it’s faster to go forward viaBand then cross over, because that takes
40 minutes, whereas going directly viaAtakes 50 minutes. What about cross-
roadsB1? We see that it’s a lot faster to just go directly viaB(incurring a cost
of 10 minutes), because going viaAand then crossing over would take us 80
minutes!
Now we know the quickest path toA1: Go viaBand then cross over. We’ll
say that’s pathB, Cwith a cost of 40 minutes. We also know the quickest path
toB1: Go directly viaB. So that’s a path consisting just ofBfor 10 minutes.
Does this knowledge help us at all if we want to know the quickest path to
the next crossroads on both main roads? Gee golly, it sure does!
Let’s see what the quickest path toA2would be. To get toA2, we’ll either
go directly toA2fromA1or we’ll go forward fromB1and then cross over (re-
member that we can only move forward or cross to the other side). And be-
cause we know the cost toA1andB1, we can easily figure out the best path to
A2. It takes us 40 minutes to get toA1and then 5 minutes to get fromA1to
A2, so that’s pathB, C, A, for a cost of 45. It takes us only 10 minutes to get
toB1, but then it would take an additional 110 minutes to go toB2and then
cross over! So obviously, the quickest path toA2isB, C, A. In the same way,
the quickest way toB2is to go forward fromA1and then cross over.
```
```
NOTE Maybe you’re asking yourself, “But what about getting toA2by first crossing over at
B1and then going forward?” Well, we already covered crossing fromB1toA1when we
were looking for the best way toA1, so we don’t need to take that into account in the
next step as well.
```
```
Now that we have the best path toA2andB2, we can repeat this until we
reach the end. Once we have calculated the best paths forA4andB4, the one
that takes less time is the optimal path.
So in essence, for the second section, we just repeat the step we did at
first, but we take into account the previous best paths onAandB. We could
say that we also took into account the best paths onAand onBin the first
step—they were both empty paths with a cost of 0 minutes.
```
**210** Chapter 10


```
Insummary, to get the best path from Heathrow to London, we do this:
```
1. We see what the best path to the next crossroads on main roadAis. The
    two options are going directly forward or starting at the opposite road,
    going forward and then crossing over. We remember the cost and
    the path.
2. We use the same method to find the best path to the next crossroads on
    main roadBand remember that.
3. We see if the path to the next crossroads onAtakes less time if we go
    from the previousAcrossroads or if we go from the previousBcrossroads
    and then cross over. We remember the quicker path. We do the same
    for the crossroads opposite of it.
4. We do this for every section until we reach the end.
5. Once we’ve reached the end, the quicker of the two paths that we have
    is our optimal path.

So, in essence, we keep one quickest path on theAroad and one quick-
est path on theBroad. When we reach the end, the quicker of those two is
our path.
We now know how to figure out the quickest path by hand. If you had
enough time, paper, and pencils, you could figure out the quickest path
through a road system with any number of sections.

## Representing the Road System in Haskell...................................

How do we represent this road system with Haskell’s data types?
Thinking back to our solution by hand, we checked the durations of
three road parts at once: the road part on theAroad, its opposite part on
theBroad, and partC, which touches those two parts and connects them.
When we were looking for the quickest path toA1andB1, we dealt with the
durations of only the first three parts, which were 50, 10, and 30. We’ll call
that one section. So the road system that we use for this example can be eas-
ily represented as four sections:

- 50, 10, 30
- 5, 90, 20
- 40, 2, 25
- 10, 8, 0

It’s always good to keep our data types as simple as possible (although
not any simpler!). Here’s the data type for our road system:

dataSection = Section { getA :: Int, getB :: Int, getC :: Int }
deriving (Show)

type RoadSystem = [Section]

```
Functionally Solving Problems 211
```

```
Thisis as simple as it gets, and I have a feeling it will work perfectly for
implementing our solution.
Sectionis a simple algebraic data type that holds three integers for the
durations of its three road parts. We introduce a type synonym as well, say-
ing thatRoadSystemis a list of sections.
```
```
NOTE We could also use a triple of(Int, Int, Int)to represent a road section. Using tuples
instead of making your own algebraic data types is good for some small, localized stuff,
but it’s usually better to make a new type for more complex representations. It gives
the type system more information about what’s what. We can use(Int, Int, Int)to
represent a road section or a vector in 3D space, and we can operate on those two, but
that allows us to mix them up. If we useSectionandVectordata types, then we can’t
accidentally add a vector to a section of a road system.
```
```
Our road system from Heathrow to London can now be represented
like this:
```
```
heathrowToLondon:: RoadSystem
heathrowToLondon = [ Section 50 10 30
, Section 5 90 20
, Section 40 2 25
, Section 10 8 0
]
```
```
Allwe need to do now is implement the solution in Haskell.
```
## Writing the Optimal Path Function.........................................

```
What should the type declaration for a function that calculates the quickest
path for any given road system be? It should take a road system as a parame-
ter and return a path. We’ll represent a path as a list as well.
Let’s introduce aLabeltype that’s just an enumeration ofA,B, orC. We’ll
also make a type synonym calledPath.
```
```
dataLabel = A | B | C deriving (Show)
type Path = [(Label, Int)]
```
```
Ourfunction, which we’ll calloptimalPath, should have the following type:
```
```
optimalPath:: RoadSystem -> Path
```
```
Ifcalled with the road systemheathrowToLondon, it should return the fol-
lowing path:
```
```
[(B,10),(C,30),(A,5),(C,20),(B,2),(B,8)]
```
```
We’regoing to need to walk over the list with the sections from left to
right and keep the optimal path onAand optimal path onBas we go along.
```
**212** Chapter 10


We’llaccumulate the best path as we walk over the list, left to right. What
does that sound like? Ding, ding, ding! That’s right, a _left fold_!
When doing the solution by hand, there was a step that we repeated
over and over. It involved checking the optimal paths onAandBso far and
the current section to produce the new optimal paths onAandB. For in-
stance, at the beginning, the optimal paths were[]and[]forAandB, re-
spectively. We examined the sectionSection 50 10 30and concluded that
the new optimal path toA1was[(B,10),(C,30)]and the optimal path toB1
was[(B,10)]. If you look at this step as a function, it takes a pair of paths
and a section and produces a new pair of paths. So its type is this:

roadStep:: (Path, Path) -> Section -> (Path, Path)

```
Let’simplement this function, because it’s bound to be useful:
```
roadStep:: (Path, Path) -> Section -> (Path, Path)
roadStep (pathA, pathB) (Section a b c) =
let timeA = sum (map snd pathA)
timeB = sum (map snd pathB)
forwardTimeToA = timeA + a
crossTimeToA = timeB + b + c
forwardTimeToB = timeB + b
crossTimeToB = timeA + a + c
newPathToA = if forwardTimeToA <= crossTimeToA
then (A, a):pathA
else (C, c):(B, b):pathB
newPathToB = if forwardTimeToB <= crossTimeToB
then (B, b):pathB
else (C, c):(A, a):pathA
in (newPathToA, newPathToB)

What’sgoing on here? First, we cal-
culate the optimal time on road A based
on the best so far onA, and we do the
same forB. We dosum (map snd pathA), so
ifpathAis something like[(A,100),(C,20)],
timeAbecomes 120.
forwardTimeToAis the time that it
would take to get to the next crossroads
onAif we went there directly from the
previous crossroads onA. It equals the
best time to our previousAplus the dura-
tion of theApart of the current section.
crossTimeToAis the time that it would take if we went to the nextAby go-
ing forward from the previousBand then crossing over. It’s the best time to
the previousBso far plus theBduration of the section plus theCduration of
the section.
We determineforwardTimeToBandcrossTimeToBin the same manner.

```
Functionally Solving Problems 213
```

```
Nowthat we know the best way toAandB, we just need to make the new
paths toAandBbased on that. If it’s quicker to go toAby just going forward,
we setnewPathToAto be(A, a):pathA. Basically, we prepend theLabel Aand the
section durationato the optimal path onAso far. We say that the best path
to the nextAcrossroads is the path to the previousAcrossroads and then one
section forward viaA. Remember thatAis just a label, whereasahas a type
ofInt.
Why do we prepend instead of doingpathA ++ [(A, a)]? Well, adding an
element to the beginning of a list is much faster than adding it to the end.
This means that the path will be the wrong way around once we fold over a
list with this function, but it’s easy to reverse the list later.
If it’s quicker to get to the nextAcrossroads by going forward from road
Band then crossing over,newPathToAis the old path toBthat then goes for-
ward and crosses toA. We do the same thing fornewPathToB, except that every-
thing is mirrored.
Finally, we returnnewPathToAandnewPathToBin a pair.
Let’s run this function on the first section ofheathrowToLondon. Because
it’s the first section, the best paths onAandBparameter will be a pair of
empty lists.
```
```
ghci>roadStep ([], []) (head heathrowToLondon)
([(C,30),(B,10)],[(B,10)])
```
```
Rememberthat the paths are reversed, so read them from right to left.
From this, we can read that the best path to the nextAis to start onBand
then cross over toA. The best path to the nextBis to just go directly forward
from the starting point atB.
```
```
NOTE When we dotimeA = sum (map snd pathA), we’re calculating the time from the path on
every step. We wouldn’t need to do that if we implementedroadStepto take and return
the best times onAandB, along with the paths themselves.
```
```
Now that we have a function that takes a pair of paths and a section, and
produces a new optimal path, we can easily do a left fold over a list of sec-
tions.roadStepis called with([], [])and the first section, and returns a pair
of optimal paths to that section. Then it’s called with that pair of paths and
the next section, and so on. When we’ve walked over all the sections, we’re
left with a pair of optimal paths, and the shorter of them is our answer. With
this in mind, we can implementoptimalPath:
```
```
optimalPath:: RoadSystem -> Path
optimalPath roadSystem =
let (bestAPath, bestBPath) = foldl roadStep ([], []) roadSystem
in if sum (map snd bestAPath) <= sum (map snd bestBPath)
then reverse bestAPath
else reverse bestBPath
```
**214** Chapter 10


Weleft fold overroadSystem(remember that it’s a list of sections) with
the starting accumulator being a pair of empty paths. The result of that fold
is a pair of paths, so we pattern match on the pair to get the paths themselves.
Then we check which one of these was quicker and return it. Before return-
ing it, we also reverse it, because the optimal paths so far were reversed due
to us choosing prepending over appending.
Let’s test this!

ghci>optimalPath heathrowToLondon
[(B,10),(C,30),(A,5),(C,20),(B,2),(B,8),(C,0)]

Thisis the result that we were supposed to get! It differs from our ex-
pected result a bit, because there’s a step(C,0)at the end, which means that
we cross over to the other road once we’re in London. But because that
crossing doesn’t take any time, this is still the correct result.

## Getting a Road System from the Input......................................

We have the function that finds an optimal path, so now we just need to read
a textual representation of a road system from the standard input, convert
it into a type ofRoadSystem, run that through ouroptimalPathfunction, and
print the resulting path.
First, let’s make a function that takes a list and splits it into groups of the
same size. We’ll call itgroupsOf:

groupsOf:: Int -> [a] -> [[a]]
groupsOf 0 _ = undefined
groupsOf _ [] = []
groupsOf n xs = take n xs : groupsOf n (drop n xs)

```
Fora parameter of[1..10],groupsOf 3should result in the following:
```
[[1,2,3],[4,5,6],[7,8,9],[10]]

Asyou can see, it’s a standard recursive function. DoinggroupsOf 3 [1..10]
equals the following:

[1,2,3]: groupsOf 3 [4,5,6,7,8,9,10]

Whenthe recursion is done, we get our list in groups of three. And
here’s our main function, which reads from the standard input, makes a
RoadSystemout of it, and prints out the shortest path:

importData.List

main = do
contents <- getContents
let threes = groupsOf 3 (map read $ lines contents)

```
Functionally Solving Problems 215
```

```
roadSystem= map (\[a,b,c] -> Section a b c) threes
path = optimalPath roadSystem
pathString = concat $ map (show. fst) path
pathTime = sum $ map snd path
putStrLn $ "The best path to take is: " ++ pathString
putStrLn $ "Time taken: " ++ show pathTime
```
```
First,we get all the contents from the standard input. Then we apply
linesto our contents to convert something like"50\n10\n30\n ...to some-
thing cleaner, like["50","10","30" .... We then mapreadover that to convert
it to a list of numbers. We applygroupsOf 3to it so that we turn it to a list of
lists of length 3. We map the lambda(\[a,b,c] -> Section a b c)over that list
of lists.
As you can see, the lambda just takes a list of length 3 and turns it into a
section. SoroadSystemis now our system of roads, and it even has the correct
type:RoadSystem(or[Section]). We applyoptimalPathto that, get the path and
the total time in a nice textual representation, and print it out.
We save the following text in a file called paths.txt :
```
```
50
10
30
5
90
20
40
2
25
10
8
0
```
```
Thenwe feed it to our program like so:
```
```
$runhaskell heathrow.hs < paths.txt
The best path to take is: BCACBBC
Time taken: 75
```
```
Workslike a charm!
You can use your knowledge of theData.Randommodule to generate a
much longer system of roads, which you can then feed to the code we just
wrote. If you get stack overflows, you can changefoldltofoldl'andsumto
foldl' (+) 0. Alternatively, try compiling it like this before running it:
```
```
$ghc --make -O heathrow.hs
```
```
IncludingtheOflag turns on optimizations that help prevent functions
such asfoldlandsumfrom causing stack overflows.
```
**216** Chapter 10


# 11

## APPLICATIVE FUNCTORS

Haskell’s combination of purity, higher-order func-

tions, parameterized algebraic data types, and type

classes makes implementing polymorphism much eas-

ier than in other languages. We don’t need to think

about types belonging to a big hierarchy. Instead, we

consider what the types can act like and then connect

them with the appropriate type classes. AnIntcan act

like a lot of things—an equatable thing, an ordered

thing, an enumerable thing, and so on.

Type classes are open, which means that we can define our own data
type, think about what it can act like, and connect it with the type classes
that define its behaviors. We can also introduce a new type class and then
make already existing types instances of it. Because of that, and because
Haskell’s type system allows us to know a lot about a function just by its type
declaration, we can define type classes that define very general and abstract
behavior.
We’ve talked about type classes that define operations for seeing if two
things are equal and comparing two things by some ordering. Those are very
abstract and elegant behaviors, although we don’t think of them as very spe-
cial, since we’ve been dealing with them for most of our lives. Chapter 7


```
introducedfunctors, which are types whose values can be mapped over.
That’s an example of a useful and yet still pretty abstract property that type
classes can describe. In this chapter, we’ll take a closer look at functors,
along with slightly stronger and more useful versions of functors called
applicative functors.
```
## Functors Redux...................................................................

```
As you learned in Chapter 7, functors are things that can be mapped over,
like lists,Maybes, and trees. In Haskell, they’re described by the type class
Functor, which has only one type class method:fmap.fmaphas a type of
fmap :: (a -> b) -> f a -> f b, which says, “Give me a function that takes
anaand returns aband a box with ana(or several of them) inside it, and
I’ll give you a box with ab(or several of them) inside it.” It applies the func-
tion to the element inside the box.
We can also look at functor values as values with an added context. For in-
stance,Maybevalues have the extra context that they might have failed. With
lists, the context is that the value can actually be several values at once or
none.fmapapplies a function to the value while preserving its context.
If we want to make a type constructor an instance ofFunctor, it must
have a kind of*->*, which means that it takes exactly one concrete type
as a type parameter. For example,Maybecan be made an instance because
it takes one type parameter to produce a concrete type, likeMaybe Intor
Maybe String. If a type constructor takes two parameters, likeEither, we
need to partially apply the type constructor until it takes only one type pa-
rameter. So we can’t writeinstance Functor Either where, but we can write
instance Functor (Either a) where. Then if we imagine thatfmapis only for
Either a, it would have this type declaration:
```
```
fmap:: (b -> c) -> Either a b -> Either a c
```
```
Asyou can see, theEither apart is fixed, becauseEither atakes only one
type parameter.
```
## I/O Actions As Functors..................................................

```
You’ve learned how a lot of types (well, type constructors really) are
instances ofFunctor:[], andMaybe,Either a, as well as aTreetype that we
created in Chapter 7. You saw how you can map functions over them for
great good. Now, let’s take a look at theIOinstance.
If some value has a type of, say,IO String, that means it’s an I/O ac-
tion that will go out into the real world and get some string for us, which it
will then yield as a result. We can use<-indosyntax to bind that result to a
name. In Chapter 8, we talked about how I/O actions are like boxes with
little feet that go out and fetch some value from the outside world for us.
We can inspect what they fetched, but after inspecting, we need to wrap the
```
**218** Chapter 11


valueback inIO. Considering this box with feet analogy, you can see howIO
acts like a functor.
Let’s see howIOis an instance ofFunctor. When wefmapa function over
an I/O action, we want to get back an I/O action that does the same thing
but has our function applied over its result value. Here’s the code:

instanceFunctor IO where
fmap f action = do
result <- action
return (f result)

Theresult of mapping something over an I/O action will be an I/O ac-
tion, so right off the bat, we use thedosyntax to glue two actions and make
a new one. In the implementation forfmap, we make a new I/O action that
first performs the original I/O action and calls its resultresult. Then we do
return (f result). Recall thatreturnis a function that makes an I/O action
that doesn’t do anything but only yields something as its result.
The action that adoblock produces will always yield the result value of
its last action. That’s why we usereturnto make an I/O action that doesn’t
really do anything; it just yieldsf resultas the result of the new I/O action.
Check out this piece of code:

main= do line <- getLine
let line' = reverse line
putStrLn $ "You said " ++ line' ++ " backwards!"
putStrLn $ "Yes, you said " ++ line' ++ " backwards!"

Theuser is prompted for a line, which we give back, but reversed. Here’s
how to rewrite this by usingfmap:

main= do line <- fmap reverse getLine
putStrLn $ "You said " ++ line ++ " backwards!"
putStrLn $ "Yes, you really said " ++ line ++ " backwards!"

Justas we canfmap reverseoverJust
"blah"to getJust "halb", we canfmap reverse
overgetLine.getLineis an I/O action that
has a type ofIO String, and mappingreverse
over it gives us an I/O action that will go
out into the real world and get a line and
then applyreverseto its result. In the same
way that we can apply a function to some-
thing that’s inside aMaybebox, we can apply
a function to what’s inside anIObox, but it
must go out into the real world to get some-
thing. Then when we bind it to a name using<-. The name will reflect the
result that already hasreverseapplied to it.

```
Applicative Functors 219
```

```
TheI/O actionfmap (++"!") getLinebehaves just likegetLine, except that
its result always has"!"appended to it!
Iffmapwere limited toIO, its type would befmap :: (a -> b) -> IO a ->
IO b.fmaptakes a function and an I/O action and returns a new I/O action
that’s like the old one, except that the function is applied to its contained
result.
If you ever find yourself binding the result of an I/O action to a name,
only to apply a function to that and call that something else, consider using
fmap. If you want to apply multiple functions to some data inside a functor,
you can declare your own function at the top level, make a lambda function,
or, ideally, use function composition:
```
```
importData.Char
import Data.List
```
```
main = do line <- fmap (intersperse '-'. reverse. map toUpper) getLine
putStrLn line
```
```
Here’swhat happens if we run this with the inputhello there:
```
```
$./fmapping_io
hello there
E-R-E-H-T- -O-L-L-E-H
```
```
Theintersperse'-'. reverse. map toUpperfunction takes a string, maps
toUpperover it, appliesreverseto that result, and then appliesintersperse '-'
to that result. It’s a prettier way of writing the following:
```
```
(\xs-> intersperse '-' (reverse (map toUpper xs)))
```
## Functions As Functors.....................................................

```
Another instance ofFunctorthat we’ve been dealing with all along is(->) r.
But wait! What the heck does(->) rmean? The function typer -> acan be
rewritten as(->) r a, much like we can write2+3as(+) 2 3. When we look
at it as(->) r a, we can see(->)in a slightly different light. It’s just a type
constructor that takes two type parameters, likeEither.
But remember that a type constructor must take exactly one type param-
eter so it can be made an instance ofFunctor. That’s why we can’t make(->)
an instance ofFunctor; however, if we partially apply it to(->) r, it doesn’t
pose any problems. If the syntax allowed for type constructors to be partially
applied with sections (like we can partially apply+by doing(2+), which is the
same as(+) 2), we could write(->) ras(r ->).
How are functions functors? Let’s take a look at the implementation,
which lies inControl.Monad.Instances:
```
```
instanceFunctor ((->) r) where
fmap f g = (\x -> f (g x))
```
**220** Chapter 11


```
First,let’s think aboutfmap’s type:
```
fmap:: (a -> b) -> f a -> f b

Next,let’s mentally replace eachf, which is the role that our functor
instance plays, with(->) r. This will let us see howfmapshould behave for
this particular instance. Here’s the result:

fmap:: (a -> b) -> ((->) r a) -> ((->) r b)

Nowwe can write the(->) r aand(->) r btypes as infixr -> aandr -> b,
as we normally do with functions:

fmap:: (a -> b) -> (r -> a) -> (r -> b)

Okay,mapping a function over a function must produce a function, just
like mapping a function over aMaybemust produce aMaybe, and mapping a
function over a list must produce a list. What does the preceding type tell
us? We see that it takes a function fromatoband a function fromrtoaand
returns a function fromrtob. Does this remind you of anything? Yes, func-
tion composition! We pipe the output ofr -> ainto the input ofa -> bto
get a functionr -> b, which is exactly what function composition is all about.
Here’s another way to write this instance:

instanceFunctor ((->) r) where
fmap = (.)

Thismakes it clear that usingfmapover functions is just function com-
position. In a script, importControl.Monad.Instances, since that’s where the
instance is defined, and then load the script and try playing with mapping
over functions:

ghci>:t fmap (*3) (+100)
fmap (*3) (+100) :: (Num a) => a -> a
ghci> fmap (*3) (+100) 1
303
ghci> (*3) `fmap` (+100) $ 1
303
ghci> (*3). (+100) $ 1
303
ghci> fmap (show. (*3)) (+100) 1
"303"

Wecan callfmapas an infix function so that the resemblance to.is clear.
In the second input line, we’re mapping(*3)over(+100), which results in a
function that will take an input, apply(+100)to that, and then apply(*3)to
that result. We then apply that function to 1.

```
Applicative Functors 221
```

```
Justlike all functors, functions can be thought of as values with contexts.
When we have a function like(+3), we can view the value as the eventual re-
sult of the function, and the context is that we need to apply the function to
something to get to the result. Usingfmap (*3)on(+100)will create another
function that acts like(+100), but before producing a result,(*3)will be ap-
plied to that result.
The fact thatfmapis function composition when used on functions isn’t
so terribly useful right now, but at least it’s very interesting. It also bends
our minds a bit and lets us see how things that act more like computations
than boxes (IOand(->) r) can be functors. The function being mapped
over a computation results in the same sort of computation, but the result
of that computation is modified with the function.
Beforewe go on to the rules thatfmap
should follow, let’s think about the type of
fmaponce more:
```
```
fmap:: (Functor f) => (a -> b) -> f a -> f b
```
```
Theintroduction of curried functions
in Chapter 5 began by stating that all Has-
kell functions actually take one parame-
ter. A functiona -> b -> ctakes just one
parameter of typeaand returns a function
b -> c, which takes one parameter and re-
turnsc. That’s why calling a function with
too few parameters (partially applying it) gives us back a function that takes
the number of parameters that we left out (if we’re thinking about func-
tions as taking several parameters again). Soa -> b -> ccan be written as
a -> (b -> c), to make the currying more apparent.
In the same vein, if we writefmap :: (a -> b) -> (f a -> f b), we can
think offmapnot as a function that takes one function and a functor value
and returns a functor value, but as a function that takes a function and re-
turns a new function that’s just like the old one, except that it takes a func-
tor value as a parameter and returns a functor value as the result. It takes
ana -> bfunction and returns a functionf a -> f b. This is called lifting a
function. Let’s play around with that idea using GHCi’s:tcommand:
```
```
ghci>:t fmap (*2)
fmap (*2) :: (Num a, Functor f) => f a -> f a
ghci> :t fmap (replicate 3)
fmap (replicate 3) :: (Functor f) => f a -> f [a]
```
```
Theexpressionfmap (*2)is a function that takes a functorfover num-
bers and returns a functor over numbers. That functor can be a list, aMaybe,
anEither String, or anything else. The expressionfmap (replicate 3)will take
a functor over any type and return a functor over a list of elements of that
type. This is even more apparent if we partially apply, say,fmap (++"!")and
then bind it to a name in GHCi.
```
**222** Chapter 11


```
Youcan think offmapin two ways:
```
- As a function that takes a function and a functor value and then maps
    that function over the functor value
- As a function that takes a function and lifts that function so it operates
    on functor values

```
Both views are correct.
The typefmap (replicate 3) :: (Functor f) => f a -> f [a]means that the
function will work on any functor. What it will do depends on the functor.
If we usefmap (replicate 3)on a list, the list’s implementation forfmapwill
be chosen, which is justmap. If we use it onMaybe a, it will applyreplicate 3
to the value inside theJust. If it’sNothing, it staysNothing. Here are some
examples:
```
```
ghci>fmap (replicate 3) [1,2,3,4]
[[1,1,1],[2,2,2],[3,3,3],[4,4,4]]
ghci> fmap (replicate 3) (Just 4)
Just [4,4,4]
ghci> fmap (replicate 3) (Right "blah")
Right ["blah","blah","blah"]
ghci> fmap (replicate 3) Nothing
Nothing
ghci> fmap (replicate 3) (Left "foo")
Left "foo"
```
## Functor Laws.....................................................................

```
All functors are expected to exhibit certain kinds of properties and behav-
iors. They should reliably behave as things that can be mapped over. Call-
ingfmapon a functor should just map a function over the functor—nothing
more. This behavior is described in the functor laws. All instances ofFunctor
should abide by these two laws. They aren’t enforced by Haskell automat-
ically, so you need to test them yourself when you make a functor. All the
Functorinstances in the standard library obey these laws.
```
## Law 1..................................................................

```
The first functor law states that if we map theidfunction over a functor
value, the functor value that we get back should be the same as the original
functor value. Written a bit more formally, it means thatfmap id = id. So es-
sentially, this says that if we dofmap idover a functor value, it should be the
same as just applyingidto the value. Remember thatidis the identity func-
tion, which just returns its parameter unmodified. It can also be written as
\x -> x. If we view the functor value as something that can be mapped over,
thefmap id = idlaw seems kind of trivial or obvious.
```
```
Applicative Functors 223
```

```
Let’ssee if this law holds for a few values of functors.
```
```
ghci>fmap id (Just 3)
Just 3
ghci> id (Just 3)
Just 3
ghci> fmap id [1..5]
[1,2,3,4,5]
ghci> id [1..5]
[1,2,3,4,5]
ghci> fmap id []
[]
ghci> fmap id Nothing
Nothing
```
```
Lookingat the implementation offmapforMaybe, for example, we can
figure out why the first functor law holds:
```
```
instanceFunctor Maybe where
fmap f (Just x) = Just (f x)
fmap f Nothing = Nothing
```
```
Weimagine thatidplays the role of thefparameter in the implementa-
tion. We see that if wefmap idoverJust x, the result will beJust (id x), and
becauseidjust returns its parameter, we can deduce thatJust (id x)equals
Just x. So now we know that if we mapidover aMaybevalue with aJustvalue
constructor, we get that same value back.
Seeing that mappingidover aNothingvalue returns the same value is
trivial. So from these two equations in the implementation forfmap, we find
that the lawfmap id = idholds.
```
## Law 2..................................................................

```
Thesecond law says that composing two
functions and then mapping the result-
ing function over a functor should be
the same as first mapping one function
over the functor and then mapping the
other one. Formally written, that means
fmap (f. g) = fmap f. fmap g. Or to
write it in another way, for any func-
tor valuex, the following should hold:
fmap (f. g) x = fmap f (fmap g x).
If we can show that some type obeys
both functor laws, we can rely on it hav-
ing the same fundamental behaviors as
other functors when it comes to map-
ping. We can know that when we use
```
**224** Chapter 11


fmapon it, therewon’t be anything other than mapping going on behind the
scenes and that it will act like a thing that can be mapped over—that is, a
functor.
We figure out how the second law holds for some type by looking at the
implementation offmapfor that type and then using the method that we
used to check ifMaybeobeys the first law. So, to check out how the second
functor law holds forMaybe, if we usefmap (f. g)overNothing, we getNothing,
because callingfmapwith any function overNothingreturnsNothing. If we call
fmap f (fmap g Nothing), we getNothing, for the same reason.
Seeing how the second law holds forMaybeif it’s aNothingvalue is pretty
easy. But how about if it’s aJustvalue? Well, if we usefmap (f. g) (Just x),
we see from the implementation that it’s implemented asJust ((f. g) x),
which isJust (f (g x)). If we usefmap f (fmap g (Just x)), we see from the im-
plementation thatfmap g (Just x)isJust (g x). Ergo,fmap f (fmap g (Just x))
equalsfmap f (Just (g x)), and from the implementation, we see that this
equalsJust (f (g x)).
If you’re a bit confused by this proof, don’t worry. Be sure that you un-
derstand how function composition works. Many times, you can intuitively
see how these laws hold because the types act like containers or functions.
You can also just try them on a bunch of different values of a type and be
able to say with some certainty that a type does indeed obey the laws.

## Breaking the Law........................................................

Let’s take a look at a pathological example of a type constructor being an
instance of theFunctortype class but not really being a functor, because it
doesn’t satisfy the laws. Let’s say that we have the following type:

data CMaybe a= CNothing | CJust Int a deriving (Show)

TheChere stands forcounter. It’s a data type that looks much like
Maybe a, but theJustpart holds two fields instead of one. The first field in
theCJustvalue constructor will always have a type ofInt, and it will be some
sort of counter. The second field is of typea, which comes from the type pa-
rameter, and its type will depend on the concrete type that we choose for
CMaybe a. Let’s play with our new type:

ghci> CNothing
CNothing
ghci> CJust0 "haha"
CJust 0 "haha"
ghci> :t CNothing
CNothing :: CMaybe a
ghci> :t CJust 0 "haha"
CJust 0 "haha" :: CMaybe [Char]
ghci> CJust 100 [1,2,3]
CJust 100 [1,2,3]

```
Applicative Functors 225
```

```
Ifwe use theCNothingconstructor, there are no fields. If we use theCJust
constructor, the first field is an integer and the second field can be any type.
Let’s make this an instance ofFunctorso that each time we usefmap, the func-
tion is applied to the second field, whereas the first field is increased by 1.
```
```
instanceFunctor CMaybe where
fmap f CNothing = CNothing
fmap f (CJust counter x) = CJust (counter+1) (f x)
```
```
Thisis kind of like the instance implementation forMaybe, except that
when we dofmapover a value that doesn’t represent an empty box (aCJust
value), we don’t just apply the function to the contents; we also increase the
counter by 1. Everything seems cool so far. We can even play with this a bit:
```
```
ghci>fmap (++"ha") (CJust 0 "ho")
CJust 1 "hoha"
ghci> fmap (++"he") (fmap (++"ha") (CJust 0 "ho"))
CJust 2 "hohahe"
ghci> fmap (++"blah") CNothing
CNothing
```
```
Doesthis obey the functor laws? In order to see that something doesn’t
obey a law, it’s enough to find just one counterexample:
```
```
ghci>fmap id (CJust 0 "haha")
CJust 1 "haha"
ghci> id (CJust 0 "haha")
CJust 0 "haha"
```
```
Asthe first functor law states, if we mapidover a functor value, it should
be the same as just callingidwith the same functor value. Our example dem-
onstrates that this is not true for ourCMaybefunctor. Even though it’s part of
theFunctortype class, it doesn’t obey this functor law and is therefore not a
functor.
SinceCMaybefails at being a functor even though it pretends to be one,
using it as a functor might lead to some faulty code. When we use a func-
tor, it shouldn’t matter if we first compose a few functions and then map
them over the functor value or we just map each function over a functor
value in succession. But withCMaybeit matters, because it keeps track of how
many times it has been mapped over. Not cool! If we wantCMaybeto obey the
functor laws, we need to make it so that theIntfield stays the same when we
usefmap.
At first, the functor laws might seem a bit confusing and unnecessary.
But if we know that a type obeys both laws, we can make certain assump-
tions about how it will act. If a type obeys the functor laws, we know that call-
ingfmapon a value of that type will only map the function over it—nothing
more. This leads to code that is more abstract and extensible, because we
```
**226** Chapter 11


```
canuse laws to reason about behaviors that any functor should have and
make functions that operate reliably on any functor.
The next time you make a type an instance ofFunctor, take a minute to
make sure that it obeys the functor laws. You can go over the implementa-
tion line by line and see if the laws hold or try to find a counterexample.
Once you’ve dealt with enough functors, you will begin to recognize the
properties and behaviors that they have in common, and begin to intuitively
see if a type obeys the functor laws.
```
## Using Applicative Functors........................................................

```
Inthis section, we’ll take a look at ap-
plicative functors, which are beefed-up
functors.
So far, we have focused on mapping
functions that take only one parameter
over functors. But what happens when
we map a function that takes two param-
eters over a functor? Let’s take a look at
a couple of concrete examples of this.
If we haveJust 3and we call
fmap (*) (Just 3), what do we get? From
the instance implementation ofMaybefor
Functor, we know that if it’s aJustvalue, it will apply the function to the value
inside theJust. Therefore, doingfmap (*) (Just 3)results inJust ((*) 3),
which can also be written asJust (3*)if we use sections. Interesting! We get
a function wrapped in aJust!
Here are some more functions inside functor values:
```
```
ghci>:t fmap (++) (Just "hey")
fmap (++) (Just "hey") :: Maybe ([Char] -> [Char])
ghci> :t fmap compare (Just 'a')
fmap compare (Just 'a') :: Maybe (Char -> Ordering)
ghci> :t fmap compare "A LIST OF CHARS"
fmap compare "A LIST OF CHARS" :: [Char -> Ordering]
ghci> :t fmap (\x y z -> x + y / z) [3,4,5,6]
fmap (\x y z -> x + y / z) [3,4,5,6] :: (Fractional a) => [a -> a -> a]
```
```
Ifwe mapcompare, which has a type of(Ord a) => a -> a -> Ordering, over
a list of characters, we get a list of functions of typeChar -> Ordering, because
the functioncomparegets partially applied with the characters in the list. It’s
not a list of(Ord a) => a -> Orderingfunction, because the firstaapplied was
aChar, and so the secondamust decide to be of typeChar.
We see how by mapping “multiparameter” functions over functor val-
ues, we get functor values that contain functions inside them. So now what
can we do with them? For one, we can map functions that take these functions
```
```
Applicative Functors 227
```

```
asparameters over them, because whatever is inside a functor value will be
given to the function that we’re mapping over it as a parameter:
```
```
ghci>let a = fmap (*) [1,2,3,4]
ghci> :t a
a :: [Integer -> Integer]
ghci> fmap (\f -> f 9) a
[9,18,27,36]
```
```
Butwhat if we have a functor value ofJust (3*)and a functor value
ofJust 5, and we want to take out the function fromJust (3*)and map
it overJust 5? With normal functors, we’re out of luck, because they sup-
port only mapping normal functions over existing functors. Even when we
mapped\f -> f 9over a functor that contained functions, we were just map-
ping a normal function over it. But we can’t map a function that’s inside a
functor value over another functor value with whatfmapoffers us. We could
pattern match against theJustconstructor to get the function out of it and
then map it overJust 5, but we’re looking for a more general and abstract
approach that works across functors.
```
## Say Hello to Applicative..................................................

```
Meet theApplicativetype class, in theControl.Applicativemodule. It defines
two functions:pureand<*>. It doesn’t provide a default implementation for
either of them, so we need to define them both if we want something to be
an applicative functor. The class is defined like so:
```
```
class(Functor f) => Applicative f where
pure :: a -> f a
(<*>) :: f (a -> b) -> f a -> f b
```
```
Thissimple three-line class definition tells us a lot! The first line starts
the definition of theApplicativeclass, and it also introduces a class con-
straint. The constraint says that if we want to make a type constructor part
of theApplicativetype class, it must be inFunctorfirst. That’s why if we know
that a type constructor is part of theApplicativetype class, it’s also inFunctor,
so we can usefmapon it.
The first method it defines is calledpure. Its type declaration is
pure :: a -> f a.fplays the role of our applicative functor instance here.
Because Haskell has a very good type system, and because all a function can
do is take some parameters and return some value, we can tell a lot from a
type declaration, and this is no exception.
pureshould take a value of any type and return an applicative value with
that value inside it. “Inside it” refers to our box analogy again, even though
we’ve seen that it doesn’t always stand up to scrutiny. But thea -> f atype
declaration is still pretty descriptive. We take a value and we wrap it in an
applicative value that has that value as the result inside it. A better way of
```
**228** Chapter 11


thinkingaboutpurewould be to say that it takes a value and puts it in some
sort of default (or pure) context—a minimal context that still yields that
value.
The<*>function is really interesting. It has this type declaration:

f(a -> b) -> f a -> f b

Doesthis remind you of anything? It’s likefmap :: (a -> b) -> f a ->
fb. You can think of the<*>function as sort of a beefed-upfmap. Whereas
fmaptakes a function and a functor value and applies the function inside the
functor value,<*>takes a functor value that has a function in it and another
functor, and extracts that function from the first functor and then maps it
over the second one.

## Maybe the Applicative Functor............................................

Let’s take a look at theApplicativeinstance implementation forMaybe:

instanceApplicative Maybe where
pure = Just
Nothing <*> _ = Nothing
(Just f) <*> something = fmap f something

Again,from the class definition, we see that thefthat plays the role
of the applicative functor should take one concrete type as a parameter,
so we writeinstance Applicative Maybe whereinstead ofinstance Applicative
(Maybe a) where.
Next, we havepure. Remember that it’s supposed to take something
and wrap it in an applicative value. We wrotepure = Just, because value
constructors likeJustare normal functions. We could have also written
pure x = Just x.
Finally, we have the definition for<*>. We can’t extract a function out
of aNothing, because it has no function inside it. So we say that if we try to
extract a function from aNothing, the result is aNothing.
In the class definition forApplicative, there’s aFunctorclass constraint,
which means that we can assume that both of the<*>function’s parame-
ters are functor values. If the first parameter is not aNothing, but aJustwith
some function inside it, we say that we then want to map that function over
the second parameter. This also takes care of the case where the second pa-
rameter isNothing, because doingfmapwith any function over aNothingwill
return aNothing. So forMaybe,<*>extracts the function from the left value if
it’s aJustand maps it over the right value. If any of the parameters isNothing,
Nothingis the result.
Now let’s give this a whirl:

ghci>Just (+3) <*> Just 9
Just 12

```
Applicative Functors 229
```

```
ghci>pure (+3) <*> Just 10
Just 13
ghci> pure (+3) <*> Just 9
Just 12
ghci> Just (++"hahah") <*> Nothing
Nothing
ghci> Nothing <*> Just "woot"
Nothing
```
```
Yousee how doingpure (+3)andJust (+3)is the same in this case. Use
pureif you’re dealing withMaybevalues in an applicative context (using them
with<*>); otherwise, stick toJust.
The first four input lines demonstrate how the function is extracted and
then mapped, but in this case, they could have been achieved by just map-
ping unwrapped functions over functors. The last line is interesting, because
we try to extract a function from aNothingand then map it over something,
which results inNothing.
With normal functors, when you map a function over a functor, you
can’t get the result out in any general way, even if the result is a partially ap-
plied function. Applicative functors, on the other hand, allow you to operate
on several functors with a single function.
```
## The Applicative Style.....................................................

```
With theApplicativetype class, we can chain the use of the<*>function, thus
enabling us to seamlessly operate on several applicative values instead of just
one. For instance, check this out:
```
```
ghci>pure (+) <*> Just 3 <*> Just 5
Just 8
ghci> pure (+) <*> Just 3 <*> Nothing
Nothing
ghci> pure (+) <*> Nothing <*> Just 5
Nothing
```
```
Wewrapped the+function inside an applicative
value and then used<*>to call it with two parameters,
both applicative values.
Let’s take a look at how this happens, step by step.
<*>is left-associative, which means that this:
```
```
pure(+) <*> Just 3 <*> Just 5
```
```
isthe same as this:
```
```
(pure(+) <*> Just 3) <*> Just 5
```
**230** Chapter 11


```
First,the+function is put in an applicative value—in this case, aMaybe
value that contains the function. So we havepure (+), which isJust (+). Next,
Just (+) <*> Just 3happens. The result of this isJust (3+). This is because
of partial application. Only applying the+function to 3 results in a function
that takes one parameter and adds 3 to it. Finally,Just (3+) <*> Just 5is car-
ried out, which results in aJust 8.
Isn’t this awesome? Applicative functors and the applicative style of
pure f <*>x<*>y<*> ...allow us to take a function that expects parame-
ters that aren’t applicative values and use that function to operate on several
applicative values. The function can take as many parameters as we want,
because it’s always partially applied step by step between occurrences of<*>.
This becomes even more handy and apparent if we consider the fact
thatpure f <*>xequalsfmap f x. This is one of the applicative laws. We’ll
take a closer look at the applicative laws later in the chapter, but let’s think
about how it applies here.pureputs a value in a default context. If we just
put a function in a default context and then extract and apply it to a value
inside another applicative functor, that’s the same as just mapping that
function over that applicative functor. Instead of writingpure f <*>x<*>
y<*> ..., we can writefmap f x <*>y<*> .... This is whyControl.Applicative
exports a function called<$>, which is justfmapas an infix operator. Here’s
how it’s defined:
```
```
(<$>):: (Functor f) => (a -> b) -> f a -> f b
f <$> x = fmap f x
```
**NOTE** _Rememberthat type variables are independent of parameter names or other value
names. Thefin the function declaration here is a type variable with a class constraint
saying that any type constructor that replacesfshould be in theFunctortype class.
Thefin the function body denotes a function that we map overx. The fact that we
usedfto represent both of those doesn’t mean that they represent the same thing._

```
By using<$>, the applicative style really shines, because now if we
want to apply a functionfbetween three applicative values, we can write
f <$> x <*>y<*>z. If the parameters were normal values rather than ap-
plicative functors, we would writefxyz.
Let’s take a closer look at how this works. Suppose we want to join the
valuesJust "johntra"andJust "volta"into oneStringinside aMaybefunctor.
We can do this:
```
```
ghci>(++) <$> Just "johntra" <*> Just "volta"
Just "johntravolta"
```
```
Beforewe see how this happens, compare the preceding line with this:
```
```
ghci>(++) "johntra" "volta"
"johntravolta"
```
```
Applicative Functors 231
```

```
Touse a normal function on applicative functors, just sprinkle some<$>
and<*>about, and the function will operate on applicatives and return an
applicative. How cool is that?
Back to our(++) <$> Just "johntra" <*> Just "volta": First(++), which
has a type of(++) :: [a] -> [a] -> [a], is mapped overJust "johntra". This
results in a value that’s the same asJust ("johntra"++)and has a type ofMaybe
([Char] -> [Char]). Notice how the first parameter of(++)got eaten up and
how theas turned intoCharvalues. And nowJust ("johntra"++) <*> Just
"volta"happens, which takes the function out of theJustand maps it over
Just "volta", resulting inJust "johntravolta". Had either of the two values
beenNothing, the result would have also beenNothing.
So far, we’ve used onlyMaybein our examples, and you might be think-
ing that applicative functors are all aboutMaybe. There are loads of other
instances ofApplicative, so let’s meet them!
```
## Lists

```
Lists (actually the list type constructor,[]) are applicative functors. What a
surprise! Here’s how[]is an instance ofApplicative:
```
```
instanceApplicative [] where
pure x = [x]
fs <*> xs = [f x | f <- fs, x <- xs]
```
```
Rememberthatpuretakes a value and puts it in a default context. In
other words, it puts it in a minimal context that still yields that value. The
minimal context for lists would be the empty list, but the empty list repre-
sents the lack of a value, so it can’t hold in itself the value on which we used
pure. That’s whypuretakes a value and puts it in a singleton list. Similarly,
the minimal context for theMaybeapplicative functor would be aNothing, but
it represents the lack of a value instead of a value, sopureis implemented as
Justin the instance implementation forMaybe.
Here’spurein action:
```
```
ghci>pure "Hey" :: [String]
["Hey"]
ghci> pure "Hey" :: Maybe String
Just "Hey"
```
```
Whatabout<*>? If the<*>function’s type were limited to only lists, we
would get(<*>) :: [a -> b] -> [a] -> [b]. It’s implemented with a list com-
prehension.<*>must somehow extract the function out of its left parame-
ter and then map it over the right parameter. But the left list can have zero
functions, one function, or several functions inside it, and the right list can
also hold several values. That’s why we use a list comprehension to draw
from both lists. We apply every possible function from the left list to every
possible value from the right list. The resulting list has every possible combi-
nation of applying a function from the left list to a value in the right one.
```
**232** Chapter 11


```
Wecan use<*>with lists like this:
```
ghci>[(*0),(+100),(^2)] <*> [1,2,3]
[0,0,0,101,102,103,1,4,9]

Theleft list has three functions, and the right list has three values, so the
resulting list will have nine elements. Every function in the left list is applied
to every function in the right one. If we have a list of functions that take two
parameters, we can apply those functions between two lists.
In the following example, we apply two function between two lists:

ghci>[(+),(*)] <*> [1,2] <*> [3,4]
[4,5,5,6,3,4,6,8]

<*>isleft-associative, so[(+),(*)] <*> [1,2]happens first, resulting in a
list that’s the same as[(1+),(2+),(1*),(2*)], because every function on the left
gets applied to every value on the right. Then[(1+),(2+),(1*),(2*)] <*> [3,4]
happens, which produces the final result.
Using the applicative style with lists is fun!

ghci>(++) <$> ["ha","heh","hmm"] <*> ["?","!","."]
["ha?","ha!","ha.","heh?","heh!","heh.","hmm?","hmm!","hmm."]

Again,we used a normal function that takes two strings between two lists
of strings just by inserting the appropriate applicative operators.
You can view lists as nondeterministic computations. A value like 100 or
"what"can be viewed as a deterministic computation that has only one result,
whereas a list like[1,2,3]can be viewed as a computation that can’t decide
on which result it wants to have, so it presents us with all of the possible re-
sults. So when you write something like(+) <$> [1,2,3] <*> [4,5,6], you can
think of it as adding together two nondeterministic computations with+,
only to produce another nondeterministic computation that’s even less sure
about its result.
Using the applicative style on lists is often a good replacement for list
comprehensions. In Chapter 1, we wanted to see all the possible products of
[2,5,10]and[8,10,11], so we did this:

ghci>[x*y | x <- [2,5,10], y <- [8,10,11]]
[16,20,22,40,50,55,80,100,110]

We’rejust drawing from two lists and applying a function between every
combination of elements. This can be done in the applicative style as well:

ghci>(*) <$> [2,5,10] <*> [8,10,11]
[16,20,22,40,50,55,80,100,110]

```
Applicative Functors 233
```

```
Thisseems clearer to me, because it’s easier to see that we’re just call-
ing*between two nondeterministic computations. If we wanted all possible
products of those two lists that are more than 50, we would use the following:
```
```
ghci>filter (>50) $ (*) <$> [2,5,10] <*> [8,10,11]
[55,80,100,110]
```
```
It’seasy to see howpure f <*> xsequalsfmap f xswith lists.pure fis just
[f], and[f] <*> xswill apply every function in the left list to every value in
the right one, but there’s just one function in the left list, so it’s like mapping.
```
## IO Is An Applicative Functor, Too..........................................

```
Another instance ofApplicativethat we’ve already encountered isIO. This is
how the instance is implemented:
```
```
instanceApplicative IO where
pure = return
a<*> b = do
f <- a
x <- b
return (f x)
```
```
Sincepureisall about putting a value in a
minimal context that still holds the value as
the result, it makes sense thatpureis justreturn.
returnmakes an I/O action that doesn’t do any-
thing. It just yields some value as its result, with-
out performing any I/O operations like printing
to the terminal or reading from a file.
If<*>were specialized forIO, it would have
a type of(<*>) :: IO (a -> b) -> IO a -> IO b. In
the case ofIO, it takes the I/O actiona, which
yields a function, performs the function, and
binds that function tof. Then it performsb
and binds its result tox. Finally, it applies the
functionftoxand yields that as the result. We
useddosyntax to implement it here. (Remember
thatdosyntax is about taking several I/O actions
and gluing them into one.)
WithMaybeand[], we could think of<*>as
simply extracting a function from its left parame-
ter and then applying it over the right one. With
IO, extracting is still in the game, but now we also
have a notion of sequencing , because we’re taking
two I/O actions and gluing them into one. We
```
**234** Chapter 11


needto extract the function from the first I/O action, but to extract a result
from an I/O action, it must be performed. Consider this:

myAction:: IO String
myAction = do
a <- getLine
b <- getLine
return $ a ++ b

Thisis an I/O action that will prompt the user for two lines and yield
as its result those two lines concatenated. We achieved it by gluing together
twogetLineI/O actions and areturn, because we wanted our new glued I/O
action to hold the result ofa ++ b. Another way of writing this is to use the
applicative style:

myAction:: IO String
myAction = (++) <$> getLine <*> getLine

Thisis the same thing we did earlier when we were making an I/O ac-
tion that applied a function between the results of two other I/O actions.
Remember thatgetLineis an I/O action with the typegetLine :: IO String.
When we use<*>between two applicative values, the result is an applicative
value, so this all makes sense.
If we return to the box analogy, we can imaginegetLineas a box that will
go out into the real world and fetch us a string. Calling(++) <$> getLine <*>
getLinemakes a new, bigger box that sends those two boxes out to fetch lines
from the terminal and then presents the concatenation of those two lines as
its result.
The type of the expression(++) <$> getLine <*> getLineisIO String. This
means that the expression is a completely normal I/O action like any other,
which also yields a result value, just like other I/O actions. That’s why we
can do stuff like this:

main= do
a <- (++) <$> getLine <*> getLine
putStrLn $ "The two lines concatenated turn out to be: " ++ a

## Functions As Applicatives.................................................

Another instance ofApplicativeis(->) r, or functions. We don’t often use
functions as applicatives, but the concept is still really interesting, so let’s
take a look at how the function instance is implemented.

instanceApplicative ((->) r) where
pure x = (\_ -> x)
f<*> g = \x -> f x (g x)

```
Applicative Functors 235
```

```
Whenwe wrap a value into an applicative value withpure, the result it
yields must be that value. A minimal default context still yields that value
as a result. That’s why in the function instance implementation,puretakes
a value and creates a function that ignores its parameter and always re-
turns that value. The type forpurespecialized for the(->) rinstance is
pure :: a -> (r -> a).
```
```
ghci>(pure 3) "blah"
3
```
```
Becauseof currying, function application is left-associative, so we can
omit the parentheses.
```
```
ghci>pure 3 "blah"
3
```
```
Theinstance implementation for<*>is a bit cryptic, so let’s just take a
look at how to use functions as applicative functors in the applicative style:
```
```
ghci>:t (+) <$> (+3) <*>(*100)
(+) <$> (+3) <*>(*100) :: (Num a) => a -> a
ghci> (+) <$> (+3) <*>(*100) $ 5
508
```
```
Calling<*>withtwo applicative values results in an applicative value,
so if we use it on two functions, we get back a function. So what goes on
here? When we do(+) <$> (+3) <*>(*100), we’re making a function
that will use+on the results of(+3)and(*100)and return that. With
(+) <$> (+3) <*>(*100) $ 5,(+3)and(*100)are first applied to 5 , resulting
in 8 and 500. Then+is called with 8 and 500 , resulting in 508.
The following code is similar:
```
```
ghci>(\x y z -> [x,y,z]) <$> (+3) <*>(*2) <*> (/2) $ 5
[8.0,10.0,2.5]
```
```
Wecreate a function that will call the
function\x y z -> [x,y,z]with the even-
tual results from(+3),(*2)and(/2). The 5
is fed to each of the three functions, and
then\x y z -> [x, y, z]is called with those
results.
```
```
NOTE It’s not very important that you get how the(->) rinstance forApplicativeworks,
so don’t despair if you don’t understand this all right now. Try playing with the ap-
plicative style and functions to get some insight into using functions as applicatives.
```
**236** Chapter 11


## Zip Lists.................................................................

It turns out there are actually more ways for lists to be applicative functors.
We’ve already covered one way: calling<*>with a list of functions and a list
of values, which results in a list containing all the possible combinations of
applying functions from the left list to the values in the right list.
For example, if we write[(+3),(*2)] <*> [1,2],(+3)will be applied to
both 1 and 2 , and(*2)will also be applied to both 1 and 2 , resulting in a list
that has four elements:[4,5,2,4]. However,[(+3),(*2)] <*> [1,2]could also
work in such a way that the first function in the left list is applied to the first
value in the right one, the second function is applied to the second value,
and so on. That would result in a list with two values:[4,4]. You could look
at it as[1 + 3, 2*2].
An instance ofApplicativethat we haven’t encountered yet isZipList,
and it lives inControl.Applicative.
Because one type can’t have two instances for the same type class, the
ZipList atype was introduced, which has one constructor (ZipList) with just
one field (a list). Here’s the instance:

instanceApplicative ZipList where
pure x = ZipList (repeat x)
ZipList fs <*> ZipList xs = ZipList (zipWith (\f x -> f x) fs xs)

<*>appliesthe first function to the first value, the second function to
the second value, and so on. This is done withzipWith (\f x -> f x) fs xs.
Because of howzipWithworks, the resulting list will be as long as the shorter
of the two lists.
pureis also interesting here. It takes a value and puts it in a list that just
has that value repeating indefinitely.pure "haha"results inZipList (["haha",
"haha","haha".... This might be a bit confusing, since you’ve learned that
pureshould put a value in a minimal context that still yields that value. And
you might be thinking that an infinite list of something is hardly minimal.
But it makes sense with zip lists, because it must produce the value on every
position. This also satisfies the law thatpure f <*> xsshould equalfmap f xs.
Ifpure 3just returnedZipList [3],pure (*2) <*> ZipList [1,5,10]would result
inZipList [2], because the resulting list of two zipped lists has the length of
the shorter of the two. If we zip a finite list with an infinite list, the length
of the resulting list will always be equal to the length of the finite list.
So how do zip lists work in an applicative style? Well, theZipList atype
doesn’t have aShowinstance, so we need to use thegetZipListfunction to
extract a raw list from a zip list:

ghci>getZipList $ (+) <$> ZipList [1,2,3] <*> ZipList [100,100,100]
[101,102,103]
ghci> getZipList $ (+) <$> ZipList [1,2,3] <*> ZipList [100,100..]
[101,102,103]
ghci> getZipList $ max <$> ZipList [1,2,3,4,5,3] <*> ZipList [5,3,1,2]
[5,3,3,4]

```
Applicative Functors 237
```

```
ghci>getZipList $ (,,) <$> ZipList "dog" <*> ZipList "cat" <*> ZipList "rat"
[('d','c','r'),('o','a','a'),('g','t','t')]
```
```
NOTE The(,,)functionis the same as\x y z -> (x,y,z). Also, the(,)function is the
same as\x y -> (x,y).
```
```
Aside fromzipWith, the standard library has functions such aszipWith3
andzipWith4, all the way up tozipWith7.zipWithtakes a function that takes
two parameters and zips two lists with it.zipWith3takes a function that takes
three parameters and zips three lists with it, and so on. By using zip lists with
an applicative style, we don’t need to have a separate zip function for each
number of lists that we want to zip together. We just use the applicative style
to zip together an arbitrary amount of lists with a function, and that’s pretty
handy.
```
## Applicative Laws.........................................................

```
Like normal functors, applicative functors come with a few laws. The most
important law is the one thatpure f <*> x = fmap f xholds. As an exercise,
you can prove this law for some of the applicative functors that we’ve met in
this chapter. The following are the other applicative laws:
```
- pure id <*>v=v
- pure (.) <*>u<*>v<*>w=u<*> (v <*> w)
- pure f <*> pure x = pure (f x)
- u<*> pure y = pure ($ y) <*>u

```
We won’t go over them in detail because that would take up a lot of
pages and be kind of boring. If you’re interested, you can take a closer look
at them and see if they hold for some of the instances.
```
## Useful Functions for Applicatives...................................................

```
Control.Applicativedefines a function that’s calledliftA2, which has the fol-
lowing type:
```
```
liftA2:: (Applicative f) => (a -> b -> c) -> f a -> f b -> f c
```
```
It’sdefined like this:
```
```
liftA2:: (Applicative f) => (a -> b -> c) -> f a -> f b -> f c
liftA2 f a b = f <$> a <*>b
```
```
Itjust applies a function between two applicatives, hiding the applica-
tive style that we’ve discussed. However, it clearly showcases why applicative
functors are more powerful than ordinary functors.
```
**238** Chapter 11


Withordinary functors, we can just map functions over one functor
value. With applicative functors, we can apply a function between sev-
eral functor values. It’s also interesting to look at this function’s type as
(a -> b -> c) -> (f a -> f b -> f c). When we look at it like this, we can
say thatliftA2takes a normal binary function and promotes it to a func-
tion that operates on two applicatives.
Here’s an interesting concept: We can take two applicative values and
combine them into one applicative value that has inside it the results of
those two applicative values in a list. For instance, we haveJust 3andJust 4.
Let’s assume that the second one contains a singleton list, because that’s re-
ally easy to achieve:

ghci>fmap (\x -> [x]) (Just 4)
Just [4]

Okay,so let’s say we haveJust 3andJust [4]. How do we getJust [3,4]?
That’s easy:

ghci>liftA2 (:) (Just 3) (Just [4])
Just [3,4]
ghci> (:) <$> Just 3 <*> Just [4]
Just [3,4]

Rememberthat:is a function that takes an element and a list and
returns a new list with that element at the beginning. Now that we have
Just [3,4], could we combine that withJust 2to produceJust [2,3,4]? Yes,
we could. It seems that we can combine any amount of applicative values
into one applicative value that has a list of the results of those applicative
values inside it.
Let’s try implementing a function that takes a list of applicative values
and returns an applicative value that has a list as its result value. We’ll call it
sequenceA.

sequenceA:: (Applicative f) => [f a] -> f [a]
sequenceA [] = pure []
sequenceA (x:xs) = (:) <$> x <*> sequenceA xs

Ah,recursion! First, we look at the type. It will transform a list of ap-
plicative values into an applicative value with a list. From that, we can lay
some groundwork for a base case. If we want to turn an empty list into an
applicative value with a list of results, we just put an empty list in a default
context. Now comes the recursion. If we have a list with a head and a tail
(remember thatxis an applicative value andxsis a list of them), we call
sequenceAon the tail, which results in an applicative value with a list inside.
Then we just prepend the value inside the applicativexinto that applicative
with a list, and that’s it!

```
Applicative Functors 239
```

```
Supposewe do this:
```
```
sequenceA[Just 1, Just 2]}
```
```
Bydefinition, that’s equal to the following:
```
```
(:)<$> Just 1 <*> sequenceA [Just 2]
```
```
Breakingthis down further, we get this:
```
```
(:)<$> Just 1 <*> ((:) <$> Just 2 <*> sequenceA [])
```
```
Weknow thatsequenceA []ends up as beingJust [], so this expression is
now as follows:
```
```
(:)<$> Just 1 <*> ((:) <$> Just 2 <*> Just [])
```
```
whichis this:
```
```
(:)<$> Just 1 <*> Just [2]
```
```
ThisequalsJust [1,2]!
Another way to implementsequenceAis with a fold. Remember that pretty
much any function where we go over a list element by element and accumu-
late a result along the way can be implemented with a fold:
```
```
sequenceA:: (Applicative f) => [f a] -> f [a]
sequenceA = foldr (liftA2 (:)) (pure [])
```
```
Weapproach the list from the right and start off with an accumulator
value ofpure []. We putliftA2 (:)between the accumulator and the last el-
ement of the list, which results in an applicative that has a singleton in it.
Then we callliftA2 (:)with the now last element and the current accumula-
tor and so on, until we’re left with just the accumulator, which holds a list of
the results of all the applicatives.
Let’s give our function a whirl on some applicatives:
```
```
ghci>sequenceA [Just 3, Just 2, Just 1]
Just [3,2,1]
ghci> sequenceA [Just 3, Nothing, Just 1]
Nothing
ghci> sequenceA [(+3),(+2),(+1)] 3
[6,5,4]
ghci> sequenceA [[1,2,3],[4,5,6]]
[[1,4],[1,5],[1,6],[2,4],[2,5],[2,6],[3,4],[3,5],[3,6]]
ghci> sequenceA [[1,2,3],[4,5,6],[3,4,4],[]]
[]
```
**240** Chapter 11


Whenused onMaybevalues,sequenceAcreates aMaybevalue with all the
results inside it as a list. If one of the values isNothing, then the result is also
aNothing. This is cool when you have a list ofMaybevalues, and you’re inter-
ested in the values only if none of them is aNothing.
When used with functions,sequenceAtakes a list of functions and returns
a function that returns a list. In our example, we made a function that took a
number as a parameter and applied it to each function in the list and then
returned a list of results.sequenceA [(+3),(+2),(+1)] 3will call(+3)with 3 ,(+2)
with 3 , and(+1)with 3 , and present all those results as a list.
Doing(+) <$> (+3) <*>(*2)will create a function that takes a parameter,
feeds it to both(+3)and(*2), and then calls+with those two results. In the
same vein, it makes sense thatsequenceA [(+3),(*2)]makes a function that
takes a parameter and feeds it to all of the functions in the list. Instead of
calling+with the results of the functions, a combination of:andpure []is
used to gather those results in a list, which is the result of that function.
UsingsequenceAis useful when we have a list of functions and we want
to feed the same input to all of them and then view the list of results. For
instance, suppose that we have a number and we’re wondering whether it
satisfies all of the predicates in a list. Here’s one way to do that:

ghci>map (\f -> f 7) [(>4),(<10),odd]
[True,True,True]
ghci> and $ map (\f -> f 7) [(>4),(<10),odd]
True

Rememberthatandtakes a list of Booleans and returnsTrueif they’re all
True. Another way to achieve the same thing is withsequenceA:

ghci>sequenceA [(>4),(<10),odd] 7
[True,True,True]
ghci> and $ sequenceA [(>4),(<10),odd] 7
True

sequenceA[(>4),(<10),odd]creates a function that will take a number
and feed it to all of the predicates in[(>4),(<10),odd]and return a list of
Booleans. It turns a list with the type(Num a) => [a -> Bool]into a function
with the type(Num a) => a -> [Bool]. Pretty neat, huh?
Because lists are homogenous, all the functions in the list must be func-
tions of the same type. You can’t have a list like[ord, (+3)], becauseord
takes a character and returns a number, whereas(+3)takes a number and
returns a number.
When used with[],sequenceAtakes a list of lists and returns a list of lists.
It actually creates lists that have all possible combinations of their elements.
For illustration, here’s the preceding example done withsequenceAand then
done with a list comprehension:

ghci>sequenceA [[1,2,3],[4,5,6]]
[[1,4],[1,5],[1,6],[2,4],[2,5],[2,6],[3,4],[3,5],[3,6]]

```
Applicative Functors 241
```

```
ghci> [[x,y] |x <- [1,2,3], y <- [4,5,6]]
[[1,4],[1,5],[1,6],[2,4],[2,5],[2,6],[3,4],[3,5],[3,6]]
ghci> sequenceA [[1,2],[3,4]]
[[1,3],[1,4],[2,3],[2,4]]
ghci> [[x,y] | x <- [1,2], y <- [3,4]]
[[1,3],[1,4],[2,3],[2,4]]
ghci> sequenceA [[1,2],[3,4],[5,6]]
[[1,3,5],[1,3,6],[1,4,5],[1,4,6],[2,3,5],[2,3,6],[2,4,5],[2,4,6]]
ghci> [[x,y,z] | x <- [1,2], y <- [3,4], z <- [5,6]]
[[1,3,5],[1,3,6],[1,4,5],[1,4,6],[2,3,5],[2,3,6],[2,4,5],[2,4,6]]
```
```
(+) <$> [1,2]<*> [4,5,6]results in a nondeterministic computation
x+y, wherextakes on every value from[1,2]andytakes on every value
from[4,5,6]. We represent that as a list that holds all of the possible re-
sults. Similarly, when we callsequenceA [[1,2],[3,4],[5,6]], the result is a
nondeterministic computation[x,y,z], wherextakes on every value from
[1,2],ytakes on every value from[3,4]and so on. To represent the result
of that nondeterministic computation, we use a list, where each element in
the list is one possible list. That’s why the result is a list of lists.
When used with I/O actions,sequenceAis the same thing assequence! It
takes a list of I/O actions and returns an I/O action that will perform each
of those actions and have as its result a list of the results of those I/O ac-
tions. That’s because to turn an[IO a]value into anIO [a]value, to make
an I/O action that yields a list of results when performed, all those I/O ac-
tions must be sequenced so that they’re then performed one after the other
when evaluation is forced. You can’t get the result of an I/O action without
performing it.
Let’s sequence threegetLineI/O actions:
```
```
ghci> sequenceA [getLine,getLine, getLine]
heyh
ho
woo
["heyh","ho","woo"]
```
```
In conclusion, applicativefunctors aren’t just interesting, they’re also
useful. They allow us to combine different computations—such as I/O com-
putations, nondeterministic computations, computations that might have
failed, and so on—by using the applicative style. Just by using<$>and<*>,
we can employ normal functions to uniformly operate on any number of ap-
plicative functors and take advantage of the semantics of each one.
```
**242** Chapter 11


# 12

## MONOIDS

```
This chapter features another useful and fun type
class:Monoid. This type class is for types whose values
can be combined together with a binary operation.
We’ll cover exactly what monoids are and what their
laws state. Then we’ll take a look at some monoids in
Haskell and how they can be of use.
First, let’s take a look at thenewtypekeyword, because we’ll be using it a
lot when we delve into the wonderful world of monoids.
```
## Wrapping an Existing Type into a New Type.......................................

```
Sofar, you’ve learned how to make your own alge-
braic data types by using thedatakeyword. You’ve
also seen how to give existing types synonyms with
thetypekeyword. In this section, we’ll look at how to
make new types out of existing data types by using the
newtypekeyword. We’ll also talk about why we would
want to do that in the first place.
In Chapter 11, you saw a couple of ways for the
list type to be an applicative functor. One way is to
have<*>take every function out of the list that is its
```

```
leftparameter and apply that to every value in the list that is on the right,
resulting in every possible combination of applying a function from the left
list to a value in the right list:
```
```
ghci>[(+1),(*100),(*5)] <*> [1,2,3]
[2,3,4,100,200,300,5,10,15]
```
```
Thesecond way is to take the first function on the left side of<*>and
apply it to the first value on the right, then take the second function from
the list on the left side and apply it to the second value on the right, and so
on. Ultimately, it’s kind of like zipping the two lists together.
But lists are already an instance ofApplicative, so how do we also make
lists an instance ofApplicativein this second way? As you learned, the
ZipList atype was introduced for this reason. This type has one value con-
structor,ZipList, which has just one field. We put the list that we’re wrap-
ping in that field. ThenZipListis made an instance ofApplicative, so that
when we want to use lists as applicatives in the zipping manner, we just wrap
them with theZipListconstructor. Once we’re finished, we unwrap them
withgetZipList:
```
```
ghci>getZipList $ ZipList [(+1),(*100),(*5)] <*> ZipList [1,2,3] $
[2,200,15]
```
```
So,what does this have to do with thisnewtypekeyword? Well, think
about how we might write the data declaration for ourZipList atype. Here’s
one way:
```
```
dataZipList a = ZipList [a]
```
```
Thisis a type that has just one value constructor, and that value con-
structor has just one field that is a list of things. We might also want to use
record syntax so that we automatically get a function that extracts a list from
aZipList:
```
```
dataZipList a = ZipList { getZipList :: [a] }
```
```
Thislooks fine and would actually work pretty well. We had two ways
of making an existing type an instance of a type class, so we used thedata
keyword to just wrap that type into another type and made the other type an
instance in the second way.
Thenewtypekeyword in Haskell is made exactly for cases when we want
to just take one type and wrap it in something to present it as another type.
In the actual libraries,ZipList ais defined like this:
```
```
newtypeZipList a = ZipList { getZipList :: [a] }
```
```
Insteadof thedatakeyword, thenewtypekeyword is used. Now why is
that? Well for one,newtypeis faster. If you use thedatakeyword to wrap a
```
**244** Chapter 12


type,there’s some overhead to all that wrapping and unwrapping when your
program is running. But if you usenewtype, Haskell knows that you’re just
using it to wrap an existing type into a new type (hence the name), because
you want it to be the same internally but have a different type. With that in
mind, Haskell can get rid of the wrapping and unwrapping once it resolves
which value is of which type.
So why not just usenewtypeinstead ofdataall the time? When you make
a new type from an existing type by using thenewtypekeyword, you can have
only one value constructor, and that value constructor can have only one
field. But withdata, you can make data types that have several value construc-
tors, and each constructor can have zero or more fields:

dataProfession = Fighter | Archer | Accountant

data Race = Human | Elf | Orc | Goblin

data PlayerCharacter = PlayerCharacter Race Profession

Wecan also use thederivingkeyword withnewtypejust as we would with
data. We can derive instances forEq,Ord,Enum,Bounded,Show, andRead. If we de-
rive the instance for a type class, the type that we’re wrapping must already
be in that type class. It makes sense, becausenewtypejust wraps an existing
type. So now if we do the following, we can print and equate values of our
new type:

newtypeCharList = CharList { getCharList :: [Char] } deriving (Eq, Show)

```
Let’sgive that a go:
```
ghci>CharList "this will be shown!"
CharList {getCharList = "this will be shown!"}
ghci> CharList "benny" == CharList "benny"
True
ghci> CharList "benny" == CharList "oisters"
False

```
Inthis particularnewtype, the value constructor has the following type:
```
CharList:: [Char] -> CharList

Ittakes a[Char]value, such as"my sharona"and returns aCharListvalue.
From the preceding examples where we used theCharListvalue constructor,
we see that really is the case. Conversely, thegetCharListfunction, which was
generated for us because we used record syntax in ournewtype, has this type:

getCharList:: CharList -> [Char]

```
Monoids 245
```

```
Ittakes aCharListvalue and converts it to a[Char]value. You can think
of this as wrapping and unwrapping, but you can also think of it as convert-
ing values from one type to the other.
```
## Using newtype to Make Type Class Instances...............................

```
Many times, we want to make our types instances of certain type classes, but
the type parameters just don’t match up for what we want to do. It’s easy to
makeMaybean instance ofFunctor, because theFunctortype class is defined
like this:
```
```
classFunctor f where
fmap :: (a -> b) -> f a -> f b
```
```
Sowe just start out with this:
```
```
instanceFunctor Maybe where
```
```
Thenwe implementfmap.
All the type parameters add up becauseMaybetakes the place offin the
definition of theFunctortype class. Looking atfmapas if it worked on only
Maybe, it ends up behaving like this:
```
```
fmap:: (a -> b) -> Maybe a -> Maybe b
```
```
Isn’tthat just peachy? Now what if we
wanted to make the tuple an instance of
Functorin such a way that when wefmap
a function over a tuple, it is applied to
the first component of the tuple? That
way, doingfmap (+3) (1, 1)would result
in(4, 1). It turns out that writing the in-
stance for that is kind of hard. WithMaybe,
we just sayinstance Functor Maybe where
because only type constructors that take
exactly one parameter can be made an in-
stance ofFunctor. But it seems like there’s
no way to do something like that with
(a, b)so that the type parameteraends up being the one that changes when
we usefmap. To get around this, we cannewtypeour tuple in such a way that
the second type parameter represents the type of the first component in the
tuple:
```
```
newtypePair b a = Pair { getPair :: (a, b) }
```
**246** Chapter 12


Andnow we can make it an instance ofFunctorso that the function is
mapped over the first component:

instanceFunctor (Pair c) where
fmap f (Pair (x, y)) = Pair (f x, y)

Asyou can see, we can pattern match on types defined withnewtype. We
pattern match to get the underlying tuple, apply the functionfto the first
component in the tuple, and then use thePairvalue constructor to convert
the tuple back to ourPair b a. If we imagine what the typefmapwould be if it
worked only on our new pairs, it would look like this:

fmap:: (a -> b) -> Pair c a -> Pair c b

Again,we saidinstance Functor (Pair c) where, and soPair ctook the
place of thefin the type class definition forFunctor:

classFunctor f where
fmap :: (a -> b) -> f a -> f b

Nowif we convert a tuple into aPair b a, we can usefmapover it, and the
function will be mapped over the first component:

ghci>getPair $ fmap (*100) (Pair (2, 3))
(200,3)
ghci> getPair $ fmap reverse (Pair ("london calling", 3))
("gnillac nodnol",3)

## On newtype Laziness.....................................................

The only thing that can be done withnewtypeis turning an existing type into
a new type, so internally, Haskell can represent the values of types defined
withnewtypejust like the original ones, while knowing that their types are
now distinct. This means that not only isnewtypeusually faster thandata, its
pattern-matching mechanism is lazier. Let’s take a look at what this means.
As you know, Haskell is lazy by default, which means that only when we
try to actually print the results of our functions will any computation take
place. Furthemore, only those computations that are necessary for our func-
tion to tell us the result will be carried out. Theundefinedvalue in Haskell
represents an erroneous computation. If we try to evaluate it (that is, force
Haskell to actually compute it) by printing it to the terminal, Haskell will
throw a hissy fit (technically referred to as an exception):

ghci>undefined

***Exception: Prelude.undefined

```
Monoids 247
```

```
However,if we make a list that has someundefinedvalues in it but request
only the head of the list, which is notundefined, everything will go smoothly.
This is because Haskell doesn’t need to evaluate any other elements in a list
if we want to see only the first element. Here’s an example:
```
```
ghci>head [3,4,5,undefined,2,undefined]
3
```
```
Nowconsider the following type:
```
```
dataCoolBool = CoolBool { getCoolBool :: Bool }
```
```
It’syour run-of-the-mill algebraic data type that was defined with the
datakeyword. It has one value constructor, which has one field whose type
isBool. Let’s make a function that pattern matches on aCoolBooland returns
the value"hello", regardless of whether theBoolinside theCoolBoolwasTrue
orFalse:
```
```
helloMe:: CoolBool -> String
helloMe (CoolBool _) = "hello"
```
```
Insteadof applying this function to a normalCoolBool, let’s throw it a
curveball and apply it toundefined!
```
```
ghci>helloMe undefined
"***Exception: Prelude.undefined
```
```
Yikes!An exception! Why did this exception happen? Types defined
with thedatakeyword can have multiple value constructors (even though
CoolBoolhas only one). So in order to see if the value given to our function
conforms to the(CoolBool _)pattern, Haskell must evaluate the value just
enough to see which value constructor was used when we made the value.
And when we try to evaluate anundefinedvalue, even a little, an exception is
thrown.
Instead of using thedatakeyword forCoolBool, let’s try usingnewtype:
```
```
newtypeCoolBool = CoolBool { getCoolBool :: Bool }
```
```
Wedon’t need to change ourhelloMefunction, because the pattern-
matching syntax is the same whether you usenewtypeordatato define your
type. Let’s do the same thing here and applyhelloMeto anundefinedvalue:
```
```
ghci>helloMe undefined
"hello"
```
```
Itworked! Hmmm, why is that? Well, as you’ve learned, when you use
newtype, Haskell can internally represent the values of the new type in the
same way as the original values. It doesn’t need to add another box around
```
**248** Chapter 12


them;it just must be aware of the values being of differ-
ent types. And because Haskell knows that types made
with thenewtypekeyword can have only one construc-
tor, it doesn’t need to evaluate the value passed to the
function to make sure that the value conforms to the
(CoolBool _)pattern, becausenewtypetypes can have only
one possible value constructor and one field!
This difference in behavior may seem trivial, but
it’s actually pretty important. It shows that even though
types defined withdataandnewtypebehave similarly from the programmer’s
point of view (because they both have value constructors and fields), they
are actually two different mechanisms. Whereasdatacan be used to make
your own types from scratch,newtypeis just for making a completely new type
out of an existing type. Pattern matching onnewtypevalues isn’t like taking
something out of a box (as it is withdata), but more about making a direct
conversion from one type to another.

## type vs. newtype vs. data

At this point, you may be a bit confused about the differences betweentype,
data, andnewtype, so let’s review their uses.
Thetypekeyword is for making type synonyms. We just give another
name to an already existing type so that the type is easier to refer to. Say we
did the following:

typeIntList = [Int]

Allthis does is allow us to refer to the[Int]type asIntList. They can be
used interchangeably. We don’t get anIntListvalue constructor or anything
like that. Because[Int]andIntListare only two ways to refer to the same
type, it doesn’t matter which name we use in our type annotations:

ghci>([1,2,3] :: IntList) ++ ([1,2,3] :: [Int])
[1,2,3,1,2,3]

Weuse type synonyms when we want to make our type signatures more
descriptive. We give types names that tell us something about their purpose
in the context of the functions where they’re being used. For instance, when
we used an association list of type[(String, String)]to represent a phone
book in Chapter 7, we gave it the type synonym ofPhoneBookso that the type
signatures of our functions were easier to read.
Thenewtypekeyword is for taking existing types and wrapping them in
new types, mostly so it’s easier to make them instances of certain type classes.
When we usenewtypeto wrap an existing type, the type that we get is separate
from the original type. Suppose we make the followingnewtype:

newtypeCharList = CharList { getCharList :: [Char] }

```
Monoids 249
```

```
Wecan’t use++to put together aCharListand a list of type[Char]. We
can’t even use++to put together twoCharListlists, because++works only
on lists, and theCharListtype isn’t a list, even though it could be said that
CharListcontains a list. We can, however, convert twoCharLists to lists,++
them, and then convert that back to aCharList.
When we use record syntax in ournewtypedeclarations, we get func-
tions for converting between the new type and the original type—namely the
value constructor of ournewtypeand the function for extracting the value in
its field. The new type also isn’t automatically made an instance of the type
classes that the original type belongs to, so we need to derive or manually
write it.
In practice, you can think ofnewtypedeclarations asdatadeclarations
that can have only one constructor and one field. If you catch yourself writ-
ing such adatadeclaration, consider usingnewtype.
Thedatakeyword is for making your own data types. You can go hog
wild with them. They can have as many constructors and fields as you wish
and can be used to implement any algebraic data type—everything from
lists andMaybe-like types to trees.
In summary, use the keywords as follows:
```
- If you just want your type signatures to look cleaner and be more de-
    scriptive, you probably want type synonyms.
- If you want to take an existing type and wrap it in a new type in order
    to make it an instance of a type class, chances are you’re looking for a
    newtype.
- If you want to make something completely new, odds are good that
    you’re looking for thedatakeyword.

## About Those Monoids.............................................................

```
Typeclasses in Haskell are used to
present an interface for types that have
some behavior in common. We started
out with simple type classes likeEq, which
is for types whose values can be equated,
andOrd, which is for things that can be
put in an order. Then we moved on to
more interesting type classes, likeFunctor
andApplicative.
When we make a type, we think
about which behaviors it supports (what
it can act like) and then decide which
type classes to make it an instance of based on the behavior we want. If it
makes sense for values of our type to be equated, we make our type an in-
stance of theEqtype class. If we see that our type is some kind of functor, we
make it an instance ofFunctor, and so on.
```
**250** Chapter 12


Nowconsider the following:*is a function that takes two numbers and
multiplies them. If we multiply some number with a 1 , the result is always

equal to that number. It doesn’t matter if we do (^1) *xorx* 1 — the result is
alwaysx. Similarly,++is a function that takes two things and returns a third.
But instead of multiplying numbers, it takes two lists and concatenates them.
And much like*, it also has a certain value that doesn’t change the other
one when used with++. That value is the empty list:[].
ghci> (^4) * 1
4
ghci> 1* 9
9
ghci> [1,2,3] ++ []
[1,2,3]
ghci> [] ++ [0.5, 2.5]
[0.5,2.5]
Itseems that*together with 1 and++along with[]share some common
properties:

- The function takes two parameters.
- The parameters and the returned value have the same type.
- There exists such a value that doesn’t change other values when used
    with the binary function.

There’s another thing that these two operations have in common that
may not be as obvious as our previous observations: When we have three
or more values and we want to use the binary function to reduce them to a
single result, the order in which we apply the binary function to the values

doesn’t matter. For example, whether we use(3*4)* 5 or (^3) *(4*5), the
result is 60. The same goes for++:
ghci>(3*2)*(8*5)
240
ghci> 3*(2*(8*5))
240
ghci> "la" ++ ("di" ++ "da")
"ladida"
ghci> ("la" ++ "di") ++ "da"
"ladida"
Wecall this property _associativity_ .*is associative, and so is++. However,-,
for example, is not associative; the expressions(5 - 3) - 4and5 - (3 - 4)re-
sult in different numbers.
By being aware of these properties, we have chanced upon monoids!
Monoids **251**


## The Monoid Type Class..................................................

```
A monoid is made up of an associative binary function and a value that acts
as an identity with respect to that function. When something acts as an iden-
tity with respect to a function, it means that when called with that function
and some other value, the result is always equal to that other value. 1 is the
identity with respect to*, and[]is the identity with respect to++. There are
a lot of other monoids to be found in the world of Haskell, which is why the
Monoidtype class exists. It’s for types that can act like monoids. Let’s see how
the type class is defined:
```
```
classMonoid m where
mempty :: m
mappend :: m -> m -> m
mconcat :: [m] -> m
mconcat = foldr mappend mempty
```
```
TheMonoidtypeclass is defined in
import Data.Monoid. Let’s take some time
to get properly acquainted with it.
First, we see that only concrete types
can be made instances ofMonoid, because
themin the type class definition doesn’t take
any type parameters. This is different from
FunctorandApplicative, which require their
instances to be type constructors that take
one parameter.
The first function ismempty. It’s not re-
ally a function, since it doesn’t take param-
eters. It’s a polymorphic constant, kind of
likeminBoundfromBounded.memptyrepresents
the identity value for a particular monoid.
Next up, we havemappend, which, as you’ve probably guessed, is the bi-
nary function. It takes two values of the same type and returns another value
of that same type. The decision to call itmappendwas kind of unfortunate, be-
cause it implies that we’re appending two things in some way. While++does
take two lists and append one to the other,*doesn’t really do any append-
ing; it just multiplies two numbers together. When you meet other instances
ofMonoid, you’ll see that most of them don’t append values either. So avoid
thinking in terms of appending and just think in terms ofmappendbeing a
binary function that takes two monoid values and returns a third.
The last function in this type class definition ismconcat. It takes a list of
monoid values and reduces them to a single value by usingmappendbetween
the list’s elements. It has a default implementation, which just takesmemptyas
a starting value and folds the list from the right withmappend. Because the de-
fault implementation is fine for most instances, we won’t concern ourselves
withmconcattoo much. When making a type an instance ofMonoid, it suffices
to just implementmemptyandmappend. Although for some instances, there
```
**252** Chapter 12


```
mightbe a more efficient way to implementmconcat, the default implementa-
tion is just fine for most cases.
```
## The Monoid Laws........................................................

```
Before moving on to specific instances ofMonoid, let’s take a brief look at the
monoid laws.
You’ve learned that there must be a value that acts as the identity with
respect to the binary function and that the binary function must be associa-
tive. It’s possible to make instances ofMonoidthat don’t follow these rules,
but such instances are of no use to anyone because when using theMonoid
type class, we rely on its instances acting like monoids. Otherwise, what’s the
point? That’s why when making monoid instances, we need to make sure
they follow these laws:
```
- mempty `mappend` x = x
- x `mappend` mempty = x
- (x `mappend` y) `mappend` z = x `mappend` (y `mappend` z)

```
The first two laws state thatmemptymust act as the identity with respect
tomappend, and the third says thatmappendmust be associative (the order in
which we usemappendto reduce several monoid values into one doesn’t mat-
ter). Haskell doesn’t enforce these laws, so we need to be careful that our
instances do indeed obey them.
```
## Meet Some Monoids..............................................................

```
Now that you know what monoids are about, let’s look at some Haskell types
that are monoids, what theirMonoidinstances look like, and their uses.
```
## Lists Are Monoids........................................................

```
Yes, lists are monoids! As you’ve seen, the++function and the empty list[]
form a monoid. The instance is very simple:
```
```
instanceMonoid [a] where
mempty = []
mappend = (++)
```
```
Listsare an instance of theMonoidtype class, regardless of the type of
the elements they hold. Notice that we wroteinstance Monoid [a]and not
instance Monoid [], becauseMonoidrequires a concrete type for an instance.
Giving this a test run, we encounter no surprises:
```
```
ghci>[1,2,3] `mappend` [4,5,6]
[1,2,3,4,5,6]
ghci> ("one" `mappend` "two") `mappend` "tree"
"onetwotree"
```
```
Monoids 253
```

```
ghci>"one" `mappend` ("two" `mappend` "tree")
"onetwotree"
ghci> "one" `mappend` "two" `mappend` "tree"
"onetwotree"
ghci> "pang" `mappend` mempty
"pang"
ghci> mconcat [[1,2],[3,6],[9]]
[1,2,3,6,9]
ghci> mempty :: [a]
[]
```
```
Noticethat in the last line, we wrote an ex-
plicit type annotation. If we just wrotemempty,
GHCi wouldn’t know which instance to use, so
we needed to say we want the list instance. We
were able to use the general type of[a](as op-
posed to specifying[Int]or[String]) because the
empty list can act as if it contains any type.
Becausemconcathas a default implemen-
tation, we get it for free when we make some-
thing an instance ofMonoid. In the case of the list,
mconcatturns out to be justconcat. It takes a list of
lists and flattens it, because that’s the equivalent of doing++between all the
adjacent lists in a list.
The monoid laws do indeed hold for the list instance. When we have
several lists and wemappend(or++) them together, it doesn’t matter which
ones we do first, because they’re just joined at the ends anyway. Also, the
empty list acts as the identity, so all is well.
Notice that monoids don’t require thata `mappend` bbe equal to
b `mappend` a. In the case of the list, they clearly aren’t:
```
```
ghci>"one" `mappend` "two"
"onetwo"
ghci> "two" `mappend` "one"
"twoone"
```
Andthat’s okay. The fact that for multiplication (^3) * 5 and (^5) * 3 are the
same is just a property of multiplication, but it doesn’t hold for all (and in-
deed, most) monoids.

## Product and Sum.........................................................

```
We already examined one way for numbers to be considered monoids: Just
let the binary function be*and the identity value be 1. Another way for
```
**254** Chapter 12


numbersto be monoids is to have the binary function be+and the identity
value be 0 :

ghci>0+4
4
ghci> 5 + 0
5
ghci> (1 + 3) + 5
9
ghci> 1 + (3 + 5)
9

Themonoid laws hold, because if you add 0 to any number, the result is
that number. And addition is also associative, so we have no problems there.
With two equally valid ways for numbers to be monoids, which way do we
choose? Well, we don’t have to pick. Remember that when there are several
ways for some type to be an instance of the same type class, we can wrap that
type in anewtypeand then make the new type an instance of the type class in
a different way. We can have our cake and eat it too.
TheData.Monoidmodule exports two types for this:ProductandSum.
Productis defined like this:

newtypeProduct a = Product { getProduct :: a }
deriving (Eq, Ord, Read, Show, Bounded)

It’ssimple—just anewtypewrapper with one type parameter along with
some derived instances. Its instance forMonoidgoes something like this:

instanceNum a => Monoid (Product a) where
mempty = Product 1
Product x `mappend` Product y = Product (x*y)

memptyisjust 1 wrapped in aProductconstructor.mappendpattern matches
on theProductconstructor, multiplies the two numbers, and then wraps the
resulting number. As you can see, there’s aNum aclass constraint. This means
thatProduct ais an instance ofMonoidfor allavalues that are already an in-
stance ofNum. To useProduct aas a monoid, we need to do somenewtype
wrapping and unwrapping:

ghci>getProduct $ Product 3 `mappend` Product 9
27
ghci> getProduct $ Product 3 `mappend` mempty
3
ghci> getProduct $ Product 3 `mappend` Product 4 `mappend` Product 2
24
ghci> getProduct. mconcat. map Product $ [3,4,2]
24

```
Monoids 255
```

```
Sumisdefined along the same lines asProduct, and the instance is similar
as well. We use it in the same way:
```
```
ghci>getSum $ Sum 2 `mappend` Sum 9
11
ghci> getSum $ mempty `mappend` Sum 3
3
ghci> getSum. mconcat. map Sum $ [1,2,3]
6
```
## Any and All.............................................................

```
Another type that can act like a monoid in two distinct but equally valid ways
isBool. The first way is to have the function||, which represents a logical
OR, act as the binary function along withFalseas the identity value. With
the logical OR, if any of the two parameters isTrue, it returnsTrue; otherwise,
it returnsFalse. So if we useFalseas the identity value, OR will returnFalse
when used withFalseandTruewhen used withTrue. TheAny newtypeconstruc-
tor is an instance ofMonoidin this fashion. It’s defined like this:
```
```
newtypeAny = Any { getAny :: Bool }
deriving (Eq, Ord, Read, Show, Bounded)
```
```
Itsinstance looks like this:
```
```
instanceMonoid Any where
mempty = Any False
Any x `mappend` Any y = Any (x || y)
```
```
It’scalledAnybecausex `mappend` ywill beTrueif any one of those two is
True. Even if three or moreAnywrappedBoolvalues aremappended together,
the result will holdTrueif any of them areTrue:
```
```
ghci>getAny $ Any True `mappend` Any False
True
ghci> getAny $ mempty `mappend` Any True
True
ghci> getAny. mconcat. map Any $ [False, False, False, True]
True
ghci> getAny $ mempty `mappend` mempty
False
```
```
Theother way forBoolto be an instance ofMonoidis to kind of do the
opposite: Have&&be the binary function and then makeTruethe identity
value. Logical AND will returnTrueonly if both of its parameters areTrue.
```
**256** Chapter 12


```
Thisis thenewtypedeclaration:
```
newtypeAll = All { getAll :: Bool }
deriving (Eq, Ord, Read, Show, Bounded)

```
Andthis is the instance:
```
instanceMonoid All where
mempty = All True
All x `mappend` All y = All (x && y)

Whenwemappendvalues of theAlltype, the result will beTrueonly if _all_
the values used in themappendoperations areTrue:

ghci>getAll $ mempty `mappend` All True
True
ghci> getAll $ mempty `mappend` All False
False
ghci> getAll. mconcat. map All $ [True, True, True]
True
ghci> getAll. mconcat. map All $ [True, True, False]
False

Justas with multiplication and addition, we usually explicitly state the
binary functions instead of wrapping them innewtypes and then usingmappend
andmempty.mconcatseems useful forAnyandAll, but usually it’s easier to use
theorandandfunctions.ortakes lists ofBoolvalues and returnsTrueif any
of them areTrue.andtakes the same values and returnsTrueif all of them
areTrue.

## The Ordering Monoid....................................................

Remember theOrderingtype? It’s used as the result when comparing things,
and it can have three values:LT,EQ, andGT, which stand for less than, equal,
and greater than, respectively.

ghci>1 `compare` 2
LT
ghci> 2 `compare` 2
EQ
ghci> 3 `compare` 2
GT

Withlists, numbers, and Boolean values, finding monoids was just a mat-
ter of looking at already existing commonly used functions and seeing if they
exhibited some sort of monoid behavior. WithOrdering, we need to look a bit

```
Monoids 257
```

```
harderto recognize a monoid. It turns out that the orderingMonoidinstance
is just as intuitive as the ones we’ve met so far, and it’s also quite useful:
```
```
instanceMonoid Ordering where
mempty = EQ
LT `mappend` _ = LT
EQ `mappend` y = y
GT `mappend` _ = GT
```
```
Theinstance is set up like this:
When wemappendtwoOrderingvalues,
the one on the left is kept, unless the
value on the left isEQ. If the value on
the left isEQ, the right one is the result.
The identity isEQ. At first, this may seem
kind of arbitrary, but it actually resem-
bles the way we alphabetically compare
words. We look at the first two letters,
and if they differ, we can already decide
which word would go first in a dictio-
nary. However, if the first two letters are
equal, then we move on to comparing
the next pair of letters and repeat the
process.
For instance, when we alphabetically compare the words ox and on , we
see that the first letter of each word is equal and then move on to comparing
the second letter. Since x is alphabetically greater than n , we know how the
words compare. To gain some understanding ofEQbeing the identity, note
that if we were to cram the same letter in the same position in both words, it
wouldn’t change their alphabetical ordering; for example, oix is still alpha-
betically greater than oin.
It’s important to note that in theMonoidinstance forOrdering,x `mappend`
ydoesn’t equaly `mappend` x. Because the first parameter is kept unless it’s
EQ,LT `mappend` GTwill result inLT, whereasGT `mappend` LTwill result inGT:
```
```
ghci>LT `mappend` GT
LT
ghci> GT `mappend` LT
GT
ghci> mempty `mappend` LT
LT
ghci> mempty `mappend` GT
GT
```
```
Okay,so how is this monoid useful? Let’s say we are writing a function
that takes two strings, compares their lengths, and returns anOrdering. But
if the strings are of the same length, instead of returningEQright away, we
want to compare them alphabetically.
```
**258** Chapter 12


```
Here’s one wayto write this:
```
lengthCompare :: String-> String -> Ordering
lengthCompare x y = let a = length x `compare` length y
b = x `compare` y
in if a == EQ then b else a

We name theresult of comparing the lengthsaand the result of the al-
phabetical comparisonb, and then if the lengths are equal, we return their
alphabetical ordering.
But by employing our understanding of howOrderingis a monoid, we
can rewrite this function in a much simpler manner:

import Data.Monoid

lengthCompare ::String -> String -> Ordering
lengthCompare x y = (length x `compare` length y) `mappend`
(x `compare` y)

```
Let’s try thisout:
```
ghci> lengthCompare "zen""ants"
LT
ghci> lengthCompare "zen" "ant"
GT

Remember that whenwe usemappend, its left parameter is kept unless
it’sEQ; if it’sEQ, the right one is kept. That’s why we put the comparison that
we consider to be the first, more important, criterion as the first parameter.
Now suppose that we want to expand this function to also compare for the
number of vowels and set this to be the second most important criterion for
comparison. We modify it like this:

import Data.Monoid

lengthCompare ::String -> String -> Ordering
lengthCompare x y = (length x `compare` length y) `mappend`
(vowels x `compare` vowels y) `mappend`
(x `compare` y)
where vowels = length. filter (`elem` "aeiou")

We made ahelper function, which takes a string and tells us how many
vowels it has by first filtering it for only letters that are in the string"aeiou"
and then applyinglengthto that.

ghci> lengthCompare "zen""anna"
LT

```
Monoids 259
```

```
ghci>lengthCompare "zen" "ana"
LT
ghci> lengthCompare "zen" "ann"
GT
```
```
Inthe first example, the lengths are found to be different, and soLTis
returned, because the length of"zen"is less than the length of"anna". In the
second example, the lengths are the same, but the second string has more
vowels, soLTis returned again. In the third example, they both have the
same length and the same number of vowels, so they’re compared alpha-
betically, and"zen"wins.
TheOrderingmonoid is very useful because it allows us to easily compare
things by many different criteria and put those criteria in an order them-
selves, ranging from the most important to the least important.
```
## Maybe the Monoid......................................................

```
Let’s take a look at the various ways thatMaybe acan be made an instance of
Monoidand how those instances are useful.
One way is to treatMaybe aas a monoid only if its type parameterais a
monoid as well and then implementmappendin such a way that it uses the
mappendoperation of the values that are wrapped withJust. We useNothingas
the identity, and so if one of the two values that we’remappending isNothing,
we keep the other value. Here’s the instance declaration:
```
```
instanceMonoid a => Monoid (Maybe a) where
mempty = Nothing
Nothing `mappend` m = m
m `mappend` Nothing = m
Just m1 `mappend` Just m2 = Just (m1 `mappend` m2)
```
```
Noticethe class constraint. It says thatMaybe ais an instance ofMonoid
only ifais an instance ofMonoid. If wemappendsomething with aNothing, the
result is that something. If wemappendtwoJustvalues, the contents of the
Justs aremappended and then wrapped back in aJust. We can do this because
the class constraint ensures that the type of what’s inside theJustis an in-
stance ofMonoid.
```
```
ghci>Nothing `mappend` Just "andy"
Just "andy"
ghci> Just LT `mappend` Nothing
Just LT
ghci> Just (Sum 3) `mappend` Just (Sum 4)
Just (Sum {getSum = 7})
```
```
Thisis useful when we’re dealing with monoids as results of computa-
tions that may have failed. Because of this instance, we don’t need to check
```
**260** Chapter 12


ifthe computations have failed by seeing if they’re aNothingorJustvalue; we
can just continue to treat them as normal monoids.
But what if the type of the contents of theMaybeis not an instance of
Monoid? Notice that in the previous instance declaration, the only case where
we must rely on the contents being monoids is when both parameters of
mappendareJustvalues. When we don’t know if the contents are monoids,
we can’t usemappendbetween them, so what are we to do? Well, one thing we
can do is discard the second value and keep the first one. For this purpose,
theFirst atype exists. Here’s its definition:

newtypeFirst a = First { getFirst :: Maybe a }
deriving (Eq, Ord, Read, Show)

Wetake aMaybe aand wrap it with anewtype. TheMonoidinstance is as
follows:

instanceMonoid (First a) where
mempty = First Nothing
First (Just x) `mappend` _ = First (Just x)
First Nothing `mappend` x = x

memptyisjust aNothingwrapped with theFirst newtypeconstructor. If
mappend’s first parameter is aJustvalue, we ignore the second one. If the first
one is aNothing, then we present the second parameter as a result, regardless
of whether it’s aJustor aNothing:

ghci>getFirst $ First (Just 'a') `mappend` First (Just 'b')
Just 'a'
ghci> getFirst $ First Nothing `mappend` First (Just 'b')
Just 'b'
ghci> getFirst $ First (Just 'a') `mappend` First Nothing
Just 'a'

Firstisuseful when we have a bunch ofMaybevalues and we just want to
know if any of them is aJust. Themconcatfunction comes in handy:

ghci>getFirst. mconcat. map First $ [Nothing, Just 9, Just 10]
Just 9

Ifwe want a monoid onMaybe asuch that the second parameter is kept
if both parameters ofmappendareJustvalues,Data.Monoidprovides theLast a
type, which works likeFirst a, but the last non-Nothingvalue is kept when
mappending and usingmconcat:

ghci>getLast. mconcat. map Last $ [Nothing, Just 9, Just 10]
Just 10
ghci> getLast $ Last (Just "one") `mappend` Last (Just "two")
Just "two"

```
Monoids 261
```

## Folding with Monoids.............................................................

```
One of the more interesting ways to put monoids to work is to have them
help us define folds over various data structures. So far, we’ve done folds
over lists, but lists aren’t the only data structure that can be folded over. We
can define folds over almost any data structure. Trees especially lend them-
selves well to folding.
Because there are so many data structures that work nicely with folds,
theFoldabletype class was introduced. Much likeFunctoris for things that
can be mapped over,Foldableis for things that can be folded up! It can be
found inData.Foldable, and because it exports functions whose names clash
with the ones from thePrelude, it’s best imported qualified (and served with
basil):
```
```
importqualified Data.Foldable as F
```
```
Tosave ourselves precious keystrokes, we’ve imported it qualified asF.
So what are some of the functions that this type class defines? Well,
among them arefoldr,foldl,foldr1, andfoldl1. Huh? We already know
these functions. What’s so new about this? Let’s compare the types of
Foldable’sfoldrandfoldrfromPreludeto see how they differ:
```
```
ghci>:t foldr
foldr :: (a -> b -> b) -> b -> [a] -> b
ghci> :t F.foldr
F.foldr :: (F.Foldable t) => (a -> b -> b) -> b -> t a -> b
```
```
Ah!So whereasfoldrtakes a list and folds it up, thefoldrfrom
Data.Foldableaccepts any type that can be folded up, not just lists! As
expected, bothfoldrfunctions do the same for lists:
```
```
ghci>foldr (*) 1 [1,2,3]
6
ghci> F.foldr (*) 1 [1,2,3]
6
```
```
Anotherdata structures that support folds is theMaybewe all know
and love!
```
```
ghci>F.foldl (+) 2 (Just 9)
11
ghci> F.foldr (||) False (Just True)
True
```
```
Butfolding over aMaybevalue isn’t terribly interesting. It just acts like a
list with one element if it’s aJustvalue and like an empty list if it’sNothing.
Let’s examine a data structure that’s a little more complex.
```
**262** Chapter 12


Rememberthe tree data structure from Chapter 7? We defined it
like this:

dataTree a = EmptyTree | Node a (Tree a) (Tree a) deriving (Show)

Youlearned that a tree is either an empty tree that doesn’t hold any val-
ues or it’s a node that holds one value and also two other trees. After defin-
ing it, we made it an instance ofFunctor, and with that we gained the ability
tofmapfunctions over it. Now we’re going to make it an instance ofFoldable
so we get the ability to fold it up.
One way to make a type constructor an instance ofFoldableis to just di-
rectly implementfoldrfor it. But another, often much easier way, is to im-
plement thefoldMapfunction, which is also a part of theFoldabletype class.
ThefoldMapfunction has the following type:

foldMap:: (Monoid m, Foldable t) => (a -> m) -> t a -> m

Itsfirst parameter is a function that takes a value of the type that our
foldable structure contains (denoted here witha) and returns a monoid
value. Its second parameter is a foldable structure that contains values of
typea. It maps that function over the foldable structure, thus producing a
foldable structure that contains monoid values. Then, by doingmappendbe-
tween those monoid values, it joins them all into a single monoid value. This
function may sound kind of odd at the moment, but you’ll see that it’s very
easy to implement. And implementing this function is all it takes for our
type to be made an instance ofFoldable! So if we just implementfoldMapfor
some type, we getfoldrandfoldlon that type for free.
This is how we makeTreean instance ofFoldable:

instanceF.Foldable Tree where
foldMap f EmptyTree = mempty
foldMap f (Node x l r) = F.foldMap f l `mappend`
fx `mappend`
F.foldMap f r

Ifwe are provided with a function
that takes an element of our tree and
returns a monoid value, how do we re-
duce our whole tree down to one single
monoid value? When we were usingfmap
over our tree, we applied the function
that we were mapping to a node, and
then we recursively mapped the function
over the left subtree as well as the right
one. Here, we’re tasked with not only
mapping a function, but also with joining up the results into a single monoid
value by usingmappend. First, we consider the case of the empty tree—a sad,
sad, lonely tree that has no values or subtrees. It doesn’t hold any value that

```
Monoids 263
```

```
wecan give to our monoid-making function, so we just say that if our tree is
empty, the monoid value it becomes ismempty.
The case of a nonempty node is a bit more interesting. It contains two
subtrees as well as a value. In this case, we recursivelyfoldMapthe same func-
tionfover the left and right subtrees. Remember that ourfoldMapresults in
a single monoid value. We also apply our functionfto the value in the node.
Now we have three monoid values (two from our subtrees and one from ap-
plyingfto the value in the node), and we just need to bang them together
into a single value. For this purpose, we usemappend, and naturally the left
subtree comes first, then the node value, followed by the right subtree.
Notice that we didn’t need to provide the function that takes a value and
returns a monoid value. We receive that function as a parameter tofoldMap,
and all we need to decide is where to apply that function and how to join the
resulting monoids from it.
Now that we have aFoldableinstance for our tree type, we getfoldrand
foldlfor free! Consider this tree:
```
```
testTree= Node 5
(Node 3
(Node 1 EmptyTree EmptyTree)
(Node 6 EmptyTree EmptyTree)
)
(Node 9
(Node 8 EmptyTree EmptyTree)
(Node 10 EmptyTree EmptyTree)
)
```
```
Ithas 5 at its root, and then its left node has 3 with 1 on the left and 6 on
the right. The root’s right node has a 9 and then 8 to its left and 10 on the far
right side. With aFoldableinstance, we can do all of the folds that we can do
on lists:
```
```
ghci>F.foldl (+) 0 testTree
42
ghci> F.foldl (*) 1 testTree
64800
```
```
foldMapisn’tuseful only for making new instances ofFoldable. It also
comes in handy for reducing our structure to a single monoid value. For
instance, if we want to know if any number in our tree is equal to 3 , we can
do this:
```
```
ghci>getAny $ F.foldMap (\x -> Any $ x == 3) testTree
True
```
**264** Chapter 12


Here,\x-> Any $ x == 3is a function that takes a number and returns
a monoid value: aBoolwrapped inAny.foldMapapplies this function to every
element in our tree and then reduces the resulting monoids into a single
monoid withmappend. Suppose we do this:

ghci>getAny $ F.foldMap (\x -> Any $ x > 15) testTree
False

Allof the nodes in our tree will hold the valueAny Falseafter having the
function in the lambda applied to them. But to end upTrue,mappendforAny
must have at least oneTruevalue as a parameter. That’s why the final result is
False, which makes sense because no value in our tree is greater than 15.
We can also easily turn our tree into a list by doing afoldMapwith the
\x -> [x]function. By first projecting that function onto our tree, each ele-
ment becomes a singleton list. Themappendaction that takes place between
all those singleton lists results in a single list that holds all of the elements
that are in our tree:

ghci>F.foldMap (\x -> [x]) testTree
[1,3,6,5,8,9,10]

What’scool is that all of these tricks aren’t limited to trees. They work
on any instance ofFoldable!

```
Monoids 265
```


# 13

## AFISTFULOFMONADS

```
When we first talked about functors in Chapter 7, you
saw that they are a useful concept for values that can
be mapped over. Then, in Chapter 11, we took that con-
cept one step further with applicative functors, which
allow us to view values of certain data types as values
with contexts and use normal functions on those val-
ues while preserving the meaning of those contexts.
In this chapter, you’ll learn about monads , which are just beefed-up ap-
plicative functors, much like applicative functors are beefed-up functors.
```
## Upgrading Our Applicative Functors...............................................

```
Whenwe started off with functors, you
saw that it’s possible to map functions
over various data types using theFunctor
type class. The introduction to functors
had us asking the question, “When we
have a function of typea -> band some
data typefa, how do we map that func-
tion over the data type to end up withfb?” You saw how to map something
over aMaybe a, a list[a], anIO a, and so on. You even saw how to map a func-
```

```
tiona-> bover other functions of typer -> ato get functions of typer -> b.
To answer the question of how to map a function over some data type, all we
needed to do was look at the type offmap:
```
```
fmap:: (Functor f) => (a -> b) -> f a -> f b
```
```
Andthen we just needed to make it work for our data type by writing the
appropriateFunctorinstance.
Then you saw a possible improvement of functors and had a few more
questions. What if that functiona -> bis already wrapped inside a func-
tor value? Say we haveJust (*3)—how do we apply that toJust 5? What if
we don’t want to apply it toJust 5, but to aNothinginstead? Or if we have
[(*2),(+4)], how do we apply that to[1,2,3]? How could that even work?
For this, theApplicativetype class was introduced:
```
```
(<*>):: (Applicative f) => f (a -> b) -> f a -> f b
```
```
Youalso saw that you can take a normal value and wrap it inside a data
type. For instance, we can take a 1 and wrap it so that it becomes aJust 1.
Or we can make it into a[1]. It could even become an I/O action that does
nothing and just yields 1. The function that does this is calledpure.
An applicative value can be seen as a value with an added context—a
fancy value, to put it in technical terms. For instance, the character'a'is just
a normal character, whereasJust 'a'has some added context. Instead of
aChar, we have aMaybe Char, which tells us that its value might be a charac-
ter, but it could also be an absence of a character. TheApplicativetype class
allows us to use normal functions on these values with context, and that con-
text is preserved. Observe an example:
```
```
ghci>(*) <$> Just 2 <*> Just 8
Just 16
ghci> (++) <$> Just "klingon" <*> Nothing
Nothing
ghci> (-) <$> [3,4] <*> [1,2,3]
[2,1,0,3,2,1]
```
```
Sonow that we treat them as applicative values,Maybe avalues represent
computations that might have failed,[a]values represent computations that
have several results (nondeterministic computations),IO avalues represent
values that have side effects, and so on.
Monads are a natural extension of applicative functors, and they provide
a solution to the following problem: If we have a value with a context,ma,
how do we apply to it a function that takes a normalaand returns a value
with a context? In other words, how do we apply a function of typea -> m b
to a value of typema? Essentially, we want this function:
```
```
(>>=):: (Monad m) => m a -> (a -> m b) -> m b
```
**268** Chapter 13


```
Ifwe have a fancy value and a function that takes a normal value but re-
turns a fancy value, how do we feed that fancy value into the function? This
is the main concern when dealing with monads. We writemainstead offa,
because themstands forMonad, but monads are just applicative functors that
support>>=. The>>=function is called bind.
When we have a normal valueaand a normal functiona -> b, it’s re-
ally easy to feed the value to the function—we just apply the function to the
value normally, and that’s it. But when we’re dealing with values that come
with certain contexts, it takes a bit of thinking to see how these fancy values
are fed to functions and how to take into account their behavior. But you’ll
see that it’s as easy as one, two, three.
```
## Getting Your Feet Wet with Maybe

```
Nowthat you have a vague idea of what
monads are about, let’s make that idea a
little more concrete. Much to no one’s
surprise,Maybeis a monad. Here, we’ll
explore it a bit more to see how it works
in this role.
```
```
NOTE Make sure you understand applicative func-
tors at this point. (We discussed them in
Chapter 11.) You should have a feel for how
the variousApplicativeinstances work and
what kinds of computations they represent.
To understand monads, you’ll be taking your
existing applicative functor knowledge and
upgrading it.
```
```
A value of typeMaybe arepresents a value of typea, but with the context
of possible failure attached. A value ofJust "dharma"means that the string
"dharma"is there. A value ofNothingrepresents its absence, or if you look at
the string as the result of a computation, it means that the computation has
failed.
When we looked atMaybeas a functor, we saw that if we want tofmapa
function over it, the function is mapped over what’s inside if that’s aJust
value. Otherwise, theNothingis kept, because there’s nothing to map it over!
```
```
ghci>fmap (++"!") (Just "wisdom")
Just "wisdom!"
ghci> fmap (++"!") Nothing
Nothing
```
```
Asan applicative functor,Maybefunctions similarly. However, with ap-
plicative functors, the function itself is in a context, along with the value to
which it’s being applied.Maybeis an applicative functor in such a way that
when we use<*>to apply a function inside aMaybeto a value that’s inside a
```
```
AFistfulofMonads 269
```

```
Maybe,they both must beJustvalues for the result to be aJustvalue; other-
wise, the result isNothing. This makes sense. If you’re missing either the func-
tion or the thing you’re applying it to, you can’t make something up out of
thin air, so you need to propagate the failure.
```
```
ghci>Just (+3) <*> Just 3
Just 6
ghci> Nothing <*> Just "greed"
Nothing
ghci> Just ord <*> Nothing
Nothing
```
```
Usingthe applicative style to have normal functions act onMaybevalues
works in a similar way. All the values must beJustvalues; otherwise, it’s all
forNothing!
```
```
ghci>max <$> Just 3 <*> Just 6
Just 6
ghci> max <$> Just 3 <*> Nothing
Nothing
```
```
Andnow, let’s think about how we would use>>=withMaybe.>>=takes a
monadic value and a function that takes a normal value. It returns a monadic
value and manages to apply that function to the monadic value. How does it
do that if the function takes a normal value? Well, it must take into account
the context of that monadic value.
In this case,>>=would take aMaybe avalue and a function of typea ->
Maybe b, and somehow apply the function to theMaybe a. To figure out how
it does that, we can use the understanding that we have fromMaybebeing
an applicative functor. Let’s say that we have a function\x -> Just (x+1). It
takes a number, adds 1 to it, and wraps it in aJust:
```
```
ghci>(\x -> Just (x+1)) 1
Just 2
ghci> (\x -> Just (x+1)) 100
Just 101
```
```
Ifwe feed it 1 , it evaluates toJust 2. If we give it the number 100 , the
result isJust 101. It seems very straightforward. But how do we feed aMaybe
value to this function? If we think about howMaybeacts as an applicative
functor, answering this is pretty easy. We feed it aJustvalue, take what’s in-
side theJust, and apply the function to it. If we give it aNothing, then we’re
left with a function butNothingto apply it to. In that case, let’s just do what
we did before and say that the result isNothing.
```
**270** Chapter 13


Insteadof calling it>>=, let’s call itapplyMaybefor now. It takes aMaybe a
and a function that returns aMaybe b, and manages to apply that function to
theMaybe a. Here it is in code:

applyMaybe:: Maybe a -> (a -> Maybe b) -> Maybe b
applyMaybe Nothing f = Nothing
applyMaybe (Just x) f = f x

Nowlet’s play with it. We’ll use it as an infix function so that theMaybe
value is on the left side and the function is on the right:

ghci>Just 3 `applyMaybe` \x -> Just (x+1)
Just 4
ghci> Just "smile" `applyMaybe` \x -> Just (x ++ " :)")
Just "smile :)"
ghci> Nothing `applyMaybe` \x -> Just (x+1)
Nothing
ghci> Nothing `applyMaybe` \x -> Just (x ++ " :)")
Nothing

Inthis example, when we usedapplyMaybewith aJustvalue and a func-
tion, the function was simply applied to the value inside theJust. When we
tried to use it with aNothing, the whole result wasNothing. What about if the
function returns aNothing? Let’s see:

ghci>Just 3 `applyMaybe` \x -> if x > 2 then Just x else Nothing
Just 3
ghci> Just 1 `applyMaybe` \x -> if x > 2 then Just x else Nothing
Nothing

Theresults are just what we expected. If the monadic value on the left
is aNothing, the whole thing isNothing. And if the function on the right re-
turns aNothing, the result isNothingagain. This is similar to when we used
Maybeas an applicative and we got aNothingresult if there was aNothingsome-
where in the mix.
It looks like we’ve figured out how to take a fancy value, feed it to a func-
tion that takes a normal value, and return a fancy one. We did this by keep-
ing in mind that aMaybevalue represents a computation that might have
failed.
You might be asking yourself, “How is this useful?” It may seem like ap-
plicative functors are stronger than monads, since applicative functors allow
us to take a normal function and make it operate on values with contexts. In
this chapter, you’ll see that monads, as an upgrade of applicative functors,
can also do that. In fact, they can do some other cool stuff that applicative
functors can’t do.
We’ll come back toMaybein a minute, but first, let’s check out the type
class that belongs to monads.

```
AFistfulofMonads 271
```

## The Monad Type Class

```
Just like functors have theFunctortype class, and applicative functors have
theApplicativetype class, monads come with their own type class:Monad!
(Wow, who would have thought?)
```
```
classMonad m where
return :: a -> m a
```
```
(>>=) :: m a -> (a -> m b) -> m b
```
```
(>>) :: m a -> m b -> m b
x >> y = x >>= \_ -> y
```
```
fail :: String -> m a
fail msg = error msg
```
```
Thefirst line saysclass Monad m where. But
wait, didn’t I say that monads are just beefed-
up applicative functors? Shouldn’t there be
a class constraint in there along the lines of
class (Applicative m) = > Monad m where, so
that a type must be an applicative functor
before it can be made a monad? Well, there
should, but when Haskell was made, it hadn’t
occurred to people that applicative functors
were a good fit for Haskell. But rest assured,
every monad is an applicative functor, even if
theMonadclass declaration doesn’t say so.
The first function that theMonadtype class
defines isreturn. It’s the same aspurefrom
theApplicativetype class. So, even though it has a different name, you’re
already acquainted with it.return’s type is(Monad m) => a -> m a. It takes a
value and puts it in a minimal default context that still holds that value. In
other words,returntakes something and wraps it in a monad. We already
usedreturnwhen handling I/O in Chapter 8. We used it to take a value and
make a bogus I/O action that does nothing but yield that value. ForMaybe, it
takes a value and wraps it in aJust.
```
```
NOTE Just a reminder:returnis nothing like thereturnthat’s in most other languages. It
doesn’t end function execution. It just takes a normal value and puts it in a context.
```
```
The next function is>>=, or bind. It’s like function application, but in-
stead of taking a normal value and feeding it to a normal function, it takes a
monadic value (that is, a value with a context) and feeds it to a function that
takes a normal value but returns a monadic value.
```
**272** Chapter 13


Nextup, we have>>. We won’t pay too
much attention to it for now because it comes
with a default implementation, and it’s rarely
implemented when makingMonadinstances.
We’ll take a closer look at it in “Banana on a
Wire” on page 278.
The final function of theMonadtype class
isfail. We never use it explicitly in our code.
Instead, it’s used by Haskell to enable fail-
ure in a special syntactic construct for mon-
ads that you’ll meet later. We don’t need to concern ourselves withfailtoo
much for now.
Now that you know what theMonadtype class looks like, let’s take a look
at howMaybeis an instance ofMonad!

instanceMonad Maybe where
return x = Just x
Nothing >>= f = Nothing
Just x >>= f = f x
fail _ = Nothing

returnisthe same aspure, so that one is a no-brainer. We do what we
did in theApplicativetype class and wrap it in aJust. The>>=function is the
same as ourapplyMaybe. When feeding theMaybe ato our function, we keep
in mind the context and return aNothingif the value on the left isNothing
Again, if there’s no value, then there’s no way to apply our function to it. If
it’s aJust, we take what’s inside and applyfto it.
We can play around withMaybeas a monad:

ghci>return "WHAT" :: Maybe String
Just "WHAT"
ghci> Just 9 >>= \x -> return (x*10)
Just 90
ghci> Nothing >>= \x -> return (x*10)
Nothing

There’snothing new or exciting on the first line, since we already used
purewithMaybe, and we know thatreturnis justpurewith a different name.
The next two lines showcase>>=a bit more. Notice how when we fed
Just 9to the function\x -> return (x*10), thextook on the value 9 inside the
function. It seems as though we were able to extract the value from aMaybe
without pattern matching. And we still didn’t lose the context of ourMaybe
value, because when it’sNothing, the result of using>>=will beNothingas well.

```
AFistfulofMonads 273
```

## Walk the Line....................................................................

```
Nowthat you know how to feed aMaybe a
value to a function of typea -> Maybe b
while taking into account the context of
possible failure, let’s see how we can use
>>=repeatedly to handle computations of
severalMaybe avalues.
Pierre has decided to take a break
from his job at the fish farm and try
tightrope walking. He is not that bad
at it, but he does have one problem:
Birds keep landing on his balancing
pole! They come and take a short rest,
chat with their avian friends, and then
take off in search of breadcrumbs. This
wouldn’t bother him so much if the number of birds on the left side of the
pole were always equal to the number of birds on the right side. But some-
times, all the birds decide that they like one side better. They throw him off
balance, which results in an embarrassing tumble for Pierre (he is using a
safety net).
Let’s say that Pierre keeps his balance if the number of birds on the left
side of the pole and on the right side of the pole is within three. So if there’s
one bird on the right side and four birds on the left side, he is okay. But if a
fifth bird lands on the left side, he loses his balance and takes a dive.
We’re going to simulate birds landing on and flying away from the pole
and see if Pierre is still at it after a certain number of bird arrivals and depar-
tures. For instance, we want to see what happens to Pierre if first one bird
arrives on the left side, then four birds occupy the right side, and then the
bird that was on the left side decides to fly away.
```
## Code, Code, Code......................................................

```
We can represent the pole with a simple pair of integers. The first component
will signify the number of birds on the left side and the second component
the number of birds on the right side:
```
```
typeBirds = Int
type Pole = (Birds, Birds)
```
```
First,we made a type synonym forInt, calledBirds, because we’re using
integers to represent how many birds there are. And then we made a type
synonym(Birds, Birds)and called itPole(not to be confused with a person
of Polish descent).
```
**274** Chapter 13


Now, how aboutadding functions that take a number of birds and land
them on one side of the pole or the other?

landLeft :: Birds-> Pole -> Pole
landLeft n (left, right) = (left + n, right)

landRight :: Birds -> Pole -> Pole
landRight n (left, right) = (left, right + n)

```
Let’s try themout:
```
ghci> landLeft 2(0, 0)
(2,0)
ghci> landRight 1 (1, 2)
(1,3)
ghci> landRight (-1) (1, 2)
(1,1)

To make birdsfly away, we just had a negative number of birds land on
one side. Because landing a bird on thePolereturns aPole, we can chain
applications oflandLeftandlandRight:

ghci> landLeft 2(landRight 1 (landLeft 1 (0, 0)))
(3,1)

When we applythe functionlandLeft 1to(0, 0)we get(1, 0). Then we
land a bird on the right side, resulting in(1, 1). Finally, two birds land on
the left side, resulting in(3, 1). We apply a function to something by first
writing the function and then writing its parameter, but here it would be
better if the pole went first and then the landing function. Suppose we make
a function like this:

x -: f=fx

We can applyfunctions by first writing the parameter and then the
function:

ghci> 100 -:(*3)
300
ghci> True -: not
False
ghci> (0, 0) -: landLeft 2
(2,0)

```
AFistful of Monads 275
```

```
Byusing this form, we can repeatedly land birds on the pole in a more
readable manner:
```
```
ghci>(0, 0) -: landLeft 1 -: landRight 1 -: landLeft 2
(3,1)
```
```
Prettycool! This version is equivalent to the one before where we re-
peatedly landed birds on the pole, but it looks neater. Here, it’s more obvi-
ous that we start off with(0, 0)and then land one bird on the left, then one
on the right, and finally, two on the left.
```
## I’ll Fly Away.............................................................

```
So far so good, but what happens if ten birds land on one side?
```
```
ghci>landLeft 10 (0, 3)
(10,3)
```
```
Tenbirds on the left side and only three on the right? That’s sure to
send poor Pierre falling through the air! This is pretty obvious here, but
what if we had a sequence of landings like this:
```
```
ghci>(0, 0) -: landLeft 1 -: landRight 4 -: landLeft (-1) -: landRight (-2)
(0,2)
```
```
Itmight seem as if everything is okay, but if you follow the steps here,
you’ll see that at one time there are four birds on the right side and no birds
on the left! To fix this, we need to take another look at ourlandLeftand
landRightfunctions.
We want thelandLeftandlandRightfunctions to be able to fail. We want
them to return a new pole if the balance is okay but fail if the birds land in
a lopsided manner. And what better way to add a context of failure to value
than by usingMaybe! Let’s rework these functions:
```
```
landLeft:: Birds -> Pole -> Maybe Pole
landLeft n (left, right)
| abs ((left + n) - right) < 4 = Just (left + n, right)
| otherwise = Nothing
```
```
landRight :: Birds -> Pole -> Maybe Pole
landRight n (left, right)
| abs (left - (right + n)) < 4 = Just (left, right + n)
| otherwise = Nothing
```
```
Insteadof returning aPole, these functions now return aMaybe Pole.
They still take the number of birds and the old pole as before, but then they
check if landing that many birds on the pole would throw Pierre off balance.
We use guards to check if the difference between the number of birds on
```
**276** Chapter 13


thenew pole is less than 4. If it is, we wrap the new pole in aJustand return
that. If it isn’t, we return aNothing, indicating failure.
Let’s give these babies a go:

ghci>landLeft 2 (0, 0)
Just (2,0)
ghci> landLeft 10 (0, 3)
Nothing

Whenwe land birds without throwing Pierre off balance, we get a new
pole wrapped in aJust. But when many more birds end up on one side of
the pole, we get aNothing. This is cool, but we seem to have lost the ability to
repeatedly land birds on the pole. We can’t dolandLeft 1 (landRight 1 (0, 0))
anymore, because when we applylandRight 1to(0, 0), we don’t get aPole,
but aMaybe Pole.landLeft 1takes aPole, rather than aMaybe Pole.
We need a way of taking aMaybe Poleand feeding it to a function that
takes aPoleand returns aMaybe Pole. Luckily, we have>>=, which does just
that forMaybe. Let’s give it a go:

ghci>landRight 1 (0, 0) >>= landLeft 2
Just (2,1)

RememberthatlandLeft 2has a type ofPole -> Maybe Pole. We couldn’t
just feed it theMaybe Polethat is the result oflandRight 1 (0, 0), so we use>>=
to take that value with a context and give it tolandLeft 2.>>=does indeed
allow us to treat theMaybevalue as a value with context. If we feed aNothing
intolandLeft 2, the result isNothing, and the failure is propagated:

ghci>Nothing >>= landLeft 2
Nothing

Withthis, we can now chain landings that may fail, because>>=allows
us to feed a monadic value to a function that takes a normal one. Here’s a
sequence of bird landings:

ghci>return (0, 0) >>= landRight 2 >>= landLeft 2 >>= landRight 2
Just (2,4)

Atthe beginning, we usedreturnto take a pole and wrap it in aJust.
We could have just appliedlandRight 2to(0, 0)—it would have been the
same—but this way, we can be more consistent by using>>=for every func-
tion.Just (0, 0)is fed tolandRight 2, resulting inJust (0, 2). This, in turn,
gets fed tolandLeft 2, resulting inJust (2, 2), and so on.
Remember the following example from before we introduced failure
into Pierre’s routine?

ghci>(0, 0) -: landLeft 1 -: landRight 4 -: landLeft (-1) -: landRight (-2)
(0,2)

```
AFistful of Monads 277
```

```
Itdidn’t simulate his interaction with birds very well. In the middle, his
balance was off, but the result didn’t reflect that. Let’s fix that now by using
monadic application (>>=) instead of normal application:
```
```
ghci>return (0, 0) >>= landLeft 1 >>= landRight 4 >>= landLeft (-1) >>= landRight (-2)
Nothing
```
```
Thefinal result represents failure, which is what we expected. Let’s see
how this result was obtained:
```
1. returnputs(0, 0)into a default context, making it aJust (0, 0).
2. Just (0, 0) >>= landLeft 1happens. Since theJust (0, 0)is aJustvalue,
    landLeft 1gets applied to(0, 0), resulting in aJust (1, 0), because the
    birds are still relatively balanced.
3. Just (1, 0) >>= landRight 4takes place, and the result isJust (1, 4), as
    the balance of the birds is still intact, although just barely.
4. Just (1, 4)gets fed tolandLeft (-1). This means thatlandLeft (-1) (1, 4)
    takes place. Now because of howlandLeftworks, this results in aNothing,
    because the resulting pole is off balance.
5. Now that we have aNothing, it gets fed tolandRight (-2), but because it’s
    aNothing, the result is automaticallyNothing, as we have nothing to apply
    landRight (-2)to.

```
We couldn’t have achieved this by just usingMaybeas an applicative. If
you try it, you’ll get stuck, because applicative functors don’t allow for the
applicative values to interact with each other very much. They can, at best,
be used as parameters to a function by using the applicative style.
The applicative operators will fetch their results and feed them to the
function in a manner appropriate for each applicative, and then put the fi-
nal applicative value together, but there isn’t that much interaction going on
between them. Here, however, each step relies on the previous one’s result.
On every landing, the possible result from the previous one is examined and
the pole is checked for balance. This determines whether the landing will
succeed or fail.
```
## Banana on a Wire.......................................................

```
Nowlet’s devise a function that ignores the
current number of birds on the balancing
pole and just makes Pierre slip and fall. We’ll
call itbanana:
```
```
banana:: Pole -> Maybe Pole
banana _ = Nothing
```
```
Wecan chain this function together with our bird landings. It will always
cause our walker to fall, because it ignores whatever is passed to it and always
returns a failure.
```
**278** Chapter 13


ghci>return (0, 0) >>= landLeft 1 >>= banana >>= landRight 1
Nothing

ThevalueJust (1, 0)gets fed tobanana, but it produces aNothing, which
causes everything to result in aNothing. How unfortunate!
Instead of making functions that ignore their input and just return a
predetermined monadic value, we can use the>>function. Here’s its default
implementation:

(>>):: (Monad m) => m a -> m b -> m b
m >> n = m >>= \_ -> n

Normally,passing some value to a function that ignores its parameter
and always returns some predetermined value always results in that prede-
termined value. With monads, however, their context and meaning must be
considered as well. Here’s how>>acts withMaybe:

ghci>Nothing >> Just 3
Nothing
ghci> Just 3 >> Just 4
Just 4
ghci> Just 3 >> Nothing
Nothing

Ifwe replace>>with>>= \_ ->, it’s easy to see what’s happening.
We can replace ourbananafunction in the chain with a>>and then a
Nothingfor guaranteed and obvious failure:

ghci>return (0, 0) >>= landLeft 1 >> Nothing >>= landRight 1
Nothing

Whatwould this look like if we hadn’t made the clever choice of treating
Maybevalues as values with a failure context and feeding them to functions?
Here’s how a series of bird landings would look:

routine:: Maybe Pole
routine = case landLeft 1 (0, 0) of
Nothing -> Nothing
Just pole1 -> case landRight 4 pole1 of
Nothing -> Nothing
Just pole2 -> case landLeft 2 pole2 of
Nothing -> Nothing
Just pole3 -> landLeft 1 pole3

Weland a bird on the left, and then we examine the possibility of fail-
ure and the possibility of success. In the case of failure, we return aNothing.

```
AFistfulofMonads 279
```

```
Inthe case of success, we land birds on
the right and then do the same thing
all over again. Converting this mon-
strosity into a neat chain of monadic
applications with>>=is a classic exam-
ple of how theMaybemonad saves a lot
of time when you need to successively
do computations that are based on
computations that might have failed.
Notice how theMaybeimplemen-
tation of>>=features exactly this logic
of seeing if a value isNothingand act-
ing on that knowledge. If the value is
Nothing, it returns aNothingimmedi-
ately. If the value is notNothing, it goes
forward with what’s inside theJust.
In this section, we looked at how some functions work better when
the values that they return support failure. By turning those values intoMaybe
values and replacing normal function application with>>=, we got a mech-
anism for handling failure pretty much for free. This is because>>=is sup-
posed to preserve the context of the value to which it applies functions. In
this case, the context was that our values were values with failure. So, when
we applied functions to such values, the possibility of failure was always taken
into account.
```
## do Notation.....................................................................

```
Monads in Haskell are so useful that they got their own special syntax, called
donotation. You already encountereddonotation in Chapter 8, when we
used it for gluing together several I/O actions into one. Well, as it turns out,
donotation isn’t just forIObut can be used for any monad. Its principle is
still the same: gluing together monadic values in sequence.
Consider this familiar example of monadic application:
```
```
ghci>Just 3 >>= (\x -> Just (show x ++ "!"))
Just "3!"
```
```
Beenthere, done that. Feeding a monadic value to a function that re-
turns one—no big deal. Notice how when we do this,xbecomes 3 inside the
lambda. Once we’re inside that lambda, it’s just a normal value rather than a
monadic value. Now, what if we had another>>=inside that function? Check
this out:
```
```
ghci>Just 3 >>= (\x -> Just "!" >>= (\y -> Just (show x ++ y)))
Just "3!"
```
```
Ah,a nested use of>>=! In the outermost lambda, we feedJust "!"to the
lambda\y -> Just (show x ++ y). Inside this lambda, theybecomes"!".xis
```
**280** Chapter 13


still 3 ,because we got it from the outer lambda. All this sort of reminds me
of the following expression:

ghci>let x = 3; y = "!" in show x ++ y
"3!"

Themain difference here is that the values in our>>=example are mon-
adic. They are values with a failure context. We can replace any of them with
a failure:

ghci>Nothing >>= (\x -> Just "!" >>= (\y -> Just (show x ++ y)))
Nothing
ghci> Just 3 >>= (\x -> Nothing >>= (\y -> Just (show x ++ y)))
Nothing
ghci> Just 3 >>= (\x -> Just "!" >>= (\y -> Nothing))
Nothing

Inthe first line, feeding aNothingto a function naturally results in a
Nothing. In the second line, we feedJust 3to a function, and thexbecomes
3. But then we feed aNothingto the inner lambda, and the result of that is
Nothing, which causes the outer lambda to produceNothingas well. So this is
sort of like assigning values to variables inletexpressions, except that the
values in question are monadic values.
To further illustrate this point, let’s write this in a script and have each
Maybevalue take up its own line:

foo:: Maybe String
foo = Just 3 >>= (\x ->
Just "!" >>= (\y ->
Just (show x ++ y)))

Tosave us from writing all these annoying lambdas, Haskell gives usdo
notation. It allows us to write the previous piece of code like this:

foo:: Maybe String
foo = do
x <- Just 3
y <- Just "!"
Just (show x ++ y)

```
Itwould seem as though we’ve gained the ability to
temporarily extract things fromMaybevalues without need-
ing to check if theMaybevalues areJustvalues orNothing
values at every step. How cool! If any of the values that
we try to extract from areNothing, the wholedoexpression
will result in aNothing. We’re yanking out their (possibly
existing) values and letting>>=worry about the context
that comes with those values.
```
```
AFistfulofMonads 281
```

```
doexpressionsare just different syntax for chaining monadic values.
```
## Do As I Do..............................................................

```
In adoexpression, every line that isn’t aletline is a monadic value. To in-
spect its result, we use<-. If we have aMaybe Stringand we bind it to a vari-
able with<-, that variable will be aString, just as when we used>>=to feed
monadic values to lambdas.
The last monadic value in adoexpression—likeJust (show x ++ y)here—
can’t be used with<-to bind its result, because that wouldn’t make sense if
we translated thedoexpression back to a chain of>>=applications. Rather,
its result is the result of the whole glued-up monadic value, taking into ac-
count the possible failure of any of the previous ones. For instance, examine
the following line:
```
```
ghci>Just 9 >>= (\x -> Just (x > 8))
Just True
```
```
Becausethe left parameter of>>=is aJustvalue, the lambda is applied to
9 , and the result is aJust True. We can rewrite this indonotation, as follows:
```
```
marySue:: Maybe Bool
marySue = do
x <- Just 9
Just (x > 8)
```
```
Comparingthese two versions, it’s easy to see why the result of the whole
monadic value is the result of the last monadic value in thedoexpression
with all the previous ones chained into it.
```
## Pierre Returns............................................................

```
Our tightrope walker’s routine can also be expressed withdonotation.landLeft
andlandRighttake a number of birds and a pole and produce a pole wrapped
in aJust. The exception is when the tightrope walker slips, in which case a
Nothingis produced. We used>>=to chain successive steps because each one
relied on the previous one, and each one had an added context of possible
failure. Here are two birds landing on the left side, then two birds landing
on the right, and then one bird landing on the left:
```
```
routine:: Maybe Pole
routine = do
start <- return (0, 0)
first <- landLeft 2 start
second <- landRight 2 first
landLeft 1 second
```
**282** Chapter 13


```
Let’ssee if he succeeds:
```
ghci>routine
Just (3,2)

Hedoes!
When we were doing these routines by explicitly writing>>=, we usu-
ally said something likereturn (0, 0) >>= landLeft 2, becauselandLeft 2is a
function that returns aMaybevalue. However, withdoexpressions, each line
must feature a monadic value. So we explicitly pass the previousPoleto the
landLeft landRightfunctions. If we examined the variables to which we bound
ourMaybevalues,startwould be(0, 0),firstwould be(2, 0)and so on.
Becausedoexpressions are written line by line, they may look like imper-
ative code to some people. But they’re just sequential, as each value in each
line relies on the result of the previous ones, along with their contexts (in
this case, whether they succeeded or failed).
Again, let’s take a look at what this piece of code would look like if we
hadn’t used the monadic aspects ofMaybe:

routine:: Maybe Pole
routine =
case Just (0, 0) of
Nothing -> Nothing
Just start -> case landLeft 2 start of
Nothing -> Nothing
Just first -> case landRight 2 first of
Nothing -> Nothing
Just second -> landLeft 1 second

Seehow in the case of success, the tuple insideJust (0, 0)becomes
start, the result oflandLeft 2 startbecomesfirst, and so on?
If we want to throw Pierre a banana peel indonotation, we can do the
following:

routine:: Maybe Pole
routine = do
start <- return (0, 0)
first <- landLeft 2 start
Nothing
second <- landRight 2 first
landLeft 1 second

Whenwe write a line indonotation without binding the monadic value
with<-, it’s just like putting>>after the monadic value whose result we want
to ignore. We sequence the monadic value but we ignore its result, because
we don’t care what it is. Plus, it’s prettier than writing its equivalent form of
_ <- Nothing.

```
AFistfulofMonads 283
```

```
Whento usedonotation and when to explicitly use>>=is up to you. I
think this example lends itself to explicitly writing>>=, because each step re-
lies specifically on the result of the previous one. Withdonotation, we need
to specifically write on which pole the birds are landing, but every time we
just use the pole that was the result of the previous landing. But still, it gave
us some insight intodonotation.
```
## Pattern Matching and Failure..............................................

```
Indonotation, when we bind monadic values to names, we can utilize pat-
tern matching, just as inletexpressions and function parameters. Here’s an
example of pattern matching in adoexpression:
```
```
justH:: Maybe Char
justH = do
(x:xs) <- Just "hello"
return x
```
```
Weuse pattern matching to get the first character of the string"hello",
and then we present it as the result. SojustHevaluates toJust 'h'.
What if this pattern matching were to fail? When matching on a pattern
in a function fails, the next pattern is matched. If the matching falls through
all the patterns for a given function, an error is thrown, and the program
crashes. On the other hand, failed pattern matching inletexpressions re-
sults in an error being produced immediately, because the mechanism of
falling through patterns isn’t present inletexpressions.
When pattern matching fails in adoexpression, thefailfunction (part
of theMonadtype class) enables it to result in a failure in the context of the
current monad, instead of making the program crash. Here’s its default
implementation:
```
```
fail:: (Monad m) => String -> m a
fail msg = error msg
```
```
So,by default, it does make the program crash. But monads that incor-
porate a context of possible failure (likeMaybe) usually implement it on their
own. ForMaybe, it’s implemented like so:
```
```
fail_ = Nothing
```
```
Itignores the error message and makes aNothing. So when pattern match-
ing fails in aMaybevalue that’s written indonotation, the whole value results
in aNothing. This is preferable to having your program crash. Here’s adoex-
pression with a pattern match that’s bound to fail:
```
```
wopwop:: Maybe Char
wopwop = do
```
**284** Chapter 13


```
(x:xs)<- Just ""
return x
```
```
Thepattern matching fails, so the effect is the same as if the whole line
with the pattern were replaced with aNothing. Let’s try this out:
```
```
ghci>wopwop
Nothing
```
```
Thefailed pattern matching has caused a failure within the context of
our monad instead of causing a program-wide failure, which is pretty neat.
```
## The List Monad...................................................................

```
Sofar, you’ve seen howMaybevalues can
be viewed as values with a failure context,
and how we can incorporate failure han-
dling into our code by using>>=to feed
them to functions. In this section, we’re
going to take a look at how to use the
monadic aspects of lists to bring nonde-
terminism into our code in a clear and
readable manner.
In Chapter 11, we talked about how
lists represent nondeterministic values
when they’re used as applicatives. A
value like 5 is deterministic—it has only
one result, and we know exactly what it
is. On the other hand, a value like[3,8,9]contains several results, so we can
view it as one value that is actually many values at the same time. Using lists
as applicative functors showcases this nondeterminism nicely.
```
```
ghci>(*) <$> [1,2,3] <*> [10,100,1000]
[10,100,1000,20,200,2000,30,300,3000]
```
```
Allthe possible combinations of multiplying elements from the left list
with elements from the right list are included in the resulting list. When
dealing with nondeterminism, there are many choices that we can make,
so we just try all of them. This means the result is a nondeterministic value
as well, but it has many more results.
This context of nondeterminism translates to monads very nicely. Here’s
what theMonadinstance for lists looks like:
```
```
instanceMonad [] where
return x = [x]
xs >>= f = concat (map f xs)
fail _ = []
```
```
AFistful of Monads 285
```

```
As you know,returndoesthe same thing aspure, and you’re already fa-
miliar withreturnfor lists.returntakes a value and puts it in a minimal de-
fault context that still yields that value. In other words,returnmakes a list
that has only that one value as its result. This is useful when we want to just
wrap a normal value into a list so that it can interact with nondeterministic
values.
>>=is about taking a value with a context (a monadic value) and feeding
it to a function that takes a normal value and returns one that has context. If
that function just produced a normal value instead of one with a context,>>=
wouldn’t be so useful—after one use, the context would be lost.
Let’s try feeding a nondeterministic value to a function:
```
```
ghci> [3,4,5] >>=\x -> [x,-x]
[3,-3,4,-4,5,-5]
```
```
When we used>>=withMaybe, the monadic value was fed into the
function while taking care of possible failures. Here, it takes care of non-
determinism for us.
[3,4,5]is a nondeterministic value, and we feed it into a function that
returns a nondeterministic value as well. The result is also nondeterminis-
tic, and it features all the possible results of taking elements from the list
[3,4,5]and passing them to the function\x -> [x,-x]. This function takes a
number and produces two results: one negated and one that’s unchanged.
So when we use>>=to feed this list to the function, every number is negated
and also kept unchanged. Thexfrom the lambda takes on every value from
the list that’s fed to it.
To see how this is achieved, we can just follow the implementation. First,
we start with the list[3,4,5]. Then we map the lambda over it and get the
following result:
```
```
[[3,-3],[4,-4],[5,-5]]
```
```
The lambda isapplied to every element, and we get a list of lists. Finally,
we just flatten the list, and voilà, we’ve applied a nondeterministic function
to a nondeterministic value!
Nondeterminism also includes support for failure. The empty list[]is
pretty much the equivalent ofNothing, because it signifies the absence of a
result. That’s why failing is just defined as the empty list. The error message
gets thrown away. Let’s play around with lists that fail:
```
```
ghci> [] >>=\x -> ["bad","mad","rad"]
[]
ghci> [1,2,3] >>= \x -> []
[]
```
**286** Chapter 13


Inthe first line, an empty list is fed into the lambda. Because the list has
no elements, there are none to be passed to the function, so the result is
an empty list. This is similar to feedingNothingto a function. In the second
line, each element is passed to the function, but the element is ignored and
the function just returns an empty list. Because the function fails for every
element that goes in it, the result is a failure.
Just as withMaybevalues, we can chain several lists with>>=, propagating
the nondeterminism:

ghci>[1,2] >>= \n -> ['a','b'] >>= \ch -> return (n, ch)
[(1,'a'),(1,'b'),(2,'a'),(2,'b')]

Thenumbers from the list
[1,2]are bound ton, and the
characters from the list['a','b']
are bound toch. Then we do
return (n, ch)(or[(n, ch)]),
which means taking a pair of
(n, ch)and putting it in a default
minimal context. In this case, it’s
making the smallest possible list
that still presents(n, ch)as the
result and features as little non-
determinism as possible. Its ef-
fect on the context is minimal.
We’re saying, “For every element
in[1,2], go over every element in
['a','b']and produce a tuple of one element from each list.”
Generally speaking, becausereturntakes a value and wraps it in a min-
imal context, it doesn’t have any extra effect (like failing inMaybeor result-
ing in more nondeterminism for lists), but it does present something as its
result.
When you have nondeterministic values interacting, you can view their
computation as a tree where every possible result in a list represents a sepa-
rate branch. Here’s the previous expression rewritten indonotation:

listOfTuples:: [(Int, Char)]
listOfTuples = do
n <- [1,2]
ch <- ['a','b']
return (n, ch)

Thismakes it a bit more obvious thatntakes on every value from[1,2]
andchtakes on every value from['a','b']. Just as withMaybe, we’re extract-
ing the elements from the monadic values and treating them like normal
values, and>>=takes care of the context for us. The context in this case is
nondeterminism.

```
AFistfulofMonads 287
```

## do Notation and List Comprehensions......................................

```
Using lists withdonotation might remind you of something you’ve seen be-
fore. For instance, check out the following piece of code:
```
```
ghci>[ (n, ch) | n <- [1,2], ch <- ['a','b'] ]
[(1,'a'),(1,'b'),(2,'a'),(2,'b')]
```
```
Yes,list comprehensions! In ourdonotation example,nbecame every re-
sult from[1,2]. For every such result,chwas assigned a result from['a','b'],
and then the final line put(n, ch)into a default context (a singleton list) to
present it as the result without introducing any additional nondeterminism.
In this list comprehension, the same thing happened, but we didn’t need to
writereturnat the end to present(n, ch)as the result, because the output
part of a list comprehension did that for us.
In fact, list comprehensions are just syntactic sugar for using lists as
monads. In the end, list comprehensions and lists indonotation translate
to using>>=to do computations that feature nondeterminism.
```
## MonadPlus and the guard Function........................................

```
List comprehensions allow us to filter our output. For instance, we can filter
a list of numbers to search only for numbers whose digits contain a 7 :
```
```
ghci>[ x | x <- [1..50], '7' `elem` show x ]
[7,17,27,37,47]
```
```
Weapplyshowtoxto turn our number into a string, and then we check
if the character'7'is part of that string.
To see how filtering in list comprehensions translates to the list monad,
we need to check out theguardfunction and theMonadPlustype class.
TheMonadPlustype class is for monads that can also act as monoids. Here
is its definition:
```
```
classMonad m => MonadPlus m where
mzero :: m a
mplus :: m a -> m a -> m a
```
```
mzeroissynonymous withmemptyfrom theMonoidtype class, andmpluscor-
responds tomappend. Because lists are monoids as well as monads, they can be
made an instance of this type class:
```
```
instanceMonadPlus [] where
mzero = []
mplus = (++)
```
**288** Chapter 13


Forlists,mzerorepresents a nondeterministic computation that has no
results at all—a failed computation.mplusjoins two nondeterministic values
into one. Theguardfunction is defined like this:

guard:: (MonadPlus m) => Bool -> m ()
guard True = return ()
guard False = mzero

guardtakesa Boolean value. If that value isTrue, guard takes a()and
puts it in a minimal default context that still succeeds. If the Boolean value
isFalse, guard makes a failed monadic value. Here it is in action:

ghci>guard (5 > 2) :: Maybe ()
Just ()
ghci> guard (1 > 2) :: Maybe ()
Nothing
ghci> guard (5 > 2) :: [()]
[()]
ghci> guard (1 > 2) :: [()]
[]

Thislooks interesting, but how is it useful? In the list monad, we use it
to filter out nondeterministic computations:

ghci>[1..50] >>= (\x -> guard ('7' `elem` show x) >> return x)
[7,17,27,37,47]

Theresult here is the same as the result of our previous list comprehen-
sion. How doesguardachieve this? Let’s first see howguardfunctions in con-
junction with>>:

ghci>guard (5 > 2) >> return "cool" :: [String]
["cool"]
ghci> guard (1 > 2) >> return "cool" :: [String]
[]

Ifguardsucceeds,the result contained within it is an empty tuple. So
then we use>>to ignore that empty tuple and present something else as the
result. However, ifguardfails, then so will thereturnlater on, because feed-
ing an empty list to a function with>>=always results in an empty list.guard
basically says, “If this Boolean isFalse, then produce a failure right here.
Otherwise, make a successful value that has a dummy result of()inside it.”
All this does is to allow the computation to continue.

```
AFistfulofMonads 289
```

```
Here’sthe previous example rewritten indonotation:
```
```
sevensOnly:: [Int]
sevensOnly = do
x <- [1..50]
guard ('7' `elem` show x)
return x
```
```
Hadwe forgotten to presentxas the final result by usingreturn, the re-
sulting list would just be a list of empty tuples. Here’s this again in the form
of a list comprehension:
```
```
ghci>[ x | x <- [1..50], '7' `elem` show x ]
[7,17,27,37,47]
```
```
Sofiltering in list comprehensions is the same as usingguard.
```
## A Knight’s Quest.........................................................

```
Here’s a problem that really lends itself to being solved with nondetermin-
ism. Say we have a chessboard and only one knight piece on it. We want to
find out if the knight can reach a certain position in three moves. We’ll just
use a pair of numbers to represent the knight’s position on the chessboard.
The first number will determine the column he is in, and the second num-
ber will determine the row.
```
```
Let’smake a type synonym for the knight’s current position on the
chessboard:
```
```
typeKnightPos = (Int, Int)
```
**290** Chapter 13


Nowsuppose that the knight starts at(6, 2). Can he get to(6, 1)in
exactly three moves? What’s the best move to make next from his current
position? I know—how about all of them! We have nondeterminism at our
disposal, so instead of picking one move, let’s pick all of them at once. Here
is a function that takes the knight’s position and returns all of his next moves:

moveKnight:: KnightPos -> [KnightPos]
moveKnight (c,r) = do
(c', r') <- [(c+2,r-1),(c+2,r+1),(c-2,r-1),(c-2,r+1)
,(c+1,r-2),(c+1,r+2),(c-1,r-2),(c-1,r+2)
]
guard (c' `elem` [1..8] && r' `elem` [1..8])
return (c', r')

Theknight can always take one step horizontally or vertically and two
steps horizontally or vertically, but his movement must be both horizontal
and vertical.(c', r')takes on every value from the list of movements and
thenguardmakes sure that the new move,(c', r'), is still on the board. If it’s
not, it produces an empty list, which causes a failure andreturn (c', r')isn’t
carried out for that position.
This function can also be written without the use of lists as monads.
Here is how to write it usingfilter:

moveKnight:: KnightPos -> [KnightPos]
moveKnight (c, r) = filter onBoard
[(c+2,r-1),(c+2,r+1),(c-2,r-1),(c-2,r+1)
,(c+1,r-2),(c+1,r+2),(c-1,r-2),(c-1,r+2)
]
where onBoard (c, r) = c `elem` [1..8] && r `elem` [1..8]

Bothof these versions do the same thing, so pick the one that looks
nicer to you. Let’s give it a whirl:

ghci>moveKnight (6, 2)
[(8,1),(8,3),(4,1),(4,3),(7,4),(5,4)]
ghci> moveKnight (8, 1)
[(6,2),(7,3)]

Workslike a charm! We take one position, and we just carry out all the
possible moves at once, so to speak.
So now that we have a nondeterministic next position, we just use>>=to
feed it tomoveKnight. Here’s a function that takes a position and returns all
the positions that you can reach from it in three moves:

in3:: KnightPos -> [KnightPos]
in3 start = do
first <- moveKnight start

```
AFistfulofMonads 291
```

```
second<- moveKnight first
moveKnight second
```
```
Ifyou pass it(6, 2), the resulting list is quite big. This is because if there
are several ways to reach some position in three moves, the move crops up in
the list several times.
Here’s the preceding code withoutdonotation:
```
```
in3start = return start >>= moveKnight >>= moveKnight >>= moveKnight
```
```
Using>>=oncegives us all possible moves from the start. When we use
>>=the second time, for every possible first move, every possible next move is
computed, and the same goes for the last move.
Putting a value in a default context by applyingreturnto it and then
feeding it to a function with>>=is the same as just normally applying the
function to that value, but we did it here anyway for style.
Now, let’s make a function that takes two positions and tells us if you can
get from one to the other in exactly three steps:
```
```
canReachIn3:: KnightPos -> KnightPos -> Bool
canReachIn3 start end = end `elem` in3 start
```
```
Wegenerate all the possible positions in three steps, and then we see if
the position we’re looking for is among them. Here’s how to check if we can
get from(6, 2)to(6, 1)in three moves:
```
```
ghci>(6, 2) `canReachIn3` (6, 1)
True
```
```
Yes!How about from(6, 2)to(7, 3)?
```
```
ghci>(6, 2) `canReachIn3` (7, 3)
False
```
```
No!As an exercise, you can change this function so that when you can
reach one position from the other, it tells you which move to take. In Chap-
ter 14, you’ll see how to modify this function so that we also pass it the num-
ber of moves to take, instead of that number being hardcoded as it is now.
```
## Monad Laws.....................................................................

```
Justlike functors and applicative func-
tors, monads come with a few laws that
all monad instances must abide by. Just
because something is made an instance
of theMonadtype class doesn’t mean that
it’s actually a monad. For a type to truly
be a monad, the monad laws must hold
```
**292** Chapter 13


forthat type. These laws allow us to make reasonable assumptions about the
type and its behavior.
Haskell allows any type to be an instance of any type class as long as the
types check out. It can’t check if the monad laws hold for a type though, so
if we’re making a new instance of theMonadtype class, we need to be reason-
ably sure that all is well with the monad laws for that type. We can rely on
the types that come with the standard library to satisfy the laws, but when we
go about making our own monads, we need to manually check whether the
laws hold. But don’t worry, they’re not complicated.

## Left Identity..............................................................

The first monad law states that if we take a value, put it in a default con-
text withreturn, and then feed it to a function by using>>=, that’s the same
as just taking the value and applying the function to it. To put it formally,
return x >>= fis the same damn thing asfx.
If you look at monadic values as values with a context, andreturnas tak-
ing a value and putting it in a default minimal context that still presents that
value as the function’s result, this law makes sense. If that context is really
minimal, feeding this monadic value to a function shouldn’t be much differ-
ent than just applying the function to the normal value—and indeed, it isn’t
different at all.
For theMaybemonad,returnis defined asJust. TheMaybemonad is all
about possible failure, and if we have a value that we want to put in such
a context, treating it as a successful computation makes sense, because we
know what the value is. Here are some examples ofreturnusage withMaybe:

ghci>return 3 >>= (\x -> Just (x+100000))
Just 100003
ghci> (\x -> Just (x+100000)) 3
Just 100003

Forthe list monad,returnputs something in a singleton list. The>>=im-
plementation for lists goes over all the values in the list and applies the func-
tion to them. However, since there’s only one value in a singleton list, it’s
the same as applying the function to that value:

ghci>return "WoM" >>= (\x -> [x,x,x])
["WoM","WoM","WoM"]
ghci> (\x -> [x,x,x]) "WoM"
["WoM","WoM","WoM"]

You’velearned that forIO, usingreturnmakes an I/O action that has no
side effects but just presents a value as its result. So it makes sense that this
law holds forIOas well.

```
AFistfulofMonads 293
```

## Right Identity............................................................

```
The second law states that if we have a monadic value and we use>>=to feed
it toreturn, the result is our original monadic value. Formally,m >>= returnis
no different than justm.
This law might be a bit less obvious than the first one. Let’s take a look
at why it should hold. When we feed monadic values to functions by using
>>=, those functions take normal values and return monadic ones.returnis
also one such function, if you consider its type.
returnputs a value in a minimal context that still presents that value as
its result. This means that, for instance, forMaybe, it doesn’t introduce any
failure; for lists, it doesn’t introduce any extra nondeterminism.
Here’s a test run for a few monads:
```
```
ghci>Just "move on up" >>= (\x -> return x)
Just "move on up"
ghci> [1,2,3,4] >>= (\x -> return x)
[1,2,3,4]
ghci> putStrLn "Wah!" >>= (\x -> return x)
Wah!
```
```
Inthis list example, the implementation for>>=is as follows:
```
```
xs>>= f = concat (map f xs)
```
```
Sowhen we feed[1,2,3,4]toreturn, firstreturngets mapped over[1,2,3,
4], resulting in[[1],[2],[3],[4]]. Then this is concatenated, and we have our
original list.
Left identity and right identity are basically laws that describe howreturn
should behave. It’s an important function for making normal values into
monadic ones, and it wouldn’t be good if the monadic value that it pro-
duced had any more than the minimal context needed.
```
## Associativity.............................................................

```
The final monad law says that when we have a chain of monadic function ap-
plications with>>=, it shouldn’t matter how they’re nested. Formally written,
doing(m >>= f) >>= gis just like doingm >>= (\x -> f x >>= g).
Hmmm, now what’s going on here? We have one monadic value,m, and
two monadic functions,fandg. When we’re using(m >>= f) >>= g, we’re
feedingmtof, which results in a monadic value. Then we feed that monadic
value tog. In the expressionm >>= (\x -> f x >>= g), we take a monadic value
and we give it to a function that feeds the result offxtog. It’s not easy to
see how those two are equal, so let’s take a look at an example that makes
this equality a bit clearer.
```
**294** Chapter 13


Rememberwhen we had our tightrope walker, Pierre, walk a rope while
birds landed on his balancing pole? To simulate birds landing on his balanc-
ing pole, we made a chain of several functions that might produce failure:

ghci>return (0, 0) >>= landRight 2 >>= landLeft 2 >>= landRight 2
Just (2,4)

Westarted withJust (0, 0)and then bound that value to the next mo-
nadic function,landRight 2. The result of that was another monadic value,
which got bound to the next monadic function, and so on. If we were to ex-
plicitly parenthesize this, we would write the following:

ghci>((return (0, 0) >>= landRight 2) >>= landLeft 2) >>= landRight 2
Just (2,4)

```
Butwe can also write the routine like this:
```
return(0, 0) >>= (\x ->
landRight 2 x >>= (\y ->
landLeft 2 y >>= (\z ->
landRight 2 z)))

return(0, 0)is the same asJust (0, 0), and when we feed it to the lambda,
thexbecomes(0, 0).landRighttakes a number of birds and a pole (a tuple
of numbers), and that’s what it gets passed. This results in aJust (0, 2), and
when we feed this to the next lambda,yis(0, 2). This goes on until the final
bird landing produces aJust (2, 4), which is indeed the result of the whole
expression.
So it doesn’t matter how you nest feeding values to monadic functions.
What matters is their meaning. Let’s consider another way to look at this
law. Suppose we compose two functions namedfandg:

(.):: (b -> c) -> (a -> b) -> (a -> c)
f. g = (\x -> f (g x))

Ifthe type ofgisa -> band the type offisb -> c, we arrange them into
a new function that has a type ofa -> c, so that its parameter is passed be-
tween those functions. Now what if those two functions were monadic? What
if the values they returned were monadic values? If we had a function of
typea -> m b, we couldn’t just pass its result to a function of typeb -> m c,
because that function accepts a normalb, not a monadic one. We could,
however, use>>=to make that happen.

(<=<):: (Monad m) => (b -> m c) -> (a -> m b) -> (a -> m c)
f <=< g = (\x -> g x >>= f)

```
AFistful of Monads 295
```

```
Sonow we can compose two monadic functions:
```
```
ghci>let f x = [x,-x]
ghci> let g x = [x*3,x*2]
ghci> let h = f <=< g
ghci> h 3
[9,-9,6,-6]
```
```
Okay,that’s cool. But what does that have to do with the associativity
law? Well, when we look at the law as a law of compositions, it states that
f <=< (g <=< h)should be the same as(f <=< g) <=< h. This is just another
way of saying that for monads, the nesting of operations shouldn’t matter.
If we translate the first two laws to use<=<, then the left identity law states
that for every monadic functionf,f <=< returnis the same as writing justf.
The right identity law says thatreturn <=< fis also no different fromf. This is
similar to how iffis a normal function,(f. g). his the same asf. (g. h),
f. idis always the same asf, andid. fis also justf.
In this chapter, we took a look at the basics of monads and learned how
theMaybemonad and the list monad work. In the next chapter, we’ll explore
a whole bunch of other cool monads, and we’ll also make our own.
```
**296** Chapter 13


# 14

## FORAFEWMONADSMORE

You’ve seen how monads can be used to take values

with contexts and apply them to functions, and how

using>>=ordonotation allows you to focus on the

values themselves, while Haskell handles the context

for you.

You’vemet theMaybemonad and seen how it
adds a context of possible failure to values. You’ve
learned about the list monad and seen how it lets
us easily introduce nondeterminism into our pro-
grams. You’ve also learned how to work in theIO
monad, even before you knew what a monad was!
In this chapter, we’ll cover a few other mon-
ads. You’ll see how they can make your programs
clearer by letting you treat all sorts of values as
monadic ones. Further exploration of monads
will also solidify your intuition for recognizing and
working with monads.
The monads that we’ll be exploring are all part
of themtlpackage. (A Haskell _package_ is a collec-
tion of modules.) Themtlpackage comes with the
Haskell Platform, so you probably already have
it. To check if you do, type **ghc-pkg list** from the


```
commandline. This will show which Haskell packages you have installed,
and one of them should bemtl, followed by a version number.
```
## Writer? I Hardly Knew Her!.......................................................

```
We’ve loaded our gun with theMaybemonad, the list monad, and theIOmo-
nad. Now let’s put theWritermonad in the chamber and see what happens
when we fire it!
Whereas theMaybemonad is for values with an added context of failure,
and the list monad is for nondeterministic values, theWritermonad is for
values that have another value attached that acts as a sort of log value.Writer
allows us to do computations while making sure that all the log values are
combined into one log value, which then is attached to the result.
For instance, we might want to equip our values with strings that explain
what’s going on, probably for debugging purposes. Consider a function that
takes a number of bandits in a gang and tells us if that’s a big gang. It’s a
very simple function:
```
```
isBigGang:: Int -> Bool
isBigGang x = x > 9
```
```
Now,what if instead of just giving us aTrueorFalsevalue, we want the
function to also return a log string that says what it did? Well, we just make
that string and return it alongside ourBool:
```
```
isBigGang:: Int -> (Bool, String)
isBigGang x = (x > 9, "Compared gang size to 9.")
```
```
Sonow, instead of just returning aBool, we return a tuple, where the
first component of the tuple is the actual value and the second component
is the string that accompanies that value. There’s some added context to our
value now. Let’s give this a go:
```
```
ghci>isBigGang 3
(False,"Compared gang size to 9.")
ghci> isBigGang 30
(True,"Compared gang size to 9.")
```
```
Sofar, so good.isBigGangtakes a normal value and returns a value with a
context. As you’ve just seen, feeding it a normal value is not a problem. Now
what if we already have a value that has a log string attached to it, such as
(3, "Smallish gang."), and we want to feed it toisBigGang? It seems like once
again, we’re faced with this question: If we have a function that takes a nor-
mal value and returns a value with a context, how do we take a value with a
context and feed it to the function?
```
**298** Chapter 14


Whenwe were exploring theMaybemonad in the
previous chapter, we made a functionapplyMaybe. This
function takes aMaybe avalue and a function of type
a -> Maybe b. We feed thatMaybe avalue into the func-
tion, even though the function takes a normalainstead
of aMaybe a. It does this by minding the context that
comes withMaybe avalues, which is that they are values
with possible failure. But inside thea -> Maybe bfunc-
tion, we can treat that value as just a normal value, be-
causeapplyMaybe(which later becomes>>=) takes care of
checking if it is aNothingor aJustvalue.
In the same vein, let’s make a function that takes a value with an at-
tached log—that is, an(a, String)value—and a function of typea -> (b, String),
and feeds that value into the function. We’ll call itapplyLog. But an(a, String)
value doesn’t carry with it a context of possible failure, but rather a context
of an additional log value. So,applyLogwill make sure that the log of the
original value isn’t lost, but is joined together with the log of the value that
results from the function. Here’s the implementation ofapplyLog:

applyLog:: (a, String) -> (a -> (b, String)) -> (b, String)
applyLog (x, log) f = let (y, newLog) = f x in (y, log ++ newLog)

Whenwe have a value with a context that we want to feed to a function,
we usually try to separate the actual value from the context, apply the func-
tion to the value, and then see whether the context is handled. In theMaybe
monad, we checked if the value was aJust x, and if it was, we took thatxand
applied the function to it. In this case, it’s very easy to find the actual value,
because we’re dealing with a pair where one component is the value and
the other a log. So, first, we just take the value, which isx, and we apply the
functionfto it. We get a pair of(y, newLog), whereyis the new result and
newLogis the new log. But if we returned that as the result, the old log value
wouldn’t be included in the result, so we return a pair of(y, log ++ newLog).
We use++to append the new log to the old one.
Here’sapplyLogin action:

ghci>(3, "Smallish gang.") `applyLog` isBigGang
(False,"Smallish gang.Compared gang size to 9.")
ghci> (30, "A freaking platoon.") `applyLog` isBigGang
(True,"A freaking platoon.Compared gang size to 9.")

Theresults are similar to before, except that now the number of people
in the gang has its accompanying log, which is included in the result log.

```
For a Few Monads More 299
```

```
Hereare a few more examples of usingapplyLog:
```
```
ghci>("Tobin", "Got outlaw name.") `applyLog` (\x -> (length x, "Applied length."))
(5,"Got outlaw name.Applied length.")
ghci> ("Bathcat", "Got outlaw name.") `applyLog` (\x -> (length x, "Applied length."))
(7,"Got outlaw name.Applied length.")
```
```
Seehow inside the lambda,xis just a normal string and not a tuple, and
howapplyLogtakes care of appending the logs?
```
## Monoids to the Rescue...................................................

```
Right now,applyLogtakes values of type(a, String), but is there a reason
that the log must be aString? It uses++to append the logs, so wouldn’t this
work on any kind of list, not just a list of characters? Sure, it would. We can
change its type to this:
```
```
applyLog:: (a, [c]) -> (a -> (b, [c])) -> (b, [c])
```
```
Nowthe log is a list. The type of values contained in the list must be the
same for the original list as well as for the list that the function returns. Oth-
erwise, we wouldn’t be able to use++to stick them together.
Would this work for bytestrings? There’s no reason it shouldn’t. How-
ever, the type we have now works only for lists. It seems as though we would
need to make a separateapplyLogfor bytestrings. But wait! Both lists and
bytestrings are monoids. As such, they are both instances of theMonoidtype
class, which means that they implement themappendfunction. And for both
lists and bytestrings,mappendis for appending. Watch it in action:
```
```
ghci>[1,2,3] `mappend` [4,5,6]
[1,2,3,4,5,6]
ghci> B.pack [99,104,105] `mappend` B.pack [104,117,97,104,117,97]
Chunk "chi" (Chunk "huahua" Empty)
```
```
Cool!Now ourapplyLogcan work for any monoid. We need to change
the type to reflect this, as well as the implementation, because we need to
change++tomappend:
```
```
applyLog:: (Monoid m) => (a, m) -> (a -> (b, m)) -> (b, m)
applyLog (x, log) f = let (y, newLog) = f x in (y, log `mappend` newLog)
```
```
Becausethe accompanying value can now be any monoid value, we no
longer need to think of the tuple as a value and a log; now we can think of it
as a value with an accompanying monoid value. For instance, we can have a
tuple that has an item name and an item price as the monoid value. We just
```
**300** Chapter 14


usetheSum newtypeto make sure that the prices are added as we operate with
the items. Here’s a function that adds drink to some cowboy food order:

importData.Monoid

type Food = String
type Price = Sum Int

addDrink :: Food -> (Food, Price)
addDrink "beans" = ("milk", Sum 25)
addDrink "jerky" = ("whiskey", Sum 99)
addDrink _ = ("beer", Sum 30)

Weuse strings to represent foods and anIntin aSum newtypewrapper to
keep track of how many cents something costs. As a reminder, doingmappend
withSumresults in the wrapped values being added together:

ghci>Sum 3 `mappend` Sum 9
Sum {getSum = 12}

TheaddDrinkfunctionis pretty simple. If we’re eating beans, it returns
"milk"along withSum 25, so 25 cents wrapped inSum. If we’re eating jerky, we
drink whiskey. And if we’re eating anything else, we drink beer. Just nor-
mally applying this function to a food wouldn’t be terribly interesting right
now. But usingapplyLogto feed a food that comes with a price itself into this
function is worth a look:

ghci>("beans", Sum 10) `applyLog` addDrink
("milk",Sum {getSum = 35})
ghci> ("jerky", Sum 25) `applyLog` addDrink
("whiskey",Sum {getSum = 124})
ghci> ("dogmeat", Sum 5) `applyLog` addDrink
("beer",Sum {getSum = 35})

Milkcosts 25 cents, but if we have it with beans that cost 25 cents, we’ll
end up paying 35 cents.
Now it’s clear how the attached value doesn’t always need to be a log. It
can be any monoid value, and how two such values are combined depends
on the monoid. When we were doing logs, they were appended, but now,
the numbers are being added up.
Because the value thataddDrinkreturns is a tuple of type(Food, Price), we
can feed that result toaddDrinkagain, so that it tells us what we should drink
along with our meal and how much that will cost us. Let’s give it a shot:

ghci>("dogmeat", Sum 5) `applyLog` addDrink `applyLog` addDrink
("beer",Sum {getSum = 65})

```
For a Few Monads More 301
```

```
Adding a drinkto some dog meat results in a beer and an additional 30
cents, so("beer", Sum 35). And if we useapplyLogto feed that toaddDrink, we
get another beer, and the result is("beer", Sum 65).
```
## The Writer Type.........................................................

```
Now that you’ve seen how a value with an attached monoid acts like a
monadic value, let’s examine theMonadinstance for types of such values. The
Control.Monad.Writermodule exports theWriter w atype along with itsMonad
instance and some useful functions for dealing with values of this type.
To attach a monoid to a value, we just need to put them together in a
tuple. TheWriter w atype is just anewtypewrapper for this. Its definition is
very simple:
```
```
newtype Writer wa = Writer { runWriter :: (a, w) }
```
```
It’s wrapped inanewtypeso that it can be made an instance ofMonadand
so that its type is separate from a normal tuple. Theatype parameter repre-
sents the type of the value, and thewtype parameter represents the type of
the attached monoid value.
TheControl.Monad.Writermodule reserves the right to change the way
it internally implements theWriter w atype, so it doesn’t export theWriter
value constructor. However, it does export thewriterfunction, which does
the same thing that theWriterconstructor would do. Use it when you want
to take a tuple and make aWritervalue from it.
Because theWritervalue constructor is not exported, you also can’t pat-
tern match against it. Instead, you need to use therunWriterfunction, which
takes a tuple that’s wrapped in aWriter newtypeand unwraps it, returning a
simple tuple.
ItsMonadinstance is defined like so:
```
```
instance (Monoid w)=> Monad (Writer w) where
return x = Writer (x, mempty)
(Writer (x, v)) >>= f = let (Writer (y, v')) = f x in Writer (y, v `mappend` v')
```
```
First, let’s examine>>=. Its imple-
mentation is essentially the same as
applyLog, only now that our tuple is
wrapped in theWriter newtype, we need
to unwrap it when pattern matching. We
take the valuexand apply the function
fto it. This gives us gives us aWriter w a
value, and we use aletexpression to pat-
tern match on it. We presentyas the
new result and usemappendto combine
the old monoid value with the new one. We pack that up with the result
value in a tuple and then wrap that with theWriterconstructor so that our
result is aWritervalue, instead of just an unwrapped tuple.
```
**302** Chapter 14


So,what aboutreturn? It must take a value and put it in a default min-
imal context that still presents that value as the result. What would such a
context be forWritervalues? If we want the accompanying monoid value to
affect other monoid values as little as possible, it makes sense to usemempty.
memptyis used to present identity monoid values, such as""andSum 0and
empty bytestrings. Whenever we usemappendbetweenmemptyand some other
monoid value, the result is that other monoid value. So, if we usereturnto
make aWritervalue and then use>>=to feed that value to a function, the
resulting monoid value will be only what the function returns.
Let’s usereturnon the number 3 a bunch of times, pairing it with a dif-
ferent monoid each time:

ghci>runWriter (return 3 :: Writer String Int)
(3,"")
ghci> runWriter (return 3 :: Writer (Sum Int) Int)
(3,Sum {getSum = 0})
ghci> runWriter (return 3 :: Writer (Product Int) Int)
(3,Product {getProduct = 1})

BecauseWriterdoesn’thave aShowinstance, we usedrunWriterto convert
ourWritervalues to normal tuples that can be shown. ForString, the monoid
value is the empty string. WithSum, it’s 0 , because if we add 0 to something,
that something stays the same. ForProduct, the identity is 1.
TheWriterinstance doesn’t feature an implementation forfail, so if a
pattern match fails indonotation,erroris called.

## Using do Notation with Writer............................................

Now that we have aMonadinstance, we’re free to usedonotation forWriter
values. It’s handy when we have severalWritervalues and want to do stuff
with them. As with other monads, we can treat them as normal values, and
the context gets taken care of for us. In this case, all the monoid values that
come attached aremappended, and so are reflected in the final result.
Here’s a simple example of usingdonotation withWriterto multiply two
numbers:

importControl.Monad.Writer

logNumber :: Int -> Writer [String] Int
logNumber x = writer (x, ["Got number: " ++ show x])

multWithLog :: Writer [String] Int
multWithLog = do
a <- logNumber 3
b <- logNumber 5
return (a*b)

```
For a Few Monads More 303
```

```
logNumbertakesa number and makes aWritervalue out of it. Notice how
we used thewriterfunction to construct aWritervalue, instead of directly
using theWritervalue constructor. For the monoid, we use a list of strings,
and we equip the number with a singleton list that just says that we have
that number.multWithLogis aWritervalue that multiplies 3 and 5 and makes
sure that their attached logs are included in the final log. We usereturnto
presenta*bas the result. Becausereturnjust takes something and puts it in
a minimal context, we can be sure that it won’t add anything to the log.
Here’s what we see if we run this code:
```
```
ghci>runWriter multWithLog
(15,["Got number: 3","Got number: 5"])
```
```
Sometimes,we just want some monoid value to be included at some
particular point. For this, thetellfunction is useful. It’s part of the
MonadWritertype class. In the case ofWriter, it takes a monoid value, like
["This is going on"], and creates aWritervalue that presents the dummy
value()as its result, but has the desired monoid value attached. When we
have a monadic value that has()as its result, we don’t bind it to a variable.
Here’smultWithLogwith some extra reporting included:
```
```
multWithLog:: Writer [String] Int
multWithLog = do
a <- logNumber 3
b <- logNumber 5
tell ["Gonna multiply these two"]
return (a*b)
```
```
It’simportant thatreturn (a*b)is the last line, because the result of the
last line in adoexpression is the result of the wholedoexpression. Had we
puttellas the last line, the result of thisdoexpression would be(). We would
lose the result of the multiplication. However, the log would be the same.
Here’s this in action:
```
```
ghci>runWriter multWithLog
(15,["Got number: 3","Got number: 5","Gonna multiply these two"])
```
## Adding Logging to Programs..............................................

```
Euclid’s algorithm takes two numbers and computes their greatest common
divisor—that is, the biggest number that still divides both of them. Haskell
already features thegcdfunction, which does exactly this, but let’s imple-
ment our own function and then equip it with logging capabilities. Here’s
the normal algorithm:
```
```
gcd':: Int -> Int -> Int
gcd' a b
```
**304** Chapter 14


```
|b == 0 = a
| otherwise = gcd' b (a `mod` b)
```
```
Thealgorithm is very simple. First, it checks if the second number is
```
0. If it is, then the result is the first number. If it isn’t, then the result is the
greatest common divisor of the second number and the remainder of divid-
ing the first number with the second one.
    For instance, if we want to know what the greatest common divisor of 8
and 3 is, we just follow this algorithm. Because 3 isn’t 0, we need to find the
greatest common divisor of 3 and 2 (if we divide 8 by 3, the remainder is 2).
Next, we find the greatest common divisor of 3 and 2. 2 still isn’t 0, so now
we have have 2 and 1. The second number isn’t 0, so we run the algorithm
again for 1 and 0, as dividing 2 by 1 gives us a remainder of 0. And finally,
because the second number is now 0, the final result is 1. Let’s see if our
code agrees:

ghci>gcd' 8 3
1

Itdoes. Very good! Now, we want to equip our result with a context,
and the context will be a monoid value that acts as a log. As before, we’ll
use a list of strings as our monoid. So, this should be the type of our new
gcd'function:

gcd':: Int -> Int -> Writer [String] Int

Allthat’s left now is to equip our function with log values. Here is
the code:

importControl.Monad.Writer

gcd' :: Int -> Int -> Writer [String] Int
gcd' a b
| b == 0 = do
tell ["Finished with " ++ show a]
return a
| otherwise = do
tell [show a ++ " mod " ++ show b ++ " = " ++ show (a `mod` b)]
gcd' b (a `mod` b)

Thisfunction takes two normalIntvalues and returns aWriter [String]
Int—that is, anIntthat has a log context. In the case wherebis 0 , instead
of just givingaas the result, we use adoexpression to put together aWriter
value as a result. First, we usetellto report that we’re finished, and then we
usereturnto presentaas the result of thedoexpression. Instead of thisdo
expression, we could have also written this:

writer(a, ["Finished with " ++ show a])

```
For a Few Monads More 305
```

```
However,I think thedoexpression is easier to read.
Next, we have the case whenbisn’t 0. In this case, we log that we’re us-
ingmodto figure out the remainder of dividingaandb. Then the second line
of thedoexpression just recursively callsgcd'. Remember thatgcd'now ulti-
mately returns aWritervalue, so it’s perfectly valid thatgcd' b (a `mod` b)is a
line in adoexpression.
Let’s try out our newgcd'. Its result is aWriter [String] Intvalue, and if
we unwrap that from itsnewtype, we get a tuple. The first part of the tuple is
the result. Let’s see if it’s okay:
```
```
ghci>fst $ runWriter (gcd' 8 3)
1
```
```
Good!Now what about the log? Because the log is a list of strings, let’s
usemapM_ putStrLnto print those strings on the screen:
```
```
ghci>mapM_ putStrLn $ snd $ runWriter (gcd' 8 3)
8 mod 3 = 2
3 mod 2 = 1
2 mod 1 = 0
Finished with 1
```
```
Ithink it’s awesome how we were able to change our ordinary algo-
rithm to one that reports what it does as it goes along. And we did this just
by changing normal values to monadic values. We let the implementation of
>>=forWritertake care of the logs for us.
You can add a logging mechanism to pretty much any function. You just
replace normal values withWritervalues where you want and change normal
function application to>>=(ordoexpressions if it increases readability).
```
## Inefficient List Construction................................................

```
Whenusing theWritermonad, you need to be careful
which monoid to use, because using lists can some-
times turn out to be very slow. Lists use++formappend,
and using++to add something to the end of a list is
slow if that list is really long.
In ourgcd'function, the logging is fast because
the list appending ends up looking like this:
```
```
a++ (b ++ (c ++ (d ++ (e ++ f))))
```
```
Alist is a data structure that’s constructed from
left to right. This is efficient, because we first fully con-
struct the left part of a list and only then add a longer
```
**306** Chapter 14


liston the right. But if we’re not careful, using theWritermonad can pro-
duce list appending that looks like this:

((((a++ b) ++ c) ++ d) ++ e) ++ f

Thisassociates to the left instead of to the right. It’s inefficient because
every time it wants to add the right part to the left part, it must construct the
left part all the way from the beginning!
The following function works likegcd', but it logs stuff in reverse. First,
it produces the log for the rest of the procedure, and then it adds the cur-
rent step to the end of the log.

importControl.Monad.Writer

gcdReverse :: Int -> Int -> Writer [String] Int
gcdReverse a b
| b == 0 = do
tell ["Finished with " ++ show a]
return a
| otherwise = do
result <- gcdReverse b (a `mod` b)
tell [show a ++ " mod " ++ show b ++ " = " ++ show (a `mod` b)]
return result

Itdoes the recursion first and binds its resulting value toresult. Then it
adds the current step to the log, but the current step goes at the end of the
log that was produced by the recursion. At the end, it presents the result of
the recursion as the final result. Here it is in action:

ghci>mapM_ putStrLn $ snd $ runWriter (gcdReverse 8 3)
Finished with 1
2 mod 1 = 0
3 mod 2 = 1
8 mod 3 = 2

Thisfunction is inefficient because it ends up associating the use of++to
the left instead of to the right.
Because lists can sometimes be inefficient when repeatedly appended
in this manner, it’s best to use a data structure that always supports efficient
appending. One such data structure is the difference list.

## Using Difference Lists.....................................................

While similar to a normal list, a _difference list_ is actually a function that takes
a list and prepends another list to it. For example, the difference list equiva-
lent of a list like[1,2,3]is the function\xs -> [1,2,3] ++ xs. A normal empty
list is[], whereas an empty difference list is the function\xs -> [] ++ xs.

```
For a Few Monads More 307
```

```
Differencelists support efficient appending. When we append two nor-
mal lists with++, the code must walk all the way to the end of the list on the
left of++, and then stick the other one there. But what if we take the differ-
ence list approach and represent our lists as functions?
Appending two difference lists can be done like so:
```
```
f`append` g = \xs -> f (g xs)
```
```
Rememberthatfandgare functions that take lists and prepend some-
thing to them. For instance, iffis the function("dog"++)(just another way of
writing\xs -> "dog" ++ xs) andgis the function("meat"++), thenf `append` g
makes a new function that’s equivalent to the following:
```
```
\xs-> "dog" ++ ("meat" ++ xs)
```
```
We’veappended two difference lists just by making a new function that
first applies one difference list to some list and then to the other.
Let’s make anewtypewrapper for difference lists so that we can easily give
them monoid instances:
```
```
newtypeDiffList a = DiffList { getDiffList :: [a] -> [a] }
```
```
Thetype that we wrap is[a] -> [a], because a difference list is just a
function that takes a list and returns another list. Converting normal lists
to difference lists and vice versa is easy:
```
```
toDiffList:: [a] -> DiffList a
toDiffList xs = DiffList (xs++)
```
```
fromDiffList :: DiffList a -> [a]
fromDiffList (DiffList f) = f []
```
```
Tomake a normal list into a difference list, we just do what we did be-
fore and make it a function that prepends it to another list. Because a differ-
ence list is a function that prepends something to another list, if we just want
that something, we apply the function to an empty list!
Here’s theMonoidinstance:
```
```
instanceMonoid (DiffList a) where
mempty = DiffList (\xs -> [] ++ xs)
(DiffList f) `mappend` (DiffList g) = DiffList (\xs -> f (g xs))
```
```
Noticehow for lists,memptyis just theidfunction, andmappendis actually
just function composition. Let’s see if this works:
```
```
ghci>fromDiffList (toDiffList [1,2,3,4] `mappend` toDiffList [1,2,3])
[1,2,3,4,1,2,3]
```
**308** Chapter 14


```
Tip-top!Now we can increase the efficiency of ourgcdReversefunction by
making it use difference lists instead of normal lists:
```
importControl.Monad.Writer

gcd' :: Int -> Int -> Writer (DiffList String) Int
gcd' a b
| b == 0 = do
tell (toDiffList ["Finished with " ++ show a])
return a
| otherwise = do
result <- gcd' b (a `mod` b)
tell (toDiffList [show a ++ " mod " ++ show b ++ " = " ++ show (a `mod` b)])
return result

```
Wejust needed to change the type of the monoid from[String]to
DiffList Stringand then when usingtell, convert our normal lists into dif-
ference lists withtoDiffList. Let’s see if the log gets assembled properly:
```
```
ghci>mapM_ putStrLn. fromDiffList. snd. runWriter $ gcdReverse 110 34
Finished with 2
8 mod 2 = 0
34 mod 8 = 2
110 mod 34 = 8
```
```
WedogcdReverse 110 34, then userunWriterto unwrap it from thenewtype,
then applysndto that to just get the log, then applyfromDiffListto convert it
to a normal list, and, finally, print its entries to the screen.
```
## Comparing Performance..................................................

```
To get a feel for just how much difference lists may improve your perfor-
mance, consider the following function. It just counts down from some
number to zero but produces its log in reverse, likegcdReverse, so that the
numbers in the log will actually be counted up.
```
```
finalCountDown:: Int -> Writer (DiffList String) ()
finalCountDown 0 = do
tell (toDiffList ["0"])
finalCountDown x = do
finalCountDown (x-1)
tell (toDiffList [show x])
```
```
Ifwe give it 0 , it just logs that value. For any other number, it first counts
down its predecessor to 0 , and then appends that number to the log. So, if
we applyfinalCountDownto 100 , the string"100"will come last in the log.
```
```
For a Few Monads More 309
```

```
Ifyou load this function in GHCi and apply it to a big number, like
500000 , you’ll see that it quickly starts counting from 0 onward:
```
```
ghci>mapM_ putStrLn. fromDiffList. snd. runWriter $ finalCountDown 500000
0
1
2
```
```
However,if you change it to use normal lists instead of difference lists,
like so:
```
```
finalCountDown:: Int -> Writer [String] ()
finalCountDown 0 = do
tell ["0"]
finalCountDown x = do
finalCountDown (x-1)
tell [show x]
```
```
andthen tell GHCi to start counting:
```
```
ghci>mapM_ putStrLn. snd. runWriter $ finalCountDown 500000
```
```
you’llsee that the counting is really slow.
Of course, this is not the proper and scientific way to test the speed of
your programs. However, we were able to see that, in this case, using dif-
ference lists starts producing results immediately, whereas normal lists take
forever.
Oh, by the way, the song “Final Countdown” by Europe is now stuck in
your head. Enjoy!
```
## Reader? Ugh, Not This Joke Again.................................................

```
InChapter 11, you saw that the function
type(->) ris an instance ofFunctor. Map-
ping a functionfover a functiongwill make
a function that takes the same thing asg, ap-
pliesgto it, and then appliesfto that result.
So basically, we’re making a new function
that’s likeg, but before returning its result,fis applied to that result as well.
Here’s an example:
```
```
ghci>let f = (*5)
ghci> let g = (+3)
ghci> (fmap f g) 8
55
```
**310** Chapter 14


You’vealso seen that functions are applicative functors. They allow us to
operate on the eventual results of functions as if we already had their results.
Here’s an example:

ghci>let f = (+) <$> (*2) <*> (+10)
ghci> f 3
19

Theexpression(+) <$> (*2) <*> (+10)makes a function that takes a
number, gives that number to(*2)and(+10), and then adds together the
results. For instance, if we apply this function to 3 , it applies both(*2)and
(+10)to 3 , giving 6 and 13. Then it calls(+)with 6 and 13 , and the result is 19.

## Functions As Monads.....................................................

Not only is the function type(->) ra functor and an applicative functor,
but it’s also a monad. Just like other monadic values that you’ve met so far,
a function can also be considered a value with a context. The context for
functions is that that value is not present yet and that we need to apply that
function to something in order to get its result.
Because you’re already acquainted with how functions work as functors
and applicative functors, let’s dive right in and see what theirMonadinstance
looks like. It’s located inControl.Monad.Instances, and it goes a little some-
thing like this:

instanceMonad ((->) r) where
return x = \_ -> x
h >>= f = \w -> f (h w) w

You’veseen howpureis implemented for functions, andreturnis pretty
much the same thing aspure. It takes a value and puts it in a minimal con-
text that always has that value as its result. And the only way to make a func-
tion that always has a certain value as its result is to make it completely ig-
nore its parameter.
The implementation for>>=may seem a bit cryptic, but it’s really not all
that complicated. When we use>>=to feed a monadic value to a function,
the result is always a monadic value. So, in this case, when we feed a function
to another function, the result is a function as well. That’s why the result
starts off as a lambda.
All of the implementations of>>=so far somehow isolated the result
from the monadic value and then applied the functionfto that result. The
same thing happens here. To get the result from a function, we need to ap-
ply it to something, which is why we use(h w)here, and then we applyfto
that.freturns a monadic value, which is a function in our case, so we apply
it towas well.

```
For a Few Monads More 311
```

## The Reader Monad......................................................

```
If you don’t get how>>=works at this point, don’t worry. After a few exam-
ples, you’ll see that this is a really simple monad. Here’s adoexpression that
utilizes it:
```
```
importControl.Monad.Instances
```
```
addStuff :: Int -> Int
addStuff = do
a <- (*2)
b <- (+10)
return (a+b)
```
```
Thisis the same thing as the applicative expression that we wrote earlier,
but now it relies on functions being monads. Adoexpression always results
in a monadic value, and this one is no different. The result of this monadic
value is a function. It takes a number, then(*2)is applied to that number,
and the result becomesa.(+10)is applied to the same number that(*2)was
applied to, and the result becomesb.return, as in other monads, doesn’t
have any effect but to make a monadic value that presents some result. This
presentsa+bas the result of this function. If we test it, we get the same result
as before:
```
```
ghci>addStuff 3
19
```
```
Both(*2)and(+10)areapplied to the number 3 in this case.return (a+b)
does as well, but it ignores that value and always presentsa+bas the result.
For this reason, the function monad is also called the reader monad. All the
functions read from a common source. To make this even clearer, we can
rewriteaddStufflike so:
```
```
addStuff:: Int -> Int
addStuff x = let
a=(*2) x
b = (+10) x
in a+b
```
```
Yousee that the reader monad allows us to treat functions as values with
a context. We can act as if we already know what the functions will return.
It does this by gluing functions together into one function and then giving
that function’s parameter to all of the functions that compose it. So, if we
have a lot of functions that are all just missing one parameter, and they will
eventually be applied to the same thing, we can use the reader monad to
sort of extract their future results, and the>>=implementation will make
sure that it all works out.
```
**312** Chapter 14


## Tasteful Stateful Computations.....................................................

```
Haskellis a pure language, and
because of that, our programs are
made of functions that can’t change
any global state or variables; they
can only do some computations
and return the results. This restric-
tion actually makes it easier to think
about our programs, as it frees us
from worrying what every variable’s
value is at some point in time.
However, some problems are
inherently stateful, in that they rely
on some state that changes over
time. While this isn’t a problem for
Haskell, these computations can be
a bit tedious to model. That’s why Haskell features theStatemonad, which
makes dealing with stateful problems a breeze, while still keeping everything
nice and pure.
When we were looking at random numbers back in Chapter 9, we dealt
with functions that took a random generator as a parameter and returned
a random number and a new random generator. If we wanted to generate
several random numbers, we always needed to use the random generator
that a previous function returned along with its result. For example, to cre-
ate a function that takes aStdGenand tosses a coin three times based on that
generator, we did this:
```
```
threeCoins:: StdGen -> (Bool, Bool, Bool)
threeCoins gen =
let (firstCoin, newGen) = random gen
(secondCoin, newGen') = random newGen
(thirdCoin, newGen'') = random newGen'
in (firstCoin, secondCoin, thirdCoin)
```
```
Thisfunction takes a generatorgen, and thenrandom genreturns aBool
value along with a new generator. To throw the second coin, we use the new
generator, and so on.
In most other languages, we wouldn’t need to return a new generator
along with a random number. We could just modify the existing one! But
since Haskell is pure, we can’t do that, so we need to take some state, make
a result from it and a new state, and then use that new state to generate new
results.
You would think that to avoid manually dealing with stateful computa-
tions in this way, we would need to give up the purity of Haskell. Well, we
don’t have to, since there’s a special little monad called theStatemonad
that handles all this state business for us, without impacting any of the
purity that makes Haskell programming so cool.
```
```
For a Few Monads More 313
```

## Stateful Computations....................................................

```
To help demonstrate stateful computations, let’s go ahead and give them
a type. We’ll say that a stateful computation is a function that takes some
state and returns a value along with some new state. That function has the
following type:
```
```
s-> (a, s)
```
```
sisthe type of the state, andais the result of the stateful computations.
```
```
NOTE Assignment in most other languages could be thought of as a stateful computation.
For instance, when we dox=5in an imperative language, it will usually assign the
value 5 to the variablex, and it will also have the value 5 as an expression. If you look
at that functionally, it’s like a function that takes a state (that is, all the variables that
have been assigned previously) and returns a result (in this case, 5 ) and a new state,
which would be all the previous variable mappings plus the newly assigned variable.
```
```
This stateful computation—a function that takes a state and returns a
result and a new state—can be thought of as a value with a context as well.
The actual value is the result, whereas the context is that we must provide
some initial state to actually get that result, and that apart from getting a
result, we also get a new state.
```
## Stacks and Stones........................................................

```
Say we want to model a stack. A stack is a data structure that contains a bunch
of elements and supports exactly two operations:
```
- _Pushing_ an element to the stack, which adds an element onto the top of
    the stack
- _Popping_ an element off the stack, which removes the topmost element
    from the stack

```
We’ll use a list to represent our stack, with the head of the list acting as
the top of the stack. To help us with our task, we’ll make two functions:
```
- popwill take a stack, pop one item, and return that item as the result. It
    will also return a new stack, without the popped item.
- pushwill take an item and a stack and then push that item onto the stack.
    It will return()as its result, along with a new stack.

```
Here are the functions in use:
```
```
typeStack = [Int]
```
```
pop :: Stack -> (Int, Stack)
pop (x:xs) = (x, xs)
```
**314** Chapter 14


push:: Int -> Stack -> ((), Stack)
push a xs = ((), a:xs)

Weused()as the result when pushing to the stack because pushing
an item onto the stack doesn’t have any important result value—its main
job is to change the stack. If we apply only the first parameter ofpush, we
get a stateful computation.popis already a stateful computation because of
its type.
Let’s write a small piece of code to simulate a stack using these func-
tions. We’ll take a stack, push 3 to it, and then pop two items, just for kicks.
Here it is:

stackManip:: Stack -> (Int, Stack)
stackManip stack = let
((), newStack1) = push 3 stack
(a , newStack2) = pop newStack1
in pop newStack2

Wetake astack, and then we dopush 1 stack, which results in a tuple.
The first part of the tuple is a(), and the second is a new stack, which we call
newStack1. Then we pop a number fromnewStack1, which results in a number
a(which is the 3 ) that we pushed and a new stack, which we callnewStack2.
Then we pop a number offnewStack2, and we get a number that’sband a
newStack3. We return a tuple with that number and that stack. Let’s try it out:

ghci>stackManip [5,8,2,1]
(5,[8,2,1])

Theresult is 5 , and the new stack is[8,2,1]. Notice howstackManipis it-
self a stateful computation. We’ve taken a bunch of stateful computations
and sort of glued them together. Hmm, sounds familiar.
The preceding code forstackManipis kind of tedious, since we’re man-
ually giving the state to every stateful computation and storing it and then
giving it to the next one. Wouldn’t it be cooler if, instead of giving the stack
manually to each function, we could write something like the following?

stackManip= do
push 3
a <- pop
pop

Well,using theStatemonad will allow us to do exactly that. With it, we
will be able to take stateful computations like these and use them without
needing to manage the state manually.

```
For a Few Monads More 315
```

## The State Monad

```
TheControl.Monad.Statemodule provides anewtypethat wraps stateful compu-
tations. Here’s its definition:
```
```
newtypeState s a = State { runState :: s -> (a, s) }
```
```
AStatesais a stateful computation that manipulates a state of types
and has a result of typea.
Much likeControl.Monad.Writer,Control.Monad.Statedoesn’t export its
value constructor. If you want to take a stateful computation and wrap it in
theState newtype, use thestatefunction, which does the same thing that the
Stateconstructor would do.
Now that you’ve seen what stateful computations are about and how
they can even be thought of as values with contexts, let’s check out their
Monadinstance:
```
```
instanceMonad (State s) where
return x = State $ \s -> (x, s)
(State h) >>= f = State $ \s -> let (a, newState) = h s
(State g) = f a
in g newState
```
```
Ouraim withreturnis to take a value and make a stateful computation
that always has that value as its result. That’s why we just make a lambda
\s -> (x, s). We always presentxas the result of the stateful computation,
and the state is kept unchanged, becausereturnmust put a value in a mini-
mal context. Soreturnwill make a stateful computation that presents a cer-
tain value as the result and keeps the state unchanged.
Whatabout>>=? Well, the result of feeding a
stateful computation to a function with>>=must
be a stateful computation, right? So, we start of
with theState newtypewrapper, and then we type
out a lambda. This lambda will be our new state-
ful computation. But what goes on in it? Well, we
need to somehow extract the result value from
the first stateful computation. Because we’re in
a stateful computation right now, we can give
the stateful computationhour current states,
which results in a pair of the result and a new
state:(a, newState).
So far, every time we implemented>>=, once we had extracted just the
result from the monadic value, we applied the functionfto it to get the
new monadic value. InWriter, after doing that and getting the new mo-
nadic value, we still need to make sure that the context is taken care of by
mappending the old monoid value with the new one. Here, we dofa, and we
get a new stateful computationg. Now that we have a new stateful computa-
tion and a new state (which goes by the name ofnewState), we just apply that
```
**316** Chapter 14


statefulcomputationgto thenewState. The result is a tuple of the final result
and final state!
So, with>>=, we kind of glue two stateful computations together. The
second computation is hidden inside a function that takes the previous com-
putation’s result. Becausepopandpushare already stateful computations, it’s
easy to wrap them into aStatewrapper:

importControl.Monad.State

pop :: State Stack Int
pop = state $ \(x:xs) -> (x, xs)

push :: Int -> State Stack ()
push a = state $ \xs -> ((), a:xs)

Noticehow we used thestatefunction to wrap a function into theState
newtypeinstead of using theStatevalue constructor directly.
popis already a stateful computation, andpushtakes anIntand returns a
stateful computation. Now we can rewrite our previous example of pushing 3
onto the stack and then popping two numbers off, like this:

importControl.Monad.State

stackManip :: State Stack Int
stackManip = do
push 3
a <- pop
pop

Seehow we’ve glued a push and two pops into one stateful computa-
tion? When we unwrap it from itsnewtypewrapper, we get a function to which
we can provide some initial state:

ghci>runState stackManip [5,8,2,1]
(5,[8,2,1])

Wedidn’t need to bind the secondpoptoa, because we didn’t use thata
at all. So, we could have written it like this:

stackManip:: State Stack Int
stackManip = do
push 3
pop
pop

Prettycool. But what if we want to do something a little more com-
plicated? Let’s say we want to pop one number off the stack, and if that

```
For a Few Monads More 317
```

```
numberis 5 , we’ll just push it back on the stack and stop. But if the number
isn’t 5 , we’ll push 3 and 8 back on instead. Here’s the code:
```
```
stackStuff:: State Stack ()
stackStuff = do
a <- pop
if a == 5
then push 5
else do
push 3
push 8
```
```
Thisis quite straightforward. Let’s run it with an initial stack:
```
```
ghci>runState stackStuff [9,0,2,1,0]
((),[8,3,0,2,1,0])
```
```
Rememberthatdoexpressions result in monadic values, and with the
Statemonad, a singledoexpression is also a stateful function. Because
stackManipandstackStuffare ordinary stateful computations, we can glue
them together to produce further stateful computations:
```
```
moreStack:: State Stack ()
moreStack = do
a <- stackManip
if a == 100
then stackStuff
else return ()
```
```
Ifthe result ofstackManipon the current stack is 100 , we runstackStuff;
otherwise, we do nothing.return ()just keeps the state as it is and does
nothing.
```
## Getting and Setting State.................................................

```
TheControl.Monad.Statemodule provides a type class calledMonadState, which
features two pretty useful functions:getandput. ForState, thegetfunction is
implemented like this:
```
```
get= state $ \s -> (s, s)
```
```
Itjust takes the current state and presents it as the result.
Theputfunction takes some state and makes a stateful function that
replaces the current state with it:
```
```
putnewState = state $ \s -> ((), newState)
```
**318** Chapter 14


So,with these, we can see what the current stack is or we can replace it
with a whole other stack, like so:

stackyStack:: State Stack ()
stackyStack = do
stackNow <- get
if stackNow == [1,2,3]
then put [8,3,1]
else put [9,2,1]

```
Wecan also usegetandputto implementpopandpush. Here’spop:
```
pop:: State Stack Int
pop = do
(x:xs) <- get
put xs
return x

Weusegetto get the whole stack, and then we useputto make every-
thing but the top element the new state. Then we usereturnto presentxas
the result.
Here’spushimplemented withgetandput:

push:: Int -> State Stack ()
push x = do
xs <- get
put (x:xs)

Wejust usegetto get the current stack and useputto make the set the
new state as our stack, with the elementxon top.
It’s worth examining what the type of>>=would be if it worked only for
Statevalues:

(>>=):: State s a -> (a -> State s b) -> State s b

Seehow the type of the statesstays the same, but the type of the result
can change fromatob? This means that we can glue together several state-
ful computations whose results are of different types, but the type of the
state must stay the same. Now why is that? Well, for instance, forMaybe,>>=
has this type:

(>>=):: Maybe a -> (a -> Maybe b) -> Maybe b

Itmakes sense that the monad itself,Maybe, doesn’t change. It wouldn’t
make sense to use>>=between two different monads. Well, for theState
monad, the monad is actuallyState s, so if thatswere different, we would
be using>>=between two different monads.

```
For a Few Monads More 319
```

## Randomness and the State Monad.........................................

```
At the beginning of this section, we talked about how generating random
numbers can sometimes be awkward. Every random function takes a gener-
ator and returns a random number along with a new generator, which must
then be used instead of the old one if we want to generate another random
number. TheStatemonad makes dealing with this a lot easier.
Therandomfunction fromSystem.Randomhas the following type:
```
```
random:: (RandomGen g, Random a) => g -> (a, g)
```
```
Thismeans it takes a random generator and produces a random num-
ber along with a new generator. We can see that it’s a stateful computation,
so we can wrap it in theState newtypeconstructor by using thestatefunction,
and then use it as a monadic value so that passing the state is handled for us:
```
```
importSystem.Random
import Control.Monad.State
```
```
randomSt :: (RandomGen g, Random a) => State g a
randomSt = state random
```
```
So,now if we want to throw three coins (Trueis tails, andFalseis heads),
we just do the following:
```
```
importSystem.Random
import Control.Monad.State
```
```
threeCoins :: State StdGen (Bool, Bool, Bool)
threeCoins = do
a <- randomSt
b <- randomSt
c <- randomSt
return (a, b, c)
```
```
threeCoinsisnow a stateful computation, and after taking an initial ran-
dom generator, it passes that generator to the firstrandomSt, which produces
a number and a new generator, which is passed to the next one, and so on.
We usereturn (a, b, c)to present(a, b, c)as the result without changing
the most recent generator. Let’s give this a go:
```
```
ghci>runState threeCoins (mkStdGen 33)
((True,False,True),680029187 2103410263)
```
```
Nowdoing things that require some state to be saved in between steps
just became much less of a hassle!
```
**320** Chapter 14


## Error Error on the Wall............................................................

```
You know by now thatMaybeis used to add a context of possible failure to
values. A value can be aJust somethingor aNothing. However useful it may be,
when we have aNothing, all we know is that there was some sort of failure—
there’s no way to cram more information in there telling us what kind of
failure it was.
TheEither e atype also allows us to incorporate a context of possible
failure into our values. It also lets us attach values to the failure, so they can
describe what went wrong or provide other useful information regarding the
failure. AnEither e avalue can either be aRightvalue, signifying the right
answer and a success, or it can be aLeftvalue, signifying failure. Here’s an
example:
```
```
ghci> :t Right 4
Right 4 :: (Num t) => Either a t
ghci> :t Left "out of cheese error"
Left "out of cheese error" :: Either [Char] b
```
```
This is prettymuch just an enhancedMaybe, so it makes sense for it to be
a monad. It can also be viewed as a value with an added context of possible
failure, but now there’s a value attached when there’s an error as well.
ItsMonadinstance is similar to that ofMaybe, and it can be found in
Control.Monad.Error:
```
```
instance (Error e)=> Monad (Either e) where
return x = Right x
Right x >>= f = f x
Left err >>= f = Left err
fail msg = Left (strMsg msg)
```
```
return, as always,takes a value and puts it in a default minimal context.
It wraps our value in theRightconstructor because we’re usingRightto rep-
resent a successful computation where a result is present. This is a lot like
returnforMaybe.
The>>=examines two possible cases: aLeftand aRight. In the case of a
Right, the functionfis applied to the value inside it, similar to the case of a
Justwhere the function is just applied to its contents. In the case of an error,
theLeftvalue is kept, along with its contents, which describe the failure.
TheMonadinstance forEither ehas an additional requirement. The
type of the value contained in aLeft—the one that’s indexed by theetype
parameter—must be an instance of theErrortype class. TheErrortype class
is for types whose values can act like error messages. It defines thestrMsg
function, which takes an error in the form of a string and returns such a
```
```
For a Few Monads More 321
```

```
value.A good example of anErrorinstance is theStringtype! In the case
ofString, thestrMsgfunction just returns the string that it got:
```
```
ghci>:t strMsg
strMsg :: (Error a) => String -> a
ghci> strMsg "boom!" :: String
"boom!"
```
```
Butsince we usually useStringto describe the error when usingEither,
we don’t need to worry about this too much. When a pattern match fails in
donotation, aLeftvalue is used to signify this failure.
Here are a few examples of usage:
```
```
ghci>Left "boom" >>= \x -> return (x+1)
Left "boom"
ghci> Left "boom " >>= \x -> Left "no way!"
Left "boom "
ghci> Right 100 >>= \x -> Left "no way!"
Left "no way!"
```
```
Whenwe use>>=to feed aLeftvalue to a function, the function is ig-
nored and an identicalLeftvalue is returned. When we feed aRightvalue to
a function, the function is applied to what’s on the inside, but in this case,
that function produced aLeftvalue anyway!
When we try to feed aRightvalue to a function that also succeeds, we’re
tripped up by a peculiar type error. Hmmm.
```
```
ghci>Right 3 >>= \x -> return (x + 100)
```
```
<interactive>:1:0:
Ambiguous type variable `a' in the constraints:
`Error a' arising from a use of `it' at <interactive>:1:0-33
`Show a' arising from a use of `print' at <interactive>:1:0-33
Probable fix: add a type signature that fixes these type variable(s)
```
```
Haskellsays that it doesn’t know which type to choose for theepart of
ourEither e a-typed value, even though we’re just printing theRightpart.
This is due to theError econstraint on theMonadinstance. So, if you get type
errors like this one when usingEitheras a monad, just add an explicit type
signature:
```
```
ghci>Right 3 >>= \x -> return (x + 100) :: Either String Int
Right 103
```
**322** Chapter 14


```
Andnow it works!
Other than this little hang-up, using the error monad is very similar to
usingMaybeas a monad.
```
```
NOTE In the previous chapter, we used the monadic aspects ofMaybeto simulate birds land-
ing on the balancing pole of a tightrope walker. As an exercise, you can rewrite that
with the error monad so that when the tightrope walker slips and falls, you remember
how many birds were on each side of the pole when he fell.
```
## Some Useful Monadic Functions...................................................

```
In this section, we’re going to explore a few functions that operate on mo-
nadic values or return monadic values as their results (or both!). Such func-
tions are usually referred to as monadic functions. While some of them will
be brand new, others will be monadic counterparts of functions that you al-
ready know, likefilterandfoldl. Here, we’ll look atliftM,join,filterM, and
foldM.
```
## liftM and Friends.........................................................

```
Whenwe started our journey to the
top of Monad Mountain, we first
looked at functors , which are for
things that can be mapped over.
Then we covered improved func-
tors called applicative functors , which
allow us to apply normal functions
between several applicative values as
well as to take a normal value and
put it in some default context. Finally, we introduced monads as improved
applicative functors, which add the ability for these values with context to
somehow be fed into normal functions.
So, every monad is an applicative functor, and every applicative func-
tor is a functor. TheApplicativetype class has a class constraint such that
our type must be an instance ofFunctorbefore we can make it an instance
ofApplicative.Monadshould have the same constraint forApplicative, as every
monad is an applicative functor, but it doesn’t, because theMonadtype class
was introduced to Haskell long beforeApplicative.
But even though every monad is a functor, we don’t need to rely on it
having aFunctorinstance because of theliftMfunction.liftMtakes a func-
tion and a monadic value and maps the function over the monadic value. So
it’s pretty much the same thing asfmap! This isliftM’s type:
```
```
liftM:: (Monad m) => (a -> b) -> m a -> m b
```
```
For a Few Monads More 323
```

```
Andthis is the type offmap:
```
```
fmap:: (Functor f) => (a -> b) -> f a -> f b
```
```
IftheFunctorandMonadinstances for a type obey the functor and monad
laws, these two amount to the same thing (and all the monads that we’ve
met so far obey both). This is kind of likepureandreturndo the same thing,
but one has anApplicativeclass constraint, whereas the other has aMonad
constraint. Let’s try outliftM:
```
```
ghci>liftM (*3) (Just 8)
Just 24
ghci> fmap (*3) (Just 8)
Just 24
ghci> runWriter $ liftM not $ Writer (True, "chickpeas")
(False,"chickpeas")
ghci> runWriter $ fmap not $ Writer (True, "chickpeas")
(False,"chickpeas")
ghci> runState (liftM (+100) pop) [1,2,3,4]
(101,[2,3,4])
ghci> runState (fmap (+100) pop) [1,2,3,4]
(101,[2,3,4])
```
```
Youalready know quite well howfmapworks withMaybevalues. AndliftM
does the same thing. ForWritervalues, the function is mapped over the first
component of the tuple, which is the result. RunningfmaporliftMover a
stateful computation results in another stateful computation, but its eventual
result is modified by the supplied function. Had we not mapped(+100)over
popbefore running it, it would have returned(1, [2,3,4]).
This is howliftMis implemented:
```
```
liftM:: (Monad m) => (a -> b) -> m a -> m b
liftM f m = m >>= (\x -> return (f x))
```
```
Orwithdonotation:
```
```
liftM:: (Monad m) => (a -> b) -> m a -> m b
liftM f m = do
x <- m
return (f x)
```
```
Wefeed the monadic valueminto the function, and then we apply the
functionfto its result before putting it back into a default context. Because
of the monad laws, this is guaranteed not to change the context; it changes
only the result that the monadic value presents.
You see thatliftMis implemented without referencing theFunctortype
class at all. This means that we can implementfmap(orliftM—whatever you
```
**324** Chapter 14


wantto call it) just by using the goodies that monads offer us. Because of
this, we can conclude that monads are at least as strong as functors.
TheApplicativetype class allows us to apply functions between values
with contexts as if they were normal values, like this:

ghci>(+) <$> Just 3 <*> Just 5
Just 8
ghci> (+) <$> Just 3 <*> Nothing
Nothing

Usingthis applicative style makes things pretty easy.<$>is justfmap, and
<*>is a function from theApplicativetype class that has the following type:

(<*>):: (Applicative f) => f (a -> b) -> f a -> f b

Soit’s kind of likefmap, but the function itself is in a context. We need
to somehow extract it from the context and map it over thefavalue, and
then reassemble the context. Because all functions are curried in Haskell by
default, we can use the combination of<$>and<*>to apply functions that
take several parameters between applicative values.
Anyway, it turns out that just likefmap,<*>can also be implemented by
using only what theMonadtype class gives us. Theapfunction is basically<*>,
but with aMonadconstraint instead of anApplicativeone. Here’s its definition:

ap:: (Monad m) => m (a -> b) -> m a -> m b
ap mf m = do
f <- mf
x <- m
return (f x)

mfisa monadic value whose result is a function. Because the function
as well as the value is in a context, we get the function from the context and
call itf, then get the value and call thatx, and, finally, apply the function to
the value and present that as a result. Here’s a quick demonstration:

ghci>Just (+3) <*> Just 4
Just 7
ghci> Just (+3) `ap` Just 4
Just 7
ghci> [(+1),(+2),(+3)] <*> [10,11]
[11,12,12,13,13,14]
ghci> [(+1),(+2),(+3)] `ap` [10,11]
[11,12,12,13,13,14]

Nowwe can see that monads are at least as strong as applicatives as
well, because we can use the functions fromMonadto implement the ones
forApplicative. In fact, many times, when a type is found to be a monad,
people first write up aMonadinstance, and then make anApplicativeinstance

```
For a Few Monads More 325
```

```
byjust saying thatpureisreturnand<*>isap. Similarly, if you already have a
Monadinstance for something, you can give it aFunctorinstance just by saying
thatfmapisliftM.
liftA2is a convenience function for applying a function between two
applicative values. It’s defined like so:
```
```
liftA2:: (Applicative f) => (a -> b -> c) -> f a -> f b -> f c
liftA2 f x y = f <$> x <*>y
```
```
TheliftM2functiondoes the same thing, but with aMonadconstraint.
There are alsoliftM3,liftM4, andliftM5functions.
You saw how monads are at least as strong as applicatives and functors
and how even though all monads are functors and applicative functors, they
don’t necessarily haveFunctorandApplicativeinstances. We examined the
monadic equivalents of the functions that functors and applicative func-
tors use.
```
## The join Function.........................................................

```
Here’s some food for thought: If the result of one monadic value is another
monadic value (one monadic value is nested inside the other), can you flat-
ten them to just a single, normal monadic value? For instance, if we have
Just (Just 9), can we make that intoJust 9? It turns out that any nested
monadic value can be flattened and that this is actually a property unique
to monads. For this, we have thejoinfunction. Its type is this:
```
```
join:: (Monad m) => m (m a) -> m a
```
```
So,jointakesa monadic value within a monadic value and gives us just
a monadic value—it flattens it, in other words. Here it is with someMaybe
values:
```
```
ghci>join (Just (Just 9))
Just 9
ghci> join (Just Nothing)
Nothing
ghci> join Nothing
Nothing
```
```
Thefirst line has a successful computation as a result of a successful
computation, so they are both just joined into one big successful computa-
tion. The second line features aNothingas a result of aJustvalue. Whenever
we were dealing withMaybevalues before and we wanted to combine several
of them into one—be it with<*>or>>=—they all needed to beJustvalues for
the result to be aJustvalue. If there was any failure along the way, the result
was a failure, and the same thing happens here. In the third line, we try to
flatten what is from the onset a failure, so the result is a failure as well.
```
**326** Chapter 14


```
Flatteninglists is pretty intuitive:
```
ghci>join [[1,2,3],[4,5,6]]
[1,2,3,4,5,6]

Asyou can see, for lists,joinis justconcat. To flatten aWritervalue whose
result is aWritervalue itself, we need tomappendthe monoid value:

ghci>runWriter $ join (Writer (Writer (1, "aaa"), "bbb"))
(1,"bbbaaa")

Theouter monoid value"bbb"comes first, and then"aaa"is appended
to it. Intuitively speaking, when you want to examine the result of aWriter
value, you need to write its monoid value to the log first, and only then can
you look at what it has inside.
FlatteningEithervalues is very similar to flatteningMaybevalues:

ghci>join (Right (Right 9)) :: Either String Int
Right 9
ghci> join (Right (Left "error")) :: Either String Int
Left "error"
ghci> join (Left "error") :: Either String Int
Left "error"

Ifwe applyjointo a stateful computation whose result is a stateful com-
putation, the result is a stateful computation that first runs the outer stateful
computation and then the resulting one. Watch it at work:

ghci>runState (join (state $ \s -> (push 10, 1:2:s))) [0,0,0]
((),[10,1,2,0,0,0])

Thelambda here takes a state, puts 2 and 1 onto the stack, and presents
push 10as its result. So, when this whole thing is flattened withjoinand then
run, it first puts 2 and 1 onto the stack, and thenpush 10is carried out, push-
ing a 10 onto the top.
The implementation forjoinis as follows:

join:: (Monad m) => m (m a) -> m a
join mm = do
m <- mm
m

Becausethe result ofmmis a monadic value, we get that result and then
just put it on a line of its own because it’s a monadic value. The trick here is
that when we callm <- mm, the context of the monad that we are in is taken
care of. That’s why, for instance,Maybevalues result inJustvalues only if the

```
For a Few Monads More 327
```

```
outerand inner values are bothJustvalues. Here’s what this would look like
if themmvalue were set in advance toJust (Just 8):
```
```
joinedMaybes:: Maybe Int
joinedMaybes = do
m <- Just (Just 8)
m
```
```
Perhapsthe most interesting thing
aboutjoinis that for every monad, feeding
a monadic value to a function with>>=is the
same thing as just mapping that function
over the value and then usingjointo flat-
ten the resulting nested monadic value! In
other words,m >>= fis always the same thing
asjoin (fmap f m). It makes sense when you
think about it.
With>>=, we’re always thinking about how
to feed a monadic value to a function that
takes a normal value but returns a monadic
value. If we just map that function over the
monadic value, we have a monadic value in-
side a monadic value. For instance, say we
haveJust 9and the function\x -> Just (x+1).
If we map this function overJust 9, we’re left
withJust (Just 10).
The fact thatm >>= falways equalsjoin (fmap f m)is very useful if we’re
making our ownMonadinstance for some type. This is because it’s often eas-
ier to figure out how we would flatten a nested monadic value than to figure
out how to implement>>=.
Another interesting thing is thatjoincannot be implemented by just
using the functions that functors and applicatives provide. This leads us to
conclude that not only are monads as strong as functors and applicatives,
but they are in fact stronger, because we can do more stuff with them than
we can with just functors and applicatives.
```
## filterM..................................................................

```
Thefilterfunction is pretty much the bread of Haskell programming (map
being the butter). It takes a predicate and a list to filter and then returns a
new list where only the elements that satisfy the predicate are kept. Its type
is this:
```
```
filter:: (a -> Bool) -> [a] -> [a]
```
**328** Chapter 14


Thepredicate takes an element of the list and returns aBoolvalue.
Now, what if theBoolvalue that it returned was actually a monadic value?
What if it came with a context? For instance, what if everyTrueorFalse
value that the predicate produced also had an accompanying monoid value,
like["Accepted the number 5"]or["3 is too small"]? If that were the case, we
would expect the resulting list to also come with a log of all the log values
that were produced along the way. So, if theBoolthat the predicate returned
came with a context, we would expect the final resulting list to have some
context attached as well. Otherwise, the context that eachBoolcame with
would be lost.
ThefilterMfunction fromControl.Monaddoes just what we want! Its type
is this:

filterM:: (Monad m) => (a -> m Bool) -> [a] -> m [a]

Thepredicate returns a monadic value whose result is aBool, but be-
cause it’s a monadic value, its context can be anything from a possible fail-
ure to nondeterminism and more! To ensure that the context is reflected
in the final result, the result is also a monadic value.
Let’s take a list and keep only those values that are smaller than 4. To
start, we’ll just use the regularfilterfunction:

ghci>filter (\x -> x < 4) [9,1,5,2,10,3]
[1,2,3]

That’spretty easy. Now, let’s make a predicate that, aside from present-
ing aTrueorFalseresult, also provides a log of what it did. Of course, we’ll
be using theWritermonad for this:

keepSmall:: Int -> Writer [String] Bool
keepSmall x
| x < 4 = do
tell ["Keeping " ++ show x]
return True
| otherwise = do
tell [show x ++ " is too large, throwing it away"]
return False

Insteadof just returning aBool, this function returns aWriter [String]
Bool. It’s a monadic predicate. Sounds fancy, doesn’t it? If the number is
smaller than 4 , we report that we’re keeping it, and thenreturn True.
Now, let’s give it tofilterMalong with a list. Because the predicate re-
turns aWritervalue, the resulting list will also be aWritervalue.

ghci>fst $ runWriter $ filterM keepSmall [9,1,5,2,10,3]
[1,2,3]

```
For a Few Monads More 329
```

```
Examiningthe result of the resultingWritervalue, we see that everything
is in order. Now, let’s print the log and see what we have:
```
```
ghci>mapM_ putStrLn $ snd $ runWriter $ filterM keepSmall [9,1,5,2,10,3]
9 is too large, throwing it away
Keeping 1
5 is too large, throwing it away
Keeping 2
10 is too large, throwing it away
Keeping 3
```
```
So,just by providing a monadic predicate tofilterM, we were able to fil-
ter a list while taking advantage of the monadic context that we used.
A very cool Haskell trick is usingfilterMto get the powerset of a list (if
we think of them as sets for now). The powerset of some set is a set of all sub-
sets of that set. So if we have a set like[1,2,3], its powerset includes the fol-
lowing sets:
```
```
[1,2,3]
[1,2]
[1,3]
[1]
[2,3]
[2]
[3]
[]
```
```
Inother words, getting a powerset is like getting all the combinations
of keeping and throwing out elements from a set. For example,[2,3]is the
original set with the number 1 excluded,[1,2]is the original set with 3 ex-
cluded, and so on.
To make a function that returns a powerset of some list, we’re going to
rely on nondeterminism. We take the list[1,2,3]and then look at the first
element, which is 1 , and we ask ourselves, “Should we keep it or drop it?”
Well, we would like to do both actually. So, we are going to filter a list, and
we’ll use a predicate that nondeterministically both keeps and drops every
element from the list. Here’s ourpowersetfunction:
```
```
powerset:: [a] -> [[a]]
powerset xs = filterM (\x -> [True, False]) xs
```
```
Wait,that’s it? Yup. We choose to drop and keep every element, regard-
less of what that element is. We have a nondeterministic predicate, so the
resulting list will also be a nondeterministic value and will thus be a list of
lists. Let’s give this a go:
```
```
ghci>powerset [1,2,3]
[[1,2,3],[1,2],[1,3],[1],[2,3],[2],[3],[]]
```
**330** Chapter 14


Thistakes a bit of thinking to wrap your head around. Just consider lists
as nondeterministic values that don’t know what to be, so they decide to be
everything at once, and the concept is a bit easier to grasp.

## foldM...................................................................

The monadic counterpart tofoldlisfoldM. If you remember your folds from
Chapter 5, you know thatfoldltakes a binary function, a starting accumu-
lator, and a list to fold up and then folds it from the left into a single value
by using the binary function.foldMdoes the same thing, except it takes a bi-
nary function that produces a monadic value and folds the list up with that.
Unsurprisingly, the resulting value is also monadic. The type offoldlis this:

foldl:: (a -> b -> a) -> a -> [b] -> a

```
WhereasfoldMhasthe following type:
```
foldM:: (Monad m) => (a -> b -> m a) -> a -> [b] -> m a

Thevalue that the binary function returns is monadic, so the result of
the whole fold is monadic as well. Let’s sum a list of numbers with a fold:

ghci>foldl (\acc x -> acc + x) 0 [2,8,3,1]
14

Thestarting accumulator is 0 , and then 2 is added to the accumulator,
resulting in a new accumulator that has a value of 2. 8 is added to this accu-
mulator, resulting in an accumulator of 10 , and so on. When we reach the
end, the final accumulator is the result.
Now, what if we wanted to sum a list of numbers but with the added con-
dition that if any number in the list is greater than 9 , the whole thing fails? It
would make sense to use a binary function that checks if the current number
is greater than 9. If it is, the function fails; if it isn’t, the function continues
on its merry way. Because of this added possibility of failure, let’s make our
binary function return aMaybeaccumulator instead of a normal one. Here’s
the binary function:

binSmalls:: Int -> Int -> Maybe Int
binSmalls acc x
| x > 9 = Nothing
| otherwise = Just (acc + x)

Becauseour binary function is now a monadic function, we can’t use it
with the normalfoldl; we must usefoldM. Here goes:

ghci>foldM binSmalls 0 [2,8,3,1]
Just 14

```
For a Few Monads More 331
```

```
ghci>foldM binSmalls 0 [2,11,3,1]
Nothing
```
```
Excellent!Because one number in the list was greater than 9 , the whole
thing resulted in aNothing. Folding with a binary function that returns a
Writervalue is cool as well, because then you log whatever you want as your
fold goes along its way.
```
## Making a Safe RPN Calculator....................................................

```
Whenwe were solving the problem of imple-
menting an RPN calculator in Chapter 10,
we noted that it worked fine as long as the in-
put that it got made sense. But if something
went wrong, it caused our whole program to
crash. Now that we know how to make already
existing code monadic, let’s take our RPN cal-
culator and add error handling to it by taking
advantage of theMaybemonad.
We implemented our RPN calculator
by taking a string like"1 3 + 2*", break-
ing it up into words to get something like
["1","3","+","2","*"]. Then we folded over
that list by starting out with an empty stack
and using a binary folding function that adds
numbers to the stack or manipulates numbers
on the top of the stack to add them together and divide them and such.
This was the main body of our function:
```
```
importData.List
```
```
solveRPN :: String -> Double
solveRPN = head. foldl foldingFunction []. words
```
```
Wemade the expression into a list of strings, and folded over it with our
folding function. Then, when we were left with just one item in the stack, we
returned that item as the answer. This was the folding function:
```
```
foldingFunction:: [Double] -> String -> [Double]
foldingFunction (x:y:ys) "*" = (y*x):ys
foldingFunction (x:y:ys) "+" = (y + x):ys
foldingFunction (x:y:ys) "-" = (y - x):ys
foldingFunction xs numberString = read numberString:xs
```
```
Theaccumulator of the fold was a stack, which we represented with a
list ofDoublevalues. As the folding function went over the RPN expression,
if the current item was an operator, it took two items off the top of the stack,
```
**332** Chapter 14


appliedthe operator between them, and then put the result back on the
stack. If the current item was a string that represented a number, it con-
verted that string into an actual number and returned a new stack that was
like the old one, except with that number pushed to the top.
Let’s first make our folding function capable of graceful failure. Its type
is going to change from what it is now to this:

foldingFunction:: [Double] -> String -> Maybe [Double]

So,it will either returnJusta new stack or it will fail withNothing.
Thereadsfunction is likeread, except that it returns a list with a single
element in case of a successful read. If it fails to read something, it returns
an empty list. Apart from returning the value that it read, it also returns the
part of the string that it didn’t consume. We’re going to say that it always
must consume the full input to work, and make it into areadMaybefunction
for convenience. Here it is:

readMaybe:: (Read a) => String -> Maybe a
readMaybe st = case reads st of [(x, "")] -> Just x
_ -> Nothing

```
Nowlet’s test it:
```
ghci>readMaybe "1" :: Maybe Int
Just 1
ghci> readMaybe "GOTO HELL" :: Maybe Int
Nothing

Okay,it seems to work. So, let’s make our folding function into a mo-
nadic function that can fail:

foldingFunction:: [Double] -> String -> Maybe [Double]
foldingFunction (x:y:ys) "*" = return ((y*x):ys)
foldingFunction (x:y:ys) "+" = return ((y + x):ys)
foldingFunction (x:y:ys) "-" = return ((y - x):ys)
foldingFunction xs numberString = liftM (:xs) (readMaybe numberString)

Thefirst three cases are like the old ones, except the new stack is wrap-
ped in aJust(we usedreturnhere to do this, but we could just as well have
writtenJust). In the last case, we usereadMaybe numberString, and then we
map(:xs)over it. So, if the stackxsis[1.0,2.0], andreadMaybe numberString
results in aJust 3.0, the result isJust [3.0,1.0,2.0]. IfreadMaybe numberString
results in aNothing, the result isNothing.
Let’s try out the folding function by itself:

ghci>foldingFunction [3,2] "*"
Just [6.0]

```
For a Few Monads More 333
```

```
ghci> foldingFunction [3,2]"-"
Just [-1.0]
ghci> foldingFunction [] "*"
Nothing
ghci> foldingFunction [] "1"
Just [1.0]
ghci> foldingFunction [] "1 wawawawa"
Nothing
```
```
It looks likeit’s working! And now it’s time for the new and improved
solveRPN. Here it is ladies and gents!
```
```
import Data.List
```
```
solveRPN ::String -> Maybe Double
solveRPN st = do
[result] <- foldM foldingFunction [] (words st)
return result
```
```
Just as inthe previous version, we take the string and make it into a list
of words. Then we do a fold, starting with the empty stack, but instead of do-
ing a normalfoldl, we do afoldM. The result of thatfoldMshould be aMaybe
value that contains a list (that’s our final stack), and that list should have
only one value. We use adoexpression to get that value, and we call itresult.
In case thefoldMreturns aNothing, the whole thing will be aNothing, because
that’s howMaybeworks. Also notice that we pattern match in thedoexpres-
sion, so if the list has more than one value or none at all, the pattern match
fails, and aNothingis produced. In the last line, we just callreturn result
to present the result of the RPN calculation as the result of the finalMaybe
value.
Let’s give it a shot:
```
ghci> solveRPN "1 (^2) *4 +"
Just 6.0
ghci> solveRPN "1 2*4+5*"
Just 30.0
ghci> solveRPN "1 2*4"
Nothing
ghci> solveRPN "1 8 wharglbllargh"
Nothing
The first failurehappens because the final stack isn’t a list with one el-
ement in it, so the pattern matching in thedoexpression fails. The second
failure happens becausereadMaybereturns aNothing.
**334** Chapter 14


## Composing Monadic Functions....................................................

```
When we were talking about the monad laws in Chapter 13, you learned that
the<=<function is just like composition, but instead of working for normal
functions likea -> b, it works for monadic functions likea -> m b. Here is
an example:
```
```
ghci>let f = (+1). (*100)
ghci> f 4
401
ghci> let g = (\x -> return (x+1)) <=< (\x -> return (x*100))
ghci> Just 4 >>= g
Just 401
```
```
Inthis example, we first composed two normal functions, applied the
resulting function to 4 , and then composed two monadic functions and fed
Just 4to the resulting function with>>=.
If you have a bunch of functions in a list, you can compose them all into
one big function just by usingidas the starting accumulator and the.func-
tion as the binary function. Here’s an example:
```
```
ghci>let f = foldr (.) id [(+1),(*100),(+1)]
ghci> f 1
201
```
```
Thefunctionftakes a number and then adds 1 to it, multiplies the re-
sult by 100 , and then adds 1 to that.
We can compose monadic functions in the same way, but instead of nor-
mal composition, we use<=<, and instead ofid, we usereturn. We don’t need
to use afoldMover afoldror anything like that, because the<=<function
makes sure that composition happens in a monadic fashion.
When you were introduced to the list monad in Chapter 13, we used
it to figure out if a knight can go from one position on a chessboard to an-
other in exactly three moves. We created a function calledmoveKnight, which
takes the knight’s position on the board and returns all the possible moves
that he can make next. Then, to generate all the possible positions that he
can have after taking three moves, we made the following function:
```
```
in3start = return start >>= moveKnight >>= moveKnight >>= moveKnight
```
```
Andto check if he can go fromstarttoendin three moves, we did the
following:
```
```
canReachIn3:: KnightPos -> KnightPos -> Bool
canReachIn3 start end = end `elem` in3 start
```
```
For a Few Monads More 335
```

```
Usingmonadic function composition, we can make a function likein3,
except instead of generating all the positions that the knight can have after
making three moves, we can do it for an arbitrary number of moves. If you
look atin3, you’ll see that we used ourmoveKnightthree times, and each time,
we used>>=to feed it all the possible previous positions. So now, let’s make it
more general. Here’s how:
```
```
importData.List
```
```
inMany :: Int -> KnightPos -> [KnightPos]
inMany x start = return start >>= foldr (<=<) return (replicate x moveKnight)
```
```
First,we usereplicateto make a list that containsxcopies of the func-
tionmoveKnight. Then we monadically compose all those functions into one,
which gives us a function that takes a starting position and nondeterministi-
cally moves the knightxtimes. Then we just make the starting position into
a singleton list withreturnand feed it to the function.
Now, we can change ourcanReachIn3function to be more general as well:
```
```
canReachIn:: Int -> KnightPos -> KnightPos -> Bool
canReachIn x start end = end `elem` inMany x start
```
## Making Monads.................................................................

```
Inthis section, we’re going to look at an example of how a type gets
made, identified as a monad, and then given the appropriateMonadinstance.
We don’t usually set out to make a monad with the sole purpose of making
a monad. Rather, we make a type whose purpose is to model an aspect of
some problem, and then later on, if we see that the type represents a value
with a context and can act like a monad, we give it aMonadinstance.
As you’ve seen, lists are used to represent nondeterministic values. A list
like[3,5,9]can be viewed as a single nondeterministic value that just can’t
decide what it’s going to be. When we feed a list into a function with>>=,
it just makes all the possible choices of taking an element from the list and
applying the function to it and then presents those results in a list as well.
```
**336** Chapter 14


Ifwe look at the list[3,5,9]as the numbers 3 , 5 , and 9 occurring at once,
we might notice that there’s no information regarding the probability that
each of those numbers occurs. What if we wanted to model a nondeterminis-
tic value like[3,5,9], but we wanted to express that 3 has a 50 percent chance
of happening and 5 and 9 both have a 25 percent chance of happening?
Let’s try to make this work!
Let’s say that every item in the list comes with another value: a probabil-
ity of it happening. It might make sense to present that value like this:

[(3,0.5),(5,0.25),(9,0.25)]

Inmathemathics, probabilities aren’t usually expressed in percentages,
but rather in real numbers between a 0 and 1. A 0 means that there’s no
chance in hell for something to happen, and a 1 means that it’s happen-
ing for sure. Floating-point numbers can get messy fast because they tend
to lose precision, but Haskell offers a data type for rational numbers. It’s
calledRational, and it lives inData.Ratio. To make aRational, we write it as if
it were a fraction. The numerator and the denominator are separated by a%.
Here are a few examples:

ghci>1%4
1%4
ghci> 1%2 + 1%2
1%1
ghci> 1%3 + 5%4
19 % 12

Thefirst line is just one-quarter. In the second line, we add two halves
to get a whole. In the third line, we add one-third with five-quarters and get
nineteen-twelfths. So, let’s throw out our floating points and useRationalfor
our probabilities:

ghci>[(3,1%2),(5,1%4),(9,1%4)]
[(3,1 % 2),(5,1 % 4),(9,1 % 4)]

Okay,so 3 has a one-out-of-two chance of happening, while 5 and 9 will
happen one time out of four. Pretty neat.
We took lists and we added some extra context to them, so this repre-
sents values with contexts as well. Before we go any further, let’s wrap this
into anewtype, because something tells me we’ll be making some instances.

importData.Ratio

newtype Prob a = Prob { getProb :: [(a, Rational)] } deriving Show

Isthis a functor? Well, the list is a functor, so this should probably be a
functor, too, because we just added some stuff to the list. When we map a
function over a list, we apply it to each element. Here, we’ll apply it to each

```
For a Few Monads More 337
```

```
elementas well, but we’ll leave the probabilities as they are. Let’s make an
instance:
```
```
instanceFunctor Prob where
fmap f (Prob xs) = Prob $ map (\(x, p) -> (f x, p)) xs
```
```
Weunwrap it from thenewtypewith pattern matching, apply the function
fto the values while keeping the probabilities as they are, and then wrap it
back up. Let’s see if it works:
```
```
ghci>fmap negate (Prob [(3,1%2),(5,1%4),(9,1%4)])
Prob {getProb = [(-3,1 % 2),(-5,1 % 4),(-9,1 % 4)]}
```
```
Notethat the probabilities should always add up to 1. If those are all the
things that can happen, it doesn’t make sense for the sum of their proba-
bilities to be anything other than 1. A coin that lands tails 75 percent of the
time and heads 50 percent of the time seems like it could work only in some
other strange universe.
Now the big question: Is this a monad? Given how the list is a monad,
this looks like it should be a monad as well. First, let’s think aboutreturn.
How does it work for lists? It takes a value and puts it in a singleton list. What
about here? Well, since it’s supposed to be a default minimal context, it
should also make a singleton list. What about the probability? Well,return x
is supposed to make a monadic value that always presentsxas its result, so it
doesn’t make sense for the probability to be 0. If it always must present this
value as its result, the probability should be 1!
What about>>=? Seems kind of tricky, so let’s make use of the fact that
m >>= falways equalsjoin (fmap f m)for monads and think about how we
would flatten a probability list of probability lists. As an example, let’s con-
sider this list where there’s a 25 percent chance that exactly one of'a'or
'b'will happen. Both'a'and'b'are equally likely to occur. Also, there’s a
75 percent chance that exactly one of'c'or'd'will happen.'c'and'd'are
also equally likely to happen. Here’s a picture of a probability list that mod-
els this scenario:
```
```
Whatare the chances for each of these letters to occur? If we were to
draw this as just four boxes, each with a probability, what would those proba-
bilites be? To find out, all we need to do is multiply each probability with all
of the probabilities that it contains.'a'would occur one time out of eight, as
would'b', because if we multiply one-half by one-quarter, we get one-eighth.
```
**338** Chapter 14


'c'wouldhappen three times out of eight, because three-quarters multi-
plied by one-half is three-eighths.'d'would also happen three times out of
eight. If we sum all the probabilities, they still add up to one.
Here’s this situation expressed as a probability list:

thisSituation:: Prob (Prob Char)
thisSituation = Prob
[(Prob [('a',1%2),('b',1%2)], 1%4)
,(Prob [('c',1%2),('d',1%2)], 3%4)
]

Noticethat its type isProb (Prob Char). So now that we’ve figured out
how to flatten a nested probability list, all we need to do is write the code for
this. Then we can write>>=simply asjoin (fmap f m), and we have ourselves
a monad! So here’sflatten, which we’ll use because the namejoinis already
taken:

flatten:: Prob (Prob a) -> Prob a
flatten (Prob xs) = Prob $ concat $ map multAll xs
where multAll (Prob innerxs, p) = map (\(x, r) -> (x, p*r)) innerxs

ThefunctionmultAlltakes a tuple of probability list and a probability
pthat comes with it and then multiplies every inner probability withp, re-
turning a list of pairs of items and probabilities. We mapmultAllover each
pair in our nested probability list, and then we just flatten the resulting
nested list.
Now we have all that we need. We can write aMonadinstance!

instanceMonad Prob where
return x = Prob [(x,1%1)]
m >>= f = flatten (fmap f m)
fail _ = Prob []

Becausewe already did all the hard work, the in-
stance is very simple. We also defined thefailfunction,
which is the same as it is for lists, so if there’s a pattern-
match failure in adoexpression, a failure occurs within
the context of a probability list.
It’s also important to check if the monad laws hold
for the monad that we just made:

1. The first law says thatreturn x >>= fshould be equal
    tofx. A rigorous proof would be rather tedious, but
    we can see that if we put a value in a default context
    withreturn, thenfmapa function over that, and then
    flatten the resulting probability list, every probability
    that results from the function would be multiplied

```
For a Few Monads More 339
```

```
bythe1%1probability that we made withreturn, so it wouldn’t affect the
context.
```
2. The second law states thatm >>= returnis no different thanm. For our
    example, the reasoning form >>= returnbeing equal to justmis similar
    to that for the first law.
3. The third law states thatf <=< (g <=< h)should be the same as(f <=< g)
    <=< h. This one is true as well, because it holds for the list monad that
    forms the basis of the probability monad and because multiplication is
    associative.1%2*(1%3*1%5)is equal to(1%2*1%3)*1%5.

```
Now that we have a monad, what can we do with it? Well, it can help us
do calculations with probabilities. We can treat probabilistic events as values
with contexts, and the probability monad will make sure that those probabil-
ities are reflected in the probabilities of the final result.
Say we have two normal coins and one loaded coin that lands tails an
astounding nine times out of ten and heads only one time out of ten. If we
throw all the coins at once, what are the odds of all of them landing tails?
First, let’s make probability values for a normal coin flip and for a loaded
one:
```
```
dataCoin = Heads | Tails deriving (Show, Eq)
```
```
coin :: Prob Coin
coin = Prob [(Heads,1%2),(Tails,1%2)]
```
```
loadedCoin :: Prob Coin
loadedCoin = Prob [(Heads,1%10),(Tails,9%10)]
```
```
Andfinally, the coin-throwing action:
```
```
importData.List (all)
```
```
flipThree :: Prob Bool
flipThree = do
a <- coin
b <- coin
c <- loadedCoin
return (all (==Tails) [a,b,c])
```
```
Givingit a go, we see that the odds of all three landing tails are not that
good, despite cheating with our loaded coin:
```
```
ghci>getProb flipThree
[(False,1 % 40),(False,9 % 40),(False,1 % 40),(False,9 % 40),
(False,1 % 40),(False,9 % 40),(False,1 % 40),(True,9 % 40)]
```
**340** Chapter 14


Allthree of them will land tails 9 times out of 40, which is less than 25
percent. We see that our monad doesn’t know how to join all of theFalse
outcomes where all coins don’t land tails into one outcome. That’s not a
big problem, since writing a function to put all the same outcomes into one
outcome is pretty easy (and left as an exercise to you, the reader).
In this section, we went from having a question (what if lists also carried
information about probability?) to making a type, recognizing a monad, and
finally making an instance and doing something with it. I think that’s quite
fetching! By now, you should have a pretty good grasp of monads and what
they’re about.

```
For a Few Monads More 341
```


# 15

## ZIPPERS

While Haskell’s purity comes with a whole bunch of

benefits, it makes us tackle some problems differently

than we would in impure languages.

Becauseof referential transparency, one value is as
good as another in Haskell if it represents the same thing.
So, if we have a tree full of fives (high fives, maybe?), and
we want to change one of them into a six, we must have
some way of knowing exactly which five in our tree we want
to change. We need to know where it is in our tree. In im-
pure languages, we could just note where the five is located
in memory and change that. But in Haskell, one five is as
good as another, so we can’t discriminate based on their
location in memory.
We also can’t really _change_ anything. When we say that
we “change a tree,” we actually mean that we take a tree
and return a new one that’s similar to the original, but
slightly different.
One thing we can do is remember a path from the
root of the tree to the element that we want to change. We
could say, “Take this tree, go left, go right and then left


```
again,and change the element that’s there.” While this works, it can be in-
efficient. If we want to later change an element that’s near the element that
we previously changed, we need to walk all the way from the root of the tree
to our element again!
In this chapter, you’ll see how to take some data structure and equip
it with something called a zipper to focus on a part of the data structure
in a way that makes changing its elements easy and walking around it effi-
cient. Nice!
```
## Taking a Walk...................................................................

```
As you learned in biology class, there are many different kinds of trees, so
let’s pick a seed that we will use to plant ours. Here it is:
```
```
dataTree a = Empty | Node a (Tree a) (Tree a) deriving (Show)
```
```
Ourtree is either empty or it’s a node that has an element and two sub-
trees. Here’s a fine example of such a tree, which I give to you, the reader,
for free!
```
```
freeTree:: Tree Char
freeTree =
Node 'P'
(Node 'O'
(Node 'L'
(Node 'N' Empty Empty)
(Node 'T' Empty Empty)
)
(Node 'Y'
(Node 'S' Empty Empty)
(Node 'A' Empty Empty)
)
)
(Node 'L'
(Node 'W'
(Node 'C' Empty Empty)
(Node 'R' Empty Empty)
)
(Node 'A'
(Node 'A' Empty Empty)
(Node 'C' Empty Empty)
)
)
```
**344** Chapter 15


```
Andhere’s this tree represented graphically:
```
```
NoticethatWin the tree there? Say we want to change it into aP. How
would we go about doing that? Well, one way would be to pattern match on
our tree until we find the element, by first going right and then left. Here’s
the code for this:
```
changeToP:: Tree Char -> Tree Char
changeToP (Node x l (Node y (Node _ m n) r)) = Node x l (Node y (Node 'P' m n) r)

```
Yuck!Not only is this rather ugly, it’s also kind of confusing. What is
actually happening here? Well, we pattern match on our tree and name its
root elementx(that becomes the'P'in the root) and its left subtreel. In-
stead of giving a name to its right subtree, we further pattern match on it.
We continue this pattern matching until we reach the subtree whose root is
our'W'. Once we’ve made the match, we rebuild the tree, but with the sub-
tree that contained the'W'at its root now having a'P'.
Is there a better way of doing this? How about if we make our function
take a tree along with a list of directions. The directions will be eitherLorR,
representing left or right, respectively, and we’ll change the element that we
arrive at by following the supplied directions. Check it out:
```
```
dataDirection = L | R deriving (Show)
type Directions = [Direction]
```
```
changeToP :: Directions -> Tree Char -> Tree Char
changeToP (L:ds) (Node x l r) = Node x (changeToP ds l) r
changeToP (R:ds) (Node x l r) = Node x l (changeToP ds r)
changeToP [] (Node _ l r) = Node 'P' l r
```
```
Zippers 345
```

```
Ifthe first element in the list of directions isL, we construct a new tree
that’s like the old tree, but its left subtree has an element changed to'P'.
When we recursively callchangeToP, we give it only the tail of the list of direc-
tions, because we already took a left. We do the same thing in the case of an
R. If the list of directions is empty, that means that we’re at our destination,
so we return a tree that’s like the one supplied, except that it has'P'as its
root element.
To avoid printing out the whole tree, let’s make a function that takes a
list of directions and tells us the element at the destination:
```
```
elemAt:: Directions -> Tree a -> a
elemAt (L:ds) (Node _ l _) = elemAt ds l
elemAt (R:ds) (Node _ _ r) = elemAt ds r
elemAt [] (Node x _ _) = x
```
```
Thisfunction is actually quite similar tochangeToP. The difference is that
instead of remembering stuff along the way and reconstructing the tree, it
ignores everything except its destination. Here, we change the'W'to a'P'
and see if the change in our new tree sticks:
```
```
ghci>let newTree = changeToP [R,L] freeTree
ghci> elemAt [R,L] newTree
'P'
```
```
Thisseems to work. In these functions, the list of directions acts as a sort
of focus , because it pinpoints one exact subtree of our tree. A direction list
of[R]focuses on the subtree that’s to the right of the root, for example. An
empty direction list focuses on the main tree itself.
While this technique may seem cool, it can be rather inefficient, espe-
cially if we want to repeatedly change elements. Say we have a really huge
tree and a long direction list that points to some element all the way at the
bottom of the tree. We use the direction list to take a walk along the tree
and change an element at the bottom. If we want to change another ele-
ment that’s close to the element that we just changed, we need to start from
the root of the tree and walk all the way to the bottom again. What a drag!
In the next section, we’ll find a better way of focusing on a subtree—one
that allows us to efficiently switch focus to subtrees that are nearby.
```
## A Trail of Breadcrumbs...................................................

```
Forfocusing on a subtree, we want something
better than just a list of directions that we al-
ways follow from the root of our tree. Would
it help if we started at the root of the tree and
moved either left or right one step at a time,
leaving “breadcrumbs” along the way? Using
this approach, when we go left, we remember
```
**346** Chapter 15


thatwe went left, and when we go right, we remember that we went right.
Let’s try it.
To represent our breadcrumbs, we’ll also use a list of direction values
(LandRvalues), but instead of calling itDirections, we’ll call itBreadcrumbs,
because our directions will now be reversed as we leave them while going
down our tree.

typeBreadcrumbs = [Direction]

Here’sa function that takes a tree and some breadcrumbs and moves
to the left subtree while addingLto the head of the list that represents our
breadcrumbs:

goLeft:: (Tree a, Breadcrumbs) -> (Tree a, Breadcrumbs)
goLeft (Node _ l _, bs) = (l, L:bs)

Weignore the element at the root and the right subtree, and just return
the left subtree along with the old breadcrumbs withLas the head.
Here’s a function to go right:

goRight:: (Tree a, Breadcrumbs) -> (Tree a, Breadcrumbs)
goRight (Node _ _ r, bs) = (r, R:bs)

```
Itworks the same way as the one to go left.
Let’s use these functions to take ourfreeTreeand go right and then left.
```
ghci>goLeft (goRight (freeTree, []))
(Node 'W' (Node 'C' Empty Empty) (Node 'R' Empty Empty),[L,R])

```
Nowwe have a tree that has'W'in its
root,'C'in the root of its left subtree, and
'R'in the root of its right subtree. The
breadcrumbs are[L,R], because we first
went right and then went left.
To make walking along our tree
clearer, we can use the-:function from
Chapter 13 that we defined like so:
```
x-: f = f x

Thisallows us to apply functions to values by first writing the value, then
a-:, and then the function. So, instead ofgoRight (freeTree, []), we can
write(freeTree, []) -: goRight. Using this form, we can rewrite the preced-
ing example so that it’s more apparent that we’re going right and then left:

ghci>(freeTree, []) -: goRight -: goLeft
(Node 'W' (Node 'C' Empty Empty) (Node 'R' Empty Empty),[L,R])

```
Zippers 347
```

## Going Back Up..........................................................

```
Whatif we want to go back up in our tree? From our breadcrumbs, we know
that the current tree is the left subtree of its parent and that it is the right
subtree of its parent, and that’s all we know. The breadcrumbs don’t tell us
enough about the parent of the current subtree for us to be able to go up in
the tree. It would seem that apart from the direction that we took, a single
breadcrumb should also contain all the other data we need to go back up. In
this case, that’s the element in the parent tree along with its right subtree.
In general, a single breadcrumb should contain all the data needed to
reconstruct the parent node. So, it should have the information from all
the paths that we didn’t take, and it should also know the direction that we
did take. However, it must not contain the subtree on which we’re currently
focusing. That’s because we already have that subtree in the first component
of the tuple. If we also had it in the breadcrumb, we would have duplicate
information.
We don’t want duplicate information because if we were to change some
elements in the subtree that we’re focusing on, the existing information in
the breadcrumbs would be inconsistent with the changes that we made. The
duplicate information becomes outdated as soon as we change something
in our focus. It can also hog a lot of memory if our tree contains a lot of
elements.
Let’s modify our breadcrumbs so that they also contain information
about everything that we previously ignored when moving left and right.
Instead ofDirection, we’ll make a new data type:
```
```
data Crumb a= LeftCrumb a (Tree a) | RightCrumb a (Tree a) deriving (Show)
```
```
Now, instead ofjustL, we have aLeftCrumb, which also contains the ele-
ment in the node that we moved from and the right tree that we didn’t visit.
Instead ofR, we haveRightCrumb, which contains the element in the node that
we moved from and the left tree that we didn’t visit.
These breadcrumbs now contain all the data needed to re-create the
tree that we walked through. So, instead of just being normal breadcrumbs,
they’re more like floppy disks that we leave as we go along, because they con-
tain a lot more information than just the direction that we took.
In essence, every breadcrumb is now like a tree node with a hole in it.
When we move deeper into a tree, the breadcrumb carries all the infor-
mation that the node that we moved away from carried, except the subtree
on which we chose to focus. It also needs to note where the hole is. In the
case of aLeftCrumb, we know that we moved left, so the missing subtree is the
left one.
Let’s also change ourBreadcrumbstype synonym to reflect this:
```
```
type Breadcrumbs a= [Crumb a]
```
**348** Chapter 15


Nextup, we need to modify thegoLeftandgoRightfunctions to store in-
formation about the paths that we didn’t take in our breadcrumbs, instead
of ignoring that information as they did before. Here’sgoLeft:

goLeft:: (Tree a, Breadcrumbs a) -> (Tree a, Breadcrumbs a)
goLeft (Node x l r, bs) = (l, LeftCrumb x r:bs)

Youcan see that it’s very similar to our previousgoLeft, but instead of
just adding aLto the head of our list of breadcrumbs, we add aLeftCrumbto
signify that we went left. We also equip ourLeftCrumbwith the element in the
node that we moved from (that’s thex) and the right subtree that we chose
not to visit.
Note that this function assumes that the current tree that’s under focus
isn’tEmpty. An empty tree doesn’t have any subtrees, so if we try to go left
from an empty tree, an error will occur. This is because the pattern match
onNodewon’t succeed, and there’s no pattern that takes care ofEmpty.
goRightis similar:

goRight:: (Tree a, Breadcrumbs a) -> (Tree a, Breadcrumbs a)
goRight (Node x l r, bs) = (r, RightCrumb x l:bs)

Wewere previously able to go left and right. What we have now is the
ability to actually go back up by remembering stuff about the parent nodes
and the paths that we didn’t visit. Here’s thegoUpfunction:

goUp:: (Tree a, Breadcrumbs a) -> (Tree a, Breadcrumbs a)
goUp (t, LeftCrumb x r:bs) = (Node x t r, bs)
goUp (t, RightCrumb x l:bs) = (Node x l t, bs)

We’refocusing on the
treet, and we check the latest
Crumb. If it’s aLeftCrumb, we con-
struct a new tree using our tree
tas the left subtree and using the
information about the right subtree
and element that we didn’t visit to
fill out the rest of theNode. Because
we “moved back” and picked up the
last breadcrumb, then used it to re-
create the parent tree, the new list
doesn’t contain that breadcrumb.
Note that this function causes an error if we’re already at the top of a
tree and we want to move up. Later on, we’ll use theMaybemonad to repre-
sent possible failure when moving focus.

```
Zippers 349
```

```
Witha pair ofTree aandBreadcrumbs a, we have all the information we
need to rebuild the whole tree, and we also have a focus on a subtree. This
scheme enables us to easily move up, left, and right.
A pair that contains a focused part of a data structure and its surround-
ings is called a zipper , because moving our focus up and down the data struc-
ture resembles the operation of a zipper on a pair of pants. So, it’s cool to
make a type synonym as such:
```
```
typeZipper a = (Tree a, Breadcrumbs a)
```
```
Iwould prefer naming the type synonymFocus, because that makes it
clearer that we’re focusing on a part of a data structure. But since the name
Zipperis more widely used to describe such a setup, we’ll stick with it.
```
## Manipulating Trees Under Focus..........................................

```
Now that we can move up and down, let’s make a function that modifies the
element in the root of the subtree on which the zipper is focusing:
```
```
modify:: (a -> a) -> Zipper a -> Zipper a
modify f (Node x l r, bs) = (Node (f x) l r, bs)
modify f (Empty, bs) = (Empty, bs)
```
```
Ifwe’re focusing on a node, we modify its root element with the func-
tionf. If we’re focusing on an empty tree, we leave it as is. Now we can start
off with a tree, move to anywhere we want, and modify an element, all while
keeping focus on that element so that we can easily move further up or down.
Here’s an example:
```
```
ghci>let newFocus = modify (\_ -> 'P') (goRight (goLeft (freeTree, [])))
```
```
Wego left, then right, and then modify the root element by replacing it
with a'P'. This reads even better if we use-::
```
```
ghci>let newFocus = (freeTree, []) -: goLeft -: goRight -: modify (\_ -> 'P')
```
```
Wecan then move up if we want and replace an element with a mysteri-
ous'X':
```
```
ghci>let newFocus2 = modify (\_ -> 'X') (goUp newFocus)
```
```
Orwe can write it with-::
```
```
ghci>let newFocus2 = newFocus -: goUp -: modify (\_ -> 'X')
```
**350** Chapter 15


Movingup is easy because the breadcrumbs that we leave form the part
of the data structure that we’re not focusing on, but it’s inverted, sort of like
turning a sock inside out. That’s why when we want to move up, we don’t
need to start from the root and make our way down. We just take the top of
our inverted tree, thereby uninverting a part of it and adding it to our focus.
Each node has two subtrees, even if those subtrees are empty. So, if
we’re focusing on an empty subtree, one thing we can do is to replace it
with a nonempty subtree, thus attaching a tree to a leaf node. The code for
this is simple:

attach:: Tree a -> Zipper a -> Zipper a
attach t (_, bs) = (t, bs)

Wetake a tree and a zipper, and return a new zipper that has its focus
replaced with the supplied tree. Not only can we extend trees this way by
replacing empty subtrees with new trees, but we can also replace existing
subtrees. Let’s attach a tree to the far left of ourfreeTree:

ghci>let farLeft = (freeTree, []) -: goLeft -: goLeft -: goLeft -: goLeft
ghci> let newFocus = farLeft -: attach (Node 'Z' Empty Empty)

newFocusisnow focused on the tree that we just attached, and the rest
of the tree lies inverted in the breadcrumbs. If we were to usegoUpto walk all
the way to the top of the tree, it would be the same tree asfreeTree, but with
an additional'Z'on its far left.

## Going Straight to the Top, Where the Air Is Fresh and Clean!................

Making a function that walks all the way to the top of the tree, regardless of
what we’re focusing on, is really easy. Here it is:

topMost:: Zipper a -> Zipper a
topMost (t, []) = (t, [])
topMost z = topMost (goUp z)

Ifour trail of beefed-up breadcrumbs is empty, that means we’re already
at the root of our tree, so we just return the current focus. Otherwise, we go
up to get the focus of the parent node, and then recursively applytopMost
to that.
So, now we can walk around our tree, going left, right, and up, applying
modifyandattachas we travel. Then, when we’re finished with our modifi-
cations, we usetopMostto focus on the root of our tree and see the changes
that we’ve made in proper perspective.

```
Zippers 351
```

## Focusing on Lists.................................................................

```
Zippers can be used with pretty much any data structure, so it’s no surprise
that they work with sublists of lists. After all, lists are pretty much like trees,
except where a node in a tree has an element (or not) and several subtrees,
a node in a list has an element and only a single sublist. When we imple-
mented our own lists in Chapter 7, we defined our data type like so:
```
```
dataList a = Empty | Cons a (List a) deriving (Show, Read, Eq, Ord)
```
```
Comparethis with the definition of our
binary tree, and it’s easy to see how lists can
be viewed as trees where each node has only
one subtree.
A list like[1,2,3]can be written as
1:2:3:[]. It consists of the head of the list,
which is 1 , and then the list’s tail, which is
2:3:[].2:3:[]also has a head, which is 2 ,
and a tail, which is3:[]. With3:[], the 3 is
the head, and the tail is the empty list[].
Let’s make a zipper for lists. To change
the focus on sublists of a list, we move ei-
ther forward or back (whereas with trees, we
move up, left, or right). The focused part will be a subtree, and along with
that, we’ll leave breadcrumbs as we move forward.
Now, what would a single breadcrumb for a list consist of? When we
were dealing with binary trees, the breadcrumb needed to hold the element
in the root of the parent node along with all the subtrees that we didn’t
choose. It also had to remember if we went left or right. So, it needed to
have all the information that a node has, except for the subtree on which
we chose to focus.
Lists are simpler than trees. We don’t need to remember if we went
left or right, because there’s only one way to go deeper into a list. Because
there’s only one subtree to each node, we don’t need to remember the paths
that we didn’t take either. It seems that all we must remember is the previ-
ous element. If we have a list like[3,4,5]and we know that the previous el-
ement was 2 , we can go back by just putting that element at the head of our
list, getting[2,3,4,5].
Because a single breadcrumb here is just the element, we don’t really
need to put it inside a data type, as we did when we made theCrumbdata type
for tree zippers.
```
```
typeListZipper a = ([a], [a])
```
**352** Chapter 15


```
Thefirst list represents the list that we’re focusing on, and the second
list is the list of breadcrumbs. Let’s make functions that go forward and
backward in lists:
```
```
goForward:: ListZipper a -> ListZipper a
goForward (x:xs, bs) = (xs, x:bs)
```
```
goBack :: ListZipper a -> ListZipper a
goBack (xs, b:bs) = (b:xs, bs)
```
```
Whenwe’re going forward, we focus on the tail of the current list and
leave the head element as a breadcrumb. When we’re moving backward, we
take the latest breadcrumb and put it at the beginning of the list. Here are
these two functions in action:
```
```
ghci>let xs = [1,2,3,4]
ghci> goForward (xs, [])
([2,3,4],[1])
ghci> goForward ([2,3,4], [1])
([3,4],[2,1])
ghci> goForward ([3,4], [2,1])
([4],[3,2,1])
ghci> goBack ([4], [3,2,1])
([3,4],[2,1])
```
```
Youcan see that the breadcrumbs in the case of lists are nothing more
than a reversed part of your list. The element that we move away from always
goes into the head of the breadcrumbs. Then it’s easy to move back by just
taking that element from the head of the breadcrumbs and making it the
head of our focus. This also makes it easier to see why we call this a zipper —
it really looks like the slider of a zipper moving up and down.
If you were making a text editor, you could use a list of strings to rep-
resent the lines of text that are currently opened, and you could then use a
zipper so that you know on which line the cursor is currently focused. Using
a zipper would also make it easier to insert new lines anywhere in the text or
delete existing ones.
```
## A Very Simple Filesystem..........................................................

```
To demonstrate how zippers work, let’s use trees to represent a very simple
filesystem. Then we can make a zipper for that filesystem, which will allow
us to move between folders, just as we do when jumping around a real file-
system.
```
```
Zippers 353
```

```
Theaverage hierarchical filesystem is mostly made up of files and fold-
ers. Files are units of data and have names. Folders are used to organize those
files and can contain files or other folders. For our simple example, let’s say
that an item in a filesystem is either one of these:
```
- A file, which comes with a name and some data
- A folder, which has a name and contains other items that are either files
    or folders themselves

```
Here’s a data type for this and some type synonyms, so we know
what’s what:
```
```
typeName = String
type Data = String
data FSItem = File Name Data | Folder Name [FSItem] deriving (Show)
```
```
Afile comes with two strings, which represent its name and the data it
holds. A folder comes with a string that is its name and a list of items. If that
list is empty, then we have an empty folder.
Here’s a folder with some files and subfolders (actually what my disk
contains right now):
```
```
myDisk:: FSItem
myDisk =
Folder "root"
[ File "goat_yelling_like_man.wmv" "baaaaaa"
, File "pope_time.avi" "god bless"
, Folder "pics"
[ File "ape_throwing_up.jpg" "bleargh"
, File "watermelon_smash.gif" "smash!!"
, File "skull_man(scary).bmp" "Yikes!"
]
, File "dijon_poupon.doc" "best mustard"
, Folder "programs"
[ File "fartwizard.exe" "10gotofart"
, File "owl_bandit.dmg" "mov eax, h00t"
, File "not_a_virus.exe" "really not a virus"
, Folder "source code"
[ File "best_hs_prog.hs" "main = print (fix error)"
, File "random.hs" "main = print 4"
]
]
]
```
**354** Chapter 15


## Making a Zipper for Our Filesystem.......................................

Nowthat we have a filesystem, all we need is
a zipper so we can zip and zoom around it,
and add, modify, and remove files and fold-
ers. As with binary trees and lists, our bread-
crumbs will contain information about all
the stuff that we chose not to visit. A single
breadcrumb should store everything except
the subtree on which we’re currently focus-
ing. It should also note where the hole is, so
that once we move back up, we can plug our
previous focus into the hole.
In this case, a breadcrumb should be
like a folder, only it should be missing the
folder that we currently chose. “Why not
like a file?” you ask? Well, because once we’re focusing on a file, we can’t
move deeper into the filesystem, so it doesn’t make sense to leave a bread-
crumb that says that we came from a file. A file is sort of like an empty tree.
If we’re focusing on the folder"root", and we then focus on the file
"dijon_poupon.doc", what should the breadcrumb that we leave look like?
Well, it should contain the name of its parent folder along with the items
that come before and after the file on which we’re focusing. So, all we need
is aNameand two lists of items. By keeping separate lists for the items that
come before the item that we’re focusing on and for the items that come af-
ter it, we know exactly where to place it once we move back up. That way, we
know the location of the hole.
Here’s our breadcrumb type for the filesystem:

dataFSCrumb = FSCrumb Name [FSItem] [FSItem] deriving (Show)

```
Andhere’s a type synonym for our zipper:
```
typeFSZipper = (FSItem, [FSCrumb])

Goingback up in the hierarchy is very simple. We just take the latest
breadcrumb and assemble a new focus from the current focus and bread-
crumb, like so:

fsUp:: FSZipper -> FSZipper
fsUp (item, FSCrumb name ls rs:bs) = (Folder name (ls ++ [item] ++ rs), bs)

Becauseour breadcrumb knew the parent folder’s name, as well as
the items that came before our focused item in the folder (that’sls) and the
items that came after (that’srs), moving up was easy.

```
Zippers 355
```

```
Howabout going deeper into the filesystem? If we’re in the"root"and
we want to focus on"dijon_poupon.doc", the breadcrumb that we leave will in-
clude the name"root", along with the items that precede"dijon_poupon.doc"
and the ones that come after it. Here’s a function that, given a name, fo-
cuses on a file or folder that’s located in the current focused folder:
```
```
importData.List (break)
```
```
fsTo :: Name -> FSZipper -> FSZipper
fsTo name (Folder folderName items, bs) =
let (ls, item:rs) = break (nameIs name) items
in (item, FSCrumb folderName ls rs:bs)
```
```
nameIs :: Name -> FSItem -> Bool
nameIs name (Folder folderName _) = name == folderName
nameIs name (File fileName _) = name == fileName
```
```
fsTotakesaNameand aFSZipperand returns a newFSZipperthat focuses
on the file with the given name. That file must be in the current focused
folder. This function doesn’t search all over the place—it just looks in the
current folder.
First,we usebreakto break the list of
items in a folder into those that precede the
file that we’re searching for and those that
come after it.breaktakes a predicate and a list
and returns a pair of lists. The first list in the
pair holds items for which the predicate re-
turnsFalse. Then, once the predicate returns
Truefor an item, it places that item and the
rest of the list in the second item of the pair.
We made an auxiliary function callednameIs,
which takes a name and a filesystem item and
returnsTrueif the names match.
Nowlsis a list that contains the items that precede the item that we’re
searching for,itemis that very item, andrsis the list of items that come after
it in its folder. Now that we have these, we just present the item that we got
frombreakas the focus and build a breadcrumb that has all the data it needs.
Note that if the name we’re looking for isn’t in the folder, the pattern
item:rswill try to match on an empty list, and we’ll get an error. And if our
current focus is a file, rather than a folder, we get an error as well, and the
program crashes.
So, we can move up and down our filesystem. Let’s start at the root and
walk to the file"skull_man(scary).bmp":
```
```
ghci>let newFocus = (myDisk, []) -: fsTo "pics" -: fsTo "skull_man(scary).bmp"
```
**356** Chapter 15


newFocusisnow a zipper that’s focused on the"skull_man(scary).bmp"file.
Let’s get the first component of the zipper (the focus itself) and see if that’s
really true:

ghci>fst newFocus
File "skull_man(scary).bmp" "Yikes!"

```
Let’smove up and focus on its neighboring file"watermelon_smash.gif":
```
ghci>let newFocus2 = newFocus -: fsUp -: fsTo "watermelon_smash.gif"
ghci> fst newFocus2
File "watermelon_smash.gif" "smash!!"

## Manipulating a Filesystem................................................

Now that we can navigate our filesystem, manipulating it is easy. Here’s a
function that renames the currently focused file or folder:

fsRename:: Name -> FSZipper -> FSZipper
fsRename newName (Folder name items, bs) = (Folder newName items, bs)
fsRename newName (File name dat, bs) = (File newName dat, bs)

```
Let’srename our"pics"folder to"cspi":
```
ghci>let newFocus = (myDisk, []) -: fsTo "pics" -: fsRename "cspi" -: fsUp

Wedescended to the"pics"folder, renamed it, and then moved back up.
How about a function that makes a new item in the current folder?
Behold:

fsNewFile:: FSItem -> FSZipper -> FSZipper
fsNewFile item (Folder folderName items, bs) =
(Folder folderName (item:items), bs)

Easyas pie. Note that this would crash if we tried to add an item but
were focusing on a file instead of a folder.
Let’s add a file to our"pics"folder, and then move back up to the root:

ghci>let newFocus =
(myDisk, []) -: fsTo "pics" -: fsNewFile (File "heh.jpg" "lol") -: fsUp

What’sreally cool about all this is that when we modify our filesystem,
our changes are not actually made in place, but instead, the function returns
a whole new filesystem. That way, we have access to our old filesystem (in
this case,myDisk), as well as the new one (the first component ofnewFocus).

```
Zippers 357
```

```
Byusing zippers, we get versioning for free. We can always refer to older
versions of data structures, even after we’ve changed them. This isn’t unique
to zippers, but it is a property of Haskell, because its data structures are im-
mutable. With zippers, however, we get the ability to easily and efficiently
walk around our data structures, so the persistence of Haskell’s data struc-
tures really begins to shine.
```
## Watch Your Step.................................................................

```
So far, while walking through our data structures—whether they were binary
trees, lists, or filesystems—we didn’t really care if we took a step too far and
fell off. For instance, ourgoLeftfunction takes a zipper of a binary tree and
moves the focus to its left subtree:
```
```
goLeft:: Zipper a -> Zipper a
goLeft (Node x l r, bs) = (l, LeftCrumb x r:bs)
```
```
Butwhat if the tree we’re stepping off from is an empty tree? What if it’s
not aNode, but anEmpty? In this case, we would get a runtime error, because
the pattern match would fail, and we have not made a pattern to handle an
empty tree, which doesn’t have any subtrees.
So far, we just assumed that we would never try to focus on the left sub-
tree of an empty tree, as its left subtree doesn’t exist. But going to the left
subtree of an empty tree doesn’t make much sense, and so far we’ve just con-
veniently ignored this.
Orwhat if we are already at the root of
some tree and don’t have any breadcrumbs
but still try to move up? The same thing
would happen. It seems that when using
zippers, any step could be our last (cue omi-
nous music). In other words, any move can
result in a success, but it can also result in a
failure. Does that remind you of something?
Of course: monads! More specifically, the
Maybemonad, which adds a context of possi-
ble failure to normal values.
Let’s use theMaybemonad to add a con-
text of possible failure to our movements.
We’re going to take the functions that work
on our binary tree zipper and make them
into monadic functions.
First, let’s take care of possible failure
ingoLeftandgoRight. So far, the failure of
functions that could fail was always reflected in their result, and this example
is no different.
```
**358** Chapter 15


```
Here aregoLeftandgoRightwith anadded possibility of failure:
```
goLeft :: Zippera -> Maybe (Zipper a)
goLeft (Node x l r, bs) = Just (l, LeftCrumb x r:bs)
goLeft (Empty, _) = Nothing

goRight :: Zipper a -> Maybe (Zipper a)
goRight (Node x l r, bs) = Just (r, RightCrumb x l:bs)
goRight (Empty, _) = Nothing

```
Now, if wetry to take a step to the left of an empty tree, we get aNothing!
```
ghci> goLeft (Empty,[])
Nothing
ghci> goLeft (Node 'A' Empty Empty, [])
Just (Empty,[LeftCrumb 'A' Empty])

Looks good! Howabout going up? The problem before happened if we
tried to go up but we didn’t have any more breadcrumbs, which meant that
we were already at the root of the tree. This is thegoUpfunction that throws
an error if we don’t keep within the bounds of our tree:

goUp :: Zippera -> Zipper a
goUp (t, LeftCrumb x r:bs) = (Node x t r, bs)
goUp (t, RightCrumb x l:bs) = (Node x l t, bs)

```
Let’s modify itto fail gracefully:
```
goUp :: Zippera -> Maybe (Zipper a)
goUp (t, LeftCrumb x r:bs) = Just (Node x t r, bs)
goUp (t, RightCrumb x l:bs) = Just (Node x l t, bs)
goUp (_, []) = Nothing

If we havebreadcrumbs, everything is okay, and we return a successful
new focus. If we don’t have breadcrumbs, we return a failure.
Before, these functions took zippers and returned zippers, which meant
that we could chain them like this to walk around:

gchi> let newFocus= (freeTree, []) -: goLeft -: goRight

But now, insteadof returningZipper a, they returnMaybe (Zipper a), and
chaining functions like this won’t work. We had a similar problem when we
were dealing with our tightrope walker in Chapter 13. He also walked one
step at a time, and each of his steps could result in failure, because a bunch
of birds could land on one side of his balancing pole and make him fall.

```
Zippers 359
```

```
Nowthe joke is on us, because we’re the ones doing the walking, and
we’re traversing a labyrinth of our own devising. Luckily, we can learn
from the tightrope walker and just do what he did: replace normal func-
tion application with>>=. This takes a value with a context (in our case, the
Maybe (Zipper a), which has a context of possible failure) and feeds it into
a function, while making sure that the context is handled. So just like our
tightrope walker, we’re going to trade in all our-:operators for>>=opera-
tors. Then we will be able to chain our functions again! Watch how it works:
```
```
ghci>let coolTree = Node 1 Empty (Node 3 Empty Empty)
ghci> return (coolTree, []) >>= goRight
Just (Node 3 Empty Empty,[RightCrumb 1 Empty])
ghci> return (coolTree, []) >>= goRight >>= goRight
Just (Empty,[RightCrumb 3 Empty,RightCrumb 1 Empty])
ghci> return (coolTree, []) >>= goRight >>= goRight >>= goRight
Nothing
```
```
Weusedreturnto put a zipper in aJust, and then used>>=to feed that
to ourgoRightfunction. First, we made a tree that has on its left an empty
subtree and on its right a node that has two empty subtrees. When we try to
go right once, the result is a success, because the operation makes sense. Go-
ing right twice is okay, too. We end up with the focus on an empty subtree.
But going right three times doesn’t make sense—we can’t go to the right of
an empty subtree. This is why the result is aNothing.
Now we’ve equipped our trees with a safety net that will catch us should
we fall off. (Wow, I nailed that metaphor.)
```
```
NOTE Our filesystem also has a lot of cases where an operation could fail, such as trying to
focus on a file or folder that doesn’t exist. As an exercise, you can equip our filesystem
with functions that fail gracefully by using theMaybemonad.
```
## Thanks for Reading!..............................................................

```
Or just flipping to the last page! I hope you found this book useful and fun.
I have strived to give you good insight into the Haskell language and its id-
ioms. While there’s always something new to learn in Haskell, you should
now be able to code cool stuff, as well as read and understand other people’s
code. So hurry up and get coding! See you on the other side!
```
**360** Chapter 15




## INDEX

## Index...............................................................................

**Symbols & Numbers**

&& (double ampersand)
as Boolean operator conjunction, 2
using with folds and lists, 78–79
'(apostrophe)
using with functions, 7
using with types, 149–150
* (asterisk)
as multiplication function, 3
using with kinds, 150
** (exponentiation), using with RPN func-
tions, 207–208
\ (backslash), declaring lambdas with, 71
` (backticks) using with functions, 4–5
: (colon)
as cons operator
bytestring version of, 200
using with applicatives, 238–239
using with lists, 8–9
using with infix constructors, 134
:: (double colon)
using in record syntax, 116
using with type annotations, 30, 118
using with types, 24
:k command, identifying kinds with,
150–151
$ (function application operator),
80–81, 83
/ (division), using with RPN functions,
207–208
/= (not-equal-to) operator, 3, 28
= (equal) sign
using with data keyword, 109
using with data types, 122
using with functions, 5
== (double equal sign), 3
using with Eq type class, 28
using with type instances, 139–140

```
!! (double exlamation point)
in Data.List module, 182
using with lists, 9
> (greater-than) operator, using with
lists, 9–10
>> function, replacing, 279
>>= (bind) function
in A Knight’s Quest, 292
nested use of, 280
using with functions as monads, 311
using with monads, 269–270, 272,
274–280, 283–284, 286
using with Reader monad, 312
using with State monad, 316–317
using with Writer type, 302
-> (arrow)
in type signature, 60–61
using with functions, 25
using with lambdas, 71
-> r as functor and monad, 311
< (less-than) operator, using with lists, 9–10
<*> function
calling with applicative values, 236
left-associative, 233
specializing for IO, 234
using with applicative style, 232
using with liftM function, 325
using with zip lists, 237
<= operator, using with lists, 9–10
<$>, using with applicative style, 231–232
<-, using with I/O actions and
functors, 219
```
- (minus) operator, using with sections, 62
() (parentheses)
    minimizing use of, 81, 83
    placement with functions, 7
    using with operations, 2, 5
    using with sections, 62
(,,) function, using with zip lists, 238


**364** INDEX

. (period), using with functions, 89
.. (dots), using with value constructors,
    113–114
+ (plus) operator, 3, 5
++ (concatenation) operator
    excluding from pattern matching, 40
    using with lists, 8
; (semicolon), using with let expressions, 46
[] (square brackets), using with lists, 7, 24
[Char] and String types, 30, 127–128
_ (underscore)
    in pattern matching, 38
    using with lists, 18
| (vertical pipe)
    using with data keyword, 109
    using with data types, 122
    using with guards, 41
|| as Boolean operator disjunction, 2, 256
0 flag, using in Heathrow to London
    example, 216
3D vector type, implementing, 121–122

```
A
accumulators
using with folds, 73
using with right folds, 75
using with scanl and scanr, 79–80
addDrink function, 301–302
algebraic data structures, 137
algebraic data types, 126–127, 133. See also
data types
algebraic expressions, writing, 203–208
All type, using with monoids, 257
ampersands (&&)
as Boolean operator conjunction, 2
using with folds and lists, 78–79
and function
using with applicative functors, 241
using with lists, 78
any function, 92
Any newtype constructor, using with
monoids, 256–257
apostrophe (')
using with functions, 7
using with types, 149–150
appendFile function
in to-do list example, 180
using in I/O, 180
applicative functors, 227–228, 237–238,
```
323. _See also_ functors
Applicative type class, 228–229, 323
functions as, 235–236

```
liftA2 function, 238–239
lists as, 232–234, 243–244, 285–287
Maybe types as, 269–270
sequenceA function, 239–242
upgrading, 267–269
zip lists, 237
applicative laws, 238
applicative operators, vs. monads, 278
applicative style, using on lists, 233–234
Applicative type class, 228–229, 323
Maybe implementation, 229–230
style of pure, 230–232
applyLog function
using with monoids, 300
using with Writer monad, 299–300
arithmetic expressions, 2
arrow (->)
in type signature, 60–61
using with functions, 25
using with lambdas, 71
askForNumber function, 197
as-pattern, 40
association lists, 98–100. See also lists
associativity
defined, 251
using with monads, 294–296
asterisk (*)
as multiplication function, 3
using with kinds, 150
```
```
B
baby.hs file
appending code to, 6
saving, 5
backslash (\), declaring lambdas with, 71
backticks (`) using with functions, 4–5
Banana on a Wire example, 278–280
base case, reaching, 51
binary functions
using on values, 251
using with folds, 73
binary search tree, implementing, 135–137
bind (>>=) function
in A Knight’s Quest, 292
nested use of, 280
using with functions as monads, 311
using with monads, 269–270, 272,
274–280, 283–284, 286
using with Reader monad, 312
using with State monad, 316–317
using with Writer type, 302
binding to variables, 39
```

```
INDEX 365
```
```
birds
ignoring in Pierre example, 278–280
representing in Pierre example, 275–278
BMI (body mass index)
calculation of, 41–42
listing of, 45
repeating calculations of, 43
Boolean algebra, 2
Boolean expressions, using with guards, 41
Boolean values
generating randomly, 191
for tossing coin, 193
Bool type, 26, 143–144, 256–257
Bounded type class, 31–32, 126–127
bracket function, using in I/O, 178–179
bracketOnError function, 183–184
breadcrumbs
in filesystem, 355
representing in trees, 346–348
using with lists and zippers, 352–353
bytestrings, 198–202. See also lists
changing types of, 300
copying files with, 201–202
module functions, 201
as monoids, 300
strict and lazy, 199–201
```
```
C
```
Caesar cipher, 92–94
calculations, performing once, 42–45
capital letters, restriction of, 7
_capslocker.hs_ program
exiting, 171
getContents I/O action, 171
saving and compiling, 170
Car data type, 119–120
case expressions, 48–49
vs. if else statements, 48
vs. let expressions, 48
syntax, 48
cat program, 180–181
characters
converting into numbers, 96
shifting, 93
[Char] and String types, 30, 127–128
CharList value constructor, 245–246, 250
Char type, 26
chessboard example, 290–292
circles, representing, 110–112
class constraints, 140, 142
class declarations, 140

```
code blocks, excluding, 48–49
coin-toss function, 193–195
Collatz sequence, 69–70
colon (:)
as cons operator
bytestring version of, 200
using with applicatives, 238–239
using with lists, 8–9
using with infix constructors, 134
command-line arguments, 184–185
compare function
using Ordering type with, 29
using with guards, 42
using with monoids, 259
computations
deferred, 199
performing, 52
concatenation (++) operator
excluding from pattern matching, 40
using with lists, 8
concrete types, 150–151. See also data types
conditions, adding to list comprehen-
sions, 16
conjunction (&&) Boolean operator, 2
cons (:) operator, using with lists, 8–9
Cons constructor, 133
context of failure, adding to values, 321.
Control.Exception bracketOnError,
183–184
copyFile function, 201
copying files with bytestrings, 201–202
Cube.hs file in Geometry module, 107
Cuboid.hs file in Geometry module, 106
curried functions, 59–62, 222
max, 60
printing functions, 63
sections, 62–63
cycle function, using with lists, 14
```
```
D
```
```
Data.ByteString.Lazy module, 199
Data.Char module, 93, 96
data keyword, 109–110
vs. newtype, 244–245, 248–249
using, 250
Data.List module, 88–89. See also lists
!! function, 182
any function, 92
delete function, 182
group function, 90
tails function, 91–92
words function, 90
```

**366** INDEX

```
Data.Map module, 114.
fromListWith function, 103
lookup function, 100
Map k v parameterized type, 120
Data.Monoid module
Product type, 255–256
Sum type, 255–256
data structures. See also zippers
reducing to values, 73
using zippers with, 352
data types. See also algebraic data types;
concrete types; recursive data struc-
tures; type constructors; type param-
eters; types
3D vector, 121–122
applying to type constructors, 150–152
defining, 109–110, 122
for describing people, 114–117, 123–124
identifying, 150–151
making, 250
record syntax, 116–117
wrapping with newtype keywords,
244–245
Day type, 127
deferred computation, 199
definitions, functions as, 7
deletetodo.hs program, saving and compil-
ing, 182
derived instances, 122–127. See also type
classes
equating people, 123–124
Read type class, 124–125
Show type class, 124–125
deriving keyword, using with newtype, 245
dictionaries, 98
difference lists, using, 307–309
digitToInt function, 96
disjunction (||) Boolean operator, 2
div function, 4–5
division (/), using with RPN functions,
207–208
do expressions. See also monads
actions of, 219
failure of pattern matching in, 284
let lines in, 282
monadic expressions in, 282
monadic values in, 282
results of, 318
writing, 283
do notation, 280–285, 290
and <-, 156
and list comprehensions, 288
pattern matching and failure, 284–285
using with Writer monad, 303–304
```
```
dots (..), using with value constructors,
113–114
double colon (::)
using in record syntax, 116
using with type annotations, 30, 118
using with types, 24
double equal sign (==), 3
using with Eq type class, 28
using with type instances, 139–140
Double type, 26
drop function, using with lists, 12
```
```
E
Either, kind of, 151
Either a b type, 130–132, 149–150
Either e a type, 321–322
elem function
using recursively, 55–56
using with lists, 12
end-of-file character, issuing, 170
Enum type class, 31, 126–127
equal (=) sign
using with data keyword, 109
using with data types, 122
using with functions, 5
equality (== and /=) operators, 3
equality testing, 28
Eq type class, 28, 122–124, 138–139,
141, 250
erroneous computation, representing, 247
error function
calling, 178
using in pattern matching, 39
Error instance, 322
error messages, 3
Euclid’s algorithm, 304–305
exceptions, raising, 178, 247–248
exponentiation (**), using with RPN func-
tions, 207–208
exporting
functions, 104
shapes in modules, 113–114
expressions
determining types of, 24
equivalent examples of, 71–72
lambdas as, 71
using operations in, 2
```
```
F
factorial function, 25, 36
failure, adding context of, 321
False Boolean value, 2–3
```

```
INDEX 367
```
Fibonacci sequence, specifying recur-
sively, 51–52
file contents vs. handles, 177
files
copying with bytestrings, 201–202
processing as strings, 199
reading and writing, 175–180
filesystem
manipulating, 357–358
moving up and down in, 356–357
representing via zippers, 353–358
filter function, 67–70
vs. takeWhile, 80
using fold with, 77
filtering over lists, 198–199
FilterM monadic function, 328–331
fixity declaration, 134
flip function, 65–66, 78
floating-point numbers, precision of, 337
Floating type class, 32
Float type, 25–26
fmap function
concept of, 223
as function composition, 222
as infix function, 221
vs. liftM, 324–325
using over functions, 221
using with newtype, 246
folding function
using with monoids, 262–265
using with RPN, 206–207
foldl function, 74, 76
vs. scanl, 79
stack overflow errors, 94–95
FoldM monadic function, 331–332
fold pattern, example of, 99
foldr function, 75–76, 78–79. _See also_ right
fold function
vs. scanr, 79
using binary search tree with, 137
folds
accumulators, 73
binary functions, 73
concept of, 77–78
examples, 76–77
left vs. right, 75
forever I/O function, 165–166
for loops, 198
forM I/O function, 166–167
fromListWith function, 103
fst function
type of, 27
using with pairs, 20

```
function application operator ($),
80–81, 83
function composition, 82–84
fmap as, 222
module functions, 91
with multiple parameters, 83–84
performing, 89
point-free style, 84–85
right-associative, 82
function f, mapping over function g,
310–311
function parameters, pattern matching
on, 48–49
functional programming, pattern in, 22
functions
```
. (period) symbol used with, 89
accessing, 88
as applicatives, 235–236
applying for monads, 275–276
applying to lists, 66–67
applying with - (minus) operator, 347
behavior of, 153–154
calling, 3–6
combining, 6
concept of, 61
creating, 5–7, 310–311
defining, 35–36
as definitions, 7
exporting from modules, 104
filter, 67–70
as functors, 220–223, 311
importing from modules, 89
infix, 3–4
lifting, 222
loading, 6
in local scope, 46
map, 66–70
mapping with multiple parameters,
    70–71
as monads, 311
optimal path, 212–215
partially applied, 60, 64, 71
polymorphic, 27
prefix, 3–4
printing, 63
referencing from modules, 89
relating to people, 115
searching for, 88
for shapes, 112–113
with side effects, 153–154
syntax, 5
type declarations, 205
types of, 24–25


**368** INDEX

```
functions ( continued )
using, 6–7
using once, 71–73
value constructors as, 110, 112, 114
values returned by, 6–7
for vectors, 121–122
in where blocks, 45
functor laws
1 and 2, 223–225
breaking, 225–227
functors, 218, 323. See also applicative
functors
converting maps into, 149–150
functions as, 220–223
I/O actions as, 218–220
Functor type class, 146–150, 227
definition of, 152
Either a type constructor, 149–150
Maybe type constructor, 147–148
Tree type constructor, 148–149
functor values, functions in, 227
```
```
G
gcd function, 304–306
gcdReverse function, efficiency of, 309
generics vs. type variables, 27
gen generator example, 313
Geometry module, 104–107
getContents I/O action, 171–173
get function, using with state, 318–319
getStdGen I/O action, 195–196
GHC compiler, invoking, 155
GHCi, let expressions in, 47
ghci, typing, 1
ghci> prompt, 1
girlfriend.txt file
caps-locked version of, 180
opening, 175
global generator, implementing, 195
greater-than (>) operator, using with lists,
9–10
greatest common divisor, calculating,
304–305
group function, using with words function,
90–91
guard function, using with monads, 289
guards. See also functions
vs. if/else trees, 41
vs. if expressions, 40–41
otherwise, 41
vs. patterns, 40–41
using, 41–42
```
```
H
haiku.txt input, 170
handles vs. file contents, 177
Haskell
laziness of, 247
as pure language, 313
haystack and needle lists, 91–92
head function, using with lists, 10–11
Heathrow to London example
optimal path function, 212–215
quickest path, 209–211
road system, 211–212
road system from input, 215–216
stack overflow errors, 216
Hello, world! program
compiling, 154–155
defining main, 154
function types, 155
printed output, 155
running, 155
hierarchical modules, 104–106
higher-order functions. See also functions
curried functions, 59–64
flip, 65–66
map, 66–70
type declaration, 63
zipWith, 64–65
Hoogle search engine, 88
```
```
I
id function, 144, 223–224
if else statements vs. case expressions, 48
if/else trees vs. guards, 41
if expressions, 40–41, 143, 145
if statement, 6–7
I’ll Fly Away example, 276–278
importing modules, 88–89
infinite lists, using, 14
infix functions, 3–5, 12, 27. See also
functions
applying, 62–63
defining automatically, 133–134
init function, using with lists, 10–11
input, transforming, 173–175
input redirection, 170
input streams, getting strings from,
171–173
instance declarations, 142
instance keyword, 139
Integer type, 25
Integral type class, 33
interactive mode, starting, 1
Int type, 25
```

```
INDEX 369
```
I/O (input and output)
appendFile function, 180
bracket function, 178–179
files and streams, 169–175
and randomness, 195–198
readFile function, 179
withFile function, 177–178
writeFile function, 179–180
I/O actions
<- vs. let bindings, 159
binding names, 158–159
do blocks, 219
do notation, 156–161
as functors, 218–220
getArgs, 184–185
getContents, 171–173
getLine type, 156
getProgName, 184–185
gluing together, 156–161
let syntax, 158–159
making from pure value, 160
vs. normal values, 157
performing, 155, 157
results yielded by, 153, 157
return function, 160–161
reverseWords function, 159–161
review, 167
in System.Environment module, 184–185
tellFortune function, 157
using sequenceA function with, 242
using with monads, 293
I/O functions
forever, 165–166
forM, 166–167
mapM, 165
print, 162–163
putChar, 162
putStr, 161–162
sequence, 164–165
when, 163–164
IO instance of Applicative, 234–235
isPrefixOf function, using with strings, 92

**J**

join monadic function, 326–328

**K**

:k command, identifying kinds with,
150–151
key/value mappings, achieving, 98–104
Knight’s Quest, A (example), 290–292

```
L
```
```
lambdas, 71–73. See also functions
declaring, 71
in function composition, 82
in Heathrow to London example, 216
using with folds, 74
landLeft and landRight functions, 276–277
last function, using with lists, 10–11
less-than (<) operator, using with lists, 9–10
left fold function, 74. See also foldl function
in Heathrow to London example,
213–215
using with RPN function, 205
Left value, feeding to functions, 322
length function, using with lists, 11, 17–18
let expressions
vs. case expressions, 48
in GHCi, 47
in list comprehensions, 46–47
pattern matching with, 46
using, 45–46
vs. where bindings, 45–46
let keyword
using with lists, 16
using with names, 8
liftA2 function, using with applicative
functors, 238–239
liftM monadic function, 323–326
list comprehensions, 15–18
and do notation, 288
pattern matching with, 38–40
using with tuples, 21–22
list monad, 285–287. See also monads
list operations
cycle function, 14
drop function, 12
elem function, 12
head function, 10–11
init function, 10–11
last function, 10–11
length function, 11
maximum function, 12
null function, 11
odd function, 16
repeat function, 14
replicate function, 15
reverse function, 11
sum function, 12
tail function, 10–11
take function, 12
list ranges, using Enum type in, 29. See also
ranges
```

**370** INDEX

```
lists. See also association lists; bytestrings;
Data.List module; task list program;
zip lists
accessing elements of, 9
adding to, 8
and function, 78
as applicative functors, 232–234,
237–238, 243–244, 285–287
applying functions to, 66–67
binding elements from, 15
checking empty status of, 11
combining, 15–18
comparing, 9–10
concatenation, 8–9
construction of, 306–307
converting trees to, 265
drawing elements from, 15
efficiency of, 306–307
filtering, 15–18, 198–199
folding, 73–74
getting last elements of, 77
including predicates in, 16–17
infinite, 14
inside lists, 9
managing via module functions, 91–92
mapping over, 198–199
as monoids, 253–254, 300
as nondeterministic computations, 233
number ranges in, 13–15
pattern matching with, 38–40
promise of, 199
recursive functions on, 99
replacing odd numbers in, 16
sorting, 56–58
square brackets ([]) used with, 7
transforming, 15–18
vs. tuples, 18, 20, 24
using applicative style on, 233
using with filter function, 67
using with RPN functions, 205–206
using zippers with, 352–353
locker codes, looking up, 132
logging, adding to programs, 304–306
logical or (||), using with monoids, 256
log type, changing type of, 300
log values. See also values
applyLog function, 299–300
implementing, 305–306
using Writer monad for, 298
```
```
M
main
defining for Hello, world!, 154–155
defining for task list, 186
```
```
map function, 66–70, 73, 75
mapM I/O function, 165
mappend function
using with folds and monoids, 263
using with Maybe and Monoid, 260
using with Monoid type class, 252, 254
using with Ordering values, 258–259
using with Writer monad, 300
using with Writer type, 303
mapping over lists, 198–199
maps. See also Data.Map module
vs. association lists, 100
converting association lists to, 100
converting into functors, 149–150
type of keys in, 120
maxBound function, using with Bounded
type, 31
max function, curried, 60
maximum function
in recursion example, 52–53
using with lists, 12
max prefix function, calling, 4
Maybe instance, using with Monad type class,
273–280
Maybe monad
using with trees, 358
vs. Writer monad, 299
Maybe type, 118–119
Applicative implementation, 229–230
for folds and monoids, 262
as functor, 147–148
identifying, 151
implementation of >>=, 280
as instance of Monoid, 260–261
as monad, 269–271
wrapping with newtype, 261
mconcat function, using with Monoid type
class, 252–254, 261
mempty function
using with Monoid type class, 252, 254–255
using with Writer type, 303
vs. mzero, 288–289
messages
decoding, 94
encoding, 93
minBound function, using with Bounded
type, 31
min prefix function, calling, 4
minus (-) operator, using with sections, 62
module functions
Caesar cipher, 93–94
counting words, 90–91
finding numbers, 95–98
list management, 91–92
on strict left folds, 94–95
```

```
INDEX 371
```
modules. _See also_ functions
accessing from GHCi, 88
advantages of, 87
exporting functions, 104
exporting shapes in, 113–114
geometry, 104–106
hierarchical, 106–107
importing, 88–89
loosely coupled, 87
qualified imports of, 89
reading source code for, 89
referencing functions from, 89
monadic functions
composing, 335–336
FilterM, 328–331
FoldM, 331–332
join, 326–328
liftM, 323–326
Monad instance, 311
monad laws, 292–293, 339–340
MonadPlus type class, 288
monads, 323. _See also_ do expressions; list
monad; monoids; Reader monad;
State monad; Writer monad
applying functions, 275–276
associativity, 294–296
do notation, 280–285
functions as, 311
guard function, 289
left identity, 293
making, 336–341
Maybe types as, 269–271
as monoids, 288
in mtl package, 297
nested use of >>=, 280
nondeterministic values, 285–287
purpose of, 268–269
right identity, 294
using with trees, 358–359
MonadState type class, 318–319
Monad type class
>> function, 273, 279
>>= (bind) function, 272–273
fail function, 273, 278, 284
Maybe instance, 273
return function, 272
monoids. _See also_ monads
All type, 257
Any newtype constructor, 256–257
attaching to values, 302
Bool type, 256–257
bytestrings as, 300
comparing strings, 258–259
composition of, 252
Data.Monoid module, 255

```
defined, 252
folding with, 262–265
laws, 253, 255
lists as, 253–254, 300
monads as, 288
newtype keyword, 243–244
numbers as, 254–255
Ordering type, 257–259
type class, 252
using with Writer monad, 306–307
Monoid type class
defining, 252
mappend function, 252, 254, 263
mconcat function, 252–254, 261
mempty function, 252, 254–255
newtype keyword, 243–244
monoid values, including, 304
mtl package, monads in, 297
multiplication (*) function, 3
mzero vs. mempty, 288–289
```
```
N
"\n" (newline) character, adding, 180
names
defining, 8
functions as, 7
needle and haystack lists, 91–92
negative number constants, 2
newline ("\n") character, adding, 180
newStdGen action, 196
newtype declarations, using record syntax
in, 250
newtype keyword, 249–250
vs. data keyword, 244–245, 248–249
using, 247–249
using with monoids, 243–244
using with Product and Sum types, 255–256
using with type class instances, 246–247
using with Writer type, 302
wrapping Maybe with, 261
newtype wrapper, using with State
monad, 317
NO! alert, 143, 145
nondeterministic values
representing, 336
using with monads, 285–287
not Boolean operator, 2
not-equal-to (/=) operator, 3, 28
Nothing value
in do notation, 281
in pattern matching, 284–285
producing in Banana on a Wire, 278–279
null function, using with lists, 11
number constants, negative, 2
```

**372** INDEX

```
number ranges, listing, 13–15
numbers. See also random generators; RPN
expressions
converting characters into, 96
filtering, 288
finding via modules, 95–98
getting chain of, 69–70
guessing, 196–197
inserting in phoneBook, 101–102
as monoids, 254–255
Num type class, 32, 140
```
```
O
odd function, using with lists, 16
operations
precedence of, 4
using in expressions, 2
or (||) Boolean operator, 2
Ordering type, using with monoids, 257–260
order of operations, specifying, 2
Ord type class, 28–29, 125–126, 250
otherwise guards, 41
output, filtering via list
comprehensions, 288
```
```
P
package, defined, 297
pairs, storing data in, 20
parameterized types, 120–122
parameters, using = operator with, 5
parentheses, ()
minimizing use of, 81, 83
placement with functions, 7
using with operations, 2, 5
using with sections, 62
pattern matching, 35–37
as-pattern, 40
error function, 39
failure in do notation, 284–285
failure of, 37
on function parameters, 48–49
with let expressions, 46
with list comprehensions, 38–40
with lists, 38–40
tell function, 39
with tuples, 37–38
using with constructors, 111
using with monads, 338
using with newtype keywords, 247
using with type class instances, 140
with where keyword, 44–45
x:xs pattern, 38
```
```
patterns
vs. guards, 40–41
using with RPN functions, 206
people, describing via data types, 123–124
performance
comparing via Writer monad, 309–310
enhancing via bytestrings, 202
period (.), using with functions, 89
phoneBook
association list, 99, 101–104
using type synonyms with, 128–129
Pierre example
of do notation, 282–284
of monads, 274–280
plus (+) operator, 3, 5
Point data type, using with shapes, 112–113
point-free style
converting function to, 206
defining functions in, 84–85
pole, representing in Pierre example,
274–277
polymorphic functions, 27
pop function, using with stacks,
314–315, 317
powerset, getting, 330
predicates
adding to list comprehensions, 16–17
using with filter function, 67
prefix functions, calling, 3–4
Prelude> prompt, 1
printing
functions, 63
text files to terminal, 180–181
print I/O function, 162–163
probabilities, expressing, 337–339
problems, implementing solutions to, 205
Product type, using with monoids, 255–256
programs, 87
adding logging to, 304–306
exiting, 174
prompt, changing, 1
pure method
using with applicative functors,
228–230, 232
using with zip lists, 237
push function, using with stacks, 314–315
putChar I/O function, 162
put function, using with state, 318–319
putStr I/O function, 161–162
putStrLn function, type of, 155
```
```
Q
quicksort algorithm, 56–58
```

```
INDEX 373
```
```
R
```
-> r, as functor and monad, 311
random data, getting, 190–198
random function, 320. _See also_ functions
RandomGen type class, 191
Random type class, 191
StdGen type, 192
type signature, 191
using, 192
random generators, 313. _See also_ numbers
making, 192
regenerating, 196
randomness and I/O, 195–198
randoms function, 194–195
random string, generating, 195–196
ranges. _See also_ list ranges
using with floating-point numbers, 15
using with lists, 13–15
Rational data type, 337
readability, improving via where keyword, 43
Reader monad, 312. _See also_ monads
readFile function, 179
reading files, 175–180
Read type class, 29–31
record syntax
using in newtype declarations, 250
using to create data types, 116–117
rectangles, representing, 110–112
recursion, 51
approaching, 58
base case, 51
in Heathrow to London example, 215
in mathematics, 51–52
using with applicative functors, 239
using with Functor type class, 148–149
recursive data structures, 132–137. _See also_
data types
algebraic data types, 132–133
binary search tree, 135–137
infix functions, 133–135
recursive definition, 194
recursive functions, 36, 38. _See also_
functions
defining, 51
elem, 55–56
maximum, 52–53
operating on lists, 99
repeat, 55
replicate, 53–54
reverse, 55
take, 54–55
writing, 52–53
zip, 55–56

```
repeat function
using recursively, 55
using with lists, 14
replicate function
using recursively, 53–54
using with lists, 15
return function
in Monad type class, 272
using with Writer type, 303
reverse function
using fold with, 76–77
using recursively, 55
using with lists, 11
reverse polish notation (RPN), 203–208
right fold function, 75–76. See also foldr
function
right triangle, finding, 21–22
Right value, feeding to functions, 322
road system
getting from input, 215–216
representing, 211–212
RPN (reverse polish notation), 203–208
RPN calculator
failures, 334
folding function, 333–334
making safe, 332–334
reads function, 333
RPN expressions, calculating, 204. See also
expressions; numbers
RPN functions. See also functions
sketching, 205–206
writing, 205–207
RPN operators, 207–208
```
```
S
scanl function, 79–80
scanr function, 79–80
sections, using with infix functions, 62–63
semicolon (;), using with let expressions, 46
sequenceA function, using with applicative
functors, 239–242
sequence I/O function, 164–165
set comprehensions, 15
shapes
exporting in modules, 113–114
improving with Point data type, 112–113
representing, 110–112
shortlinesonly.hs program, compiling, 173
shortlines.txt file
redirecting contents of, 173
saving, 172
Show type class, 29
side effects, 153–154
```

**374** INDEX

```
snd function, using with pairs, 20
sorting lists, 56–58
source code, reading for modules, 89
Sphere.hs file, in Geometry module, 106
square brackets ([]), using with lists, 7, 24
square roots, getting for natural
numbers, 80
stack overflow errors, 94, 216
stacks
keeping for RPN functions, 205–206
modeling for stateful computations,
314–315
popping elements from, 314
pushing elements to, 314
state, getting and setting, 318–319
stateful computations, 313–314
assigning types to, 314
stack modeling, 314–315
State monad. See also monads
and randomness, 320
using, 315–318
steps, using with ranges in lists, 13–14
String and [Char] type, 30, 127–128
strings, 8
comparing via monoids, 258–259
converting to uppercase, 128
encoding, 93
getting, 196
getting from input streams, 171–173
isPrefixOf function, 92
processing files as, 199
representing values as, 29
String type, using with type synonyms, 129,
131–132
subclassing type classes, 140
subtrees, focusing on, 346–347
succ: function, calling, 4
sum function
using with fold, 74
using with lists, 12, 17–18
Sum type, using with monoids, 255–256
System.Environment module
getArgs I/O action, 184–185
getProgName I/O action, 184–185
System.IO, openTempFile function, 182
System.Random module
getStdGen I/O action, 195
mkStdGen function, 192
random function, 191–192
```
```
T
:t (type) command, 24, 26, 65
tail function, using with lists, 10–11
```
```
tails function, 91–92
take function
using recursively, 54–55
using with lists, 12
takeWhile function, 69, 80
task list program, 188–189. See also lists
add function, 186–187, 190
bad input, 190
calling, 186–187
dispatch function, 189–190
implementing functions, 186–187
list-viewing functionality, 187
remove function, 187–188
running, 189
view function, 187
tasks. See to-do list
tell function, using with log values,
305–306
terminal
printing text files to, 180–181
reading from, 175
writing to, 175
text files, printing to terminal, 180–181
threeCoins stateful computation, 320
thunk, defined, 199
to-do list
adding tasks to, 185
appendFile function, 180
bracketOnError function, 183
cleaning up, 183–184
deleting items from, 181–183
functionality, 185
removing tasks from, 186
viewing tasks, 186
traffic light, defining states of, 139–140,
144–145
trees. See also zippers
balancing, 135
converting to lists, 265
going to tops of, 351
manipulating under focus, 350–351
mapping, 148
moving up in, 348–350
nodes for monoids, 265
nonempty node for monoids, 264
providing safety nets for, 358–360
representing breadcrumbs, 346–348
subtrees of, 346–347
using monads with, 358–359
using with folds and monoids, 263
in zippers example, 344–346
Tree type constructor, as instance of Func-
tor, 148–149
triangle, right, 21–22
```

```
INDEX 375
```
triples
pattern matching, 38
using with road system, 212
True Boolean value, 2–3
tuples
changing vectors to, 19
fixed size of, 19–20
vs. lists, 18, 20, 24
pairs, 19–20
pattern matching with, 37–38
triples, 19, 21–22
as types, 26
using, 19–20
using commas with, 19
using parentheses with, 19
using with list comprehensions, 21–22
using with road system, 212
using with shapes, 110
two-dimensional vector, representing,
19–20
type annotations, 29
type class constraints, 120–121
type classes, 27, 33, 122–123. _See also_
derived instances
Bounded, 31–32, 126–127
displaying instances of, 142–143
Enum, 31, 126–127
Eq, 28, 123–124, 138–139, 141
Floating, 32
Functor, 146–150
instances of, 141–143
Integral, 33
minimum complete definition of, 139
Monad, 272–273
Num, 32
open quality of, 217
Ord, 28–29, 125–126
Read, 29–31, 124–125
reviewing, 138
Show, 29, 124–125
subclassing, 140
using, 250
YesNo, 143–146
type class instances, using newtype with,
246–247
type constructors, 117. _See also_ data types
applying types to, 150–152
as instances of Functor type class, 218,
225–226
parameters, 150
type parameters for, 141
vs. value constructors, 122, 130
type declarations, 24–25, 205
in higher-order functions, 63
for zipWith function, 64

```
type inference, 23
type instances, making, 139–140
type keyword, 128, 249
type names, capitalization of, 24, 26
type parameters, 117–119. See also
data types
passing types as, 118
using, 119–121
types. See also data types
Bool, 26
Char, 26
Double, 26
Float, 25–26
of functions, 24
Int, 25
Integer, 25
tuples as, 26
type signatures, 110
type synonyms, 127–132, 249–250
Either a b type, 130–132
for knight’s position, 290
parameterizing, 129–130
for zipper in filesystem, 355
type system, 23
type variables, 26–27, 231
```
```
U
undefined value, 247–248
underscore (_)
in pattern matching, 38
using with lists, 18
```
```
V
value constructors
for Either a b type, 130–131
exporting, 113–114
as functions, 110, 112, 114
parameters, 117
vs. type constructors, 122, 130
using .. (dots) with, 113–114
using with shapes, 110
values. See also log values
adding context of failure to, 321
applying functions to, 347
attaching monoids to, 302
concept of, 343
expressing as strings, 29
mapping keys to, 98–104
reducing data structures to, 73
returning in functions, 6–7
testing for equality, 3
using Ord type class with, 28–29
```

**376** INDEX

```
values with contexts, using monads with,
268–269
variables
binding to, 39
binding via let expressions, 45
vectors
changing to tuples, 19
implementing types for, 121–122
vertical pipe (|)
using with data keyword, 109
using with data types, 122
using with guards, 41
```
```
W
```
```
when I/O function, 163–164
where bindings vs. let expressions, 45–46
where blocks, functions in, 45
where keyword, 42–43
pattern matching with, 44–45
scope of, 44
while loops, 198
withFile function, using in I/O, 177–178
words, counting, 90–91
words.txt file, creating and saving, 175
writeFile function, 179–180
Writer monad, 298–300. See also monads
adding logging to programs, 304–306
applyLog function, 299
changing log type, 300
comparing performance, 309–310
difference lists, 307–309
inefficient list construction, 306–307
vs. State monad, 316
using do notation with, 303–304
using monoids with, 300–302, 306–307
Writer type, 302–303
writing files, 175–180
```
```
X
```
```
x:xs pattern, using, 38
```
```
Y
YEAH! alert, 143, 145
YesNo type class, 143–146
```
```
Z
zip function
using recursively, 55–56
using with pairs, 20
zip lists, 237, 244. See also lists
zippers. See also data structures; trees
defined, 350
filesystem example, 353–358
focus of, 350–351
for lists, 352–353
using with data structures, 352
zipWith function, 64–65, 73
```

Thefonts used in _Learn You a Haskell for Great Good!_ are New Baskerville, Fu-
tura, The Sans Mono Condensed and Dogma. The book was typeset with
LATEX2"packagenostarchby Boris Veytsman _(2008/06/06 v1.3 Typesetting
books for No Starch Press)._
This book was printed and bound by Transcontinental, Inc. at Transcon-
tinental Gagné in Louiseville, Quebec, Canada. The paper is Domtar Husky
60# Smooth, which is certified by the Forest Stewardship Council (FSC). The
book has an Otabind binding, which allows it to lie flat when open.



The Electronic Frontier Foundation (EFF)is the leading

organization defending civil liberties in the digital world. We defend

free speech on the Internet, fight illegal surveillance, promote the

rights of innovators to develop new digital technologies, and work to

ensure that the rights and freedoms we enjoy are enhanced —

rather than eroded — as our use of technology grows.

```
EFF has sued telecom giant AT&T for giving the NSA unfettered access to the
private communications of millions of their customers.eff.org/nsa
```
```
EFF’s Coders’ Rights Project is defending the rights of programmers and security
researchers to publish their findings without fear of legal challenges.
eff.org/freespeech
```
```
EFF's Patent Busting Project challenges overbroad patents that threaten
technological innovation. eff.org/patent
```
```
EFF is fighting prohibitive standards that would take away your right to receive and
use over-the-air television broadcasts any way you choose. eff.org/IP/fairuse
```
```
EFF has developed the Switzerland Network Testing Tool to give individuals the tools
to test for covert traffic filtering.eff.org/transparency
```
```
EFF is working to ensure that international treaties do not restrict our free speech,
privacy or digital consumer rights. eff.org/global
```
PRIVACY

FREE SPEECH

INNOVATION

FAIR USE

TRANSPARENCY

INTERNATIONAL

EFF is a member-supported organization. Join Now! [http://www.eff.org/support](http://www.eff.org/support)


_More No-Nonsense Books from_

ELOQUENT JAVASCRIPT

A Modern Introduction to Programming

_by_ MARIJN HAVERBEKE

_Eloquent JavaScript_ is a guide to JavaScript that focuses on good programming
techniques rather than offering a mish-mash of cut-and-paste effects. The
author teaches readers how to leverage JavaScript’s grace and precision to
write real, browser-based applications. The book begins with the fundamentals
of programming—variables, control structures, functions, and data structures—
then moves on to more complex topics, like object-oriented programming,
regular expressions, and browser events. With clear examples and a focus on
elegance, _Eloquent JavaScript_ will have the reader fluent in the language of
the Web in no time.
JANUARY 2011, 224 PP., $29.95
ISBN 978-1-59327-282-1

THE LINUX PROGRAMMING INTERFACE

A Linux and UNIX® System Programming Handbook

_by_ MICHAEL KERRISK
_The Linux Programming Interface_ is the definitive guide to the Linux and UNIX
programming interface—the interface employed by nearly every application that
runs on a Linux or UNIX system. In this authoritative work, Linux programming
expert Michael Kerrisk provides detailed descriptions of the system calls and
library functions that readers need to master the craft of system programming
and accompanies his explanations with clear, complete example programs.
Extensively indexed and heavily cross-referenced, _The Linux Programming Inter-
face_ is both an introductory guide for readers new to the topic of system program-
ming and a comprehensive reference for experienced system programmers.

SEPTEMBER 2010, 1552 PP., $99.95, _hardcover_
ISBN 978-1-59327-220-3

LAND OF LISP

Learn to Program in Lisp, One Game at a Time!

_by_ CONRAD BARSKI, M.D.
Lisp is a uniquely powerful programming language that, despite its academic
reputation, is actually very practical. _Land of Lisp_ brings the language into the
real world, teaching readers Lisp by showing them how to write several com-
plete Lisp-based games, including a text adventure, an evolution simulation, and
a robot battle. While building these games, readers learn the core concepts of
Lisp programming, such as recursion, input/output, object-oriented program-
ming, and macros. And thanks to Lisp’s powerful syntax, the example code is
short and easy to understand. The book is filled with the author’s brilliant Lisp
cartoons, which are sure to appeal to many Lisp fans and, in the tradition of all
No Starch Press titles, make learning more fun.

OCTOBER 2010, 504 PP., $49.95
ISBN 978-1-59327-281-4

NO STARCH PRESS


THE BOOK OF CSS3

A Developer’s Guide to the Future of Web Design

_by_ PETER GASSTON

CSS3 is the latest revision of cascading style sheets, the language used to define
the look and formatting of web documents. A still-evolving standard, CSS3
presents a moving target for developers who need to stay abreast of which fea-
tures are supported by particular web browsers. _The Book of CSS3_ uses real-world
examples to teach developers the fundamentals of the CSS3 specification, high-
lighting the latest developments and future features while paying close attention
to current browser implementations. Each chapter examines a different CSS3
module and teaches the reader to use exciting new features like web fonts,
background images, gradients, 2D and 3D transformations, animation, box
effects, and more.
MAY 2011, 304 PP., $34.95
ISBN 978-1-59327-286-9

MAP SCRIPTING 101

An Example-Driven Guide to Building Interactive Maps with Bing, Yahoo!, and

Google Maps

_by_ ADAM DUVANDER

_Map Scripting 101_ uses a project-based approach to teach readers how to create
useful and fun online map mashups like weather maps and local concert track-
ers. Author Adam DuVander shows readers how to use Mapstraction, an open
source JavaScript library, to create and manipulate basic maps by setting zoom
levels, showing and hiding markers, geocoding addresses, customizing maps
for visitors based on their locales, and so on. Readers will also learn to handle
complex GIS (geographic information system) data and formats like KML and
GeoRSS, and to create graphical overlays to make sense of data and trends.
This book is perfect for any web developer, whether their goal is to build a map
to track earthquakes around the world or to simply mark the best coffee shops
in town.

AUGUST 2010, 376 PP., $34.95
ISBN 978-1-59327-271-5

PHONE:
800.420.7240 OR
415.863.9900
MONDAY THROUGH FRIDAY,
9 A.M. TO 5 P.M. (PST)

FAX:
415.863.9950
24 HOURS A DAY,
7 DAYS A WEEK

```
EMAIL:
SALES@NOSTARCH.COM
```
```
WEB:
WWW.NOSTARCH.COM
```
```
MAIL:
NO STARCH PRESS
38 RINGOLD STREET
SAN FRANCISCO, CA 94103
USA
```

## UPDATES

Visit _[http://www.nostarch.com/lyah.htm](http://www.nostarch.com/lyah.htm)_ for updates, errata, and

other information.



**It’s all in the name: Learn You a Haskell**

**for Great Good! is a hilarious, illustrated**

**guide to this complex functional language.**

**Packed with the author’s original artwork,**

**pop culture references, and, most impor-**

**tantly, useful example code, this book**

**teaches functional fundamentals in a way**

**you never thought possible.**

**You’ll start with the kid stuff: basic syntax,**

**recursion, types, and type classes. Then**

**once you’ve got the basics down, the real**

**black-belt master class begins: you’ll learn to**

**use applicative functors, monads, zippers,**

**and all the other mythical Haskell constructs**

**you’ve only read about in storybooks.**

**As you work your way through the author’s**

**imaginative (and occasionally insane)**

**examples, you’ll learn to:**

**s Laugh in the face of side effects as you**

```
wield purely functional programming
techniques
```
**s Use the magic of Haskell’s “laziness” to**

```
play with infinite sets of data
```
```
s Organize your programs by creating
your own types, type classes, and
modules
```
```
s Use Haskell’s elegant input/output
system to share the genius of your
programs with the outside world
```
```
Short of eating the author’s brain, you will
not find a better way to learn this powerful
language than reading Learn You a Haskell
for Great Good!
```
**About the Author**

```
Miran Lipovacˇa is a computer science
student in Ljubljana, Slovenia. In addition to
his passion for Haskell, he enjoys boxing,
playing bass guitar, and, of course, drawing.
He has a fascination with dancing skeletons
and the number 71, and when he walks
through automatic doors, he
pretends that he’s actually
opening them with
his mind.
```
**Maps, Monads, Monoids, and More!**

```
http://www.nostarch.com
```
```
THE FINEST IN GEEK ENTERTAINMENT™
SHELVE IN:
PROGRAMMING LANGUAGES/
HASKELL
```
```
$ 44 .95 ($ 51 .95 CDN )
```
```
“I LIE FLAT.”
This book uses a lay-flat binding that won't snap shut.
```

