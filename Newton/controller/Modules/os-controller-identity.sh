#!/bin/bash

#########
# Functions declared here
function getVariablesFromConfigFile() {
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line == *"adminToken="* ]]; then
      IFS='=' read -a myarray <<< "$line"
      adminToken=${myarray[1]}
    else
      if [[ $line == *"ControllerHostname="* ]]; then
        IFS='=' read -a myarray1 <<< "$line"
        controllerHostname=${myarray1[1]}
      else
        if [[ $line == *"MDBPass="* ]]; then
          IFS='=' read -a myarray2 <<< "$line"
          controllerMDBPass=${myarray2[1]}
        else
          if [[ $line == *"KeystonePass="* ]]; then
            IFS='=' read -a myarray3 <<< "$line"
            controllerKeystonePass=${myarray3[1]}
          else
            if [[ $line == *"KeystoneDBPass="* ]]; then
              IFS='=' read -a myarray4 <<< "$line"
              controllerKeystoneDBPass=${myarray4[1]}
            else
              if [[ $line == *"KeystoneRegion="* ]]; then
                IFS='=' read -a myarray5 <<< "$line"
                controllerKeystoneRegion=${myarray5[1]}
              else
                if [[ $line == *"KeystoneDomain="* ]]; then
                  IFS='=' read -a myarray6 <<< "$line"
                  controllerKeystoneDomain=${myarray6[1]}
                else
                  if [[ $line == *"AdminPass="* ]]; then
                    IFS='=' read -a myarray7 <<< "$line"
                    controllerKeystoneAdminPass=${myarray7[1]}
                  else
                    if [[ $line == *"DemoPass="* ]]; then
                      IFS='=' read -a myarray8 <<< "$line"
                      controllerKeystoneDemoPass=${myarray8[1]}
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
  echo "KeystonePass=$userInputKeystonePass
KeystoneDBPass=$userInputKeystoneDBPass
KeystoneRegion=$userInputKeystoneRegion
KeystoneDomain=$userInputKeystoneDomain
AdminPass=$userInputKeystoneAdminPass
DemoPass=$userInputKeystoneDemoPass" >> $confFilePath
}

function buildAdminSourceFile() {
  echo "export OS_PROJECT_DOMAIN_NAME=$controllerKeystoneDomain
export OS_USER_DOMAIN_NAME=$controllerKeystoneDomain
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$controllerKeystoneAdminPass
export OS_AUTH_URL=http://$controllerHostname:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2" >> admin-openrc
}

function buildDemoSourceFile() {
  echo "export OS_PROJECT_DOMAIN_NAME=$controllerKeystoneDomain
export OS_USER_DOMAIN_NAME=$controllerKeystoneDomain
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$controllerKeystoneDemoPass
export OS_AUTH_URL=http://$controllerHostname:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2" >> demo-openrc
}

function buildKeystoneFile() {
  echo "[DEFAULT]
admin_token = $adminToken
log_dir = /var/log/keystone

[database]
connection = mysql+pymysql://keystone:$controllerKeystoneDBPass@$controllerHostname/keystone

[token]
provider = fernet

[extra_headers]
Distribution = Ubuntu" >> keystone.conf
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
  echo "This script was tested in Ubuntu 16.04. Other versions weren't tested."
  echo "You linux distribution will be tested for compatibility.\n"
  echo "This script will install the Keystone OpenStack controller module."
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
  if [[ "$UV" != *"16.04"* ]]; then
    echo "This Ubuntu version isn't 14.04."
    read -r -p "Do you wish to continue? [y/N]" responseVersion
    if [[ $responseVersion =~ ^([yY][eE][sS]|[yY])$ ]]; then
      echo ""
    else
      exit
    fi
  fi
fi

# Installing keystone prerequisites
if [[ "$1" != "following" ]]; then
  echo "2 - Installing prerequisites"
else
  echo "7.1 - Installing prerequisites"
fi
sleep 2

# Getting user input data and storing it in the config file
confFilePath=$(find / -name configFileController.txt)
if [[ "$1" != "following" ]]; then
  echo "2.1 - Getting user input data and storing it in the config file"
  echo "SERVICE PASSWORDS"
  echo "It is recommended that you use distinct passwords for each module and service"
  read -r -p "Keystone (Identity) server password: " userInputKeystonePass
  read -r -p "Keystone (Identity) DB password: " userInputKeystoneDBPass
  read -r -p "Keystone (Identity) region name (leave empty for default (RegionOne)): " userInputKeystoneRegion
  if [[ "$userInputKeystoneRegion" == "" ]]; then
    $userInputKeystoneRegion = RegionOne
  fi
  read -r -p "Keystone (Identity) domain (leave empty for default (default)): " userInputKeystoneDomain
  if [[ "$userInputKeystoneDomain" == "" ]]; then
    $userInputKeystoneDomain = default
  fi
  read -r -p "Keystone (Identity) admin user password: " userInputKeystoneAdminPass
  read -r -p "Keystone (Identity) demo user password: " userInputKeystoneDemoPass
  storeServiceModulesDataConfigFile
fi
getVariablesFromConfigFile

# Database commands
if [[ "$1" != "following" ]]; then
  echo "2.2 - Creating MySQL database for Keystone"
else
  echo "7.1.1 - Creating MySQL database for Keystone"
fi

user=root
database=keystone
#mysql --user="$user" --password="$controllerMDBPass" --execute="CREATE DATABASE $database;"
#mysql --user="$user" --password="$controllerMDBPass" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'localhost' IDENTIFIED BY '$controllerKeystoneDBPass';"
#mysql --user="$user" --password="$controllerMDBPass" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'%' IDENTIFIED BY '$controllerKeystoneDBPass';"
mysql --user="$user" --execute="CREATE DATABASE $database;"
mysql --user="$user" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'localhost' IDENTIFIED BY '$controllerKeystoneDBPass';"
mysql --user="$user" --database="$database" --execute="GRANT ALL PRIVILEGES ON $database.* TO '$database'@'%' IDENTIFIED BY '$controllerKeystoneDBPass';"


# Configuring keystone components
if [[ "$1" != "following" ]]; then
  echo "3 - Configuring components"
else
  echo "7.2 - Configuring components"
fi
sleep 2
#buildKeystoneOverrideFile
#mv keystone.override /etc/init/keystone.override

# keystone.conf configuration
apt-get install keystone -y > /dev/null
buildKeystoneFile
mv keystone.conf /etc/keystone/keystone.conf
chown root:root /etc/keystone/keystone.conf
chmod 644 /etc/keystone/keystone.conf
su -s /bin/sh -c "keystone-manage db_sync" keystone

# Initialize Fernet key repositories
if [[ "$1" != "following" ]]; then
  echo "3.1 - Initialize Fernet key repositories"
else
  echo "7.2.1 - Initialize Fernet key repositories"
fi
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

# Bootstrap the Identity service
if [[ "$1" != "following" ]]; then
  echo "3.2 - Bootstrap the Identity service"
else
  echo "7.2.2 - Bootstrap the Identity service"
fi
sleep 2
keystone-manage bootstrap --bootstrap-password $controllerKeystoneAdminPass --bootstrap-admin-url http://$controllerHostname:35357/v3/ --bootstrap-internal-url http://$controllerHostname:35357/v3/ --bootstrap-public-url http://$controllerHostname:5000/v3/ --bootstrap-region-id RegionOne

# Configure the Apache HTTP server
if [[ "$1" != "following" ]]; then
  echo "3.3 - Configure the Apache HTTP server"
else
  echo "7.2.3 - Configure the Apache HTTP server"
fi
sleep 2
echo "ServerName $controllerHostname" >> /etc/apache2/apache2.conf
#ln -s /etc/apache2/sites-available/wsgi-keystone.conf /etc/apache2/sites-enabled

# Finalize the installation
if [[ "$1" != "following" ]]; then
  echo "3.4 - Finalize the installation"
else
  echo "7.2.4 - Finalize the installation"
fi
sleep 2
service apache2 restart
rm -f /var/lib/keystone/keystone.db

export OS_USERNAME=admin
export OS_PASSWORD=$controllerKeystoneAdminPass
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=$controllerKeystoneDomain
export OS_PROJECT_DOMAIN_NAME=$controllerKeystoneDomain
export OS_AUTH_URL=http://$controllerHostname:35357/v3
export OS_IDENTITY_API_VERSION=3

# Create a domain, projects, users, and roles
if [[ "$1" != "following" ]]; then
  echo "3.5 - Create a domain, projects, users, and roles"
else
  echo "7.3 - Create a domain, projects, users, and roles"
fi
sleep 2
openstack project create --domain $controllerKeystoneDomain --description "Service Project" service
openstack project create --domain $controllerKeystoneDomain --description "Demo Project" demo
openstack user create --domain $controllerKeystoneDomain --password $controllerKeystoneDemoPass demo
openstack role create user
openstack role add --project demo --user demo user

unset OS_USERNAME
unset OS_PASSWORD
unset OS_PROJECT_NAME
unset OS_USER_DOMAIN_NAME
unset OS_PROJECT_DOMAIN_NAME
unset OS_AUTH_URL
unset OS_IDENTITY_API_VERSION

buildAdminSourceFile
buildDemoSourceFile

if [[ "$1" != "following" ]]; then
  echo "END"
fi
