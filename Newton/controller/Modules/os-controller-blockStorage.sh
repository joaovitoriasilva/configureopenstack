#!/bin/bash

#########
# Functions declared here
function getVariablesFromConfigFile() {
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"OSIP="* ]]; then
      IFS='=' read -a myarray1 <<< "$line"
      controllerOSIP=${myarray1[1]}
    else
      if [[ $line == *"ControllerHostname="* ]]; then
        IFS='=' read -a myarray2 <<< "$line"
        controllerHostname=${myarray2[1]}
      else
        if [[ $line == *"MDBPass="* ]]; then
          IFS='=' read -a myarray3 <<< "$line"
          controllerMDBPass=${myarray3[1]}
        else
          if [[ $line == *"RMQUser="* ]]; then
            IFS='=' read -a myarray4 <<< "$line"
            controllerRMQUser=${myarray4[1]}
          else
            if [[ $line == *"RMQPass="* ]]; then
              IFS='=' read -a myarray5 <<< "$line"
              controllerRMQPass=${myarray5[1]}
            else
              if [[ $line == *"KeystoneRegion="* ]]; then
                IFS='=' read -a myarray6 <<< "$line"
                controllerKeystoneRegion=${myarray6[1]}
              else
                if [[ $line == *"KeystoneDomain="* ]]; then
                  IFS='=' read -a myarray7 <<< "$line"
                  controllerKeystoneDomain=${myarray7[1]}
                else
                  if [[ $line == *"CinderPass="* ]]; then
                    IFS='=' read -a myarray8 <<< "$line"
                    controllerCinderPass=${myarray8[1]}
                  else
                    if [[ $line == *"CinderDBPass="* ]]; then
                      IFS='=' read -a myarray9 <<< "$line"
                      controllerCinderDBPass=${myarray9[1]}
                    fi
                  fi
                fi
              fi
            fi
          fi
        fi
      fi
    fi
  done < "$confFilePath"
}

function storeServiceModulesDataConfigFile() {
  echo "CinderPass=$userInputCinderPass
CinderDBPass=$userInputCinderDBPass" >> $confFilePath
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

rpc_backend = rabbit

auth_strategy = keystone

my_ip = $controllerOSIP

#notification_driver = messagingv2
transport_url = rabbit://$controllerRMQUser:$controllerRMQPass@$controllerHostname

[database]
connection = mysql+pymysql://cinder:$controllerCinderDBPass@$controllerHostname/cinder

[keystone_authtoken]
auth_uri = http://$controllerHostname:5000
auth_url = http://$controllerHostname:35357
memcached_servers = $controllerHostname:11211
auth_plugin = password
project_domain_name = $controllerKeystoneDomain
user_domain_name = $controllerKeystoneDomain
project_name = service
username = cinder
password = $controllerCinderPass

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
  echo "This script will install the Cinder OpenStack controller module."
  echo "This is a controller script."
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

# Installing prerequisites
if [[ "$1" != "following" ]]; then
  echo "2 - Installing prerequisites"
else
  echo "12.1 - Installing prerequisites"
fi

# Getting user input data and storing it in the config file
confFilePath=$(find / -name configFileController.txt)
if [[ "$1" != "following" ]]; then
  echo "2.1 - Getting user input data and storing it in the config file"
  userInputCinderPass=`openssl rand -hex 10`
  userInputCinderDBPass=`openssl rand -hex 10`
  storeServiceModulesDataConfigFile
fi
getVariablesFromConfigFile

# Database commands
if [[ "$1" != "following" ]]; then
  echo "2.2 - Creating MySQL database for Cinder"
else
  echo "12.1.1 - Creating MySQL database for Cinder"
fi
user=root
database=cinder
#mysql --user="$user" --password="$controllerMDBPass" --execute="CREATE DATABASE $database;"
#mysql --user="$user" --password="$controllerMDBPass" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'localhost' IDENTIFIED BY '$controllerCinderDBPass';"
#mysql --user="$user" --password="$controllerMDBPass" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'%' IDENTIFIED BY '$controllerCinderDBPass';"
mysql --user="$user" --execute="CREATE DATABASE $database;"
mysql --user="$user" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'localhost' IDENTIFIED BY '$controllerCinderDBPass';"
mysql --user="$user" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'%' IDENTIFIED BY '$controllerCinderDBPass';"

# Create the service entity and API endpoints
if [[ "$1" != "following" ]]; then
  echo "2.3 - Create the service entity and API endpoints"
else
  echo "12.1.2 - Create the service entity and API endpoints"
fi
sourcePathAdmin=$(find / -name admin-openrc.sh)
. $sourcePathAdmin
openstack user create --domain $controllerKeystoneDomain --password $controllerCinderPass cinder
openstack role add --project service --user cinder admin
openstack service create --name cinder --description "OpenStack Block Storage" volume
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
openstack endpoint create --region $controllerKeystoneRegion volume public http://$controllerHostname:8776/v1/%\(tenant_id\)s
openstack endpoint create --region $controllerKeystoneRegion volume internal http://$controllerHostname:8776/v1/%\(tenant_id\)s
openstack endpoint create --region $controllerKeystoneRegion volume admin http://$controllerHostname:8776/v1/%\(tenant_id\)s
openstack endpoint create --region $controllerKeystoneRegion volumev2 public http://$controllerHostname:8776/v2/%\(tenant_id\)s
openstack endpoint create --region $controllerKeystoneRegion volumev2 internal http://$controllerHostname:8776/v2/%\(tenant_id\)s
openstack endpoint create --region $controllerKeystoneRegion volumev2 admin http://$controllerHostname:8776/v2/%\(tenant_id\)s

# Configuring cinder components
if [[ "$1" != "following" ]]; then
  echo "3 - Configuring components"
else
  echo "12.2 - Configuring components"
fi
apt-get install cinder-api cinder-scheduler -y > /dev/null
buildCinderFile
mv cinder.conf /etc/cinder/cinder.conf
chown cinder:cinder /etc/cinder/cinder.conf
chmod 644 /etc/cinder/cinder.conf

su -s /bin/sh -c "cinder-manage db sync" cinder

echo "
[cinder]
os_region_name = $controllerKeystoneRegion" >> /etc/nova/nova.conf

# Finalizing installation
if [[ "$1" != "following" ]]; then
  echo "4 - Finalizing installation"
else
  echo "12.3 - Finalizing installation"
fi
service nova-api restart
service cinder-scheduler restart
service cinder-api restart
rm -f /var/lib/cinder/cinder.sqlite

if [[ "$1" != "following" ]]; then
  echo "END"
fi
