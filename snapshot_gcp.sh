#!/bin/bash
# Menu to choose options related to creating snapshots in GCP

# gcloud auth list --filter="-status:ACTIVE" | grep ACTIVE

echo "Enter VM name: "
read vmname
# get zone name from vm name and add to var
zonename=`gcloud compute disks list --filter=$vmname | grep $vmname | awk '{print $2}'`
echo "Zone name found as: $zonename - is this correct? type yes or no: "
read zone_correct
    if [ "$zone_correct" != "yes" ]; then
      echo "Enter zone name: "
      read zonename
    fi

# Get disk name from gcp and add to var
diskname=`gcloud compute disks list --filter=$vmname | grep $vmname | awk '{print $1}'`
echo "Disk name found as: $diskname - is this correct? Type yes or no: "
read disk_correct
    if [ "$disk_correct" != "yes" ]; then
      echo "Enter disk name: "
      read diskname
    fi




diskname_new=$diskname-restored


##### List of functions

# List any snapshots existing for this vm and present it as an option

function list_snapshot()
{
  snapshotname=`gcloud compute snapshots list --filter=$vmname | grep $vmname`
  echo "Snap found: $snapshotname."
  echo "Use this snapshot? type yes or no: "
  read snap_correct
  if [ "$snap_correct" != "yes" ]; then
    echo "Enter existing or new snapshot name: "
    read snapshotname
    echo "You typed: $snapshotname"
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

function create_new_disk_from_snap()
{
  list_snapshot
  echo "Shutting down vm before snap... please wait"
  gcloud compute instances stop $vmname --zone=$zonename
  sleep 2
  
  echo "Detaching disk..."
  gcloud beta compute instances detach-disk $vmname --zone=$zonename --disk $diskname
  sleep 3
  
  echo "Creating new disk from snapshot... this will take some time..."
  gcloud compute disks create $diskname_new --source-snapshot $snapshotname --zone=$zonename
  sleep 10  

  #Attach the disk created from step as the boot disk:
  gcloud beta compute instances attach-disk $vmname --disk $diskname_new --boot --zone=$zonename

  # Set auto-delete for the restored vm when destroyed:
  gcloud compute instances set-disk-auto-delete $vmname --disk=$diskname_new --zone=$zonename
  
  # Restart the vm
    echo "Restart the vm? yes or no "
    read restartvm
    if [ "$restartvm" == "yes" ]; then
      gcloud compute instances start $vmname --zone=$zonename
    fi
}

function delete_disk()
{
  echo "Shutting down vm $vmname... please wait..."
  gcloud compute instances stop $vmname --zone=$zonename
  #sleep 1
  echo "Are you SURE you want to delete $diskname? type yes or no: "
  read deletedisk
  
  if [ "$deletedisk" == "yes" ]; then
    echo "Detaching disk $diskname..."
    gcloud beta compute instances detach-disk $vmname --zone=$zonename --disk $diskname
    #sleep 1

    echo "Deleting disk..."
    gcloud compute disks delete $diskname --zone=$zonename
  fi
  
}

function revert_vm_from_snap () {
  list_snapshot
  echo "Shutting down vm before snap... please wait"
  gcloud compute instances stop $vmname --zone=$zonename
  sleep 2
  
  echo "Detaching disk..."
  gcloud beta compute instances detach-disk $vmname --zone=$zonename --disk $diskname_new
  sleep 2
  
  echo "Reverting snap disk back to original disk... this will take some time..."
  gcloud beta compute instances attach-disk $vmname --disk $diskname --boot --zone=$zonename
  sleep 10  

# Restart the vm
  echo "Restart the vm? yes or no "
  read restartvm
  if [ "$restartvm" == "yes" ]; then
    echo gcloud compute instances start $vmname --zone=$zonename
  fi
}

#### end functions ####


#### Start case menu ####

while true
do

  echo " 
  1. Take a snapshot
  2. Delete a snapshot
  3. Restore snap to new disk
  4. Delete disk
  5. Restart VM
  6. Revert vm back from snap to original disk
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
           Restore snap to new disk
           "
           create_new_disk_from_snap
          ;;
      4)  echo "
          -> You chose: 
           Delete disk - are you sure? This will shut down the vm, detach, and delete a disk. type yes or no: "
           read shutnow
           if [ "$shutnow" == "yes" ]; then
             delete_disk
           fi
          ;;
      5)  echo "
          -> You chose: 
           Restart VM
           "
           gcloud compute instances start $vmname --zone=$zonename
          ;;
      6)  echo "
          -> You chose: 
           Revert vm back from snap to original disk
           "
           revert_vm_from_snap
          ;;
      q)  echo "Quitting."
          exit 
          ;;
      *)  echo "Invalid selection."
          ;;
  esac
done
    
