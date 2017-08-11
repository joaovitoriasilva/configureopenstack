#!/bin/bash

#########
# Functions declared here

#########

if [[ "$1" != "" ]] && [[ "$1" != "following" ]]; then
  echo "Option -$1- not valid"
  echo "Rerun script with a valid option (main) or without arguments"
  exit
fi

if [[ "$1" != "following" ]]; then
  # Sudo execution verifycation
  if [[ "$EUID" -ne 0 ]]; then
    echo "Please run this script as root."
    exit
  fi
  # Warnings for the user
  echo "This script was tested in Ubuntu 16.04. Other versions weren't tested."
  echo "You linux distribution will be tested for compatibility.\n"
  echo "This script will configure nova for cinder module."
  echo "This is a compute script."
  read -r -p "Do you wish to continue? [y/N]" response

  if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
  else
    exit
  fi

  # Checking linux distribuion version. Must be Ubuntu 14.04
  echo "1 - Checking your linux distribution"
  UV=$(lsb_release -r)
  if [[ "$UV" != *"16.04"* ]]; then
    echo "This ubuntu version isn't 16.04."
    read -r -p "Do you wish to continue? [y/N]" responseVersion
    if [[ $responseVersion =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo ""
    else
      exit
    fi
  fi
fi

# Configuring neutron components
if [[ "$1" != "following" ]]; then
  echo "2 - Configuring components"
else
  echo "6.1 - Configuring components"
fi

# Setting up LVM
sed -i '/devices {/a \filter = [ "a/sda/", "r/.*/"]' /etc/lvm/lvm.conf

if [[ "$1" != "following" ]]; then
  echo "END"
fi
