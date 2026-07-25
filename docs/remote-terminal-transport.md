# Remote Terminal Transport (mosh over Tailscale)

Read this before changing `scripts/claude/run-on-mini.sh`, the `programs.tmux` block in
`modules/base.nix`, or any `programs.ssh` settings in a downstream flake.

## The Problem, Decomposed

Three independent problems get collapsed into "tmux is unusable on a train". They are
owned by different layers, and only one layer can solve each.

| # | Problem | Owning layer | Nothing else can fix it |
|---|---|---|---|
| a | Session persistence — processes survive client death | multiplexer (tmux on the always-on host) | transport cannot |
| b | Transport resilience — survives IP change, NAT rebind, blackout | mosh SSP (UDP, re-targets by authenticated source) | tmux config cannot |
| c | Perceived keystroke latency | local echo (mosh prediction) | ssh_config, tmux.conf, terminal emulator cannot |

**(c) is the one people get wrong.** ssh runs in character-at-a-time mode, so one
keystroke costs one full RTT by construction. At 200 ms RTT, keyboard scan (8-22 ms),
terminal rendering (2-10 ms) and display latency (~12 ms) together account for under
15 % of what the user feels. Swapping terminal emulators, tuning ciphers, enabling
`Compression`, or adding `ControlMaster` do not touch this layer at all.

**Window geometry breaking on reconnect is not a resize-policy problem.** It is a tmux
*client lifetime* problem. Since tmux 3.1 the default `window-size` is `latest`, so
attaching makes the newest client authoritative and non-latest clients are excluded from
the size calculation. But that exclusion branch only runs when client count > 1. A single
frozen client still dictates the size, which is why `tmux attach -d` does not help —
detaching it leaves zero clients. mosh removes the failure mode structurally: the client
process never dies, so attach/detach never happens.

## What We Run

```
transport   : mosh (over Tailscale)   -a (always predict) -o (predict-overwrite)
persistence : tmux on the always-on host
fallback    : plain ssh, entering the same tmux session
```

Concept count 2, source of truth 1, boundary 1. mosh is bootstrapped over sshd and dies
with the session — it adds no daemon, no launchd unit, and no new auth surface.

## Alternatives Considered

Map every candidate onto the three layers above before comparing feature lists. Most
alternatives solve (b) and are then marketed as if they solved (c).

| | (a) persistence | (b) transport | (c) local echo | port fwd / scp | resident daemon |
|---|---|---|---|---|---|
| **mosh** | tmux's job | ✅ SSP | ✅ **only one** | ❌ none at all | none |
| quicssh-rs | tmux's job | ✅ QUIC conn. migration | ❌ | ✅ transparent | ✅ UDP 4433 |
| Eternal Terminal | ✅ | ⚠️ TCP reconnect + replay | ❌ by design | ✅ | ✅ root, TCP 2022 |
| zellij remote | ✅ | ⚠️ TCP/WSS | ❌ | ❌ | ✅ web server |
| WezTerm mux | ✅ | ⚠️ TLS reconnect | ✅ | ⚠️ | ✅ mux-server |
| plain ssh | tmux's job | ❌ TCP HOL + RTO backoff | ❌ | ✅ | none (sshd exists) |
| autossh | tmux's job | ⚠️ reconnect = new shell | ❌ | ✅ | none |

**Eternal Terminal** is the one people reach for because it keeps native scrollback. It has
no predictive local echo and never has: upstream issue #40 was closed unimplemented in
2017, no such flag exists on master, and nothing appears through v7.0.0. Its typing
latency therefore equals plain ssh. The price is a root `etserver` resident on TCP 2022.
Its two genuine advantages — terminal-native scrollback and tmux control mode (`-CC`) —
are worth nothing here: we already run tmux, and Ghostty does not implement `-CC`.
(nixpkgs has 6.2.11 on aarch64-darwin, verified to run as an arm64 Mach-O.)

**quicssh-rs** (`oowl/quicssh-rs`, Rust/quinn, 262★, last push 2025-10-27) proxies SSH over
QUIC via `ProxyCommand`, giving connection migration and much better loss recovery than
TCP. It does **not** reduce keystroke latency — QUIC replaces TCP but SSH stays
character-at-a-time, so one keystroke still costs one RTT. The author of the widely-cited
Japanese write-up states this explicitly in his conclusion.

Two things are worth knowing about it anyway:

- It does what mosh structurally cannot: being a transparent proxy, port forwarding,
  scp/sftp, rsync and agent forwarding all keep working. This is relevant to us, because
  `run-on-mini.sh` rsyncs the working tree to the host on first use, and that bulk transfer
  is exactly what suffers from TCP head-of-line blocking on a lossy link. mosh cannot help
  there at all.
- Its README's "Why not mosh?" cites mosh's port range and VSCode-remote incompatibility.
  Neither applies to us: the UDP 60000-61000 range never leaves the tailnet (registering one
  binary with the macOS firewall was the entire cost), and we do not use VSCode remote.

Note also that quicssh-rs's headline feature, connection migration, is already provided by
Tailscale in this setup: peers keep a stable 100.x address, so a TCP connection does not
break when the underlying network changes. What Tailscale does *not* fix is TCP
head-of-line blocking under loss — and mosh's UDP already covers that.

Verdict: mosh remains correct for the interactive path. quicssh-rs is a reasonable future
complement for bulk transfer over a bad link, wired the same way `RUN_ON_MINI_TRANSPORT`
is — swap the `ProxyCommand` for the rsync step only. It is not a replacement.

## Wiring

`scripts/claude/run-on-mini.sh` is the single place that chooses the transport. Its last
lines pick mosh when available and fall back to ssh otherwise:

```sh
if [ "${RUN_ON_MINI_TRANSPORT:-mosh}" = mosh ] && command -v mosh >/dev/null 2>&1; then
  exec mosh -a -o \
    --server="env MOSH_SERVER_NETWORK_TMOUT=604800 LANG=en_US.UTF-8 mosh-server" \
    "$MINI" -- bash -lc "..."
fi
exec ssh -t "$MINI" "bash -lc '...'"
```

This means `cc` and `codex` get the benefit without anyone learning a new command. The
guard keeps the script working on machines without mosh installed.

Flags, and why each is load-bearing:

| Flag / env | Why |
|---|---|
| `-a` (`--predict=always`) | Predict even when the link looks fast. This is the only thing that changes the order of magnitude of felt latency. |
| `-o` (`--predict-overwrite`) | fish's autosuggestion assumes typed text *overwrites* the grey suggestion. Inserting predictions pushes it rightward (upstream mosh issue #932, still open). |
| `MOSH_SERVER_NETWORK_TMOUT=604800` | Without it `mosh-server` waits forever, so every reconnect stacks another zombie server squatting on the same tmux session. |
| `LANG=en_US.UTF-8` | `mosh-server` refuses to start without a UTF-8 locale. |
| `RUN_ON_MINI_TRANSPORT=ssh` | Escape hatch for networks that block UDP 60000-61000. Enters the same tmux session. |

## tmux Defaults Changed in `modules/base.nix`

- `escapeTime` 0 → 25. `escape-time 0` was advice from when tmux's own default was 500 ms
  (through 3.4). Since 3.5 the default is 10 ms, so the original goal (undoing
  home-manager's 500 ms so nvim's ESC is not delayed) no longer requires 0. On a jittery
  link 0 actively hurts: an arrow/Alt escape sequence split across packet boundaries gets
  committed as a lone ESC plus garbage. 25 ms is below the ~40 ms visual-processing
  threshold, so it is not perceptible.
- `allow-passthrough on` replaced with explicit `terminal-features`. OSC 8 hyperlinks have
  been native since tmux 3.4, but tmux only re-emits them when the client advertises the
  `hyperlinks` feature — and Ghostty is not auto-detected (measured:
  `#{client_termfeatures}` contained neither `RGB` nor `hyperlinks`). Declaring the
  features fixes hyperlinks *and* enables truecolor, which had silently been falling back
  to 256 colours. What `allow-passthrough` still grants is the ability for any program to
  bypass tmux's discard-and-repaint throttle and write escapes straight to the terminal,
  which is harmful on a thin link.

## Gotchas (all measured, 2026-07-26)

**`UseKeychain` in ssh_config kills mosh entirely.** It is an Apple-only patch absent from
upstream OpenSSH, and upstream treats unknown options as a *fatal* error, not a warning.
mosh hardcodes its own OpenSSH by absolute path (`.mosh-wrapped` line 78 points at a nix
store openssh), so any `UseKeychain` line makes mosh die with
`Did not find remote IP address (is SSH ProxyCommand disabled?)`. Testing with
`/usr/bin/ssh -o UseKeychain=yes` succeeds and hides the problem. Fix: put
`IgnoreUnknown UseKeychain` earlier in the same block.

**The macOS Application Firewall drops mosh's return UDP.** Symptom:
`mosh: Nothing received from server on UDP port 600xx`, while the ssh bootstrap has
already succeeded and `mosh-server` is running on the host. sshd passes because it is an
Apple binary; a Nix-installed `mosh-server` is an unregistered app. ALF applies even to
traffic arriving over Tailscale's utun. Register it with
`socketfilterfw --add <path>` + `--unblockapp <path>`. ALF records the *real* path, so the
grant silently lapses whenever the store path changes — re-register from an activation
script, not by hand.

**Non-interactive fish over sshd lacks the per-user profile on PATH.**
`/etc/profiles/per-user/<user>/bin` is only added for login shells, so `ssh host cmd`
cannot see `mosh-server` (or tmux, once the Homebrew copy is removed). Add it in
`programs.fish.shellInit` with `fish_add_path --global --append`.

**mosh forces `TERM=xterm-256color` and never sets `COLORTERM`.** `mosh-client` passes the
local `tigetnum("colors")` via `-c`, and the server only sets `xterm-256color` on an exact
match of 256. A direct-colour local terminfo (returning 16777216) therefore downgrades the
remote to plain `xterm`. Declare truecolor via tmux `terminal-features` instead. A useful
side effect: the "Ghostty's `xterm-ghostty` terminfo is missing on the remote" problem
cannot occur under mosh.

## Non-Obvious Non-Problems

Do not spend time on these; each was measured and found irrelevant to felt latency:

- Heavy prompts (starship and friends). A prompt function sleeping 400 ms produced
  byte-for-byte identical per-keystroke output to the default. Prompt functions run once
  per prompt render, not per keystroke.
- fish autosuggestions. They do not change time-to-first-echo. They change *redraw count*
  per keystroke (42 B / 2.25 writes vs 21 B / 1.6 writes with them off). Over ssh that
  second redraw arrives one RTT later, which is what users report as "lag".
- Terminal emulator choice. Typometer puts software-side input latency at 2-10 ms, and
  inter-emulator differences at 5-11 ms — 2-5 % of a 200 ms RTT.
- Nagle. OpenSSH sets `TCP_NODELAY` unconditionally in `apply_qos` (`packet.c`).
- Cipher choice, `Compression`, MTU tuning. Tailscale's tun MTU is fixed at 1280 and
  mosh's datagrams are already 1280.
- Aggressive keepalives. `ServerAliveInterval 5` / `CountMax 3` is a 15-second death
  sentence that cannot outlast Shin-Tanna (~100 s) or Rokko (~200 s). Keepalives that are
  too aggressive do not hold connections open; they kill connections that were recovering.
  Use a long client budget (15 × 20 = 300 s) and a deliberately longer server budget
  (`ClientAliveInterval 15` × `ClientAliveCountMax 24` = 360 s) so the client always gives
  up first.

## Verification

```sh
# Which path is Tailscale on? DERP silently puts mosh's UDP inside TCP and
# removes the head-of-line-blocking advantage that motivated mosh in the first place.
tailscale status | grep <host>          # want "direct <ip:port>", not relay "<region>"

# Does the config parse under the ssh binary mosh actually uses?
<mosh's openssh>/bin/ssh -G <host>      # must not print "Bad configuration option"

# Is mosh-server reachable from the remote's non-interactive PATH?
ssh <host> 'command -v mosh-server'

# End-to-end, from a pty:
mosh -a -o --server="env LANG=en_US.UTF-8 mosh-server" <host> -- /bin/sh -c 'hostname'
```

Do not try to measure predictive local echo with a byte-round-trip harness. Local echo by
definition never crosses the network, so it reads as 0 ms — that is the specification, not
a measurement failure. Compare `--predict=never` against `-a` on slow-motion video, or
judge subjectively.

## Reading

- [Mosh: An Interactive Remote Shell for Mobile Clients](https://mosh.org/mosh-paper.pdf)
  (USENIX ATC 2012) — the SSP design and the latency measurements. The single most
  worthwhile paper here.
- [tmux `options-table.c`](https://github.com/tmux/tmux/blob/master/options-table.c) — the
  only place the `window-size` default is documented; the man page omits it.
- [tmux `resize.c`](https://github.com/tmux/tmux/blob/master/resize.c) —
  `clients_calculate_size`, where the `latest` exclusion branch is gated on n > 1.
- [OpenSSH 9.5 release notes](https://www.openssh.com/txt/release-9.5) —
  `ObscureKeystrokeTiming`, which adds ~10 ms mean by bucketing keystrokes onto a 20 ms grid.
- [Tailscale connection types](https://tailscale.com/kb/1257/connection-types) — direct vs DERP.
- [Typing with pleasure](https://pavelfatin.com/typing-with-pleasure/) — human-side latency
  thresholds worth calibrating against before optimising anything.
- [quicssh-rs](https://github.com/oowl/quicssh-rs) — SSH over QUIC via `ProxyCommand`; see
  its README's architecture diagram for where the relay sits.
- [新幹線でもQUICで快適にSSHする](https://qiita.com/tksst/items/68e8f802822913025286) — the
  best Japanese write-up on quicssh-rs, with `tc`-emulated 30 % packet loss measurements.
  Read the conclusion carefully: loss resilience and IP-change survival improve, RTT does not.
- [Eternal Terminal issue #40](https://github.com/MisterTea/EternalTerminal/issues/40) —
  local echo requested, closed unimplemented; the reason ET does not solve (c).
