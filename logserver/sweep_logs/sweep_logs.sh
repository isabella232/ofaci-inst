#!/bin/bash

LOGROOT='/data/ryuci'
LOGROOT_SWEEP=${LOGROOT}/sweep.log
if [ -z "$1" ]; then
	HISTORY=32
else
	HISTORY=$1
fi
#read -p "Sweep logs before ${HISTORY} days. Do you want to do it? [y/N]:" res
#if [ "x${res}" = "xy" -o "x${res}" = "xY" ]; then
#	:
#else
#	echo "Nothing to do"
#	exit 0
#fi

echo "### Sweep log before ${HISTORY} days." 2>&1 | tee -a $LOGROOT_SWEEP
date 2>&1 | tee -a $LOGROOT_SWEEP
df -h 2>&1 | tee -a $LOGROOT_SWEEP
DIRS=`find $LOGROOT -maxdepth 1 -type d -name "??"`
for dir in $DIRS; do
	echo $dir
	pushd $dir 1> /dev/null
	ls -l
	sudo find -mindepth 5 -type d -mtime +${HISTORY} -print -exec rm -rf {} 2> /dev/null \;
	#sudo find -type d -empty -delete
	popd 1> /dev/null
done
df -h 2>&1 | tee -a $LOGROOT_SWEEP
date 2>&1 | tee -a $LOGROOT_SWEEP
exit 0
