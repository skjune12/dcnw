if [ $(id -u) -ne 0 ] ; then
  echo "Error: Please run with sudo";
  exit 1;
fi

set -e

run () {
  echo "$@"
  "$@" || exit 1
}

create_netns() {
  run ip netns add as65100-rtr
  run ip netns exec as65100-rtr ip link set lo up
  run ip netns exec as65100-rtr /sbin/sysctl -w net.ipv4.ip_forward=1

  run ip netns add as65100-cli
  run ip netns exec as65100-cli ip link set lo up
  run ip netns exec as65100-cli /sbin/sysctl -w net.ipv4.ip_forward=1

  run ip netns add as65200-rtr
  run ip netns exec as65200-rtr ip link set lo up
  run ip netns exec as65200-rtr /sbin/sysctl -w net.ipv4.ip_forward=1

  run ip netns add as65200-cli
  run ip netns exec as65200-cli ip link set lo up
  run ip netns exec as65200-cli /sbin/sysctl -w net.ipv4.ip_forward=1

  run ip netns add as65300-rtr
  run ip netns exec as65300-rtr ip link set lo up
  run ip netns exec as65300-rtr /sbin/sysctl -w net.ipv4.ip_forward=1

  run ip netns add as65300-cli
  run ip netns exec as65300-cli ip link set lo up
  run ip netns exec as65300-cli /sbin/sysctl -w net.ipv4.ip_forward=1

  run ip link add as65100-65000 type veth peer name as65000-65100
  # run ip link add as65200-65000-1 type veth peer name as65000-65200-1
  # run ip link add as65200-65000-2 type veth peer name as65000-65200-2
  # run ip link add as65300-65000 type veth peer name as65000-65300

  run ip link add as65100-rtr type veth peer name as65100-cli
  # run ip link add as65200-rtr type veth peer name as65200-cli
  # run ip link add as65300-rtr type veth peer name as65300-cli

  # configure AS65100
  run ip link set as65100-65000 netns as65100-rtr
  run ip netns exec as65100-rtr ip link set as65100-65000 up
  run ip netns exec as65100-rtr ip addr add 10.10.1.1/30 dev as65100-65000

  run ip link set as65000-65100 netns eg1
  run ip netns exec eg1 ip link set as65000-65100 up
  run ip netns exec eg1 ip addr add 10.10.1.2/30 dev as65000-65100

  run ip link set as65100-rtr netns as65100-rtr
  run ip netns exec as65100-rtr ip link set as65100-rtr up
  run ip netns exec as65100-rtr ip addr add 10.10.10.1/24 dev as65100-rtr

  run ip link set as65100-cli netns as65100-cli
  run ip netns exec as65100-cli ip link set as65100-cli up
  run ip netns exec as65100-cli ip addr add 10.10.10.10/24 dev as65100-cli
  run ip netns exec as65100-cli ip route add default via 10.10.10.1

  # run quagga and gobgp on netns as65100-rtr
  run ip netns exec as65100-rtr /usr/sbin/zebra -d -f /vagrant_data/conf/zebra/as65100.conf -i /tmp/as65100_zebra.pid -A 127.0.0.1 -z /tmp/as65100_zebra.vty
  run ip netns exec as65100-rtr gobgpd -f /vagrant_data/conf/gobgp/as65100.toml > /vagrant_data/log/as65100.log &

  # run ip link set as65200-65000-1 netns as65200-rtr
  # run ip link set as65200-65000-2 netns as65200-rtr
  # run ip link set as65200-rtr netns as65200-rtr
  # run ip link set as65200-cli netns as65200-cli
  # run ip link set as65000-65200-1 netns eg1
  # run ip link set as65000-65200-2 netns eg2
  #
  # run ip link set as65300-65000 netns as65300-rtr
  # run ip link set as65300-rtr netns as65300-rtr
  # run ip link set as65300-cli netns as65300-cli
  # run ip link set as65000-65300 netns eg2
}

destroy_netns() {
  run ip netns del as65100-rtr
  run ip netns del as65100-cli
  run ip netns del as65200-rtr
  run ip netns del as65200-cli
  run ip netns del as65300-rtr
  run ip netns del as65300-cli
}

stop () {
  destroy_netns
}

# exec funtion
create_netns

trap stop 0 1 2 3 13 14 15

status=0; $SHELL || status=$?
exit $status
