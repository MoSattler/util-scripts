#!/bin/bash

# Input and output directories
input_dir=$1
output_dir=$2

# Check if the input and output directories are provided
if [ -z "$input_dir" ] || [ -z "$output_dir" ]; then
    echo "Usage: $0 <input_directory> <output_directory>"
    exit 1
fi

# Create a temporary directory
tmp_dir=$(mktemp -d)

# Convert FLAC files to M4A and move them to the temporary directory
for f in "$input_dir"/*.flac; do
    ffmpeg -i "$f" -map 0:a -c:a alac -map_metadata 0 "$tmp_dir/$(basename "${f%.flac}.m4a")"
done

# Define variables for metadata and file output
first_file=$(ls "$tmp_dir"/*.m4a | head -n 1)
metadata=$(ffmpeg -i "$first_file" 2>&1 | grep -E 'artist|album|date|album_artist')

# Extract and clean up the album information
album_full=$(echo "$metadata" | grep '^ *album *:' | head -n 1 | cut -d ':' -f 2- | xargs)

# Get the part before the `/` (assuming it's the track number)
track_number=$(echo "$album_full" | cut -d '/' -f 1 | xargs)

# Get the part after the `/` (assuming it's the actual album name)
album=$(echo "$album_full" | cut -d '/' -f 2- | xargs)

# Variables to hold other metadata
artist=$(echo "$metadata" | grep 'artist' | head -n 1 | cut -d ':' -f 2- | xargs)
date=$(echo "$metadata" | grep 'date' | head -n 1 | cut -d ':' -f 2- | xargs)
album_artist=$(echo "$metadata" | grep 'album_artist' | head -n 1 | cut -d ':' -f 2- | xargs)

# Use album name for title and filename if the album is missing
if [ -z "$album" ]; then
    album="merged_output"
fi

# Set the title to be the same as the album
title="$album"
output_file="$output_dir/${track_number}. ${title}.m4a"  # Final output file in the output directory

# Define a temporary file in the tmp_dir to store the list of files
concat_file="$tmp_dir/concat_list.txt"

# Generate the list of files with proper quoting
echo "Generating file list for concatenation..."

# Use a while loop with find to handle spaces in file names properly
find "$tmp_dir" -name "*.m4a" | while IFS= read -r file; do
  # Append each file, correctly quoted, to the concat list
  echo "file '$file'" >> "$concat_file"
done

# Sort the concat_file by version (natural numeric sorting)
sort -V "$concat_file" -o "$concat_file"

# Print the contents of the concat_file to double check the file paths
echo "Here is the generated file list after sorting:"
cat "$concat_file"

# Use the temporary file as input for FFmpeg
ffmpeg -f concat -safe 0 -i "$concat_file" -map 0:a -c copy "$tmp_dir/merged_audio.m4a"

# Initialize chapter file
chapters_file="$tmp_dir/chapters.txt"
echo ";FFMETADATA1" > $chapters_file

# Initialize cumulative time
cumulative_time=0

# Add chapters based on the length of each source file
while IFS= read -r line; do
    # Extract the file path from the "file '...'" format in the list
    f=$(echo "$line" | cut -d "'" -f 2)

    # Get the title metadata of the file for chapter name
    title_metadata=$(ffmpeg -i "$f" 2>&1 | grep -Eo 'title *:.*' | cut -d ':' -f 2- | xargs)

    # Fallback to file name if no title metadata is found
    if [ -z "$title_metadata" ]; then
        title_metadata=$(basename "$f" .m4a)
    fi

    # Get the duration of the file in seconds
    duration=$(ffmpeg -i "$f" 2>&1 | grep "Duration" | awk '{print $2}' | tr -d ,)

    # Convert the duration to seconds
    IFS=: read -r hour min sec <<< "$duration"
    duration_sec=$(echo "$hour*3600 + $min*60 + $sec" | bc)

    # Add a chapter for the current file
    echo "[CHAPTER]" >> $chapters_file
    echo "TIMEBASE=1/1000" >> $chapters_file
    echo "START=$cumulative_time" >> $chapters_file
    cumulative_time=$(echo "$cumulative_time + $duration_sec * 1000" | bc)
    echo "END=$cumulative_time" >> $chapters_file
    echo "title=$title_metadata" >> $chapters_file
done < "$concat_file"

# Add chapters and metadata to the merged file
ffmpeg -i "$tmp_dir/merged_audio.m4a" -i "$chapters_file" \
-map_metadata 1 \
-metadata artist="$artist" \
-metadata album="$album" \
-metadata date="$date" \
-metadata album_artist="$album_artist" \
-metadata title="$title" \
-metadata track="$track_number" \
-metadata encoder="FFmpeg" \
-c copy "$tmp_dir/merged_with_chapters.m4a"

# Add the cover image (if available), and place the final output in the output directory
if [ -f "$input_dir/cover.jpg" ]; then
    ffmpeg -i "$tmp_dir/merged_with_chapters.m4a" -i "$input_dir/cover.jpg" \
    -map 0:a -map 1 \
    -c:a copy -c:v mjpeg -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" \
    -disposition:v:0 attached_pic \
    "$output_file"
else
    # If no cover is available, just rename the final file
    mv "$tmp_dir/merged_with_chapters.m4a" "$output_file"
fi

# Clean up temporary directory
rm -rf "$tmp_dir"