# configureopenstack
OpenStack configuration
This readme may not be completed or updated.

# Resume
With this script it's possible to create a OpenStack Newton environment fully automated.
This implementation require at least one controller node, one network node and one compute node.
OpenvSwitch is used.
Integration with OpenDaylight openflow controller.

# Current limitations
- Unable to detect interface types, i.e. (enp0sX or ethX). 
  - Pre-installation scripts need to be changed manually;
  - OpenvSwitch interfaces need to be changed manually in network and compute files (os-network-network.sh and os-compute-network.sh).
- Configuration files from controller and network nodes not acessible from other servers. Configuration files need to be copied manually.

# To do
- Block and object storage nodes;
- Other relevant nodes;
- More OpenStack Modules like orchestration or telemetry;
- High availability scenarios.

Sources: 
- https://docs.openstack.org/newton/install-guide-ubuntu/index.html
- https://docs.openstack.org/newton/networking-guide/deploy-ovs-provider.html
- https://docs.openstack.org/newton/networking-guide/deploy-ovs-selfservice.html
- http://docs.opendaylight.org/en/stable-boron/submodules/netvirt/docs/openstack-guide/openstack-with-netvirt.html#installing-opendaylight-on-an-existing-openstack
