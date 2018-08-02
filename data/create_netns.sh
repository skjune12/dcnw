#!/bin/bash

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
  # create veth pair between cr and ag
  ag_max=2
  sw_max=4
  sv_max=6

  # create netns
  for ((ag_num=1; ag_num <= $ag_max; ag_num++))
  do
    netns_name="ag${ag_num}"
    ag_devid=$ag_num

    run ip netns add ${netns_name}
    run ip netns exec ${netns_name} /sbin/sysctl -w net.ipv4.ip_forward=1
    run ip netns exec ${netns_name} ip link set lo up

    # zebra configuration
    run ip netns exec ${netns_name} /usr/sbin/zebra -d -f /vagrant_data/conf/zebra/${netns_name}.conf -i /tmp/${netns_name}_zebra.pid -A 127.0.0.1 -z /tmp/${netns_name}_zebra.vty

    # gobgp configuration
    run ip netns exec ${netns_name} gobgpd -f /vagrant_data/conf/gobgp/${netns_name}.toml > /vagrant_data/log/${netns_name}.log &
  done

  # create netns_sw
  for ((sw_num=1; sw_num <= $sw_max; sw_num++))
  do
    netns_name="sw${sw_num}"
    run ip netns add ${netns_name}
    run ip netns exec ${netns_name} /sbin/sysctl -w net.ipv4.ip_forward=1
    run ip netns exec ${netns_name} ip link set lo up

    # zebra configuration
    run ip netns exec ${netns_name} /usr/sbin/zebra -d -f /vagrant_data/conf/zebra/${netns_name}.conf -i /tmp/${netns_name}_zebra.pid -A 127.0.0.1 -z /tmp/${netns_name}_zebra.vty
    # run ip netns exec ${netns_name} /usr/sbin/ospfd -d -f /vagrant_data/conf/ospfd/${netns_name}.conf -i /tmp/${netns_name}_ospfd.pid -A 127.0.0.1 -z /tmp/${netns_name}_zebra.vty

    # gobgp configuration
    run ip netns exec ${netns_name} gobgpd -f /vagrant_data/conf/gobgp/${netns_name}.toml > /vagrant_data/log/${netns_name}.log &
  done

  # create netns sv
  for ((sv_num=1; sv_num <= $sv_max; sv_num++))
  do
    netns_name="sv${sv_num}"
    run ip netns add ${netns_name}
    run ip netns exec ${netns_name} ip link set lo up

    # zebra configuration
    run ip netns exec ${netns_name} /usr/sbin/zebra -d -f /vagrant_data/conf/zebra/${netns_name}.conf -i /tmp/${netns_name}_zebra.pid -A 127.0.0.1 -z /tmp/${netns_name}_zebra.vty

    # gobgp configuration
    run ip netns exec ${netns_name} gobgpd -f /vagrant_data/conf/gobgp/${netns_name}.toml > /vagrant_data/log/${netns_name}.log &
  done

  # create veth pair between ag and sw
  for ((ag_num=1; ag_num <= $ag_max; ag_num++))
  do
    ag_netns_name="ag${ag_num}"
    ag_devid=$ag_num
    for ((sw_num=1; sw_num <= $sw_max; sw_num++))
    do
      sw_devid=$(($ag_max+$sw_num))
      sw_netns_name="sw${sw_num}"
      run ip link add ag${ag_num}_sw${sw_num} type veth peer name sw${sw_num}_ag${ag_num}
      run ip link set ag${ag_num}_sw${sw_num} netns ${ag_netns_name}
      run ip link set sw${sw_num}_ag${ag_num} netns ${sw_netns_name}

      run ip netns exec ${ag_netns_name} ip link set ag${ag_num}_sw${sw_num} up
      run ip netns exec ${ag_netns_name} ip addr add 192.168.${ag_devid}${sw_devid}.1/30 dev ag${ag_num}_sw${sw_num}
      run ip netns exec ${sw_netns_name} ip link set sw${sw_num}_ag${ag_num} up
      run ip netns exec ${sw_netns_name} ip addr add 192.168.${ag_devid}${sw_devid}.2/30 dev sw${sw_num}_ag${ag_num}
    done
  done

  # create veth pair between sw and sv
  for ((sw_num=1; sw_num <= $sw_max; sw_num++))
  do
    sw_netns_name="sw${sw_num}"
    sw_devid=$(($ag_max+$sw_num))
    for ((sv_num=1; sv_num <= $sv_max; sv_num++))
    do
      sv_netns_name="sv${sv_num}"
      sv_devid=${sv_num}

      if [[ $sw_num -le $(($sw_max/2)) ]]; then
        if [[ $sv_num -gt $(($sv_max/2)) ]]; then
          continue;
        fi

        run ip link add sw${sw_num}_sv${sv_num} type veth peer name sv${sv_num}_sw${sw_num}
        run ip link set sw${sw_num}_sv${sv_num} netns ${sw_netns_name}
        run ip link set sv${sv_num}_sw${sw_num} netns ${sv_netns_name}
        run ip netns exec ${sw_netns_name} ip link set sw${sw_num}_sv${sv_num} up
        run ip netns exec ${sw_netns_name} ip addr add 192.168.${sw_devid}${sv_devid}.1/30 dev sw${sw_num}_sv${sv_num}
        run ip netns exec ${sv_netns_name} ip link set sv${sv_num}_sw${sw_num} up
        run ip netns exec ${sv_netns_name} ip addr add 192.168.${sw_devid}${sv_devid}.2/30 dev sv${sv_num}_sw${sw_num}

      elif [[ $sw_num -gt $(($sw_max/2)) ]]; then
        if [[ $sv_num -le $(($sv_max/2)) ]]; then
          continue;
        fi

        run ip link add sw${sw_num}_sv${sv_num} type veth peer name sv${sv_num}_sw${sw_num}
        run ip link set sw${sw_num}_sv${sv_num} netns ${sw_netns_name}
        run ip link set sv${sv_num}_sw${sw_num} netns ${sv_netns_name}
        run ip netns exec ${sw_netns_name} ip link set sw${sw_num}_sv${sv_num} up
        run ip netns exec ${sw_netns_name} ip addr add 192.168.${sw_devid}${sv_devid}.1/30 dev sw${sw_num}_sv${sv_num}
        run ip netns exec ${sv_netns_name} ip link set sv${sv_num}_sw${sw_num} up
        run ip netns exec ${sv_netns_name} ip addr add 192.168.${sw_devid}${sv_devid}.2/30 dev sv${sv_num}_sw${sw_num}

      fi
    done  # end of create veth pair between sw and sv
  done
}

destroy_netns() {
  # kill zebra
  run ps aux | grep gobgpd | grep -v grep | awk '{ print "kill -9", $2 }' | sh
  run ps aux | grep zebra | grep -v grep | awk '{ print "kill -9", $2 }' | sh

  for ((ag_num=1; ag_num <= $ag_max; ag_num++))
  do
    netns_name="ag${ag_num}"
    run ip netns exec ${netns_name} /sbin/sysctl -w net.ipv4.ip_forward=0
    run ip netns del ${netns_name}
  done

  for ((sw_num=1; sw_num <= $sw_max; sw_num++))
  do
    netns_name="sw${sw_num}"
    run ip netns exec ${netns_name} /sbin/sysctl -w net.ipv4.ip_forward=0
    run ip netns del ${netns_name}
  done

  for ((sv_num=1; sv_num <= $sv_max; sv_num++))
  do
    netns_name="sv${sv_num}"
    run ip netns del ${netns_name}
  done

  unset ag_max
  unset sw_max
  unset sv_max
}

stop () {
  destroy_netns
}

# exec funtion
create_netns

trap stop 0 1 2 3 13 14 15

status=0; $SHELL || status=$?
exit $status
