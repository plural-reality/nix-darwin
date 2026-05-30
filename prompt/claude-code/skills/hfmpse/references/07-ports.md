# 7. Ports (JavaScript Interop)

### Pattern

```elm
-- src/Ports.elm
port module Ports exposing (..)

-- Outgoing (Elm → JS)
port saveToLocalStorage : { key : String, value : String } -> Cmd msg
port copyToClipboard : String -> Cmd msg
port shareViaWebShare : { title : String, url : String } -> Cmd msg

-- Incoming (JS → Elm)
port onLocalStorageLoaded : ({ key : String, value : String } -> msg) -> Sub msg
port onClipboardResult : (Bool -> msg) -> Sub msg
port onWindowResize : ({ width : Int, height : Int } -> msg) -> Sub msg
port onDarkModeChange : (Bool -> msg) -> Sub msg
```

```javascript
// index.html / main.js
const app = Elm.Main.init({ flags: { ... } });

app.ports.saveToLocalStorage.subscribe(({ key, value }) => {
  localStorage.setItem(key, value);
});

app.ports.copyToClipboard.subscribe((text) => {
  navigator.clipboard.writeText(text).then(
    () => app.ports.onClipboardResult.send(true),
    () => app.ports.onClipboardResult.send(false)
  );
});

// Dark mode detection
const mq = window.matchMedia('(prefers-color-scheme: dark)');
app.ports.onDarkModeChange.send(mq.matches);
mq.addEventListener('change', (e) => app.ports.onDarkModeChange.send(e.matches));

// Window resize for elm-ui classifyDevice
app.ports.onWindowResize.send({ width: window.innerWidth, height: window.innerHeight });
window.addEventListener('resize', () => {
  app.ports.onWindowResize.send({ width: window.innerWidth, height: window.innerHeight });
});
```

### Rules

- Ports are the ONLY way to interact with JavaScript. Never use `Html.Events.on` with `Json.Decode.value` hacks.
- Every outgoing port that expects a result must have a corresponding incoming port.
- Port names use camelCase matching Elm conventions.

