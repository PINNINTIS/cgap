#!/usr/local/bin/perl

######################################################################
# GetUserResults.pl
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
use Scan;

my $query  = new CGI;

my $base      = $query->param("BASE");
my $cache_id  = $query->param("CACHE");
my $time      = $query->param("TIME");
my $email     = $query->param("EMAIL");

print "Content-type: text/plain\n\n";
## print "Content-type: application/zip\n\n";
## print "Content-type: application/download\n\n";

Scan (
    $base,
    $cache_id,
    $time,
    $email
);

print GetUserResults_1 (
    $base,
    $cache_id,
    $time,
    $email
);

