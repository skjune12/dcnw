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
  # create veth pair between cr and eg
  eg_max=2
  cr_max=4
  ac_max=6

  # create netns
  for ((eg_num=1; eg_num <= $eg_max; eg_num++))
  do
    netns_name="eg${eg_num}"
    eg_devid=$eg_num

    run ip netns add ${netns_name}
    run ip netns exec ${netns_name} /sbin/sysctl -w net.ipv4.ip_forward=1
    run ip netns exec ${netns_name} ip link set lo up

    # zebra configuration
    run ip netns exec ${netns_name} /usr/sbin/zebra -d -f /vagrant_data/conf/zebra/${netns_name}.conf -i /tmp/${netns_name}_zebra.pid -A 127.0.0.1 -z /tmp/${netns_name}_zebra.vty

    # gobgp configuration
    run ip netns exec ${netns_name} gobgpd -f /vagrant_data/conf/gobgp/${netns_name}.toml > /vagrant_data/log/${netns_name}.log &
  done

  # create netns_cr
  for ((cr_num=1; cr_num <= $cr_max; cr_num++))
  do
    netns_name="cr${cr_num}"
    run ip netns add ${netns_name}
    run ip netns exec ${netns_name} /sbin/sysctl -w net.ipv4.ip_forward=1
    run ip netns exec ${netns_name} ip link set lo up

    # zebra configuration
    run ip netns exec ${netns_name} /usr/sbin/zebra -d -f /vagrant_data/conf/zebra/${netns_name}.conf -i /tmp/${netns_name}_zebra.pid -A 127.0.0.1 -z /tmp/${netns_name}_zebra.vty
    # run ip netns exec ${netns_name} /usr/sbin/ospfd -d -f /vagrant_data/conf/ospfd/${netns_name}.conf -i /tmp/${netns_name}_ospfd.pid -A 127.0.0.1 -z /tmp/${netns_name}_zebra.vty

    # gobgp configuration
    run ip netns exec ${netns_name} gobgpd -f /vagrant_data/conf/gobgp/${netns_name}.toml > /vagrant_data/log/${netns_name}.log &
  done

  # create netns ac
  for ((ac_num=1; ac_num <= $ac_max; ac_num++))
  do
    netns_name="ac${ac_num}"
    run ip netns add ${netns_name}
    run ip netns exec ${netns_name} ip link set lo up

    # zebra configuration
    run ip netns exec ${netns_name} /usr/sbin/zebra -d -f /vagrant_data/conf/zebra/${netns_name}.conf -i /tmp/${netns_name}_zebra.pid -A 127.0.0.1 -z /tmp/${netns_name}_zebra.vty

    # gobgp configuration
    run ip netns exec ${netns_name} gobgpd -f /vagrant_data/conf/gobgp/${netns_name}.toml > /vagrant_data/log/${netns_name}.log &
  done

  # create veth pair between eg and cr
  for ((eg_num=1; eg_num <= $eg_max; eg_num++))
  do
    eg_netns_name="eg${eg_num}"
    eg_devid=$eg_num
    for ((cr_num=1; cr_num <= $cr_max; cr_num++))
    do
      cr_devid=$(($eg_max+$cr_num))
      cr_netns_name="cr${cr_num}"
      run ip link add eg${eg_num}_cr${cr_num} type veth peer name cr${cr_num}_eg${eg_num}
      run ip link set eg${eg_num}_cr${cr_num} netns ${eg_netns_name}
      run ip link set cr${cr_num}_eg${eg_num} netns ${cr_netns_name}

      run ip netns exec ${eg_netns_name} ip link set eg${eg_num}_cr${cr_num} up
      run ip netns exec ${eg_netns_name} ip addr add 192.168.${eg_devid}${cr_devid}.1/30 dev eg${eg_num}_cr${cr_num}
      run ip netns exec ${cr_netns_name} ip link set cr${cr_num}_eg${eg_num} up
      run ip netns exec ${cr_netns_name} ip addr add 192.168.${eg_devid}${cr_devid}.2/30 dev cr${cr_num}_eg${eg_num}
    done
  done

  # create veth pair between cr and ac
  for ((cr_num=1; cr_num <= $cr_max; cr_num++))
  do
    cr_netns_name="cr${cr_num}"
    cr_devid=$(($eg_max+$cr_num))
    for ((ac_num=1; ac_num <= $ac_max; ac_num++))
    do
      ac_netns_name="ac${ac_num}"
      ac_devid=${ac_num}

      if [[ $cr_num -le $(($cr_max/2)) ]]; then
        if [[ $ac_num -gt $(($ac_max/2)) ]]; then
          continue;
        fi

        run ip link add cr${cr_num}_ac${ac_num} type veth peer name ac${ac_num}_cr${cr_num}
        run ip link set cr${cr_num}_ac${ac_num} netns ${cr_netns_name}
        run ip link set ac${ac_num}_cr${cr_num} netns ${ac_netns_name}
        run ip netns exec ${cr_netns_name} ip link set cr${cr_num}_ac${ac_num} up
        run ip netns exec ${cr_netns_name} ip addr add 192.168.${cr_devid}${ac_devid}.1/30 dev cr${cr_num}_ac${ac_num}
        run ip netns exec ${ac_netns_name} ip link set ac${ac_num}_cr${cr_num} up
        run ip netns exec ${ac_netns_name} ip addr add 192.168.${cr_devid}${ac_devid}.2/30 dev ac${ac_num}_cr${cr_num}

      elif [[ $cr_num -gt $(($cr_max/2)) ]]; then
        if [[ $ac_num -le $(($ac_max/2)) ]]; then
          continue;
        fi

        run ip link add cr${cr_num}_ac${ac_num} type veth peer name ac${ac_num}_cr${cr_num}
        run ip link set cr${cr_num}_ac${ac_num} netns ${cr_netns_name}
        run ip link set ac${ac_num}_cr${cr_num} netns ${ac_netns_name}
        run ip netns exec ${cr_netns_name} ip link set cr${cr_num}_ac${ac_num} up
        run ip netns exec ${cr_netns_name} ip addr add 192.168.${cr_devid}${ac_devid}.1/30 dev cr${cr_num}_ac${ac_num}
        run ip netns exec ${ac_netns_name} ip link set ac${ac_num}_cr${cr_num} up
        run ip netns exec ${ac_netns_name} ip addr add 192.168.${cr_devid}${ac_devid}.2/30 dev ac${ac_num}_cr${cr_num}

      fi
    done  # end of create veth pair between cr and ac
  done
}

destroy_netns() {
  # kill zebra
  run ps aux | grep gobgpd | grep -v grep | awk '{ print "kill -9", $2 }' | sh
  run ps aux | grep zebra | grep -v grep | awk '{ print "kill -9", $2 }' | sh

  for ((eg_num=1; eg_num <= $eg_max; eg_num++))
  do
    netns_name="eg${eg_num}"
    run ip netns exec ${netns_name} /sbin/sysctl -w net.ipv4.ip_forward=0
    run ip netns del ${netns_name}
  done

  for ((cr_num=1; cr_num <= $cr_max; cr_num++))
  do
    netns_name="cr${cr_num}"
    run ip netns exec ${netns_name} /sbin/sysctl -w net.ipv4.ip_forward=0
    run ip netns del ${netns_name}
  done

  for ((ac_num=1; ac_num <= $ac_max; ac_num++))
  do
    netns_name="ac${ac_num}"
    run ip netns del ${netns_name}
  done

  unset eg_max
  unset cr_max
  unset ac_max
}

stop () {
  destroy_netns
}

# exec funtion
create_netns

trap stop 0 1 2 3 13 14 15

status=0; $SHELL || status=$?
exit $status
