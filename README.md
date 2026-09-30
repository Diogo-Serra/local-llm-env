# local-llm
 
A reproducible environment for running locally hosted language models with minimal configuration.
 
## Description
 
`local-llm` automates the provisioning of a local inference environment for open-weight language models. It combines [llama.cpp](https://github.com/ggml-org/llama.cpp) as the inference runtime with [opencode](https://github.com/anomalyco/opencode) as a command-line agent interface, and as the agent harness, the layer that provides tool use, context management, and a terminal interface to the model. Once installed, all inference runs on the local machine and requires no external API services.
 
The project is intended as a convenient baseline for experimentation with locally hosted models, and for users who prefer not to assemble the toolchain manually.

It was developed and tested on limited GPU hardware ([GPU model, VRAM]), which is why the default models are small, quantized 4B-parameter variants. The setup is not tied to this configuration. It can be adapted to less capable hardware by choosing smaller or more heavily quantized models, and to more capable hardware by serving larger models or longer context windows.
 
## Scope and Design Goals
 
- **Reproducibility.** Dependencies are pinned through `uv.lock`, and installation is performed by a single scripted procedure.
- **Locality.** Inference is performed entirely on the host machine. No network access is required during normal operation, after models have been downloaded.
- **Low configuration overhead.** Installation and startup are driven by Makefile targets; no manual editing of configuration files is required for the default setup.
- **Multi-model serving.** llama.cpp is run in router mode, which serves all cached models on demand.
## Default Models
 
Two quantized models are configured by default:
 
| Model | Identifier | Quantization |
|---|---|---|
| Sharp Spark X2.5 4B | `peculiar-ragdoll/Sharp-Spark-X2.5-4B-GGUF` | Q6_K_XL |
| Qwen3.8 4B Distill | `empero-ai/Qwen3.8-4B-Distill-GGUF` | Q8_0 |
 
Model files are obtained from the [Hugging Face Hub](https://huggingface.co) & [llama.app](https://llama.app/models).
 
## Requirements
 
| Component | Requirement | Provisioning |
|---|---|---|
| Python | >= 3.14 | Managed by the project |
| Package manager | [uv](https://github.com/astral-sh/uv) | Installed by `make install` |
| Inference runtime | llama.cpp | Installed by `make install` |
| Agent interface | opencode | Installed by `make install` |
| Model hosting | Hugging Face Hub | Used to download model files |
 
## Installation
 
```bash
make install
```
 
This target performs the following steps:
 
1. Creates the Python environment (`.venv`) and installs `uv` if it is not already present.
2. Installs llama.cpp and opencode.
3. Verifies that all components were installed correctly.
4. Confirms that the configured models are available.
A summary of the resulting setup is printed on completion.
 
## Usage
 
### 1. Start the inference server
 
```bash
make serve
```
 
Starts llama.cpp in router mode. All cached models are served on demand at `http://127.0.0.1:8080`.
 
### 2. Start the agent interface
 
```bash
make opencode-local
```
 
Launches opencode, configured through `opencode.json` to connect to the local llama.cpp server.
 
### 3. Verify system status
 
```bash
make status
```
 
Reports the state of the installed binaries, the server process, and the available models.
 
### 4. Stop and clean up
 
| Command | Effect |
|---|---|
| `make stop` | Stops the llama.cpp server. |
| `make clean` | Removes the Python environment, opencode, llama.cpp, and downloaded models. Requires confirmation. |
 
## Configuration
 
Default settings are defined in the project files and can be overridden through Makefile variables:
 
| Variable | Purpose |
|---|---|
| `MODEL` | Model(s) to be served |
| `HOST` | Server bind address (default `127.0.0.1`) |
| `PORT` | Server port (default `8080`) |
| `CONTEXT` | Context window size |
| `PARALLEL` | Number of parallel request slots |
 
The connection between opencode and the local server is defined in `opencode.json`.
 
## Using Additional Models
 
Models other than the defaults may be used as follows.
 
1. Obtain a GGUF-format model from the Hugging Face Hub:
```bash
   (.venv) # to use hf:huggingface
   llama serve -hf MyModel-7B-GGUF:Q4_K_M/MyModel-7B-GGUF-Q4_K_M.gguf
```
 
2. For future use, add the model to the `MODEL` variable in the `Makefile`:
```makefile
   MODEL := Sharp-Spark-X2.5-4B-GGUF:Q6_K_XL|Qwen3.8-4B-Distill-GGUF:Q8_0|MyModel-7B-GGUF:Q4_K_M
```
 
3. Re-run `make install`, followed by `make serve` and `make opencode-local`.
Only two components require modification to support additional models: llama.cpp (inference) and opencode (model routing and configuration).
 
## Adapting to Different Hardware
 
The defaults reflect the limited hardware described above. Resource use is controlled in two places: the `Makefile` variables (see [Configuration](#configuration)) and the choice of model.
 
| To reduce memory use or load | To use more capable hardware |
|---|---|
| Lower `CONTEXT` (smaller context window) | Raise `CONTEXT` (longer context window) |
| Lower `PARALLEL` (fewer concurrent request slots) | Raise `PARALLEL` (more concurrent request slots) |
| Serve a smaller model, or a lower quantization (for example Q4 instead of Q8) | Serve a larger model, or a higher quantization |
 
Changes to the `Makefile` take effect the next time the server is started with `make serve`. New models are added as described in [Using Additional Models](#using-additional-models). Further server options, including GPU offloading, are documented in the [llama.cpp server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md).

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
 
## Additional Resources
 
The following references document the components on which this project depends. They are maintained by their respective projects and may change independently of this repository.
 
### llama.cpp
 
| Resource | Description |
|---|---|
| [Repository](https://github.com/ggml-org/llama.cpp) | Source code, releases, and build instructions |
| [Server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) | `llama-server` options, HTTP API, and router mode |
| [Server development notes](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README-dev.md) | Architecture of the server and of router mode |
| [Model management in llama.cpp](https://huggingface.co/blog/ggml-org/model-management-in-llamacpp) | Overview of router mode, model caching, and on-demand loading |
 
### opencode
 
| Resource | Description |
|---|---|
| [Repository](https://github.com/anomalyco/opencode) | Source code and releases |
| [Documentation](https://opencode.ai/docs/) | Installation and general usage |
| [Configuration](https://opencode.ai/docs/config/) | The `opencode.json` file and its options |
| [Providers](https://opencode.ai/docs/providers/) | Connecting opencode to model providers, including local servers |
| [Models](https://opencode.ai/docs/models/) | Selecting and configuring models |
| [Agents](https://opencode.ai/docs/agents/) | Defining primary agents and subagents |
| [Agent Skills](https://opencode.ai/docs/skills/) | Creating and loading reusable skills |
| [Commands](https://opencode.ai/docs/commands/) | Custom slash commands |
| [Rules](https://opencode.ai/docs/rules/) | Project instructions through `AGENTS.md` |
| [MCP servers](https://opencode.ai/docs/mcp-servers/) | Connecting external tools through the Model Context Protocol |
| [Custom tools](https://opencode.ai/docs/custom-tools/) | Extending opencode with user-defined tools |
| [Plugins](https://opencode.ai/docs/plugins/) | Extending opencode through the plugin interface |
| [Permissions](https://opencode.ai/docs/permissions/) | Controlling which actions an agent may perform |
| [Ecosystem](https://opencode.ai/docs/ecosystem/) | Community plugins, tools, and projects |
 
### Model Distribution
 
| Resource | Description |
|---|---|
| [Hugging Face Hub](https://huggingface.co) | Repository of open-weight models, including GGUF-format files |

## Project Status and Contributions
 
This project is a work in progress. It was created as a learning exercise to better understand large language models and the tooling used to run them locally, and it may contain errors, omissions, or outdated information.
 
Findings, corrections, bug reports, and suggestions are welcome and may be submitted through the issue tracker of this repository. Reports are most useful when they include the hardware used, the operating system, the model and quantization served, and the relevant `Makefile` settings.

## AI Use Disclosure
 
AI tools, including small language models, were used to support the development of this project and the writing of its documentation. The author remains responsible for the accuracy, originality, and final content of the work.
