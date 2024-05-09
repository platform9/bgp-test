#Run this in console access

ovs-vsctl add-br br-pf9
ovs-vsctl add-port br-pf9 bond0.600
ip addr add {131.153.241.61/29} dev br-pf9
ovs-vsctl set bridge br-pf9 other_config:hwaddr={7c:c2:55:43:07:f0}
ip link set dev br-pf9 up
ip addr del 131.153.241.61/29 dev bond0.600
ip addr del 131.153.225.166/28 dev bond0.600
ip addr del 131.153.225.167/28 dev bond0.600
ip addr del 131.153.225.168/28 dev bond0.600
ip addr del 131.153.225.169/28 dev bond0.600
ip route del default via {131.153.225.145} dev bond0.600 
ip route add default via {131.153.225.145} dev br-pf9
#( 7c:c2:55:43:07:f0 is the Mac address, 131.153.241.61 is machine’s primary IP, 131.153.225.145 is gateway IP). Number 6 to number 10 IPs are the ones from external IP range (external subnet)
