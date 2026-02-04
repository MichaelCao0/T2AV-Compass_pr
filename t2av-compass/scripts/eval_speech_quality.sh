#!/usr/bin/env bash
# Speech Quality (SQ) Evaluation Script
# Measures speech quality via NISQA
set -euo pipefail

INPUT_DIR="${1:-input}"
OUTPUT_DIR="${2:-Output}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "Speech Quality (SQ) Evaluation"
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
ENV_NAME="t2av-nisqa"
NISQA_DIR="${PROJECT_ROOT}/Objective/Audio/NISQA"

if ! conda env list | grep -q "^${ENV_NAME} "; then
  echo "Creating conda environment: ${ENV_NAME}"
  
  if [[ -f "${NISQA_DIR}/env.yml" ]]; then
    conda env create -f "${NISQA_DIR}/env.yml" -n "${ENV_NAME}"
  else
    conda create -n "${ENV_NAME}" python=3.8 -y
    conda activate "${ENV_NAME}"
    pip install torch torchaudio librosa pandas
  fi
else
  conda activate "${ENV_NAME}"
fi

# Extract audio if not already done
OUTPUT_DIR_ABS="${PROJECT_ROOT}/${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR_ABS}/audio_wav"

if [[ $(find "${OUTPUT_DIR_ABS}/audio_wav" -type f -name "*.wav" | wc -l) -eq 0 ]]; then
  echo "Extracting audio from videos..."
  bash "${PROJECT_ROOT}/Objective/Audio/audiobox-aesthetics/extract_audio.sh" \
    "${PROJECT_ROOT}/${INPUT_DIR}" \
    "${OUTPUT_DIR_ABS}/audio_wav"
fi

# Run NISQA prediction
echo "Running NISQA speech quality prediction..."
pushd "${NISQA_DIR}" >/dev/null

# Create file list
find "${OUTPUT_DIR_ABS}/audio_wav" -name "*.wav" > "${OUTPUT_DIR_ABS}/audio_list.txt"

python run_predict.py \
  --mode predict_file \
  --pretrained_model weights/nisqa.tar \
  --deg "${OUTPUT_DIR_ABS}/audio_list.txt" \
  --output_dir "${OUTPUT_DIR_ABS}/nisqa_output"

popd >/dev/null

# Convert to JSON format
if [[ -f "${OUTPUT_DIR_ABS}/nisqa_output/NISQA_results.csv" ]]; then
  python -c "
import pandas as pd
import json
df = pd.read_csv('${OUTPUT_DIR_ABS}/nisqa_output/NISQA_results.csv')
results = df.to_dict('records')
output = {
    'metric': 'nisqa_speech_quality',
    'summary': {'SQ_mean': float(df['mos_pred'].mean())} if 'mos_pred' in df.columns else {},
    'results': results
}
with open('${OUTPUT_DIR_ABS}/speech_quality.json', 'w') as f:
    json.dump(output, f, indent=2)
print('✓ Results saved to: ${OUTPUT_DIR_ABS}/speech_quality.json')
"
else
  echo "✗ No results generated"
  exit 1
fi

conda deactivate
echo "Done: Speech Quality evaluation completed"
