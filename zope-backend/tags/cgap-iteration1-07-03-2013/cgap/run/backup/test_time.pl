#!/usr/local/bin/perl
use strict;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);

my $t0 = [gettimeofday]; 
for(my $i=0; $i<10000000; $i++) {
  my $j = $i + 1;
}
my $elapsed = tv_interval ($t0, [gettimeofday]);
print "8888: $elapsed\n";
