## Introduction
Since Big Sur came out there is a problem when trying to manage updates in more robust way than Apple typically allows. Configuration profiles, delays and MDM commands are just not good enough.

## SUManage
The idea is that SUManage lets you specify a particualar label to download and it will check and tell you when that is finished. You can use this with tools like Jamf to have a more sane user experience. Simply connect your notifications to the current plist output. 

## OS Compatability
This should work on any version of MacOS Monterey, but it will have issues with Big Sur. I am building a fix for that right now. I just have not added the changes. I am still doing some analysis of Big Sur.

## How It Works
1. Build the plist
2. Start the download of the given software update
3. Record the process has started in the plist
4. Check the log for the MSU_UPDATE entry and record the log line
5. Use the log date provided to search for the completion string
6. Verify with another attempt to download the update
7. Mark complete, or retry depending on the results

## Further Improvements
This is a very first attempt and needs much work and help.
