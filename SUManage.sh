#! /bin/bash

#############################################################
#     _____ __________________          ___            	    #
#    / ___// ____/_  __/ ____/___  ____/ (_)___  ____ _     #
#    \__ \/ /     / / / /   / __ \/ __  / / __ \/ __ `/     #
#   ___/ / /___  / / / /___/ /_/ / /_/ / / / / / /_/ /      #
#  /____/\____/ /_/  \____/\____/\__,_/_/_/ /_/\__, /       # 
#                                             /____/        #  
#############################################################

#############################################################
## Create by Simon Carlson-Thies on 4/21/22
## Copyright © 2022 Simon Carlson-Thies All rights reserved.
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
## 
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <https://www.gnu.org/licenses/>.
#############################################################

loggedInUser=$(/usr/bin/stat -f%Su /dev/console)
loggedInUID=$(/usr/bin/id -u "$loggedInUser")

## Lable without build
updateLabelSearch="$4"
## Obtain actual label
updateLabel=$(/usr/sbin/softwareupdate --list | /usr/bin/grep -m 1 "$updateLabelSearch" | /usr/bin/awk -F 'Label: ' '{print $2}' | /usr/bin/xargs)

if [[ -z "$updateLabel" ]]
then
	echo "Update was not available. Please check the name."
	exit 1
fi

updateLabelNoBuild=$(echo -n "$updateLabel" | /usr/bin/cut -d '-' -f1 | /usr/bin/xargs)
buildNumber=$(echo -n "$updateLabel" | /usr/bin/cut -d '-' -f2 | /usr/bin/xargs)
## Desired version number
versionNumber="$5"
storagePath="$6"

if [[ -z "$storagePath" ]]
then
	storagePath="/usr/local"
else
	if [[ ! -z $(echo -n "$storagePath" | /usr/bin/grep -E '/$') ]]
	then
		storagePath=$(echo -n "$storagePath" | /usr/bin/sed -e 's/\/$//g')
		if [[ ! -e "$storagePath" ]]
		then
			mkdir -p "$storagePath"
		fi
	fi
fi

msuSearchTerm=$(echo -n "MSU_UPDATE_${buildNumber}_patch_${versionNumber}")
followUpVisit="NO"
needsPassowrd="False"

if [[ "$(/usr/bin/sw_vers -productVersion | /usr/bin/xargs)" == "$versionNumber" ]]
then
	echo "No need to update."
	exit 0
fi

if [[ ! -e "${storagePath}/SUmanage.log" ]] || [[ $(/usr/bin/du -k -d 0 "${storagePath}/SUmanage.log" | /usr/bin/awk '{print $1}') -gt 10240 ]]
then
	echo "$(date '+%F %T') LOG STARTED" > "${storagePath}/SUmanage.log"
	echo "$(date '+%F %T') PROCESS STARTED for ${updateLabelSearch}" >> "${storagePath}/SUmanage.log"
else
	echo "$(date '+%F %T') PROCESS STARTED for ${updateLabelSearch}" >> "${storagePath}/SUmanage.log"
fi


if [[ $(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $1}' | /usr/bin/xargs) -eq 12 ]]
then
	downloadCompleteSearch="Download is complete"
elif [[ $(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $1}' | /usr/bin/xargs) -eq 11 ]]
then
	downloadCompleteSearch="${msuSearchTerm} (no, not downloaded)"
fi

## Make sure the plist exists
if [[ ! -e "${storagePath}/SUManage.plist" ]]
then
	touch "${storagePath}/SUManage.plist"
	/usr/bin/chflags hidden "${storagePath}/SUManage.plist"
fi

## Make sure process is not complete
if [[ $(/usr/bin/defaults read "${storagePath}/SUManage.plist" StatusValue) == "COMPLETE" ]]
then
	echo "${updateLabel} already completed"
	exit 0
elif [[ $(/usr/bin/defaults read "${storagePath}/SUManage.plist" StatusValue) == "STARTED" ]]
then
	followUpVisit="YES"
elif [[ $(/usr/bin/defaults read "${storagePath}/SUManage.plist" StatusValue) == "RESTARTED" ]] 
then
	echo "Trying this again. ${updateLabel}"
fi

## Check and fix plist
if [[ "$(/usr/bin/defaults read "${storagePath}/SUManage.plist" UpdateNameReference | /usr/bin/xargs)" != "$updateLabel" ]]
then
	/usr/bin/defaults write "${storagePath}/SUManage.plist" UpdateNameReference -string "$updateLabel"
	/usr/bin/defaults write "${storagePath}/SUManage.plist" DateProcessStarted -string "$(date '+%s')"
	/usr/bin/defaults write "${storagePath}/SUManage.plist" MSU_UPDATE -string "$msuSearchTerm"
	echo "$(date '+%F %T') START DATE: $(/usr/bin/defaults read "${storagePath}/SUManage.plist" DateProcessStarted) for ${updateLabelSearch}" >> "${storagePath}/SUmanage.log"
fi

## Trigger update
if [[ "$followUpVisit" == "NO" ]]
then
	echo "Beginning the update download for ${updateLabel}"
	#nowTime=$(date '+%Y-%m-%d %H:%M:%S')

	nohup /usr/sbin/softwareupdate --download "$updateLabel" &

	echo "$(date '+%F %T') UPDATE DOWNLOAD STARTED for ${updateLabelSearch}" >> "${storagePath}/SUmanage.log"
	
	echo "Download has started for ${updateLabel} in the background"
	/usr/bin/defaults write "${storagePath}/SUManage.plist" UpdateDownloadStart -string "$(date '+%Y-%m-%d %H:%M:%S')"
	/usr/bin/defaults write "${storagePath}/SUManage.plist" StatusValue -string "STARTED"
	echo "$(date '+%F %T') DOWNLOAD STARTED for ${updateLabelSearch}" >> "${storagePath}/SUmanage.log"

	## Grab the log
	if [[ -z $(/usr/bin/defaults read "${storagePath}/SUManage.plist" StartingLogLine | /usr/bin/base64 -D | /usr/bin/grep "$msuSearchTerm") ]]
	then
		initialObtainedLog=$(/usr/bin/log show --process "SoftwareUpdateNotificationManager") 
		encodeForPlistLogLine=$(echo "$initialObtainedLog" | /usr/bin/grep "$msuSearchTerm" | /usr/bin/head -n 1 | /usr/bin/base64)

		/usr/bin/defaults write "${storagePath}/SUManage.plist" StartingLogLine -string "$encodeForPlistLogLine"	

	fi
else
	dateStartTimeLog=$(/usr/bin/defaults read "${storagePath}/SUManage.plist" StartingLogLine | /usr/bin/base64 -D | /usr/bin/awk -F ' ' '{print $1, $2}' | /usr/bin/cut -d '.' -f1)
fi

## macOS 11+
if [[ $(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $1}') -eq 11 ]]
then
	
	echo "$(date '+%F %T') FOLLOWING UP for ${updateLabelSearch}" >> "${storagePath}/SUmanage.log"

	downloadUpdateReturn=$(/usr/sbin/softwareupdate --download "$updateLabel" | /usr/bin/grep "Downloaded: $updateLabelNoBuild")

	if [[ -z "$downloadUpdateReturn" ]] || [[ -z $(/usr/bin/log show --predicate 'eventMessage contains "BOOT_TIME"' --start "$(echo -n "$dateStartTimeLog" | /usr/bin/awk -F ' ' '{print $1}')" | /usr/bin/grep "=== system boot:") ]]
	then
		echo "Download did not finish. Try again."
		/usr/bin/defaults write "${storagePath}/SUManage.plist" StatusValue -string "RESTARTED"
		echo "$(date '+%F %T') RESTARTING PROCESSS for ${updateLabelSearch}" >> "${storagePath}/SUmanage.log"
	else
		echo "Update ${updateLabel} successfully downloaded"
		/usr/bin/defaults write "${storagePath}/SUManage.plist" StatusValue -string "COMPLETE"
		/usr/bin/notifyutil -p "updateDownloaded"
		echo "$(date '+%F %T') DOWNLOAD COMPLETE for ${updateLabelSearch}" >> "${storagePath}/SUmanage.log"
	fi

	exit 0
fi


## See if we are finished macOS 12+
if [[ "$followUpVisit" == "YES" ]] && [[ ! -z $(/usr/bin/log show --process "SoftwareUpdateNotificationManager" --start "$(echo -n "$dateStartTimeLog" | /usr/bin/awk -F ' ' '{print $1}')" | /usr/bin/grep "$downloadCompleteSearch") ]]
then
	
	echo "$(date '+%F %T') FOLLOWING UP for ${updateLabelSearch}" >> "${storagePath}/SUmanage.log"

	downloadUpdateReturn=$(/usr/sbin/softwareupdate --download "$updateLabel" | /usr/bin/grep "Downloaded: $updateLabelNoBuild")

	if [[ -z "$downloadUpdateReturn" ]] || [[ -z $(/usr/bin/log show --predicate 'eventMessage contains "BOOT_TIME"' --start "$(echo -n "$dateStartTimeLog" | /usr/bin/awk -F ' ' '{print $1}')" | /usr/bin/grep "=== system boot:") ]]
	then
		echo "Download did not finish. Try again."
		/usr/bin/defaults write "${storagePath}/SUManage.plist" StatusValue -string "RESTARTED"
		echo "$(date '+%F %T') RESTARTING PROCESSS for ${updateLabelSearch}" >> "${storagePath}/SUmanage.log"
	else
		echo "Update ${updateLabel} successfully downloaded"
		/usr/bin/defaults write "${storagePath}/SUManage.plist" StatusValue -string "COMPLETE"
		/usr/bin/notifyutil -p "updateDownloaded"
		echo "$(date '+%F %T') DOWNLOAD COMPLETE for ${updateLabelSearch}" >> "${storagePath}/SUmanage.log"
	fi

fi

exit 0
