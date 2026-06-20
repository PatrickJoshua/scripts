#!/bin/bash

# Configuration
LLAMA_DIR="/home/pa3k/llama.cpp"
DEFAULT_MODEL="$LLAMA_DIR/models/qwen2.5-coder-7b-instruct-q4_k_m.gguf"
MODEL_PATH="${1:-$DEFAULT_MODEL}"
SERVER_BIN="$LLAMA_DIR/build/bin/llama-server"
PORT=8888
#CTX_SIZE=8192
#CTX_SIZE=16384
CTX_SIZE=32768
GPU_LAYERS=99

# Check if model exists
if [ ! -f "$MODEL_PATH" ]; then
    echo "Error: Model file not found at $MODEL_PATH"
    exit 1
fi

# Start the server with Vulkan support
echo "Starting llama.cpp server with Vulkan support..."
echo "Model: $MODEL_PATH"
echo "Port: $PORT"

"$SERVER_BIN" \
    -m "$MODEL_PATH" \
    --port "$PORT" \
    --n-gpu-layers "$GPU_LAYERS" \
    --device Vulkan0 \
    --ctx-size "$CTX_SIZE" \
    --mlock --no-mmap \
    --tools read_file,write_file,exec_shell_command
#    --jinja
