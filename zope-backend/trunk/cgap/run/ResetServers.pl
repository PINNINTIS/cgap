#!/usr/local/bin/perl

use strict;
use FileHandle;
use Socket;
use Blocks;

######################################################################
sub CatchPipe {
  print STDERR "Caught PIPE signal\n";
}
$SIG{PIPE} = \&CatchPipe;

######################################################################

open(INPF, $ARGV[0]) or die "Cannot open input file $ARGV[0]";

my ($host, $port, $iaddr, $sin);
my $proto          = getprotobyname('tcp');
## my $request = "ResetServer()";
my $request = "StopServer()";
my $fh = new FileHandle;

while (<INPF>) {

  chop;
  if (/^\s*$/) {
    next;
  }
  if (/^\s*#/) {
    next;
  }
  ($host, $port) = split /\s+/;
  if ($host eq "" || $port eq "") {
    print "Bad input line $_\n";
    next
  }

  if( $ARGV[1] eq "TEST" and $host eq "lpgprod101.nci.nih.gov" ) {
    next;
  }
  elsif ( $ARGV[1] ne "TEST" and $host eq "lpgprot101.nci.nih.gov" ) {
    next;
  }

  print STDERR "Reseting $_\n";

  my $iaddr          = gethostbyname($host);
  my $sin            = sockaddr_in($port, $iaddr);

  if( !socket($fh, PF_INET, SOCK_STREAM, $proto) ) {
      print "Cannot open socket to $host:$port\n";
      next;
  }
  if( !connect($fh, $sin) ) {
      print "Cannot connect to $host:$port\n";
      next;
  }
  if( !SendBlocks($fh, \$request) ) {
      print "SendBlocks failed for $host:$port\n";
      next;
  }
  close($fh);

  print STDERR "Reseting $_\n";
}


