import sys
import os
import subprocess
import tempfile
import pysrt
from pathlib import Path

# ──────────────────────────────────────────────────────────────
# 🧠 Usage: python auto_merge_subs.py /path/to/video.mp4
# ──────────────────────────────────────────────────────────────

if len(sys.argv) != 2:
    print("Usage: python auto_merge_subs.py <video_file.mp4>")
    sys.exit(1)

video_path = Path(sys.argv[1])
if not video_path.exists():
    print(f"❌ File not found: {video_path}")
    sys.exit(1)

basename = video_path.stem
output_srt = video_path.with_suffix(".srt")

print(f"📥 Processing: {video_path.name}")

with tempfile.TemporaryDirectory() as tmpdir:
    tmpdir = Path(tmpdir)
    track3_path = tmpdir / "track_catalan_audio_spanish_subs.srt"
    track4_path = tmpdir / "track_catalan_subtitles_full.srt"

    # Extract subtitle streams 0:3 and 0:4
    print("🎬 Extracting Track 0:3 (Spanish subs for Catalan speech)...")
    subprocess.run([
        "ffmpeg", "-y", "-i", str(video_path), "-map", "0:3", str(track3_path)
    ], check=True)

    print("🎬 Extracting Track 0:4 (Catalan full subs)...")
    subprocess.run([
        "ffmpeg", "-y", "-i", str(video_path), "-map", "0:4", str(track4_path)
    ], check=True)

    print("📚 Loading and merging subtitles...")
    primary_subs = pysrt.open(str(track3_path))   # Spanish for Catalan speech
    fallback_subs = pysrt.open(str(track4_path))  # Catalan full subs (used only if missing)

    # Use primary subs by default, fill gaps from fallback
    def overlaps(sub, subs_list):
        for other in subs_list:
            if not (sub.end <= other.start or sub.start >= other.end):
                return True
        return False

    final_subs = primary_subs[:]
    for sub in fallback_subs:
        if not overlaps(sub, primary_subs):
            final_subs.append(sub)

    # Remove duplicates
    seen = set()
    unique = []
    for sub in final_subs:
        key = (sub.start.ordinal, sub.end.ordinal, sub.text.strip())
        if key not in seen:
            seen.add(key)
            unique.append(sub)

    # Sort and write to output
    unique.sort(key=lambda x: x.start)
    print(f"💾 Writing final merged subtitles to: {output_srt}")
    with open(output_srt, 'w', encoding='utf-8') as f:
        for i, sub in enumerate(unique, 1):
            f.write(f"{i}\n{sub.start} --> {sub.end}\n{sub.text.strip()}\n\n")

print("✅ Done!")