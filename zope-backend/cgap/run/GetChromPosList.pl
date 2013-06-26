#!/usr/local/bin/perl

#############################################################################
# GetChromPosList.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPGene;
use Scan;

##my ($page, $org, $cids) = @ARGV;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $page      = $query->param("PAGE");
my $org       = $query->param("ORG");
my $cids      = $query->param("CIDS");
my $gene_ids  = $query->param("GENE_IDS");
my $syms      = $query->param("GENE_SYMS");

print "Content-type: text/plain\n\n";

Scan($page, $org, $cids, $gene_ids, $syms);
print GetChromPosList_1($page, $org, $cids, $gene_ids, $syms);
