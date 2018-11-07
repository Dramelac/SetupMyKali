# SetupMyKali
This project can automatically configure a live USB kali with a persistent encrypted partition

## Prerequisites

This script require **cryptsetup**, **parted**, **pv** and **dd**.

    apt-get update && apt-get install cryptsetup pv

## How to use

>**Syntaxe**
>
> - Usage: 
    
    ./setupKali.sh [OPTIONS] -i <iso> -d <usb device>
> - Help :

    ./setupKali.sh -h
> -  Example: 
  
    ./setupKali.sh -i /data/ISO/kali-linux-amd64.iso -d /dev/sdb



