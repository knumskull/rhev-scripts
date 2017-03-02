#!/bin/bash
#
#
# Copyright (c) 2016 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
API_VERSION=3

# name of virtual machine, which is used for running the repair actions
# example: my-vm
MGMT_VM=
[[ -z "$MGMT_VM" ]] && echo "Please specify the name of the virtual machine. (e.g. MGMT_VM=my-vm)" && exit 1

# define API_HOST likei, 'rhev-m.example.com'
API_HOST=""
API_URI="https://${API_HOST}/ovirt-engine/api"
API_USER=admin@internal

# the password is located separately in the file '.apipasswd' beside this script'
[[ -f '.apipasswd' ]] && [[ -n $(cat .apipasswd) ]] && API_PASSWD=$(cat .apipasswd)
[[ -z "API_PASSWD" ]] && echo "You need to specify API password in file '.apipasswd'" && exit 1

# check if ca.crt already exist
CACERT=ca.crt
[[ ! -f 'ca.crt' ]] && curl -o ca.crt "http://${API_HOST}/ovirt-engine/services/pki-resource?resource=ca-certificate&format=X509-PEM-CA"


########################################
### No modifications below this line ###
pushd `dirname $0` > /dev/null
BASE=$(pwd -P)
popd > /dev/null


API_CREDENTIALS="${API_USER}:${API_PASSWD}"

api_call () {
  api_uri=$1
  rc=$(curl -s --cacert ${CACERT} -X GET -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/${api_uri}")
  echo $rc
}

get_vm_id () {
  vm_name=$1
  vm_id=$(curl -s --cacert ${CACERT} -X GET -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/vms?search={$vm_name}"  | python -c "import sys, json; print json.load(sys.stdin)['vm'][0]['id']") 
  echo $vm_id
}

create_snapshot_of_vmid () {
  vm_id=$1
  snap_id=$(curl -s --cacert ${CACERT} -X POST -k -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/vms/$vm_id/snapshots" -d '<snapshot><description>AUTOMATIC SNAPSHOT FOR XFS-CHECK</description></snapshot>' | python -c "import sys, json; print json.load(sys.stdin)['id']")
  echo $snap_id
}

check_snapshot_status () {
  vm_id=$1
  snapshot_id=$2
  snap_status=$(curl -s --cacert ${CACERT} -X GET -k -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/vms/$vm_id/snapshots/${snapshot_id}" | python -c "import sys, json; print json.load(sys.stdin)['snapshot_status']" 2>/dev/null)
  echo $snap_status
}

get_disk_count () {
  vm_id=$1
  snapshot_id=$2
  count=$(curl -s --cacert ${CACERT} -X GET -k -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/vms/$vm_id/snapshots/${snapshot_id}/disks" | python -c "import sys, json; print len(json.load(sys.stdin)['disk'])")
  echo $count
}

get_disk_id () {
  vm_id=$1
  snapshot_id=$2
  [[ -z "$3" ]] && disk_cnt=0 || disk_cnt=$3
  disk_id=$(curl -s --cacert ${CACERT} -X GET -k -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/vms/${vm_id}/snapshots/${snapshot_id}/disks" | python -c "import sys, json; print json.load(sys.stdin)['disk'][$disk_cnt]['id']")
  echo $disk_id
}

get_disk_snapshot_id () {
  disk_snapshot_id=$(curl -s --cacert ${CACERT} -X GET -k -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/vms/$vm_id/snapshots/cc15f6f2-bbcc-47bf-91fa-5a4a9aa646ca/disks" | python -c "import sys, json; print json.load(sys.stdin)['disk'][0]['snapshot']['id']")
}

attach_disk_to_vm () {
    DISK_ID=$1
    DISK_SNAPSHOT_ID=$2
    VM_ID=$3
    rc=$(curl -s --cacert ${CACERT} -X POST -k -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/vms/${VM_ID}/disks" -d "<disk id=\"${DISK_ID}\"><snapshot id=\"${DISK_SNAPSHOT_ID}\"/><active>true</active></disk>")
}

detach_disk_from_vm () {
    vm_id=$1
    disk_id=$2
    rc=$(curl -s --cacert ${CACERT} -X DELETE -k -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/vms/${vm_id}/disks/${disk_id}" -d "<action><detach>true</detach></action>")
}

delete_snapshot () {
  vm_id=$1
  snapshot_id=$2
  rc=$(curl -s --cacert ${CACERT} -X DELETE -k -H "Content-Type: application/xml" -H "Accept: application/json" -u "${API_CREDENTIALS}" "${API_URI}/vms/${vm_id}/snapshots/${snapshot_id}")
}

check_mounted () {
  device=$1
  mount | grep ${device} >/dev/null; echo $?
}


mount_cycle () {
  device=$1
  if [ 0 -eq $(check_mounted ${device}) ]; then
    umount ${device}
  fi
  if [ ! -d /mnt ]; then
    mkdir /mnt
  fi
  mount ${device} /mnt 
  umount ${device}
}

xfs_check () {
  /usr/sbin/xfs_repair -n "$1"
}


xfs_repair () {
  /usr/sbin/xfs_repair "$1"
}

check_blk_device () {
  blk_dev=$1
  dev_name=${blk_dev##/dev*/}
  mount_cycle "${blk_dev}" >"$log_path/${dev_name}-mount" 2>&1
  xfs_check "${blk_dev}" >"$log_path/${dev_name}-check" 2>&1
  xfs_repair "${blk_dev}" >"$log_path/${dev_name}-repair" 2>&1
  xfs_repair "${blk_dev}" >"$log_path/${dev_name}-post" 2>&1
}

check_lvm_device () {
  PV=$1
  VG=$(/usr/sbin/lvm pvs ${PV} |grep ${PV} | awk -F" " '{print $2}')
  VG_UUID=$(/usr/sbin/lvm lvs -a -o devices,vg_uuid | grep ${PV}| awk -F" " '{print $2}')
  # activate the locigal volume
  /usr/sbin/lvm vgchange -ay ${VG} >"${log_path}/activity.log"

  for LV in $(/usr/sbin/lvm lvs | grep ${VG} | grep -v swap | awk -F" " '{print $1}'); do
    lv_dev="/dev/${VG}/${LV}"
    dev_name=${lv_dev##/dev*/}
    mount_cycle "${lv_dev}" >"$log_path/${VG}-${dev_name}-mount" 2>&1
    xfs_check "${lv_dev}" >"$log_path/${VG}-${dev_name}-check" 2>&1
    xfs_repair "${lv_dev}" >"$log_path/${VG}-${dev_name}-repair" 2>&1
    xfs_repair "${lv_dev}" >"$log_path/${VG}-${dev_name}-post" 2>&1
  done

  # deactivate logical volume
  /usr/sbin/lvm vgchange -an ${VG} >"${log_path}/activity.log"
}

check_devices () {
  VMNAME=$1
  DEVICE_FILE=$2 

  # logging
  log_base="${BASE}/logging"
  log_path=$log_base/$VMNAME
  [[ ! -d "$log_path" ]] && mkdir -p $log_path

  while IFS='' read -r line || [[ -n "$line" ]]; do
    DEV=$(echo $line | cut -d" " -f2)
     # skip if no device is found
    [[ -z "$DEV" ]] && continue

    if [ 0 -eq $(echo $line | grep -e 'LVM' >/dev/null;echo $?) ]; then 
      check_lvm_device "$DEV"
    else
      check_blk_device "$DEV"
    fi

 done < "$DEVICE_FILE"
}


### Run Actions ###

MGMT_VM_ID=$(get_vm_id ${MGMT_VM})


do_check_vm () {
  current_vm=$1

  # 1. create snapshot on VM, which needs to be checked and wait until the snapshot is created (while snapshot status locked)
  # 2. count number of disks in the recently created snapshot
  # 3. attach each disk to the virtual machine, which is checking the filesystems
  # 4. run the check routine on the filesystem
  # 4.1. running a mount-cycle for replaying filesystem log and log the activity
  # 4.2. when filesystem is unmounted, do a 'xfs_repair -n', followed by 'xfs_repair' twice. In sum 
  #      you're running xfs_repair 3 times. All activity needs to be logged.
  # 5. detaching the disks from the virtual machine, which checked the filesystems
  # 6. deleting the snapshot and wait until the snapshot is deleted (while snapshot status locked)
  # 7. replay this step with another virtual machine


  # select VM for check
  VMID=$(get_vm_id $current_vm)
  # 1. create snapshot
  echo "[$(date '+%c')] creating snapshot of VM ${current_vm} (id: $VMID) ..." | tee -a activity.log
  SNAPSHOT_ID=$(create_snapshot_of_vmid $VMID)
 
  # check_snapshot_status $VMID $SNAPSHOT_ID
  # wait until snapshot isn't locked
  while [[ "locked" == "$(check_snapshot_status $VMID $SNAPSHOT_ID)" ]]; do sleep 2; done
  RC=$(check_snapshot_status $VMID $SNAPSHOT_ID >/dev/null 2>&1 | echo $?) 
  # check if the snapshot is created successfully
  if [ 0 -eq ${RC} ]; then
    echo "[$(date '+%c')] snapshot (id: ${SNAPSHOT_ID}) created." | tee -a activity.log
  else
    echo "[$(date '+%c')] failed to create snapshot (id: ${SNAPSHOT_ID}). Aborting!" | tee -a activity.log
    exit 1
  fi

  cnt=$(get_disk_count $VMID $SNAPSHOT_ID)
  for ((i=0; i<cnt; i++)) 
  do 
    DID=$(get_disk_id $VMID $SNAPSHOT_ID $i)
    # before attaching the disk to VM, the communication file between udev and this script needs to be flushed
    echo > /tmp/added-xfs-devices.log
    echo "[$(date '+%c')] Attaching Disk (id: $DID) to VM $MGMT_VM (id: $MGMT_VM_ID) ..." | tee -a activity.log
    attach_disk_to_vm $DID $SNAPSHOT_ID $MGMT_VM_ID
    echo "[$(date '+%c')] Disk (id: $DID) was attached." | tee -a activity.log

    echo "[$(date '+%c')] running check on filesystem of disk (id: $DID)" | tee -a activity.log

    ##### critical part #####
    # just to be sure, the udev rules was running, wait 2 seconds
    sleep 2
    # aborting, if the communication file does not exist. 
    if [ ! -f '/tmp/added-xfs-devices.log' ]; then
      echo "something went wrong. The disks could not be identified. Nothing will be checked." 
    else
      check_devices "${current_vm}" "/tmp/added-xfs-devices.log"
    fi
    ##### end critical part #####
  
    echo "[$(date '+%c')] detaching Disk (id: $DID) from VM $MGMT_VM (id: $MGMT_VM_ID) ..." | tee -a activity.log
    detach_disk_from_vm $MGMT_VM_ID $DID
    sleep 5
    echo "[$(date '+%c')] Disk (id: $DID) was detached." | tee -a activity.log
  done

  echo "[$(date '+%c')] deleting snapshot (id: ${SNAPSHOT_ID}) from VM $current_vm ..." | tee -a activity.log
  delete_snapshot $VMID $SNAPSHOT_ID

  # check_snapshot_status $VMID $SNAPSHOT_ID
  while [[ "locked" == "$(check_snapshot_status $VMID $SNAPSHOT_ID)" ]]; do sleep 2; done
  echo "[$(date '+%c')] snapshot (id: ${SNAPSHOT_ID}) deleted." | tee -a activity.log
}

###########  MAIN  ###########

# call the do_check_vm routine with parameter 'name of the vm, which needs to be checked'
[[ ! -z "$1" ]] && do_check_vm "$1"
