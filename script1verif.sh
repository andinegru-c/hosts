#!/bin/bash

HOSTS_FILE="$HOME/etc/hosts"

verify-IP() {
local hostname="$1"
local ip_fila
local adresedns


if [ -z "$hostname" ]; then
    return 2
fi


if [ ! -f "$HOSTS_FILE" ]; then
    return 2
fi

ip_fila=$(awk -v host="$hostname" '
    /^[[:space:]]*#/ { next }
    {
        for (i=2; i<=NF; i++) {
            if ($i ~ /^#/) break
            if ($i == host) {
                print $1
                exit
            }
        }
    }
' "$HOSTS_FILE")


if [ -z "$ip_fila" ]; then
    return 2
fi



    local lookup_output
    lookup_output=$(nslookup -type=A "$hostname" 2>/dev/null)

    if [ $? -ne 0 ]; then
        return 3
    fi



    adresedns=$(printf '%s\n' "$lookup_output" | awk '
        /^Name:[[:space:]]/ { answer=1; next }
        answer && /^[[:space:]]*Address:[[:space:]]/ {
            if ($2 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/)
                print $2
        }
    ')

    if [ -z "$adresedns" ]; then
        return 3
    fi

if ! grep -Fxq -- "$ip_fila" <<< "$adresedns"; then
        echo "Bogus IP for $hostname in $HOME/etc/hosts !"
        return 1
    fi

    return 0
}



if [ ! -f "$HOSTS_FILE" ]; then
    echo "Error: $HOSTS_FILE does not exist."
    exit 2
fi

overall_status=0


while IFS= read -r line || [ -n "$line" ]; do

    line="${line%%#*}"


    read -r -a fields <<< "$line"


    if [ "${#fields[@]}" -lt 2 ]; then
        continue
    fi

    ip="${fields[0]}"


    if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        continue
    fi


    for ((i=1; i<${#fields[@]}; i++)); do

        hostname="${fields[$i]}"

        verify-IP "$hostname"
        result=$?

        case "$result" in
            0)
                echo "$hostname: IP address is correct."
                ;;
            1)
                overall_status=1
                ;;
            2)
                echo "Error: Missing file or hostname entry for $hostname."
                overall_status=1
                ;;
            3)
                echo "Error: DNS lookup failed for $hostname."
                overall_status=1
                ;;
        esac

    done

done < "$HOSTS_FILE"

exit "$overall_status"

