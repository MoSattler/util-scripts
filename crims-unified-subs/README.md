# 🎬 Crims Subtitle Merger

A simple Python script that merges multiple subtitle tracks from `.mp4` video files into a single `.srt` file.

Specifically built for episodes of *Crímenes* (TV3), where:
- **Track 0:3** contains **Spanish subtitles for Catalan speech**
- **Track 0:4** contains **Catalan subtitles for the full episode**

The script merges these into a single `.srt`:
- Keeps Spanish subtitles from Track 0:3
- Fills in missing dialogue using Catalan subs from Track 0:4
- Outputs a clean `.srt` file in **Spanish only**

---

## ✅ Requirements

- Python 3.8+
- [FFmpeg](https://ffmpeg.org/) (must be installed and available in your terminal)

Install Python dependencies:

```bash
pip install -r requirements.txt
```

```bash
brew install ffmpeg
```

## 🚀 Usage
```bash
python merge_subs.py "/path/to/your/video.mp4"
```
