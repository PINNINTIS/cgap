#!/bin/csh

set RUNDIR = /share/content/CGAP/run

set PROGS = ( \
##  GeneServer.pl \
##  LibServer.pl \
##  CytSearchServer.pl \
  PathwayServer.pl \
##   BlastQueryServer.pl \
  GXSServer.pl \
  GLServer.pl \
  MicroArrayServer.pl \
)

cd $RUNDIR

if ($1 == "") then
  foreach prog ($PROGS)
    $RUNDIR/$prog &
  end
else
  $RUNDIR/$1 &
endif
