---
name: elm
description: >
  Elm functional frontend-language reference (the official guide.elm-lang.org,
  Elm compiles to JavaScript). Use when writing, reading, or reviewing Elm code,
  designing with The Elm Architecture (Model/update/view/Msg), modeling state
  with custom types and type aliases, exhaustive pattern matching, handling JSON
  decoders / HTTP / random / time via commands and subscriptions, error handling
  with Maybe and Result, JS interop (flags, ports, custom elements), building
  multi-page web apps (Browser.document, routing, URL parsing, module structure),
  installing/configuring the Elm toolchain and editor, or optimizing with
  Html.Lazy and Html.Keyed and shrinking asset size. Trigger on .elm edits, Elm
  compiler/type errors, and questions about Elm idioms, types, or packages.
---

# Elm — Functional Frontend Language Reference

This skill bundles the official Elm guide (guide.elm-lang.org) split by chapter as reference material. Elm is a delightful, statically typed functional language that compiles to JavaScript with no runtime exceptions in practice. The collection covers the language fundamentals, The Elm Architecture, the type system, effects, error handling, JS interop, multi-page web apps, the toolchain, and optimization.

Key themes across the library:
- **Language & types**: values, functions, custom types, type aliases, type inference, exhaustive pattern matching
- **The Elm Architecture (TEA)**: Model / update / view / Msg, the pattern behind Redux
- **Effects & data**: commands & subscriptions, HTTP, JSON decoders/encoders, random, time
- **Robustness**: errors-as-data with `Maybe` and `Result`
- **Integration & apps**: JS interop (flags, ports, custom elements), routing, URL parsing, module structure
- **Tooling & performance**: install/editor setup, `Html.Lazy`, `Html.Keyed`, asset-size reduction

## When to use this skill

Invoke when the user asks about:
- Elm syntax, idioms, or core-language concepts (values, functions, lists, tuples, records)
- The Elm Architecture — wiring `Model`, `update`, `view`, and `Msg`; buttons, text fields, forms
- The type system — reading type annotations, type aliases, custom (union) types, pattern matching
- Effects — commands & subscriptions, making HTTP requests, JSON decoding/encoding, randomness, time
- Error handling — modeling failure as data with `Maybe` and `Result` instead of exceptions
- JavaScript interop — passing flags, communicating over ports, embedding custom elements, and interop limits
- Building real web apps — `Browser.document`, navigation, URL parsing, and structuring modules/projects
- Installing Elm, setting up the compiler and editor integration
- Optimization — `Html.Lazy`, `Html.Keyed`, and reducing compiled asset size
- Designing with the "make impossible states impossible" mindset (types as sets)

---

## Additional Resources

### Getting started

- [index.md](index.md) — An Introduction to Elm: what Elm is, a quick increment/decrement sample, and how the guide is structured
- [core_language.md](core_language.md) — Core language tour: values, functions, `if` expressions, lists, tuples, records
- [install/](install/) — Getting Elm working locally: installing the compiler ([elm.md](install/elm.md)) and editor integration ([editor.md](install/editor.md))

### The Elm Architecture

- [architecture/](architecture/) — The Model / View / Update pattern that structures every Elm app. Worked examples for [buttons](architecture/buttons.md), [text fields](architecture/text_fields.md), and [forms](architecture/forms.md)

### Types

- [types/](types/) — Type inference, [reading type annotations](types/reading_types.md), [type aliases](types/type_aliases.md), [custom types](types/custom_types.md), and [pattern matching](types/pattern_matching.md)

### Effects (commands & subscriptions)

- [effects/](effects/) — Talking to the outside world: how `Cmd`/`Sub` work, plus [HTTP](effects/http.md), [JSON](effects/json.md) decoders/encoders, [random](effects/random.md), and [time](effects/time.md)

### Error handling

- [error_handling/](error_handling/) — Treating errors as data with [Maybe](error_handling/maybe.md) and [Result](error_handling/result.md)

### JavaScript interop

- [interop/](interop/) — Compiling to JS and the three interop mechanisms: [flags](interop/flags.md), [ports](interop/ports.md), [custom elements](interop/custom_elements.md), and their [limits](interop/limits.md)

### Web apps

- [webapps/](webapps/) — Building multi-page apps: `Browser.document`, [navigation](webapps/navigation.md), [URL parsing](webapps/url_parsing.md), [modules](webapps/modules.md), and [project structure](webapps/structure.md)

### Optimization

- [optimization/](optimization/) — Performance via [Html.Lazy](optimization/lazy.md) and [Html.Keyed](optimization/keyed.md), and reducing [asset size](optimization/asset_size.md)

### Going further

- [next_steps.md](next_steps.md) — Where to go after the guide: things to build and community resources
- [appendix/](appendix/) — Deeper mental models: [types as sets](appendix/types_as_sets.md), [types as bits](appendix/types_as_bits.md), and [function types](appendix/function_types.md)
