#!/usr/local/bin/perl

BEGIN {
  # unshift @INC, ".";
  my @path_elems = split("/", $0);
  pop @path_elems;
  unshift @INC, join("/", @path_elems);
}

use strict;
use FileHandle;
use Blocks;
use ServerSupport;

use constant SERVER_PORT => 8030;

my $sixty = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";

######################################################################
sub TimeStamp {
  my ($sec, $min, $hr, $mday, $mon, $year, $wday, $yday, $isdst) =
      localtime(time);
  my $month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec')[$mon];
  $year = $year + 1900;
  return sprintf "%d_%2.2d_%2.2d %2.2d:%2.2d::%2.2d",
      $year, $mon+1, $mday, $hr, $min, $sec;
}

######################################################################
sub SleepTest {
  my ($base, $id, $seconds, $bytes) = @_;

  my $start = TimeStamp();

  my @lines;  
  my $times = int($bytes / 60);
  my $remainder = $bytes % 60;
  for (my $i = 0; $i < $times; $i++) {
    push @lines, $sixty;
  }
  my @rem;
  for (my $i = 0; $i < $remainder; $i++) {
    push @rem, "X";
  }

  sleep($seconds);
  
  my $stop = TimeStamp();
  return join("\n", "test: $id", $start, $stop, @lines, join("", @rem), "");

}

######################################################################
#
# main
#

SetProgramName($0);

SetSafe(
    "KillServer",
    "ResetServer",
    "SleepTest"
);

SetForkable(
    "SleepTest",
);

StartServer(SERVER_PORT, "SleepTest");
