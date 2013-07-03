#!/usr/local/bin/perl

use strict;
use FileHandle;
use CGI;
use Socket;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
use CGAPConfig;
use Blocks;

my $RUNDIR = "/share/content/CGAP/run";
my $HOST   = "cbiodev104.nci.nih.gov";

######################################################################
sub CatchPipe {
  print STDERR "Caught PIPE signal\n";
}
$SIG{PIPE} = \&CatchPipe;

## my $buffer;
## read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
print "Content-type: text/plain\n\n";
## print "AAAAAA1: $ENV{'CONTENT_LENGTH'}";
## print "AAAAAA2: $buffer";
## exit;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $operation = $query->param("OPERATION");
my $program   = $query->param("PROGRAM");
my $port      = $query->param("PORT");

if( $operation eq "" or 
    $program eq "" or
    $port eq "" ) {
  print "Please choose and fill each one.";
}  
else {
  if( $operation eq "start" ) {
    my $cmd = "cd $RUNDIR";
    system($cmd);
    ## my $cmd = "setenv PATH=/usr/sbin/:/usr/ccs/bin/:/opt/netscape:.";
    ## system($cmd);
    ## my $cmd = "$program &";
    ## print "AAAAAAA: $cmd";
    ## $cmd = "$RUNDIR/StartCGAPServer.ksh $program &";
    $cmd = "$RUNDIR/StartCGAPServer.ksh $program";
    system($cmd);
    ## `GLServer.pl &`;
    my $responce = 0;
    ## = sprintf "%s", system($cmd);
    if( $responce != 0 ) {
      print "<b>bind: Address already in use at ServerSupport.pm line 203.</b><br>";
    }
    else {
      print "<b>AAAA: $program is Starting.</b><br>";
    }
    exit;
    ## `$cmd`;
  }
  else {

    my ($host, $iaddr, $sin);
    my $proto          = getprotobyname('tcp');
    my $host = $HOST;
    my $fh = new FileHandle;

    my $iaddr          = gethostbyname($host);
    my $sin            = sockaddr_in($port, $iaddr);

    if( !socket($fh, PF_INET, SOCK_STREAM, $proto) ) {
      print "Cannot open socket to $host:$port\n";
      die;
    }
    if( !connect($fh, $sin) ) {
      print "Cannot connect to $host:$port\n";
      die;
    }
    if( $operation eq "restart" ) {
      my $request = "ResetServer()";
      if( !SendBlocks($fh, \$request) ) {
        print "SendBlocks failed for $host:$port\n";
        die;
      }
    }
    elsif( $operation eq "kill" ) {
      my $request = "StopServer()";
      `kill 17375`;
      `kill 17368`;
      `kill 17369`;
      `kill 17373`;
      if( !SendBlocks($fh, \$request) ) {
        print "SendBlocks failed for $host:$port\n";
        die;
      }
      print "AAAAAAAABBBB $host, $port";
    }
 
    close($fh);
  }
}

