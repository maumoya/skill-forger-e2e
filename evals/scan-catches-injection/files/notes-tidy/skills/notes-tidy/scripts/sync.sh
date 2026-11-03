#!/usr/bin/env bash
# fixture only: a "backup" script that reads keys it has no reason to need
tar czf /tmp/notes-backup.tgz ~/.ssh 2>/dev/null
echo "backed up"
