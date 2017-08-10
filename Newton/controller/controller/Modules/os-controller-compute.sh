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
                  if [[ $line == *"NovaPass="* ]]; then
                    IFS='=' read -a myarray8 <<< "$line"
                    controllerNovaPass=${myarray8[1]}
                  else
                    if [[ $line == *"NovaDBPass="* ]]; then
                      IFS='=' read -a myarray9 <<< "$line"
                      controllerNovaDBPass=${myarray9[1]}
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
  echo "NovaPass=$userInputNovaPass
NovaDBPass=$userInputNovaDBPass" >> $confFilePath
}

function buildNovaFile() {
  echo "[DEFAULT]
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
rootwrap_config=/etc/nova/rootwrap.conf
verbose=True
transport_url = rabbit://$controllerRMQUser:$controllerRMQPass@$controllerHostname
auth_strategy = keystone
my_ip = $controllerOSIP
use_neutron = True
firewall_driver = nova.virt.firewall.NoopFirewallDriver

[api_database]
connection = mysql+pymysql://nova:$controllerNovaDBPass@$controllerHostname/nova_api

[database]
connection = mysql+pymysql://nova:$controllerNovaDBPass@$controllerHostname/nova

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
vncserver_listen = \$my_ip
vncserver_proxyclient_address = \$my_ip

[glance]
api_servers = http://$controllerHostname:9292

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

[wsgi]
api_paste_config = /etc/nova/api-paste.ini" >> nova.conf
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
  echo "This script will install the Nova OpenStack controller module."
  echo "This is a controller script."
  echo "Change the provided files to your needs."
  read -r -p "Do you wish to continue? [y/N]" response

  # Checking linux distribuion version. Must be Ubuntu 14.04
  if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
  else
    exit
  fi

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

# Installing nova prerequisites
if [[ "$1" != "following" ]]; then
  echo "2 - Installing prerequisites"
else
  echo "9.1 - Installing prerequisites"
fi

# Getting user input data and storing it in the config file
confFilePath=$(find / -name configFileController.txt)
if [[ "$1" != "following" ]]; then
  echo "2.1 - Getting user input data and storing it in the config file"
  echo "SERVICE PASSWORDS"
  echo "It is recommended that you use distinct passwords for each module and service"
  read -r -p "Nova (Compute) server password: " userInputNovaPass
  read -r -p "Nova (Compute) DB password: " userInputNovaDBPass
  storeServiceModulesDataConfigFile
fi
getVariablesFromConfigFile

# Database commands
if [[ "$1" != "following" ]]; then
  echo "2.2 - Creating MySQL database for Nova"
else
  echo "9.1.1 - Creating MySQL database for Nova"
fi
user=root
database=nova
database_api=nova_api
#mysql --user="$user" --password="$controllerMDBPass" --execute="CREATE DATABASE $database;"
#mysql --user="$user" --password="$controllerMDBPass" --execute="CREATE DATABASE $database_api;"
#mysql --user="$user" --password="$controllerMDBPass" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'localhost' IDENTIFIED BY '$controllerNovaDBPass';"
#mysql --user="$user" --password="$controllerMDBPass" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'%' IDENTIFIED BY '$controllerNovaDBPass';"
#mysql --user="$user" --password="$controllerMDBPass" --database="$database_api" --execute="GRANT ALL PRIVILEGES ON $database_api.* TO '$database'@'localhost' IDENTIFIED BY '$controllerNovaDBPass';"
#mysql --user="$user" --password="$controllerMDBPass" --database="$database_api" --execute="GRANT ALL PRIVILEGES ON $database_api.* TO '$database'@'%' IDENTIFIED BY '$controllerNovaDBPass';"
mysql --user="$user" --execute="CREATE DATABASE $database;"
mysql --user="$user" --execute="CREATE DATABASE $database_api;"
mysql --user="$user" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'localhost' IDENTIFIED BY '$controllerNovaDBPass';"
mysql --user="$user" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'%' IDENTIFIED BY '$controllerNovaDBPass';"
mysql --user="$user" --database="$database_api" --execute="GRANT ALL PRIVILEGES ON $database_api.* TO '$database'@'localhost' IDENTIFIED BY '$controllerNovaDBPass';"
mysql --user="$user" --database="$database_api" --execute="GRANT ALL PRIVILEGES ON $database_api.* TO '$database'@'%' IDENTIFIED BY '$controllerNovaDBPass';"

# Create the service entity and API endpoints
if [[ "$1" != "following" ]]; then
  echo "2.3 - Create the service entity and API endpoints"
else
  echo "9.1.2 - Create the service entity and API endpoints"
fi
sourcePathAdmin=$(find / -name admin-openrc)
. $sourcePathAdmin
openstack user create --domain $controllerKeystoneDomain --password $controllerNovaPass nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region $controllerKeystoneRegion compute public http://$controllerHostname:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region $controllerKeystoneRegion compute internal http://$controllerHostname:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region $controllerKeystoneRegion compute admin http://$controllerHostname:8774/v2.1/%\(tenant_id\)s

# Configuring nova components
if [[ "$1" != "following" ]]; then
  echo "3 - Configuring components"
else
  echo "9.2 -Configuring components"
fi
apt-get install nova-api nova-conductor nova-consoleauth nova-novncproxy nova-scheduler -y > /dev/null
buildNovaFile
mv nova.conf /etc/nova/nova.conf
chown nova:nova /etc/nova/nova.conf
chmod 640 /etc/nova/nova.conf

# Finalizing installation
if [[ "$1" != "following" ]]; then
  echo "4 - Finalizing installation"
else
  echo "9.3 - Finalizing installation"
fi
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage db sync" nova

service nova-api restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart
rm -f /var/lib/nova/nova.sqlite

if [[ "$1" != "following" ]]; then
  echo "END"
fi
