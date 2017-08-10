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
            if [[ $line == *"KeystoneRegion="* ]]; then
              IFS='=' read -a myarray4 <<< "$line"
              controllerKeystoneRegion=${myarray4[1]}
            else
              if [[ $line == *"NeutronPass="* ]]; then
                IFS='=' read -a myarray5 <<< "$line"
                controllerNeutronPass=${myarray5[1]}
              else
				if [[ $line == *"ODControllerIPAddress="* ]]; then
	              IFS='=' read -a myarray6 <<< "$line"
	              ODControllerIP=${myarray6[1]}
			    else
                  if [[ $line == *"NeutronDBPass="* ]]; then
                    IFS='=' read -a myarray7 <<< "$line"
                    controllerNeutronDBPass=${myarray7[1]}
                  else
					if [[ $line == *"NeutronSharedSecret="* ]]; then
					  IFS='=' read -a myarray <<< "$line"
   			          controllerNeutronSharedSecret=${myarray[1]}
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

function getVariablesFromConfigFileCompute() {
  confFilePathCompute=$(find / -name configFileCompute.txt)
  while IFS='' read -r line || [[ -n "$line" ]]; do
	if [[ $line == *"OSIP="* ]]; then
	  IFS='=' read -a myarray <<< "$line"
	  computeOSIP=${myarray[1]}
	else
	  if [[ $line == *"OSIPTunnel="* ]]; then
		IFS='=' read -a myarray1 <<< "$line"
		computeOSIPTunnel=${myarray1[1]}
	  else
	    if [[ $line == *"ComputeHostname="* ]]; then
		  IFS='=' read -a myarray2 <<< "$line"
		  computeHostname=${myarray2[1]}
        fi
      fi
    fi
  done < "$confFilePathCompute"
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

[oslo_concurrency]
lock_path = \$state_path/lock" >> neutron.conf
}

function buildOvSAgentFile() {
  echo "[DEFAULT]
  
[ovs]
bridge_mappings = provider:br-provider
local_ip = $computeOSIPTunnel

[agent]
tunnel_types = vxlan
l2_population = True

[securitygroup]
firewall_driver = iptables_hybrid" >> openvswitch_agent.ini
}

function buildML2AgentFile() {
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
enable_security_group = True
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver" >> ml2_conf.ini
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

# Configuring neutron components
if [[ "$1" != "following" ]]; then
  echo "2 - Configuring components"
else
  echo "5.1 - Configuring components"
fi
getVariablesFromConfigFileController
getVariablesFromConfigFileCompute

apt-get install neutron-common neutron-plugin-ml2 neutron-plugin-openvswitch-agent -y > /dev/null
buildNeutronFile
buildOvSAgentFile
buildML2AgentFile
echo "
[neutron]
url = http://$controllerHostname:9696
auth_url = http://$controllerHostname:35357
auth_type = password
project_domain_name = $controllerKeystoneDomain
user_domain_name = $controllerKeystoneDomain
region_name = $controllerKeystoneRegion
project_name = service
username = neutron
password = $controllerNeutronPass" >> /etc/nova/nova.conf
mv neutron.conf /etc/neutron/neutron.conf
chown root:neutron /etc/neutron/neutron.conf
chmod 640 /etc/neutron/neutron.conf
mv openvswitch_agent.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini
chown root:neutron /etc/neutron/plugins/ml2/openvswitch_agent.ini
chmod 640 /etc/neutron/plugins/ml2/openvswitch_agent.ini
mv ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
chown root:neutron /etc/neutron/plugins/ml2/ml2_conf.ini
chmod 640 /etc/neutron/plugins/ml2/ml2_conf.ini

ovs-vsctl add-br br-provider
ovs-vsctl add-port br-provider enp0s9
ovs-vsctl add-br br-tun

service nova-compute restart
service neutron-openvswitch-agent restart

# Finalizing installation
if [[ "$1" != "following" ]]; then
  echo "3 - Finaling installation"
else
  echo "5.2 - Finaling installation"
fi

if [[ "$1" != "following" ]]; then
  echo "END"
fi
