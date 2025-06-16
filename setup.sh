#!/usr/bin/env bash
set -euxo pipefail
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
    disk=$(readlink -f /dev/disk/by-id/$id)
    if ! $(zpool status rpool | grep -q "${disk##*/}"); then
        zpool add rpool $disk
    else
        echo $disk already added to pool, skipping
    fi
done

### Other disk setup ###
mkdir -p /mnt/media{0,1,2,3} /mnt/cache /mnt/media
while read line; do
    if ! grep -q "$line" /etc/fstab; then
        echo "$line" | tee -a /etc/fstab
    fi
done <$SCRIPT_DIR/fstab
mount -a || true
read -p "If it's safe to continue, press enter. Otherwise, do ^C to exit."
systemctl daemon-reload

### Program installation ###
apt install $(jq ."programs"[]? $SCRIPT_DIR/data.json -r | tr '\n' ' ') -y

sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port 2222/g' /etc/ssh/sshd_config

### SMB - Share to the server ###
apt install samba -y

while read line; do
    if ! grep -q "$line" /etc/samba/smb.conf; then
        echo "$line" | tee -a /etc/samba/smb.conf
    fi
done <$SCRIPT_DIR/smb.conf
systemctl restart smbd
# ASSUMES USER IS ROOT
# ASSUMES SMB SHOULD BE ROOT
smb_user="root"
if ! $(pdbedit -L -v | grep -q "Unix username: .*$smb_user"); then
    read -p "Enter the SMB password at the prompt - press enter to continue"
    smbpasswd -a $smb_user
fi
