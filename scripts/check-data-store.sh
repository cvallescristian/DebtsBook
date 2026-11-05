#!/bin/sh
# Views must change data through DataStore (the one door that schedules sync), never
# through modelContext.insert/delete directly. See DebtsBook/DebtsBook/Services/DataStore.swift.
set -e
matches=$(grep -rnE "modelContext\.(insert|delete)\(|FriendSyncService\.shared\.push" DebtsBook/Views DebtsBook/DebtsBook/Views || true)
if [ -n "$matches" ]; then
  echo "Use DataStore (insert/delete/commit) instead of writing or pushing directly in views:"
  echo "$matches"
  exit 1
fi
echo "DataStore check passed"
