#!/bin/bash

set -euo pipefail

# Predefine variables
TOP_LEVEL=false

usage() {
    echo
    echo "USAGE:   $0"
    echo
    echo VALID ARGS
    echo "-t:      Operate in TOP-LEVEL mode. This will store snapshots on the specified subvolume at the DRIVE ROOT (ie. /snapshots)."
    echo
    echo "NO ARGS: Operate in NESTED-SUBVOLUME mode. This will store snapshots in a nested subvolume relative to the snapshot target (ie. /home/.snapshots)."
    echo
    exit 1
}

# Parse options
while getopts "th" opt; do
    case $opt in
        t) TOP_LEVEL=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# GLOBAL
#  NOTE: These variables apply to all running modes.
BTRFS_SUBVOLUMES=(/ /home) # / = root, /home = home; provide direct path on disk; use a space to separate items
MAX_SNAPSHOT=8 # Maximum snapshots to retain per snapshotted subvolume

# TOP LEVEL MODE (ROOT-LEVEL STORAGE)
#  NOTE: In this mode, the snapshot subvolume will NOT be automatically created OR mounted. You MUST do both of these things manually prior to running in this mode.
TL_MOUNTPOINT="/snapshots"

# NESTED SUBVOL MODE (NESTED STORAGE)
#  NOTE: In this mode, the snapshot subvolume WILL be automatically created within the target subvolume (ie. /home/.snapshots). No prerequisite setup is required.
NS_MOUNTPOINT=".snapshots"


for subvol in "${BTRFS_SUBVOLUMES[@]}"; do
    subvol_name="${subvol//\//}" # Strip / out of the path for naming purposes.
    if [[ -z "$subvol_name" ]]; then # If subvol=/, then set it to "root" instead of empty string.
        subvol_name="root"
    fi

    if [[ $TOP_LEVEL == true ]]; then
        snapshot_root=$TL_MOUNTPOINT
    else
        snapshot_root="$subvol/$NS_MOUNTPOINT"
    fi

    snapshot_name=${subvol_name}-$(date +%Y%m%d-%H%M%S)

    # Check if $subvol exists - checks for misconfiguration of $BTRFS_SUBVOLUMES
    if [[ ! -d "$subvol" ]]; then
        echo "[$subvol_name] Error 1: Snapshot source not found."
        logger -t "btrfs-snapshot" -p user.notice "[$subvol_name] Error 1: Snapshot source not found."
        echo
        continue
    fi

    # Check if snapshot storage subvolume is accessible to the system.
    if ! btrfs subvolume show "$snapshot_root" &>/dev/null; then
        if [[ -e "$snapshot_root" ]]; then
            echo "[$subvol_name] Error 2: Snapshot not taken. $snapshot_root is not a Btrfs subvolume."
            logger -t "btrfs-snapshot" -p user.notice "Error 2: Snapshot not taken. $snapshot_root is not a Btrfs subvolume."
            echo
            continue
        fi
        if [[ $TOP_LEVEL == true ]]; then
            echo "[$subvol_name] Error 3: Snapshot not taken. $snapshot_root does not exist."
            logger -t "btrfs-snapshot" -p user.notice "[$subvol_name] Error 3: Snapshot not taken. $snapshot_root does not exist."
            echo
            continue
        else
            echo "[$subvol_name] Creating $NS_MOUNTPOINT subvolume on $subvol_name."
            logger -t "btrfs-snapshot" -p user.notice "[$subvol_name] Creating $NS_MOUNTPOINT subvolume on $subvol_name."
            btrfs subvolume create "$snapshot_root"
        fi
    fi

    # Create read-only snapshot
    echo "[$subvol_name] Creating snapshot: $snapshot_root/$snapshot_name"
    logger -t btrfs-snapshot -p user.notice "[$subvol_name] Creating snapshot: $snapshot_root/$snapshot_name"
    btrfs subvolume snapshot -r "$subvol" "$snapshot_root/$snapshot_name"

    # Cleanup old snapshots
    mapfile -t snapshots < <(find "$snapshot_root" -maxdepth 1 -type d -name "${subvol_name}-*" | sort)
    count=${#snapshots[@]}
    if (( count > MAX_SNAPSHOT )); then
        delete_count=$((count - MAX_SNAPSHOT))
        for ((i=0; i<delete_count; i++)); do
            echo "[$subvol_name] Deleting old snapshot: ${snapshots[i]}"
            logger -t btrfs-snapshot -p user.notice "[$subvol_name] Deleting old snapshot: ${snapshots[i]}"
            btrfs subvolume delete "${snapshots[i]}"
        done
    fi

    echo
done

#Changelog
#2025-11-18 - AS - v1, First release.
#2025-11-18 - AS - v2, Split into top-level and sub-level versions.
#2025-11-19 - AS - v3, Combine both top-level and nested-subvol scripts.
