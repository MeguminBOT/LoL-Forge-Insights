"""
Combines per-champion override files from data/overrides/*.json
into a single data/overrides.json file.

Usage: python scripts/build-overrides.py
"""

import json
import os
import sys


def main():
    overrides_dir = os.path.join("data", "overrides")
    output_path = os.path.join("data", "overrides.json")

    combined = {}
    if not os.path.isdir(overrides_dir):
        print(f"No overrides directory found at {overrides_dir}")
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(combined, f)
        return

    count = 0
    for filename in sorted(os.listdir(overrides_dir)):
        if not filename.endswith(".json"):
            continue
        champ_key = filename[:-5]  # strip .json
        filepath = os.path.join(overrides_dir, filename)
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
        combined[champ_key] = data
        item_count = len(data)
        print(f"  {champ_key}: {item_count} override(s)")
        count += item_count

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(combined, f, indent=2)

    print(
        f"Combined {count} override(s) from {len(combined)} champion(s) -> {output_path}"
    )


if __name__ == "__main__":
    main()
