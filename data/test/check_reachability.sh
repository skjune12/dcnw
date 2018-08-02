#!/usr/bin/env bash

cr_max=1
ag_max=2
sw_max=4
sv_max=6

# cr
for ((cr_num=1; cr_num <= $cr_max; cr_num++))
do
  cr_netns_name="cr${cr_num}"
  cr_devid=$cr_num

  for ((ag_num=1; ag_num <= $ag_max; ag_num++))
  do
    ag_netns_name="ag${ag_num}"
    ag_devid=$(($cr_max+$ag_num))

    echo "connectivity between ${cr_netns_name} and ${ag_netns_name}"
    ping -c 3 -w 1000 192.168.${cr_devid}${ag_devid}.1
    ping -c 3 -w 1000 192.168.${cr_devid}${ag_devid}.2
  done
done

for ((ag_num=1; ag_num <= $ag_max; ag_num++))
do
  ag_netns_name="ag${ag_num}"
  ag_devid=$(($cr_max+$ag_num))

  for ((sw_num=1; sw_num <= $sw_max; sw_num++))
  do
    sw_netns_name="sw${sw_num}"
    sw_devid=$(($cr_max+$ag_max+$sw_num))

    echo "connectivity between ${ag_netns_name} and ${sw_netns_name}"
    ping -c 3 -w 1000 192.168.${ag_devid}${sw_devid}.1
    ping -c 3 -w 1000 192.168.${ag_devid}${sw_devid}.2
  done
done

for ((sw_num=1; sw_num <= $sw_max; sw_num++))
do
  sw_netns_name="sw${sw_num}"
  sw_devid=$(($cr_max+$ag_max+$sw_num))

  for ((sv_num=1; sv_num <= $sv_max; sv_num++))
  do
    sv_netns_name="sv${sv_num}"
    sv_devid=${sv_num}

    if [[ $sw_num -le $(($sw_max/2)) ]]; then
      if [[ $sv_num -gt $(($sv_max/2)) ]]; then
        continue;
      fi
      echo "connectivity between ${sw_netns_name} and ${sv_netns_name}"
      ping -c 3 -w 1000 192.168.${sw_devid}${sv_devid}.1
      ping -c 3 -w 1000 192.168.${sw_devid}${sv_devid}.2
    elif [[ $sw_num -gt $(($sw_max/2)) ]]; then
      if [[ $sv_num -le $(($sv_max/2)) ]]; then
        continue;
      fi
      ping -c 3 -w 1000 192.168.${sw_devid}${sv_devid}.1
      ping -c 3 -w 1000 192.168.${sw_devid}${sv_devid}.2
    fi
  done
done
