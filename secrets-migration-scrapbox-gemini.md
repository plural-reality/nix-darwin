# SOPS migration plan — SCRAPBOX_SID / GEMINI_API_KEY

Status: **wiring prepared (not yet activated)**. 2026-06-22.

## Why

Two plaintext secret leaks exist today:

- `SCRAPBOX_SID` is set in `personal.nix` `home.sessionVariables` as plaintext, and
  `modules/claude-code.nix` projects it into `~/.claude/settings.json` `env` — which is a
  **world-readable `/nix/store` path**. It is also duplicated (with a DIFFERENT, likely
  stale value) in the hand-edited `~/.claude/settings.local.json` `env`.
- `GEMINI_API_KEY` is plaintext in `~/.claude/settings.local.json`.

This violates the repo's own SSH-key SOPS doctrine (`prompt/engineering.md`): "鍵はディスクに平文で保存しない".

## Existing machinery (already wired, reuse it)

- `sops-nix` HM module is imported (`personal.nix` L103).
- `secrets.yaml` (repo root + `/etc/nix-darwin/secrets.yaml`) is age-encrypted to
  recipient `age13ld8gy634vgv4dxrwfh2scl92w4rr580dg43ae7a75as0eplcygq8ul9r0`; age key at
  `~/.config/sops/age/keys.txt`.
- Pattern in use: runtime `${pkgs.sops}/bin/sops decrypt --extract '["KEY"]' secrets.yaml`
  (see the `gws` wrapper, `personal.nix` L136). No plaintext ever hits the store.

## Activation steps (do when ready to rotate)

1. **Rotate first** (both are already exposed):
   - SCRAPBOX_SID: log into scrapbox.io in the browser, copy the fresh `connect.sid` cookie
     (URL-decoded, starts with `s:`).
   - GEMINI_API_KEY: regenerate in Google AI Studio; revoke the old key.

2. **Add to secrets.yaml** (encrypted):
   ```sh
   cd /etc/nix-darwin   # or the upstream checkout
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops set secrets.yaml '["scrapbox_sid"]' '"<NEW_SID>"'
   SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops set secrets.yaml '["gemini_api_key"]' '"<NEW_KEY>"'
   ```

3. **Wire into nix** — render decrypted secrets to runtime files and export from the shell
   instead of baking into the store. In `personal.nix` `home-manager.users.tkgshn`:
   ```nix
   sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
   sops.defaultSopsFile = /etc/nix-darwin/secrets.yaml;
   sops.secrets.scrapbox_sid = { };   # → renders to a 0400 file outside the store
   sops.secrets.gemini_api_key = { };
   ```
   Then export at shell init (fish) so Claude Code / Codex / hooks inherit it at runtime:
   ```nix
   programs.fish.shellInit = ''
     test -r "${config.sops.secrets.scrapbox_sid.path}"; and set -gx SCRAPBOX_SID (cat ${config.sops.secrets.scrapbox_sid.path})
     test -r "${config.sops.secrets.gemini_api_key.path}"; and set -gx GEMINI_API_KEY (cat ${config.sops.secrets.gemini_api_key.path})
   '';
   ```

4. **Remove the plaintext sources**:
   - Delete `SCRAPBOX_SID` from `home.sessionVariables` in `personal.nix` (so it stops being
     projected into the world-readable store `settings.json`). Remove it from
     `sharedAgentEnvNames` in `modules/claude-code.nix` if present.
   - Delete the `env` block (`GEMINI_API_KEY`, `SCRAPBOX_SID`) from
     `~/.claude/settings.local.json`.

5. `cd /etc/nix-darwin && ./apply`, then verify:
   - `grep -c SCRAPBOX_SID ~/.claude/settings.json` → 0 (no longer in store).
   - new shell: `echo $SCRAPBOX_SID | head -c 8` shows the rotated value.
   - `cosense-fetch --me` succeeds (Scrapbox auth still works).

## Note

Until step 4 runs, Scrapbox auth keeps working off the current plaintext value, so this can
be activated in one deliberate pass without an intermediate broken state.
