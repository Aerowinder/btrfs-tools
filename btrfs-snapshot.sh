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

    snapshot_root="$subvol/$DIR_SNAPSHOT"
    snapshot_name=${subvol_name}-$(date +%Y%m%d-%H%M%S)

    # Check if subvolume exists
    if [[ ! -d "$subvol" ]]; then
        echo "[$subvol] Error: Snapshot not taken on ${subvol}, subvolume does not exist."
        logger -t "btrfs-snapshot" -p user.notice "[$subvol] Error: Snapshot not taken on ${subvol}, subvolume does not exist."
        continue
    fi


    # Check if the subvolume has a .snapshots subvolume. If it does not, create it.
    if ! btrfs subvolume show "$snapshot_root" &>/dev/null; then
        if [[ -e "$snapshot_root" ]]; then
            echo "[$subvol] Error: Snapshot not taken on $snapshot_root, .snapshots exists but is not a subvolume."
            logger -t "btrfs-snapshot" -p user.notice "[$subvol] Error: Snapshot not taken on $snapshot_root, .snapshots exists but is not a subvolume."
            continue
        fi
        echo "[$subvol] Creating .snapshots subvolume on $subvol"
        logger -t "btrfs-snapshot" "[$subvol] Creating .snapshots subvolume on $subvol."
        btrfs subvolume create "$snapshot_root"
    fi

    # Create read-only snapshot
    echo "[$subvol] Creating snapshot: $snapshot_root/$snapshot_name"
    logger -t btrfs-snapshot -p user.notice "[$subvol] Creating snapshot: $snapshot_root/$snapshot_name"
    btrfs subvolume snapshot -r "$subvol" "$snapshot_root/$snapshot_name"

    # Cleanup old snapshots
    cd "$snapshot_root"
    snapshots=($(ls -1d */ 2>/dev/null | sort))
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
#2025-11-18 - AS - v1, First release.
