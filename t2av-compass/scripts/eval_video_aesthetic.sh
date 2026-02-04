#!/usr/bin/env bash
# Video Aesthetic (VA) Evaluation Script
# Measures high-level perceptual attributes via LAION-Aesthetic V2.5
set -euo pipefail

INPUT_DIR="${1:-input}"
OUTPUT_DIR="${2:-Output}"
NUM_FRAMES="${3:-10}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "Video Aesthetic (VA) Evaluation"
echo "=========================================="
echo "Input:  ${INPUT_DIR}"
echo "Output: ${OUTPUT_DIR}"
echo "Frames: ${NUM_FRAMES}"
echo ""

# Check conda
if ! command -v conda >/dev/null 2>&1; then
  echo "ERROR: conda not found. Please install Miniconda/Anaconda first."
  exit 1
fi

CONDA_BASE="$(conda info --base)"
source "${CONDA_BASE}/etc/profile.d/conda.sh"

# Create conda environment if not exists
ENV_NAME="t2av-aesthetic"
if ! conda env list | grep -q "^${ENV_NAME} "; then
  echo "Creating conda environment: ${ENV_NAME}"
  conda create -n "${ENV_NAME}" python=3.10 -y
  conda activate "${ENV_NAME}"
  
  # Install dependencies
  pushd "${PROJECT_ROOT}/Objective/Video/aesthetic-predictor-v2-5" >/dev/null
  pip install -e .
  pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118
  popd >/dev/null
else
  conda activate "${ENV_NAME}"
fi

# Run evaluation
OUTPUT_DIR_ABS="${PROJECT_ROOT}/${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR_ABS}/video_aesthetic"

pushd "${PROJECT_ROOT}/Objective/Video/aesthetic-predictor-v2-5" >/dev/null
python batch_inference.py \
  --video_dir "${PROJECT_ROOT}/${INPUT_DIR}" \
  --output_dir "${OUTPUT_DIR_ABS}/video_aesthetic" \
  --num_frames "${NUM_FRAMES}"
popd >/dev/null

# Copy results
if [[ -f "${OUTPUT_DIR_ABS}/video_aesthetic/results.json" ]]; then
  cp "${OUTPUT_DIR_ABS}/video_aesthetic/results.json" "${OUTPUT_DIR_ABS}/video_aesthetic.json"
  echo "✓ Results saved to: ${OUTPUT_DIR_ABS}/video_aesthetic.json"
else
  echo "✗ No results generated"
  exit 1
fi

conda deactivate
echo "Done: Video Aesthetic evaluation completed"
