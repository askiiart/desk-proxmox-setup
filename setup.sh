#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

if [ $(whoami) -ne "root"]; then
    echo "not root, exiting"
fi

### Repo setup ###
if [ -e /etc/apt/sources.list.d/pve-enterprise.list ]; then
    rm /etc/apt/sources.list.d/pve-enterprise.list
fi
echo 'deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription' | tee /etc/apt/sources.list.d/pve-no-subscription.list
sed -i 's/enterprise\.proxmox\.com/download.proxmox.com/g' /etc/apt/sources.list.d/ceph.list
sed -i 's/enterprise/no-subscription/g' /etc/apt/sources.list.d/ceph.list

### initial setup ###
apt update
apt install jq -y

### ZFS setup ###

# import storage pool
if ! zpool status storage; then
    zpool import -f storage
else
    echo "storage pool already imported"
fi

# add rpool disks
for id in $(jq ."disks"."other"[]? $SCRIPT_DIR/data.json -r); do
    if ! $(zpool status rpool | grep -q "$id"); then
        zpool add rpool $id
    else
        echo $id already added to pool, skipping
    fi
done

### Other disk setup ###
mkdir -p /mnt/media{0,1,2,3} /mnt/cache /mnt/media
IFS=$'\n'
for key in $(jq '."fstab"[]?' $SCRIPT_DIR/data.json -r); do
    if ! grep -q "$key" /etc/fstab; then
        echo "$key" | tee -a /etc/fstab
    fi
done
unset IFS
mount -a || true
read -p "If it's safe to continue, press enter. Otherwise, do ^C to exit."
systemctl daemon-reload

### Program installation ###
apt install $(jq ."programs"[]? $SCRIPT_DIR/data.json -r | tr '\n' ' ') -y

sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port 2222/g' /etc/ssh/sshd_config

### NFS ###
IFS=$'\n'
for key in $(jq '."exports"[]?' $SCRIPT_DIR/data.json -r); do
    if ! grep -q "$key" /etc/exports; then
        echo "$key" | tee -a /etc/exports
    fi
done
unset IFS
exportfs -arv
systemctl enable --now nfs-server

IFS=$'\n'
for key in $(jq '."ssh-keys"[]?' $SCRIPT_DIR/data.json -r); do
    if ! grep -q "$key" $HOME/.ssh/authorized_keys; then
        echo "$key" | tee -a $HOME/.ssh/authorized_keys
    fi
done
unset IFS
