#!/bin/bash

# Copyright (c) 2025 VolaryCloud | Phillip Rødseth
# All rights reserved.
# 
# This software is proprietary and confidential. Unauthorized copying, modification,
# distribution, reverse engineering, or use of this software is strictly prohibited.
# This software is provided "as is" without warranty of any kind.
#
# VolaryDDNS Update Script - Version 2025.5.27
# Contact: phillip@vtolvr.tech
#
# For subdomain: DDNS-{subdomain.name}.{CF_DOMAIN}

set -euo pipefail
readonly TOKEN="{subdomain.token}"
readonly API_URL="{base_url}/api/update"
readonly LOG_FILE="$HOME/.volary_ddns_update.log"
readonly MAX_LOG_SIZE=1048576
readonly TIMEOUT=30
log_message() {{
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${{timestamp}}] [${{level}}] ${{message}}" >> "${{LOG_FILE}}"

    if [[ -t 1 ]]; then
        if [[ "${{level}}" == "ERROR" ]]; then
            echo "[${{level}}] ${{message}}" >&2
        else
            echo "[${{level}}] ${{message}}"
        fi
    fi
}}
rotate_log() {{
    if [[ -f "${{LOG_FILE}}" ]] && [[ $(stat -f%z "${{LOG_FILE}}" 2>/dev/null || stat -c%s "${{LOG_FILE}}" 2>/dev/null || echo 0) -gt ${{MAX_LOG_SIZE}} ]]; then
        mv "${{LOG_FILE}}" "${{LOG_FILE}}.old"
        log_message "INFO" "Log file rotated due to size limit"
    fi
}}
cleanup_and_exit() {{
    local exit_code=$1
    local message="$2"

    if [[ ${{exit_code}} -eq 0 ]]; then
        log_message "INFO" "Script completed successfully: ${{message}}"
    else
        log_message "ERROR" "Script failed: ${{message}}"
    fi

    exit ${{exit_code}}
}}
trap 'cleanup_and_exit 130 "Script interrupted"' INT TERM

log_message "INFO" "Starting VolaryDDNS update process"

mkdir -p "$(dirname "${{LOG_FILE}}")"
if ! touch "${{LOG_FILE}}" 2>/dev/null; then
    echo "ERROR: Cannot write to log file ${{LOG_FILE}}" >&2
    exit 1
fi

rotate_log

log_message "INFO" "Retrieving current public IP address"
IP=""
for attempt in 1 2 3; do
    if IP=$(curl -s --connect-timeout ${{TIMEOUT}} --max-time ${{TIMEOUT}} https://api.ipify.org 2>/dev/null); then
        if [[ -n "${{IP}}" ]] && [[ "${{IP}}" =~ ^[0-9]{{1,3}}\.[0-9]{{1,3}}\.[0-9]{{1,3}}\.[0-9]{{1,3}}$ ]]; then
            log_message "INFO" "Successfully retrieved IP address: ${{IP}}"
            break
        else
            log_message "WARN" "Attempt ${{attempt}}: Invalid IP format received: '${{IP}}'"
            IP=""
        fi
    else
        log_message "WARN" "Attempt ${{attempt}}: Failed to retrieve IP address from api.ipify.org"
    fi

    if [[ ${{attempt}} -lt 3 ]]; then
        sleep 5
    fi
done

if [[ -z "${{IP}}" ]]; then
    cleanup_and_exit 1 "Failed to get valid public IP address after 3 attempts"
fi

if ! [[ "${{IP}}" =~ ^[0-9]{{1,3}}\.[0-9]{{1,3}}\.[0-9]{{1,3}}\.[0-9]{{1,3}}$ ]]; then
    cleanup_and_exit 1 "Invalid IP address format: ${{IP}}"
fi

LAST_IP_FILE="${{HOME}}/.volary_ddns_last_ip"
if [[ -f "${{LAST_IP_FILE}}" ]]; then
    LAST_IP=$(cat "${{LAST_IP_FILE}}" 2>/dev/null || echo "")
    if [[ "${{IP}}" == "${{LAST_IP}}" ]]; then
        log_message "INFO" "IP address unchanged (${{IP}}), skipping update"
        cleanup_and_exit 0 "No update needed - IP unchanged"
    fi
fi

log_message "INFO" "Updating DNS record to IP: ${{IP}}"

JSON_PAYLOAD=$(printf '{{"token": "%s", "ip": "%s"}}' "${{TOKEN}}" "${{IP}}")
if ! RESPONSE=$(curl -s \
    --connect-timeout ${{TIMEOUT}} \
    --max-time ${{TIMEOUT}} \
    -X POST \
    -H "Content-Type: application/json" \
    -H "User-Agent: VolaryDDNS-Script/1.0" \
    -d "${{JSON_PAYLOAD}}" \
    "${{API_URL}}" 2>&1); then
    cleanup_and_exit 1 "Failed to make API request to ${{API_URL}}"
fi

log_message "DEBUG" "API Response: ${{RESPONSE}}"

if [[ -z "${{RESPONSE}}" ]]; then
    cleanup_and_exit 1 "Empty response from API"
fi

if echo "${{RESPONSE}}" | grep -qi "success\|updated\|ok"; then
    log_message "INFO" "DNS record updated successfully"
    echo "${{IP}}" > "${{LAST_IP_FILE}}"
    cleanup_and_exit 0 "IP successfully updated to ${{IP}}"
else
    ERROR_MSG="Unknown error"
    if echo "${{RESPONSE}}" | grep -q '"error"'; then
        ERROR_MSG=$(echo "${{RESPONSE}}" | sed -n 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    elif echo "${{RESPONSE}}" | grep -q '"message"'; then
        ERROR_MSG=$(echo "${{RESPONSE}}" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    fi

    if [[ -z "${{ERROR_MSG}}" ]] || [[ "${{ERROR_MSG}}" == "Unknown error" ]]; then
        ERROR_MSG="${{RESPONSE}}"
    fi

    cleanup_and_exit 1 "API request failed: ${{ERROR_MSG}}"
fi
