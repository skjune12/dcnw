#!/usr/bin/env bash
for i in `seq 1 6`
do
  for j in `seq 1 6`
  do
    for k in `seq 3 6`
    do
      cr_num=$((k-2))
      ip netns exec eg1 ping -c 3 -w 1000 10.0.${k}${j}.2 > /dev/null
      if [ $? -eq 0 ]; then
        # echo "ping eg1 to ac${j} via cr${cr_num}: true"
        ip netns exec eg2 traceroute 10.0.${k}${j}.2
      fi

      ip netns exec eg2 ping -c 3 -w 1000 10.0.${k}${j}.2 > /dev/null
      if [ $? -eq 0 ]; then
        # echo "ping eg1 to ac${j} via cr${cr_num}: true"
        ip netns exec eg2 traceroute 10.0.${k}${j}.2
      fi

      ip netns exec ac${i} ping -c 3 -w 1000 10.0.${k}${j}.2 > /dev/null
      if [ $? -eq 0 ]; then
        # echo "ping ac${i} to ac${j} via cr${cr_num}: true"
        ip netns exec ac${i} traceroute 10.0.${k}${j}.2
      fi
    done
  done
done
