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

use SAGE;

my $query  = new CGI;

my $base      = $query->param("BASE");
my $cache_id  = $query->param("CACHE");

print "Content-type: text/plain\n\n";
## print "Content-type: application/zip\n\n";
## print "Content-type: application/download\n\n";

print GetGenimicsCache_1 (
    $base,
    $cache_id
);

