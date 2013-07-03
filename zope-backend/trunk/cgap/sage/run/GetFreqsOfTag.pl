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
my $method   = $query->param("METHOD");
my $format   = $query->param("FORMAT");
my $scope    = $query->param("CELL");
my $tag      = $query->param("TAG");
my $tiss     = $query->param("TISS");
my $hist     = $query->param("HIST");
my $knockout = $query->param("NOT");

print "Content-type: text/plain\n\n";

Scan ($org, $method, $format, $tag, $scope, $tiss, $hist, $knockout);
print GetFreqsOfTag_1 ($org, $method, $format, $tag, $scope, $tiss, $hist, $knockout);

