#!/usr/bin/env node
// scrapbox-write: Hermetic Scrapbox page writer via @cosense/std WebSocket patch.
// Reads page body from stdin, writes to Scrapbox.
//
// Usage:
//   echo "line1\nline2" | scrapbox-write --project tkgshn-private --title "Page Title"
//   scrapbox-write -p plural-reality -t "Meeting Notes" < body.txt
//
// Environment:
//   SCRAPBOX_SID — connect.sid cookie value (URL-decoded, starts with "s:")

import { patch } from "@cosense/std/websocket";

const die = (msg) => { process.stderr.write(`scrapbox-write: ${msg}\n`); process.exit(1); };

const parseArgs = (argv) =>
  argv.slice(2).reduce(
    (acc, arg, i, arr) =>
      arg === "--project" || arg === "-p" ? { ...acc, project: arr[i + 1] } :
      arg === "--title"   || arg === "-t" ? { ...acc, title:   arr[i + 1] } :
      acc,
    { project: "plural-reality", title: undefined }
  );

const readStdin = () =>
  new Promise((resolve, reject) => {
    const chunks = [];
    process.stdin.on("data", (chunk) => chunks.push(chunk));
    process.stdin.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
    process.stdin.on("error", reject);
  });

const main = () => {
  const args = parseArgs(process.argv);
  const sid = process.env.SCRAPBOX_SID;

  !sid        && die("SCRAPBOX_SID environment variable is not set");
  !args.title && die("--title (-t) is required");

  return readStdin().then((body) => {
    const lines = [args.title, ...body.split("\n").map((l) => ` ${l}`)];
    return patch(args.project, args.title, () => lines, { sid })
      .then((result) =>
        result.ok
          ? process.stdout.write(`https://scrapbox.io/${args.project}/${encodeURIComponent(args.title)}\n`)
          : die(`patch failed: ${JSON.stringify(result)}`)
      );
  });
};

main();
