#!/usr/local/bin/perl

#############################################################################
# FindLICRGenePage.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use TESTSVG;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $org       = $query->param("ORG");
my $cid       = $query->param("CID");
my $licr_ids  = $query->param("LICR_ID");

print "Content-type: text/plain\n\n";

## print "AAAAAAAAAAAAAA";
print GetmRNA_1($base, $org, $cid, $licr_ids);
