# Forge Insight — Build System

HAXE     := haxe
NODE     := node
BUILD    := build
CONFIG   := config
SCRIPTS  := scripts

.PHONY: all browser offline data serve clean

## Build both targets
all: browser offline cpp

## Compile for browser / GitHub Pages
browser:
	@echo "Building browser target…"
	@mkdir -p $(BUILD)/browser
	$(HAXE) $(CONFIG)/browser.hxml
	@echo "Copying index file into browser output folder…"
	@python - <<'PY'
from pathlib import Path
src = Path('assets/index.html')
path = src.read_text(encoding='utf-8')
path = path.replace('../build/browser/forge.js','forge.js')
Path('build/browser/index.html').write_text(path, encoding='utf-8')
PY
	@echo "✓ build/browser/forge.js + build/browser/index.html ready"

## Compile offline variant (same JS engine, served locally)
offline:
	@echo "Building offline target…"
	@mkdir -p $(BUILD)/offline
	$(HAXE) $(CONFIG)/offline.hxml
	@echo "Copying index file into offline output folder…"
	@python - <<'PY'
from pathlib import Path
src = Path('assets/index.html')
path = src.read_text(encoding='utf-8')
path = path.replace('../build/browser/forge.js','../build/offline/forge-offline.js')
Path('build/offline/index.html').write_text(path, encoding='utf-8')
PY
	@echo "✓ build/offline/forge-offline.js + build/offline/index.html ready"

## Compile C++ native binary
cpp:
	@echo "Building C++ target…"
	@mkdir -p $(BUILD)/cpp
	$(HAXE) $(CONFIG)/cpp.hxml
	@echo "✓ C++ native output ready in $(BUILD)/cpp"

## Download all Data Dragon assets into data/
data:
	@echo "Fetching Data Dragon assets…"
	$(NODE) $(SCRIPTS)/fetch-data.js

## Fetch a specific patch version: make data VERSION=14.9.1
data-version:
	$(NODE) $(SCRIPTS)/fetch-data.js $(VERSION)

## Start local server (offline mode)
serve:
	$(NODE) $(SCRIPTS)/serve-local.js

## Generate static champion JSON files (profile + synergy data per champion)
generate: cpp-generate
	@echo "Running champion data generator…"
	./$(BUILD)/generate/GenerateChampionData
	@echo "✓ Static champion JSON files ready in $(BUILD)/champion-data/"

## Compile the generator tool
cpp-generate:
	@echo "Building generator tool…"
	@mkdir -p $(BUILD)/generate
	$(HAXE) $(CONFIG)/generate.hxml

## Remove compiled output
clean:
	rm -rf $(BUILD) forge.js forge-offline.js
