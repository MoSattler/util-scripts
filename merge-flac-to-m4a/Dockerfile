# Use an official lightweight FFmpeg image as the base image
FROM jrottenberg/ffmpeg:4.4-alpine as ffmpeg

# Install necessary dependencies
RUN apk add --no-cache bash bc findutils

# Set the working directory inside the container
WORKDIR /app

# Create dedicated input and output directories inside the container
RUN mkdir /input /output

# Copy everything from the current directory into the container
COPY . /app

# Make the script executable
RUN chmod +x /app/script.sh

# Define the entrypoint to find subdirectories and run the script in parallel with xargs
ENTRYPOINT ["bash", "-c", "find /input -mindepth 1 -type d | xargs -P 4 -I {} bash /app/script.sh {} /output"]