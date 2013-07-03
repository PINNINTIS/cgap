#!/usr/local/bin/perl

#############################################################################
# GetAllSeqs.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use LICRGene;
use Scan;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $org       = $query->param("ORG");
my $licr_ids  = $query->param("LICR_ID");

print "Content-type: text/plain\n\n";

Scan($base, $org, $licr_ids);
print GetAllSeqs_1($base, $org, $licr_ids);
