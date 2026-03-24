#!/usr/bin/env python3
"""
clean-img-assets.py
Removes all dragontail image assets EXCEPT:
  - Champion icons     (img/champion/*.png — top-level portraits only)
  - Item icons          (img/item/)
  - Spell icons         (img/spell/)
  - Passive/Buff icons  (img/passive/)

Usage:
    python scripts/clean-img-assets.py          # dry-run (default)
    python scripts/clean-img-assets.py --apply  # actually delete
"""

import argparse
import shutil
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
DRAGONTAIL = ROOT / "data" / "dragontail"

# Top-level img subdirectories to KEEP (everything else is deleted)
KEEP_DIRS = {"item", "spell", "passive"}

# Inside img/champion/ we keep only the top-level .png files (square icons)
# and delete the subdirectories (centered, loading, splash, tiles)
CHAMPION_DIR = "champion"


def find_img_roots():
    """Find all img/ directories under dragontail (one per patch version)."""
    return sorted(DRAGONTAIL.rglob("img")) if DRAGONTAIL.exists() else []


def collect_deletions(img_root: Path):
    """Return list of paths to delete under a single img/ root."""
    targets = []

    for child in sorted(img_root.iterdir()):
        if not child.is_dir():
            # Top-level files in img/ — delete
            targets.append(child)
            continue

        name = child.name

        if name in KEEP_DIRS:
            # Keep entirely
            continue

        if name == CHAMPION_DIR:
            # Keep champion/*.png but delete subdirectories
            for sub in sorted(child.iterdir()):
                if sub.is_dir():
                    targets.append(sub)
            continue

        # Everything else: delete the whole directory
        targets.append(child)

    return targets


def dir_size(p: Path) -> int:
    if p.is_file():
        return p.stat().st_size
    return sum(f.stat().st_size for f in p.rglob("*") if f.is_file())


def fmt_size(n: int) -> str:
    if n >= 1 << 30:
        return f"{n / (1 << 30):.1f} GB"
    if n >= 1 << 20:
        return f"{n / (1 << 20):.1f} MB"
    if n >= 1 << 10:
        return f"{n / (1 << 10):.1f} KB"
    return f"{n} B"


def main():
    parser = argparse.ArgumentParser(description="Clean non-essential dragontail image assets.")
    parser.add_argument("--apply", action="store_true", help="Actually delete (default is dry-run)")
    args = parser.parse_args()

    img_roots = find_img_roots()
    if not img_roots:
        print(f"No img/ directories found under {DRAGONTAIL}")
        return

    total_freed = 0
    all_targets = []

    for img_root in img_roots:
        if not img_root.is_dir():
            continue
        targets = collect_deletions(img_root)
        for t in targets:
            size = dir_size(t)
            total_freed += size
            all_targets.append((t, size))

    if not all_targets:
        print("Nothing to delete — all clean!")
        return

    print(f"{'DRY RUN' if not args.apply else 'DELETING'}:")
    print(f"{'─' * 60}")
    for t, size in all_targets:
        rel = t.relative_to(ROOT)
        tag = "DIR " if t.is_dir() else "FILE"
        print(f"  {tag}  {rel}  ({fmt_size(size)})")

    print(f"{'─' * 60}")
    print(f"  Total: {len(all_targets)} items, {fmt_size(total_freed)} freed")

    if not args.apply:
        print(f"\nRe-run with --apply to delete.")
        return

    for t, _ in all_targets:
        if t.is_dir():
            shutil.rmtree(t)
        else:
            t.unlink()

    print(f"\nDone — {fmt_size(total_freed)} freed.")


if __name__ == "__main__":
    main()
