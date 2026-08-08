# Photos business-card scan bridge

## Decision

Do not grant Photos access to Terminal, Codex, Python, or a generic MCP host.
Use a separately named and signed `PhotoLibraryBridge.app` with a fixed read-only
request algebra.

```text
JSON request
  -> photo-library
  -> mode-0600 launchd Unix socket
  -> PhotoLibraryBridge.app/photo-libraryd
  -> PhotoKit metadata / local Vision classification
  -> JSONL records + terminal end record
```

The weekly driver compares stable PhotoKit asset IDs, runs Vision only for new
IDs, and exports only business-card candidates as bounded JPEG derivatives.
The Photos library database and originals are never opened directly.

## Interface

```bash
photo-library status
photo-library authorize
photo-library snapshot
printf '%s\n' '{"op":"classify","spec":{"assetIds":["..."]}}' | photo-library request
printf '%s\n' '{"op":"export","spec":{"assetIds":["..."],"runId":"20260803T160000Z-a1b2"}}' | photo-library request

photo-card-scan run
photo-card-scan pending
photo-card-scan ack RUN_ID
```

Every bridge response is JSONL and ends with an `end` record. Snapshot records
contain only the stable asset ID, creation/modification timestamps, and pixel
dimensions. Classification records contain boolean signals and a score, never
recognized contact text.

The bridge exposes no delete, edit, album mutation, arbitrary path, shell,
JavaScript, SQL, or AppleScript operation. Export destinations are fixed below
`~/Library/Application Support/PhotoLibraryBridge/exports/<validated-run-id>/`.

## Difference and queue semantics

- `photo-card-scan` stores a mode-0600 sorted asset-ID snapshot.
- The first run uses creation time only to inspect the preceding seven days,
  then establishes the full baseline.
- Later runs use set difference, not a timestamp filter. This catches iCloud
  assets whose original creation date predates their local arrival.
- Candidate jobs remain `pending` until the caller has verified Gyazo and
  Scrapbox readback and calls `photo-card-scan ack RUN_ID`.
- A failed downstream card ingestion therefore remains visible even after the
  next Photos snapshot advances.

## Personal Nix binding

The shared repository owns the client, bridge source, tests, protocol, and
skill. `/etc/nix-darwin/personal.nix` owns only the local bundle ID, existing
Apple Development signing identity, direct-exec user LaunchAgent, socket path,
and application-support directories.

The LaunchAgent must execute the signed app binary directly. Do not put a shell
or Home Manager launchd wrapper in front of the TCC-responsible process.

## Activation boundary

1. Build the shared tests and downstream Nix configuration.
2. Apply the downstream configuration or install the exact generated
   LaunchAgent without applying unrelated dirty changes.
3. Run `photo-library-build` to create an immutable signed generation.
4. Run `photo-library authorize` once. The user must select Full Access in the
   macOS prompt or System Settings. Never modify the TCC database.
5. Verify the signature, designated requirement, socket mode, authorization
   status, baseline scan, and pending queue.

Building, prompting, granting, scanning, and publishing are separate states.
