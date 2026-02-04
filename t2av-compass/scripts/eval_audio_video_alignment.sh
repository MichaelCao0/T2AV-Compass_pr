#!/usr/bin/env bash
# Audio-Video (A-V) Alignment Evaluation Script
# Measures semantic alignment between audio and video via ImageBind (independent of text)
set -euo pipefail

INPUT_DIR="${1:-input}"
OUTPUT_DIR="${2:-Output}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "Audio-Video (A-V) Alignment Evaluation"
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
echo "Computing Audio-Video alignment..."
pushd "${IMAGEBIND_DIR}" >/dev/null

# Create a Python script to compute A-V alignment
python -c "
import torch
import json
from pathlib import Path
from imagebind import data
from imagebind.models import imagebind_model
from imagebind.models.imagebind_model import ModalityType

device = 'cuda:0' if torch.cuda.is_available() else 'cpu'

# Load model
model = imagebind_model.imagebind_huge(pretrained=True)
model.eval()
model.to(device)

input_dir = Path('${PROJECT_ROOT}/${INPUT_DIR}')
audio_dir = Path('${OUTPUT_DIR_ABS}/audio_wav')

# Find all video files
video_exts = {'.mp4', '.avi', '.mov', '.mkv', '.webm'}
video_files = []
for ext in video_exts:
    video_files.extend(input_dir.glob(f'*{ext}'))
    video_files.extend(input_dir.glob(f'*{ext.upper()}'))
video_files = sorted(set(video_files))

results = []
scores = []

print(f'Processing {len(video_files)} videos...')

for video_path in video_files:
    video_name = video_path.stem
    audio_path = audio_dir / f'{video_name}.wav'
    
    if not audio_path.exists():
        print(f'Warning: Audio not found for {video_name}')
        continue
    
    try:
        # Load video and audio
        inputs = {
            ModalityType.VISION: data.load_and_transform_video_data([str(video_path)], device),
            ModalityType.AUDIO: data.load_and_transform_audio_data([str(audio_path)], device)
        }
        
        with torch.no_grad():
            embeddings = model(inputs)
        
        # Compute similarity
        vision_emb = embeddings[ModalityType.VISION]
        audio_emb = embeddings[ModalityType.AUDIO]
        
        # Normalize
        vision_emb = vision_emb / vision_emb.norm(dim=-1, keepdim=True)
        audio_emb = audio_emb / audio_emb.norm(dim=-1, keepdim=True)
        
        # Compute cosine similarity
        similarity = (vision_emb @ audio_emb.T).squeeze().item()
        
        results.append({
            'file': str(video_path),
            'filename': video_path.name,
            'audio_file': str(audio_path),
            'av_alignment': float(similarity)
        })
        scores.append(similarity)
        
        print(f'  {video_path.name}: {similarity:.4f}')
        
    except Exception as e:
        print(f'Error processing {video_name}: {e}')
        continue

# Save results
output = {
    'metric': 'audio_video_alignment',
    'summary': {
        'mean_av_alignment': float(sum(scores) / len(scores)) if scores else 0.0,
        'total_samples': len(results)
    },
    'results': results
}

output_path = Path('${OUTPUT_DIR_ABS}/audio_video_alignment.json')
with open(output_path, 'w') as f:
    json.dump(output, f, indent=2)

print(f'Mean A-V Alignment: {output[\"summary\"][\"mean_av_alignment\"]:.4f}')
print(f'✓ Results saved to: {output_path}')
"

popd >/dev/null

if [[ -f "${OUTPUT_DIR_ABS}/audio_video_alignment.json" ]]; then
  echo "✓ Results saved to: ${OUTPUT_DIR_ABS}/audio_video_alignment.json"
else
  echo "✗ No results generated"
  exit 1
fi

conda deactivate
echo "Done: Audio-Video alignment evaluation completed"
