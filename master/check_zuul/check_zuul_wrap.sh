#!/bin/bash
export ZUUL_LOG_FILE="/var/log/zuul/zuul.log"
export ZUUL_DEBUG_FILE="/var/log/zuul/debug.log"
export ZUUL_FAIL_STR_FILE="/var/log/zuul/zuul_check_data"
export TRB_MAX=300
/usr/local/bin/check_zuul.sh -m 0 -i 4 -s 15 1>> /var/log/check_zuul.log 2>&1 &
