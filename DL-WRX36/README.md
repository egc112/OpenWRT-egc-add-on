## Directory for the Dynalink DL-WRX36

You can view the current firmware with: `dmesg | grep HK`
```
root@DL-WRX36:~# dmesg | grep HK
[   13.126573] ath11k c000000.wifi: fw_version 0x290984a5 fw_build_timestamp 2023-07-19 02:31 fw_build_id WLAN.HK.2.9.0.1-01862-QCAHKSWPL_SILICONZ-1
```
For the radio firmware simply replace content of `/lib/firmware/IPQ8074` with e.g. content of the 1835 directory
