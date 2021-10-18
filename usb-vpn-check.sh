#!/bin/bash

SCRIPT=`realpath -s $0`
SCRIPTPATH=`dirname $SCRIPT`

IP='1.1.1.1'
NOW=$(date '+%d/%m/%Y %H:%M:%S')
DT_NOW=$(date '+%Y-%m-%d %H:%M:%S')
USB_CHECK_FILENAME=$SCRIPTPATH'/usb_check_timestamp'
REBOOT_CHECK_FILENAME=$SCRIPTPATH'/reboot_check_timestamp'
REBOOT_COUNT_FILENAME=$SCRIPTPATH'/reboot_count'
MAX_SYSTEM_REBOOT=3
USB_KEY_BRAND='Huawei'
USB_KEY_PATH=''
DIFF_TIME_USB_CHECK_TS=600
#DIFF_TIME_REBOOT_CHECK_TS=3600
DIFF_TIME_REBOOT_CHECK_TS=1800
#DIFF_TIME_DAILY_REBOOT_TS=86400
DIFF_TIME_DAILY_REBOOT_TS=3600

diff_check_timestamp(){
	# ARG1: filename to check timestamp
	# ARG2: time in second the check delta T

	if [ -z "$1" ]; then
		echo "No file timestamp to check"
	else
		if [ -z "$2" ]; then
			echo "No diff timestamp to check"
		else
			#DTA=$(date --date '2017-08-17 04:00:01' +%s)
			#echo "DT_NOW: $DT_NOW"
			DTA=$(date --date "$DT_NOW" +%s)
			FILE_TIMESTAMP=$(stat --printf=%y $1 | cut -d. -f1)
			#echo "FILE_TIMESTAMP: $FILE_TIMESTAMP"
			DTB=$(date --date "$FILE_TIMESTAMP" +%s)
			#echo "DTB: $DTB"
			delta=$((DTA - DTB))
			echo "$delta seconds"
			if [ "$delta" -gt "$2" ]; then
				echo "Threshold exceeded"
				false
			else
				echo "Threshold not exceeded"
				return
			fi
		fi
	fi
}

reboot_count_check(){
	echo "-- Reboot count check"
	# If reboot count file not exist create with 0 value
	if [ ! -f $REBOOT_COUNT_FILENAME ]; then
		echo 0 > $REBOOT_COUNT_FILENAME
	else
		# If reboot check file not exist create new one
		if [ ! -f $REBOOT_CHECK_FILENAME ]; then
			echo "Creating $REBOOT_CHECK_FILENAME"
			#touch -amt $(date +%Y%m%d%H%M -d "yesterday") $REBOOT_CHECK_FILENAME
			touch -am $REBOOT_CHECK_FILENAME
		fi
	fi

	# If reboot count file has less or equal value of max value increment
	if [ $(<$REBOOT_COUNT_FILENAME) -le $MAX_SYSTEM_REBOOT ]; then
		echo "Current Reboot Count ($(<$REBOOT_COUNT_FILENAME)) < Max Reboot Retries ($MAX_SYSTEM_REBOOT)"
		NEW_REBOOT_COUNT=$(($(<$REBOOT_COUNT_FILENAME) + 1)) 
		echo $NEW_REBOOT_COUNT > $REBOOT_COUNT_FILENAME
		return
	else
		echo "Current Reboot Count ($(<$REBOOT_COUNT_FILENAME)) > Max Reboot Retries ($MAX_SYSTEM_REBOOT)"

		# If reboot check filename timestamp is older than 1 day allow new reboot (reset count & timestamp)
		if diff_check_timestamp $REBOOT_CHECK_FILENAME $DIFF_TIME_DAILY_REBOOT_TS; then
			# Reset reboot count file
			#echo "Wait for reset reboot due threshold not exceeded 24h"
			echo "Wait for reset reboot due threshold not exceeded $DIFF_TIME_DAILY_REBOOT_TS"
		else
			# Reset reboot count file
			echo "Reset reboot count file"
			echo 0 > $REBOOT_COUNT_FILENAME
			echo "Reset rebot check file timestamp"
			touch -am $REBOOT_CHECK_FILENAME
		fi
		false
	fi
}

ping_ip_check(){
	# Try to ping ip address and get response
	ping -c 1 $IP &> /dev/null
	if [[ $? -ne 0 ]]; then
		echo "ERROR "$NOW
		echo "[$NOW] ERROR" >> $SCRIPTPATH/logs/$(date '+%Y%m%d').log
		false
	else
		echo "OK "$NOW
		echo "[$NOW] OK" >> $SCRIPTPATH/logs/$(date '+%Y%m%d').log
		return
	fi
}

search_usb_key(){
	# Search for USB key path device
	echo $(lsusb | grep "$USB_KEY_BRAND"); USB_KEY_PATH=$( lsusb | grep "$USB_KEY_BRAND" | perl -nE "/\D+(\d+)\D+(\d+).+/; print qq(\$1/\$2)") 
	
	# Check if USB key path string length result is equal 0
	if [[ "0" -eq ${#USB_KEY_PATH} ]]; then
		echo "USB Key not found!"
		false
	else
		echo "USB Key found at: $USB_KEY_PATH"
		return
	fi
}

if [ ! -d $SCRIPTPATH/logs/ ]; then
	mkdir -p $SCRIPTPATH/logs/
fi

if ping_ip_check; then
	echo "Ping check status: true"
else
	echo "Ping check status: false"
	if search_usb_key; then
		# If usb check filename not exist create new one, first check need timestamp
		if [ ! -f $USB_CHECK_FILENAME ]; then
			touch $USB_CHECK_FILENAME 
		fi
		if diff_check_timestamp $USB_CHECK_FILENAME $DIFF_TIME_USB_CHECK_TS; then
			# Wait USB reset due threshold not exceeded
			echo "Wait USB reset due threshold not exceeded"
		else
			# Try USB reset with device path found
			echo "Try USB reset, /dev/bus/usb/$USB_KEY_PATH"
			#/usr/local/sbin/usbreset/usbreset /dev/bus/usb/$USB_KEY_PATH
			$SCRIPTPATH/usbreset /dev/bus/usb/$USB_KEY_PATH
			touch -am $USB_CHECK_FILENAME
			sleep 15
			service openvpn restart
		fi
	else
		if diff_check_timestamp $REBOOT_CHECK_FILENAME $DIFF_TIME_REBOOT_CHECK_TS; then
			# Wait system reboot due threshold not exceeded
			echo "Wait system reboot due threshold not exceeded"
		else
			# Try system restart
			echo "Try system reboot"
			#touch -am $REBOOT_CHECK_FILENAME
			if reboot_count_check; then
				echo "Reboot count check pass, reboot"
				#echo 0 > $REBOOT_COUNT_FILENAME
				echo "[$NOW] REBOOT" >> $SCRIPTPATH/logs/$(date '+%Y%m%d').log
				echo "REBOOT!"
				shutdown -r now
			fi
		fi
	fi
fi
