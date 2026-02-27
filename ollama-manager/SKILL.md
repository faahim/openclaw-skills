---
name: ollama-manager
description: >-
  Install, configure, and manage local LLMs via Ollama. Pull models, run inference, monitor GPU/RAM usage, and automate model lifecycle.
categories: [dev-tools, automation]
dependencies: [bash, curl]
---

# Ollama Manager

## What This Does

Run large language models locally with zero cloud dependencies. This skill installs Ollama, manages model downloads, runs inference, monitors resource usage, and automates model lifecycle — all from your terminal.

**Example:** "Install Ollama, pull llama3.2, run a prompt, check GPU usage, clean up old models."

## Quick Start (5 minutes)

### 1. Install Ollama

```bash
bash scripts/install.sh
```

This detects your OS (Linux/macOS), installs Ollama, and starts the service.

### 2. Pull Your First Model

```bash
bash scripts/run.sh pull llama3.2
```

### 3. Run a Prompt

```bash
bash scripts/run.sh prompt llama3.2 "Explain quantum computing in 3 sentences"
```

### 4. Check Status

```bash
bash scripts/run.sh status
```

## Core Workflows

### Workflow 1: Pull and Run Models

```bash
# Pull a model
bash scripts/run.sh pull llama3.2
bash scripts/run.sh pull codellama
bash scripts/run.sh pull mistral

# Run a prompt
bash scripts/run.sh prompt llama3.2 "Write a bash script to find large files"

# Run with system prompt
bash scripts/run.sh prompt codellama "Refactor this function" --system "You are a senior Go developer"

# Chat interactively
bash scripts/run.sh chat mistral
```

### Workflow 2: List and Manage Models

```bash
# List all downloaded models
bash scripts/run.sh list

# Show model details (size, parameters, quantization)
bash scripts/run.sh info llama3.2

# Delete a model
bash scripts/run.sh delete codellama:7b

# Pull a specific variant
bash scripts/run.sh pull llama3.2:3b
bash scripts/run.sh pull llama3.2:70b-q4_0
```

### Workflow 3: Monitor Resources

```bash
# Check Ollama service status + resource usage
bash scripts/run.sh status

# Output:
# Ollama v0.6.x — Running
# Models loaded: llama3.2 (3.8 GB VRAM)
# GPU: NVIDIA RTX 4090 — 8.2/24 GB used
# RAM: 12.4/64 GB used
# Disk: 3 models, 18.7 GB total

# Monitor in real-time (updates every 5s)
bash scripts/run.sh monitor
```

### Workflow 4: Batch Inference

```bash
# Process multiple prompts from a file
bash scripts/run.sh batch llama3.2 prompts.txt --output results.jsonl

# Format: one prompt per line in prompts.txt
# Output: JSONL with prompt + response pairs
```

### Workflow 5: Model Cleanup

```bash
# Show disk usage per model
bash scripts/run.sh disk

# Remove models not used in 30+ days
bash scripts/run.sh cleanup --days 30

# Remove all models except specified ones
bash scripts/run.sh cleanup --keep "llama3.2,mistral"
```

### Workflow 6: API Server Management

```bash
# Check if Ollama API is responding
bash scripts/run.sh health

# Restart the Ollama service
bash scripts/run.sh restart

# Set custom host/port
bash scripts/run.sh config --host 0.0.0.0 --port 11434

# Generate embeddings
bash scripts/run.sh embed llama3.2 "Your text here"
```

## Configuration

### Environment Variables

```bash
# Ollama API endpoint (default: http://localhost:11434)
export OLLAMA_HOST="http://localhost:11434"

# Custom models directory
export OLLAMA_MODELS="/path/to/models"

# GPU layers to offload (0 = CPU only)
export OLLAMA_NUM_GPU=99

# Max concurrent requests
export OLLAMA_MAX_LOADED_MODELS=2
```

### Recommended Models by Use Case

| Use Case | Model | Size | Notes |
|----------|-------|------|-------|
| General chat | llama3.2 | 2-4 GB | Best all-rounder |
| Code generation | codellama | 4-7 GB | Code-focused |
| Small/fast | phi3:mini | 2 GB | Good for low-RAM |
| Creative writing | mistral | 4 GB | Strong creative output |
| Embeddings | nomic-embed-text | 274 MB | Fast vector embeddings |
| Vision | llava | 4.7 GB | Image understanding |

## Advanced Usage

### Run as SystemD Service

```bash
# The installer sets this up automatically on Linux
sudo systemctl status ollama
sudo systemctl restart ollama
sudo journalctl -u ollama -f
```

### Use with OpenClaw

```bash
# In your OpenClaw config, set Ollama as a provider:
# provider: ollama
# model: llama3.2
# baseUrl: http://localhost:11434/v1

# Test the OpenAI-compatible endpoint
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.2","messages":[{"role":"user","content":"Hello"}]}'
```

### Custom Modelfiles

```bash
# Create a custom model from a Modelfile
cat > Modelfile <<EOF
FROM llama3.2
SYSTEM "You are a helpful coding assistant. Always provide working code examples."
PARAMETER temperature 0.3
PARAMETER num_ctx 4096
EOF

bash scripts/run.sh create my-coder --modelfile Modelfile

# Run your custom model
bash scripts/run.sh prompt my-coder "Write a Python web scraper"
```

### GPU Troubleshooting

```bash
# Check GPU detection
bash scripts/run.sh gpu

# Output:
# GPU 0: NVIDIA RTX 4090 (24 GB VRAM)
# CUDA: 12.4
# Driver: 550.54
# Ollama GPU offload: enabled

# Force CPU-only mode
OLLAMA_NUM_GPU=0 bash scripts/run.sh prompt llama3.2 "test"
```

## Troubleshooting

### Issue: "ollama: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually: curl -fsSL https://ollama.com/install.sh | sh
```

### Issue: Models download slowly

**Fix:** Ollama uses ~/.ollama/models by default. Ensure the disk has enough space:
```bash
df -h ~/.ollama
```

### Issue: Out of memory (OOM)

**Fix:** Use a smaller quantization:
```bash
bash scripts/run.sh pull llama3.2:3b-q4_0  # Smaller variant
```

### Issue: GPU not detected

**Fix:**
```bash
# Check NVIDIA drivers
nvidia-smi

# Check CUDA
nvcc --version

# Reinstall Ollama (picks up GPU automatically)
bash scripts/install.sh
```

## Key Principles

1. **Local-first** — All inference runs on your machine, no data leaves
2. **Model management** — Track what's installed, clean up what's unused
3. **Resource-aware** — Monitor GPU/RAM/disk before pulling large models
4. **OpenAI-compatible** — Works as a drop-in replacement for OpenAI API
