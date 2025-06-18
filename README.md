# Proxmox Setup

Proxmox setup for `bagel`

## Install

***Not automated***

Use ZFS with RAID0 on a single disk during setup. Doing this because then I can just update it to add whatever other disks automatically later.

## Disk setup

### ZFS Setup

Adds other disks to ZFS pool. `disks` in `data.json` contains the IDs of the original install disk (`install`) and the ones to be added to the ZFS pool (`others`). See `ls /dev/disk/by-id` for the disk identifiers.

### Other disks

## Repo configuration

Proxmox repos are replaced with their no-subscription variants.

## Program installation

Programs are installed according to `programs` in `data.json`

## TODO

- ~~host smb share~~
- ~~set proxmox community repos~~
- ~~add ssh keys~~
- ~~assemble server~~
- ~~set up smb share mounting on server~~
- zram-generator on server
- ~~get ssd off btrfs (in progress)~~
