# OCI Container Instances
This repo shows an example how to spin up an OCI container instance when a new media file is uploaded to OCI Object Storage bucket. When a new file is uploaded to the object storage bucket, it emits an event that executes a serverless function. The function creates a serveless container instance that starts a transcoding container. The transcoding job uses ffmpeg open source software to transcode to multiple resolutions and different bitrates. It supports both HLS and DASH streaming protocols. On completion it creates a master manifest file and uploads all the files to the destination bucket. In addition it creates a thumbnail of the media content and uploads it to the destination bucket. 

# Data Flow
The data flow is illustrated in the picture below:

![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/028cb8b2-c1b3-49df-a87a-d5a79e0c9536)

OCI serverless function is a light-weight resource with a limited execution time. Transcoding of large media files can be quite time consuming and require more disk space than OCI functions support. Therefore, the role of the function is to spin up a serveless container instance that can efficiently execute the transcoding job. 

# Pre-Requisites

Both OCI function and container instance services use AIM resource principal to authenticate and access OCI resources.  Create a [dynamic group](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingdynamicgroups.htm) matching OCI function and container instance resource types in a given compartment. Use the following matching rule:

  ALL {resource.type='computecontainerinstance', resource.compartment.id = 'compartment-id'}
  ALL {resource.type = 'fnfunc',resource.compartment.id = 'compartment-id'}

where compartment-id is OCID of your compartment. You can get compartment OCID in OCI console from Identity & Security. Under Identity, click Compartments. A compartment hierarchy in your tenancy is displayed. Find your compartment and copy its OCID.

After creating the dynamic group, you should set specific [IAM policies](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/policyreference.htm) for OCI services that can be used by the dynamic group. 

At a minimum, the following policies are required:

    Allow dynamic-group <dynamic group name> to manage object-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic group name> to manage compute-container-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic group name> to read repos in tenancy
  
# Create a Container Image in OCI registry
In a terminal window on a client machine running Docker, clone this github repo

git clone https://github.com/mprestin77/oci-container-instances/edit/main

Run "docker" command to check that Docker is installed and running. If you are getting an error message indicating that Docker is not installed see [Docker documentation for your platform](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsquickstartocicomputeinstance.htm#).

Go to oci-container-instance/build directory and create a local container image by running

docker build -t transcoder . --no-cache

Check that the container image was successfully:

docker images

In the output of this command you should see "transcoder:latest" image

Tag this image to 

For more details see [Pushing Images Using the Docker CLI](https://docs.oracle.com/en-us/iaas/Content/Registry/Tasks/registrypushingimagesusingthedockercli.htm)


Create an [Authentication Token](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm#create_swift_password) and save it in your records. After that create a repo in [OCI Registry](https://docs.oracle.com/en-us/iaas/Content/Registry/Concepts/registryoverview.htm) where the container image will be stored.

**The OCI registry must be in the tenanacy root and the user account associated with the auth token will need relevant privileges for the repo**

Log in to Oracle Cloud Infrastructure Registry by entering:

docker login <region-key>.ocir.io

where <region-key> is the key for the Oracle Cloud Infrastructure Registry region you're using. See [Availability by Region](https://docs.cloud.oracle.com/iaas/Content/Registry/Concepts/registryprerequisites.htm#Availab) topic in OCI Registry documentation.

When prompted for username, enter your username in the format <tenancy-namespace>/<username>. If your tenancy is federated with Oracle Identity Cloud Service, use the format <tenancy-namespace>/oracleidentitycloudservice/<username>.

When prompted for password, enter the auth token you copied earlier as the password.

Create a tag to the image that you're going to push to OCI Registry by entering: 

docker tag transcoder:latest <region-key>.ocir.io/<tenancy-namespace>/<repo-name>/transcoder:latest

Push the container image to OCI registry

docker push <region-key>.ocir.io/<tenancy-namespace>/<repo-name>/transcoder:latest

For more details see [Pushing Images Using the Docker CLI](https://docs.oracle.com/en-us/iaas/Content/Registry/Tasks/registrypushingimagesusingthedockercli.htm)

# Create Network Infrastracture for OCI Functions and Container Instances



# Create OCI Function Application

Create [OCI fn Application](https://docs.oracle.com/en-us/iaas/Content/Functions/Tasks/functionsquickstartlocalhost.htm#) attached to the subnet that OCI container instances will be using.

# Create OCI Event Rule

Create an [Event Rule](https://docs.oracle.com/en-us/iaas/Content/Events/Task/create-events-rule.htm#top) that fires when a new file is uploaded to the object storage bucket. Here is an example of the event rule:

![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/58272778-6ad1-44f1-9980-9f7b8a6d8c35)



