# Listing Copy: Ollama Manager

## Metadata
- **Type:** Skill
- **Name:** ollama-manager
- **Display Name:** Ollama Manager
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [bash, curl]
- **Icon:** 🦙

## Tagline

Run local LLMs with zero cloud — install, manage, and monitor Ollama models

## Description

Cloud AI APIs are expensive, slow, and send your data to third parties. Running models locally solves all three problems — but managing Ollama manually is tedious: installing, pulling models, checking GPU usage, cleaning up disk space.

Ollama Manager automates the entire lifecycle. Install Ollama with one command, pull models, run prompts, batch-process files, monitor GPU/RAM, and clean up unused models — all from your OpenClaw agent.

**What it does:**
- 🦙 Install Ollama on Linux or macOS (auto-detects GPU)
- 📥 Pull, list, and delete models with simple commands
- 💬 Run prompts, batch inference, and embeddings
- 📊 Monitor GPU/RAM/disk usage in real-time
- 🧹 Auto-cleanup models unused for N days
- 🔧 Configure host, port, GPU offload, and custom Modelfiles
- 🔌 OpenAI-compatible API endpoint included

Perfect for developers, AI engineers, and privacy-conscious users who want local LLM inference without cloud dependencies.

## Quick Start Preview

```bash
# Install Ollama
bash scripts/install.sh

# Pull and run a model
bash scripts/run.sh pull llama3.2
bash scripts/run.sh prompt llama3.2 "Explain Docker in 3 sentences"

# Check status
bash scripts/run.sh status
```

## Core Capabilities

1. One-command install — Detects OS, installs Ollama, starts service
2. Model management — Pull, list, delete, show info for any model
3. Prompt runner — One-shot prompts with optional system prompts
4. Batch inference — Process files of prompts, output JSONL
5. Embedding generation — Vector embeddings for RAG pipelines
6. Custom models — Create models from Modelfiles with custom parameters
7. Resource monitoring — GPU/RAM/disk usage with real-time updates
8. Auto-cleanup — Remove models unused for N days
9. GPU detection — NVIDIA CUDA and Apple Silicon Metal support
10. OpenAI-compatible — Drop-in replacement for OpenAI API

## Dependencies
- `bash` (4.0+)
- `curl`
- `jq` (for JSON parsing)
- Optional: NVIDIA GPU with CUDA or Apple Silicon for acceleration

## Installation Time
**5 minutes** — Run install script, pull first model
