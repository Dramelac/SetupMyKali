#!/bin/bash

function tryAndExit {
    command=$1
    trycpt=$2
    if [ -z "$2" ]
      then
        trycpt=3 # Never trust
    fi

    i=0
    until [ $i -ge $trycpt ]
    do
      $command && break
      i=$[$i+1]
      echo -e "[${RED}ERROR${NC}] Fail ! Retry [$i/$trycpt]"
      sleep 1
    done

    if [ $i -ge $trycpt ]
      then echo -e "[${RED}ERROR${NC}] An error occured"
      exit 1
    fi

}

command -v cryptsetup >/dev/null 2>&1 || { 
    echo "I require cryptsetup but it's not installed.  Aborting." 
    echo "Try to run this script from a live kali or install cryptsetup."
    exit 1
}

#ARGS
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -i|--iso)
    iso="$2"
    shift # past argument
    shift # past value
    ;;
    -d|--device)
    device="$2"
    shift # past argument
    shift # past value
    ;;
    -v|--verbose)
    verbose=YES
    shift # past argument
    ;;
    -h|--help)
    help=YES
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [ ! -z $help ]
  then
    echo "Setup My Kali -- help"
    echo "Usage: $0 [OPTION] -i <iso> -d <usb device>"
    echo "Automated creation of a usb bootable key on Kali Linux with an encrypted persistence partition"
    echo ""
    echo "Mandatory arguments :"
    echo "  -i, --iso           path to kali iso image"
    echo "  -d, --device        path to usb device (for example : /dev/sdc)"
    echo ""
    echo "Optional arguments :"
    echo "  -v, --verbose       verbose mode (WIP)"
    echo "  -h, --help          print this help message"
    echo ""
    echo "Tools from : https://github.com/Dramelac/SetupMyKali"

    exit 0
fi

if [ -z $iso ] || [ -z $device ]
  then
    echo "Arguments error"
    echo "Usage: $0 -i <iso> -d <usb device>"
    echo "Try -h or --help for more information."
    echo "Example: $0 /data/ISO/kali-linux-amd64.iso /dev/sdb"
    exit 1
fi

if [ "$EUID" -ne 0 ]
  then echo "$0: Permission denied"
  exit
fi

#COLOR
NC='\033[0m' # No color
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'

echo -e "[${BLUE}INFO${NC}] Creating bootable Kali Linux with $iso on $device"


echo -e "[${BLUE}INFO${NC}] Please wait ... Might be (very) long ..."
# dd if=$iso of=$device bs=512k


if [ $? -ne 0 ]
  then echo -e "[${RED}ERROR${NC}] An error occured"
  exit 1
fi
echo -e "[${GREEN}OK${NC}] Success !"

# Determine free left space on USB device
part=$(parted -m /dev/sdc unit s print free | grep "free" | tail -n1)
start=$(echo $part | awk -F':' '{print $2}')
end=$(echo $part | awk -F':' '{print $3}')

echo -e "[${BLUE}INFO${NC}] Creating the Persistence Partition"
#parted -s $device unit s mkpart primary $start $end
partition=$(echo $device)3

echo -e "[${BLUE}INFO${NC}] Creating encrypted partition format on $partition"
echo -e "[${BLUE}INFO${NC}] Enter your passphrase (initialization step) :"
# Using luks format to encrypt data on this partition
tryAndExit "cryptsetup -v -y luksFormat $partition" 5

echo -e "[${BLUE}INFO${NC}] Enter your passphrase (unlocking step) :"
tryAndExit "cryptsetup luksOpen $partition temp_usb" 2

echo -e "[${BLUE}INFO${NC}] Creating ext4 file system"
mkfs.ext4 -L persistence /dev/mapper/temp_usb
e2label /dev/mapper/temp_usb persistence

echo -e "[${BLUE}INFO${NC}] Mount filesystem"
mkdir -p /mnt/temp_usb
mount /dev/mapper/temp_usb /mnt/temp_usb

echo -e "[${BLUE}INFO${NC}] Write persistence setting"
# Writing kali configuration to enable persistence
echo "/ union" > /mnt/temp_usb/persistence.conf

echo -e "[${BLUE}INFO${NC}] Unmount and close filesystem"
umount /dev/mapper/temp_usb
cryptsetup luksClose /dev/mapper/temp_usb

echo -e "[${GREEN}SUCCESS${NC}] USB READY !"


