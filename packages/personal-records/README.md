# Personal record search

Pinned upstream CLIs provide Hatena Bookmark, Gyazo and Cosense searches through
stdio MCP in Claude Code and Codex. Enable through downstream `userConfig.personalRecords`:
`hatenaUser`, `defaultProject`, `gyazoTokenFile`, `cosenseTokenFile`.
Only secret file paths enter Nix; values are read at process startup.

MCP servers expose read operations only. The upstream Gyazo CLI also contains
upload commands; MCP does not expose these. Launchers use an empty immutable cwd
and official origins to avoid project `.env` overrides. Cosense's runtime HTTP
boundary allows authenticated requests only to https://scrapbox.io, disables
redirects, and keeps anonymous Gyazo oEmbed available. Error response bodies are
omitted. No arbitrary MCP shell or code execution is added.

Build `nix build .#hatebucli .#gyazocli .#cosensecli --no-link`. Install checks
exercise the stdio handshake, read-only tool list and rejection of unknown writes.
Cosense also tests destination rejection before network I/O and redirect policy.
Source revisions and npm closure hashes are recorded in sources.json.

Hatena's past-day search reads a local cache. Run `hatebu sync --days 30` or
`hatebu sync --date YYYY-MM-DD` to fetch a bounded range. An uncached day is a gap,
not evidence of no bookmarks. Gyazo and Cosense searches are live.

CLI examples: `hatebu search QUERY --json`, `gyazo search QUERY --json`,
`cosensecli doctor`. MCP tools accept a specific project for Cosense searches;
the default project is a convenience, not an authorization limit. Bookmarks do
not imply that a page was read or endorsed. AI hypotheses and source records
remain distinct; these tools do not auto-create Cosense pages.

A ChatGPT web connection is separate from local MCP configuration. It needs an
OpenAI Secure MCP Tunnel and account-side connection; local installation alone
does not create a ChatGPT plugin or expose a public server.
