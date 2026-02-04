#!/usr/bin/env bash
# Audio-Video Synchronization (DeSync) Evaluation Script
# Measures temporal synchronization via Synchformer
set -euo pipefail

INPUT_DIR="${1:-input}"
OUTPUT_DIR="${2:-Output}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "AV Synchronization (DeSync) Evaluation"
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
ENV_NAME="t2av-synchformer"
SYNCH_DIR="${PROJECT_ROOT}/Objective/Similarity/Synchformer-main"

if ! conda env list | grep -q "^${ENV_NAME} "; then
  echo "Creating conda environment: ${ENV_NAME}"
  
  if [[ -f "${SYNCH_DIR}/conda_env.yml" ]]; then
    conda env create -f "${SYNCH_DIR}/conda_env.yml" -n "${ENV_NAME}"
  else
    conda create -n "${ENV_NAME}" python=3.8 -y
    conda activate "${ENV_NAME}"
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
    pip install opencv-python librosa soundfile scipy einops timm
  fi
else
  conda activate "${ENV_NAME}"
fi

# Run evaluation
OUTPUT_DIR_ABS="${PROJECT_ROOT}/${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR_ABS}"

pushd "${SYNCH_DIR}" >/dev/null
python batch_test_folder.py \
  --folder "${PROJECT_ROOT}/${INPUT_DIR}" \
  --exp_name "24-01-04T16-39-21" \
  --output "${OUTPUT_DIR_ABS}/av_sync.json" \
  --device "cuda:0"
popd >/dev/null

if [[ -f "${OUTPUT_DIR_ABS}/av_sync.json" ]]; then
  echo "✓ Results saved to: ${OUTPUT_DIR_ABS}/av_sync.json"
  echo "  Note: Lower DeSync scores indicate better synchronization"
else
  echo "✗ No results generated"
  exit 1
fi

conda deactivate
echo "Done: AV Synchronization evaluation completed"
