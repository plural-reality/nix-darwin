#!/usr/bin/env -S deno run --allow-all

/**
 * gemini-rag.ts - RAG tool using Gemini File Search API
 *
 * State Convergence Implementation:
 * - Hash-based change detection (SHA-256)
 * - Differential sync (add/update/delete)
 * - Local files are Source of Truth
 */

import { GoogleGenAI } from "npm:@google/genai";
import { walk } from "jsr:@std/fs/walk";
import { basename, extname } from "jsr:@std/path";
import { parseArgs } from "jsr:@std/cli/parse-args";
import { crypto } from "jsr:@std/crypto";
import { encodeHex } from "jsr:@std/encoding/hex";

// ==========================================
// Functional Core & Types
// ==========================================

type Result<T, E = Error> =
  | { readonly success: true; readonly value: T }
  | { readonly success: false; readonly error: E };

const ok = <T>(value: T): Result<T> => ({ success: true, value });
const fail = <E>(error: E): Result<never, E> => ({ success: false, error });
const isSuccess = <T, E>(r: Result<T, E>): r is { success: true; value: T } => r.success;

const mapResult = <T, U, E>(r: Result<T, E>, fn: (v: T) => U): Result<U, E> =>
  r.success ? ok(fn(r.value)) : r;

const safeAsync = async <T>(fn: () => Promise<T>): Promise<Result<T, Error>> => {
  try {
    return ok(await fn());
  } catch (e) {
    return fail(e instanceof Error ? e : new Error(String(e)));
  }
};

// Chunk array into batches (pure)
const chunk = <T>(arr: readonly T[], size: number): readonly (readonly T[])[] =>
  arr.length === 0
    ? []
    : [arr.slice(0, size), ...chunk(arr.slice(size), size)];

// ==========================================
// Configuration (Pure Data)
// ==========================================

const SUPPORTED_EXTENSIONS: ReadonlySet<string> = new Set([
  ".txt", ".md", ".py", ".js", ".ts", ".html", ".css", ".json", ".yaml", ".yml",
  ".sh", ".bash", ".zsh", ".nix", ".hs", ".c", ".cpp", ".h", ".rs", ".go",
  ".pdf", ".csv",
]);

// API constraints (max pageSize for documents.list is 20)
const API_PAGE_SIZE = 20 as const;

// Performance tuning
const UPLOAD_CONCURRENCY = 10 as const; // Parallel upload limit
const RAG_MODEL = "gemini-3-pro-preview" as const; // Strongest model for RAG

const MIME_OVERRIDES: Readonly<Record<string, string>> = {
  ".ts": "text/plain", ".tsx": "text/plain", ".js": "text/plain", ".jsx": "text/plain",
  ".py": "text/plain", ".sh": "text/plain", ".nix": "text/plain", ".md": "text/markdown",
  ".json": "application/json", ".html": "text/html", ".css": "text/css",
  ".yaml": "text/yaml", ".yml": "text/yaml", ".hs": "text/plain",
  ".c": "text/plain", ".cpp": "text/plain", ".h": "text/plain",
  ".go": "text/plain", ".rs": "text/plain", ".txt": "text/plain",
  ".pdf": "application/pdf", ".csv": "text/csv",
};

// ==========================================
// Pure Functions
// ==========================================

const getMimeType = (path: string): string =>
  MIME_OVERRIDES[extname(path).toLowerCase()] ?? "text/plain";

const isSupported = (path: string): boolean =>
  SUPPORTED_EXTENSIONS.has(extname(path).toLowerCase()) && !basename(path).startsWith(".");

const getScope = (cwd: string): string => basename(cwd);

// Hash encoding in displayName: "filename__HASH.ext"
// This allows us to detect changes by comparing hashes
const HASH_SEPARATOR = "__";

const encodeDisplayName = (filename: string, hash: string): string => {
  const ext = extname(filename);
  const base = basename(filename, ext);
  // URL encode base name for non-ASCII safety, truncate hash to 8 chars
  return `${encodeURIComponent(base)}${HASH_SEPARATOR}${hash.slice(0, 8)}${ext}`;
};

const decodeDisplayName = (encoded: string): { filename: string; hash: string } | null => {
  const ext = extname(encoded);
  const withoutExt = basename(encoded, ext);
  const sepIndex = withoutExt.lastIndexOf(HASH_SEPARATOR);

  if (sepIndex === -1) return null; // Legacy format without hash

  const base = withoutExt.slice(0, sepIndex);
  const hash = withoutExt.slice(sepIndex + HASH_SEPARATOR.length);

  return {
    filename: decodeURIComponent(base) + ext,
    hash,
  };
};

// ==========================================
// Hashing
// ==========================================

const computeFileHash = async (path: string): Promise<string> => {
  const content = await Deno.readFile(path);
  const hashBuffer = await crypto.subtle.digest("SHA-256", content);
  return encodeHex(new Uint8Array(hashBuffer));
};

// ==========================================
// File System (IO Layer)
// ==========================================

interface LocalFile {
  readonly path: string;
  readonly filename: string;
  readonly hash: string;
  readonly displayName: string; // Encoded with hash
}

const expandPath = async (pathStr: string): Promise<readonly string[]> =>
  safeAsync(async () => {
    const stat = await Deno.stat(pathStr);
    return stat.isFile
      ? (isSupported(pathStr) ? [pathStr] : [])
      : stat.isDirectory
        ? await collectWalkPaths(pathStr)
        : [];
  }).then(r => (isSuccess(r) ? r.value : []));

const collectWalkPaths = async (dir: string): Promise<readonly string[]> => {
  const paths: string[] = [];
  for await (const entry of walk(dir, { includeDirs: false })) {
    if (isSupported(entry.path) && !entry.name.startsWith(".")) {
      paths.push(entry.path);
    }
  }
  return paths;
};

const resolveTargetsWithHash = async (pathStrs: readonly string[]): Promise<readonly LocalFile[]> => {
  const allPaths = await Promise.all(pathStrs.map(expandPath));
  const uniquePaths = [...new Set(allPaths.flat())];

  // Compute hashes in parallel
  const results = await Promise.all(
    uniquePaths.map(async (p): Promise<LocalFile> => {
      const filename = basename(p);
      const hash = await computeFileHash(p);
      return {
        path: p,
        filename,
        hash,
        displayName: encodeDisplayName(filename, hash),
      };
    })
  );

  return results;
};

// ==========================================
// Gemini API (IO Layer)
// ==========================================

type FileSearchStore = { readonly name: string; config?: { displayName?: string }; displayName?: string };
type RemoteDoc = { readonly name: string; readonly displayName: string; readonly hash: string | null };

const createClient = (apiKey: string): GoogleGenAI => new GoogleGenAI({ apiKey });

const findExistingStore = async (
  ai: GoogleGenAI,
  displayName: string
): Promise<Result<FileSearchStore | null>> =>
  safeAsync(async () => {
    const listResp = await ai.fileSearchStores.list();
    // @ts-ignore: async iterable
    for await (const store of listResp) {
      if (store.config?.displayName === displayName || store.displayName === displayName) {
        return store as FileSearchStore;
      }
    }
    return null;
  });

const createStore = async (
  ai: GoogleGenAI,
  displayName: string
): Promise<Result<FileSearchStore>> =>
  safeAsync(async () => {
    const newStore = await ai.fileSearchStores.create({ config: { displayName } });
    return newStore as FileSearchStore;
  });

const getOrCreateStore = async (
  ai: GoogleGenAI,
  displayName: string
): Promise<Result<FileSearchStore>> => {
  const existingRes = await findExistingStore(ai, displayName);
  if (!isSuccess(existingRes)) return existingRes;

  if (existingRes.value !== null) {
    console.error(`INFO: Found existing store: ${displayName} (${existingRes.value.name})`);
    return ok(existingRes.value);
  }

  console.error(`INFO: Creating new store: ${displayName}`);
  return createStore(ai, displayName);
};

// Get all documents in store with parsed hash
const getRemoteDocs = async (
  ai: GoogleGenAI,
  storeName: string
): Promise<Result<readonly RemoteDoc[]>> =>
  safeAsync(async () => {
    const docsResp = await ai.fileSearchStores.documents.list({ parent: storeName, config: { pageSize: API_PAGE_SIZE } });
    const docs: RemoteDoc[] = [];
    // @ts-ignore: async iterable
    for await (const d of docsResp) {
      const parsed = decodeDisplayName(d.displayName || "");
      docs.push({
        name: d.name,
        displayName: d.displayName || "",
        hash: parsed?.hash ?? null,
      });
    }
    return docs;
  });

// Delete a document
const deleteDocument = async (
  ai: GoogleGenAI,
  docName: string
): Promise<Result<void>> => {
  console.error(`INFO: Deleting ${docName}...`);
  return safeAsync(async () => {
    await ai.fileSearchStores.documents.delete({ name: docName });
  });
};

// Poll operation until done
const pollOperation = async (
  ai: GoogleGenAI,
  op: { done?: boolean; error?: unknown }
): Promise<Result<void>> =>
  op.done
    ? (op.error ? fail(new Error(`Upload failed: ${JSON.stringify(op.error)}`)) : ok(undefined))
    : new Promise(r => setTimeout(r, 2000))
        .then(() => ai.operations.get({ operation: op }))
        .then(nextOp => pollOperation(ai, nextOp));

// Check if filename contains non-ASCII characters
const hasNonAscii = (str: string): boolean => /[^\x00-\x7F]/.test(str);

// Generate a safe ASCII filename from original
const toSafeFilename = (original: string): string => {
  const ext = extname(original);
  const hash = Array.from(new TextEncoder().encode(original))
    .reduce((acc, b) => ((acc << 5) - acc + b) | 0, 0)
    .toString(16);
  return `upload_${Math.abs(parseInt(hash, 16) || Date.now()).toString(36)}${ext}`;
};

const uploadFileToStore = async (
  ai: GoogleGenAI,
  storeName: string,
  localFile: LocalFile
): Promise<Result<void>> => {
  console.error(`INFO: Uploading ${localFile.filename}...`);

  // If filename has non-ASCII, copy to temp file with safe name
  const needsTempCopy = hasNonAscii(localFile.filename);
  const tempPath = needsTempCopy
    ? `/tmp/${toSafeFilename(localFile.filename)}`
    : null;

  const uploadPath = tempPath ?? localFile.path;

  // Copy file to temp if needed
  if (tempPath) {
    try {
      await Deno.copyFile(localFile.path, tempPath);
    } catch (e) {
      return fail(e instanceof Error ? e : new Error(String(e)));
    }
  }

  const result = await safeAsync(() =>
    ai.fileSearchStores.uploadToFileSearchStore({
      file: uploadPath,
      fileSearchStoreName: storeName,
      config: {
        displayName: localFile.displayName, // Already encoded with hash
        mimeType: getMimeType(localFile.path),
      },
    })
  ).then(res => (isSuccess(res) ? pollOperation(ai, res.value) : res));

  // Clean up temp file
  if (tempPath) {
    Deno.remove(tempPath).catch(() => {});
  }

  return result;
};

// Retry with exponential backoff
const retry = <T>(
  fn: () => Promise<Result<T>>,
  retries: number = 3,
  delay: number = 2000
): Promise<Result<T>> =>
  fn().then(res =>
    isSuccess(res) || retries <= 0
      ? res
      : (console.error(`WARN: Retrying... (${res.error.message})`),
         new Promise<void>(r => setTimeout(r, delay)).then(() =>
           retry(fn, retries - 1, delay * 2)
         ))
  );

// ==========================================
// Diff Calculation (Pure)
// ==========================================

interface SyncDiff {
  readonly toAdd: readonly LocalFile[];
  readonly toUpdate: readonly { local: LocalFile; remote: RemoteDoc }[];
  readonly toDelete: readonly RemoteDoc[];
  readonly unchanged: number;
}

const computeDiff = (
  localFiles: readonly LocalFile[],
  remoteDocs: readonly RemoteDoc[]
): SyncDiff => {
  // Build maps for O(1) lookup
  // For local: key by encoded displayName (contains filename + hash)
  const localByDisplayName = new Map(localFiles.map(f => [f.displayName, f]));

  // For remote: key by displayName
  const remoteByDisplayName = new Map(remoteDocs.map(d => [d.displayName, d]));

  // Also build a map of remote docs by decoded filename for update detection
  // Handle both new format (with hash) and legacy format (without hash)
  const remoteByFilename = new Map<string, RemoteDoc>();
  for (const doc of remoteDocs) {
    const parsed = decodeDisplayName(doc.displayName);
    const filename = parsed?.filename ?? doc.displayName; // Legacy: use displayName directly
    remoteByFilename.set(filename, doc);
  }

  const toAdd: LocalFile[] = [];
  const toUpdate: { local: LocalFile; remote: RemoteDoc }[] = [];
  let unchanged = 0;

  // Check each local file
  for (const local of localFiles) {
    const existingExact = remoteByDisplayName.get(local.displayName);

    if (existingExact) {
      // Exact match (same filename + same hash) → unchanged
      unchanged++;
    } else {
      // Check if same filename exists with different hash
      const existingByFilename = remoteByFilename.get(local.filename);

      if (existingByFilename) {
        // Same filename, different hash → update (delete old, upload new)
        toUpdate.push({ local, remote: existingByFilename });
      } else {
        // New file
        toAdd.push(local);
      }
    }
  }

  // Find files to delete (remote exists but no local file with same filename)
  // Handle both new format (with hash) and legacy format (without hash)
  const localFilenames = new Set(localFiles.map(f => f.filename));
  const toDelete: RemoteDoc[] = [];

  for (const doc of remoteDocs) {
    const parsed = decodeDisplayName(doc.displayName);
    const filename = parsed?.filename ?? doc.displayName; // Legacy: use displayName directly
    if (!localFilenames.has(filename)) {
      toDelete.push(doc);
    }
  }

  return { toAdd, toUpdate, toDelete, unchanged };
};

// ==========================================
// Actions (Compose IO with Pure Logic)
// ==========================================

const doUpsert = async (
  ai: GoogleGenAI,
  scope: string,
  paths: readonly string[]
): Promise<Result<string>> => {
  // 1. Resolve local files with hashes
  const localFiles = await resolveTargetsWithHash(paths);

  if (localFiles.length === 0) {
    return fail(new Error("No supported files found."));
  }

  console.error(`INFO: Found ${localFiles.length} local files.`);

  // 2. Get or create store
  const storeRes = await getOrCreateStore(ai, scope);
  if (!isSuccess(storeRes)) return storeRes;
  const store = storeRes.value;

  // 3. Get remote documents
  const remoteRes = await getRemoteDocs(ai, store.name);
  if (!isSuccess(remoteRes)) return remoteRes;
  const remoteDocs = remoteRes.value;

  console.error(`INFO: Found ${remoteDocs.length} remote documents.`);

  // 4. Compute diff
  const diff = computeDiff(localFiles, remoteDocs);

  console.error(`INFO: Diff - Add: ${diff.toAdd.length}, Update: ${diff.toUpdate.length}, Delete: ${diff.toDelete.length}, Unchanged: ${diff.unchanged}`);

  // 5. Execute deletes first (to free up space and avoid conflicts)
  const deleteResults = await Promise.all(
    [...diff.toDelete, ...diff.toUpdate.map(u => u.remote)].map(doc =>
      retry(() => deleteDocument(ai, doc.name))
    )
  );

  const deleteFailures = deleteResults.filter(r => !r.success);
  if (deleteFailures.length > 0) {
    console.error(`WARN: ${deleteFailures.length} deletes failed.`);
  }

  // 6. Upload new and updated files
  const filesToUpload = [...diff.toAdd, ...diff.toUpdate.map(u => u.local)];

  if (filesToUpload.length > 0) {
    const batches = chunk(filesToUpload, UPLOAD_CONCURRENCY);
    const uploadResults = await batches.reduce(
      async (accP, batch) => {
        const acc = await accP;
        const batchResults = await Promise.all(
          batch.map(f => retry(() => uploadFileToStore(ai, store.name, f)))
        );
        return [...acc, ...batchResults];
      },
      Promise.resolve([] as readonly Result<void>[])
    );

    const uploadFailures = uploadResults.filter(r => !r.success);
    if (uploadFailures.length > 0) {
      return fail(new Error(`${uploadFailures.length} uploads failed.`));
    }
  }

  // 7. Report
  return ok(
    `Synced to '${scope}': Added ${diff.toAdd.length}, Updated ${diff.toUpdate.length}, Deleted ${diff.toDelete.length}, Unchanged ${diff.unchanged}`
  );
};

const doAsk = async (ai: GoogleGenAI, scope: string, query: string): Promise<Result<string>> => {
  const storeRes = await getOrCreateStore(ai, scope);
  if (!isSuccess(storeRes)) return storeRes;
  const store = storeRes.value;

  console.error(`INFO: Querying store ${store.config?.displayName ?? scope} (${store.name})...`);

  return safeAsync(() =>
    ai.models.generateContent({
      model: RAG_MODEL,
      contents: query,
      config: {
        tools: [{ fileSearch: { fileSearchStoreNames: [store.name] } }],
      },
    })
  ).then(res => mapResult(res, r => r.text ?? "No response text."));
};

const doList = async (ai: GoogleGenAI, scope: string): Promise<Result<string>> => {
  const storeRes = await getOrCreateStore(ai, scope);
  if (!isSuccess(storeRes)) return storeRes;
  const store = storeRes.value;

  const docsRes = await getRemoteDocs(ai, store.name);
  if (!isSuccess(docsRes)) return docsRes;

  const docs = docsRes.value;

  if (docs.length === 0) return ok("No documents in store.");

  const lines = docs.map(d => {
    const parsed = decodeDisplayName(d.displayName);
    const filename = parsed?.filename ?? d.displayName;
    const hash = parsed?.hash ?? "?";
    return `${filename} [${hash}]`;
  });

  return ok(lines.join("\n"));
};

const doPurge = async (ai: GoogleGenAI, scope: string): Promise<Result<string>> => {
  const storeRes = await getOrCreateStore(ai, scope);
  if (!isSuccess(storeRes)) return storeRes;
  const store = storeRes.value;

  const docsRes = await getRemoteDocs(ai, store.name);
  if (!isSuccess(docsRes)) return docsRes;
  const docs = docsRes.value;

  if (docs.length === 0) return ok("No documents to delete.");

  console.error(`INFO: Deleting ${docs.length} documents...`);

  // Delete all documents in parallel batches
  const batches = chunk(docs, UPLOAD_CONCURRENCY);
  let deleted = 0;
  let failed = 0;

  for (const batch of batches) {
    const results = await Promise.all(
      batch.map(doc => retry(() => deleteDocument(ai, doc.name), 2, 1000))
    );
    deleted += results.filter(r => r.success).length;
    failed += results.filter(r => !r.success).length;
  }

  return ok(`Purged store '${scope}': Deleted ${deleted}, Failed ${failed}`);
};

// ==========================================
// Main (IO Boundary)
// ==========================================

const main = async (): Promise<void> => {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    console.error("Error: GEMINI_API_KEY is not set.");
    return Deno.exit(1);
  }

  const ai = createClient(apiKey);
  const scope = getScope(Deno.cwd());
  const args = parseArgs(Deno.args);
  const cmd = args._[0];

  const res: Result<string> =
    cmd === "upsert" ? await doUpsert(ai, scope, args._.slice(1).map(String)) :
    cmd === "ask"    ? await doAsk(ai, scope, String(args._[1] ?? "")) :
    cmd === "list"   ? await doList(ai, scope) :
    cmd === "purge"  ? await doPurge(ai, scope) :
    fail(new Error("Usage: gemini-rag [upsert <paths> | ask <query> | list | purge]"));

  return isSuccess(res)
    ? (console.log(res.value), Deno.exit(0))
    : (console.error(`Error: ${res.error.message}`), Deno.exit(1));
};

// Entry point
import.meta.main && main();
