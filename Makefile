# DualSense Remap — build entry points.
# Run `make` (or `make help`) to list the available targets.

APP_NAME     := DualSense Remap
DIST_APP     := dist/$(APP_NAME).app
SPOON_SOURCE := Hammerspoon/DualSenseRemap.spoon
SPOON_DEST   := $(HOME)/.hammerspoon/Spoons/DualSenseRemap.spoon

.DEFAULT_GOAL := help
.PHONY: help build release app run install spoon clean

help: ## Show this help (default target)
	@echo "DualSense Remap — available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Typical flow: make app && make install"

build: ## Debug build (swift build)
	swift build

release: ## Optimized build (swift build -c release)
	swift build -c release

app: ## Build and assemble the ad-hoc signed dist/DualSense Remap.app
	./Scripts/bundle.sh

run: ## Run from sources for development (swift run — TCC grants land on the terminal, prefer 'make app' for real use)
	swift run

install: app ## Assemble the app then copy it into /Applications
	ditto "$(DIST_APP)" "/Applications/$(APP_NAME).app"
	@echo "✔ Installé : /Applications/$(APP_NAME).app"

spoon: ## Install the Hammerspoon Spoon into ~/.hammerspoon/Spoons/
	mkdir -p "$(HOME)/.hammerspoon/Spoons"
	ditto "$(SPOON_SOURCE)" "$(SPOON_DEST)"
	@echo "✔ Spoon installé : $(SPOON_DEST)"
	@echo "  Ajoutez à ~/.hammerspoon/init.lua :"
	@echo "    require(\"hs.ipc\")"
	@echo "    hs.loadSpoon(\"DualSenseRemap\")"
	@echo "    spoon.DualSenseRemap:start()"

clean: ## Remove build products (.build/ and dist/)
	swift package clean
	rm -rf dist
