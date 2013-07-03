#!/usr/local/bin/perl

######################################################################
# AnatomicFreqs.pl
#


use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SAGE;

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

print AnatomicFreqs_1 ($base, $tag, $scope, $org, $method);
