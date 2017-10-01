# SetupMyKali
This project can automatically configure a live USB kali with a persistent encrypted partition

## Prerequisites

This script require **cryptsetup**, **parted** and **dd**.

    apt-get update && apt-get install cryptsetup

## How to use

>**Syntaxe**
>
> - Usage: 
    
    ./setupKali.sh <iso> <usb device>
> -  Example: 
  
    ./setupKali.sh /data/ISO/kali-linux-amd64.iso /dev/sdb


