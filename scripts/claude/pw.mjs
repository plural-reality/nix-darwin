#!/usr/bin/env node

// This entry point intentionally fails closed. The former helper launched
// persistent/headed Chromium, reused profiles, and accepted fixed CDP ports;
// browser automation now belongs to the Chrome plugin or an explicitly
// isolated, Nix-managed runner.
console.error(
  "pw.mjs is retired: use the Chrome plugin for the user's browser or an explicitly isolated runner."
);
process.exitCode = 64;
