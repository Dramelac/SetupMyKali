#!/bin/bash

#COLOR
NC='\033[0m' # No color
BOLD='\033[1m'
GREEN='\033[0;32m'${BOLD}
BLUE='\033[0;34m'${BOLD}
ORANGE='\033[0;33m'${BOLD}
RED='\033[0;31m'${BOLD}

function tryAndExit {
    command=$1

    while true; do
      eval $command && break
      if ask "[${RED}ERROR${NC}] Fail ! Retry?" Y; then
        sleep 1
      else
        echo -e "[${RED}ERROR${NC}] Execution aborted"
        exit 1
      fi
    done

}

function ask() {
    # https://djm.me/ask
    local prompt default reply

    while true; do

        if [[ "${2:-}" = "Y" ]]; then
            prompt="Y/n"
            default=Y
        elif [[ "${2:-}" = "N" ]]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -en "$1 [$prompt] "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read reply </dev/tty

        # Default?
        if [[ -z "$reply" ]]; then
            reply=${default}
        fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}

function setupPassword(){
    while true; do
        local pwd1='a'
        local pwd2=''
        echo -ne "[${GREEN}?${NC}] Please enter your password: "
        read -s pwd1 </dev/tty
        echo -ne "\n[${GREEN}?${NC}] Confirm your password: "
        read -s pwd2 </dev/tty
        echo

        if [[ "$pwd1" == "$pwd2" ]]; then
            password=${pwd1}
            return 0
        fi
        echo -e "[${RED}ERROR${NC}] Passwords don't match !"
    done

    
}

#ARGS
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case ${key} in
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

if [[ ! -z ${help} ]]
  then
    echo "Setup My Kali -- help"
    echo "Usage: $0 [OPTIONS] -i <iso> -d <usb device>"
    echo "Automated creation of a usb bootable key on Kali Linux with an encrypted persistence partition"
    echo ""
    echo "Mandatory arguments :"
    echo "  -i, --iso           path to kali iso image"
    echo "  -d, --device        path to usb device (for example : /dev/sdc)"
    echo ""
    echo "Optional arguments :"
    # echo "  -v, --verbose       verbose mode (WIP)"
    echo "  -h, --help          print this help message"
    echo ""
    echo "Tools from : https://github.com/Dramelac/SetupMyKali"

    exit 0
fi

if [[ -z ${iso} ]] || [[ -z ${device} ]]
  then
    echo "Arguments error"
    echo "Usage: $0 -i <iso> -d <usb device>"
    echo "Try -h or --help for more information."
    echo "Example: $0 -i /data/ISO/kali-linux-amd64.iso -d /dev/sdb"
    exit 1
fi

# This script must be executed as root
if [[ "$EUID" -ne 0 ]]
  then echo "$0: Permission denied"
  exit
fi

# Dependencies checks

command -v cryptsetup >/dev/null 2>&1 || {
    echo -e "[${RED}ERROR${NC}] This script require cryptsetup but it's not installed."
    echo -e "[${BLUE}INFO${NC}] Try to run this script from a live kali or install cryptsetup."
    if command -v apt-get >/dev/null 2>&1 && ask "[${GREEN}?${NC}] Do you want to try to install it automatically?" Y; then
        apt-get update && apt-get install cryptsetup || exit 1
    else
        echo -e "[${RED}INFO${NC}] Aborting."
        exit 1
    fi
}

command -v parted >/dev/null 2>&1 || {
    echo -e "[${RED}ERROR${NC}] This script require parted but it's not installed."
    echo -e "[${BLUE}INFO${NC}] Try to run this script from a live kali or install parted."
    if command -v apt-get >/dev/null 2>&1 && ask "[${GREEN}?${NC}] Do you want to try to install it automatically?" Y; then
        apt-get update && apt-get install parted || exit 1
    else
        echo -e "[${RED}INFO${NC}] Aborting."
        exit 1
    fi
}

pv_installed=1
command -v pv >/dev/null 2>&1 || {
    echo -e "[${ORANGE}INFO${NC}] PV was not detected on your system."
    if command -v apt-get >/dev/null 2>&1 && ask "[${GREEN}?${NC}] This package is not mandatory but recommended. Do you want to try to install it automatically?" Y; then
        apt-get update && apt-get install pv || exit 1
    else
        echo -e "[${BLUE}INFO${NC}] Resume execution without pv..."
        pv_installed=0
    fi
}

# Starting setup
echo -e "[${BLUE}INFO${NC}] Creating bootable Kali Linux with $iso on $device"

echo -e "[${ORANGE}WARNING${NC}] This script will${BOLD} DEFINITIVELY DELETE${NC} all the data present on ${BOLD}${device}${NC}"
ask "[${GREEN}?${NC}] Are you sure you want to continue?" Y || exit 0

setupPassword

# Burning kali ISO
echo -e "[${BLUE}INFO${NC}] Please wait ... Might be (very) long ..."
if [[ ${pv_installed} -eq 1 ]]; then
    dd if=${iso} status=none | pv -s `du -k "$iso" -b | cut -f1` | dd of=${device} status=none
else
    dd if=${iso} of=${device}
fi


if [[ $? -ne 0 ]]; then
    echo -e "[${RED}ERROR${NC}] An error occurred"
    exit 1
fi
echo -e "[${GREEN}OK${NC}] Kali installed successfully !"

# Determine free left space on USB device
part=$(parted -m ${device} unit s print free | grep "free" | tail -n1)
start=$(echo ${part} | awk -F':' '{print $2}')
end=$(echo ${part} | awk -F':' '{print $3}')

echo -e "[${BLUE}INFO${NC}] Creating the Persistence Partition"
parted -s ${device} unit s mkpart primary ${start} ${end}
partition=$(echo ${device})3

echo -e "[${BLUE}INFO${NC}] Creating encrypted partition format on $partition"

# Using luks format to encrypt data on this partition
tryAndExit "echo ${password} | cryptsetup luksFormat ${partition}"
tryAndExit "echo ${password} | cryptsetup luksOpen ${partition} temp_usb"

echo -e "[${BLUE}INFO${NC}] Creating ext4 file system .. Please wait ..."
mkfs.ext4 -L persistence /dev/mapper/temp_usb > /dev/null
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
