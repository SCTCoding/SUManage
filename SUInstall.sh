#! /bin/bash

#############################################################
#     _____ __________________          ___                 #
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


if [[ -e "/usr/local/Avalara/SUManage.plist" ]]
then
    statusValue=$(/usr/bin/defaults read "/usr/local/Avalara/SUManage.plist" StatusValue | /usr/bin/xargs)
    updateValue=$(/usr/bin/defaults read "/usr/local/Avalara/SUManage.plist" UpdateNameReference | /usr/bin/xargs)
else
    echo "SUManage.plist does not exist. Cannot continue without it."
    exit 1
fi

if [[ "$statusValue" != "COMPLETE" ]]
then
    echo "Update has not downloaded."
    exit 1
fi

readyState="NOT READY"

if [[ ! -z $(/usr/sbin/softwareupdate --list --no-scan | /usr/bin/grep "$updateValue") ]]
then
    readyState="READY"
else
    echo "Update label is wrong, or update is no longer present."
    exit 1
fi

if [[ "$readyState" == "READY" ]]
then
    dialogReturn=1

    until [[ $dialogReturn -eq 0 ]]
    do
        /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -heading "Update Ready To Install" -description "Please save what you are doing and when you are ready click the \"Ready\" button to continue with the installation of ${updateValue}. It may take a few minutes, before your computer is ready to restart, but when ready your computer will restart and install the update." -button1 "Ready" -lockHUD -icon "/System/Library/PreferencePanes/SoftwareUpdate.prefPane/Contents/Resources/SoftwareUpdate.icns"
        dialogReturn=$?
    done
fi

if [[ $dialogReturn -eq 0 ]]
then
    /usr/sbin/softwareupdate --install "$updateValue" --restart
fi

exit 0
