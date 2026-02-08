#!/bin/bash

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
