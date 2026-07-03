from __future__ import annotations

import hashlib
import json
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "src" / "pandalife_gan" / "assets" / "manifest.json"
ASSET_ROOT = ROOT / "src" / "pandalife_gan" / "assets"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url: str, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_suffix(target.suffix + ".part")
    with urllib.request.urlopen(url, timeout=60) as response, tmp.open("wb") as f:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            f.write(chunk)
    tmp.replace(target)


def main() -> int:
    if not MANIFEST.exists():
        print(f"ERROR: Missing manifest: {MANIFEST}")
        return 1
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    files = manifest.get("files", [])
    if not files:
        print("Asset manifest contains no mandatory external files. Nothing to download.")
        return 0

    for item in files:
        rel = item["path"]
        url = item["url"]
        expected_sha256 = item.get("sha256", "").lower().strip()
        target = ASSET_ROOT / rel
        if target.exists() and expected_sha256:
            actual = sha256_file(target)
            if actual == expected_sha256:
                print(f"OK: {rel}")
                continue
            print(f"Hash mismatch for existing file {rel}; re-downloading.")
        elif target.exists():
            print(f"Exists: {rel}")
            continue
        print(f"Downloading {rel}...")
        download(url, target)
        if expected_sha256:
            actual = sha256_file(target)
            if actual != expected_sha256:
                print(f"ERROR: Hash mismatch for {rel}")
                print(f" expected {expected_sha256}")
                print(f" actual   {actual}")
                return 1
    print("Assets ready.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
