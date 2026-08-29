#!/usr/bin/env node

// Shared macOS is not an automation sandbox. The former implementation launched
// a detached Google Chrome headless process on a fixed CDP port and kept a
// persistent profile alive after its caller exited. Keep this adapter fail
// closed until the monitor is moved to a dedicated VM/display or a broker that
// owns a run-scoped browser lease.
const result = {
  ok: false,
  status: "安全のため停止",
  reason:
    "GMO監視は共有デスクトップ上のheadless Chrome/CDPを使わない設計へ移行するまで停止しています。専用VM/displayで再有効化してください。",
  source: "disabled-shared-desktop",
};

process.stdout.write(`${JSON.stringify(result)}\n`);
process.exitCode = 78;
