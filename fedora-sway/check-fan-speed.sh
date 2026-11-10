#!/bin/bash

for x in {1..2}; do
   echo "Fan $x: $(cat /sys/class/hwmon/hwmon4/fan${x}_input)"
done;
