#!/usr/local/bin/perl

######################################################################
# BrainAnatomicFreqs.pl
#


use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SAGE;
use Scan;

## my (
##   $base,
##   $tag,
##   $scope
## ) = @ARGV;

my $query  = new CGI;
my $base   = $query->param("BASE");
my $tag    = $query->param("TAG");
my $scope  = $query->param("CELL");
my $org    = $query->param("ORG");
my $method = $query->param("METHOD");

print "Content-type: text/plain\n\n";

Scan ($base, $tag, $scope, $org, $method);
print BrainAnatomicFreqs_1 ($base, $tag, $scope, $org, $method);
