#!/bin/bash
# Menu to choose options related to delete data1 volume and recreate from snapshot in GCP
# Sanitized version for github.

# Requires gcloud auth login first.

# Steps from the doc to follow are:
#1. Create snapshot from a known good system
#2. umount -R /data (included in detach or destroy)
#3. detach disk
#4. destroy old disk
#5. create new disk from the snapshot and name it -data1, 6000 GB
#6. attach new disk to vm
#7. Restart vm
#8. (Not automated) Enable and start postgresql-11, fix /data/pgdata/recovery.conf, repmgr standby follow

DATA1_SIZE="6000"
SNAP_RESTOREFROM="gx-dbro-02-2022-10-03"
KMS_KEY="projects/projname/locations/global/keyRings/encryption/cryptoKey/something/disks"

echo "Enter VM name: "
read vmname
# get zone name from vm name and add to var
zonename=`gcloud compute disks list --filter=$vmname | grep $vmname | awk '{print $2}' | head -1`
echo "Zone name found as: $zonename - is this correct? type yes or no: "
read zone_correct
    if [ "$zone_correct" != "yes" ]; then
      echo "Enter zone name: "
      read zonename
    fi

# Get disk name from gcp and add to var
diskname=`gcloud compute disks list --filter=$vmname | grep $vmname | awk '{print $1}' | grep data`
echo "Disk name found as: $diskname - is this correct? Type yes or no: "
read disk_correct
    if [ "$disk_correct" != "yes" ]; then
      echo "Enter disk name: "
      read diskname
    fi


##### List of functions


function list_snapshot()
{
  snapshotname=`gcloud compute snapshots list --filter=$vmname | grep $vmname | awk '{print $1}'`
  echo "Snap found: $snapshotname."
  echo "Use this snapshot? type yes or no: "
  read snap_correct
  if [ "$snap_correct" != "yes" ]; then
    echo "Enter existing or new snapshot, or copy/paste predefined snapshot name from here: $SNAP_RESTOREFROM "
    read snapshotname
    gcloud compute snapshots list --filter="$snapshotname"
    echo "Setting snapshot name to: $snapshotname"
    
    # Add check if there is no snapshot found
  fi
}

function take_snapshot()
{
  list_snapshot
  gcloud compute disks snapshot $diskname --zone=$zonename --snapshot-names=$snapshotname --description='snapshot created for $vmname'
}

function delete_snapshot() 
{
  list_snapshot
  gcloud compute snapshots delete $snapshotname --zone=$zonename 
}

function detach_disk()
{
  echo "Stopping postgresql and unmounting /data..."
  if [[ $(ssh $vmname "which postgres" | grep 11) ]]
  then
    echo "$vmname pg 11 detected"
    ssh $vmname "sudo systemctl stop postgresql-11 && sudo umount -R /data"
   elif [[ $(ssh $vmname "which postgres" | grep 12) ]]
  then
    echo "$vmname pg 12 detected"
    ssh $vmname "sudo systemctl stop postgresql-12 && sudo umount -R /data"
  fi
  sleep 1

  echo "Detaching disk..."
  gcloud compute instances detach-disk $vmname --zone=$zonename --disk $diskname
}


function destroy_disk()
{
  echo "Shutting down vm $vmname... please wait..."
  gcloud compute instances stop $vmname --zone=$zonename
  
  echo "Are you SURE you want to delete $diskname on $vmname? type YES or no: "
  read deletedisk
  
  if [ "$deletedisk" == "YES" ]; then
    echo "Detaching disk $diskname..."
    gcloud compute instances detach-disk $vmname --zone=$zonename --disk $diskname
    
    echo "Deleting disk..."
    gcloud compute disks delete $diskname --zone=$zonename
  fi
  
}

function create_new_disk_from_snap()
{
  list_snapshot
  echo "Creating new disk from snapshot... this will take some time..."
  gcloud compute disks create $diskname --size $DATA1_SIZE --source-snapshot $snapshotname --zone=$zonename --type pd-ssd --kms-key $KMS_KEY
  
  #Attach the disk created from step as the data1 disk:
  echo "Attaching disk..."
  gcloud compute instances attach-disk $vmname --disk $diskname --zone=$zonename --device-name data1
  
  # Restart the vm
  echo "Start the vm? yes or no "
  read restartvm
  if [ "$restartvm" == "yes" ]; then
    gcloud compute instances start $vmname --zone=$zonename
  fi
}



#### end functions ####


#### Start case menu ####

while true
do

  echo " 
  1. Take a snapshot
  2. Delete a snapshot
  3. Detach disk
  4. Destroy disk
  5. Create new disk from snapshot
  6. Restart VM
  7. List snapshot
  q to Quit
  "
  
  read -p "Choose your option 1-6 or q to quit: " choice

  case $choice in
      1)  echo "
          -> You chose:
           Take a snapshot:
           "
           take_snapshot
           exit
          ;;
      2)  echo "
          -> You chose: 
           Delete a snapshot:
           "
           delete_snapshot
          ;;
      3)  echo "
          -> You chose:
           Detach disk - are you sure? This will stop postgresql, umount /data, detach the disk. type yes or no: "
           read detach_now
           if [ "$detach_now" == "yes" ]; then
             detach_disk
           fi
          ;;          
      4)  echo "
          -> You chose: 
           Destroy disk - are you sure? This will shut down the vm, detach, and delete a disk. type YES or no: "
           read shutnow
           if [ "$shutnow" == "YES" ]; then
             destroy_disk
           fi
          ;;
      5)  echo "
           Create new disk from snapshot and attach it
           "
           create_new_disk_from_snap
          ;;
      6)  echo "
          -> You chose: 
           Start VM from down state
           "
           gcloud compute instances start $vmname --zone=$zonename
          ;;
      7)  echo "
          -> You chose: 
           List snapshot
           "
           list_snapshot
          ;;    
      q)  echo "Quitting."
          exit 
          ;;
      *)  echo "Invalid selection."
          ;;
  esac
done
    
