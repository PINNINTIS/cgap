#!/usr/local/bin/perl

######################################################################
# SAGELibPage.pl
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
##   $lid
##   $org
## ) = @ARGV;

my $query      = new CGI;
my $base = $query->param("BASE");
my $lid = $query->param("LID");
my $org = $query->param("ORG");

print "Content-type: text/plain\n\n";

print SAGELibPage_1 ($base, $lid, $org);
