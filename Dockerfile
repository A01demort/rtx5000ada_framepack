FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_CACHE_DIR=/workspace/.cache/pip

# 시스템 패키지 및 빌드 도구 + Jupyter 필수 툴 설치
RUN apt-get update && apt-get install -y \
    git wget curl ffmpeg libgl1 \
    build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncurses5-dev \
    libncursesw5-dev xz-utils tk-dev libffi-dev \
    liblzma-dev software-properties-common \
    locales sudo tzdata xterm nano \
    nodejs npm && \
    apt-get clean

# 정확한 Python 3.10.6 소스 설치 + pip 심볼릭 링크 추가
WORKDIR /tmp
RUN wget https://www.python.org/ftp/python/3.10.6/Python-3.10.6.tgz && \
    tar xzf Python-3.10.6.tgz && cd Python-3.10.6 && \
    ./configure --enable-optimizations && \
    make -j$(nproc) && make altinstall && \
    ln -sf /usr/local/bin/python3.10 /usr/bin/python && \
    ln -sf /usr/local/bin/python3.10 /usr/bin/python3 && \
    ln -sf /usr/local/bin/pip3.10 /usr/bin/pip && \
    ln -sf /usr/local/bin/pip3.10 /usr/local/bin/pip && \
    cd / && rm -rf /tmp/*

# ComfyUI 설치
WORKDIR /workspace
RUN mkdir -p /workspace && chmod -R 777 /workspace && \
    chown -R root:root /workspace
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI
WORKDIR /workspace/ComfyUI

# 의존성 설치
RUN pip install -r requirements.txt && \
    pip install torch==2.7.1 torchvision==0.22.1+cu126 torchaudio==2.7.1+cu126 --extra-index-url https://download.pytorch.org/whl/cu126

# Node.js 18 설치 (기존 nodejs 제거 후)
RUN apt-get remove -y nodejs npm && \
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    node -v && npm -v

# JupyterLab 안정 버전 설치
RUN pip install --force-reinstall jupyterlab==3.6.6 jupyter-server==1.23.6

# Jupyter 설정파일 보완
RUN mkdir -p /root/.jupyter && \
    echo "c.NotebookApp.allow_origin = '*'\n\
c.NotebookApp.ip = '0.0.0.0'\n\
c.NotebookApp.open_browser = False\n\
c.NotebookApp.token = ''\n\
c.NotebookApp.password = ''\n\
c.NotebookApp.terminado_settings = {'shell_command': ['/bin/bash']}" \
> /root/.jupyter/jupyter_notebook_config.py


# 커스텀 노드 및 의존성 설치 통합
RUN echo '📁 커스텀 노드 및 의존성 설치 시작' && \
    mkdir -p /workspace/ComfyUI/custom_nodes && \
    cd /workspace/ComfyUI/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git || echo '⚠️ Manager 실패' && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git || echo '⚠️ Scripts 실패' && \
    git clone https://github.com/rgthree/rgthree-comfy.git || echo '⚠️ rgthree 실패' && \
    git clone https://github.com/WASasquatch/was-node-suite-comfyui.git || echo '⚠️ WAS 실패' && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git || echo '⚠️ KJNodes 실패' && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git || echo '⚠️ Essentials 실패' && \
    git clone https://github.com/city96/ComfyUI-GGUF.git || echo '⚠️ GGUF 실패' && \
    git clone https://github.com/welltop-cn/ComfyUI-TeaCache.git || echo '⚠️ TeaCache 실패' && \
    git clone https://github.com/kaibioinfo/ComfyUI_AdvancedRefluxControl.git || echo '⚠️ ARC 실패' && \
    git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git || echo '⚠️ Comfyroll 실패' && \
    git clone https://github.com/cubiq/PuLID_ComfyUI.git || echo '⚠️ PuLID 실패' && \
    git clone https://github.com/sipie800/ComfyUI-PuLID-Flux-Enhanced.git || echo '⚠️ Flux 실패' && \
    git clone https://github.com/Gourieff/ComfyUI-ReActor.git || echo '⚠️ ReActor 실패' && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git || echo '⚠️ EasyUse 실패' && \
    git clone https://github.com/PowerHouseMan/ComfyUI-AdvancedLivePortrait.git || echo '⚠️ LivePortrait 실패' && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git || echo '⚠️ VideoHelper 실패' && \
    git clone https://github.com/Jonseed/ComfyUI-Detail-Daemon.git || echo '⚠️ Daemon 실패' && \
    git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git || echo '⚠️ Upscale 실패' && \
    git clone https://github.com/risunobushi/comfyUI_FrequencySeparation_RGB-HSV.git || echo '⚠️ Frequency 실패' && \
    git clone https://github.com/silveroxides/ComfyUI_bnb_nf4_fp4_Loaders.git || echo '⚠️ NF4 노드 실패' && \
    git clone https://github.com/kijai/ComfyUI-FramePackWrapper.git || echo '⚠️ FramePackWrapper 실패' && \
    echo '📦 segment-anything 설치' && \
    git clone https://github.com/facebookresearch/segment-anything.git /workspace/segment-anything || echo '⚠️ segment-anything 실패' && \
    pip install -e /workspace/segment-anything || echo '⚠️ segment-anything pip 설치 실패' && \
    echo '📦 ReActor ONNX 모델 설치' && \
    mkdir -p /workspace/ComfyUI/models/insightface && \
    wget -O /workspace/ComfyUI/models/insightface/inswapper_128.onnx https://huggingface.co/datasets/Gourieff/ReActor/resolve/main/models/inswapper_128.onnx || echo '⚠️ ONNX 다운로드 실패' && \
    echo '📦 파이썬 패키지 설치' && \
    pip install --no-cache-dir \
        GitPython onnx onnxruntime opencv-python-headless tqdm requests \
        scikit-image piexif packaging protobuf scipy einops pandas matplotlib imageio[ffmpeg] pyzbar pillow numba \
        gguf dill insightface ftfy ultralytics timm \
        facelib==0.2.2 mtcnn==0.1.1 facexlib basicsr gfpgan realesrgan \
        diffusers==0.24.0 transformers==4.39.3 huggingface_hub==0.20.3 peft==0.7.1 bitsandbytes==0.42.0.post2 xformers || echo '⚠️ 일부 pip 설치 실패' && \
    echo '📦 sageattention 1.0.6 설치 중...' && \
    pip install sageattention==1.0.6 || echo '⚠️ sageattention 설치 실패'


# A1 폴더 생성 후 자동 커스텀 노드 설치 스크립트 복사
RUN mkdir -p /workspace/A1
COPY init_or_check_nodes.sh /workspace/A1/init_or_check_nodes.sh
RUN chmod +x /workspace/A1/init_or_check_nodes.sh

# Hugging Face 모델 다운로드 스크립트 복사
COPY Hugging_down_a1.sh /workspace/A1/Hugging_down_a1.sh
RUN chmod +x /workspace/A1/Hugging_down_a1.sh

# Framepack_down.sh 스크립트 복사 및 실행 권한 설정
COPY Framepack_down.sh /workspace/A1/Framepack_down.sh
RUN chmod +x /workspace/A1/Framepack_down.sh

# 볼륨 마운트
VOLUME ["/workspace"]

# 포트 설정
EXPOSE 8188
EXPOSE 8888

# 실행 명령어
CMD bash -c "\
echo '🌀 A1(AI는 에이원) : https://www.youtube.com/@A01demort' && \
jupyter lab --ip=0.0.0.0 --port=8888 --allow-root \
--ServerApp.root_dir=/workspace \
--ServerApp.token='' --ServerApp.password='' & \
python -u /workspace/ComfyUI/main.py --listen 0.0.0.0 --port=8188 \
--front-end-version Comfy-Org/ComfyUI_frontend@latest & \
/workspace/A1/init_or_check_nodes.sh && \
wait"
