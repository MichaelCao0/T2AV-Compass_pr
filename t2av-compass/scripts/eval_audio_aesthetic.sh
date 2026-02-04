#!/usr/bin/env bash
# Audio Aesthetic (AA) Evaluation Script
# Measures PQ (Perceptual Quality) and CU (Content Usefulness) via AudioBox
# AA is computed as the mean of PQ and CU
set -euo pipefail

INPUT_DIR="${1:-input}"
OUTPUT_DIR="${2:-Output}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "Audio Aesthetic (AA) Evaluation"
echo "=========================================="
echo "Input:  ${INPUT_DIR}"
echo "Output: ${OUTPUT_DIR}"
echo ""

# Check conda
if ! command -v conda >/dev/null 2>&1; then
  echo "ERROR: conda not found. Please install Miniconda/Anaconda first."
  exit 1
fi

CONDA_BASE="$(conda info --base)"
source "${CONDA_BASE}/etc/profile.d/conda.sh"

# Create conda environment if not exists
ENV_NAME="t2av-audiobox"
if ! conda env list | grep -q "^${ENV_NAME} "; then
  echo "Creating conda environment: ${ENV_NAME}"
  conda create -n "${ENV_NAME}" python=3.10 -y
  conda activate "${ENV_NAME}"
  
  # Install dependencies
  pushd "${PROJECT_ROOT}/Objective/Audio/audiobox-aesthetics" >/dev/null
  pip install -e .
  pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu118
  popd >/dev/null
else
  conda activate "${ENV_NAME}"
fi

# Step 1: Extract audio from videos
OUTPUT_DIR_ABS="${PROJECT_ROOT}/${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR_ABS}/audio_wav"

echo "Step 1: Extracting audio from videos..."
bash "${PROJECT_ROOT}/Objective/Audio/audiobox-aesthetics/extract_audio.sh" \
  "${PROJECT_ROOT}/${INPUT_DIR}" \
  "${OUTPUT_DIR_ABS}/audio_wav"

if [[ $(find "${OUTPUT_DIR_ABS}/audio_wav" -type f -name "*.wav" | wc -l) -eq 0 ]]; then
  echo "✗ No audio files extracted"
  exit 1
fi

# Step 2: Run AudioBox aesthetics
echo "Step 2: Computing AudioBox aesthetics (PQ, CU)..."
python "${PROJECT_ROOT}/scripts/run_audiobox_batch.py" \
  --audio_dir "${OUTPUT_DIR_ABS}/audio_wav" \
  --output "${OUTPUT_DIR_ABS}/audio_aesthetic.json"

if [[ -f "${OUTPUT_DIR_ABS}/audio_aesthetic.json" ]]; then
  echo "✓ Results saved to: ${OUTPUT_DIR_ABS}/audio_aesthetic.json"
  echo "  Note: AA = (PQ + CU) / 2"
else
  echo "✗ No results generated"
  exit 1
fi

conda deactivate
echo "Done: Audio Aesthetic evaluation completed"
