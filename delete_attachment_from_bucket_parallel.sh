#!/bin/bash
# Script to use Linux "parallel" command to delete old bucket files, running 'gsutil rm gs://bucket_name' using parallel jobs. 
#  This improved the time for deleting millions of orphaned files in gcp buckets from several days duration to several hours.
#
# Check key and authenticate
check_gcloud_key() {
  key_file="your-gcp-key.json"
  if [ ! -f "$key_file" ]; then
    echo "Google Cloud service account key file not found!"
    echo "Please copy the key file to the specified location and reauthenticate."
    exit 1
  else
    # Authenticate with Google Cloud
    gcloud auth activate-service-account --key-file="$key_file"
    if [ $? -ne 0 ]; then
      echo "Authentication failed. Please check your key file and try again."
      exit 1
    fi
  fi
}
check_gcloud_key

# Specify the bucket name
bucket_name="your-bucket-name"

# Prompt for the filename containing the list of UUIDs
read -p "Enter the filename containing the list of UUIDs: " filename

# Check if the file exists
if [ ! -f "$filename" ]; then
  echo "File not found!"
  exit 1
fi

# Save the start time
start_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "Start time: $start_time"

# Run the parallel command and save the log output in /tmp
logfile="/tmp/gsutil_rm_$(date +"%Y%m%d_%H%M%S").log"
echo "Starting deletes... see $logfile"
cat "$filename" | parallel -j 16 gsutil rm gs://$bucket_name/{} &> "$logfile"

# Save the end time
end_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "End time: $end_time"

# Output the log file location
echo "Log file saved to: $logfile"
