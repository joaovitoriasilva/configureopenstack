#!/bin/bash

#########
# Functions declared here
function getVariablesFromControllerConfigFile() {
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
            if [[ $line == *"KeystoneRegion="* ]]; then
              IFS='=' read -a myarray4 <<< "$line"
              controllerKeystoneRegion=${myarray4[1]}
            else
              if [[ $line == *"CinderPass="* ]]; then
                IFS='=' read -a myarray5 <<< "$line"
                controllerCinderPass=${myarray5[1]}
              else
                if [[ $line == *"CinderDBPass="* ]]; then
                  IFS='=' read -a myarray8 <<< "$line"
                  controllerCinderDBPass=${myarray8[1]}
                fi
              fi
            fi
          fi
        fi
      fi
    fi
  done < "$confFilePathController"
}

function getVariablesFromNetworkConfigFile() {
  confFilePathBS=$(find / -name configFileBlockStorage.txt)
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"OSIP="* ]]; then
    IFS='=' read -a myarray <<< "$line"
      bsOSIP=${myarray[1]}
    fi
  done < "$confFilePathBS"
}

function buildCinderFile() {
  echo "[DEFAULT]
rootwrap_config = /etc/cinder/rootwrap.conf
api_paste_confg = /etc/cinder/api-paste.ini
iscsi_helper = tgtadm
volume_name_template = volume-%s
volume_group = cinder-volumes
verbose = True
auth_strategy = keystone
state_path = /var/lib/cinder
lock_path = /var/lock/cinder
volumes_dir = /var/lib/cinder/volumes

my_ip = $bsOSIP

enabled_backends = lvm

glance_api_servers = http://$controllerHostname:9292

transport_url = rabbit://$RMQUser:$RMQPass@$controllerHostname

[database]
connection = mysql+pymysql://cinder:$controllerCinderDBPass@$controllerHostname/cinder

[keystone_authtoken]
auth_uri = http://$controllerHostname:5000
auth_url = http://$controllerHostname:35357
memcached_servers = $controllerHostname:11211
auth_type = password
project_domain_name = $controllerKeystoneDomain
user_domain_name = $controllerKeystoneDomain
project_name = service
username = cinder
password = $controllerCinderPass

[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = tgtadm

[oslo_concurrency]
lock_path = /var/lib/cinder/tmp" >> cinder.conf
}
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
  echo "This script will install the Cinder OpenStack Block Storage module."
  echo "This is a Block Storage script."
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
  echo "5.1 - Configuring components"
fi
getVariablesFromControllerConfigFile
getVariablesFromNetworkConfigFile

# Setting up LVM
pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb
sed -i '/devices {/a \filter = [ "a/sda/", "a/sdb/", "r/.*/"]' /etc/lvm/lvm.conf

apt-get install cinder-volume -y > /dev/null
buildCinderFile
mv cinder.conf /etc/cinder/cinder.conf
chown cinder:cinder /etc/cinder/cinder.conf
chmod 644 /etc/cinder/cinder.conf

# Finalizing installation
if [[ "$1" != "following" ]]; then
  echo "3 - Finaling installation"
else
  echo "5.2 - Finaling installation"
fi
sleep 2
service tgt restart
service cinder-volume restart

if [[ "$1" != "following" ]]; then
  echo "END"
fi
