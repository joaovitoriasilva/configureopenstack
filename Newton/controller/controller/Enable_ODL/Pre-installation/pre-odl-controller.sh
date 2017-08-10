#!/bin/bash

#########
# Functions declared here
function ipValidation() {
  local  ip=$1
  local  stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
      OIFS=$IFS
      IFS='.'
      ip=($ip)
      IFS=$OIFS
      if [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]; then
        stat=$?
      fi
  fi
  echo $stat
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
sleep 2

# Replacing /etc/hostname and /etc/hosts files
echo "2.1 - Adding ODL hosts attribute"
echo "Insert OpenDaylight controller information"
read -r -p "OpenDaylight controller hostname: " userInputODHostname
ODControllerHostname=$userInputODHostname
validInputODIP=true
  while $validInputODIP; do
    read -r -p "OpenDaylight controller IP: " userInputODIP
    if [[ $(ipValidation $userInputODIP) -eq 0 ]]; then
      ODControllerIPAddress=$userInputODIP
      validInputODIP=false
    fi
  done
echo "
# OpenDaylight controller
$ODControllerIPAddress  $ODControllerHostname" >> /etc/hosts

# adding additional variables to config file
echo "2.2 - Adding ODL hosts attribute"
sleep 2
configFile=$(find / -type f -name "configFileController.txt")
echo "ODControllerIPAddress=$ODControllerIPAddress
ODHostname=$ODControllerHostname" >> $configFile

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