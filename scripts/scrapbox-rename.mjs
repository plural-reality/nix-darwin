// scrapbox-rename — rename a Scrapbox/Cosense page in place and repoint every
// backlink to the new title. Sibling of scrapbox-write; shares its managed
// @cosense/std node_modules under ~/.local/share/scrapbox-write/.
//
// The Scrapbox UI rename's "update N links" only repoints plain [Title] links
// (the REST replaceLinks endpoint is the API behind it). This tool runs that
// pass AND additionally rewrites the reference forms replaceLinks leaves behind
// — deep links, icon embeds, and hashtags — so a rename never strands a backlink.
//
// Usage:
//   SCRAPBOX_SID=... scrapbox-rename <project> "<oldTitle>" "<newTitle>" [--dry-run]
//
// On success prints a JSON summary and exits 0.
//
// @cosense/std is imported dynamically inside main() (not at the top level) so
// this module stays pure-importable for the unit tests, which need only
// rewriteLinks and must not resolve the runtime-only node_modules.
import { pathToFileURL } from "node:url";

const die = (msg) => {
  process.stderr.write(`scrapbox-rename: ${msg}\n`);
  process.exit(1);
};

const escapeRegExp = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// Rewrite every Scrapbox reference to page `oldTitle` so it points at `newTitle`.
//
// Scrapbox reference grammar — the forms that genuinely link to a page:
//   [oldTitle]               plain link
//   [oldTitle#<lineId>]      deep link to a line (the lineId anchor is rename-stable)
//   [oldTitle.icon]          icon embed, optionally [oldTitle.icon*N]
//   #oldTitle                hashtag link (a hashtag ends at whitespace, so only a
//                            whitespace-free title can be one)
//
// Deliberately NOT rewritten — these do not reference oldTitle, and rewriting them
// would corrupt a link to a *different* page or an external link's label:
//   [oldTitle other words]   a different page literally titled "oldTitle other words"
//   [oldTitle https://…]     an external link whose label happens to equal oldTitle
//   [oldTitle.bar]           a different page "oldTitle.bar" (.icon is the only special suffix)
//
// Replacer *functions* (not strings) are used so a newTitle containing `$` is
// substituted verbatim rather than interpreted as a backreference.
export const rewriteLinks = (text, oldTitle, newTitle) => {
  const o = escapeRegExp(oldTitle);
  const bracketed = text.replace(
    new RegExp(`\\[${o}(?=\\]|#|\\.icon(?:\\*\\d+)?\\])`, "g"),
    () => `[${newTitle}`,
  );
  return /\s/.test(oldTitle)
    ? bracketed
    : bracketed.replace(
        new RegExp(`(^|\\s)#${o}(?=\\s|$)`, "gm"),
        (_m, pre) => `${pre}#${newTitle}`,
      );
};

const lineText = (l) => (typeof l === "string" ? l : l.text);

const main = async () => {
  const { patch } = await import("@cosense/std/websocket");
  const { replaceLinks } = await import("@cosense/std/rest");

  const [project, oldTitle, newTitle, ...rest] = process.argv.slice(2);
  const dryRun = rest.includes("--dry-run");
  const sid = process.env.SCRAPBOX_SID;

  (!project || !oldTitle || !newTitle) &&
    die('usage: scrapbox-rename <project> "<oldTitle>" "<newTitle>" [--dry-run]');
  !sid && die("SCRAPBOX_SID environment variable is not set");
  oldTitle === newTitle && die("oldTitle and newTitle are identical");

  // Full-text search for pages whose body mentions oldTitle: a candidate net for
  // the sweep. The per-page rewrite is exact, so over-broad search hits are harmless.
  const searchPagesMentioning = async (query) => {
    const url =
      `https://scrapbox.io/api/pages/${encodeURIComponent(project)}` +
      `/search/query?q=${encodeURIComponent(query)}`;
    const res = await fetch(url, {
      headers: { Cookie: `connect.sid=${encodeURIComponent(sid)}` },
    });
    return res.ok ? ((await res.json()).pages ?? []).map((p) => p.title) : [];
  };

  // Repoint every reference form on one page, preserving page ID & history.
  const sweepLinksOnPage = (title) =>
    patch(
      project,
      title,
      (lines, meta) => {
        if (meta?.persistent === false) return undefined;
        const texts = lines.map(lineText);
        const next = texts.map((t) => rewriteLinks(t, oldTitle, newTitle));
        return next.some((t, i) => t !== texts[i]) ? next : undefined;
      },
      { sid },
    );

  // 1) Rename the title line in place. Abort if the page is a phantom or its
  //    first line no longer matches oldTitle (already renamed / wrong target).
  let guard = { existed: false, titleMatched: false, lineCount: 0 };
  const renameResult = await patch(
    project,
    oldTitle,
    (lines, meta) => {
      guard = {
        existed: meta?.persistent !== false,
        titleMatched: lineText(lines[0]) === oldTitle,
        lineCount: lines.length,
      };
      return !guard.existed || !guard.titleMatched || dryRun
        ? undefined // abort (no commit) on guard failure or dry-run preview
        : [newTitle, ...lines.map(lineText).slice(1)];
    },
    { sid },
  );

  !guard.existed && die(`page not found: "${oldTitle}" in ${project}`);
  !guard.titleMatched &&
    die(`first line is not "${oldTitle}" (already renamed?) — aborted`);

  // 2) Repoint plain [oldTitle] backlinks via the authoritative REST link index.
  const linkResult = dryRun
    ? { ok: true, val: "(dry-run: replaceLinks skipped)" }
    : await replaceLinks(project, oldTitle, newTitle, { sid });

  // 3) Sweep the remaining reference forms ([#anchor], [.icon], #tag) page by page.
  //    Sequenced (reduce-over-promises) rather than Promise.all to avoid opening a
  //    websocket storm against Scrapbox.
  const deepFixed = dryRun
    ? []
    : await (await searchPagesMentioning(oldTitle))
        .filter((t) => t !== newTitle) // skip the renamed page itself
        .reduce(
          (acc, title) =>
            acc.then(async (fixed) => {
              const r = await sweepLinksOnPage(title);
              return r?.ok && r.val !== undefined ? [...fixed, title] : fixed;
            }),
          Promise.resolve([]),
        );

  process.stdout.write(
    JSON.stringify(
      {
        project,
        oldTitle,
        newTitle,
        dryRun,
        guard,
        rename: renameResult,
        replaceLinks: linkResult,
        deepLinkPagesFixed: deepFixed,
      },
      null,
      2,
    ) + "\n",
  );
  process.exit(0);
};

const isEntry = import.meta.url === pathToFileURL(process.argv[1] ?? "").href;
isEntry && main().catch((e) => die(e?.stack || String(e)));
