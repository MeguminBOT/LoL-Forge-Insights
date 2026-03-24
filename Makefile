# Forge Insight — Build System

HAXE     := haxe
NODE     := node
BUILD    := build
CONFIG   := config
SCRIPTS  := scripts

.PHONY: all browser desktop data serve clean generate

## Build all targets
all: browser desktop

## Compile for browser / GitHub Pages
browser:
	@echo "Building browser target…"
	@mkdir -p $(BUILD)/browser
	$(HAXE) $(CONFIG)/browser.hxml
	@echo "Copying index + assets into browser output…"
	@python - <<'PY'
from pathlib import Path
src = Path('assets/index.html')
html = src.read_text(encoding='utf-8')
html = html.replace('../build/browser/','')
Path('build/browser/index.html').write_text(html, encoding='utf-8')
PY
	@cp -r assets/img $(BUILD)/browser/img 2>/dev/null || true
	@cp -r assets/fonts $(BUILD)/browser/fonts 2>/dev/null || true
	@cp data/meraki-champions.json $(BUILD)/browser/data/ 2>/dev/null || true
	@cp data/meraki-items.json $(BUILD)/browser/data/ 2>/dev/null || true
	@cp data/version.txt $(BUILD)/browser/data/ 2>/dev/null || true
	@echo "✓ build/browser/ ready"

## Build desktop (OpenFL + HaxeUI)
desktop:
	@echo "Building desktop target…"
	lime build project.xml windows
	@mkdir -p $(BUILD)/desktop/windows/bin/data
	@mkdir -p $(BUILD)/desktop/windows/bin/img
	@cp -r assets/img/* $(BUILD)/desktop/windows/bin/img/ 2>/dev/null || true
	@cp -r assets/fonts $(BUILD)/desktop/windows/bin/fonts 2>/dev/null || true
	@cp data/meraki-champions.json $(BUILD)/desktop/windows/bin/data/ 2>/dev/null || true
	@cp data/meraki-items.json $(BUILD)/desktop/windows/bin/data/ 2>/dev/null || true
	@cp data/version.txt $(BUILD)/desktop/windows/bin/data/ 2>/dev/null || true
	@echo "✓ Desktop build ready"

## Download Meraki data + images into data/ and assets/img/
data:
	@echo "Fetching game data…"
	$(NODE) $(SCRIPTS)/fetch-data.js

## Start local dev server
serve:
	$(NODE) $(SCRIPTS)/serve-local.js

## Generate static champion JSON files
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
	rm -rf $(BUILD)
