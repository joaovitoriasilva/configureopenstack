#!/bin/bash

#########
# Functions declared here
function getVariablesFromConfigFile() {
  confFilePath=$(find / -name configFileController.txt)
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"OSIP="* ]]; then
      IFS='=' read -a myarray <<< "$line"
      controllerIP=${myarray[1]}
    else
      if [[ $line == *"ControllerHostname="* ]]; then
        IFS='=' read -a myarray <<< "$line"
        controllerHostname=${myarray[1]}
      fi
    fi
  done < "$confFilePath"
}

function buildMySQLFile() {
  echo "[mysqld]
bind-address = $controllerIP

default-storage-engine = innodb
innodb_file_per_table
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8" >> 99-openstack.cnf
}

function storeServiceModulesDataConfigFile() {
  if [[ "$1" != "optional" ]]; then
    echo "[passwords]
MDBPass=$userInputMDBPass
RMQUser=$userInputRMQUser
RMQPass=$userInputRMQPass" >> "$confFilePath"
    if [[ "$1" != "base" ]]; then
      echo "KeystonePass=$userInputKeystonePass
KeystoneDBPass=$userInputKeystoneDBPass
KeystoneRegion=$userInputKeystoneRegion
KeystoneDomain=$userInputKeystoneDomain
AdminPass=$userInputKeystoneAdminPass
DemoPass=$userInputKeystoneDemoPass
GlancePass=$userInputGlancePass
GlanceDBPass=$userInputGlanceDBPass
NovaPass=$userInputNovaPass
NovaDBPass=$userInputNovaDBPass
NeutronPass=$userInputNeutronPass
NeutronDBPass=$userInputNeutronDBPass
NeutronSharedSecret=$userInputNeutronSharedSecret
HorizonPass=$userInputHorizonPass" >> "$confFilePath"
    fi
  fi
  if [[ "$1" == "all" ]] || [[ "$1" == "optional" ]]; then
    echo "CinderPass=$userInputCinderPass
CinderDBPass=$userInputCinderDBPass
SwiftPass=$userInputSwiftPass
HeatPass=$userInputHeatPass
HeatDBPass=$userInputHeatDBPass
CeilometerPass=$userInputCeilometerPass
CeilometerDBPass=$userInputCeilometerDBPass" >> "$confFilePath"
  fi
}

function buildAdminFile() {
  echo "export OS_PROJECT_DOMAIN_ID=$userInputKeystoneDomain
export OS_USER_DOMAIN_ID=$userInputKeystoneDomain
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$userInputKeystoneAdminPass
export OS_AUTH_URL=http://$controllerHostname:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2" >> ../admin-openrc.sh
}

function buildDemoFile() {
  echo "export OS_PROJECT_DOMAIN_ID=$userInputKeystoneDomain
export OS_USER_DOMAIN_ID=$userInputKeystoneDomain
export OS_PROJECT_NAME=demo
export OS_TENANT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=$userInputKeystoneDemoPass
export OS_AUTH_URL=http://$controllerHostname:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2" >> ../demo-openrc.sh
}
########

# Sudo execution and argument verifycation
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run this script as root."
  exit
else
  if [[ "$1" != "required" ]] && [[ "$1" != "all" ]] && [[ "$1" != "optional" ]] && [[ "$1" != "base" ]] && [[ "$1" != "help" ]]; then
    if [[ "$1" == "" ]]; then
      echo "You need to specify one argument"
    else
      echo "Option -$1- not valid"
    fi
    echo "Rerun script with a valid option (base, optional, required, all or help)"
    exit
  else
    if [[ "$1" == "help" ]]; then
      echo "Run the script with the following options:"
      echo "  help - Get script options"
      echo "  base - Only OpenStack core"
      echo "  required - OpenStack core and Glance, Horizon, Keystone, Neutron, Nova modules"
      echo "  all - OpenStack core and all modules"
      echo "  optional - Only optional modules Cinder, Swift, Heat and Ceilometer"
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
echo "This script will install all the components needed for a correct controller OpenStack installation."
if [[ "$1" == "required" ]]; then
  echo "It'll be installed the following OpenStack modules: Glance, Horizon, Keystone, Neutron and Nova.\n"
else
  if [[ "$1" == "all" ]]; then
    echo "It'll be installed the following OpenStack modules: Ceilometer, Cinder, Glance, Heat,Horizon,"
    echo "Keystone, Neutron, Nova and Swift.\n"
  else
    if [[ "$1" == "optional" ]]; then
      echo "It'll be installed the following OpenStack modules: Cinder, Swift, Heat and Ceilometer.\n"
    fi
  fi
fi
echo "This is a controller script."
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
getVariablesFromConfigFile

# Getting user input data and storing it in the config file
echo "1.3 - Getting data and storing it in the config file"
if [[ "$1" != "optional" ]]; then
  adminToken=`openssl rand -hex 10`
  userInputMDBPass=`openssl rand -hex 10`
  userInputRMQUser="testesRabbit"
  userInputRMQPass=`openssl rand -hex 10`
  if [[ "$1" != "base" ]]; then
	userInputKeystonePass=`openssl rand -hex 10`
	userInputKeystoneDBPass=`openssl rand -hex 10`
    userInputKeystoneRegion="RegionOne"
    userInputKeystoneDomain="default"
    userInputKeystoneAdminPass="testesAdmin"
    userInputKeystoneDemoPass="testesDemo"
    #userInputKeystoneAdminPass=`openssl rand -hex 10`
    #userInputKeystoneDemoPass=`openssl rand -hex 10`
    userInputGlancePass=`openssl rand -hex 10`
    userInputGlanceDBPass=`openssl rand -hex 10`
    userInputNovaPass=`openssl rand -hex 10`
    userInputNovaDBPass=`openssl rand -hex 10`
    userInputNeutronPass=`openssl rand -hex 10`
    userInputNeutronDBPass=`openssl rand -hex 10`
    userInputNeutronSharedSecret=`openssl rand -hex 10`
    userInputHorizonPass=`openssl rand -hex 10`
  fi
fi
if [[ "$1" == "all" ]] || [[ "$1" == "optional" ]]; then
  userInputCinderPass=`openssl rand -hex 10`
  userInputCinderDBPass=`openssl rand -hex 10`
  userInputSwiftPass=`openssl rand -hex 10`
  userInputHeatPass=`openssl rand -hex 10`
  userInputHeatDBPass=`openssl rand -hex 10`
  userInputCeilometerPass=`openssl rand -hex 10`
  userInputCeilometerDBPass=`openssl rand -hex 10`
fi
storeServiceModulesDataConfigFile $1

buildAdminFile
buildDemoFile

if [[ "$1" != "optional" ]]; then
  # Installing Chrony packages
  echo "2 - Installing Chrony NTP server"
  sleep 2
  apt-get update > /dev/null && apt-get dist-upgrade -y > /dev/null
  apt-get install chrony -y > /dev/null
  sed -i 's/pool 2.debian.pool.ntp.org offline iburst/server 0.debian.pool.ntp.org iburst/' /etc/chrony/chrony.conf
  sed -i '/server 0.debian.pool.ntp.org iburst/a \server 1.debian.pool.ntp.org iburst' /etc/chrony/chrony.conf
  sed -i '/server 1.debian.pool.ntp.org iburst/a \server 2.debian.pool.ntp.org iburst' /etc/chrony/chrony.conf
  sed -i '/server 2.debian.pool.ntp.org iburst/a \server 3.debian.pool.ntp.org iburst' /etc/chrony/chrony.conf
  #cp chrony.conf /etc/chrony/chrony.conf
  echo "allow 192.168.10.0/24
allow 192.168.20.0/24
allow 192.168.30.0/24" >> /etc/chrony/chrony.conf

  # Restarting Chrony server
  echo "2.1 - Restarting Chrony server"
  service chrony restart

  # Installing OpenStack packages
  echo "3 - Installing OpenStack packages"
  sleep 2
  echo "3.1 - Checking pre-requisites and updating repositories to OpenStack newton version"
  apt-get install software-properties-common -y > /dev/null
  add-apt-repository cloud-archive:newton -y
  apt-get update > /dev/null && apt-get dist-upgrade -y > /dev/null
  echo "3.2 - OpenStack packages"
  apt-get install python-openstackclient -y > /dev/null

  # Installing SQL database packages
  echo "4 - Installing MySQL database packages"
  sleep 2
  #apt-get install debconf-utils -y > /dev/null
  #debconf-set-selections <<< "mysql-server mysql-server/root_password password $userInputMDBPass"
  #debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $userInputMDBPass"
  apt-get install mariadb-server python-pymysql expect -y > /dev/null

  echo "4.1 - Creating necessary file - /etc/mysql/conf.d/mysqld_openstack.cnf"
  buildMySQLFile
  mv 99-openstack.cnf /etc/mysql/mariadb.conf.d/99-openstack.cnf
  chown root:root /etc/mysql/mariadb.conf.d/99-openstack.cnf
  chmod 644 /etc/mysql/mariadb.conf.d/99-openstack.cnf

  echo "4.2 - Restarting MySQL server"
  service mysql restart

  echo "4.3 - Securing MySQL installation - script mysql_secure_installation"

#expect \"Set root password?\" 
#send \"y\r\"

#expect \"New password:\"
#send \"$userInputMDBPass\r\"

#expect \"Re-enter new password:\"
#send \"$userInputMDBPass\r\"
  SECURE_MYSQL=$(expect -c "
  
set timeout 10 
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\" 
send \"\r\"

expect \"Set root password?\" 
send \"n\r\"

expect \"Remove anonymous users?\" 
send \"y\r\"

expect \"Disallow root login remotely?\" 
send \"y\r\"

expect \"Remove test database and access to it?\" 
send \"y\r\"

expect \"Reload privilege tables now?\" 
send \"y\r\"

expect eof 
") 

  echo "$SECURE_MYSQL"

  # Installing RabbitMQ packages
  echo "5 - Installing RabbitMQ packages"
  sleep 2
  apt-get install rabbitmq-server -y > /dev/null
  rabbitmqctl add_user $userInputRMQUser $userInputRMQPass
  rabbitmqctl set_permissions $userInputRMQUser ".*" ".*" ".*"

  # Installing memcached packages
  echo "6 - Installing memcached packages"
  sleep 2
  apt-get install memcached python-memcache -y > /dev/null
  sed -i "s/-l 127.0.0.1/-l $controllerIP/" /etc/memcached.conf
  service memcached restart

  if [[ "$1" != "base" ]]; then
    #Installing OpenStack Keystone module
    echo "7 - Installing Keystone module"
    sleep 2
    ../Modules/./os-controller-identity.sh following

    #Installing OpenStack Glance module
    echo "8 - Installing Glance module"
    sleep 2
    ../Modules/./os-controller-image.sh following

    #Installing OpenStack Nova module
    echo "9 - Installing Nova module"
    sleep 2
    ../Modules/./os-controller-compute.sh following

    #Installing OpenStack Neutron module
    echo "10 - Installing Neutron module"
    sleep 2
    ../Modules/./os-controller-network.sh following

    #Installing OpenStack Horizon module
    echo "11 - Installing Horizon module"
    sleep 2
    ../Modules/./os-controller-dashboard.sh following
  fi
fi
if [[ "$1" != "required" ]] && [[ "$1" != "base" ]]; then
  #Installing OpenStack Cinder module
  echo "12 - Installing Cinder module"
  sleep 2
  ../Modules/./os-controller-blockStorage.sh following

  #Installing OpenStack Swift module
  #echo "14 - Installing Swift module"
  #sleep 2
  #read -p "Pause: "
  #../Modules/./os-controller-objectStorage.sh following
  #../Modules/Swift/./os-pos-controller-objectStorage.sh following

  #Installing OpenStack Heat module
  #echo "15 - Installing Heat module"
  #sleep 2
  #read -p "Pause: "
  #../Modules/./os-controller-orchestration.sh following

  #Installing OpenStack Ceilometer module
  #echo "16 - Installing Ceilometer module"
  #sleep 2
  #read -p "Pause: "
  #../Modules/./os-controller-telemetry.sh following
fi

echo "END"
