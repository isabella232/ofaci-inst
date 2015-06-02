#!/bin/bash
#
# Copyright (C) 2015 VA Linux Systems Japan K.K.
# Copyright (C) 2015 Fumihiko Kakuma <kakuma at valinux co jp>
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
# This script checks if the zuul works well. If the zuul doesn't exist, starts it.

SCRIPT_NAME="`basename $0`"
ZUUL_LOG_FILE=${ZUUL_LOG_FILE:-"/var/log/zuul/zuul.log"}
ZUUL_DEBUG_FILE=${ZUUL_DEBUG_FILE:-"/var/log/zuul/debug.log"}
MAX_LOOP=4
SLEEP_SEC=15
CHECK_CNT=0
CHECK_INT_ZUUL=0
JENKINS_CLI=/usr/local/jenkins/jenkins-cli.jar
TRB_MAX=${TRB_MAX:-300}
ZUUL_LOOP_CNT=0
ZUUL_FAIL_CNT=0
ZUUL_FAIL_TOTAL=0
ZUUL_DEBUG_CNT=0
LAST_ZUUL_LOG=()
LAST_ZUUL_DBGLOG=()
ZUUL_FAIL_STR=(
"AttributeError: 'NoneType' object has no attribute"
)
ZUUL_DEBUG_STR=(
"Looking for lost builds"
)


function usage {
	cat <<- EOF
	USAGE : $SCRIPT_NAME [-h -c max-check -i int -m max -s sec]
	        -h display this messages
	        -i interval to check if zuul is in trouble
	        -m max loop times
	           runs until killed if max is zero
	           default: 4
	        -s interval to check zuul
	           default: 15
	        and you can use the following environment vaiables
	            ZUUL_LOG_FILE: zuul log file to check
	            TRB_MAX: cwinterval to check any trouble
	EOF
}

function restart_zuul {
    local merger_only=${1:-'n'}

    service zuul-merger stop
    echo "Stop zuul-merger"
    if [[ $merger_only == 'n' ]]; then
        service zuul stop
        echo "Stop zuul"
        pkill -9 zuul-server
    fi
    pkill -9 zuul-merger
    ps -ef | grep zuul-
    sleep 1
    if [[ $merger_only == 'n' ]]; then
        service zuul start
        echo "Start zuul"
    fi
    sleep 1
    service zuul-merger start
    echo "Start zuul-merger"
    ZUUL_FAIL_CNT=0
    ZUUL_FAIL_TOTAL=0
    ZUUL_DEBUG_CNT=0
}

# Unstable zuul often raises an exception by reloading zuul.
# This tries to detect it.
function reload_zuul {
    echo "Reload zuul"
    service zuul reload
}

function zuul_exists {
    local slave=$1
    local cli_res
    local count

    if [[ $CHECK_INT_ZUUL -eq 0 ]]; then
        echo "Checking zuul status is unavailable."
        return 0
    fi
    service zuul status
    zuul_stat=$?
    service zuul-merger status
    merger_stat=$?

    if [[ $zuul_stat -ne 0 ]]; then
        restart_zuul
        return 1
    elif [[ $merger_stat -ne 0 ]]; then
        restart_zuul 'y'
        return 2
    fi
    echo "zuul condition is OK"
    return 0
}

function check_zuul_log {
    local taillog
    local matchlog
    local str

    taillog=`tail -n 20 $ZUUL_LOG_FILE`
    for (( i=0; i < ${#ZUUL_FAIL_STR[@]}; ++i ))
    do
        str=${ZUUL_FAIL_STR[$i]}
        matchlog=`echo "$taillog" | grep "$str"`
        if [ -n "$matchlog" -a "x${matchlog}" != "x${LAST_ZUUL_LOG[$i]}" ]; then
            LAST_ZUUL_LOG[$i]="$matchlog"
            echo "Currently zuul is in trouble"
            ZUUL_FAIL_CNT=$((++ZUUL_FAIL_CNT))
            if [[ $(($SLEEP_SEC*$ZUUL_FAIL_CNT)) -ge $TRB_MAX ]]; then
                echo "fail count reached the max"
                ZUUL_FAIL_CNT=0
                ZUUL_FAIL_TOTAL=0
                return 1
            else
                return 0
            fi
        fi
    done
    ZUUL_FAIL_TOTAL=$(($ZUUL_FAIL_TOTAL+$ZUUL_FAIL_CNT))
    ZUUL_FAIL_CNT=0
    if [[ $ZUUL_FAIL_TOTAL -ne 0 ]]; then
        ZUUL_LOOP_CNT=$((++ZUUL_LOOP_CNT))
    fi
    if [[ $(($SLEEP_SEC*$ZUUL_LOOP_CNT)) -ge $TRB_MAX ]]; then
        ZUUL_LOOP_CNT=0
        ZUUL_FAIL_TOTAL=0
        reload_zuul
    fi
    declare -p ZUUL_FAIL_TOTAL
    if [[ $ZUUL_FAIL_TOTAL -ge $TOTAL_FAIL_MAX ]]; then
        echo "total fail count reached the max"
        ZUUL_FAIL_TOTAL=0
        return 2
    fi
    echo "Currently zuul is normaly running from zuul log"
    return 0
}

function check_zuul_debug_log {
    local taillog
    local matchlog
    local str

    taillog=`tail -n 1 $ZUUL_DEBUG_FILE`
    for (( i=0; i < ${#ZUUL_DEBUG_STR[@]}; ++i ))
    do
        str=${ZUUL_DEBUG_STR[$i]}
        matchlog=`echo "$taillog" | grep "$str"`
        if [ -n "$matchlog" -a "x${matchlog}" != "x${LAST_ZUUL_DBGLOG[$i]}" ]; then
            LAST_ZUUL_DBGLOG[$i]="$matchlog"
            echo "Currently zuul in trouble"
            ZUUL_DEBUG_CNT=$((++ZUUL_DEBUG_CNT))
            if [[ $(($SLEEP_SEC*$ZUUL_DEBUG_CNT)) -ge $TRB_MAX ]]; then
                echo "debug fail count reached the max"
                ZUUL_DEBUG_CNT=0
                return 1
            else
                return 0
            fi
        fi
    done
    ZUUL_DEBUG_CNT=0
    echo "Currently zuul is normaly running from debug log"
    return 0
}

while getopts "hc:i:m:s:" opt; do
    case $opt in
      h)
        usage
        exit 0
        ;;
      i)
        CHECK_INT_ZUUL=$OPTARG
        ;;
      m)
        MAX_LOOP=$OPTARG
        ;;
      s)
        SLEEP_SEC=$OPTARG
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
TOTAL_FAIL_MAX=$(($TRB_MAX/$SLEEP_SEC))
if [[ -n "$ZUUL_FAIL_STR_FILE" ]]; then
    ZUUL_FAIL_STR=()
    exec < $ZUUL_FAIL_STR_FILE
    while read LINE; do
        ZUUL_FAIL_STR=("${ZUUL_FAIL_STR[@]}" "$LINE")
    done
fi
if [[ -n "$ZUUL_DEBUG_STR_FILE" ]]; then
    ZUUL_DEBUG_STR=()
    exec < $ZUUL_DEBUG_STR_FILE
    while read LINE; do
        ZUUL_DEBUG_STR=("${ZUUL_DEBUG_STR[@]}" "$LINE")
    done
fi
echo "########## Start checking zuul script ##########"
declare -p MAX_LOOP SLEEP_SEC COUNT
declare -p TRB_MAX TOTAL_FAIL_MAX CHECK_INT_ZUUL
declare -p ZUUL_FAIL_CNT ZUUL_DEBUG_CNT
declare -p ZUUL_FAIL_STR ZUUL_DEBUG_STR
echo "sleep every $SLEEP_SEC sec"
while [ $COUNT -lt $MAX_LOOP ]; do
    sleep $SLEEP_SEC
    echo "########## start loop ##########"
    date
    CHECK_CNT=$((++CHECK_CNT))
    declare -p CHECK_CNT ZUUL_LOOP_CNT
    declare -p LAST_ZUUL_LOG LAST_ZUUL_DBGLOG
    if [[ $CHECK_INT_ZUUL -gt $CHECK_CNT ]]; then
        echo "** SKIP checking zuul status"
    else
        CHECK_CNT=0
        declare -p CHECK_CNT
    fi
    if [[ $CHECK_CNT -eq 0 ]]; then
        echo "check if zuul exists"
        if ! zuul_exists; then
            continue
        fi
    fi
    echo "check zuul log"
    if ! check_zuul_log; then
        echo "Restart zuul !!"
        date
        restart_zuul
    elif ! check_zuul_debug_log; then
        echo "Restart zuul !!"
        date
        restart_zuul
    fi
    declare -p ZUUL_FAIL_CNT ZUUL_DEBUG_CNT
    if [[ $MAX_LOOP -ne 0 ]]; then
        COUNT=$((COUNT+1))
    fi
done
exit 0
