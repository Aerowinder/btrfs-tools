#!/bin/bash

set -euo pipefail

# Global Variables
BTRFS_SUBVOLUMES=(/ /home) # / = root, /home = home
DIR_SNAPSHOT=".snapshots"
MAX_SNAPSHOT=8 # Per subvolume

for subvol in "${BTRFS_SUBVOLUMES[@]}"; do
    subvol_name="${subvol//\//}"
    if [[ -z "$subvol_name" ]]; then
        subvol_name="root"
    fi

    snapshot_root="/snapshots"
    snapshot_name=${subvol_name}-$(date +%Y%m%d-%H%M%S)

    # Check if "snapshots" top-level subvolume is accessible to the system.
    if ! btrfs subvolume show $snapshot_root &>/dev/null; then
        echo "[$subvol_name] Error: Snapshot not taken on $subvol_name, subvolume does not exist. You must create the top-level subvolume manually, then use fstab to mount it to $snapshot_root."
        logger -t "btrfs-snapshot" -p user.notice "[$subvol_name] Error: Snapshot not taken on $subvol_name, subvolume does not exist."
        continue
    fi

    # Check if subvolume exists
    if [[ ! -d "$subvol" ]]; then
        echo "[$subvol_name] Error: Snapshot not taken on ${subvol_name}, subvolume does not exist."
        logger -t "btrfs-snapshot" -p user.notice "[$subvol_name] Error: Snapshot not taken on ${subvol_name}, subvolume does not exist."
        continue
    fi

    # Create read-only snapshot
    echo "[$subvol_name] Creating snapshot: $snapshot_root/$snapshot_name"
    logger -t btrfs-snapshot -p user.notice "[$subvol_name] Creating snapshot: $snapshot_root/$snapshot_name"
    btrfs subvolume snapshot -r "$subvol" "$snapshot_root/$snapshot_name"

    # Cleanup old snapshots
    cd "$snapshot_root"
    snapshots=($(ls -1d "${subvol_name}-"*/ 2>/dev/null | sort))

    count=${#snapshots[@]}

    if (( count > MAX_SNAPSHOT )); then
        delete_count=$((count - MAX_SNAPSHOT))
        for ((i=0; i<delete_count; i++)); do
            echo "[$subvol] Deleting old snapshot: ${snapshots[i]}"
            logger -t btrfs-snapshot -p user.notice "[$subvol] Deleting old snapshot: ${snapshots[i]}"
            btrfs subvolume delete "$snapshot_root/${snapshots[i]}"
        done
    fi

    echo ""
done

#Changelog
#2025-11-18 - AS - v2, Split into top-level and sub-level versions.
#2025-11-18 - AS - v1, First release.
