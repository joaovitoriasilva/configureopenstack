#!/bin/bash

#########
# Functions declared here
function getVariablesFromConfigFile() {
  confFilePath=$(find / -name configFileController.txt)
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"ODControllerIPAddress="* ]]; then
      IFS='=' read -a myarray <<< "$line"
      ODControllerIPAddress=${myarray[1]}
    else
      if [[ $line == *"ODHostname="* ]]; then
        IFS='=' read -a myarray1 <<< "$line"
        ODControllerHostname=${myarray1[1]}
      fi
    fi
  done < "$confFilePath"
}
########

# Sudo execution
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root."
  exit
fi

# Warnings for the user
echo "This script was tested in Ubuntu 16.04. Other versions weren't tested."
echo "This script will verify your system compability."
echo "Use this script on a OpenStack controller node."
echo ""
echo "This script will replace your /etc/hosts file."
echo "This script WILL need user input"
read -r -p "Do you wish to continue? [y/N]" userInputInitialPrompt

if [[ $userInputInitialPrompt =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "Installation initiated"
else
  exit
fi

# Checking your linux distribution
echo "1 - Checking your linux distribution"
UV=$(lsb_release -r)
if [[ "$UV" != *"16.04"* ]]; then
  echo "This ubuntu version isn't 16.04."
  read -r -p "Do you wish to continue? [y/N]" userInputUbuntuVersion
  if [[ $userInputUbuntuVersion =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Resuming installation with untested Ubuntu version"
  else
    exit
  fi
fi

# Replacing files
echo "2 - Replacing files"
getVariablesFromConfigFile
sleep 2

# Replacing /etc/hostname and /etc/hosts files
echo "2.1 - Adding ODL hosts attribute"
echo "
# OpenDaylight controller
$ODControllerIPAddress  $ODControllerHostname" >> /etc/hosts

# Rebooting and final warnings
echo "As you add more servers to the configuration, you need to add them to the hosts file"
echo "The system need a reboot to apply the changes."
echo "It is not recommended to install ODL controller without restarting."
read -r -p "Do you wish to reboot now or later? [y for now/N for later]" responseReboot
if [[ $responseReboot =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "The system will now reboot."
  reboot
else
  echo "END"
fi