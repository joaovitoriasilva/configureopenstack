#!/bin/bash

#########
# Functions declared here
function getVariablesFromConfigFile() {
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"ControllerHostname="* ]]; then
      IFS='=' read -a myarray1 <<< "$line"
      controllerHostname=${myarray1[1]}
    else
      if [[ $line == *"MDBPass="* ]]; then
        IFS='=' read -a myarray2 <<< "$line"
        controllerMDBPass=${myarray2[1]}
      else
        if [[ $line == *"RMQUser="* ]]; then
          IFS='=' read -a myarray3 <<< "$line"
          controllerRMQUser=${myarray3[1]}
        else
          if [[ $line == *"RMQPass="* ]]; then
            IFS='=' read -a myarray4 <<< "$line"
            controllerRMQPass=${myarray4[1]}
          else
            if [[ $line == *"KeystoneRegion="* ]]; then
              IFS='=' read -a myarray5 <<< "$line"
              controllerKeystoneRegion=${myarray5[1]}
            else
              if [[ $line == *"KeystoneDomain="* ]]; then
                IFS='=' read -a myarray6 <<< "$line"
                controllerKeystoneDomain=${myarray6[1]}
              else
                if [[ $line == *"NovaPass="* ]]; then
                  IFS='=' read -a myarray7 <<< "$line"
                  controllerNovaPass=${myarray7[1]}
                else
                  if [[ $line == *"NeutronPass="* ]]; then
                    IFS='=' read -a myarray8 <<< "$line"
                    controllerNeutronPass=${myarray8[1]}
                  else
                    if [[ $line == *"NeutronDBPass="* ]]; then
                      IFS='=' read -a myarray9 <<< "$line"
                      controllerNeutronDBPass=${myarray9[1]}
                    else
					  if [[ $line == *"NeutronSharedSecret="* ]]; then
					    IFS='=' read -a myarray <<< "$line"
   			            controllerNeutronSharedSecret=${myarray[1]}
			          else
			            if [[ $line == *"ODControllerIPAddress="* ]]; then
				          IFS='=' read -a myarray10 <<< "$line"
			          	  ODControllerIP=${myarray10[1]}
			            fi
					  fi
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
  echo "NeutronPass=$userInputNeutronPass
NeutronDBPass=$userInputNeutronDBPass
NeutronSharedSecret=$userInputNeutronSharedSecret" >> $confFilePath
}

function buildNeutronFile() {
  echo "[DEFAULT]
auth_strategy = keystone
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True
dhcp_agent_notification = True
state_path = /var/lib/neutron
notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True
transport_url = rabbit://$controllerRMQUser:$controllerRMQPass@$controllerHostname

[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

[database]
connection = mysql+pymysql://neutron:$controllerNeutronDBPass@$controllerHostname/neutron

[keystone_authtoken]
auth_uri = http://$controllerHostname:5000
auth_url = http://$controllerHostname:35357
memcached_servers = $controllerHostname:11211
auth_type = password
project_domain_name = $controllerKeystoneDomain
user_domain_name = $controllerKeystoneDomain
project_name = service
username = neutron
password = $controllerNeutronPass

[nova]
auth_url = http://$controllerHostname:35357
auth_type = password
project_domain_name = $controllerKeystoneDomain
user_domain_name = $controllerKeystoneDomain
region_name = $controllerKeystoneRegion
project_name = service
username = nova
password = $controllerNovaPass

[oslo_concurrency]
lock_path = \$state_path/lock" >> neutron.conf
}

function buildML2File() {
  echo "[DEFAULT]

[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
#mechanism_drivers = linuxbridge,l2population
mechanism_drivers = openvswitch,linuxbridge,l2population
extension_drivers = port_security

[ml2_type_flat]
flat_networks = provider

[ml2_type_vlan]
network_vlan_ranges = provider

[ml2_type_vxlan]
vni_ranges = 1:1000

[securitygroup]
enable_ipset = true
#enable_security_group = True
#firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver" >> ml2_conf.ini
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
  echo "This script will install the Neutron OpenStack controller module."
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

# Installing prerequisites
if [[ "$1" != "following" ]]; then
  echo "2 - Installing prerequisites"
else
  echo "10.1 - Installing prerequisites"
fi

# Getting user input data and storing it in the config file
confFilePath=$(find / -name configFileController.txt)
if [[ "$1" != "following" ]]; then
  echo "2.1 - Getting user input data and storing it in the config file"
  echo "SERVICE PASSWORDS"
  echo "It is recommended that you use distinct passwords for each module and service"
  read -r -p "Neutron (Network) server password: " userInputNeutronPass
  read -r -p "Neutron (Network) DB password: " userInputNeutronDBPass
  read -r -p "Neutron (Network) shared secret: " userInputNeutronSharedSecret
  storeServiceModulesDataConfigFile
fi
getVariablesFromConfigFile

# Database commands
if [[ "$1" != "following" ]]; then
  echo "2.2 - Creating MySQL database for Neutron"
else
  echo "10.1.1 - Creating MySQL database for Neutron"
fi
user=root
database=neutron
#mysql --user="$user" --password="$controllerMDBPass" --execute="CREATE DATABASE $database;"
#mysql --user="$user" --password="$controllerMDBPass" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'localhost' IDENTIFIED BY '$controllerNeutronDBPass';"
#mysql --user="$user" --password="$controllerMDBPass" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'%' IDENTIFIED BY '$controllerNeutronDBPass';"
mysql --user="$user" --execute="CREATE DATABASE $database;"
mysql --user="$user" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'localhost' IDENTIFIED BY '$controllerNeutronDBPass';"
mysql --user="$user" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'%' IDENTIFIED BY '$controllerNeutronDBPass';"

# Create the service entity and API endpoints
if [[ "$1" != "following" ]]; then
  echo "2.3 - Create the service entity and API endpoints"
else
  echo "10.1.2 - Create the service entity and API endpoints"
fi
sourcePathAdmin=$(find / -name admin-openrc.sh)
. $sourcePathAdmin
openstack user create --domain $controllerKeystoneDomain --password $controllerNeutronPass neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
openstack endpoint create --region $controllerKeystoneRegion network public http://$controllerHostname:9696
openstack endpoint create --region $controllerKeystoneRegion network internal http://$controllerHostname:9696
openstack endpoint create --region $controllerKeystoneRegion network admin http://$controllerHostname:9696

# Networking Option 2: Self-service networks
# Configuring neutron components
if [[ "$1" != "following" ]]; then
  echo "3 - Configuring components"
else
  echo "10.2 - Configuring components"
fi
apt-get install neutron-server neutron-plugin-ml2 python-neutronclient -y > /dev/null

# Adapting files
if [[ "$1" != "following" ]]; then
  echo "3.1 - Adapting files"
else
  echo "10.2.1 - Adapting files"
fi
echo "[neutron]
url = http://$controllerHostname:9696
auth_url = http://$controllerHostname:35357
auth_type = password
project_domain_name = $controllerKeystoneDomain
user_domain_name = $controllerKeystoneDomain
region_name = $controllerKeystoneRegion
project_name = service
username = neutron
password = $controllerNeutronPass

service_metadata_proxy = True
metadata_proxy_shared_secret = $controllerNeutronSharedSecret"  >> /etc/nova/nova.conf

# Copying files
if [[ "$1" != "following" ]]; then
  echo "3.2 - Copying files"
else
  echo "10.2.2 - Copying files"
fi
buildNeutronFile
buildML2File
mv neutron.conf /etc/neutron/neutron.conf
chown root:neutron /etc/neutron/neutron.conf
chmod 640 /etc/neutron/neutron.conf
mv ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
chown root:neutron /etc/neutron/plugins/ml2/ml2_conf.ini
chmod 644 /etc/neutron/plugins/ml2/ml2_conf.ini

# Finalizing installation
if [[ "$1" != "following" ]]; then
  echo "4 - Finalizing installation"
else
  echo "10.3 - Finalizing installation"
fi
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
service nova-api restart
service neutron-server restart
rm -f /var/lib/neutron/neutron.sqlite

#route
#sleep 5
#cat /etc/network/interfaces
#sleep 5

if [[ "$1" != "following" ]]; then
  echo "END"
fi
