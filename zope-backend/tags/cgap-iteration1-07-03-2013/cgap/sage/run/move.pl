#!/usr/local/bin/perl

use strict;
use DBI;
use CGAPConfig;
use Cache;

my @chr_order = ("1", "2", "3", "4", "5", "6", "7", "8", "9",
     "10", "11", "12", "13", "14", "15", "16", "17", "18", "19",
     "20", "21", "22", "X", "Y");

my $path = "/cgap/webcontent/CGAP/dev/data/cache/bak/";

for (my $num = 100001; $num <= 101622; ($num = $num + 100)) {
  my $count = $num;
  for my $chr (@chr_order) {
    my $file1 = $path . "DK.$chr.$count";
    my $file2 = $path . "DK.$num.$chr";
    my $cmd = "mv $file1 $file2";
    system($cmd);
    ## print "8888 $cmd\n";
    $count++
  }
}

