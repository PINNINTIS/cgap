#!/usr/local/bin/perl

######################################################################
# SelectionPullDowns.pl

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SAGE;
use Scan;

my $query       = new CGI;
my $base        = $query->param("BASE");
my $org         = $query->param("ORG");
my $what        = $query->param("WHAT");

#my (
#  $base,
#  $org,
#  $what
#) = @ARGV;

print "Content-type: text/plain\n\n";

Scan($base, $org, $what);
print SelectionPullDowns_1($base, $org, $what);

