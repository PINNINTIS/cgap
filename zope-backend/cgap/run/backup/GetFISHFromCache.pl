#!/usr/local/bin/perl

######################################################################
# GetFISHFromCache.pl
#
######################################################################

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use DigitalFISH;
use Scan;

my $query  = new CGI;

my $base      = $query->param("BASE");
my $cache_id  = $query->param("CACHE");

print "Content-type: image/gif\n\n";

Scan (
    $base,
    $cache_id
);

print GetFISHFromCache_1 (
    $base,
    $cache_id
);

