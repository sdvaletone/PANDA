#!/bin/bash

# Install required packages if not already installed
sudo apt-get update
sudo apt-get install -y nfs-common

# Discover available NFS shares on the network
echo "Scanning for NFS shares..."
sudo showmount -e

# Prompt user to input the NFS server and share path
read -p "Enter the NFS server IP or hostname: " nfs_server
read -p "Enter the NFS share path (e.g., /mnt/share): " nfs_share
read -p "Enter the local mount point (e.g., /mnt/nfs): " local_mount

# Create local mount point if it doesn't exist
sudo mkdir -p $local_mount

# Mount the NFS share
sudo mount -t nfs $nfs_server:$nfs_share $local_mount

# Verify if mount was successful
if mountpoint -q $local_mount; then
    echo "NFS share successfully mounted."

    # Update /etc/fstab for persistence
    echo "$nfs_server:$nfs_share $local_mount nfs defaults 0 0" | sudo tee -a /etc/fstab

    echo "Mount point added to /etc/fstab for persistence."
else
    echo "Failed to mount NFS share."
fi
