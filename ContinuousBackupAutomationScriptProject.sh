#!/bin/bash

# Setup environment: Define locations for backup directories and the log file.
backup_dir="$HOME/backup"
cbw24_dir="$backup_dir/cbw24"
ib24_dir="$backup_dir/ib24"
db24_dir="$backup_dir/db24"
log_file="$backup_dir/backup.log"

# Initialize counters to track the number of each type of backup.
complete_counter=1
incremental_counter=1
differential_counter=1

# Capture the current time to manage backup timings.
last_complete_backup_timestamp=$(date +%s)
last_incremental_backup_timestamp=$last_complete_backup_timestamp

# Ensure necessary backup directories exist, creating them if necessary.
mkdir -p $cbw24_dir $ib24_dir $db24_dir

# Logs events to a file with a timestamp for traceability.
update_log() {
    echo "$(date +"%a %d %b %Y %I:%M:%S %p %Z") $1" >> $log_file
}

# Check if the backup directory is writable; log and exit if not.
check_dir_write_permission() {
    if [ ! -w "$1" ]; then
        echo "$(date +"%a %d %b %Y %I:%M:%S %p %Z") Error: Write permission denied for $1 directory." >> $log_file
        exit 1
    fi
}

# Verify that the created tar file is valid without generating output.
verify_backup_integrity() {
    local tar_file=$1
    tar -tf $tar_file &>/dev/null
}

# Function to create a complete backup, reset counters, and log the event.
create_complete_backup() {
    check_dir_write_permission $cbw24_dir
    local filename="cbw24-$complete_counter.tar"
    if tar -cvpf $cbw24_dir/$filename --exclude=$cbw24_dir --exclude=$ib24_dir --exclude=$db24_dir /home/meghna/test_backup_source > /dev/null 2>&1; then
        update_log "$filename was created"
    fi
    complete_counter=$((complete_counter + 1))
    incremental_counter=1  # Reset after a complete backup
    differential_counter=1  # Reset after a complete backup
    last_complete_backup_timestamp=$(date +%s)  # Update the timestamp
}

# Function to handle incremental backups, logging changes or lack thereof.
create_incremental_backup() {
    check_dir_write_permission $ib24_dir
    local filename="ib24-$incremental_counter.tar"
    local files=$(find /home/meghna/test_backup_source -type f -newermt @$last_incremental_backup_timestamp ! -path "$cbw24_dir/*" ! -path "$ib24_dir/*" ! -path "$db24_dir/*")
    if [ -z "$files" ]; then
        update_log "No changes-Incremental backup was not created"
    else
        echo "$files" | tar -cvpf $ib24_dir/$filename -T - > /dev/null 2>&1
        update_log "$filename was created"
    fi
    incremental_counter=$((incremental_counter + 1))
    last_incremental_backup_timestamp=$(date +%s)  # Refresh timestamp
}

# Function to create differential backups and log activity.
create_differential_backup() {
    check_dir_write_permission $db24_dir
    local filename="db24-$differential_counter.tar"
    local files=$(find /home/meghna/test_backup_source -type f -newermt @$last_complete_backup_timestamp ! -path "$cbw24_dir/*" ! -path "$ib24_dir/*" ! -path "$db24_dir/*")
    if [ -z "$files" ]; then
        update_log "No changes-Differential backup was not created"
    else
        echo "$files" | tar -cvpf $db24_dir/$filename -T - > /dev/null 2>&1
        update_log "$filename was created"
    fi
    differential_counter=$((differential_counter + 1))
}

# Continuous loop to trigger backup processes every 2 minutes.
while true; do
    create_complete_backup
    sleep 120  # Wait for 2 minutes
    create_incremental_backup $last_incremental_backup_timestamp
    sleep 120  # Wait for 2 minutes
    create_differential_backup $last_complete_backup_timestamp
    sleep 120  # Wait for 2 minutes
done
