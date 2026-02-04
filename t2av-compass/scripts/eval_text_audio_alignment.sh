#!/usr/bin/env bash
# Text-Audio (T-A) Alignment Evaluation Script
# Measures semantic alignment between text prompts and audio via ImageBind
set -euo pipefail

INPUT_DIR="${1:-input}"
PROMPTS_JSON="${2:-Data/prompts.json}"
OUTPUT_DIR="${3:-Output}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "Text-Audio (T-A) Alignment Evaluation"
echo "=========================================="
echo "Input:   ${INPUT_DIR}"
echo "Prompts: ${PROMPTS_JSON}"
echo "Output:  ${OUTPUT_DIR}"
echo ""

# Check conda
if ! command -v conda >/dev/null 2>&1; then
  echo "ERROR: conda not found. Please install Miniconda/Anaconda first."
  exit 1
fi

CONDA_BASE="$(conda info --base)"
source "${CONDA_BASE}/etc/profile.d/conda.sh"

# Create conda environment if not exists
ENV_NAME="t2av-imagebind"
IMAGEBIND_DIR="${PROJECT_ROOT}/Objective/Similarity/ImageBind-main"

if ! conda env list | grep -q "^${ENV_NAME} "; then
  echo "Creating conda environment: ${ENV_NAME}"
  conda create -n "${ENV_NAME}" python=3.10 -y
  conda activate "${ENV_NAME}"
  
  # Install dependencies
  pushd "${IMAGEBIND_DIR}" >/dev/null
  pip install -r requirements.txt
  pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
  popd >/dev/null
else
  conda activate "${ENV_NAME}"
fi

# Extract audio if needed
OUTPUT_DIR_ABS="${PROJECT_ROOT}/${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR_ABS}/audio_wav"

if [[ $(find "${OUTPUT_DIR_ABS}/audio_wav" -type f -name "*.wav" | wc -l) -eq 0 ]]; then
  echo "Extracting audio from videos..."
  bash "${PROJECT_ROOT}/Objective/Audio/audiobox-aesthetics/extract_audio.sh" \
    "${PROJECT_ROOT}/${INPUT_DIR}" \
    "${OUTPUT_DIR_ABS}/audio_wav"
fi

# Run evaluation
pushd "${IMAGEBIND_DIR}" >/dev/null
python batch_inference_audio_text.py \
  --json_file "${PROJECT_ROOT}/${PROMPTS_JSON}" \
  --audio_dir "${OUTPUT_DIR_ABS}/audio_wav" \
  --output_file "${OUTPUT_DIR_ABS}/text_audio_alignment.json" \
  --device "cuda:0"
popd >/dev/null

if [[ -f "${OUTPUT_DIR_ABS}/text_audio_alignment.json" ]]; then
  echo "✓ Results saved to: ${OUTPUT_DIR_ABS}/text_audio_alignment.json"
else
  echo "✗ No results generated"
  exit 1
fi

conda deactivate
echo "Done: Text-Audio alignment evaluation completed"
