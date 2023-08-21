# OCI Container Instances
This repo shows an example how to automatically spin up an OCI container instance when a new media file is uploaded to OCI Object Storage bucket. When a new file is uploaded to the bucket, it emits an event that executes a serverless function. The function creates a serveless container instance that starts a transcoding container. The transcoding container uses ffmpeg open source software to transcode the media file to multiple resolutions and different bitrates. It supports both HLS and DASH streaming protocols. On completion it creates a master manifest file and uploads all the files to the destination bucket. In addition it creates a thumbnail of the media content and uploads it to the destination bucket. 

# Data Flow
The data flow is illustrated in the picture below:

![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/028cb8b2-c1b3-49df-a87a-d5a79e0c9536)

OCI serverless function is a light-weight resource with a limited execution time. Transcoding of large media files can be quite time consuming and requires more disk space than OCI functions support. Therefore, the role of the function is to spin up a serveless container instance that can efficiently execute the transcoding job. 

# Pre-Requisites

Both OCI function and container instance services use AIM resource principal to authenticate and access OCI resources.  Create a [dynamic group](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingdynamicgroups.htm) matching OCI function and container instance resource types in a given compartment. Use the following matching rule:
```
ALL {resource.type='computecontainerinstance', resource.compartment.id = 'compartment-id'}
ALL {resource.type = 'fnfunc',resource.compartment.id = 'compartment-id'}
```
where compartment-id is OCID of your compartment. You can get compartment OCID in OCI console from Identity & Security. Under Identity, click Compartments. A compartment hierarchy in your tenancy is displayed. Find your compartment and copy its OCID.

After creating the dynamic group, you should set specific [IAM policies](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/policyreference.htm) for OCI services that can be used by the dynamic group. 

At a minimum, the following policies are required:

    Allow dynamic-group <dynamic group name> to manage object-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic group name> to manage compute-container-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic group name> to read repos in tenancy
  
# Create a Container Image in OCI registry
In a terminal window on a client machine running Docker, clone this github repo:
```
git clone https://github.com/mprestin77/oci-container-instances/edit/main
```
Go to oci-container-instance/build directory and create a local container image by running:
```
docker build -t transcoder . --no-cache
```
Check that the container image was created on the local machine:
```
docker images
```
In the output of this command you should see "transcoder:latest" image listed.

Create an [Authentication Token](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm#create_swift_password) and save it in your records. After that create a repo in [OCI Registry](https://docs.oracle.com/en-us/iaas/Content/Registry/Concepts/registryoverview.htm) where the container image will be stored.

**The OCI registry must be in the tenanacy root compartment and the user account associated with the auth token will need relevant privileges for the repo**

Log in to Oracle Cloud Infrastructure Registry:
```
docker login <region-key>.ocir.io
```
where \<region-key\> is the key for the Oracle Cloud Infrastructure Registry region you're using. See [Availability by Region](https://docs.cloud.oracle.com/iaas/Content/Registry/Concepts/registryprerequisites.htm#Availab) topic in OCI Registry documentation.

When prompted for username, enter your username in the format \<tenancy-namespace\>\<username\>. If your tenancy is federated with Oracle Identity Cloud Service, use the format \<tenancy-namespace\>\/oracleidentitycloudservice/\<username\>.

When prompted for password, enter the auth token you copied earlier as the password.

Create a tag to the image that you're going to push to OCI Registry: 
```
docker tag transcoder:latest <region-key>.ocir.io/<tenancy-namespace>/<repo-name>/transcoder:latest
```
Push the container image to OCI registry:
```
docker push <region-key>.ocir.io/<tenancy-namespace>/<repo-name>/transcoder:latest
```
For more details see [Pushing Images Using the Docker CLI](https://docs.oracle.com/en-us/iaas/Content/Registry/Tasks/registrypushingimagesusingthedockercli.htm)

# Create Network Infrastracture for OCI Functions and Container Instances

Create a VCN with a subnet which will be used by OCI function and container instance services. Note that a public subnet requires an internet gateway in the VCN, and a private subnet requires a service gateway in the VCN. For more inormation see:

[Create VCN and subnet for OCI functions](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsquickstartocicomputeinstance.htm#)

[Create VCN and subnet for OCI container instances](https://docs.oracle.com/en-us/iaas/Content/container-instances/creating-a-container-instance.htm#)

# Create OCI Function Application

Create [OCI fn Application](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsquickstartlocalhost.htm#) attached to the subnet that OCI function and container instance services will be using. In my example I called the application "process-new-file"

In the terminal window on the client machine install [fn project CLI](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsquickstartocicomputeinstance.htm#)

After that go to the parent directory oci-container-instance and edit func.yaml file.  Set the values of the environment variables:
```
  AVAILABILITY_DOMAIN: <name of the availability domain>
  COMPARTMENT_ID: <compartment OCID>
  SHAPE: <container instance shape, currently supported shapes are CI.Standard.E4.Flex and CI.Standard.E3.Flex>
  CONFIG_SHAPE_MEMORY: <amount of memory (GB)> 
  CONFIG_SHAPE_OCPUS: <number of OCPUs>
  IMAGE_URL: <URL the container image in OCI registry>
  OUTPUT_BUCKET: <name of the output object storage bucket where the transcoded files will be uploaded>
  STREAMING_PROTOCOL: <HLS or DASH>
  SUBNET_ID: <subnet OCID>
```
and save the file.

Deploy create-container-instance function: 
```
fn deploy --app process-new-file
```

# Create OCI Event Rule

In OCI Console create an [Event Rule](https://docs.oracle.com/en-us/iaas/Content/Events/Task/create-events-rule.htm#top) that fires when a new file is uploaded to the object storage bucket. Here is an example of the event rule:

![Screen Shot 2023-08-15 at 4 27 55 PM](https://github.com/mprestin77/oci-container-instances/assets/54962742/e8f826ee-4b0e-4509-a9cf-6f8b8d48d91b)

Input bucket must be an existing object storage bucket where the input media files are uploaded. 

# Test the Flow

Upload a new file to the input bucket. Shortly after that you should see that OCI event new-file-upload is emitted. Here is a screenshot from OCI event metrics:

![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/fd39e420-6e9e-4a07-aac0-46d4ad0a2b96)

It triggers execution of "create-container-instance" function that you can see in OCI function metrics:

![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/676cf74f-c537-4895-ac17-253aa9b366ea)

This function spins up a new "transcode" container instance that you can see in OCI Container Instance metrics:

![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/fec57c25-481b-4b41-87c0-42f2940046e1)

The spun off container downloads the media file from the object storage bucket and transcodes the file to 3 different resolutions and bitrates

1080p 5Mbit/s

720p  3Mbit/s

360p  1Mbit/s

It creates a new folder in the output object storage bucket with the name of the input file, and uploads the playlist files to this folder. He is an example:

![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/bde73d2b-dc64-45cb-942a-07007966cd3a)

At the end it creates a thumbnail of the media content and uploads it to "thumbnails" folder of the destination bucket.
 
For troubleshooting purpose you can turn on logging in OCI fn application. Once the container instance is spun off you can view logs of the transcoding container while the container is running. 




