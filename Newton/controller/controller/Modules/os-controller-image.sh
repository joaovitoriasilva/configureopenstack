#!/bin/bash

#########
# Functions declared here
function getVariablesFromConfigFile() {
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"ControllerHostname="* ]]; then
      IFS='=' read -a myarray <<< "$line"
      controllerHostname=${myarray[1]}
    else
      if [[ $line == *"MDBPass="* ]]; then
        IFS='=' read -a myarray1 <<< "$line"
        controllerMDBPass=${myarray1[1]}
      else
        if [[ $line == *"KeystoneRegion="* ]]; then
          IFS='=' read -a myarray2 <<< "$line"
          controllerKeystoneRegion=${myarray2[1]}
        else
          if [[ $line == *"KeystoneDomain="* ]]; then
            IFS='=' read -a myarray3 <<< "$line"
            controllerKeystoneDomain=${myarray3[1]}
          else
            if [[ $line == *"GlancePass="* ]]; then
              IFS='=' read -a myarray4 <<< "$line"
              controllerGlancePass=${myarray4[1]}
            else
              if [[ $line == *"GlanceDBPass="* ]]; then
                IFS='=' read -a myarray5 <<< "$line"
                controllerGlanceDBPass=${myarray5[1]}
              fi
            fi
          fi
        fi
      fi
    fi
  done < "$confFilePath"
}

function storeServiceModulesDataConfigFile() {
  echo "GlancePass=$userInputGlancePass
GlanceDBPass=$userInputGlanceDBPass" >> $confFilePath
}

function buildGlanceAPIFile() {
  echo "[DEFAULT]
verbose = True

[database]
connection = mysql+pymysql://glance:$controllerGlanceDBPass@$controllerHostname/glance
backend = sqlalchemy

[keystone_authtoken]
auth_uri = http://$controllerHostname:5000
auth_url = http://$controllerHostname:35357
memcached_servers = $controllerHostname:11211
auth_type = password
project_domain_name = $controllerKeystoneDomain
user_domain_name = $controllerKeystoneDomain
project_name = service
username = glance
password = $controllerGlancePass

[paste_deploy]
flavor = keystone

[glance_store]
stores = file,http
default_store = file
filesystem_store_datadir = /var/lib/glance/images/

[image_format]
disk_formats = ami,ari,aki,vhd,vhdx,vmdk,raw,qcow2,vdi,iso,root-tar" >> glance-api.conf
}

function buildGlanceRegistryFile() {
  echo "[DEFAULT]
verbose = True

[database]
connection = mysql+pymysql://glance:$controllerGlanceDBPass@$controllerHostname/glance
backend = sqlalchemy

[keystone_authtoken]
auth_uri = http://$controllerHostname:5000
auth_url = http://$controllerHostname:35357
memcached_servers = $controllerHostname:11211
auth_type = password
project_domain_name = $controllerKeystoneDomain
user_domain_name = $controllerKeystoneDomain
project_name = service
username = glance
password = $controllerGlancePass

[paste_deploy]
flavor = keystone" >> glance-registry.conf
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
  echo "This script was tested in Ubuntu 14.04. Other versions weren't tested."
  echo "You linux distribution will be tested for compatibility.\n"
  echo "This script will install the Glance OpenStack controller module."
  echo "This is a controller script."
  echo "Change the provided files to your needs."
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

# Installing glance prerequisites
if [[ "$1" != "following" ]]; then
  echo "2 - Installing prerequisites"
else
  echo "8.1 - Installing prerequisites"
fi

# Getting user input data and storing it in the config file
confFilePath=$(find / -name configFileController.txt)
if [[ "$1" != "following" ]]; then
  echo "2.1 - Getting user input data and storing it in the config file"
  echo "SERVICE PASSWORDS"
  echo "It is recommended that you use distinct passwords for each module and service"
  read -r -p "Glance (Image) server password: " userInputGlancePass
  read -r -p "Glance (Image) DB password: " userInputGlanceDBPass
  storeServiceModulesDataConfigFile
fi
getVariablesFromConfigFile

# Database commands
if [[ "$1" != "following" ]]; then
  echo "2.2 - Creating MySQL database for Glance"
else
  echo "8.1.1 - Creating MySQL database for Glance"
fi
user=root
database=glance
#mysql --user="$user" --password="$controllerMDBPass" --execute="CREATE DATABASE $database;"
#mysql --user="$user" --password="$controllerMDBPass" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'localhost' IDENTIFIED BY '$controllerGlanceDBPass';"
#mysql --user="$user" --password="$controllerMDBPass" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'%' IDENTIFIED BY '$controllerGlanceDBPass';"
mysql --user="$user" --execute="CREATE DATABASE $database;"
mysql --user="$user" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'localhost' IDENTIFIED BY '$controllerGlanceDBPass';"
mysql --user="$user" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'%' IDENTIFIED BY '$controllerGlanceDBPass';"


# Creating service credentials
if [[ "$1" != "following" ]]; then
  echo "2.2 - Creating service credentials"
else
  echo "8.1.2 - Creating service credentials"
fi
sourcePathAdmin=$(find / -name admin-openrc)
. $sourcePathAdmin
openstack user create --domain $controllerKeystoneDomain --password $controllerGlancePass glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image service" image

# Creating image service API endpoints
if [[ "$1" != "following" ]]; then
  echo "2.3 - Creating image service API endpoints"
else
  echo "8.1.3 - Creating image service API endpoints"
fi
openstack endpoint create --region $controllerKeystoneRegion image public http://$controllerHostname:9292
openstack endpoint create --region $controllerKeystoneRegion image internal http://$controllerHostname:9292
openstack endpoint create --region $controllerKeystoneRegion image admin http://$controllerHostname:9292

# Configuring glance components
if [[ "$1" != "following" ]]; then
  echo "2.4 - Configuring components"
else
  echo "8.1.4 - Configuring components"
fi
apt-get install glance -y > /dev/null
buildGlanceAPIFile
buildGlanceRegistryFile
mv glance-api.conf /etc/glance/glance-api.conf
mv glance-registry.conf /etc/glance/glance-registry.conf
chown glance:glance /etc/glance/glance-api.conf
chown glance:glance /etc/glance/glance-registry.conf
chmod 644 /etc/glance/glance-api.conf
chmod 644 /etc/glance/glance-registry.conf
su -s /bin/sh -c "glance-manage db_sync" glance

# Restaring services and finishing installation
if [[ "$1" != "following" ]]; then
  echo "3 - Restaring services and finishing installation"
else
  echo "8.2 - Restaring services and finishing installation"
fi
service glance-registry restart
service glance-api restart
rm -f /var/lib/glance/glance.sqlite

. $sourcePathAdmin
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
openstack image create "cirros" --file cirros-0.3.4-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack image list

if [[ "$1" != "following" ]]; then
  echo "END"
fi
