
# USB Device and Openvpn Reset Application

This script checks the connection and performs a reset of the USB device based on the search for the USB model ("Huawei"), if not present it attempts a full reboot.

Conditions evaluated:
- OK / ERROR connection (ping external IP)
- USB device present
- USB device reset time threshold
- system restart threshold

Credit to for developing usbreset program to Alan Stern: http://marc.info/?l=linux-usb&m=121459435621262&w=2

Script and usbreset binary must be executed as privileged user to allow system check and restarts

##

Compile usbreset and make it executable:

`cc usbreset.c -o usbreset`
`chmod +x usbreset`

USB reset issued with Bus Device Path (found with lsusb) as parameter:


`lsusb |grep Huawei'`

   which provides output:
   
```
	Bus 001 Device 003: ID 12d1:14dc Huawei Technologies Co., Ltd. 
   ```
   
USB Bus Device Path:

```
	Bus 001
	Device 003
	ID 12d1:14dc
```

USB reset can be used with these parameters:

Syntax: *usbreset /dev/bus/usb/bus/device*

```sudo usbreset /dev/bus/usb/001/003```


##
Add script to crontab:
```
*/10 * * * * /usr/local/sbin/usb-vpn-check/usb-vpn-check.sh 2>&1
```
