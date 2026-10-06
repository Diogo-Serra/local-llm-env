SHELL := /bin/bash
 
VENV := $(CURDIR)/.venv
BIN  := $(VENV)/bin
 
# llama and opencode install to their own default locations (not .venv).
# Make sure those locations are on PATH for every recipe.
export PATH := $(HOME)/.opencode/bin:$(HOME)/.llama-app:$(HOME)/.local/bin:$(PATH)

# Models cached by llama - "make model"
MODELS ?=	LiquidAI/LFM2.5-2.6B-GGUF:Q8_0

# Model opencode starts with (provider id "llama" + model id from opencode.json)
MODEL ?= 	LiquidAI/LFM2.5-2.6B-GGUF:Q8_0
 
HOST     ?= 127.0.0.1
PORT     ?= 8080
CONTEXT  ?= 32768
PARALLEL ?= 1
 
# -------------------------------------------------------------------
# Full installation
# -------------------------------------------------------------------
 # Install only llama to use as provider for other harness
 install_llama: python llama model
	@echo ""
	@echo "======================================"
	@echo " Local LLM environment ready"
	@echo "======================================"
	@echo ""
	@echo "Python:   $(BIN)/python"
	@echo "llama:    $$(command -v llama)"
	@echo "models:   $(MODELS)"
	@echo ""
	@echo "Start llama.cpp with:"
	@echo "  make serve"
	@echo ""
 
install: python llama opencode model
	@echo ""
	@echo "======================================"
	@echo " Local LLM environment ready"
	@echo "======================================"
	@echo ""
	@echo "Python:   $(BIN)/python"
	@echo "llama:    $$(command -v llama)"
	@echo "opencode: $$(command -v opencode)"
	@echo "models:   $(MODELS)"
	@echo ""
	@echo "Start llama.cpp with:"
	@echo "  make serve"
	@echo ""
	@echo "Then, in another terminal:"
	@echo "  make opencode-local"
	@echo ""
 
# -------------------------------------------------------------------
# Python / uv (installed inside .venv)
# -------------------------------------------------------------------
 
python:
	@echo "==> Setting up Python environment in .venv..."
	@mkdir -p "$(BIN)"
	@if [ ! -x "$(BIN)/uv" ]; then \
		echo "  Installing uv..."; \
		curl -LsSf https://astral.sh/uv/install.sh | \
			env UV_INSTALL_DIR="$(BIN)" UV_NO_MODIFY_PATH=1 sh; \
	else \
		echo "==> uv already installed."; \
	fi
	@if [ ! -f .venv/pyvenv.cfg ]; then \
		echo "==> Creating virtual environment..."; \
		$(BIN)/uv venv --allow-existing; \
	fi
	@if [ -f pyproject.toml ]; then \
		echo "==> Syncing Python environment..."; \
		$(BIN)/uv sync; \
	else \
		echo "==> No pyproject.toml found, skipping uv sync."; \
	fi
 
# -------------------------------------------------------------------
# llama.cpp (default install location)
# -------------------------------------------------------------------
 
llama:
	@echo "==> Installing llama.cpp..."
	@if command -v llama >/dev/null 2>&1; then \
		echo "==> llama already installed: $$(command -v llama)"; \
	else \
		curl -LsSf https://llama.app/install.sh | sh; \
	fi
	@echo "==> Checking installation:"
	@llama --version
 
# -------------------------------------------------------------------
# opencode (default install location, ~/.opencode/bin)
# -------------------------------------------------------------------
 
opencode:
	@echo "==> Installing opencode..."
	@if command -v opencode >/dev/null 2>&1; then \
		echo "==> opencode already installed: $$(command -v opencode)"; \
	else \
		curl -fsSL https://opencode.ai/install | bash; \
	fi
	@echo "==> Verifying installation:"
	@opencode --version
 
# -------------------------------------------------------------------
# Download/cache the models
# -------------------------------------------------------------------
 
model: llama
	@echo "==> Downloading/checking models:"
	@for m in $(MODELS); do \
		echo "    $$m"; \
		if llama cli -hf "$$m" -st -p "Say OK" >/dev/null 2>&1; then \
			echo "    -> ready"; \
		else \
			echo "    -> FAILED: $$m"; \
			exit 1; \
		fi; \
	done
	@echo "==> Models are ready."
 
# -------------------------------------------------------------------
# Start llama.cpp (router mode: serves every cached model on demand)
# -------------------------------------------------------------------
 
serve: llama
	@echo "==> Starting llama.cpp (router mode)"
	@echo "    Address:  http://$(HOST):$(PORT)"
	@echo "    Context:  $(CONTEXT)"
	@echo "    Parallel: $(PARALLEL)"
	@echo ""
	@llama serve \
		--jinja \
		--n-gpu-layers auto \
		--host "$(HOST)" \
		--port "$(PORT)" \
		-c "$(CONTEXT)" \
		-np "$(PARALLEL)"
 
stop:
	@echo "==> Stopping llama.cpp server..."
	@pkill -f "[l]lama.*serve" && echo "  Stopped." || echo "  No server was running."
 
# -------------------------------------------------------------------
# Start opencode configured for llama.cpp
# (providers and models are defined in ./opencode.json)
# -------------------------------------------------------------------
 
opencode-local: opencode
	@if [ ! -f "$(CURDIR)/opencode.json" ]; then \
		echo "ERROR: $(CURDIR)/opencode.json not found."; \
		exit 1; \
	fi
	@echo "==> Checking llama-server at http://$(HOST):$(PORT)..."
	@curl -sf "http://$(HOST):$(PORT)/v1/models" >/dev/null || \
		{ echo "ERROR: llama-server is not responding. Run 'make serve' first."; exit 1; }
	@echo "==> Starting opencode with local llama.cpp ($(MODEL))..."
	OPENCODE_CONFIG="$(CURDIR)/opencode.json" opencode
 
# -------------------------------------------------------------------
# Check everything
# -------------------------------------------------------------------
 
status:
	@echo "==> Binaries:"
	@if [ -x "$(BIN)/uv" ]; then \
		echo "  uv (in .venv): installed"; \
	else \
		echo "  uv (in .venv): NOT FOUND"; \
	fi
	@for bin in llama llama-server opencode; do \
		if command -v $$bin >/dev/null 2>&1; then \
			echo "  $$bin: $$(command -v $$bin)"; \
		else \
			echo "  $$bin: NOT FOUND"; \
		fi; \
	done
	@echo ""
	@echo "==> llama.cpp server:"
	@if curl -sf "http://$(HOST):$(PORT)/health" >/dev/null; then \
		echo "  Server: RUNNING (http://$(HOST):$(PORT))"; \
	else \
		echo "  Server: NOT RUNNING"; \
	fi
	@echo ""
	@echo "==> Models:"
	@if curl -sf "http://$(HOST):$(PORT)/v1/models" | grep -q '"id"'; then \
		echo "  Models: available"; \
	else \
		echo "  Models: not available (server not running)"; \
	fi
	@echo ""
	@echo "==> GPU:"
	@if command -v llama-server >/dev/null 2>&1; then \
		out=$$(llama-server --list-devices 2>&1); \
		echo "$$out" | sed 's/^/  /'; \
		if echo "$$out" | grep -qiE 'cuda|vulkan|rocm|hip|metal|sycl'; then \
			echo "  GPU backend: FOUND"; \
		else \
			echo "  GPU backend: NOT FOUND (this build is CPU-only)"; \
		fi; \
	else \
		echo "  llama-server: NOT FOUND (cannot list devices)"; \
	fi
	@if command -v nvidia-smi >/dev/null 2>&1; then \
		echo "  VRAM in use:"; \
		nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader | sed 's/^/    /'; \
	fi
# -------------------------------------------------------------------
# Clean: remove everything this Makefile installed
#   make clean         asks for confirmation first
#   make clean YES=1   no prompt
# Individual pieces: clean-venv, clean-opencode, clean-llama
# -------------------------------------------------------------------
 
clean: confirm clean-opencode clean-llama clean-venv
	@echo ""
	@echo "==> Clean complete."
 
confirm:
	@if [ "$(YES)" != "1" ]; then \
		echo "This will remove:"; \
		echo "  - $(VENV)"; \
		echo "  - opencode (binary + its config, data, cache, state)"; \
		echo "  - llama binary and the downloaded models in the llama.cpp cache"; \
		read -r -p "Continue? [y/N] " a; \
		if [ "$$a" != "y" ] && [ "$$a" != "Y" ]; then echo "Aborted."; exit 1; fi; \
	fi
 
clean-venv:
	@echo "==> Removing $(VENV)..."
	@rm -rf "$(VENV)"
 
# opencode's own uninstall command removes config/data/cache/state.
# For curl installs it leaves the executable, so remove that too.
clean-opencode:
	@echo "==> Removing opencode..."
	@if command -v opencode >/dev/null 2>&1; then \
		OC="$$(command -v opencode)"; \
		opencode uninstall --force || true; \
		if [ -e "$$OC" ]; then \
			case "$$OC" in \
				"$(HOME)"/*) rm -f "$$OC"; echo "  removed $$OC";; \
				*) echo "  $$OC is outside $(HOME) (package manager?), not removing it.";; \
			esac; \
		fi; \
		rmdir "$(HOME)/.opencode/bin" "$(HOME)/.opencode" 2>/dev/null || true; \
	else \
		echo "  opencode not installed."; \
	fi
 
# llama has no documented uninstall command, so this removes the binary
# the curl installer put on PATH plus the default model cache locations.
clean-llama: stop
	@echo "==> Removing llama.cpp..."
	@if command -v llama >/dev/null 2>&1; then \
		LL="$$(command -v llama)"; \
		case "$$LL" in \
			"$(HOME)"/*) rm -f "$$LL"; echo "  removed $$LL";; \
			*) echo "  $$LL is outside $(HOME) (brew/winget/system package?)."; \
			   echo "  Remove it with its package manager, e.g. 'brew uninstall llama.cpp'.";; \
		esac; \
	else \
		echo "  llama not installed."; \
	fi
	@rm -rf "$(HOME)/.cache/llama.cpp" "$(HOME)/Library/Caches/llama.cpp"
	@echo "  removed default model cache (if any)."
 
.PHONY: install python llama opencode model serve stop opencode-local status clean confirm clean-venv clean-opencode clean-llama
 