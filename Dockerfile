FROM runpod/worker-comfyui:5.8.4-base

USER root
WORKDIR /comfyui

ENV COMFY_LOG_LEVEL=INFO
ENV CC=/usr/bin/gcc
ENV CXX=/usr/bin/g++

# ---------------------------------------------------------
# System build dependencies for Triton / SageAttention
# ---------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        python3.12-dev \
        git \
        && \
    rm -rf /var/lib/apt/lists/*

# Verify compiler + Python headers exist
RUN gcc --version && \
    g++ --version && \
    test -f /usr/include/python3.12/Python.h && \
    echo "Python 3.12 development headers OK"

# ---------------------------------------------------------
# Pin ComfyUI
# ---------------------------------------------------------
RUN git fetch --depth 1 origin tag v0.38.2 && \
    git checkout --detach v0.38.2

# ---------------------------------------------------------
# PyTorch CUDA 13
# ---------------------------------------------------------
RUN uv pip install --python /opt/venv/bin/python \
    "torch==2.11.0+cu130" \
    "torchvision==0.26.0+cu130" \
    "torchaudio==2.11.0+cu130" \
    --index-url https://download.pytorch.org/whl/cu130

# ---------------------------------------------------------
# ComfyUI requirements
# ---------------------------------------------------------
RUN uv pip install --python /opt/venv/bin/python \
    -r /comfyui/requirements.txt

# ---------------------------------------------------------
# KJNodes
# Provides PathchSageAttentionKJ
# ---------------------------------------------------------
RUN mkdir -p /comfyui/custom_nodes && \
    git clone --depth 1 \
        https://github.com/kijai/ComfyUI-KJNodes \
        /comfyui/custom_nodes/ComfyUI-KJNodes

RUN if [ -f /comfyui/custom_nodes/ComfyUI-KJNodes/requirements.txt ]; then \
        uv pip install --python /opt/venv/bin/python \
            -r /comfyui/custom_nodes/ComfyUI-KJNodes/requirements.txt; \
    fi

# ---------------------------------------------------------
# SageAttention
# ---------------------------------------------------------
RUN uv pip install --python /opt/venv/bin/python \
    sageattention

# ---------------------------------------------------------
# Network volume model paths
# ---------------------------------------------------------
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# ---------------------------------------------------------
# Final verification
# ---------------------------------------------------------
RUN /opt/venv/bin/python - <<'PY'
import os
import shutil
import torch
import sageattention
import triton

print("PyTorch:", torch.__version__)
print("PyTorch CUDA:", torch.version.cuda)
print("CUDA available:", torch.cuda.is_available())
print("GPU capability:", torch.cuda.get_device_capability() if torch.cuda.is_available() else None)
print("Triton:", triton.__version__)
print("SageAttention: imported successfully")
print("CC:", os.environ.get("CC"))
print("CXX:", os.environ.get("CXX"))
print("gcc:", shutil.which("gcc"))
print("g++:", shutil.which("g++"))

assert torch.version.cuda == "13.0"
assert shutil.which("gcc") is not None
assert shutil.which("g++") is not None
assert os.path.exists("/usr/include/python3.12/Python.h")

print("All SageAttention/Triton build dependencies OK")
PY

WORKDIR /
