#! /bin/bash

updateLabel="$4"
updateLabelNoBuild=$(echo -n "$updateLabel" | /usr/bin/cut -d '-' -f1 | /usr/bin/xargs)
buildNumber=$(echo -n "$updateLabel" | /usr/bin/cut -d '-' -f2 | /usr/bin/xargs)
versionNumber="$5"

msuSearchTerm=$(echo -n "MSU_UPDATE_${buildNumber}_patch_${versionNumber}")
followUpVisit="NO"

## Make sure the plist exists
if [[ ! -e "/usr/local/SUManage.plist" ]]
then
	touch "/usr/local/SUManage.plist"
	/usr/bin/chflags hidden "/usr/local/SUManage.plist"
fi

## Make sure process is not complete
if [[ $(/usr/bin/defaults read "/usr/local/SUManage.plist" StatusValue) == "COMPLETE" ]]
then
	echo "${updateLabel} already completed"
	exit 0
elif [[ $(/usr/bin/defaults read "/usr/local/SUManage.plist" StatusValue) == "STARTED" ]]
then
	followUpVisit="YES"
elif [[ $(/usr/bin/defaults read "/usr/local/SUManage.plist" StatusValue) == "RESTARTED" ]] 
then
	echo "Trying this again. ${updateLabel}"
fi

## Check and fix plist
if [[ "$(/usr/bin/defaults read "/usr/local/SUManage.plist" UpdateNameReference | /usr/bin/xargs)" != "$updateLabel" ]]
then
	/usr/bin/defaults write "/usr/local/SUManage.plist" UpdateNameReference -string "$updateLabel"
	/usr/bin/defaults write "/usr/local/SUManage.plist" DateProcessStarted -string "$(date '+%s')"
	/usr/bin/defaults write "/usr/local/SUManage.plist" MSU_UPDATE -string "$msuSearchTerm"
fi

## Trigger update
if [[ "$followUpVisit" == "NO" ]]
then
	echo "Beginning the update download for ${updateLabel}"
	nowTime=$(date '+%Y-%m-%d %H:%M:%S')
	/usr/sbin/softwareupdate --download "$updateLabel" &
	echo "Download has started for ${updateLabel} in the background"
	/usr/bin/defaults write "/usr/local/SUManage.plist" UpdateDownloadStart -string "$(date '+%Y-%m-%d %H:%M:%S')"
	/usr/bin/defaults write "/usr/local/SUManage.plist" StatusValue -string "STARTED"

	## Grab the log
	if [[ -z $(/usr/bin/defaults read "/usr/local/SUManage.plist" StartingLogLine | /usr/bin/base64 -D | /usr/bin/grep "$msuSearchTerm") ]]
	then
		initialObtainedLog=$(log show --process "SoftwareUpdateNotificationManager") 
		encodeForPlistLogLine=$(echo $initialObtainedLog | /usr/bin/grep "$msuSearchTerm" | /usr/bin/head -n 1 | /usr/bin/base64)

		/usr/bin/defaults write "/usr/local/SUManage.plist" StartingLogLine -string "$encodeForPlistLogLine"	

	fi
else
	dateStartTimeLog=$(/usr/bin/defaults read "/usr/local/SUManage.plist" StartingLogLine | /usr/bin/base64 -D | /usr/bin/awk -F ' ' '{print $1 $2}' | /usr/bin/cut -d '.' -f1)
fi

## See if we are finished
if [[ "$followUpVisit" == "YES" ]] && [[ ! -z $(log show --process "SoftwareUpdateNotificationManager" --start "$(echo -n "$dateStartTimeLog" | /usr/bin/awk -F ' ' '{print $1}')" | /usr/bin/grep "Download is complete") ]] && [[ "$(/usr/bin/grep -A 1 ">Build<" "/System/Library/AssetsV2/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml" | /usr/bin/head -n 1 | /usr/bin/xargs)" == "$buildNumber" ]]
if [[  ]] ]]
then
	if [[ -z $(/usr/sbin/softwareupdate --download "$updateLabel" | /usr/bin/grep "Downloaded: $updateLabelNoBuild") ]]
	then
		echo "Download did not finish. Try again."
		/usr/bin/defaults write "/usr/local/SUManage.plist" StatusValue -string "RESTARTED"
	else
		echo "Update ${updateLabel} successfully downloaded"
		/usr/bin/defaults write "/usr/local/SUManage.plist" StatusValue -string "COMPLETE"
	fi

fi

exit 0