#!/usr/bin/env bash
# Complete T2AV-Compass Evaluation Pipeline
# Runs all objective metrics for Text-to-Audio-Video generation
set -euo pipefail

# Default arguments
INPUT_DIR="${1:-input}"
PROMPTS_JSON="${2:-Data/prompts.json}"
OUTPUT_DIR="${3:-Output}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=============================================="
echo "T2AV-Compass: Complete Evaluation Pipeline"
echo "=============================================="
echo "Input Directory:  ${INPUT_DIR}"
echo "Prompts JSON:     ${PROMPTS_JSON}"
echo "Output Directory: ${OUTPUT_DIR}"
echo "Project Root:     ${PROJECT_ROOT}"
echo ""
echo "This will run all objective metrics:"
echo "  1. Video Quality:    VT (DOVER), VA (Aesthetic)"
echo "  2. Audio Quality:    AA (AudioBox), SQ (NISQA)"
echo "  3. Cross-modal:      T-V, T-A, A-V (semantic), DeSync (temporal), LS (lip-sync)"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Verify input directory exists
if [[ ! -d "${PROJECT_ROOT}/${INPUT_DIR}" ]]; then
  echo "ERROR: Input directory not found: ${PROJECT_ROOT}/${INPUT_DIR}"
  exit 1
fi

# Verify prompts file exists
if [[ ! -f "${PROJECT_ROOT}/${PROMPTS_JSON}" ]]; then
  echo "ERROR: Prompts file not found: ${PROJECT_ROOT}/${PROMPTS_JSON}"
  exit 1
fi

# Create output directory
OUTPUT_DIR_ABS="${PROJECT_ROOT}/${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR_ABS}"

# Start timestamp
START_TIME=$(date +%s)
echo "Started at: $(date)"
echo ""

# ========================================
# VIDEO QUALITY METRICS
# ========================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 1/4: Video Quality Metrics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "[1/8] Video Aesthetic (VA)..."
bash "${SCRIPT_DIR}/eval_video_aesthetic.sh" "${INPUT_DIR}" "${OUTPUT_DIR}" || {
  echo "WARNING: Video Aesthetic evaluation failed"
}

echo ""
echo "[2/8] Video Technical (VT)..."
bash "${SCRIPT_DIR}/eval_video_technical.sh" "${INPUT_DIR}" "${OUTPUT_DIR}" || {
  echo "WARNING: Video Technical evaluation failed"
}

# ========================================
# AUDIO QUALITY METRICS
# ========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 2/4: Audio Quality Metrics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "[3/8] Audio Aesthetic (AA = mean of PQ & CU)..."
bash "${SCRIPT_DIR}/eval_audio_aesthetic.sh" "${INPUT_DIR}" "${OUTPUT_DIR}" || {
  echo "WARNING: Audio Aesthetic evaluation failed"
}

echo ""
echo "[4/8] Speech Quality (SQ via NISQA)..."
bash "${SCRIPT_DIR}/eval_speech_quality.sh" "${INPUT_DIR}" "${OUTPUT_DIR}" || {
  echo "WARNING: Speech Quality evaluation failed"
}

# ========================================
# CROSS-MODAL ALIGNMENT METRICS
# ========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 3/4: Cross-Modal Alignment Metrics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "[5/8] Text-Video Alignment (T-V)..."
bash "${SCRIPT_DIR}/eval_text_video_alignment.sh" "${INPUT_DIR}" "${PROMPTS_JSON}" "${OUTPUT_DIR}" || {
  echo "WARNING: Text-Video alignment evaluation failed"
}

echo ""
echo "[6/8] Text-Audio Alignment (T-A)..."
bash "${SCRIPT_DIR}/eval_text_audio_alignment.sh" "${INPUT_DIR}" "${PROMPTS_JSON}" "${OUTPUT_DIR}" || {
  echo "WARNING: Text-Audio alignment evaluation failed"
}

echo ""
echo "[7/9] Audio-Video Alignment (A-V)..."
bash "${SCRIPT_DIR}/eval_audio_video_alignment.sh" "${INPUT_DIR}" "${OUTPUT_DIR}" || {
  echo "WARNING: Audio-Video alignment evaluation failed"
}

echo ""
echo "[8/10] Audio-Video Synchronization (DeSync)..."
bash "${SCRIPT_DIR}/eval_av_sync.sh" "${INPUT_DIR}" "${OUTPUT_DIR}" || {
  echo "WARNING: AV Sync evaluation failed"
}

echo ""
echo "[9/10] Lip-Sync Quality (LatentSync)..."
bash "${SCRIPT_DIR}/eval_lipsync.sh" "${INPUT_DIR}" "${OUTPUT_DIR}" || {
  echo "WARNING: LatentSync evaluation failed (may be no talking faces)"
}

# ========================================
# SUMMARY
# ========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "PHASE 4/4: Generating Summary Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# List all generated JSON files
echo ""
echo "Generated result files:"
find "${OUTPUT_DIR_ABS}" -maxdepth 1 -name "*.json" -type f | sort | while read -r file; do
  echo "  ✓ $(basename "${file}")"
done

# Create summary
SUMMARY_FILE="${OUTPUT_DIR_ABS}/evaluation_summary.json"
python3 - <<EOF
import json
from pathlib import Path
from datetime import datetime

output_dir = Path("${OUTPUT_DIR_ABS}")
summary = {
    "timestamp": datetime.now().isoformat(),
    "input_dir": "${INPUT_DIR}",
    "prompts_file": "${PROMPTS_JSON}",
    "metrics": {}
}

# Collect all metric results
for json_file in output_dir.glob("*.json"):
    if json_file.name == "evaluation_summary.json":
        continue
    
    with open(json_file, 'r') as f:
        data = json.load(f)
        metric_name = json_file.stem
        
        # Extract summary statistics if available
        if "summary" in data:
            summary["metrics"][metric_name] = data["summary"]
        elif "results" in data and isinstance(data["results"], list):
            summary["metrics"][metric_name] = {
                "total_samples": len(data["results"])
            }

# Save summary
with open("${SUMMARY_FILE}", 'w') as f:
    json.dump(summary, f, indent=2)

print(f"✓ Summary saved to: ${SUMMARY_FILE}")
EOF

# End timestamp
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Evaluation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Completed at: $(date)"
echo "Total time:   ${MINUTES}m ${SECONDS}s"
echo "Results dir:  ${OUTPUT_DIR_ABS}"
echo ""
echo "Next steps:"
echo "  1. Check individual metric files: ${OUTPUT_DIR}/*.json"
echo "  2. View summary: ${OUTPUT_DIR}/evaluation_summary.json"
echo "  3. Run MLLM-as-a-Judge for subjective metrics (see README)"
echo ""
