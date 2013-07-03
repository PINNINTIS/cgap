#!/usr/local/bin/perl

######################################################################
# SimpleTagList.pl
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
##   $lid
## ) = @ARGV;

my $query      = new CGI;
my $base      = $query->param("BASE");
my $lid       = $query->param("LID");

print "Content-type: text/plain\n\n";

Scan ($base, $lid);
print SimpleTagList_1 ($base, $lid);
