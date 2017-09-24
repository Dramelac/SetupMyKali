#!/bin/bash

if [ $# -eq 0 ] || [ $# != 2 ]
  then
    echo "Arguments error"
    echo "Usage: $0 <iso> <usb device>"
    echo "Example: $0 /data/ISO/kali-linux-amd64.iso /dev/sdb"
    exit 1
fi

if [ "$EUID" -ne 0 ]
  then echo "$0: Permission denied"
  exit
fi

command -v cryptsetup >/dev/null 2>&1 || { 
    echo "I require cryptsetup but it's not installed.  Aborting." 
    echo "Try to run this script from a live kali or install cryptsetup."
    exit 1
}

#ARGS
iso=$1
device=$2

#COLOR
NC='\033[0m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'

echo -e "[${BLUE}INFO${NC}] Creating bootable Kali Linux with $iso on $device"
echo -e "[${BLUE}INFO${NC}] Please wait ... Might be long ..."
dd if=$iso of=$device bs=512k


if [ $? -ne 0 ]
  then echo -e "[${RED}ERROR${NC}] An error occured"
  exit 1
fi
echo -e "[${GREEN}OK${NC}] Success !"

part=$(parted -m /dev/sdc unit s print free | grep "free" | tail -n1)
start=$(echo $part | awk -F':' '{print $2}')
end=$(echo $part | awk -F':' '{print $3}')

echo -e "[${BLUE}INFO${NC}] Creating the Persistence Partition"
parted -s $device unit s mkpart primary $start $end
partition=$(echo $device)3

echo -e "[${BLUE}INFO${NC}] Creating encrypted partition format on $partition"
echo -e "[${BLUE}INFO${NC}] Enter your passphrase (initialization step) :"
cryptsetup -v -y luksFormat $partition
if [ $? -ne 0 ]
  then echo -e "[${RED}ERROR${NC}] An error occured"
  exit 1
fi

echo -e "[${BLUE}INFO${NC}] Enter your passphrase (unlocking step) :"
cryptsetup luksOpen $partition temp_usb
if [ $? -ne 0 ]
  then echo -e "[${RED}ERROR${NC}] An error occured"
  exit 1
fi

echo -e "[${BLUE}INFO${NC}] Creating ext4 file system"
mkfs.ext4 -L persistence /dev/mapper/temp_usb
e2label /dev/mapper/temp_usb persistence

echo -e "[${BLUE}INFO${NC}] Mount filesystem"
mkdir -p /mnt/temp_usb
mount /dev/mapper/temp_usb /mnt/temp_usb

echo -e "[${BLUE}INFO${NC}] Write persistence setting"
echo "/ union" > /mnt/temp_usb/persistence.conf

echo -e "[${BLUE}INFO${NC}] Unmount and close filesystem"
umount /dev/mapper/temp_usb
cryptsetup luksClose /dev/mapper/temp_usb

echo -e "[${GREEN}SUCCESS${NC}] USB READY !"









