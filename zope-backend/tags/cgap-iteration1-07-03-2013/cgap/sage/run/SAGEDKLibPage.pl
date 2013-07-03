#!/usr/local/bin/perl

######################################################################
# SAGEDKLibPage.pl
#


use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use DKView;
use Scan;

## my (
##   $lid
##   $org
## ) = @ARGV;

my $query      = new CGI;
my $base = $query->param("BASE");
my $libname = $query->param("LIBNAME");
my $org = $query->param("ORG");

print "Content-type: text/plain\n\n";

Scan ($base, $libname, $org);
print SAGEDKLibPage_1 ($base, $libname, $org);
