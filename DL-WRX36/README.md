## Directory for the Dynalink DL-WRX36

### Radio Firmware

This repo conains several 2.9.0 firmwares for IPQ8074 e.g. Dynalink DL-WRX36

There is also older 2.7 firmware available both from the kvalo and official qualcomm sources

You can view your current firmware with: `dmesg | grep HK`
```
root@DL-WRX36:~# dmesg | grep HK
[   13.126573] ath11k c000000.wifi: fw_version 0x290984a5 fw_build_timestamp 2023-07-19 02:31 fw_build_id WLAN.HK.2.9.0.1-01862-QCAHKSWPL_SILICONZ-1
```
For the radio firmware simply replace content of `/lib/firmware/IPQ8074` with e.g. content of the 1835 directory
  
For upstream Qualcomm repo see: https://github.com/quic/upstream-wifi-fw/tree/main/ath11k-firmware/IPQ8074/hw2.0

KVALO's repo: https://github.com/kvalo/ath11k-firmware/tree/master/IPQ8074 

Official Linux firmware: https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/  

To download a folder from GitHub, navigate to your desired repository, select the folder you want to download from GitHub, copy the URL, navigate to https://download-directory.github.io/ and paste the URL into the text box, and hit enter.
