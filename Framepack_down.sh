#!/bin/bash

# ====================================
# 🧳 Hugging Face API 키 (필요 입력)
# ====================================
HUGGINGFACE_TOKEN="Huggingface_Token_key"

# ====================================
# 🛠️ 사용자 설정값
# ====================================
MAX_PARALLEL=5

# ====================================
# 📂 파일 설정
# ====================================
INPUT_FILE="aria2_downloads.txt"
LOG_FILE="aria2_log.txt"
RESULT_FILE="aria2_result.txt"

# ====================================
# ⏱️ 타이머 시작
# ====================================
start_time=$(date +%s)

# ====================================
# 📦 Aria2 설치 확인
# ====================================
if ! command -v aria2c &> /dev/null; then
    echo "📦 aria2c가 설치되지 않았습니다. 설치를 시작합니다..."
    sudo apt update && sudo apt install -y aria2
    if [ $? -ne 0 ]; then
        echo "❌ aria2 설치 실패. 수동 설치 필요."
        exit 1
    fi
else
    echo "✅ aria2c 설치 확인 완료."
fi

# ====================================
# 🔐 Hugging Face API 키 유효성 검사
# ====================================
TEST_URL="https://huggingface.co/Comfy-Org/sigclip_vision_384/resolve/main/sigclip_vision_patch14_384.safetensors"
echo "🔍 Hugging Face API 키 유효성 검사 중..."

test_response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $HUGGINGFACE_TOKEN" "$TEST_URL")

if [[ "$test_response" == "403" || "$test_response" == "401" ]]; then
    echo -e "\n\033[0;31m🚫 오류: Hugging Face API 키가 유효하지 않습니다! (에러코드: $test_response)\033[0m"
    echo "# 🚫 잘못된 Hugging Face API 키 검지됨 (에러 $test_response)" | tee -a "$RESULT_FILE"
    echo "# 5초 대기 후, 인증 없이 받을 수 있는 파일들부터 다운로드를 시작합니다..." | tee -a "$RESULT_FILE"
    sleep 5
else
    echo "✅ Hugging Face API 키 인증 성공 ($test_response)"
fi

# ====================================
# 📌 다운로드 리스트 (4개 파일)
# ====================================
downloads=(
  # 1. Diffusion 모델
  "https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/FramePackI2V_HY_fp8_e4m3fn.safetensors|/workspace/ComfyUI/models/diffusion_models/FramePackI2V_HY_fp8_e4m3fn.safetensors"

  # 2. CLIP Vision 모델
  "https://huggingface.co/Comfy-Org/sigclip_vision_384/resolve/main/sigclip_vision_patch14_384.safetensors|/workspace/ComfyUI/models/clip_vision/sigclip_vision_patch14_384.safetensors"

  # 3. VAE 모델
  "https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/vae/hunyuan_video_vae_bf16.safetensors|/workspace/ComfyUI/models/vae/hunyuan_video_vae_bf16.safetensors"

  # 4. 텍스트 인코더 모델 - llava
  "https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/text_encoders/llava_llama3_fp16.safetensors|/workspace/ComfyUI/models/text_encoders/llava_llama3_fp16.safetensors"

  # 5. 텍스트 인코더 모델 - clip_l
  "https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/text_encoders/clip_l.safetensors|/workspace/ComfyUI/models/text_encoders/clip_l.safetensors"

  # 6. 텍스트 인코더 모델 - llava (fp8 scaled)
  "https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/text_encoders/llava_llama3_fp8_scaled.safetensors|/workspace/ComfyUI/models/text_encoders/llava_llama3_fp8_scaled.safetensors"
)

# ====================================
# 🧹 초기화
# ====================================
rm -f "$INPUT_FILE" "$LOG_FILE" "$RESULT_FILE"

# ====================================
# 📋 리스트 생성
# ====================================
for item in "${downloads[@]}"; do
  IFS="|" read -r url path <<< "$item"
  if [ -f "$path" ]; then
    echo "[완료] 이미 존재: $path" | tee -a "$RESULT_FILE"
  else
    mkdir -p "$(dirname "$path")"
    echo "$url" >> "$INPUT_FILE"
    echo "  dir=$(dirname "$path")" >> "$INPUT_FILE"
    echo "  out=$(basename "$path")" >> "$INPUT_FILE"
  fi
done

# ====================================
# 🚀 다운로드 시작
# ====================================
if [ -s "$INPUT_FILE" ]; then
  echo -e "\n🚀 다운로드 시작...\n"
  aria2c -x 8 -j "$MAX_PARALLEL" -i "$INPUT_FILE" \
         --console-log-level=notice --summary-interval=1 \
         --header="Authorization: Bearer $HUGGINGFACE_TOKEN" \
         | tee -a "$LOG_FILE"
else
  echo "📂 다운로드할 항목이 없습니다."
fi

# ====================================
# ✅ 결과 반영
# ====================================
total=${#downloads[@]}
success=0
failures=()

for item in "${downloads[@]}"; do
  IFS="|" read -r url path <<< "$item"
  if [ -f "$path" ]; then
    echo "[완료] $path" | tee -a "$RESULT_FILE"
    ((success++))
  else
    echo "[실패] $path" | tee -a "$RESULT_FILE"
    failures+=("$path")
  fi
done

# ====================================
# ⏱️ 소요 시간
# ====================================
end_time=$(date +%s)
duration=$((end_time - start_time))
minutes=$((duration / 60))
seconds=$((duration % 60))

echo -e "\n🕒 총 소요 시간: ${minutes}분 ${seconds}초\n" | tee -a "$RESULT_FILE"

# ====================================
# 📊 요약
# ====================================
if [ "$success" -eq "$total" ]; then
  echo "✅ $success/$total 모든 파일 정상!" | tee -a "$RESULT_FILE"
else
  echo "❌ $success/$total 완료, ${#failures[@]} 실패" | tee -a "$RESULT_FILE"
  echo "🔹 실패 파일 목록:" | tee -a "$RESULT_FILE"
  for fail in "${failures[@]}"; do
    echo " - $fail" | tee -a "$RESULT_FILE"
  done
fi

# ====================================
# ❌ 손상/중단 파일 검사 및 재시도
# ====================================
echo -e "\n🔍 다중 실패(또는 중단) 파일 검사..."
broken_files=()

for item in "${downloads[@]}"; do
  IFS="|" read -r url path <<< "$item"
  if [[ -f "$path" && ! -s "$path" ]] || [[ -f "$path.aria2" ]]; then
    broken_files+=("$path")
  fi
done

if [ "${#broken_files[@]}" -gt 0 ]; then
  echo -e "\n🚨 ${#broken_files[@]}개의 중단/잘못된 파일 발견됨:"
  for bf in "${broken_files[@]}"; do
    echo " - $bf"
  done

  echo -e "\n❓ 자동 삭제 후 재다운로드 하시겠습니까? (Y/N): \c"
  read -r confirm_retry

  if [[ "$confirm_retry" == "Y" || "$confirm_retry" == "y" ]]; then
    echo "🗑️ 삭제 중..."
    for bf in "${broken_files[@]}"; do
      rm -f "$bf" "$bf.aria2"
      echo "삭제됨: $bf"
    done
    echo "♻️ 다시 실행합니다..."
    bash "$0"
    exit 0
  else
    echo "⛔ 수동 처리 위해 종료합니다."
    exit 0
  fi
else
  echo "✅ 모든 파일이 정상적으로 다운로드되었습니다."
fi
