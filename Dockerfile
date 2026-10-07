FROM runpod/worker-comfyui:5.8.4-base

USER root
WORKDIR /comfyui

ENV COMFY_LOG_LEVEL=INFO
ENV CC=/usr/bin/gcc
ENV CXX=/usr/bin/g++

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential git && \
    rm -rf /var/lib/apt/lists/*

RUN git fetch --depth 1 origin tag v0.38.2 && \
    git checkout --detach v0.38.2

RUN uv pip install --python /opt/venv/bin/python \
    "torch==2.11.0+cu130" \
    "torchvision==0.26.0+cu130" \
    "torchaudio==2.11.0+cu130" \
    --index-url https://download.pytorch.org/whl/cu130

RUN uv pip install --python /opt/venv/bin/python \
    -r /comfyui/requirements.txt

RUN mkdir -p /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes /comfyui/custom_nodes/ComfyUI-KJNodes && \
    if [ -f /comfyui/custom_nodes/ComfyUI-KJNodes/requirements.txt ]; then \
      uv pip install --python /opt/venv/bin/python \
        -r /comfyui/custom_nodes/ComfyUI-KJNodes/requirements.txt; \
    fi

RUN uv pip install --python /opt/venv/bin/python sageattention

COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

RUN /opt/venv/bin/python - <<'PY'
import os
import shutil
import torch
import sageattention

print('PyTorch:', torch.__version__, 'CUDA:', torch.version.cuda)
print('CC:', os.environ.get('CC'), '->', shutil.which('gcc'))
print('CXX:', os.environ.get('CXX'), '->', shutil.which('g++'))
print('SageAttention import: OK')

assert torch.version.cuda == '13.0'
assert shutil.which('gcc')
assert shutil.which('g++')
PY

WORKDIR /
