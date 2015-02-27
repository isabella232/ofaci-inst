#!/bin/bash
export IMAGES_DIR="/opt/ci-pool"
export JENKINS_URL=http://master:8080/
export OFFLINE_MAX=600
export TARGETVMS="slave1 slave2 slave3 slave4 jslave1"
/usr/local/bin/check_vm.sh -c 3 -m 0 -i 15 1>> /var/log/check_vm.log 2>&1 &
