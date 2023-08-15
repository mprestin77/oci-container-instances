# oci-container-instances
This repo shows an example how to spin up an OCI container instance when a new media file is uploaded to OCI Object Storage bucket. When a new file is uploaded to the object storage bucket, it emits an event that executes a serverless function. The function creates a serveless container instaces that starts a transcoding container. The transcoding job uses ffmpeg open source software to transcode to multiple resolutions and different bitrates. It supports both HLS and DASH streaming protocols. On completion it creates a master manifest file, uploads all the files to the destination bucket. In addition it creates a thumbnail of the media content and uploads it to the destination bucket. 

![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/028cb8b2-c1b3-49df-a87a-d5a79e0c9536)


![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/2df0f48e-abad-4e9b-9639-24a5988ae0ef)

