#!/bin/bash
set -x
INPUT_BUCKET=$1
INPUT_FILE=$2
PROJECT_NAME=$TC_PROJECT_NAME
OUTPUT_BUCKET=$TC_DST_BUCKET
STREAMING_PROTOCOL=$TC_STREAMING_PROTOCOL
OUTPUT_DIR="/tmp/ffmpeg"

get_video_duration()
{
  #Check duration of the video stream
  video_duration=$(ffprobe -v error -of flat=s_ -select_streams v -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$1")
  echo "$video_duration"
}

get_audio_duration()
{
  #Check duration of the audio stream (0 if there no audio stream
  audio_duration=$(ffprobe -v error -of flat=s_ -select_streams a -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$1")
  echo "$audio_duration"
}

transcode_hls()
{
  FFMPEG_STREAM_MAP=""

  # If HLS protocol is used set FFMPEG Stream Map for HLS
  # v:0,a:0 v:1,a:1 ... (if there are both video and audio streams)
  # v:0 v:1 ... (if there are only video streams)

  audio_duration=$( get_audio_duration "$1" )

  #Set stream map between video and audio streams for HLS
  if [ "$audio_duration" ]; then
    FFMPEG_STREAM_MAP="v:0,a:0 v:1,a:1 v:2,a:2"
  else
    echo "No audio stream"
    FFMPEG_STREAM_MAP="v:0 v:1 v:2"
  fi

  #Run HLS transcoding
  ffmpeg -i "$1" \
  -map v:0 -s:0 1920x1080 -b:v:0 5M -maxrate 5M -minrate 5M -bufsize 10M \
  -map v:0 -s:1 1280x720 -b:v:1 3M -maxrate 3M -minrate 3M -bufsize 3M \
  -map v:0 -s:2 640x360 -b:v:2 1M -maxrate 1M -minrate 1M -bufsize 1M \
  -map a:0? -map a:0? -map a:0? -c:a aac -b:a 128k -ac 1 -ar 44100 \
  -keyint_min 48 -g 48 \
  -c:v libx264 -sc_threshold 0 \
  -f hls \
  -hls_time 5 \
  -hls_playlist_type vod \
  -hls_segment_filename stream_%v_%03d.ts \
  -master_pl_name master.m3u8 \
  -var_stream_map "$FFMPEG_STREAM_MAP" stream_%v.m3u8  
} 

transcode_dash()
{
  #Set stream map between video and audio streams for DASH   
  FFMPEG_STREAM_MAP="id=0,streams=v id=1,streams=a"

  #Run DASH transocding
  ffmpeg -i "$1" \
  -map v:0 -s:0 1920x1080 -b:v:0 5M -maxrate 5M -minrate 5M -bufsize 10M \
  -map v:0 -s:1 1280x720 -b:v:1 3M -maxrate 3M -minrate 3M -bufsize 3M \
  -map v:0 -s:2 640x360 -b:v:2 1M -maxrate 1M -minrate 1M -bufsize 1M \
  -map a:0? -c:a aac -b:a 128k -ac 1 -ar 44100 \
  -keyint_min 48 -g 48 \
  -c:v libx264 -sc_threshold 0 \
  -f dash \
  -use_template 1 \
  -use_timeline 1 \
  -seg_duration 5 \
  -adaptation_sets "$FFMPEG_STREAM_MAP" dash.mpd
}

create_thumbnail()
{
  # Create thumbnail and set thumbnail duration to 10 sec. If video duration is less than 10 sec set thumbnail duration to video duration
  video_duration=$( get_video_duration "$1" )
  if (( $(echo "$video_duration > 10" |bc -l) )); then
        ffmpeg -i "$1" -ss 00:00:10 -s 1280x720 -frames:v 1 "$2"
  else
        ffmpeg -i "$1" -s 1280x720 -frames:v 1 "$2"
  fi
}

## Main script starts here

#Download input file from OCI object storage bucket
echo "Downloading file $INPUT_FILE from $INPUT_BUCKET OS bucket"
ifile="/tmp/$(basename $INPUT_FILE)"
oci os object get --bucket-name $INPUT_BUCKET --name $INPUT_FILE --file $ifile --auth resource_principal

if [ $? -eq 0 ]; then
        echo "Successfully downloaded the input file $INPUT_FILE from OS bucket $INPUT_BUCKET"
else
        echo "Failed to download the input file $INPUT_FILE from OS bucket  $INPUT_BUCKET"
        exit 1
fi

mkdir -p $OUTPUT_DIR/$INPUT_FILE
cd $OUTPUT_DIR/$INPUT_FILE

#Transcode the file
if [[ "${TC_STREAMING_PROTOCOL^^}" == "HLS" ]]; then
        #Run HLS transcoding
        echo "HLS transcoding file $INPUT_FILE"
        transcode_hls "$ifile" 
elif [[ "${TC_STREAMING_PROTOCOL^^}" == "DASH" ]]; then
        #Run DASH transcoding
        echo "DASH transcoding file $INPUT_FILE"
        transcode_dash "$ifile" 
else
    echo "Unsupported streaming protocol. Supported protocols are HLS & DASH"
    exit 1
fi


if [ $? -eq 0 ]; then
        echo "Successfully transcoded $INPUT_FILE"
else
        echo "Failed to transcode $INPUT_FILE"
        exit 1
fi

#Upload the transcoded files to OCI object storage bucket
echo "Uploading transcoded files to $TC_DST_BUCKET OS bicket"
#Firt check if the folder with this name already exists. If found - delete it including all objects inside the folder.
oci os object bulk-delete --bucket-name $OUTPUT_BUCKET --prefix $INPUT_FILE/ --force --auth resource_principal
oci os object bulk-upload --bucket-name $OUTPUT_BUCKET --src-dir $OUTPUT_DIR --overwrite --auth resource_principal

if [ $? -eq 0 ]; then
        echo "Successfully uploaded the transcoded files of $INPUT_FILE to OS bucket $OUTPUT_BUCKET"
else
        echo "Failed to upload the transcoded files of  $INPUT_FILE to OS bucket $OUTPUT_BUCKET"
        $SQL_CONNECT "update jobs set status='ERROR' where id=$job_id"
        exit 1
fi

# Create thumbnail and set thumbnail duration to 10 sec. If video duration is less than 10 sec set thumbnail duration to video duration
THUMB_FILE=$INPUT_FILE'_thumb.png'
create_thumbnail "$ifile" "$THUMB_FILE"

#Upload thumbnail to OCI object storage bucket
echo "Uploading thumbnail file to $TC_DST_BUCKET OS bucket"
oci os object put --bucket-name $OUTPUT_BUCKET --file $THUMB_FILE --name thumbnails/$THUMB_FILE --force --auth resource_principal
