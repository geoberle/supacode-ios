#!/usr/bin/env bash
set -euo pipefail

devices=()
labels=()

while IFS= read -r line; do
    name=$(echo "$line" | sed 's/  \+/\t/g' | cut -f1)
    uuid=$(echo "$line" | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}')
    if [[ -n "$uuid" ]]; then
        devices+=("$uuid")
        labels+=("$name")
    fi
done < <(xcrun devicectl list devices 2>/dev/null | awk 'NR>2 && !/disconnected/')

if [[ ${#devices[@]} -eq 0 ]]; then
    echo "No connected devices found" >&2
    exit 1
fi

if [[ ${#devices[@]} -eq 1 ]]; then
    echo "${devices[0]}"
    exit 0
fi

echo "Connected devices:" >&2
for i in "${!devices[@]}"; do
    echo "  $((i+1))) ${labels[$i]}  [${devices[$i]}]" >&2
done

printf "Pick device [1-%d]: " "${#devices[@]}" >&2
read -r choice

if [[ "$choice" -ge 1 && "$choice" -le ${#devices[@]} ]] 2>/dev/null; then
    echo "${devices[$((choice-1))]}"
else
    echo "Invalid selection" >&2
    exit 1
fi
