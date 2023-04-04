#!/usr/bin/env bash
#
# Author: artheus
#
# Simple migration script for migrating log-tracking data from FluentD instances to
# fluent-bit SQLite3 DB.
#
# This will only look for the fluentd-containers.log.pos file, and migrate any data
# from within that file. If no fluent-bit SQLite3 DB exists, this script will create
# one, and input any data from the FluentD container log tracking file.
#

info() {
  printf "[%s] INFO - %s\n" "$(date --iso-8601=seconds )" "$@"
}

readonly DB='/opt/fluent-bit-db/log-tracking.db'
readonly FLUENTD_LOG_POS="/var/log/fluentd-containers.log.pos"

if [[ ! -f "$FLUENTD_LOG_POS" ]]; then
  info "No FluentD log tracking file to migrate from, no migration done"
  exit
fi

if [[ ! -f "$DB" ]]; then
  sqlite3 "$DB" "CREATE TABLE main.in_tail_files (id INTEGER PRIMARY KEY, name TEXT, offset INTEGER, inode INTEGER, created INTEGER, rotated INTEGER);"
else
  info "fluent-bit database already exists, will not do migration"
  exit
fi

while read -r line; do
  IFS=$'\t' read -r -a parts <<< "$line"

  filename="${parts[0]}"
  offset="$((16#${parts[1]}))"
  inode="$((16#${parts[2]}))"
  now="$(date +%s)"

  sqlite3 "$DB" "INSERT INTO in_tail_files (name, offset, inode, created, rotated) VALUES ('$filename', $offset, $inode, $now, 0)"
done < <(sort "$FLUENTD_LOG_POS")
