set -x

echo -n '{
  "eventType" : "com.oraclecloud.objectstorage.createobject",
  "cloudEventsVersion" : "0.1",
  "eventTypeVersion" : "2.0",
  "source" : "ObjectStorage",
  "eventTime" : "2023-07-25T19:58:33Z",
  "contentType" : "application/json",
  "data" : {
    "compartmentId" : "ocid1.compartment.oc1..aaaaaaaak4br2cpp6gggpquw6omq7ocf2kinkz3qi5oyjbispxped525cdga",
    "compartmentName" : "mikep",
    "resourceName" : "sintel.mp4",
    "resourceId" : "/n/axhlyht8myu1/b/src_bucket/o/sintel.mp4",
    "availabilityDomain" : "IAD-AD-1",
    "additionalDetails" : {
      "bucketName" : "src_bucket",
      "versionId" : "2a33033a-9f01-4646-9d4b-ee5c11bb8d28",
      "archivalState" : "Available",
      "namespace" : "axhlyht8myu1",
      "bucketId" : "ocid1.bucket.oc1.iad.aaaaaaaamdutx2nihz3bfzdcr4ktbt2gkfmivgbj3gi62oetskzlw4cne2wq",
      "eTag" : "5b9744cc-d973-41be-8d04-e723c4809ac7"
    }
  },
  "eventID" : "cd5c629a-de5e-defa-c88c-993a237aa86e",
  "extensions" : {
    "compartmentId" : "ocid1.compartment.oc1..aaaaaaaak4br2cpp6gggpquw6omq7ocf2kinkz3qi5oyjbispxped525cdga"
  }}' | DEBUG=1 fn invoke process-new-file create-container-instance
