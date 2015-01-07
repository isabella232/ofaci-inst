#!/bin/bash

LOGROOT='/data/ryuci'
LOGROOT_SWEEP=${LOGROOT}/sweep_empty_dirs.log

echo "### Sweep empty directory." 2>&1 | tee -a $LOGROOT_SWEEP
date 2>&1 | tee -a $LOGROOT_SWEEP
DIRS=`find $LOGROOT -maxdepth 1 -type d -name "??"`
for dir in $DIRS; do
	echo $dir
	pushd $dir 1> /dev/null
	ls -l
	sudo find -type d -empty -print -delete
	popd 1> /dev/null
done
date 2>&1 | tee -a $LOGROOT_SWEEP
exit 0
