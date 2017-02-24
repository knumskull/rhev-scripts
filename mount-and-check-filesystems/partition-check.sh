#!/bin/bash
DEVICE=$1

# this rule will put the added xfs-device to a temporary file, which can be used for further checking

echo "$ID_FS_TYPE $DEVNAME" >> /tmp/added-xfs-devices.log


