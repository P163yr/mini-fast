# Install only H3 Fused Kernels.
USER root

RUN git clone --depth 1 --branch main \
      https://github.com/ByronLeeeee/ComfyUI-MiniMax-H3-Optimization-Suite.git \
      /tmp/h3-optimization-suite && \
    test -f /tmp/h3-optimization-suite/plugins/ComfyUI-H3-Fused-Kernels/__init__.py && \
    mkdir -p /comfyui/custom_nodes && \
    test ! -e /comfyui/custom_nodes/ComfyUI-H3-Fused-Kernels && \
    cp -a /tmp/h3-optimization-suite/plugins/ComfyUI-H3-Fused-Kernels \
      /comfyui/custom_nodes/ComfyUI-H3-Fused-Kernels && \
    git -C /tmp/h3-optimization-suite rev-parse HEAD | \
      tee /comfyui/custom_nodes/ComfyUI-H3-Fused-Kernels/SOURCE_COMMIT && \
    rm -rf /tmp/h3-optimization-suite

# Install plugin requirements if supplied, while pinning the
# currently installed working runtime versions.
RUN /opt/venv/bin/python -c 'from importlib.metadata import version; print("\n".join(n + "==" + version(n) for n in ("torch", "torchvision", "torchaudio", "triton", "comfy-kitchen", "comfy-aimdo")))' \
      > /tmp/h3-runtime-pins.txt && \
    if [ -f /comfyui/custom_nodes/ComfyUI-H3-Fused-Kernels/requirements.txt ]; then \
      uv pip install --python /opt/venv/bin/python \
        --constraint /tmp/h3-runtime-pins.txt \
        -r /comfyui/custom_nodes/ComfyUI-H3-Fused-Kernels/requirements.txt; \
    fi && \
    rm -f /tmp/h3-runtime-pins.txt
