#!/usr/bin/env python3
# ==============================================================================
# MarkItDown Filter - Robust Implementation (Powered by Joblib/Loky)
# Unix Filter: stdin (tar) -> stdout (tar)
# ==============================================================================

import sys
import os
import tarfile
import tempfile
import io
import shutil
import logging
import signal
import gc
from pathlib import Path
from dataclasses import dataclass
from typing import IO, Optional

# Joblib / Loky for robust process management
from joblib import Parallel, delayed, parallel_backend

# Suppress library noise
logging.getLogger("pdfminer").setLevel(logging.ERROR)
import warnings
warnings.filterwarnings("ignore", category=UserWarning)

# ==============================================================================
# Domain Types (Immutable Data)
# ==============================================================================

@dataclass(frozen=True)
class FileTask:
    path: Path
    original_name: str
    mtime: float

@dataclass(frozen=True)
class ConvertSuccess:
    original_name: str
    content_path: Path
    mtime: float

@dataclass(frozen=True)
class ConvertSkipped:
    original_name: str
    reason: str

@dataclass(frozen=True)
class ConvertFailed:
    original_name: str
    error: str

ConvertResult = ConvertSuccess | ConvertSkipped | ConvertFailed

# ==============================================================================
# Pure Helper Functions & Worker Logic
# ==============================================================================

JUNK_PATTERNS = frozenset({".DS_Store"})
JUNK_PREFIXES = ("._",)
SKIP_EXTENSIONS = frozenset({".mov", ".mp4", ".mp3", ".wav", ".m4a"})

def is_valid_member(name: str) -> bool:
    base = os.path.basename(name)
    _, ext = os.path.splitext(base)
    return (
        not base.startswith(JUNK_PREFIXES) and
        base not in JUNK_PATTERNS and
        ext.lower() not in SKIP_EXTENSIONS and
        not name.startswith("..") and
        not os.path.isabs(name)
    )

def md_output_name(original: str) -> str:
    base, _ = os.path.splitext(original)
    return base + ".md"

# Worker-side initialization is handled automatically by Loky if needed,
# but we'll use a functional approach where we instantiate clients purely.

def convert_task_isolated(task: FileTask) -> ConvertResult:
    """
    Executed in a separate process.
    Self-contained, minimal state.
    """
    try:
        # Re-import inside worker to ensure clean state
        import os
        from markitdown import MarkItDown
        from openai import OpenAI
        import netrc

        # 1. Resolve Auth (Stateless)
        def get_auth(env_key: str, host: str) -> Optional[str]:
            if (val := os.environ.get(env_key)): return val
            try:
                auth = netrc.netrc().authenticators(host)
                return auth[2] if auth else None
            except Exception:
                return None

        llm_client = None
        llm_model = None

        openrouter_key = get_auth("OPENROUTER_API_KEY", "openrouter.ai")
        if openrouter_key:
             try:
                llm_client = OpenAI(base_url="https://openrouter.ai/api/v1", api_key=openrouter_key)
                llm_model = os.environ.get("OPENROUTER_MODEL", "google/gemini-2.0-flash-001")
             except: pass

        if not llm_client:
            openai_key = get_auth("OPENAI_API_KEY", "api.openai.com")
            if openai_key:
                try:
                    llm_client = OpenAI(api_key=openai_key)
                    llm_model = "gpt-4o"
                except: pass

        # 2. Setup Unix Timeout (Pure Signal Approach)
        # import signal # Already imported at the top level, no need to re-import here.

        def timeout_handler(signum, frame):
            raise TimeoutError("Conversion timed out")

        # Set alarm for 180 seconds (3 minutes per file)
        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(180)

        try:
            # 3. Perform Conversion
            md = MarkItDown(llm_client=llm_client, llm_model=llm_model)
            result = md.convert(str(task.path))

            # 4. Write output to disk
            if result.text_content and result.text_content.strip():
                output_path = task.path.with_suffix(".md.tmp")
                output_path.write_bytes(result.text_content.encode('utf-8'))
                return ConvertSuccess(task.original_name, output_path, task.mtime)

            return ConvertSkipped(task.original_name, "No convertible text content")

        finally:
            # Disable alarm immediately
            signal.alarm(0)

    except TimeoutError:
        return ConvertFailed(task.original_name, "Timeout (180s)")

    except Exception as e:
        # Capture trace for debugging if needed, but return clean error
        msg = str(e).split('\n')[0][:200]
        return ConvertFailed(task.original_name, f"{type(e).__name__}: {msg}")

# ==============================================================================
# Pipeline Phases
# ==============================================================================

def phase_extract(input_stream: IO[bytes], work_dir: Path) -> list[FileTask]:
    sys.stderr.write("[Phase 1] Extracting archive...\n")
    tasks = []
    with tarfile.open(fileobj=input_stream, mode='r|*') as tar:
        for member in tar:
            if not member.isfile() or not is_valid_member(member.name): continue
            try:
                dest_path = work_dir / os.path.normpath(member.name)
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                source = tar.extractfile(member)
                if source:
                    dest_path.write_bytes(source.read())
                    tasks.append(FileTask(dest_path, member.name, member.mtime))
            except Exception as e:
                sys.stderr.write(f"[Extract Error] {member.name}: {e}\n")
    sys.stderr.write(f"[Phase 1] Extracted {len(tasks)} files.\n")
    return tasks

def phase_transform(tasks: list[FileTask]) -> list[ConvertResult]:
    # Determine optimal worker count (keep some breathing room for system)
    cpu_count = os.cpu_count() or 1
    # Limit parallelism to avoid 37GB RAM usage if files are huge
    # 8-12 workers is usually the sweet spot for IO/Network bound tasks like this
    n_jobs = min(cpu_count, 12)

    sys.stderr.write(f"[Phase 2] Converting {len(tasks)} files with {n_jobs} workers uses Joblib...\n")

    results: list[ConvertResult] = []
    total = len(tasks)

    # Use 'loky' backend for robust process management (handles crashes/hangs)
    # batch_size='auto' helps reduce overhead.
    try:
        with parallel_backend('loky', n_jobs=n_jobs):
            # return_as='generator' allows us to stream results and show progress!
            # timeout is available in recent joblib, but standardized via iterator here.

            generator = Parallel(return_as='generator')(
                delayed(convert_task_isolated)(task) for task in tasks
            )

            completed = 0
            for result in generator:
                results.append(result)
                completed += 1

                # Show progress with last processed file name (truncated)
                status = "OK" if isinstance(result, ConvertSuccess) else ("SKIP" if isinstance(result, ConvertSkipped) else "ERR")
                fname = result.original_name
                if len(fname) > 30: fname = fname[:13] + "..." + fname[-14:]

                sys.stderr.write(f"\r[Phase 2] {completed}/{total} | {status} | {fname}                    ")
                sys.stderr.flush()

                # Explicit GC
                if completed % 100 == 0:
                    gc.collect()

    except Exception as e:
        sys.stderr.write(f"\n[Parallel Error] {e}\n")
        # Joblib usually raises only after everything is stopped,
        # but we might have partial results in 'results' list if we consumed generator
        pass

    sys.stderr.write(f"\n[Phase 2] Completed {len(results)} conversions.\n")
    results.sort(key=lambda r: r.original_name)
    return results

def phase_emit(results: list[ConvertResult], output_stream: IO[bytes], work_dir: Path):
    sys.stderr.write("[Phase 3] Building output archive...\n")
    buffer_path = work_dir / "output.tar"

    with tarfile.open(buffer_path, mode='w') as tar:
        for res in results:
            if isinstance(res, ConvertSuccess):
                try:
                    info = tar.gettarinfo(name=str(res.content_path), arcname=md_output_name(res.original_name))
                    info.mtime = res.mtime
                    with open(res.content_path, 'rb') as f:
                        tar.addfile(info, f)
                    sys.stderr.write(f"x {md_output_name(res.original_name)}\n")
                except Exception as e:
                    sys.stderr.write(f"[Pack Error] {res.original_name}: {e}\n")
            elif isinstance(res, ConvertSkipped):
                sys.stderr.write(f"[Skip] {res.original_name}: {res.reason}\n")
            elif isinstance(res, ConvertFailed):
                sys.stderr.write(f"[Failed] {res.original_name}: {res.error}\n")

    size = buffer_path.stat().st_size
    sys.stderr.write(f"[Phase 3] Streaming {size} bytes to stdout...\n")

    with open(buffer_path, 'rb') as f:
        shutil.copyfileobj(f, output_stream)
    output_stream.flush()
    sys.stderr.write("[Done]\n")

def run_pipeline(input_stream: IO[bytes], output_stream: IO[bytes]):
    with tempfile.TemporaryDirectory() as temp_dir:
        work_dir = Path(temp_dir)
        tasks = phase_extract(input_stream, work_dir)
        results = phase_transform(tasks)
        phase_emit(results, output_stream, work_dir)

def main():
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    try:
        run_pipeline(sys.stdin.buffer, sys.stdout.buffer)
        return 0
    except BrokenPipeError:
        return 0
    except KeyboardInterrupt:
        sys.stderr.write("\n[Interrupted]\n")
        return 130
    except Exception as e:
        import traceback
        sys.stderr.write(f"[Critical Error] {e}\n")
        traceback.print_exc(file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
