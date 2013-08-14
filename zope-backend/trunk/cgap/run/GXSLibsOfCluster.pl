#!/usr/local/bin/perl

#############################################################################
# GXSLibsOfCluster.pl
#

use strict;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPLib;
use Blocks;
use Scan;

my ($base, $org, $cid, $lib_set) = @ARGV;

$base = cleanString($base);
$org = cleanString($org);
$cid = cleanString($cid);
$lib_set = cleanString($lib_set);
Scan($base, $org, $cid, $lib_set);
print GXSLibsOfCluster_1($base, $org, $cid, $lib_set);

exit GetStatus();
