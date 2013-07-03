#!/bin/csh

set THIS_SCRIPT = cgap_cron.csh

set RUNDIR = /share/content/CGAP/run

set START_SERVER_SCRIPT = $RUNDIR/StartCGAPServers.csh

set PROGS = ( \
##   GLServer.pl \
##  PathwayServer.pl \
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

##
## now the PID server
##

set RUNDIR = /share/content/PID/run

set PROGS = ( \
  ## PWAppServer.pl \
)

set PSFILE = /tmp/pid_ps.txt

ps -ef > $PSFILE

foreach prog ($PROGS)
  set EXPR = $RUNDIR/$prog
  if (`grep -c $EXPR $PSFILE` < 1) then
    logger -p daemon.alert "$THIS_SCRIPT restarting $prog"
    $RUNDIR/$prog &
  endif
end
