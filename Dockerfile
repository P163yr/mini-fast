FROM runpod/worker-comfyui:5.8.4-base

USER root
WORKDIR /comfyui

ENV COMFY_LOG_LEVEL=INFO

# Pin ComfyUI core to the same version you've been using.
RUN git fetch --depth 1 origin tag v0.38.2 && \
    git checkout --detach v0.38.2

# Upgrade PyTorch runtime to CUDA 13.0 so comfy-kitchen CUDA kernels are available.
RUN uv pip install --python /opt/venv/bin/python \
    "torch==2.11.0+cu130" \
    "torchvision==0.26.0+cu130" \
    "torchaudio==2.11.0+cu130" \
    --index-url https://download.pytorch.org/whl/cu130

# Reinstall ComfyUI's Python requirements against this runtime.
RUN uv pip install --python /opt/venv/bin/python \
    -r /comfyui/requirements.txt

# Install KJNodes so the workflow can use the Patch Sage Attention KJ node.
RUN mkdir -p /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes /comfyui/custom_nodes/ComfyUI-KJNodes && \
    if [ -f /comfyui/custom_nodes/ComfyUI-KJNodes/requirements.txt ]; then \
      uv pip install --python /opt/venv/bin/python \
        -r /comfyui/custom_nodes/ComfyUI-KJNodes/requirements.txt; \
    fi

# Install SageAttention itself.
RUN uv pip install --python /opt/venv/bin/python sageattention

# Keep your network-volume model path fix.
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

# Simple sanity checks.
RUN /opt/venv/bin/python - <<'PY'
import torch
print('PyTorch:', torch.__version__, 'CUDA:', torch.version.cuda)
assert torch.version.cuda == '13.0'
import sageattention
print('sageattention OK')
PY

WORKDIR /
