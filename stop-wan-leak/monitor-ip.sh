#!/bin/sh
#DEBUG=; set -x; logger -t stop-wan-leak $(env); # uncomment/comment to enable/disable debug mode

# Name: monitor-ip.sh
# Version: 0.90 14-feb-2026 by egc
# Description: (b)ash script to monitor the external lPv4 address from the linux command line of your LAN clients
# Operating mode: The script will run continuously checking external IP address every second until stopped with CTRL+C
# Usage: e.g. if you want to be sure there is no wan leak while using your VPN and PBR
# Installation:
#  Copy script from https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/stop-wan-leak/09-stop-wan-leak to your home directory of your Linux PC
#     with, from commandline (SSH): curl -o ~/monitor-ip.sh https://raw.githubusercontent.com/egc112/OpenWRT-egc-add-on/main/stop-wan-leak/monitor-ip.sh
#     or by clicking the download icon in the upper right corner of the script and using e.g. winscp to transfer the script.
#  make executable with: `cd ~ && chmod +x monitor-ip.sh`
#  start script with: `./monitor-ip.sh`
# Enable debugging by removing the # before the #DEBUG= ... on line 2, check debug output with `logread -e stop-wan-leak
# Script can also run on the router but it is useless to do if you check forwarding as the router itself is not blocked when forwarding is disabled

# Initialize variables
previous_ip=""
last_output_time=$(date +%s)

while true; do
    # Get current external IP address
    current_ip=$(curl -4 -s --connect-timeout 5 ifconfig.me 2>/dev/null)
    # If curl failed or returned empty, set to special value
    if [ -z "$current_ip" ]; then
        current_ip="< none >"
    fi
    current_time=$(date +%s)
    time_passed=$((current_time - last_output_time))
    # Check if IP has changed or 10 seconds have passed
    if [ "$current_ip" != "$previous_ip" ] || [ $time_passed -ge 10 ]; then
        # Only show time passed if this is not the first run
        if [ -n "$previous_ip" ]; then
            echo "< ${time_passed}s >"
        fi
        
        echo "$current_ip"
        
        # Update tracking variables
        previous_ip="$current_ip"
        last_output_time=$current_time
    fi
    # Wait 1 second before checking again
    sleep 1
done
