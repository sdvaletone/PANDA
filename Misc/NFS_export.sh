#!/bin/bash

# Function to restart NFS services
restart_nfs() {
    echo "Restarting NFS services..."
    sudo exportfs -ra
    sudo systemctl restart nfs-kernel-server
    echo "NFS services restarted."
}

# Backup current /etc/exports file
backup_exports() {
    sudo cp /etc/exports /etc/exports.bak
    echo "Backup of /etc/exports created at /etc/exports.bak"
}

# Main script
main() {
    echo "Enter NFS shares you want to export."
    echo "Enter 'done' when finished."

    backup_exports

    # Clear the /etc/exports file
    sudo truncate -s 0 /etc/exports

    while true; do
        read -p "Enter the path to share: " share_path
        if [[ "$share_path" == "done" ]]; then
            break
        fi

        read -p "Enter the client (e.g., 192.168.1.0/24): " client

        # Default NFSv4 options
        options="rw,sync,no_root_squash,no_subtree_check,noatime"

        echo "$share_path $client($options)" | sudo tee -a /etc/exports > /dev/null
    done

    # Display the updated /etc/exports file
    echo "Updated /etc/exports file:"
    cat /etc/exports

    restart_nfs
}

# Run the main function
main


##/TV_shows 192.168.1.0/24(rw,sync,no_root_squash,no_subtree_check,noatime)
##/Movies   192.168.1.0/24(rw,sync,no_root_squash,no_subtree_check,noatime)
##/Storage  192.168.1.0/24(rw,sync,no_root_squash,no_subtree_check,noatime)