#!/usr/local/bin/perl

######################################################################
# GenomeExpression.pl
#
######################################################################

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use GenomeExpression;
use Scan;

##  my (
##    $base,
##    $org,
##    $chr,
##    $start,
##    $end,
##    $tissue,
##    $data_src,
##    $filter,
##    $efold,
##    $zoomfold,
##    $zoomlevel,
##    $zoompoint
##  ) = @_;

my $query  = new CGI;

my $base      = $query->param("BASE");
my $org       = $query->param("ORG");
my $chr       = $query->param("CHR");
my $start     = $query->param("START");
my $end       = $query->param("END");
my $tissue    = $query->param("TISSUE");
my $data_src  = $query->param("SRC");
my $filter    = $query->param("FILTER");
my $efold     = $query->param("EFOLD");
my $zoomfold  = $query->param("ZFOLD");
my $zoomlevel = $query->param("ZLEVEL");
my $zoompoint = $query->param("ZPOINT");

print "Content-type: text/plain\n\n";

Scan (
    $base,
    $org,
    $chr,
    $start,
    $end,
    $tissue,
    $data_src,
    $filter,
    $efold,
    $zoomfold,
    $zoomlevel,
    $zoompoint
  );
print  GenomeExpression_1 (
    $base,
    $org,
    $chr,
    $start,
    $end,
    $tissue,
    $data_src,
    $filter,
    $efold,
    $zoomfold,
    $zoomlevel,
    $zoompoint
  );
