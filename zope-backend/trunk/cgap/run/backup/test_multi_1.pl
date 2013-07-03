#!/usr/local/bin/perl

#############################################################################
#

use strict;
use Config; 
use CGI;

use Thread;
use Thread::Queue;
my $stream = new Thread::Queue;
my $kid    = new Thread(\&check_num, $stream, 2);

for my $i ( 3 .. 1000 ) {
  $stream->enqueue($i);
} 

$stream->enqueue(undef);
$kid->join();

sub check_num {
  my ($upstream, $cur_prime) = @_;
  my $kid;
  my $downstream = new Thread::Queue;
  while (my $num = $upstream->dequeue) {
    next unless $num % $cur_prime;
    if ($kid) {
       $downstream->enqueue($num);
    } else {
      print "Found prime $num\n";
      $kid = new Thread(\&check_num, $downstream, $num);
    }
  } 
  $downstream->enqueue(undef) if $kid;
  $kid->join()         if $kid;
}
