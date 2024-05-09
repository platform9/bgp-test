sudo add-apt-repository cloud-archive:wallaby #(in doc we have queens, but ubuntu 20 doesn’t support queens, hence wallaby)
sudo apt-get update
sudo systemctl stop systemd-resolved #(*needed for dnsmasq)
apt-get install -y dnsmasq arping conntrack ifenslave vlan software-properties- common
modprobe bridge
modprobe br_netfilter
modprobe 8021q
modprobe bonding
echo bridge >/etc/modules-load.d/pf9.conf
echo 8021q >> /etc/modules-load.d/pf9.conf
echo bonding >> /etc/modules-load.d/pf9.conf
echo br_netfilter >> /etc/modules-load.d/pf9.conf
cat /etc/modules-load.d/pf9.conf
echo net.ipv4.conf.all.rp_filter=0 >> /etc/sysctl.conf
echo net.ipv4.conf.default.rp_filter=0 >> /etc/sysctl.conf
echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.conf
echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
echo net.ipv4.tcp_mtu_probing=2 >> /etc/sysctl.conf
sysctl -p
wget -q -O - https://platform9-neutron.s3-us-west-1.amazonaws.com/ ubuntu_latest/key.gpg | sudo apt-key add -
add-apt-repository 'deb http://platform9-neutron.s3-website-us- west-1.amazonaws.com/ubuntu_latest /'
apt-get -y install openvswitch-switch
systemctl enable openvswitch-switch.service
systemctl start openvswitch-switch.service
apt-get -y install radvd #(note that there might be some error of ipv6, but we can ignore that)
