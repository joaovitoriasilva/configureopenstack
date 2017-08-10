#!/bin/bash

#########
# Functions declared here
function getVariablesFromControllerConfigFile() {
  confFilePathController=$(find / -name configFileController.txt)
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"ControllerHostname="* ]]; then
      IFS='=' read -a myarray <<< "$line"
      controllerHostname=${myarray[1]}
    fi
  done < "$confFilePathController"
}
#########

# Sudo execution and argument verifycation
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root."
  exit
else
  if [[ "$1" != "required" ]] && [[ "$1" != "base" ]] && [[ "$1" != "help" ]]; then
    if [[ "$1" == "" ]]; then
      echo "You need to specify one argument"
    else
      echo "Option -$1- not valid"
    fi
    echo "Rerun script with a valid option (base, all or help)"
    exit
  else
    if [[ "$1" == "help" ]]; then
      echo "Run the script with the following options:"
      echo "  help - Get script options"
      echo "  base - Only OpenStack core"
      echo "  all - OpenStack core and all modules"
      exit
    else
      echo "Running script with -$1- enabled"
      echo ""
      sleep 2
    fi
  fi
fi

# Warnings for the user
echo "This script was tested in Ubuntu 16.04. Other versions weren't tested."
echo "You linux distribution will be tested for compatibility.\n"
echo "This script will install all the components needed for a correct network OpenStack installation."
if [[ "$1" == "all" ]]; then
  echo "It'll be installed the following OpenStack modules: Neutron"
fi
echo "This is a network script."
echo "This script WILL need user input.\n"
echo "Do not change the order of the provided directories or files.\n"
read -r -p "Do you wish to continue? [y/N]" userInputInitialPrompt

if [[ $userInputInitialPrompt =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "Resuming installation with -$1- option enabled"
else
  exit
fi

# Executing verifications
echo "1 - Executing verifications"

# Checking linux distribuion version. Must be Ubuntu 14.04
echo "1.1 - Checking your linux distribution"
UV=$(lsb_release -r)
if [[ "$UV" != *"16.04"* ]]; then
  echo "This ubuntu version isn't 16.04."
  read -r -p "Do you wish to continue? [y/N]" userInputUbuntuVersion
  if [[ $userInputUbuntuVersion =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
  else
    exit
  fi
fi

# Verifying and importing data from config file
echo "1.2 - Verifying and importing data from config file"
getVariablesFromControllerConfigFile

if [[ "$1" != "optional" ]]; then
  # Install Chrony packages
  echo "2 - Installing Chrony NTP server"
  sleep 2
  sudo apt-get update > /dev/null
  apt-get install chrony -y > /dev/null

  echo "2.1 - Editing Chrony conf file"
  sed -i "s/pool 2.debian.pool.ntp.org offline iburst/server $controllerHostname iburst/" /etc/chrony/chrony.conf

  echo "2.2 - Restarting Chrony server"
  service chrony restart

  # Install OpenStack packages
  echo "3 - Installing OpenStack packages"
  echo "3.1 - Checking pre-requisites and updating repositories to OpenStack newton version"
  apt-get install software-properties-common -y > /dev/null
  add-apt-repository cloud-archive:newton -y
  apt-get update > /dev/null && apt-get dist-upgrade -y > /dev/null
  echo "3.2 - OpenStack packages"
  apt-get install python-openstackclient -y > /dev/null

  if [[ "$1" != "base" ]]; then
    #Installing OpenStack Neutron module
    echo "4 - Installing Neutron module"
	../Modules/./os-network-network.sh following
    sleep 2
  fi
fi

echo "END"
