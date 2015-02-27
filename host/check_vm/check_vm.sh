#!/bin/bash
#
# Copyright (C) 2014 VA Linux Systems Japan K.K.
# Copyright (C) 2014 Fumihiko Kakuma <kakuma at valinux co jp>
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#
# This script checks if a target vm exists. If the vm doesn't exist, starts it.
# And also receate an overlay image file by default.

SCRIPT_NAME="`basename $0`"
IMAGES_DIR=${IMAGES_DIR:-"/var/lib/libvirt/images"}
MAX_LOOP=4
MAX_CHECK=3
SLEEP_SEC=15
REMOVEOVL='n'
RECREATE='y'
CHECK_SLAVE='n'
TARGETVMS=${TARGETVMS:-"slave1 slave2 slave3 slave4 slave5 slave6 jslave1"}
JENKINS_URL=${JENKINS_URL:-http://master:8080/}
JENKINS_CLI=/usr/local/jenkins/jenkins-cli.jar
OFFLINE_MAX=${OFFLINE_MAX:-600}
declare -A SLAVE_STATUS

function usage {
	cat <<- EOF
	USAGE : $SCRIPT_NAME [-h -c max-check -i int -j -m max -r -s -t vm-name]
	        -h display this messages
	        -c max existece check count
	           default: 3
	        -i interval to check vm
	           default: 15
	        -j check if slave is offline
	        -m max loop times
	           runs until killed if max is zero
	           default: 4
	        -r remove an old ovl file
	           default: save an old ovl image file as xxx.old
	        -s only start vm
	           default: recreate an ovl image file
	        -t specify target vm
	           default: $TARGETVMS
	        and you can use the following environment vaiables
	          IMAGES_DIR: a directory has image file
	          TARGETVMS: specify target vm(same to -t option)
	EOF
}

function jenkins_cli() {
    local cmd=$1
    local slave=$2
    java -jar $JENKINS_CLI -s $JENKINS_URL $cmd $slave
}

function check_slave_status {
    local slave=$1
    local cli_res
    local count

    if [[ $CHECK_SLAVE == 'n' ]]; then
        return 0
    fi
    cli_res=$(jenkins_cli get-node $slave)
    if [[ $? -ne 0 ]]; then
        echo "failed to get jenkins node status!!"
        return 0
    else
        echo $cli_res|grep 'temporaryOfflineCause' >/dev/null
        if [[ $? -eq 0 ]]; then
            echo "Currently $slave is offline."
            count=${SLAVE_STATUS[$slave]}
            SLAVE_STATUS[$slave]=$((++count))
            if [[ $(($count*$SLEEP_SEC)) -gt $OFFLINE_MAX ]]; then
                SLAVE_STATUS[$slave]=0
                return 1
            else
                return 0
            fi
        else
            echo "Currently $slave is online."
            SLAVE_STATUS[$slave]=0
            return 0
        fi
    fi
}

function vm_exists {
    local vm=$1
    local max=$MAX_CHECK
    local count=0
    while [ $count -lt $max ]; do
        if virsh list | grep " $vm" > /dev/null; then
            return 0
        fi
        count=$((count+1))
        sleep 1
    done
    return 1
}

while getopts "hc:i:jm:rst:" opt; do
    case $opt in
      h)
        usage
        exit 0
        ;;
      c)
        MAX_CHECK=$OPTARG
        ;;
      i)
        SLEEP_SEC=$OPTARG
        ;;
      j)
        CHECK_SLAVE='y'
        ;;
      m)
        MAX_LOOP=$OPTARG
        ;;
      r)
        REMOVEOVL='y'
        ;;
      s)
        RECREATE='n'
        ;;
      t)
        TARGETVMS="$OPTARG"
        ;;
      *)
        echo "unknown option is specified!!"
        exit 1
        ;;
    esac
done
shift $((OPTIND - 1))
if [ $MAX_LOOP -eq 0 ]; then
    COUNT=-1
else
    COUNT=0
    #SLEEP_SEC=$((60/$MAX_LOOP))
fi
for vm in $TARGETVMS; do
    SLAVE_STATUS[$vm]=0
done
declare -p MAX_LOOP SLEEP_SEC COUNT RECREATE REMOVEOVL TARGETVMS OFFLINE_MAX CHECK_SLAVE
declare -p SLAVE_STATUS
echo "sleep every $SLEEP_SEC sec"
while [ $COUNT -lt $MAX_LOOP ]; do
    sleep $SLEEP_SEC
    echo "start loop"
    virsh list
    date
    for vm in $TARGETVMS; do
        echo "check $vm"
        if vm_exists $vm; then
            echo "$vm exsits"
            if ! check_slave_status $vm; then
                echo "!!virsh destroy $vm"
                virsh destroy $vm
            fi
            continue
        fi
        virsh list
        date
        stat=0
        if [ "$RECREATE" = "y" ]; then
            echo "!!create overlay image for $vm"
            if [ -f ${IMAGES_DIR}/${vm}.ovl ]; then
                if [ "$REMOVEOVL" = "y" ]; then
                    rm -f ${IMAGES_DIR}/${vm}.ovl
                else
                    mv ${IMAGES_DIR}/${vm}.ovl ${IMAGES_DIR}/${vm}.ovl.old
                fi
            fi
            qemu-img create -o backing_file=${IMAGES_DIR}/${vm}.qc2,backing_fmt=qcow2 -f qcow2 ${IMAGES_DIR}/${vm}.ovl
            stat=$?
            if [ $stat -ne 0 ]; then
                echo "!!failed to create overlay image for $vm"
                continue
            fi
            sleep 2
        fi
        echo "!!virsh start $vm"
        virsh start $vm
    done
    declare -p SLAVE_STATUS
    if [ $MAX_LOOP -ne 0 ]; then
        COUNT=$((COUNT+1))
    fi
done
exit 0
