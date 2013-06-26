#!/usr/local/bin/perl

#############################################################################
# FormatLibraryList.pl
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

my ($base, $page, $org, $cmd, $header, $lib_set) = @ARGV;

Scan($base, $page, $org, $cmd, $header, $lib_set);
print FormatLibraryList_1($base, $page, $org, $cmd, $header, $lib_set);

exit GetStatus();
