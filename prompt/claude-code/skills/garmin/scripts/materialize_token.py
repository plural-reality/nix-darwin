"""Materialize the canonical token (GARMINTOKENS env) into GarminDB's token
store file, so GarminDB authenticates token-only (no password in its config).

The canonical secret stays in SOPS; this writes only a derived 0600 cache at
~/.GarminDb/garmin_tokens.json that GarminDB expects.
"""
import os
import stat
from pathlib import Path

from garminconnect import Garmin

DEST = Path(os.environ.get("GARMINDB_TOKENS", "~/.GarminDb/garmin_tokens.json")).expanduser()

g = Garmin()
g.client.loads(os.environ["GARMINTOKENS"])  # canonical token string -> session
DEST.parent.mkdir(parents=True, exist_ok=True)
g.client.dump(str(DEST))
os.chmod(DEST, stat.S_IRUSR | stat.S_IWUSR)  # 0600
print(f"materialized token -> {DEST}")
