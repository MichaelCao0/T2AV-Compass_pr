#!/usr/bin/env bash
# LatentSync (LS) Evaluation Script
# Measures lip-sync quality for talking-face scenarios
set -euo pipefail

INPUT_DIR="${1:-input}"
OUTPUT_DIR="${2:-Output}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "LatentSync (LS) Evaluation"
echo "=========================================="
echo "Input:  ${INPUT_DIR}"
echo "Output: ${OUTPUT_DIR}"
echo ""
echo "Note: This metric evaluates lip-sync quality"
echo "      for videos with talking faces."
echo ""

# Check conda
if ! command -v conda >/dev/null 2>&1; then
  echo "ERROR: conda not found. Please install Miniconda/Anaconda first."
  exit 1
fi

CONDA_BASE="$(conda info --base)"
source "${CONDA_BASE}/etc/profile.d/conda.sh"

# Create conda environment if not exists
ENV_NAME="t2av-latentsync"
LATENTSYNC_DIR="${PROJECT_ROOT}/Objective/Similarity/LatentSync"

if ! conda env list | grep -q "^${ENV_NAME} "; then
  echo "Creating conda environment: ${ENV_NAME}"
  
  pushd "${LATENTSYNC_DIR}" >/dev/null
  
  # Create environment from setup script
  conda create -y -n "${ENV_NAME}" python=3.10
  conda activate "${ENV_NAME}"
  
  # Install dependencies
  pip install torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 --index-url https://download.pytorch.org/whl/cu118
  pip install -r requirements.txt
  
  # Download models if not exist
  if [[ ! -f "checkpoints/auxiliary/syncnet_v2.model" ]]; then
    echo "Downloading SyncNet model..."
    pip install huggingface_hub
    huggingface-cli download ByteDance/LatentSync-1.6 auxiliary/syncnet_v2.model --local-dir checkpoints
  fi
  
  popd >/dev/null
else
  conda activate "${ENV_NAME}"
fi

# Run evaluation
OUTPUT_DIR_ABS="${PROJECT_ROOT}/${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR_ABS}"

echo "Running LatentSync lip-sync evaluation..."
echo "This may take a while for videos with multiple talking faces..."

pushd "${LATENTSYNC_DIR}" >/dev/null

python batch_inference_lipsync.py \
  --video_dir "${PROJECT_ROOT}/${INPUT_DIR}" \
  --model_path "checkpoints/auxiliary/syncnet_v2.model" \
  --output_file "${OUTPUT_DIR_ABS}/lipsync.json" \
  --device "cuda" \
  --temp_dir "${OUTPUT_DIR_ABS}/temp_lipsync"

popd >/dev/null

if [[ -f "${OUTPUT_DIR_ABS}/lipsync.json" ]]; then
  echo "✓ Results saved to: ${OUTPUT_DIR_ABS}/lipsync.json"
  
  # Display summary
  python -c "
import json
with open('${OUTPUT_DIR_ABS}/lipsync.json', 'r') as f:
    data = json.load(f)
    summary = data.get('summary', {})
    print('\n=== LatentSync Summary ===')
    print(f\"Total videos:       {summary.get('total_videos', 0)}\")
    print(f\"Successful:         {summary.get('successful_videos', 0)}\")
    print(f\"Failed:             {summary.get('failed_videos', 0)}\")
    if 'sync_confidence' in summary:
        print(f\"Avg Sync Confidence: {summary['sync_confidence'].get('mean', 0):.4f}\")
    if 'av_offset' in summary:
        print(f\"Avg AV Offset:       {summary['av_offset'].get('mean', 0):.4f} frames\")
" || true

else
  echo "✗ No results generated"
  exit 1
fi

conda deactivate
echo "Done: LatentSync evaluation completed"
