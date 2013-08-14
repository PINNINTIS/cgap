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
use Scan;

## my (
##   $base,
##   $tag,
##   $scope
## ) = @ARGV;

my $query  = new CGI;
my $base   = $query->param("BASE");
$base   = cleanString($base);
my $tag    = $query->param("TAG");
$tag    = cleanString($tag);
my $scope  = $query->param("CELL");
$scope  = cleanString($scope);
my $org    = $query->param("ORG");
$org    = cleanString($org);
my $method = $query->param("METHOD");
$method = cleanString($method);

print "Content-type: text/plain\n\n";

Scan ($base, $tag, $scope, $org, $method);
print AnatomicFreqs_1 ($base, $tag, $scope, $org, $method);
