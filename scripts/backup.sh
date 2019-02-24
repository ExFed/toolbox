#!/usr/bin/env bash

# Performs a standard incremental backup of a given source directory using `tar`
#
# USAGE: backup.sh ARCHIVE_DIR SOURCE_DIR
#
# Backup file naming...
#   Pattern: $NAME.$EPOCH.$INCREMENT.(tar.gz|snar)
#   RegEx: /^(.*)\.([0-9]+)\.([0-9]+)\.(tar\.gz|snar)$/

set -eu -o pipefail
shopt -s failglob

IS_FULL=${IS_FULL:-}

[[ -z ${1:-} ]] && { echo 'Missing target backup file!'; exit 2; }
ARCHIVE_DIR=$(realpath "$1")
[[ -z ${2:-} ]] && { echo 'Missing source directory!'; exit 2; }
SOURCE_DIR=$(realpath "$2")

EPOCH=$(date +%s)
NAME="$(/usr/bin/basename "$SOURCE_DIR")"

# Select last backup snapshot file
LAST_SNAPSHOT=$(
    /usr/bin/find "$ARCHIVE_DIR" -maxdepth 1 -type f -name "$NAME.*.*.snar" \
        | sort -r \
        | head -n1)

# if incremental (last snapshot exists and is not full), copy the snapshot
if [[ -f "$LAST_SNAPSHOT" && $IS_FULL != true ]]
then
    # extract the last increment number
    LAST_INCREMENT=$(echo "$LAST_SNAPSHOT" | sed -E 's/^.*\.[0-9]+\.([0-9]+)\.snar$/\1/')
    INCREMENT=$(($LAST_INCREMENT + 1))
    ARCHIVE_BASE="$NAME.$EPOCH.$INCREMENT"
    # create a new working snapshot
    cp --no-preserve=mode "$LAST_SNAPSHOT" "$ARCHIVE_DIR/$ARCHIVE_BASE.snar"
else
    INCREMENT=0
    ARCHIVE_BASE="$NAME.$EPOCH.$INCREMENT"
fi

tar --verbose --exclude-vcs-ignores \
    --listed-incremental="$ARCHIVE_DIR/$ARCHIVE_BASE.snar" \
    --create --file "$ARCHIVE_DIR/$ARCHIVE_BASE.tar.gz" "$SOURCE_DIR" > "$ARCHIVE_DIR/$ARCHIVE_BASE.log"

# try to remove write permissions
chmod -w "$ARCHIVE_DIR/$ARCHIVE_BASE".*
