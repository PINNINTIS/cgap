#!/usr/local/bin/perl

#############################################################################
# GetmRNA.pl
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
my $licr_id   = $query->param("LICR_ID");
my $contigs   = $query->param("CONTIG");

print "Content-type: text/plain\n\n";

Scan($base, $org, $licr_id, $contigs);
print GetmRNA_1($base, $org, $licr_id, $contigs);
