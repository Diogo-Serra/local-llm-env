# local-llm
 
A reproducible, low-configuration environment for running open-weight language models entirely on your own machine.
 
`local-llm` provisions a complete local inference stack with a single command: [llama.cpp](https://github.com/ggml-org/llama.cpp) as the inference runtime and [opencode](https://github.com/anomalyco/opencode) as the command-line agent interface (the harness that provides tool use, context management, and a terminal UI). Once models are downloaded, no external API or network access is required.
 
It is intended as a convenient baseline for experimenting with locally hosted models, and for users who would rather not assemble the toolchain by hand.
 
> **Tested hardware:** 6 GB of VRAM. The default models are therefore small, quantized variants (roughly 2B–4B parameters). Nothing in the setup is tied to this configuration; see [Adapting to Different Hardware](#adapting-to-different-hardware).
 
## Table of Contents
 
- [Features](#features)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Configuration](#configuration)
- [Models](#models)
- [Adapting to Different Hardware](#adapting-to-different-hardware)
- [MCP Servers](#mcp-servers)
- [Repository Structure](#repository-structure)
- [Resources](#resources)
- [Project Status and Contributing](#project-status-and-contributing)
- [AI Use Disclosure](#ai-use-disclosure)
## Features
 
- **Reproducible.** Dependencies are pinned in `uv.lock`, and installation is a single scripted procedure.
- **Local-first.** All inference runs on the host. After the initial model download, no network access is needed during normal operation.
- **Low configuration overhead.** Installation and startup are driven by `make` targets; the default setup requires no manual editing of configuration files.
- **Multi-model serving.** llama.cpp runs in router mode, serving every cached model on demand through one endpoint.
## Requirements
 
| Component | Requirement | Provisioning |
|---|---|---|
| Python | >= 3.14 | Managed by the project |
| Package manager | [uv](https://github.com/astral-sh/uv) | Installed by `make install` |
| Inference runtime | [llama.cpp](https://github.com/ggml-org/llama.cpp) | Installed by `make install` |
| Agent interface | [opencode](https://github.com/anomalyco/opencode) | Installed by `make install` |
| Model source | [Hugging Face Hub](https://huggingface.co) | Used to download GGUF model files |
| MCP servers (optional) | See [MCP Servers](#mcp-servers) | Installed manually |
 
Recommended: a GPU with at least 6 GB of VRAM for the default models. Smaller or more heavily quantized models can run on less capable hardware.
 
## Quick Start
 
```bash
make install   # provision the environment and download the default model
make serve     # start the inference server (terminal 1)
make opencode-local   # start the agent interface (terminal 2)
```
 
## Usage
 
### Installation
 
```bash
make install
```
 
This target:
 
1. Creates the Python environment (`.venv`) and installs `uv` if it is not already present.
2. Installs llama.cpp and opencode.
3. Verifies that all components were installed correctly.
4. Confirms that the configured models are available.
A summary of the resulting setup is printed on completion.
 
### Start the inference server
 
```bash
make serve
```
 
Starts llama.cpp in router mode. All cached models are served on demand at `http://127.0.0.1:8080`.
 
### Start the agent interface
 
```bash
make opencode-local
```
 
Launches opencode, which connects to the local llama.cpp server as defined in `opencode.json`.
 
### Check system status
 
```bash
make status
```
 
Reports the state of the installed binaries, the server process, and the available models.
 
### Stop and clean up
 
| Command | Effect |
|---|---|
| `make stop` | Stops the llama.cpp server. |
| `make clean` | Removes the Python environment, opencode, llama.cpp, and downloaded models. Requires confirmation. |
 
## Configuration
 
Defaults are defined in the project files and can be overridden through `Makefile` variables:
 
| Variable | Purpose | Default |
|---|---|---|
| `MODEL` | Model(s) to be served | See [Models](#models) |
| `HOST` | Server bind address | `127.0.0.1` |
| `PORT` | Server port | `8080` |
| `CONTEXT` | Context window size | Defined in `Makefile` |
| `PARALLEL` | Number of parallel request slots | Defined in `Makefile` |
 
The connection between opencode and the local server is defined in `opencode.json`. Changes to the `Makefile` take effect the next time the server is started with `make serve`.
 
## Models
 
Model files are obtained from the [Hugging Face Hub](https://huggingface.co) in GGUF format.
 
### Default model
 
| Model | Identifier | Quantization |
|---|---|---|
| LFM2.5 2.6B | `LiquidAI/LFM2.5-2.6B-GGUF:Q8_0` | Q8_0 |
 
### Also tested
 
| Model | Quantization | Notes |
|---|---|---|
| `openbmb/MiniCPM5-2B-GGUF` | Q8_0 | Small 2B model for efficient inference |
| `openbmb/MiniCPM5-2B-GGUF` | F16 | Full-precision variant of the above |
| `empero-ai/Qwen3.8-2B-Distill-GGUF` | BF16 | Distilled Qwen3.8 2B |
| `lmstudio-community/Qwen3-4B-Instruct-2507-GGUF` | Q4_K_M | 4B instruct model |
| `Qwen/Qwen2.5-Coder-3B-Instruct-GGUF` | Q8_0 | Code-focused 3B model |
 
### Adding other models
 
1. Download a GGUF model from the Hugging Face Hub by serving it once with llama.cpp (from within the activated `.venv`):
```bash
   llama-server -hf MyModel-7B-GGUF:Q4_K_M
```
 
2. To make the model permanent, add it to the `MODEL` variable in the `Makefile`:
```makefile
   MODEL := LiquidAI/LFM2.5-2.6B-GGUF:Q8_0|MyOrg/MyModel-7B-GGUF:Q4_K_M
```
 
3. Re-run `make install`, then `make serve` and `make opencode-local`.
Only two components need to know about additional models: llama.cpp (inference) and opencode (model routing and configuration).
 
## Adapting to Different Hardware
 
The defaults reflect the 6 GB VRAM test configuration. Resource use is controlled by the `Makefile` variables and by the choice of model.
 
| To reduce memory use or load | To use more capable hardware |
|---|---|
| Lower `CONTEXT` (smaller context window) | Raise `CONTEXT` (longer context window) |
| Lower `PARALLEL` (fewer concurrent request slots) | Raise `PARALLEL` (more concurrent request slots) |
| Serve a smaller model or a lower-bit quantization (e.g. Q4 instead of Q8) | Serve a larger model or a higher-precision quantization |
 
Further server options, including GPU offloading, are documented in the [llama.cpp server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md).
 
## MCP Servers
 
opencode can use [Model Context Protocol](https://opencode.ai/docs/mcp-servers/) servers to extend the agent with additional tools. The following are optional and not installed by `make install`.
 
**Terminal operations** ([terminal-mcp](https://mcpservers.org/servers/elleryfamilia/terminal-mcp)):
 
```bash
curl -fsSL https://raw.githubusercontent.com/elleryfamilia/terminal-mcp/main/install.sh | bash
terminal-mcp setup
```
 
> Piping a remote script into a shell executes code you have not reviewed. Inspect the script before running it.
 
**Web search and fetch** ([web-search-mcp](https://github.com/sydasif/web-search-mcp)):
 
```bash
uv tool install git+https://github.com/sydasif/web-search-mcp.git
```
 
Note that web-based tools require network access, which departs from the fully offline operation described above.
 
## Repository Structure
 
```
local_llm/
├── Makefile              # Automation: install, serve, status, stop, clean
├── opencode.json         # opencode configuration (local llama.cpp endpoint)
├── pyproject.toml        # Python project metadata and dependencies
├── src/
│   └── local_llm/
│       └── __init__.py   # Package initialization
└── uv.lock               # Dependency lockfile
```
 
## Resources
 
### llama.cpp
 
| Resource | Description |
|---|---|
| [Repository](https://github.com/ggml-org/llama.cpp) | Source code, releases, and build instructions |
| [Server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) | `llama-server` options, HTTP API, and router mode |
| [Server development notes](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README-dev.md) | Architecture of the server and router mode |
| [Model management in llama.cpp](https://huggingface.co/blog/ggml-org/model-management-in-llamacpp) | Router mode, model caching, and on-demand loading |
 
### opencode
 
| Resource | Description |
|---|---|
| [Repository](https://github.com/anomalyco/opencode) | Source code and releases |
| [Documentation](https://opencode.ai/docs/) | Installation and general usage |
| [Configuration](https://opencode.ai/docs/config/) | The `opencode.json` file and its options |
| [Providers](https://opencode.ai/docs/providers/) | Connecting to model providers, including local servers |
| [Models](https://opencode.ai/docs/models/) | Selecting and configuring models |
| [Agents](https://opencode.ai/docs/agents/) | Primary agents and subagents |
| [Agent Skills](https://opencode.ai/docs/skills/) | Creating and loading reusable skills |
| [Commands](https://opencode.ai/docs/commands/) | Custom slash commands |
| [Rules](https://opencode.ai/docs/rules/) | Project instructions through `AGENTS.md` |
| [MCP servers](https://opencode.ai/docs/mcp-servers/) | External tools through the Model Context Protocol |
| [Custom tools](https://opencode.ai/docs/custom-tools/) | User-defined tools |
| [Plugins](https://opencode.ai/docs/plugins/) | The plugin interface |
| [Permissions](https://opencode.ai/docs/permissions/) | Controlling which actions an agent may perform |
| [Ecosystem](https://opencode.ai/docs/ecosystem/) | Community plugins, tools, and projects |
 
### Model distribution
 
| Resource | Description |
|---|---|
| [Hugging Face Hub](https://huggingface.co) | Open-weight models, including GGUF files |
 
These references are maintained by their respective projects and may change independently of this repository.
 
## Project Status and Contributing
 
This project is a work in progress, created as a learning exercise to better understand large language models and the tooling used to run them locally. It may contain errors, omissions, or outdated information.
 
Corrections, bug reports, and suggestions are welcome through the issue tracker. Reports are most useful when they include:
 
- Hardware (GPU model and VRAM)
- Operating system
- Model and quantization served
- Relevant `Makefile` settings

## AI Use Disclosure
 
AI tools were used to support the development of this project and the writing of its documentation. This includes a locally hosted AI agent powered by `LiquidAI/LFM2.5-2.6B-GGUF:Q8_0`, the default model of this project, as well as other small language models.
 
The author reviewed the AI-assisted material and remains responsible for the accuracy, originality, and final content of the work.
