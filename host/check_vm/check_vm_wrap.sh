#!/bin/bash
export IMAGES_DIR="/opt/ci-pool"
export OFFLINE_MAX=600
export TARGETVMS="master:slave1,slave2,slave3,slave4 jmaster:jslave1"
/usr/local/bin/check_vm.sh -c 3 -m 0 -i 15 -j 4 1>> /var/log/check_vm.log 2>&1 &
