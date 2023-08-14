#
# oci-create-container-instance-on-event version 1.0.
#
# Copyright (c) 2020 Oracle, Inc.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

# This function is executed when a new file is uploaded to OCI Object Storage bucket. The function checks
# that the file exists in the bucket and creates a container instance to process the file

import io
import os
import json
import sys
from fdk import response

import oci.auth
import oci.object_storage
import oci.container_instances
import logging

logging.getLogger('oci').setLevel(logging.DEBUG)

def handler(ctx, data: io.BytesIO=None):
    try:
        cfg = ctx.Config()

        body = json.loads(data.getvalue())

        bucket_name = body["data"]["additionalDetails"]["bucketName"]
        object_name = body["data"]["resourceName"]
        print(bucket_name, object_name, flush=True)

        signer = oci.auth.signers.get_resource_principals_signer()

        ret = get_object(bucket_name, object_name, signer)

        if ret:
           create_container_instances(cfg, bucket_name, object_name, signer)

        message = "SUCCESS"

    except Exception as e:
        message = "FAILED: " + str(e)
        print(message, flush=True)

    return response.Response(
        ctx,
        response_data=json.dumps({"message": message}),
        headers={"Content-Type": "application/json"}
    )

def get_object(bucket_name, object_name, signer):
    client = oci.object_storage.ObjectStorageClient(config={}, signer=signer)
    namespace = client.get_namespace().data

    print("A new object {0} has been uploaded to bucket {1}".format(object_name, bucket_name), flush=True)
    object = client.get_object(namespace, bucket_name, object_name)
    if object.status != 200:
        message = "FAILED: The object " + object_name + " was found"
        print(message, flush=True)
        raise Exception ("message")
    else:
        message = "SUCCESS: The object " + object_name + " was found"
        print(message,flush=True)
    return True
      
def create_container_instances(cfg, bucket_name, object_name, signer):
    container_instances_client = oci.container_instances.ContainerInstanceClient(config={}, signer=signer)

    create_container_instance_response = container_instances_client.create_container_instance(
      create_container_instance_details=oci.container_instances.models.CreateContainerInstanceDetails(
       display_name="transcode",
       compartment_id = cfg["COMPARTMENT_ID"],
       availability_domain = cfg["AVAILABILITY_DOMAIN"],
       shape = cfg["SHAPE"],
       shape_config=oci.container_instances.models.CreateContainerInstanceShapeConfigDetails(
         ocpus = int(cfg["CONFIG_SHAPE_OCPUS"]),
         memory_in_gbs = int(cfg["CONFIG_SHAPE_MEMORY"])),
       containers=[
         oci.container_instances.models.CreateContainerDetails(
             image_url = cfg["IMAGE_URL"],
             display_name="transcoder",
             arguments = [bucket_name, object_name],
             environment_variables={"TC_PROJECT_NAME":"Transcode","TC_DST_BUCKET":cfg["OUTPUT_BUCKET"],"TC_STREAMING_PROTOCOL":cfg["STREAMING_PROTOCOL"]})],
       vnics=[oci.container_instances.models.CreateContainerVnicDetails(subnet_id=cfg["SUBNET_ID"])],
       container_restart_policy="NEVER"
      )
     )



