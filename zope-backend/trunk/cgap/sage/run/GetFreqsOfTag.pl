#!/usr/local/bin/perl

######################################################################
# GetFreqsOfTag.pl
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
##   $format,
##   $tag,
##   $scope,
##   $tiss,
##   $hist,
##   $knockout
## ) = @ARGV;

my $query    = new CGI;
my $org      = $query->param("ORG");
$org      = cleanString($org);
my $method   = $query->param("METHOD");
$method   = cleanString($method);
my $format   = $query->param("FORMAT");
$format   = cleanString($format);
my $scope    = $query->param("CELL");
$scope    = cleanString($scope);
my $tag      = $query->param("TAG");
$tag      = cleanString($tag);
my $tiss     = $query->param("TISS");
$tiss     = cleanString($tiss);
my $hist     = $query->param("HIST");
$hist     = cleanString($hist);
my $knockout = $query->param("NOT");
$knockout = cleanString($knockout);

print "Content-type: text/plain\n\n";

Scan ($org, $method, $format, $tag, $scope, $tiss, $hist, $knockout);
print GetFreqsOfTag_1 ($org, $method, $format, $tag, $scope, $tiss, $hist, $knockout);

