# OCI Container Instances
This repo shows an example how to spin up an OCI container instance when a new media file is uploaded to OCI Object Storage bucket. When a new file is uploaded to the object storage bucket, it emits an event that executes a serverless function. The function creates a serveless container instance that starts a transcoding container. The transcoding job uses ffmpeg open source software to transcode to multiple resolutions and different bitrates. It supports both HLS and DASH streaming protocols. On completion it creates a master manifest file, uploads all the files to the destination bucket. In addition it creates a thumbnail of the media content and uploads it to the destination bucket. 

# Data Flow
The data flow is illustrated in the picture below:

![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/028cb8b2-c1b3-49df-a87a-d5a79e0c9536)

OCI serverless function is a light weight resource with a limited execution time. Transcoding of large media files can be quite time consuming and require more disk space than OCI functions support. Therefore, the role of the function is to spin up a serveless container instance that can efficiently execute the transcoding job. 

# Pre-Requisites

Both OCI function and OCI container instance require usage of [Resource Principals](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm) for container execution.  You should create a [dynamic group](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingdynamicgroups.htm) for the compartment where you are deploying your OKE cluster. When creating a dynamic group to match all compute instances in the compartment you can use the following matching rule:

  instance.compartment.id = 'compartment-id'

where compartment-id is ID of your compartment. You can get compartment OCID in OCI console from Identity & Security. Under Identity, click Compartments. A compartment hierarchy in your tenancy is displayed. Find your compartment and copy its OCID.

After creating the dynamic group, you should set specific [IAM policies](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/policyreference.htm) for OCI services that can be used by the Dynamic Group. 

**Due to enforcement of [OSMS](https://docs.oracle.com/en-us/iaas/os-management/osms/osms-getstarted.htm) for compute resources created using an `manage all-resources` policy, you need to specify each service in a separate policy syntax**

At a minimum, the following policies are required:

    Allow dynamic-group <dynamic group name> to manage cluster-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic group name> to manage secret-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic group name> to manage vaults in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage streams in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage repos in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage object-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage instance-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage virtual-network-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage cluster-node-pools in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage vnics in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage mysql-family in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to inspect compartments in compartment id <compartment OCID>
    Allow dynamic-group <dynamic-group-name> to manage cloudevents-rules in compartment id <compartment OCID>

Also required prior to deployment are an [OCI Registry](https://docs.oracle.com/en-us/iaas/Content/Registry/Concepts/registryoverview.htm), [OCI Vault](https://docs.oracle.com/en-us/iaas/Content/KeyManagement/Concepts/keyoverview.htm), [Auth Token](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm#create_swift_password), and a [Vault Secret](https://docs.oracle.com/en-us/iaas/Content/KeyManagement/Tasks/managingsecrets.htm) which contains the Auth Token.  

**The OCI registry must be in the tenanacy root and the user account associated with the auth token will need relevant privileges for the repo**

![image](https://github.com/mprestin77/oci-container-instances/assets/54962742/2df0f48e-abad-4e9b-9639-24a5988ae0ef)

