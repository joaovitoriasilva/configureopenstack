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
              if [[ $line == *"NeutronPass="* ]]; then
                IFS='=' read -a myarray5 <<< "$line"
                controllerNeutronPass=${myarray5[1]}
              else
                if [[ $line == *"NeutronSharedSecret="* ]]; then
                 IFS='=' read -a myarray6 <<< "$line"
                 controllerNeutronSharedSecret=${myarray6[1]}
				 else
		           if [[ $line == *"ODControllerIPAddress="* ]]; then
			          IFS='=' read -a myarray7 <<< "$line"
			          ODControllerIP=${myarray7[1]}
                  else
                    if [[ $line == *"NeutronDBPass="* ]]; then
                      IFS='=' read -a myarray8 <<< "$line"
                      controllerNeutronDBPass=${myarray8[1]}
                    else
                      if [[ $line == *"NovaPass="* ]]; then
                        IFS='=' read -a myarray7 <<< "$line"
                        controllerNovaPass=${myarray7[1]}
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
  done < "$confFilePathController"
}

function getVariablesFromNetworkConfigFile() {
  confFilePathNetwork=$(find / -name configFileNetwork.txt)
  while IFS='' read -r line || [[ -n "$line" ]]; do
	if [[ $line == *"OSIPTunnel="* ]]; then
	  IFS='=' read -a myarray <<< "$line"
	  networkOSTunnelIP=${myarray[1]}
	else
	  if [[ $line == *"OSIP="* ]]; then
		IFS='=' read -a myarray <<< "$line"
	    networkOSIP=${myarray[1]}
	  fi
	fi
  done < "$confFilePathNetwork"
}

function buildNeutronFile() {
  echo "[DEFAULT]
auth_strategy = keystone
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True
state_path = /var/lib/neutron
#notify_nova_on_port_status_changes = True
#notify_nova_on_port_data_changes = True
transport_url = rabbit://$controllerRMQUser:$controllerRMQPass@$controllerHostname

[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

#[database]
#connection = mysql+pymysql://neutron:$controllerNeutronDBPass@$controllerHostname/neutron

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

#[nova]
#auth_url = http://$controllerHostname:35357
#auth_type = password
#project_domain_name = $controllerKeystoneDomain
#user_domain_name = $controllerKeystoneDomain
#region_name = $controllerKeystoneRegion
#project_name = service
#username = nova
#password = $controllerNovaPass

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
enable_ipset = true" >> ml2_conf.ini
}

function buildL3AgentFile() {
  echo "[DEFAULT]
interface_driver = openvswitch
external_network_bridge =
verbose = True" >> l3_agent.ini
}

function buildOvSAgentFile() {
  echo "[DEFAULT]

[agent]
tunnel_types = vxlan
l2_population = True

[ovs]
local_ip = $networkOSTunnelIP
bridge_mappings = provider:br-provider

[securitygroup]
firewall_driver = iptables_hybrid" >> openvswitch_agent.ini
}

function buildDHCPAgentFile() {
  echo "[DEFAULT]
interface_driver = openvswitch
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = True
force_metadata  = true" >> dhcp_agent.ini
}

function buildMetadataAgent() {
  echo "[DEFAULT]
nova_metadata_ip = $controllerHostname
metadata_proxy_shared_secret = $controllerNeutronSharedSecret" >> metadata_agent.ini
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
  echo "This script will install the Neutron OpenStack compute module."
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

#apt-get install neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent -y > /dev/null
#apt-get install neutron-server neutron-plugin-ml2 neutron-plugin-openvswitch-agent openvswitch-switch neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent -y > /dev/null
apt-get install neutron-plugin-ml2 neutron-plugin-openvswitch-agent neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent python-neutronclient -y > /dev/null
buildNeutronFile
buildML2File
buildDHCPAgentFile
buildMetadataAgent
buildL3AgentFile
buildOvSAgentFile
mv neutron.conf /etc/neutron/neutron.conf
chown root:neutron /etc/neutron/neutron.conf
chmod 640 /etc/neutron/neutron.conf
mv ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
chown root:neutron /etc/neutron/plugins/ml2/ml2_conf.ini
chmod 644 /etc/neutron/plugins/ml2/ml2_conf.ini
mv dhcp_agent.ini /etc/neutron/dhcp_agent.ini
chown root:neutron /etc/neutron/dhcp_agent.ini
chmod 640 /etc/neutron/dhcp_agent.ini
mv metadata_agent.ini /etc/neutron/metadata_agent.ini
chown root:neutron /etc/neutron/metadata_agent.ini
chmod 640 /etc/neutron/metadata_agent.ini
mv l3_agent.ini /etc/neutron/l3_agent.ini
chown root:neutron /etc/neutron/l3_agent.ini
chmod 640 /etc/neutron/l3_agent.ini
mv openvswitch_agent.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini
chown root:neutron /etc/neutron/plugins/ml2/openvswitch_agent.ini
chmod 640 /etc/neutron/plugins/ml2/openvswitch_agent.ini

ovs-vsctl add-br br-provider
ovs-vsctl add-port br-provider enp0s9
ovs-vsctl add-br br-tun


service neutron-l3-agent restart
service neutron-openvswitch-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart

# Finalizing installation
if [[ "$1" != "following" ]]; then
  echo "3 - Finaling installation"
else
  echo "5.2 - Finaling installation"
fi

if [[ "$1" != "following" ]]; then
  echo "END"
fi
