#!/bin/csh

set THIS_SCRIPT = cbiodev5047_cgap_cron.csh

set RUNDIR = /share/content/CGAP/run

set START_SERVER_SCRIPT = $RUNDIR/StartCGAPServers.csh

set PROGS = ( \
##  GeneServer.pl \
##  LibServer.pl \
  GLServer.pl \
##  CytSearchServer.pl \
  PathwayServer.pl \
  BlastQueryServer.pl \
  MicroArrayServer.pl \
  GXSServer.pl \
##  PWAppServer.pl \
)

set PSFILE = /tmp/cgap_ps.txt

ps -ef > $PSFILE

foreach prog ($PROGS)
  set EXPR = $RUNDIR/$prog
  if (`grep -c $EXPR $PSFILE` < 1) then
    logger -p daemon.alert "$THIS_SCRIPT restarting $prog"
    $START_SERVER_SCRIPT $prog
  endif
end

#set EXPR = /cgap/schaefec/carl/PATHWAY/PWAppServer.pl
#if (`grep -c  $EXPR $PSFILE` < 1) then
#  /cgap/schaefec/carl/PATHWAY/PWAppServer.pl &
#endif
