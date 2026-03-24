# Champion Override Files

Place per-champion JSON files here to manually override item synergy judgements.

**Filename**: Use the champion's internal key (e.g., `Aatrox.json`, `MissFortune.json`, `KSante.json`).

**Format**:
```json
{
  "<itemId>": {
    "tier": "Core|Good|Situational|Weak|Trap",
    "reason": "Explanation for the override"
  }
}
```

**Example** (`Yasuo.json`):
```json
{
  "3085": {
    "tier": "Good",
    "reason": "Yasuo's kit synergises with Runaan's despite being melee (passive interaction)"
  }
}
```

**Tier values**: `Core`, `Good`, `Situational`, `Weak`, `Trap`

After editing, run `python scripts/build-overrides.py` to combine into `data/overrides.json`,
then regenerate `meraki-data.js` if using the browser build.
