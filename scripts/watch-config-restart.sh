#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -eq 0 ]; then
  cat <<'EOF'
Usage:
  scripts/watch-config-restart.sh <command> [args...]

Examples:
  scripts/watch-config-restart.sh bundle exec jekyll serve --livereload
  scripts/watch-config-restart.sh docker compose up
EOF
  exit 1
fi

WATCH_FILES=(
  "_config.yml"
  "_config_docker.yml"
)

existing_watch_files=()
for file in "${WATCH_FILES[@]}"; do
  if [ -f "$file" ]; then
    existing_watch_files+=("$file")
  fi
done

if [ "${#existing_watch_files[@]}" -eq 0 ]; then
  echo "No config files found to watch."
  exit 1
fi

child_pid=""

get_state() {
  local state=""
  local file

  for file in "${existing_watch_files[@]}"; do
    state+="${file}:$(stat -c %Y "$file")"$'\n'
  done

  printf '%s' "$state"
}

start_server() {
  "$@" &
  child_pid=$!
  echo "Started PID ${child_pid}: $*"
}

stop_server() {
  if [ -n "${child_pid}" ] && kill -0 "${child_pid}" 2>/dev/null; then
    kill "${child_pid}" 2>/dev/null || true
    wait "${child_pid}" 2>/dev/null || true
  fi
  child_pid=""
}

cleanup() {
  stop_server
}

trap cleanup EXIT INT TERM

last_state="$(get_state)"
start_server "$@"

while true; do
  sleep 1
  current_state="$(get_state)"

  if [ "${current_state}" != "${last_state}" ]; then
    echo "Config changed. Restarting..."
    stop_server
    start_server "$@"
    last_state="${current_state}"
  elif [ -n "${child_pid}" ] && ! kill -0 "${child_pid}" 2>/dev/null; then
    echo "Process exited. Starting again..."
    start_server "$@"
  fi
done
