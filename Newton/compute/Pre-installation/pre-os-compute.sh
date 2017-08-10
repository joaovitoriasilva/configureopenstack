#!/bin/bash

#########
# Functions declared here
function getVariablesFromControllerConfigFile() {
  configFilePathController=$(find / -name configFileController.txt)
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"OSIP="* ]]; then
      IFS='=' read -a myarray <<< "$line"
      controllerOSIP=${myarray[1]}
    else
      if [[ $line == *"ControllerHostname="* ]]; then
        IFS='=' read -a myarray1 <<< "$line"
        controllerHostname=${myarray1[1]}
      else
        if [[ $line == *"ODHostname="* ]]; then
          IFS='=' read -a myarray2 <<< "$line"
          ODControllerHostname=${myarray2[1]}
        else
          if [[ $line == *"ODControllerIPAddress="* ]]; then
            IFS='=' read -a myarray3 <<< "$line"
            ODControllerIPAddress=${myarray3[1]}
          fi
        fi
      fi
    fi
  done < "$configFilePathController"
}

function getVariablesFromNetworkConfigFile() {
  configFilePathNetwork=$(find / -name configFileNetwork.txt)
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"OSIP="* ]]; then
      IFS='=' read -a myarray <<< "$line"
      networkOSIP=${myarray[1]}
    else
      if [[ $line == *"NetworkHostname="* ]]; then
        IFS='=' read -a myarray1 <<< "$line"
        networkHostname=${myarray1[1]}
      fi
    fi
  done < "$configFilePathNetwork"
}

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

function buildInterfacesFile() {
  echo "# Keep this interface as you see it
# The loopback network interface
auto lo
iface lo inet loopback

# Compute node network interface for internet access
auto enp0s3
iface enp0s3 inet static
  address $OSIPAddress
  netmask $OSNetmask
  dns-nameservers 8.8.8.8 8.8.4.4" >> interfaces
  if [[ ${#OSGateway[@]} -eq 1 ]]; then
	echo "  gateway ${OSGateway[0]}" >> interfaces
  else
    value=100 
    for i in "${OSGateway[@]}"
	  do
	  echo "  up ip route add default via $i dev enp0s3 metric $value" >> interfaces
	  value=$((value+100))
	done
  fi
 
 echo "
# Compute node network interface for tunnel network
auto enp0s8
iface enp0s8 inet static
  address $OSIPAddressTunnel
  netmask $OSNetmaskTunnel
	
# Compute node network interface for VLAN network
auto enp0s9
iface enp0s9 inet manual
  up ip link set dev \$IFACE up
  down ip link set dev \$IFACE down" >> interfaces
}

function buildHostnameFile() {
  echo "$computeHostname" >> hostname
}

function buildHostsFile() {
  echo "127.0.0.1 localhost
# 127.0.1.1 $computeHostname

# Change the name of the hosts to your needs
# controller
$controllerOSIP       $controllerHostname

# controller OD
$ODControllerIPAddress		  $ODControllerHostname

# network
$networkOSIP	    $networkHostname  

# compute1
$OSIPAddress      $computeHostname

# block1
# 10.0.0.41       block1

# object1
# 10.0.0.51       object1

::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters" >> hosts
}

function buildConfigFile() {
  echo "[compute]
OSIP=$OSIPAddress
OSNetmask=$OSNetmask" >> ../configFileCompute.txt
  if [[ ${#OSGateway[@]} -eq 1 ]]; then
	echo "OSGateway1=${OSGateway[0]}" >> ../configFileCompute.txt
  else
    value=1 
    for i in "${OSGateway[@]}"
	  do
	  echo "OSGateway$value=$i" >> ../configFileCompute.txt
	  value=$((value+1))
	done
  fi
echo "OSIPTunnel=$OSIPAddressTunnel
OSNetmaskTunnel=$OSNetmaskTunnel
ComputeHostname=$computeHostname
" >> ../configFileCompute.txt
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
echo "It's recommended to use a clean install."
echo ""
echo "This script will replace your /etc/network/interfaces, /etc/hosts and /etc/network/interfaces files."
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
  echo "This ubuntu version isn't 14.04."
  read -r -p "Do you wish to continue? [y/N]" userInputUbuntuVersion
  if [[ $userInputUbuntuVersion =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Resuming installation with untested Ubuntu version"
  else
    exit
  fi
fi

# Updating system
echo "2 - Updating system"
sleep 2
apt-get update > /dev/null && apt-get dist-upgrade -y > /dev/null

# Verifying and importing data from config file
echo "3 - Verifying and importing data from config file"
getVariablesFromControllerConfigFile
getVariablesFromNetworkConfigFile

# Replacing files
echo "4 - Replacing files"
echo "This script, by default, will use the 10.0.0.0/24 network, 10.0.0.31 IPv4 address and three gateways (10.0.0.254, 10.0.0.253 and 10.0.0.252) for the compute node management interface"
read -r -p "Use default? [y/N]" userInputResponseOSManagementNetwork
if [[ $userInputResponseOSManagementNetwork =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "Using default network (10.0.0.0/24)"
  OSIPAddress=10.0.0.31
  OSNetmask=255.255.255.0
  OSGateway+=('10.0.0.254')
  OSGateway+=('10.0.0.253')
  OSGateway+=('10.0.0.252')
else
  validInputOS=true
  while $validInputOS; do
    echo "Insert the new values for the compute node management interface"
    read -r -p "Compute node IP address: " userInputNewNetworkIP
    read -r -p "Netmask: " userInputNewOSNetmask
	  read -r -p "Multiple gateways? [y/N]" userInputResponseMultiGateways
    if [[ $userInputResponseMultiGateways =~ ^([yY][eE][sS]|[yY])$ ]]; then
      validNumber=true
      while $validNumber; do
        read -r -p "How many gateways? " userInputResponseGatewaysNumber
        if [[ $userInputResponseGatewaysNumber =~ ^-?[0-9]+$ ]]; then
          aux=0
          while [ $aux -lt $userInputResponseGatewaysNumber ]; do
            aux=$((aux+1))
            read -r -p "Compute node gateway address $aux: " userInputNewNetworkGateway
            OSGateway+=("$userInputNewNetworkGateway")
          done
          found=0
          for i in "${OSGateway[@]}"
          do
            if [[ $(ipValidation $i) -ne 0 ]]; then
              found=1
            fi
          done
          if [[ $found -eq 0 ]]; then
            if [[ $(ipValidation $userInputNewOSNetmask) -eq 0 ]] && [[ $(ipValidation $userInputNewNetworkIP) -eq 0 ]]; then 
              validNumber=false
              validInputOS=false
              OSIPAddress=$userInputNewNetworkIP
              OSNetmask=$userInputNewOSNetmask
            fi
          fi
        fi
      done
    else
      read -r -p "Network node gateway address: " userInputNewNetworkGateway
      if [[ $(ipValidation $userInputNewOSNetmask) -eq 0 ]] && [[ $(ipValidation $userInputNewNetworkIP) -eq 0 ]] && [[ $(ipValidation $userInputNewNetworkGateway) -eq 0 ]]; then
          validInputOS=false
          OSIPAddress=$userInputNewNetworkIP
          OSNetmask=$userInputNewOSNetmask
          OSGateway+=("$userInputNewNetworkGateway")
        fi
    fi
  done
fi
echo "This script, by default, will use the 10.0.1.0/24 network and the 10.0.1.31 IPv4 address for the network node tunnel interface"
read -r -p "Use default? [y/N]" userInputResponseOSTunnelNetwork
if [[ $userInputResponseOSTunnelNetwork =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "Using default network (10.0.1.0/24)"
  OSIPAddressTunnel=10.0.1.31
  OSNetmaskTunnel=255.255.255.0
else
  validInputOS=true
  while $validInputOS; do
    echo "Insert the new values for the network node tunnel interface"
    read -r -p "Compute node tunnel IP address: " userInputNewTunnelIP
    read -r -p "Tunnel network netmask: " userInputNewTunnelNetmask
    if [[ $(ipValidation $userInputNewTunnelIP) -eq 0 ]] && [[ $(ipValidation $userInputNewTunnelNetmask) -eq 0 ]]; then
      validInputOS=false
    fi
  done
  OSIPAddressTunnel=$userInputNewTunnelIP
  OSNetmaskTunnel=$userInputNewTunnelNetmask
fi
buildInterfacesFile
mv interfaces /etc/network/interfaces

# Replacing /etc/hostname and /etc/hosts files
echo "4.2 - Replacing /etc/hostname and /etc/hosts files"
echo "This script, by default, will use the following hostname \"compute1\""
read -r -p "Use default? [y/N]" userInputResponseHostname
if [[ $userInputResponseHostname =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "Using default hostname"
  computeHostname="compute1"
else
  read -r -p "Insert the new hostname: " userInputNewHostname
  computeHostname=$userInputNewHostname
fi
buildHostnameFile
buildHostsFile
mv hostname /etc/hostname
mv hosts /etc/hosts

#  Generating config file
echo "5 - Generating config file"
buildConfigFile

# Rebooting and final warnings
echo "As you add more servers to the configuration, you need to add them to the hosts file"
echo "The system need a reboot to apply the changes."
echo "It is not recommended to install OpenStack and its modules without restarting."
read -r -p "Do you wish to reboot now or later? [y for now/N for later]" responseReboot
if [[ $responseReboot =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "The system will now reboot."
  reboot
else
  echo "END"
fi
