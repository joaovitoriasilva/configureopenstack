#!/bin/bash

#########
# Functions declared here
function getVariablesFromConfigFile() {
  confFilePath=$(find / -name configFileController.txt)
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"ODControllerIPAddress="* ]]; then
      IFS='=' read -a myarray <<< "$line"
      ODControllerIPAddress=${myarray[1]}
    else
      if [[ $line == *"NeutronDBPass="* ]]; then
        IFS='=' read -a myarray1 <<< "$line"
        controllerNeutronDBPass=${myarray1[1]}
      fi
    fi
  done < $confFilePath
}
########

# Sudo execution and argument verifycation
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root."
  exit
fi

# Warnings for the user
echo "This script was tested in Ubuntu 16.04. Other versions weren't tested."
echo "You linux distribution will be tested for compatibility.\n"
echo "This script will install the ODL controller OpenStack related attributes."
echo "This is a controller script."
echo "This script WILL need user input.\n"
echo "Do not change the order of the provided directories or files.\n"
read -r -p "Do you wish to continue? [y/N]" userInputInitialPrompt

# Executing verifications
echo "1 - Executing verifications"

# Checking linux distribuion version. Must be Ubuntu 16.04
echo "1.1 - Checking your linux distribution"
sleep 2
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
sleep 2
getVariablesFromConfigFile

#Installing OpenStack Neutron module
echo "2 - Installing ODL Newton library"
sleep 2
apt-get update && apt-get install git -y > /dev/null
git clone https://github.com/openstack/networking-odl -b stable/newton
cd networking-odl
python setup.py install
cd ..

echo "3 - Applying ODL settings to Neutron Server"
sleep 2
sed -i 's/service_plugins = router/service_plugins = odl-router/' /etc/neutron/neutron.conf
sed -i 's/mechanism_drivers = openvswitch,l2population/mechanism_drivers = opendaylight/' /etc/neutron/plugins/ml2/ml2_conf.ini
echo "[ml2_odl]
url = http://$ODControllerIPAddress:8080/controller/nb/v2/neutron
password = admin
username = admin" >> /etc/neutron/plugins/ml2/ml2_conf.ini

# Resetting Neutron databases
echo "5 - Resetting Neutron databases"
user=root
database=neutron
mysql --user="$user" --execute="DROP DATABASE IF EXISTS $database;"
mysql --user="$user" --execute="CREATE DATABASE $database;"
mysql --user="$user" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'localhost' IDENTIFIED BY '$controllerNeutronDBPass';"
mysql --user="$user" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'%' IDENTIFIED BY '$controllerNeutronDBPass';"
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

# Restarting services
echo "5 - Restarting services"
sleep 2
service neutron-server restart

echo "END"