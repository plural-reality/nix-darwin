---
name: functional-swift
description: >
  Write Swift code in a functional, immutable, type-safe style for iOS/macOS development.
  Use this skill whenever the user asks to write, generate, review, refactor, or design
  Swift code — especially when they mention functional programming, immutability, value types,
  pure functions, composition, or type safety. Also trigger when the user asks for architecture
  advice on SwiftUI apps, state management, error handling patterns, or data transformation
  pipelines in Swift. Even if the user just says "write this in Swift" without mentioning
  functional style, apply this skill to produce high-quality functional Swift by default.
  Trigger on: Swift code generation, Swift code review, Swift refactoring, SwiftUI architecture,
  iOS app design patterns, "make this more functional", "clean up this Swift code",
  struct vs class decisions, error handling design, Combine/async patterns.
---

# Functional Swift

Write Swift code that is functional, immutable, and type-safe. This skill covers three modes:
**code generation**, **code review / refactoring**, and **architecture consultation**.

## Core Philosophy

Functional programming builds programs by composing expressions — not by sequencing
imperative statements that mutate state. In Swift, this means:

1. **Expressions over statements** — Prefer `let` bindings, ternary expressions, `switch`
   expressions, and method chains over `var` + mutation loops.
2. **Values over references** — Default to `struct` and `enum`. Use `class` only when
   identity semantics or reference sharing is genuinely needed (e.g., `ObservableObject`).
3. **Pure functions over side effects** — A function should return the same output for the
   same input. Isolate side effects (network, disk, UI) at the system boundary.
4. **Composition over inheritance** — Build behavior by combining small functions and
   protocol conformances rather than deep class hierarchies.

These are not academic ideals — they directly reduce bugs, simplify concurrency,
and make code easier to test and reason about.

---

## 1. Immutable Value Types

### Default to `struct` + `let`

Every new data type starts as a `struct` with `let` properties unless there is a concrete
reason to do otherwise. This is the single most impactful habit.

```swift
// ✅ Good — immutable value type
struct User {
    let id: UUID
    let name: String
    let email: String
}

// ❌ Avoid — mutable reference type for plain data
class User {
    var id: UUID
    var name: String
    var email: String
}
```

### Updating immutable structs

When you need a "modified copy", provide a `with`-style method or use Swift's
memberwise copy pattern:

```swift
struct User {
    let id: UUID
    let name: String
    let email: String

    func withName(_ newName: String) -> User {
        User(id: id, name: newName, email: email)
    }
}

// Usage: creates a new value, original is untouched
let updated = user.withName("Yui")
```

For types with many fields, use a `copying` pattern with a closure:

```swift
extension User {
    func copy(mutating transform: (inout MutableUser) -> Void) -> User {
        var mutable = MutableUser(from: self)
        transform(&mutable)
        return mutable.toUser()
    }
}
```

### When `var` is acceptable

- **Local computation scope** — A `var` inside a function body that does not escape
  is fine when it makes the algorithm clearer (e.g., accumulator in a loop).
  Even then, prefer `reduce` or `map` if the intent is a transformation.
- **SwiftUI `@State` / `@Binding`** — These are designed for controlled local mutation
  within the view lifecycle. Use them, but keep the state surface small.
- **`mutating` on structs** — Acceptable for ergonomic APIs, since struct mutation
  is copy-on-write and does not create shared mutable state.

### When `class` is justified

- `ObservableObject` — SwiftUI requires reference semantics here.
- Wrapping a system resource that has identity (file handle, socket, Core Data context).
- Explicit shared state behind a controlled interface (actor or synchronized wrapper).

In every case, document *why* a `class` is chosen.

---

## 2. Higher-Order Functions & Composition

### Transform, don't loop

Replace imperative loops with `map`, `filter`, `reduce`, `compactMap`, `flatMap`,
and `sorted(by:)`. These express *what* you want, not *how* to iterate.

```swift
// ❌ Imperative
var activeNames: [String] = []
for user in users {
    if user.isActive {
        activeNames.append(user.name)
    }
}

// ✅ Functional
let activeNames = users
    .filter(\.isActive)
    .map(\.name)
```

### Function composition

Build complex transformations by chaining small, named functions:

```swift
func normalize(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespaces).lowercased()
}

func isValid(_ s: String) -> Bool {
    !s.isEmpty && s.count <= 100
}

// Compose via pipeline
let cleanInputs = rawInputs
    .map(normalize)
    .filter(isValid)
```

When a pipeline grows long, extract named intermediate steps or helper functions
rather than writing one massive chain.

### Custom operators — use sparingly

Swift supports custom operators (e.g., `>>>` for forward composition), but they
reduce readability for teammates unfamiliar with them. Prefer named functions
and method chains unless the team has agreed on a set of operators.

```swift
// Composition operator (use only if team convention)
func >>> <A, B, C>(f: @escaping (A) -> B, g: @escaping (B) -> C) -> (A) -> C {
    { a in g(f(a)) }
}

let process = normalize >>> validate
```

### Lazy evaluation

For large collections, use `.lazy` to avoid creating intermediate arrays:

```swift
let result = hugeArray.lazy
    .filter(\.isActive)
    .map(\.name)
    .prefix(10)
// Only evaluates what's needed for the first 10 matches
```

---

## 3. Result / Optional — Monadic Error Handling

### Optional as Maybe monad

`Optional` is Swift's built-in `Maybe`. Use `map`, `flatMap`, and `compactMap`
instead of nested `if let` when transforming optional values:

```swift
// ❌ Pyramid of doom
if let data = data {
    if let json = try? JSONSerialization.jsonObject(with: data) {
        if let dict = json as? [String: Any] {
            // ...
        }
    }
}

// ✅ Flat chain
let value = data
    .flatMap { try? JSONSerialization.jsonObject(with: $0) }
    .flatMap { $0 as? [String: Any] }
    .flatMap { $0["key"] as? String }
```

### Result for typed errors

Use `Result<Success, Failure>` to make error paths explicit and composable:

```swift
enum AppError: Error {
    case networkFailure(underlying: Error)
    case decodingFailure(underlying: Error)
    case notFound
}

func fetchUser(id: UUID) async -> Result<User, AppError> {
    do {
        let data = try await network.get("/users/\(id)")
        let user = try decoder.decode(User.self, from: data)
        return .success(user)
    } catch let error as DecodingError {
        return .failure(.decodingFailure(underlying: error))
    } catch {
        return .failure(.networkFailure(underlying: error))
    }
}

// Compose with map/flatMap
let userName = fetchUser(id: someID)
    .map(\.name)
```

### When to use `throws` vs `Result`

- **`throws`** — Good for call sites that handle errors immediately (e.g., top-level
  controller code, simple scripts). Works naturally with `try await`.
- **`Result`** — Good for storing outcomes, passing them around, or composing
  error-handling chains functionally. Useful in Combine pipelines.

Both are valid. Pick one style per layer and be consistent.

---

## 4. Protocol + Generics — Type-Safe Abstraction

### Protocol as typeclass

Use protocols to define capabilities, similar to Haskell typeclasses:

```swift
protocol Identifiable {
    associatedtype ID: Hashable
    var id: ID { get }
}

protocol Persistable: Encodable {
    static var storageKey: String { get }
}
```

### Generics over `Any`

Avoid `Any` and `AnyObject`. Use generics to preserve type information:

```swift
// ❌ Loses type safety
func first(of array: [Any]) -> Any? { array.first }

// ✅ Preserves type
func first<T>(of array: [T]) -> T? { array.first }
```

### Constrained extensions

Add functionality to types that satisfy specific constraints:

```swift
extension Array where Element: Numeric {
    var sum: Element {
        reduce(.zero, +)
    }
}

// Now [1, 2, 3].sum == 6
```

### Phantom types for compile-time safety

Use phantom types to encode state or units at the type level:

```swift
enum Validated {}
enum Unvalidated {}

struct Email<Status> {
    let rawValue: String
}

func validate(_ email: Email<Unvalidated>) -> Email<Validated>? {
    email.rawValue.contains("@")
        ? Email<Validated>(rawValue: email.rawValue)
        : nil
}

// Can't accidentally pass unvalidated email to a function expecting validated
func sendWelcome(to email: Email<Validated>) { ... }
```

---

## 5. SwiftUI Architecture Patterns

### View as pure function of state

A SwiftUI `View` is already a value type that declares UI as a function of state.
Lean into this:

```swift
struct UserProfileView: View {
    let user: User          // Input — immutable
    let onEdit: () -> Void  // Callback — no internal mutation

    var body: some View {
        VStack {
            Text(user.name)
            Button("Edit", action: onEdit)
        }
    }
}
```

Prefer injecting data and callbacks over having views own mutable state.

### Unidirectional data flow

For complex state, use a reducer pattern (similar to Elm / Redux):

```swift
enum Action {
    case increment
    case decrement
    case reset
}

struct AppState {
    let count: Int

    func reduce(_ action: Action) -> AppState {
        switch action {
        case .increment: return AppState(count: count + 1)
        case .decrement: return AppState(count: count - 1)
        case .reset:     return AppState(count: 0)
        }
    }
}
```

State is always replaced, never mutated in place. Each `reduce` call returns a
new `AppState` value.

### Isolate side effects

Side effects (network calls, persistence, analytics) belong at the boundary:

```swift
// Pure: computes what to display
func viewModel(from state: AppState) -> ViewModel { ... }

// Impure: performs the effect
func execute(_ effect: Effect) async { ... }
```

Keep the pure core large and the impure shell thin.

---

## 6. Code Review Checklist

When reviewing Swift code, check for these functional quality signals:

1. **Unnecessary `var`** — Can this be `let`? Can the mutation be replaced with
   `map`/`reduce`?
2. **Class used for data** — Should this be a `struct`?
3. **Force unwrap `!`** — Replace with `guard let`, `??`, or optional chaining.
4. **Nested `if let`** — Flatten with `flatMap`, `guard let`, or early return.
5. **Mutable shared state** — Can this be modeled as a value passed through
   a pipeline instead?
6. **Large `switch` with side effects** — Can each case return a value instead?
7. **Callback hell** — Can this use `async/await` or Combine?
8. **`Any` / `AnyObject`** — Can generics or a protocol preserve type safety?
9. **God object** — Can responsibilities be split into composable protocols?
10. **Missing access control** — Mark internals as `private` or `internal`;
    expose only what's needed.

When suggesting refactors, show before/after with explanation of why the
functional version is better (fewer states, easier to test, thread-safe, etc.).

---

## Decision Guide

```
User wants to...        → Do this
─────────────────────────────────────────────
Write new Swift code     → Generate functional code following all principles above.
                           Default to struct, let, higher-order functions, Result.

Review existing code     → Apply the review checklist. Identify imperative patterns
                           and propose functional alternatives with before/after.

Refactor code            → Transform in place: var→let, class→struct, loop→map,
                           nested if-let→flatMap, scattered state→reducer.

Design / architecture    → Recommend unidirectional data flow, value-type models,
                           protocol-based abstractions, and thin impure shell.
                           Draw on Elm/Redux/TCA patterns where appropriate.

Debug concurrency issue  → Look for shared mutable state first. Suggest value types
                           or actors to eliminate data races.
```

---

## Anti-patterns to actively avoid

- **Stringly-typed APIs** — Use enums with associated values instead of raw strings.
- **Singleton mutable state** — Use dependency injection with protocols.
- **Delegate explosion** — Prefer closures or Combine publishers.
- **Massive view controller** — Extract pure logic into standalone functions.
- **Default parameters hiding complexity** — Make dependencies explicit.
