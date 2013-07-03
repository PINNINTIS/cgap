#!/bin/ksh

## set RUNDIR = /space/CGAP/run
export RUNDIR=/share/content/CGAP/run
## PATH=/usr/sbin/:/usr/ccs/bin/:/opt/netscape:.:$PATH
## export PATH
cd $RUNDIR
./$1 -bd
exit 0
