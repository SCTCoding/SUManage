#! /bin/bash

#############################################################
#     _____ __________________          ___            	    #
#    / ___// ____/_  __/ ____/___  ____/ (_)___  ____ _     #
#    \__ \/ /     / / / /   / __ \/ __  / / __ \/ __ `/     #
#   ___/ / /___  / / / /___/ /_/ / /_/ / / / / / /_/ /      #
#  /____/\____/ /_/  \____/\____/\__,_/_/_/ /_/\__, /       # 
#                                             /____/        #  
#############################################################

## Copyright April 26, 2022 Simon

loggedInUser=$(/usr/bin/stat -f%Su /dev/console)
loggedInUID=$(/usr/bin/id -u "$loggedInUser")

## Lable without build
updateLabelSearch="$4"
## Obtain actual label
updateLabel=$(/usr/sbin/softwareupdate --list | /usr/bin/grep -m 1 "$updateLabelSearch" | /usr/bin/awk -F 'Label: ' '{print $2}' | /usr/bin/xargs)
updateLabelNoBuild=$(echo -n "$updateLabel" | /usr/bin/cut -d '-' -f1 | /usr/bin/xargs)
buildNumber=$(echo -n "$updateLabel" | /usr/bin/cut -d '-' -f2 | /usr/bin/xargs)
versionNumber="$5"

msuSearchTerm=$(echo -n "MSU_UPDATE_${buildNumber}_patch_${versionNumber}")
followUpVisit="NO"
needsPassowrd="False"

if [[ "$(/usr/bin/sw_vers -productVersion | /usr/bin/xargs)" == "$versionNumber" ]]
then
	echo "No need to update."
	exit 0
fi

function obtainPasswordFromUser {
	counter=0
	passwordCheck=1

	until [[ $passwordCheck -eq 0 ]] || [[ $counter -ge 4 ]]
	do
		local passwordToCheck=$(/bin/launchctl asuser "$loggedInUID" sudo -iu "$loggedInUser" /usr/bin/osascript << EOD
set userpw to the text returned of (display dialog "Please enter the password for '$loggedInUser'." default answer "" buttons {"Cancel", "Continue"} default button "Continue" with hidden answer)
EOD
)
		passwordToCheckReturn=$?

		if [[ $passwordToCheckReturn -gt 0 ]]
		then
			echo "ERROR: User cancelled."
			exit 0
		fi

		passwordCheck=$(dscl /Local/Default -authonly "$loggedInUser" "$passwordToCheck"; echo $?)

		if [[ $passwordCheck -eq 0 ]]
		then
			echo "$passwordToCheck"
			break
		else
			sleep $(( ( RANDOM % 3 )  + 1 ))
		fi

		counter=$(( $counter + 1 ))
	done
}

if [[ $(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $1}' | /usr/bin/xargs) -eq 12 ]]
then
	downloadCompleteSearch="Download is complete"
elif [[ $(/usr/bin/sw_vers -productVersion | /usr/bin/awk -F '.' '{print $1}' | /usr/bin/xargs) -eq 11 ]]
then
	downloadCompleteSearch="${msuSearchTerm} (no, not downloaded)"
fi

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
	#nowTime=$(date '+%Y-%m-%d %H:%M:%S')

	if [[ "$(/usr/sbin/sysctl "machdep.cpu.brand_string" | /usr/bin/awk -F ' ' '{print $2}')" == "Intel(R)" ]]
	then
		nohup /usr/sbin/softwareupdate --download "$updateLabel" &
	elif [[ "$(/usr/sbin/sysctl "machdep.cpu.brand_string" | /usr/bin/awk -F ' ' '{print $2}')" == "Apple" ]]
	then
		needsPassowrd="True"
		if [[ "$needsPassowrd" == "True" ]]
		then
			passwordProvided=$(obtainPasswordFromUser)

			if [[ -z "$passwordProvided" ]]
			then
				echo "ERROR: Incorrect password provided. Failing."
				exit 1
			fi
		fi

		nohup /usr/sbin/softwareupdate --download "$updateLabel" --stdinpass "$passwordProvided" &
	fi
	
	echo "Download has started for ${updateLabel} in the background"
	/usr/bin/defaults write "/usr/local/SUManage.plist" UpdateDownloadStart -string "$(date '+%Y-%m-%d %H:%M:%S')"
	/usr/bin/defaults write "/usr/local/SUManage.plist" StatusValue -string "STARTED"

	## Grab the log
	if [[ -z $(/usr/bin/defaults read "/usr/local/SUManage.plist" StartingLogLine | /usr/bin/base64 -D | /usr/bin/grep "$msuSearchTerm") ]]
	then
		initialObtainedLog=$(/usr/bin/log show --process "SoftwareUpdateNotificationManager") 
		encodeForPlistLogLine=$(echo "$initialObtainedLog" | /usr/bin/grep "$msuSearchTerm" | /usr/bin/head -n 1 | /usr/bin/base64)

		/usr/bin/defaults write "/usr/local/SUManage.plist" StartingLogLine -string "$encodeForPlistLogLine"	

	fi
else
	dateStartTimeLog=$(/usr/bin/defaults read "/usr/local/SUManage.plist" StartingLogLine | /usr/bin/base64 -D | /usr/bin/awk -F ' ' '{print $1 $2}' | /usr/bin/cut -d '.' -f1)
fi


## See if we are finished
if [[ "$followUpVisit" == "YES" ]] && [[ ! -z $(/usr/bin/log show --process "SoftwareUpdateNotificationManager" --start "$(echo -n "$dateStartTimeLog" | /usr/bin/awk -F ' ' '{print $1}')" | /usr/bin/grep "$downloadCompleteSearch") ]] && [[ "$(/usr/bin/grep -A 1 ">Build<" "/System/Library/AssetsV2/com_apple_MobileAsset_MacSoftwareUpdate/com_apple_MobileAsset_MacSoftwareUpdate.xml" | /usr/bin/head -n 1 | /usr/bin/xargs)" == "$buildNumber" ]]
then
	needsPassowrd="True"
	if [[ "$needsPassowrd" == "True" ]]
	then
		passwordProvided=$(obtainPasswordFromUser)
		if [[ -z "$passwordProvided" ]]
		then
			echo "ERROR: Incorrect password provided. Failing."
			exit 1
		fi
	fi

	if [[ "$(/usr/sbin/sysctl "machdep.cpu.brand_string" | /usr/bin/awk -F ' ' '{print $2}')" == "Intel(R)" ]]
	then
		downloadUpdateReturn=$(/usr/sbin/softwareupdate --download "$updateLabel" | /usr/bin/grep "Downloaded: $updateLabelNoBuild")
	elif [[ "$(/usr/sbin/sysctl "machdep.cpu.brand_string" | /usr/bin/awk -F ' ' '{print $2}')" == "Apple" ]]
	then
		downloadUpdateReturn=$(/usr/sbin/softwareupdate --download "$updateLabel" --stdinpass "$passwordProvided" | /usr/bin/grep "Downloaded: $updateLabelNoBuild")
	fi

	if [[ -z "$downloadUpdateReturn" ]] || [[ -z $(/usr/bin/log show --predicate 'eventMessage contains "BOOT_TIME"' --start "$(echo -n "$dateStartTimeLog" | /usr/bin/awk -F ' ' '{print $1}')" | /usr/bin/grep "=== system boot:") ]]
	then
		echo "Download did not finish. Try again."
		/usr/bin/defaults write "/usr/local/SUManage.plist" StatusValue -string "RESTARTED"
	else
		echo "Update ${updateLabel} successfully downloaded"
		/usr/bin/defaults write "/usr/local/SUManage.plist" StatusValue -string "COMPLETE"
		/usr/bin/notifyutil -p "updateDownloaded"
	fi

fi

exit 0
