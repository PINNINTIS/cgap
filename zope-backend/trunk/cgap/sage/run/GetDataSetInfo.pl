#!/usr/local/bin/perl

######################################################################
# GetDataSetInfo.pl
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
##   $rank
## ) = @ARGV;

my $query       = new CGI;
my $rank     = $query->param("RANK");
$rank     = cleanString($rank);
my $org      = $query->param("ORG");
$org      = cleanString($org);
my $method   = $query->param("METHOD");
$method   = cleanString($method);

print "Content-type: text/plain\n\n";

Scan ($rank, $org, $method);
print GetDataSetInfo_1 ($rank, $org, $method);

