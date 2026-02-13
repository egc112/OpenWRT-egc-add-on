# Name: monitor-ip.ps1
# Version: 0.90 14-feb-2026 by egc (PowerShell port)
# Description: PowerShell script to monitor the external IPv4 address from Windows
# Operating mode: Runs continuously checking external IP every second until stopped with CTRL+C
# Usage: e.g. if you want to be sure there is no WAN leak while using your VPN and PBR
# Installation:
#   Save this file as monitor-ip.ps1
#   If needed, allow script execution with: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#   Run with: .\monitor-ip.ps1

# Initialize variables
$previousIp = ""
$lastOutputTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

while ($true) {
    # Get current external IP address
    try {
        $currentIp = (Invoke-WebRequest -Uri "https://ifconfig.me/ip" -UseBasicParsing -TimeoutSec 5).Content.Trim()
    } catch {
        $currentIp = ""
    }

    # If request failed or returned empty, set to special value
    if ([string]::IsNullOrWhiteSpace($currentIp)) {
        $currentIp = "< none >"
    }

    $currentTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $timePassed = $currentTime - $lastOutputTime

    # Check if IP has changed or 10 seconds have passed
    if ($currentIp -ne $previousIp -or $timePassed -ge 10) {
        # Only show time passed if this is not the first run
        if ($previousIp -ne "") {
            Write-Host "< $($timePassed)s >"
        }

        Write-Host $currentIp

        # Update tracking variables
        $previousIp = $currentIp
        $lastOutputTime = $currentTime
    }

    # Wait 1 second before checking again
    Start-Sleep -Seconds 1
}