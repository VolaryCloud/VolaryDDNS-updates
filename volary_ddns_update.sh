#!/bin/bash

# VolaryDDNS Update Script - Version 2025.5.27
# Maintainer: Phillip Rødseth <phillip@vtolvr.tech>
# 
# Description:
#   This script updates a DNS record via the VolaryDDNS API when the host's public IP changes.
#   Designed for use with systems on dynamic IPs behind NAT or residential connections.
#
# Usage:
#   Schedule with cron or systemd to run periodically.
#
# For subdomain: DDNS-{subdomain.name}.{CF_DOMAIN}

set -euo pipefail

readonly TOKEN="{subdomain.token}" # <-- Replace this with your VolaryDDNS token!
readonly API_URL="{base_url}/api/update" # <-- This is the base url for VolaryDDNS. It's not explicity set incase domains change in the future.
# ^^^^^^^^^^^^^^^^^^^^^^^^^
# Please note that you can download this script from your VolaryDDNS dashboard with these automatically filled out.

readonly LOG_FILE="$HOME/.volary_ddns_update.log" # <-- This is where the VolaryDDNS log file is at; /home/username/.volary_ddns_update.log
readonly MAX_LOG_SIZE=1048576 # Maximum log file size, 1 MB
readonly TIMEOUT=30 # HTTP timeout in seconds

log_message() {
    # Assign the first argument to 'level' (e.g., INFO, ERROR, DEBUG)
    local level="$1"

    # Assign the second argument to 'message' (the actual log message)
    local message="$2"

    # Get the current timestamp in "YYYY-MM-DD HH:MM:SS" format
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Append the log message to the log file with timestamp and level
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"

    # If the script is run in a terminal (not via cron or redirected), also show output
    if [[ -t 1 ]]; then
        if [[ "${level}" == "ERROR" ]]; then
            # If it's an error, send the message to stderr (standard error)
            echo "[${level}] ${message}" >&2
        else
            # Otherwise, print the message normally to stdout
            echo "[${level}] ${message}"
        fi
    fi
}

rotate_log() {
    # Check if the log file exists and its size exceeds the MAX_LOG_SIZE threshold
    if [[ -f "${LOG_FILE}" ]] && [[ $(stat -f%z "${LOG_FILE}" 2>/dev/null || stat -c%s "${LOG_FILE}" 2>/dev/null || echo 0) -gt ${MAX_LOG_SIZE} ]]; then
        # Rename the current log file to .old
        mv "${LOG_FILE}" "${LOG_FILE}.old"

        # Log the rotation action to the new log file
        log_message "INFO" "Log file rotated due to size limit"
    fi
}

cleanup_and_exit() {
    # Get the first argument: the exit code (0 for success, non-zero for error)
    local exit_code=$1

    # Get the second argument: a message describing the reason for exit
    local message="$2"

    # If the exit code is 0, it's a successful run
    if [[ ${exit_code} -eq 0 ]]; then
        log_message "INFO" "Script completed successfully: ${message}"
    else
        # If not 0, something went wrong — log as an error
        log_message "ERROR" "Script failed: ${message}"
    fi

    # Exit the script with the provided exit code
    exit ${exit_code}
}

# Set up a trap so that if the script is interrupted (Ctrl+C or terminated),
# it will call cleanup_and_exit with code 130 and a message.
trap 'cleanup_and_exit 130 "Script interrupted"' INT TERM

# Log the start of the script
log_message "INFO" "Starting VolaryDDNS update process"

# Create the directory for the log file if it doesn't already exist
mkdir -p "$(dirname "${LOG_FILE}")"

# Try to create or touch the log file to ensure it is writable
if ! touch "${LOG_FILE}" 2>/dev/null; then
    # If the log file can't be written, print an error and exit with code 1
    echo "ERROR: Cannot write to log file ${LOG_FILE}" >&2
    exit 1
fi

# Rotate the log file if it exceeds size limits before proceeding
rotate_log

# Log that the script is starting to retrieve the public IP address
log_message "INFO" "Retrieving current public IP address"

# Initialize IP variable to empty string
IP=""

# Try up to 3 times to get the public IP
for attempt in 1 2 3; do
    # Use curl with timeout to fetch IP from api.ipify.org silently
    if IP=$(curl -s --connect-timeout ${TIMEOUT} --max-time ${TIMEOUT} https://api.ipify.org 2>/dev/null); then
        # Check if IP is not empty and matches IPv4 regex pattern
        if [[ -n "${IP}" ]] && [[ "${IP}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            # Log success and break the loop
            log_message "INFO" "Successfully retrieved IP address: ${IP}"
            break
        else
            # Log a warning if IP format is invalid, reset IP variable
            log_message "WARN" "Attempt ${attempt}: Invalid IP format received: '${IP}'"
            IP=""
        fi
    else
        # Log a warning if curl failed to fetch the IP
        log_message "WARN" "Attempt ${attempt}: Failed to retrieve IP address from api.ipify.org"
    fi

    # If not the last attempt, wait 5 seconds before retrying
    if [[ ${attempt} -lt 3 ]]; then
        sleep 5
    fi
done

# If the IP variable is empty after attempts, exit with error
if [[ -z "${IP}" ]]; then
    cleanup_and_exit 1 "Failed to get valid public IP address after 3 attempts"
fi

# Double-check the IP format again; if invalid, exit with error
if ! [[ "${IP}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    cleanup_and_exit 1 "Invalid IP address format: ${IP}"
fi

# Path to file where last updated IP is stored
LAST_IP_FILE="${HOME}/.volary_ddns_last_ip"

# If the file with the last IP exists, read it
if [[ -f "${LAST_IP_FILE}" ]]; then
    LAST_IP=$(cat "${LAST_IP_FILE}" 2>/dev/null || echo "")
    # Compare current IP with last IP; if unchanged, log and exit successfully
    if [[ "${IP}" == "${LAST_IP}" ]]; then
        log_message "INFO" "IP address unchanged (${IP}), skipping update"
        cleanup_and_exit 0 "No update needed - IP unchanged"
    fi
fi

# Log that the script is starting the DNS update with the new IP
log_message "INFO" "Updating DNS record to IP: ${IP}"

# Prepare the JSON payload with the token and the new IP for the API request
JSON_PAYLOAD=$(printf '{"token": "%s", "ip": "%s"}' "${TOKEN}" "${IP}")

# Make a POST request to the API_URL with the JSON payload
# -s: silent mode (no progress bar)
# --connect-timeout and --max-time: limit connection and overall time
# -H: set headers for JSON content and user agent
# 2>&1: capture both stdout and stderr
if ! RESPONSE=$(curl -s \
    --connect-timeout ${TIMEOUT} \
    --max-time ${TIMEOUT} \
    -X POST \
    -H "Content-Type: application/json" \
    -H "User-Agent: VolaryDDNS-Script/1.0" \
    -d "${JSON_PAYLOAD}" \
    "${API_URL}" 2>&1); then
    # If curl fails, exit with an error and message
    cleanup_and_exit 1 "Failed to make API request to ${API_URL}"
fi

# Log the raw API response at DEBUG level for troubleshooting
log_message "DEBUG" "API Response: ${RESPONSE}"

# If the API response is empty, exit with an error
if [[ -z "${RESPONSE}" ]]; then
    cleanup_and_exit 1 "Empty response from API"
fi

# Check if the API response contains keywords indicating success (case-insensitive)
if echo "${RESPONSE}" | grep -qi "success\|updated\|ok"; then
    # Log successful update
    log_message "INFO" "DNS record updated successfully"

    # Save the new IP to the last IP file to avoid unnecessary future updates
    echo "${IP}" > "${LAST_IP_FILE}"

    # Exit cleanly with success status and message
    cleanup_and_exit 0 "IP successfully updated to ${IP}"

else
    # Default error message if no specific info found
    ERROR_MSG="Unknown error"

    # Try to extract an error message from the JSON response under "error" key
    if echo "${RESPONSE}" | grep -q '"error"'; then
        ERROR_MSG=$(echo "${RESPONSE}" | sed -n 's/.*"error"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

    # Otherwise, try extracting from "message" key if present
    elif echo "${RESPONSE}" | grep -q '"message"'; then
        ERROR_MSG=$(echo "${RESPONSE}" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    fi

    # If extraction failed or message is still default, set ERROR_MSG to full response
    if [[ -z "${ERROR_MSG}" ]] || [[ "${ERROR_MSG}" == "Unknown error" ]]; then
        ERROR_MSG="${RESPONSE}"
    fi

    # Exit with failure and the extracted or default error message
    cleanup_and_exit 1 "API request failed: ${ERROR_MSG}"
fi