
---- https://hackage.haskell.org/package/polysemy-1.9.2.0 ----
polysemy
Overview
polysemy
is a library for writing high-power, low-boilerplate domain specific
languages. It allows you to separate your business logic from your
implementation details. And in doing so, polysemy
lets you turn your
implementation code into reusable library code.
It's like mtl
but composes better, requires less boilerplate, and avoids the
O(n^2) instances problem.
It's like freer-simple
but more powerful.
It's like fused-effects
but with an order of magnitude less boilerplate.
Additionally, unlike mtl
, polysemy
has no functional dependencies, so you
can use multiple copies of the same effect. This alleviates the need for ugly
hacks band-aids like
classy lenses,
the
ReaderT
pattern
and nicely solves the
trouble with typed errors.
Concerned about type inference? polysemy
comes with its companion
polysemy-plugin
,
which helps it perform just as well as mtl
's! Add polysemy-plugin
to your
package.yaml
or .cabal
file's dependencies
section to use. Then turn it on with a pragma in your source files:
{-# OPTIONS_GHC -fplugin=Polysemy.Plugin #-}
Or by adding -fplugin=Polysemy.Plugin
to your package.yaml
/.cabal
file ghc-options
section.
Features
- Effects are higher-order, meaning it's trivial to write
bracket
and local
as first-class effects.
- Effects are low-boilerplate, meaning you can create new effects in a
single-digit number of lines. New interpreters are nothing but functions and
pattern matching.
Tutorials and Resources
Examples
Make sure you read the
Necessary Language Extensions
before trying these yourself!
Teletype effect:
{-# LANGUAGE TemplateHaskell, LambdaCase, BlockArguments, GADTs
, FlexibleContexts, TypeOperators, DataKinds, PolyKinds, ScopedTypeVariables #-}
import Polysemy
import Polysemy.Input
import Polysemy.Output
data Teletype m a where
ReadTTY :: Teletype m String
WriteTTY :: String -> Teletype m ()
makeSem ''Teletype
teletypeToIO :: Member (Embed IO) r => Sem (Teletype ': r) a -> Sem r a
teletypeToIO = interpret \case
ReadTTY -> embed getLine
WriteTTY msg -> embed $ putStrLn msg
runTeletypePure :: [String] -> Sem (Teletype ': r) a -> Sem r ([String], a)
runTeletypePure i
-- For each WriteTTY in our program, consume an output by appending it to the
-- list in a ([String], a)
= runOutputMonoid pure
-- Treat each element of our list of strings as a line of input
. runInputList i
-- Reinterpret our effect in terms of Input and Output
. reinterpret2 \case
ReadTTY -> maybe "" id <$> input
WriteTTY msg -> output msg
echo :: Member Teletype r => Sem r ()
echo = do
i <- readTTY
case i of
"" -> pure ()
_ -> writeTTY i >> echo
-- Let's pretend
echoPure :: [String] -> Sem '[] ([String], ())
echoPure = flip runTeletypePure echo
pureOutput :: [String] -> [String]
pureOutput = fst . run . echoPure
-- echo forever
main :: IO ()
main = runM . teletypeToIO $ echo
Resource effect:
{-# LANGUAGE TemplateHaskell, LambdaCase, BlockArguments, GADTs
, FlexibleContexts, TypeOperators, DataKinds, PolyKinds
, TypeApplications #-}
import Polysemy
import Polysemy.Input
import Polysemy.Output
import Polysemy.Error
import Polysemy.Resource
-- Using Teletype effect from above
data CustomException = ThisException | ThatException deriving Show
program :: Members '[Resource, Teletype, Error CustomException] r => Sem r ()
program = catch @CustomException work \e -> writeTTY $ "Caught " ++ show e
where
work = bracket (readTTY) (const $ writeTTY "exiting bracket") \input -> do
writeTTY "entering bracket"
case input of
"explode" -> throw ThisException
"weird stuff" -> writeTTY input *> throw ThatException
_ -> writeTTY input *> writeTTY "no exceptions"
main :: IO (Either CustomException ())
main
= runFinal
. embedToFinal @IO
. resourceToIOFinal
. errorToIOFinal @CustomException
. teletypeToIO
$ program
Easy.
Friendly Error Messages
Free monad libraries aren't well known for their ease-of-use. But following in
the shoes of freer-simple
, polysemy
takes a serious stance on providing
helpful error messages.
For example, the library exposes both the interpret
and interpretH
combinators. If you use the wrong one, the library's got your back:
runResource
:: forall r a
. Sem (Resource ': r) a
-> Sem r a
runResource = interpret $ \case
...
makes the helpful suggestion:
• 'Resource' is higher-order, but 'interpret' can help only
with first-order effects.
Fix:
use 'interpretH' instead.
• In the expression:
interpret
$ \case
Necessary Language Extensions
You're going to want to stick all of this into your package.yaml
file.
ghc-options: -O2 -flate-specialise -fspecialise-aggressively
default-extensions:
- DataKinds
- FlexibleContexts
- GADTs
- LambdaCase
- PolyKinds
- RankNTypes
- ScopedTypeVariables
- TypeApplications
- TypeOperators
- TypeFamilies
Building with Nix
The project provides a basic nix config for building in development.
It is defined as a flake with backwards compatibility stubs in default.nix
and shell.nix
.
To build the main library or plugin:
nix-build -A polysemy
nix-build -A polysemy-plugin
Flake version:
nix build
nix build '.#polysemy-plugin'
To inspect a dependency:
nix repl
> p = import ./.
> p.unagi-chan
To run a shell command with all dependencies in the environment:
nix-shell --pure
nix-shell --pure --run 'cabal v2-haddock polysemy'
nix-shell --pure --run ghcid
Flake version:
nix develop -i # just enter a shell
nix develop -i -c cabal v2-haddock polysemy
nix develop -i -c haskell-language-server-wrapper # start HLS for your IDE
Previous versions of this README
mentioned the library being
zero-cost, as in having no visible effect on performance. While this was
the original motivation and main factor in implementation of this library, it
turned out that
optimizations we depend on,
while showing amazing results in small benchmarks, don't work in
bigger, multi-module programs,
what greatly limits their usefulness.
What's more interesting though is that
this isn't a polysemy
-specific problem - basically all popular effects
libraries ended up being bitten by variation of this problem in one way or
another, resulting in
visible drop in performance
compared to equivalent code without use of effect systems.
Why did nobody notice this?
One factor may be that while GHC's optimizer is
very, very good in general in optimizing all sorts of abstraction, it's
relatively complex and hard to predict - authors of libraries may have not
deemed location of code relevant, even though it had big effect at the end.
The other is that maybe it doesn't matter as much as we like to tell
ourselves. Many of these effects
libraries are used in production and they're doing just fine, because maximum
performance usually matters in small, controlled areas of code, that often
don't use features of effect systems at all.
What can we do about this?
Luckily, the same person that uncovered this problems proposed a
solution -
set of primops that will allow interpretation of effects at runtime, with
minimal overhead. It's not zero-cost as we hoped for with polysemy
at
first, but it should have negligible effect on performance in real life and
compared to current solutions, it should be much more predictable and even
resolve some problems with behaviour of
specific effects.
You can try out experimental library that uses proposed features
here.
When it comes to polysemy
, once GHC proposal lands, we will consider the option of
switching to an implementation based on it. This will probably require some
breaking changes, but should resolve performance issues and maybe even make
implementation of higher-order effects easier.
If you're interested in more details, see
Alexis King's
talk about the problem,
Sandy Maguire's
followup about how it relates to polysemy
and
GHC proposal that
adds features needed for new type of implementation.
TL;DR
Basically all current effects libraries (including polysemy
and
even mtl
) got performance wrong - but, there's ongoing work on extending
GHC with features that will allow for creation of effects implementation with
stable and strong performance. It's what polysemy
may choose at some point,
but it will probably require few breaking changes.
The following is a non-exhaustive list of people and works that have had a
significant impact, directly or indirectly, on polysemy
’s design and
implementation:

