#!/usr/bin/env bash
# Video Technical (VT) Evaluation Script
# Measures low-level visual integrity via DOVER++
set -euo pipefail

INPUT_DIR="${1:-input}"
OUTPUT_DIR="${2:-Output}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "Video Technical (VT) Evaluation"
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
ENV_NAME="t2av-dover"
if ! conda env list | grep -q "^${ENV_NAME} "; then
  echo "Creating conda environment: ${ENV_NAME}"
  conda create -n "${ENV_NAME}" python=3.10 -y
  conda activate "${ENV_NAME}"
  
  # Install dependencies
  pushd "${PROJECT_ROOT}/Objective/Video/DOVER" >/dev/null
  pip install -r requirements.txt
  pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118
  popd >/dev/null
else
  conda activate "${ENV_NAME}"
fi

# Run evaluation
OUTPUT_DIR_ABS="${PROJECT_ROOT}/${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR_ABS}"

pushd "${PROJECT_ROOT}/Objective/Video/DOVER" >/dev/null
python batch_dover.py \
  --input "${PROJECT_ROOT}/${INPUT_DIR}" \
  --output "${OUTPUT_DIR_ABS}/video_technical.json" \
  --config "./dover.yml" \
  --device "cuda"
popd >/dev/null

if [[ -f "${OUTPUT_DIR_ABS}/video_technical.json" ]]; then
  echo "✓ Results saved to: ${OUTPUT_DIR_ABS}/video_technical.json"
else
  echo "✗ No results generated"
  exit 1
fi

conda deactivate
echo "Done: Video Technical evaluation completed"
