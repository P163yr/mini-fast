FROM runpod/worker-comfyui:5.8.4-base

USER root
WORKDIR /comfyui

ENV COMFY_LOG_LEVEL=INFO
ENV CC=/usr/bin/gcc
ENV CXX=/usr/bin/g++

# 1. Retain the system dependencies from the original working file.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        python3.12-dev \
        git \
    && rm -rf /var/lib/apt/lists/*

RUN gcc --version && \
    g++ --version && \
    test -f /usr/include/python3.12/Python.h

# 2. Retain the working ComfyUI version.
RUN git fetch --depth 1 origin tag v0.38.2 && \
    git checkout --detach v0.38.2

# 3. Retain the working PyTorch / CUDA wheel versions.
RUN uv pip install --python /opt/venv/bin/python \
    "torch==2.11.0+cu130" \
    "torchvision==0.26.0+cu130" \
    "torchaudio==2.11.0+cu130" \
    --index-url https://download.pytorch.org/whl/cu130

# 4. Install ComfyUI dependencies as before.
RUN uv pip install --python /opt/venv/bin/python \
    -r /comfyui/requirements.txt

# 5. Retain the existing KJNodes installation method.
RUN mkdir -p /comfyui/custom_nodes && \
    git clone --depth 1 \
        https://github.com/kijai/ComfyUI-KJNodes \
        /comfyui/custom_nodes/ComfyUI-KJNodes

RUN if [ -f /comfyui/custom_nodes/ComfyUI-KJNodes/requirements.txt ]; then \
        uv pip install --python /opt/venv/bin/python \
            -r /comfyui/custom_nodes/ComfyUI-KJNodes/requirements.txt; \
    fi

# 6. Retain SageAttention for existing workflows / dense attention.
RUN uv pip install --python /opt/venv/bin/python sageattention

# 7. Check package metadata only: no GPU imports or kernel execution.
# Veda 0.3.1 requires triton >= 3.0 on Linux. Reuse PyTorch's copy.
# Do not upgrade or reinstall Triton independently of PyTorch.
RUN /opt/venv/bin/python -c "from importlib.metadata import version; \
from packaging.version import Version; \
print('PyTorch:', version('torch')); \
print('Torchvision:', version('torchvision')); \
print('Torchaudio:', version('torchaudio')); \
print('Triton:', version('triton')); \
print('SageAttention:', version('sageattention')); \
assert version('torch') == '2.11.0+cu130', 'Unexpected PyTorch version'; \
assert version('torchvision') == '0.26.0+cu130', 'Unexpected torchvision version'; \
assert version('torchaudio') == '2.11.0+cu130', 'Unexpected torchaudio version'; \
assert Version(version('triton')) >= Version('3.0'), 'Veda requires Triton >= 3.0'; \
print('Package checks passed; GPU validation happens at runtime.')"

# 8. Install the exact Veda 0.3.1 source revision.
# Fetch one commit instead of cloning the complete repository history.
ARG VEDA_COMMIT=8d7ac153ac215d636eaf1b5910b0536c3de9e6ed

RUN mkdir -p /comfyui/custom_nodes/Veda-on-ComfyUI && \
    git -C /comfyui/custom_nodes/Veda-on-ComfyUI init && \
    git -C /comfyui/custom_nodes/Veda-on-ComfyUI remote add origin \
        https://github.com/veda-sparse/Veda-on-ComfyUI.git && \
    git -C /comfyui/custom_nodes/Veda-on-ComfyUI fetch \
        --depth 1 origin "${VEDA_COMMIT}" && \
    git -C /comfyui/custom_nodes/Veda-on-ComfyUI checkout --detach FETCH_HEAD && \
    test "$(git -C /comfyui/custom_nodes/Veda-on-ComfyUI rev-parse HEAD)" = "${VEDA_COMMIT}" && \
    git -C /comfyui/custom_nodes/Veda-on-ComfyUI rev-parse HEAD \
        > /comfyui/veda_revision.txt

# 9. Validate Veda source syntax without loading GPU-dependent modules.
RUN test -f /comfyui/custom_nodes/Veda-on-ComfyUI/__init__.py && \
    test -f /comfyui/custom_nodes/Veda-on-ComfyUI/veda_comfy/nodes.py && \
    /opt/venv/bin/python -m compileall -q \
        /comfyui/custom_nodes/Veda-on-ComfyUI/__init__.py \
        /comfyui/custom_nodes/Veda-on-ComfyUI/veda_comfy

# 10. Read models from the attached network volume at runtime.
# No predictor downloads or volume access are needed during the build.
COPY extra_model_paths.yaml /comfyui/extra_model_paths.yaml

RUN /opt/venv/bin/python -c "from pathlib import Path; import yaml; \
p = Path('/comfyui/extra_model_paths.yaml'); \
cfg = yaml.safe_load(p.read_text())['runpod_worker_comfy']; \
assert cfg['base_path'] == '/runpod-volume'; \
assert cfg['veda'] == 'models/veda/'; \
print('Network-volume configuration OK.')"

# Inherit the base image's RunPod handler and /start.sh command.
WORKDIR /
