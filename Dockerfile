FROM runpod/worker-comfyui:5.8.4-base

USER root
WORKDIR /comfyui

ENV COMFY_LOG_LEVEL=INFO

# Pin modern ComfyUI instead of "latest"
RUN git fetch --depth 1 origin tag v0.38.2 && \
    git checkout --detach v0.38.2

# CUDA 13 PyTorch
RUN uv pip install --python /opt/venv/bin/python \
    "torch==2.11.0+cu130" \
    "torchvision==0.26.0+cu130" \
    "torchaudio==2.11.0+cu130" \
    --index-url https://download.pytorch.org/whl/cu130

# Install dependencies for this ComfyUI checkout
RUN uv pip install --python /opt/venv/bin/python \
    -r /comfyui/requirements.txt

COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

RUN /opt/venv/bin/python -c \
    "import torch, comfy_kitchen, comfy_aimdo.storage; print('PyTorch:', torch.__version__, 'CUDA:', torch.version.cuda); assert torch.version.cuda == '13.0'"

WORKDIR /
