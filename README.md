# OCI Container Instances
This repo shows an example how to spin up an OCI container instance when a new media file is uploaded to OCI Object Storage bucket. When a new file is uploaded to the object storage bucket, it emits an event that executes a serverless function. The function creates a serveless container instance that starts a transcoding container. The transcoding job uses ffmpeg open source software to transcode to multiple resolutions and different bitrates. It supports both HLS and DASH streaming protocols. On completion it creates a master manifest file and uploads all the files to the destination bucket. In addition it creates a thumbnail of the media content and uploads it to the destination bucket. 

# Data Flow
The data flow is illustrated in the picture below:

![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/028cb8b2-c1b3-49df-a87a-d5a79e0c9536)

OCI serverless function is a light-weight resource with a limited execution time. Transcoding of large media files can be quite time consuming and require more disk space than OCI functions support. Therefore, the role of the function is to spin up a serveless container instance that can efficiently execute the transcoding job. 

# Pre-Requisites

Both OCI function and container instance services use AIM resource principal to authenticate and access Oracle Cloud Infrastructure resources [Resource Principals](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm).  You should create a [dynamic group](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingdynamicgroups.htm) for the compartment where you are deploying the resources. When creating a dynamic group to match OCI functions and container instances in a given compartment you can use the following matching rule:

  ALL {resource.type='computecontainerinstance', resource.compartment.id = 'compartment-id'}
  ALL {resource.type = 'fnfunc',resource.compartment.id = 'compartment-id'}

where compartment-id is OCID of your compartment. You can get compartment OCID in OCI console from Identity & Security. Under Identity, click Compartments. A compartment hierarchy in your tenancy is displayed. Find your compartment and copy its OCID.

After creating the dynamic group, you should set specific [IAM policies](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/policyreference.htm) for OCI services that can be used by the Dynamic Group. 

**Due to enforcement of [OSMS](https://docs.oracle.com/en-us/iaas/os-management/osms/osms-getstarted.htm) for compute resources created using an `manage all-resources` policy, you need to specify each service in a separate policy syntax**

At a minimum, the following policies are required:

    Allow dynamic-group <dynamic group name> to manage object-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic group name> to manage compute-container-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic group name> to read repos in tenancy
  

Prior to deployment create an [Authentication Token](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm#create_swift_password) and create a repo in [OCI Registry](https://docs.oracle.com/en-us/iaas/Content/Registry/Concepts/registryoverview.htm) where the container image will be stored.

**The OCI registry must be in the tenanacy root and the user account associated with the auth token will need relevant privileges for the repo**

![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/2df0f48e-abad-4e9b-9639-24a5988ae0ef)

