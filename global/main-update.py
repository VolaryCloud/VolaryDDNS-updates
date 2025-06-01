# VolaryDDNS Update Script - Version 2025.6.01
# Maintainer: Phillip Rødseth <phillip@vtolvr.tech>
# 
# Description:
#   This script updates a DNS record via the VolaryDDNS API when the host's public IP changes.
#   Designed for use with systems on dynamic IPs behind NAT or residential connections.
#
# Usage:
#   Schedule with cron, systemd or system scheduler to run periodically.
#
# For subdomain: DDNS-{subdomain.name}.{CF_DOMAIN}

import os
import sys
import json
import time
import requests
from datetime import datetime

TOKEN = f"{subdomain.token}"
API_URL = f"{base_url}/api/update"

LOG_FILE = os.path.expanduser("~/.volary_ddns_update.log")
LAST_IP_FILE = os.path.expanduser("~/.volary_ddns_last_ip")
MAX_LOG_SIZE = 1048576
TIMEOUT = 30

def log_message(level, message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] [{level}] {message}\\n"
    with open(LOG_FILE, "a") as f:
        f.write(log_entry)
    if level == "ERROR":
        print(log_entry.strip(), file=sys.stderr)
    else:
        print(log_entry.strip())
        
def rotate_log():
    if os.path.isfile(LOG_FILE) and os.path.getsize(LOG_FILE) > MAX_LOG_SIZE:
        os.rename(LOG_FILE, LOG_FILE + ".old")
        log_message("INFO", "Log file rotated due to size limit")

def get_public_ip():
    for attempt in range(3):
        try:
            response = requests.get("https://api.ipify.org", timeout=TIMEOUT)
            if response.status_code == 200:
                ip = response.text.strip()
                if validate_ip(ip):
                    log_message("INFO", f"Successfully retrieved IP address: {ip}")
                    return ip
                else:
                    log_message("WARN", f"Attempt {attempt+1}: Invalid IP format: '{ip}'")
            else:
                log_message("WARN", f"Attempt {attempt+1}: HTTP error {response.status_code}")
        except Exception as e:
            log_message("WARN", f"Attempt {attempt+1}: Failed to retrieve IP: {e}")
        if attempt < 2:
            time.sleep(5)
    return None

def validate_ip(ip):
    import re
    pattern = re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")
    return bool(pattern.match(ip))

def update_ddns(ip):
    payload = {
        "token": TOKEN,
        "ip": ip
    }
    headers = {
        "Content-Type": "application/json",
        "User-Agent": "VolaryDDNS-Script/1.0"
    }
    try:
        response = requests.post(API_URL, headers=headers, json=payload, timeout=TIMEOUT)
        log_message("DEBUG", f"API Response: {response.text}")
        if response.ok and any(k in response.text.lower() for k in ["success", "updated", "ok"]):
            log_message("INFO", "DNS record updated successfully")
            with open(LAST_IP_FILE, "w") as f:
                f.write(ip)
            return True
        else:
            try:
                error_data = response.json()
                error_msg = error_data.get("error") or error_data.get("message") or response.text
            except Exception:
                error_msg = response.text
            log_message("ERROR", f"API request failed: {error_msg}")
            return False
    except Exception as e:
        log_message("ERROR", f"API request exception: {e}")
        return False

def main():
    log_message("INFO", "Starting VolaryDDNS update process")
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    rotate_log()

    ip = get_public_ip()
    if not ip:
        log_message("ERROR", "Failed to get valid public IP after 3 attempts")
        sys.exit(1)

    if os.path.isfile(LAST_IP_FILE):
        with open(LAST_IP_FILE, "r") as f:
            last_ip = f.read().strip()
        if ip == last_ip:
            log_message("INFO", f"IP address unchanged ({ip}), skipping update")
            sys.exit(0)

    if update_ddns(ip):
        log_message("INFO", f"IP successfully updated to {ip}")
        sys.exit(0)
    else:
        log_message("ERROR", "Failed to update DDNS")
        sys.exit(1)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log_message("ERROR", "Script interrupted")
        sys.exit(130)
