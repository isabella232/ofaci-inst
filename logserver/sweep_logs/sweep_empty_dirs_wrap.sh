#!/bin/bash
set -x

LOGDATE=`date +%Y%m%d`
/data/sweep_logs/sweep_empty_dirs.sh 2>&1 | tee sweep_empty_dirs.sh.${LOGDATE}.log
