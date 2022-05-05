#!/bin/bash
# Menu to choose options related to creating snapshots in GCP

# READ vmname
echo "Enter VM name: "
read vmname
echo "Enter zone name: "
read zonename
echo "Enter storage location such as northamerica-northeast1 or europe-west4: "
read storagelocation
echo "Enter disk name: "
read diskname
echo "Enter snapshot name: "
read snapshotname
diskname_new=$diskname-restored


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
  
  read -p "Choose your option 1-6 or quit: " choice

  case $choice in
      1)  echo "
          -> You chose:
           Take a snapshot:
           echo gcloud compute disks snapshot $diskname --zone=$zonename --snapshot-names=$snapshotname --storage-location=$storagelocation --description='snapshot created for $vmname'
           "
           exit
          ;;
      2)  echo "
          -> You chose: 
           Delete a snapshot:
           echo gcloud compute snapshots delete $snapshotname --zone=$zonename 
           "
          ;;
      3)  echo "
          -> You chose:
           Restore snap to new disk"
           # Call function
           detach_and_create_snap
          ;;
      4)  echo "
          -> You chose: 
           Delete disk, are you sure you want to shut down the vm, detach, and delete a disk?"
           read shutnow
           if [ "$shutnow" == "yes" ]; then
             delete_disk
           fi
          ;;
      5)  echo "
          -> You chose: 
           Restart VM"
           echo gcloud compute instances start $vmname --zone=$zonename
          ;;
      6)  echo "
          -> You chose: 
           Revert vm back from snap to original disk"
          ;;
      q)  echo "Quitting."
          exit 
          ;;
      *)  echo "Invalid selection."
          ;;
  esac
done
    

# function
detach_and_create_snap () {
  echo "Shutting down vm before snap... please wait"
  echo gcloud compute instances stop $vmname --zone=$zonename
  sleep 10
  
  echo "Detaching disk..."
  echo gcloud beta compute instances detach-disk $vmname --zone=$zonename --disk $diskname
  sleep 5
  
  echo "Creating new disk from snapshot..."
  echo gcloud compute disks create $diskname_new --source-snapshot $snapshotname --zone=$zonename
  sleep 10  

  #Attach the disk created from step as the boot disk:
  echo gcloud beta compute instances attach-disk $vmname --disk $diskname_new --boot --zone=$zonename

  # Set auto-delete for the restored vm when destroyed:
  echo gcloud compute instances set-disk-auto-delete $vmname --disk=$diskname_new --zone=$zonename
  
  # Restart the vm
    echo "Restart the vm? yes or no "
    read restartvm
    if [ "$restartvm" == "yes" ]; then
      echo gcloud compute instances start $vmname --zone=$zonename
    fi
}

# function
delete_disk () {
  echo "Shutting down vm... please wait"
  echo gcloud compute instances stop $vmname --zone=$zonename
  sleep 10
  echo "Detaching disk..."
  echo gcloud beta compute instances detach-disk $vmname --zone=$zonename --disk $diskname
  sleep 5
  echo "Deleting disk..."
  echo gcloud compute disks delete $diskname --zone=$zonename
}

# function
revert_vm_from_snap () {
  echo "Shutting down vm before snap... please wait"
  echo gcloud compute instances stop $vmname --zone=$zonename
  sleep 10
  
  echo "Detaching disk..."
  echo gcloud beta compute instances detach-disk $vmname --zone=$zonename --disk $diskname_new
  sleep 5
  
  echo "Reverting snap disk back to original disk..."
  echo gcloud beta compute instances attach-disk $vmname --disk $diskname --boot --zone=$zonename
  sleep 10  

# Restart the vm
  echo "Restart the vm? yes or no "
  read restartvm
  if [ "$restartvm" == "yes" ]; then
    echo gcloud compute instances start $vmname --zone=$zonename
  fi
}