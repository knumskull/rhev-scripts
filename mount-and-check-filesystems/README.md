# Disk mount and Repair

## Description
This script is for checking xfs-filesystems of running virtual machines. As by design this is not possible, one can use some kind of management-virtual-machine, which will create a snapshot of the VM, which needs to be checked and attach these disks to itself. Then the filesystem can be checked.
The motivation to do this, is to have a knowledge, if this machine needs to be maintained or not. The cause was a former outage, which caused a lot of XFS corruptions.

## Installation
All files must be copied to the same virtual machine in the RHEV cluster.
To use the latest available `xfs_repair` utility, you need to run RHEL 7.3 with errata [RHBA-2017-0100](https://rhn.redhat.com/errata/RHBA-2017-0100.html) installed.

### Copy scripts
Copy the files `api-xfs-check.sh`, `partition-check.sh` and `partition-clear.sh` to `/root`.

### Install udev-rule
Copy the file `udev.rules/99-xfs-check.rules` to `/etc/udev/rules.d` and reload rules.
~~~
udevadm control --reload-rules
udevadm trigger
~~~

### Setup Configuration
Open file `api-xfs-check.sh` and define the variables `MGMT_VM`, `API_HOST` and `API_USER`. 

Example:
~~~
MGMT_VM=my-vm
API_HOST="rhev-m.example.com"
API_USER=admin@internal
~~~

### Setup password
The password for the RHEV-API user is stored in the file `.apipasswd` beside the script `api-xfs-check.sh`.
Example:
~~~
$: cat .apipasswd
redhat
~~~

For gaining a minimum of security, this file should not be accessible by others than the owner itself.
~~~
chmod 600 .apipasswd
~~~

## Usage
Using this script by simply execute `api-xfs-check.sh` with the name of a virtual machine as first parameter.
The virtual machine, where this script is executed need to have access to RHEV-API.
~~~
./api-xfs-check.sh my-simple-vm
~~~
This script will run through following steps.

* create snapshot on VM, which needs to be checked and wait until the snapshot is created (while snapshot status locked)
* count number of disks in the recently created snapshot
* attach each disk to the virtual machine, which is checking the filesystems
* run the check routine on the filesystem
  * running a mount-cycle for replaying filesystem log and log the activity
  * when filesystem is unmounted, do a `xfs_repair -n`, followed by `xfs_repair` twice. In sum you're running xfs_repair 3 times. All activity will be logged.
* detaching the disks from the virtual machine, which checked the filesystems
* deleting the snapshot and wait until the snapshot is deleted (while snapshot status locked)


## Disclaimer
There is no warranty on success by using these scripts. You will use these scripts on your own risk.
