# Servant — Type-Level Web DSL for Haskell

Servant is a set of Haskell libraries for writing type-safe web applications. It uses a type-level DSL to describe web APIs as Haskell types, then derives servers, clients, documentation, and more from that single API description. The key insight is **reifying the API as a type**: the compiler checks that server handlers conform to the API, client functions match the API, and documentation stays in sync — all statically. Extensibility is achieved through open type families and type classes, making both the DSL and its interpretations open for extension without modifying existing code.

## When to use this skill

- Defining a web API as a Haskell type and implementing its server with `servant-server`
- Generating type-safe Haskell client functions with `servant-client`
- Generating JavaScript client code or OpenAPI/Swagger documentation from an API type
- Structuring APIs with combinators (`:>`, `:<|>`, `NamedRoutes`)
- Implementing authentication (Basic Auth, JWT, OpenID Connect)
- Integrating databases (SQLite, PostgreSQL, MySQL) with Servant handlers
- Streaming responses, file uploads, pagination, or custom content types
- Testing Servant applications with `hspec` and `servant-client`
- Understanding the type-level generic programming techniques behind Servant

---

## Additional Resources

### Theory & Design
- [servant-wgp.md](servant-wgp.md) — Academic paper: "Type-level Web APIs with Servant — An exercise in domain-specific generic programming." Covers the design rationale, type-level DSL grammar, the `HasServer`/`HasClient`/`HasLink` type class machinery, content-type negotiation, extensibility (expression problem), and the connection to datatype-generic programming.
- [principles.rst](principles.rst) — Guiding principles: concision, flexibility, separation of concerns, and type safety.
- [links.rst](links.rst) — External links: GitHub repo, Hackage packages, IRC channel, mailing list, blog posts.
- [examples.md](examples.md) — Curated list of example projects: minimal servant, servant+elm, servant+PureScript, servant+persistent, and more.

### Tutorial (start here)
- [Install](tutorial/install.rst) — Setting up the tutorial project with cabal or stack.
- [A web API as a type](tutorial/ApiType.lhs) — Core concepts: defining API types with combinators (`Capture`, `ReqBody`, `QueryParam`, `Get`, `Post`, `:<|>`, `:>`).
- [Serving an API](tutorial/Server.lhs) — Implementing server handlers with `servant-server`, the `Server` type family, running with Warp.
- [Querying an API](tutorial/Client.lhs) — Deriving Haskell client functions with `servant-client`, auto-generated from the API type.
- [Generating JavaScript functions](tutorial/Javascript.lhs) — Generating JS client code to query a Servant API from the browser.
- [Documenting an API](tutorial/Docs.lhs) — Auto-generating API documentation in Markdown from the API type.
- [Authentication in Servant](tutorial/Authentication.lhs) — Basic Authentication and generalized/ad-hoc authentication schemes.

### Cookbook — API Structure & Patterns
- [Structuring APIs](cookbook/structuring-apis/StructuringApis.lhs) — Splitting APIs into sub-APIs, sharing common structure between routes.
- [Record-based APIs (NamedRoutes)](cookbook/named-routes/NamedRoutes.lhs) — Defining APIs using Haskell records with `NamedRoutes` (Servant 0.19+).
- [OpenAPI / Swagger](cookbook/openapi3/OpenAPI.lhs) — Generating OpenAPI 3 specifications and serving Swagger UI.
- [UVerb: Alternative responses](cookbook/uverb/UVerb.lhs) — Listing alternative response types and exceptions in API types using open unions.
- [MultiVerb: Powerful endpoint types](cookbook/multiverb/MultiVerb.lhs) — Endpoints with multiple response types, status codes, and headers.
- [Custom errors](cookbook/custom-errors/CustomErrors.lhs) — Customizing error responses (e.g., wrapping Servant's error messages in JSON).
- [Pagination](cookbook/pagination/Pagination.lhs) — Type-safe pagination with `servant-pagination` (offset/limit, cursor-based, ordering).

### Cookbook — Authentication & Security
- [Basic Authentication](cookbook/basic-auth/BasicAuth.lhs) — Protecting endpoints with HTTP Basic Auth.
- [JWT and Basic Auth combined](cookbook/jwt-and-basic-auth/JWTAndBasicAuth.lhs) — Combining JWT-based browser auth with Basic Auth for programmatic clients.
- [OpenID Connect](cookbook/open-id-connect/OpenIdConnect.lhs) — Authenticating users via OpenID Connect (Google OIDC provider example).
- [HTTPS](cookbook/https/Https.lhs) — Serving Servant applications over HTTPS with `warp-tls`.

### Cookbook — Database Integration
- [MySQL basics](cookbook/db-mysql-basics/MysqlBasics.lhs) — Single-module Servant API with MySQL, including basic CRUD operations.
- [SQLite with sqlite-simple](cookbook/db-sqlite-simple/DBConnection.lhs) — Using SQLite to store and retrieve data in Servant handlers.
- [PostgreSQL connection pool](cookbook/db-postgres-pool/PostgresPool.lhs) — PostgreSQL integration with connection pooling via `resource-pool`.

### Cookbook — Server Patterns
- [Using a custom monad](cookbook/using-custom-monad/UsingCustomMonad.lhs) — Reader monad + STM for shared in-memory state across handlers.
- [Hoist Server With Context](cookbook/hoist-server-with-context/HoistServerWithContext.lhs) — Combining `hoistServerWithContext` with custom monads (e.g., `ReaderT env IO`).
- [File upload (multipart/form-data)](cookbook/file-upload/FileUpload.lhs) — Handling multipart file uploads in Servant.
- [Basic streaming](cookbook/basic-streaming/Streaming.lhs) — Streaming responses without external streaming libraries.
- [Infinite streams](cookbook/infinite-streams/InfiniteStreams.lhs) — Serving infinite HTTP streams with resource management considerations.
- [Request-lifetime managed resources](cookbook/managed-resource/ManagedResource.lhs) — Resources automatically created/destroyed per request by Servant.
- [Expose Prometheus metrics](cookbook/expose-prometheus/ExposePrometheus.lhs) — Instrumenting Servant applications with Prometheus metrics.
- [Error logging with Sentry](cookbook/sentry/Sentry.lhs) — Capturing runtime exceptions with Sentry via `raven-haskell`.

### Cookbook — Client & Testing
- [Using Servant.Client.Free](cookbook/using-free-client/UsingFreeClient.lhs) — Inspecting, debugging, and simulating client requests with the free monad client.
- [Generating mock curl calls](cookbook/curl-mock/CurlMock.lhs) — Generating curl commands with mock data from a Servant API using `servant-foreign`.
- [Testing Servant applications](cookbook/testing/Testing.lhs) — Testing strategies: unit tests, integration tests with `hspec` and `servant-client`.
