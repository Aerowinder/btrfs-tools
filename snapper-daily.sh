#!/bin/bash
set -euo pipefail

# Global Variables
KEEP_SNAPSHOT=7 # Maximum number of snapshots to keep per subvolume.
SEARCH_KEYWORD="AUTO:" # Keyword used to determine which snapshots to prune. Only prune the automated snapshots, not the manually created ones.
DESC="AUTO: snapper-daily" # Description the automated snapshot will use.
SUBVOLS=(root home) # List of snapper configs that you want to use.

log() {
    logger -t snapper-daily "$1"
}

for subvol in "${SUBVOLS[@]}"; do
    log "Starting snapshot for $subvol..."

    if ! snapper -c "$subvol" create -d "$DESC"; then
        log "ERROR: Failed to create snapshot for $subvol!"
        continue
    fi

    log "Pruning old snapshots for $subvol..."
    if ! snapper -c "$subvol" list \
        | awk -v kw="$SEARCH_KEYWORD" '$0 ~ kw {print $1}' \
        | sort -n \
        | { head -n -"$KEEP_SNAPSHOT" 2>/dev/null || true; } \
        | xargs -r snapper -c "$subvol" delete; then
        log "ERROR: Failed to prune snapshots for $subvol!"
    fi

    log "Completed snapshot and cleanup for $subvol."
done
