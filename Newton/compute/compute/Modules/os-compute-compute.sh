#!/bin/bash

#########
# Functions declared here
function getVariablesFromConfigFileController() {
  confFilePathController=$(find / -name configFileController.txt)
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"ControllerHostname="* ]]; then
      IFS='=' read -a myarray <<< "$line"
      controllerHostname=${myarray[1]}
    else
      if [[ $line == *"RMQUser="* ]]; then
        IFS='=' read -a myarray1 <<< "$line"
        controllerRMQUser=${myarray1[1]}
      else
        if [[ $line == *"RMQPass="* ]]; then
          IFS='=' read -a myarray2 <<< "$line"
          controllerRMQPass=${myarray2[1]}
        else
          if [[ $line == *"KeystoneDomain="* ]]; then
            IFS='=' read -a myarray3 <<< "$line"
            controllerKeystoneDomain=${myarray3[1]}
          else
            if [[ $line == *"NovaPass="* ]]; then
              IFS='=' read -a myarray4 <<< "$line"
              controllerNovaPass=${myarray4[1]}
            fi
          fi
        fi
      fi
    fi
  done < "$confFilePathController"
}

function getVariablesFromConfigFileCompute() {
  confFilePathCompute=$(find / -name configFileCompute.txt)
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"ComputeHostname="* ]]; then
      IFS='=' read -a myarray <<< "$line"
      computeHostname=${myarray[1]}
    else
      if [[ $line == *"OSIP="* ]]; then
        IFS='=' read -a myarray1 <<< "$line"
        computeOSIP=${myarray1[1]}
      else
        if [[ $line == *"OSIPTunnel="* ]]; then
          IFS='=' read -a myarray2 <<< "$line"
          computeOSIPTunnel=${myarray2[1]}
        fi
      fi
    fi
  done < "$confFilePathCompute"
}

function buildNovaFile() {
  echo "[DEFAULT]
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
rootwrap_config=/etc/nova/rootwrap.conf
verbose=True
auth_strategy = keystone
my_ip = $computeOSIP
use_neutron = True
firewall_driver = nova.virt.firewall.NoopFirewallDriver
transport_url = rabbit://$controllerRMQUser:$controllerRMQPass@$controllerHostname

[keystone_authtoken]
auth_uri = http://$controllerHostname:5000
auth_url = http://$controllerHostname:35357
memcached_servers = $controllerHostname:11211
auth_type = password
project_domain_name = $controllerKeystoneDomain
user_domain_name = $controllerKeystoneDomain
project_name = service
username = nova
password = $controllerNovaPass

[vnc]
enabled = True
vncserver_listen = \$my_ip
vncserver_proxyclient_address = \$my_ip
novncproxy_base_url = http://$controllerHostname:6080/vnc_auto.html

[glance]
api_servers = http://$controllerHostname:9292

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

[wsgi]
api_paste_config = /etc/nova/api-paste.ini" >> nova.conf
}

function buildNovaComputeFile() {
  if [[ "$virtualCap" == "0" ]]; then
    echo "[DEFAULT]
compute_driver=libvirt.LibvirtDriver
[libvirt]
virt_type=qemu" >> nova-compute.conf
  else
    echo "[DEFAULT]
compute_driver=libvirt.LibvirtDriver
[libvirt]
virt_type=kvm" >> nova-compute.conf
  fi
}
#########

if [[ "$1" != "" ]] && [[ "$1" != "following" ]]; then
  echo "Option -$1- not valid"
  echo "Rerun script with a valid option (following) or without arguments"
  exit
fi

if [[ "$1" != "following" ]]; then
  # Sudo execution verifycation
  if [[ "$EUID" -ne 0 ]]; then
    echo "Please run this script as root."
    exit
  fi
  # Warnings for the user
  echo "This script was tested in Ubuntu 14.04. Other versions weren't tested."
  echo "You linux distribution will be tested for compatibility.\n"
  echo "This script will install the Nova OpenStack compute module."
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
  if [[ "$UV" != *"14.04"* ]]; then
    echo "This ubuntu version isn't 14.04."
    read -r -p "Do you wish to continue? [y/N]" responseVersion
    if [[ $responseVersion =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo ""
    else
      exit
    fi
  fi
fi

# Installing and configuring components
if [[ "$1" != "following" ]]; then
  echo "2 - Installing and configuring components"
else
  echo "4.1 - Installing and configuring components"
fi
getVariablesFromConfigFileController
getVariablesFromConfigFileCompute
apt-get install nova-compute -y > /dev/null
buildNovaFile
mv nova.conf /etc/nova/nova.conf
chown nova:nova /etc/nova/nova.conf
chmod 640 /etc/nova/nova.conf

virtualCap=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
buildNovaComputeFile
mv nova-compute.conf /etc/nova/nova-compute.conf
chown nova:nova /etc/nova/nova-compute.conf
chmod 640 /etc/nova/nova-compute.conf

# Installing and configuring components
if [[ "$1" != "following" ]]; then
  echo "3 - Finalizing installation"
else
  echo "4.2 - Finalizing installation"
fi
service nova-compute restart
rm -f /var/lib/nova/nova.sqlite

if [[ "$1" != "following" ]]; then
  echo "END"
fi
