#!/bin/bash

ovs-vsctl add-br br-pf9
ovs-vsctl add-port br-pf9 bond0.600

#!/bin/bash

ip addr add 131.153.225.183/28 dev br-pf9
ovs-vsctl set bridge br-pf9 other_config:hwaddr=7c:c2:55:44:73:80
ip link set dev br-pf9 up
ip addr del 131.153.225.183/28 dev bond0.600
ip route del default via 131.153.225.177 dev bond0.600
ip route add default via 131.153.225.177 dev br-pf9
exit 0