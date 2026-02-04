# T2AV-Compass: 面向文本到音视频生成的统一评测基准

[![Project Page](https://img.shields.io/badge/Project-Page-blue)](https://nju-link.github.io/T2AV-Compass/)
[![Dataset](https://img.shields.io/badge/🤗-Dataset-yellow)](https://huggingface.co/datasets/NJU-LINK/T2AV-Compass)
[![arXiv](https://img.shields.io/badge/arXiv-Paper-red)](https://arxiv.org/abs/2512.21094)

> English version: [README.md](README.md)

## 📖 摘要

**T2AV-Compass** 是一个面向 **Text-to-Audio-Video (T2AV)** 生成的统一评测基准，旨在同时覆盖：单模态质量（视频/音频）、跨模态对齐与同步、复杂指令跟随，以及感知真实感与物理合理性。

文本到音视频（T2AV）生成旨在从自然语言合成时间连贯的视频和语义同步的音频，但其评估仍然碎片化，通常依赖于单模态指标或范围狭窄的基准，无法捕捉复杂提示下的跨模态对齐、指令跟随和感知真实性。

本仓库包含：**500 条 taxonomy-driven 构建的复杂提示词**，以及用于 **MLLM-as-a-Judge** 的细粒度 checklist。

## 🌟 主要特点

- **Taxonomy-Driven 高复杂度基准**：500 条语义密集的提示词，通过分类驱动的策划和视频反演的混合管道合成。针对现有评估中经常被忽视的细粒度视听约束，如画外音和物理因果关系。

- **统一双层评估框架**：
  - **客观评估**：视频质量（VT, VA）、音频质量（AA, SQ）、跨模态对齐（T-A, T-V, A-V, DeSync, LatentSync）
  - **主观评估（MLLM-as-a-Judge）**：基于 checklist 的可解释评估，覆盖 **指令跟随** 和 **感知真实性**

- **广泛基准测试**：系统评估了 11 个最先进的 T2AV 系统，包括 Veo-3.1、Sora-2、Kling-2.6、Wan-2.5/2.6、Seedance-1.5、PixVerse-V5.5、Ovi-1.1、JavisDiT 以及组合管道。

## 📊 评估指标

### 客观指标

| 类别 | 指标 | 描述 |
|------|------|------|
| **视频质量** | VT (Video Technological) | 通过 DOVER++ 评估底层视觉完整性 |
| | VA (Video Aesthetic) | 通过 LAION-Aesthetic V2.5 评估高层感知属性 |
| **音频质量** | AA (Audio Aesthetic) | PQ 与 CU 的均值（感知质量与内容有用性） |
| | SQ (Speech Quality) | 基于 NISQA 的语音质量 |
| **跨模态对齐** | T-A | 通过 ImageBind 的文本-音频对齐 |
| | T-V | 通过 ImageBind 的文本-视频对齐 |
| | A-V | 通过 ImageBind 的音频-视频对齐 |
| | DS (DeSync) | 时间同步误差（越低越好） |
| | LS (LatentSync) | 说话人脸场景的唇形同步质量 |

### 主观指标（MLLM-as-a-Judge）

**指令跟随 (IF)** - 7 个维度，17 个子维度：
- **Attribute（属性）**：外观、数量
- **Dynamics（动态）**：运动、交互、变换、镜头运动
- **Cinematography（摄影）**：光照、构图、调色
- **Aesthetics（美学）**：风格、氛围
- **Relations（关系）**：空间、逻辑
- **World Knowledge（世界知识）**：事实知识
- **Sound（声音）**：音效、语音、音乐

**真实性** - 5 个指标：
- **视频**：MSS（运动平滑度）、OIS（物体完整性）、TCS（时间连贯性）
- **音频**：AAS（声学伪影）、MTC（材质-音色一致性）

## 📦 数据文件

- `prompts_with_checklist.json`：核心 benchmark 数据（500 条提示词 + checklist）

## 🧩 数据格式

每个样本是一个 JSON object，核心字段如下：

| 字段 | 类型 | 说明 |
|------|------|------|
| `index` | int | 样本编号（1~500） |
| `source` | str | 来源标识（如 `LMArena`、`RealVideo`、`VidProM`、`Kling`、`Shot2Story`） |
| `subject_matter` | str | 主题/题材 |
| `core_subject` | list[str] | 核心主体类别（People/Objects/Animals…） |
| `event_scenario` | list[str] | 场景类别（Urban/Living/Natural/Virtual…） |
| `sound_type` | list[str] | 声音类别（Ambient/Musical/Speech…） |
| `camera_movement` | list[str] | 镜头运动（Static/Translation/Zoom…） |
| `prompt` | str | **整合提示词**（视觉+声音+语音等混合描述） |
| `video_prompt` | str | 仅视觉描述（便于视频端模型输入） |
| `audio_prompt` | str | 非语音音频描述（可为空字符串） |
| `speech_prompt` | list[object] | 结构化语音，元素含 `speaker`/`description`/`text` |
| `video` | str | 参考视频路径（若有；无则为空字符串） |
| `checklist_info` | object | MLLM-as-a-Judge 用的 checklist |

## 🧠 模型适配

- **端到端 T2AV 模型**（如 Veo、Kling）：直接用 `prompt`
- **两阶段/分模块系统**：
  - 视频模型：`video_prompt`
  - 音频模型：`audio_prompt`
  - TTS/语音：`speech_prompt`

---

## 🔧 客观评测：环境配置与使用

客观指标（VT、VA、AA、SQ、T-V、T-A、A-V、DeSync、LatentSync 等）的评测代码位于 **`t2av-compass/`** 目录。详细说明见 [readme.md](readme.md)，此处为简要步骤。

### 环境要求

- **Conda**（Miniconda 或 Anaconda）
- **ffmpeg**（音频抽取与 Synchformer 预处理）
- **NVIDIA GPU + CUDA**（推荐）

### 目录结构

```
T2AV-Compass/
├── t2av-compass/           # 评测代码根目录（以下命令均在此目录执行）
│   ├── scripts/            # batch_eval_all.sh、run_audiobox_batch.py
│   ├── Objective/          # 客观指标实现（DOVER、Aesthetic、AudioBox、ImageBind、Synchformer 等）
│   ├── Subjective/         # MLLM-as-a-Judge 主观评测
│   ├── Data/               # 示例 prompts.json
│   ├── input/              # 放置待评测视频（如 1.mp4、2.mp4）
│   └── Output/             # 评测结果 JSON 输出
├── data/                   # 基准数据 prompts_with_checklist.json
└── readme.md               # 客观评测完整说明（英文）
```

### 一键批量评测

在 **`t2av-compass`** 目录下执行：

```bash
cd t2av-compass
bash scripts/batch_eval_all.sh input Data/prompts.json Output
```

- `input`：视频所在目录
- `Data/prompts.json`：包含 `video_prompt`、`audio_prompt` 的提示词文件（可与 `data/prompts_with_checklist.json` 格式兼容或转换）
- `Output`：结果输出目录

### 按指标配置 Conda 环境

每个客观指标使用**独立 conda 环境**以避免依赖冲突。需创建的环境名称：

- `t2av-aesthetic` — 视频美学（Aesthetic Predictor V2.5）
- `t2av-dover` — 视频技术质量（DOVER）
- `t2av-audiobox` — 音频质量（AudioBox Aesthetics）
- `t2av-imagebind-vt` — 视频–文本相似度（ImageBind）
- `t2av-imagebind-at` — 音频–文本相似度（ImageBind）
- `t2av-synchformer` — 音视频同步（Synchformer）

各环境的创建命令、依赖安装及模型权重下载见 **[readme.md](readme.md)** 第 4 节。

### 简要检查清单

```bash
cd t2av-compass
# 1) 将待评测视频放入 input/
# 2) 准备 Data/prompts.json 或 input/prompts.json（含 video_prompt、audio_prompt）
# 3) 按 readme.md 创建各 conda 环境并下载所需模型权重
# 4) 运行：
bash scripts/batch_eval_all.sh input Data/prompts.json Output
```

---

## 🚀 快速开始

### 环境要求

- **操作系统**: Linux (推荐 Ubuntu 18.04+) 或 macOS
- **GPU**: NVIDIA GPU，支持 CUDA（建议 16GB+ 显存）
- **CUDA**: 版本 11.8 或更高
- **Conda**: 安装 Miniconda 或 Anaconda
- **Python**: 3.8 - 3.10
- **FFmpeg**: 用于音频提取

```bash
# 安装 FFmpeg (Ubuntu/Debian)
sudo apt-get update && sudo apt-get install -y ffmpeg

# 安装 FFmpeg (macOS)
brew install ffmpeg
```

### 安装步骤

1. **克隆仓库**

```bash
git clone https://github.com/NJU-LINK/T2AV-Compass.git
cd T2AV-Compass
```

2. **准备数据**

组织你生成的视频和对应的提示词：

```
T2AV-Compass/
├── input/                    # 你生成的视频
│   ├── video_001.mp4
│   ├── video_002.mp4
│   └── ...
├── Data/
│   └── prompts.json         # 对应的提示词
└── t2av-compass/            # 评测代码
```

`prompts.json` 格式示例：

```json
[
  {
    "index": 1,
    "prompt": "一个人在公园散步，有鸟鸣声",
    "video_prompt": "一个人在公园散步",
    "audio_prompt": "公园里的鸟鸣声",
    "speech_prompt": []
  }
]
```

### 使用方法

#### 方式一：运行完整评测（所有指标）

一次性运行所有客观指标：

```bash
cd t2av-compass
bash scripts/eval_all_metrics.sh input Data/prompts.json Output
```

这将评测：
- **视频质量**: VT（技术质量）、VA（美学质量）
- **音频质量**: AA（音频美学 = PQ 与 CU 的均值）、SQ（语音质量，使用 NISQA）
- **跨模态对齐**: T-V（文本-视频）、T-A（文本-音频）、A-V（音频-视频语义对齐）、DeSync（音视频时间同步）、LS（说话人脸的唇形同步）

结果将保存在 `Output/` 目录下的 JSON 文件中。

#### 方式二：运行单个指标

独立评测特定指标：

```bash
# 视频美学 (VA)
bash scripts/eval_video_aesthetic.sh input Output

# 视频技术质量 (VT) 
bash scripts/eval_video_technical.sh input Output

# 音频美学 (AA = PQ 与 CU 的均值)
bash scripts/eval_audio_aesthetic.sh input Output

# 语音质量 (SQ，使用 NISQA)
bash scripts/eval_speech_quality.sh input Output

# 文本-视频对齐 (T-V)
bash scripts/eval_text_video_alignment.sh input Data/prompts.json Output

# 文本-音频对齐 (T-A)
bash scripts/eval_text_audio_alignment.sh input Data/prompts.json Output

# 音频-视频对齐 (A-V)
bash scripts/eval_audio_video_alignment.sh input Output

# 音视频同步 (DeSync)
bash scripts/eval_av_sync.sh input Output

# 唇形同步质量 (LatentSync) - 用于有说话人脸的视频
bash scripts/eval_lipsync.sh input Output
```

每个脚本会：
- 首次运行时自动创建所需的 conda 环境
- 安装必要的依赖包
- 执行评测
- 将结果保存为 JSON 文件

#### 环境管理

脚本会自动为每个指标创建独立的 conda 环境，避免依赖冲突：

- `t2av-aesthetic`: 视频美学质量
- `t2av-dover`: 视频技术质量
- `t2av-audiobox`: 音频美学质量
- `t2av-nisqa`: 语音质量
- `t2av-imagebind`: 跨模态对齐
- `t2av-synchformer`: 音视频同步

手动激活环境：

```bash
conda activate t2av-aesthetic
```

### 输出格式

所有指标输出统一的 JSON 格式：

```json
{
  "metric": "指标名称",
  "summary": {
    "mean_score": 0.85,
    "...": "..."
  },
  "results": [
    {
      "file": "input/video_001.mp4",
      "score": 0.87,
      "...": "..."
    }
  ]
}
```

### 示例工作流

```python
import json

# 1. 加载提示词
with open("prompts_with_checklist.json", "r", encoding="utf-8") as f:
    data = json.load(f)

item = data[0]
print(f"提示词: {item['prompt'][:200]}...")
print(f"视频提示词: {item['video_prompt'][:200]}...")
print(f"音频提示词: {item['audio_prompt']}")
print(f"语音提示词: {item['speech_prompt']}")
print(f"Checklist 维度: {list(item['checklist_info'].keys())}")

# 2. 运行评测后，加载结果
with open("Output/evaluation_summary.json", "r") as f:
    summary = json.load(f)
    print(f"评测完成时间: {summary['timestamp']}")
    print(f"指标: {list(summary['metrics'].keys())}")
```

## 📊 主观评测（MLLM-as-a-Judge）

使用 MLLM 评测脚本进行主观指标评测（指令跟随和真实感）：

```bash
cd t2av-compass/Subjective

# 评测指令跟随能力
python eval_checklist.py \
  --video_dir ../input \
  --prompts_file ../Data/prompts.json \
  --output_file ../Output/instruction_following.json

# 评测真实感
python eval_realism.py \
  --video_dir ../input \
  --output_file ../Output/realism.json
```

详细说明请参考 [主观评测指南](t2av-compass/Subjective/README.md)。

## 📈 引用

如果该工作对你的研究有帮助，欢迎引用：

```bibtex
@misc{cao2025t2avcompass,
  title         = {T2AV-Compass: Towards Unified Evaluation for Text-to-Audio-Video Generation},
  author        = {Cao, Zhe and Wang, Tao and Wang, Jiaming and Wang, Yanghai and Zhang, Yuanxing and Chen, Jialu and Deng, Miao and Wang, Jiahao and Guo, Yubin and Liao, Chenxi and Zhang, Yize and Zhang, Zhaoxiang and Liu, Jiaheng},
  year          = {2025},
  eprint        = {2512.21094},
  archivePrefix = {arXiv},
  primaryClass  = {cs.CV},
  url           = {https://arxiv.org/abs/2512.21094},
}
```

## 🔗 链接

- **项目主页**: [github.com/NJU-LINK/T2AV-Compass](https://github.com/NJU-LINK/T2AV-Compass)
- **arXiv 论文**: [arxiv.org/abs/2512.21094](https://arxiv.org/abs/2512.21094)
- **数据集**: [huggingface.co/datasets/NJU-LINK/T2AV-Compass](https://huggingface.co/datasets/NJU-LINK/T2AV-Compass)

## 📧 联系方式

- `zhecao@smail.nju.edu.cn`
- `liujiaheng@nju.edu.cn`

---

**NJU-LINK Team, 南京大学** · **Kling Team, 快手科技** · **中国科学院自动化研究所**
