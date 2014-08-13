#!/bin/sh
set -e
CDIR=$(cd $(dirname $0) && pwd)
cd $CDIR
./bench --workload 1 --init /home/isu-user/isucon/init.sh 2>&1 | tee ./data/latest

