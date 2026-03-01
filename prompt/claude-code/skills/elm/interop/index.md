
---- https://guide.elm-lang.org/interop/ ----
JavaScript Interop
By now we have seen The Elm Architecture, types, commands, subscriptions, and we even have Elm installed locally.
But what happens when you need to integrate with JavaScript? Maybe there is a browser API that does not have an equivalent Elm package yet. Maybe you want to embed a JavaScript widget within your Elm app? Etc. This chapter will outline Elm's three interop mechanisms:
Before we get into the three mechanisms, we need to know how to compile Elm programs to JavaScript!
NOTE: If you are evaluating Elm for use at work, I encourage you to make sure these three mechanisms will be able to cover all of your needs. You can get a quick overview of this chapter by looking at these examples. Please ask here if you are not sure about something, and I encourage you to circle back to Elm later if you are not fully confident.
Compiling to JavaScript
Running elm make
produces HTML files by default. So if you say:
elm make src/Main.elm
It produces an index.html
file that you can just open and start playing with. If you are getting into JavaScript interop, you want to produce JavaScript files instead:
elm make src/Main.elm --output=main.js
This produces a JavaScript file that exposes an Elm.Main.init()
function. So once you have main.js
you can write your own HTML file that does whatever you want.
Embedding in HTML
Here is the minimal HTML needed to make your main.js
appear in a browser:
<html>
<head>
<meta charset="UTF-8">
<title>Main</title>
<script src="main.js"></script>
</head>
<body>
<div id="myapp"></div>
<script>
var app = Elm.Main.init({
node: document.getElementById('myapp')
});
</script>
</body>
</html>
I want to call attention to the important lines here:
<head>
- We have a line to load our compiledmain.js
file. This is required! If you compile an Elm module calledMain
, you will get anElm.Main.init()
function available in JavaScript. If you compile an Elm module namedHome
, you will get anElm.Home.init()
function in JavaScript. Etc.<body>
- We need to do two things here. First, we create a<div>
that we want our Elm program to take over. Maybe it is within a larger application, surrounded by tons of other stuff? That is fine! Second, we have a<script>
to initialize our Elm program. Here we call theElm.Main.init()
function to start our program, passing in thenode
we want to take over.
Now that we know how to embed Elm programs in an HTML document, it is time to start exploring the three interop options: flags, ports, and custom elements!
Note: This is a normal HTML file, so you can put whatever you want in it! Many people load additional JS and CSS files in the
<head>
. That means it is totally fine to write your CSS by hand or to generate it somehow. Add something like<link rel="stylesheet" href="whatever-you-want.css">
in your<head>
and you have access to it. (There are some great options for specifying your CSS all within Elm as well, but that is a whole other topic!)

