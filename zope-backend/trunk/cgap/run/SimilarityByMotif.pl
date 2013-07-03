#!/usr/local/bin/perl

#############################################################################
# SimilarityByMotif.pl
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

##my ($base, $page, $accession, $e_value, $score, $p_value, $org) = @ARGV;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $page      = $query->param("PAGE");
my $accession = $query->param("ACCESSION");
my $e_value   = $query->param("E_VALUE");
my $score     = $query->param("SCORE");
my $p_value   = $query->param("P_VALUE");
my $org       = $query->param("ORG");

print "Content-type: text/plain\n\n";

Scan($base, $page, $accession, $e_value, $score, $p_value, $org);
print SimilarityByMotif_1($base, $page, $accession, $e_value, $score, $p_value, $org);

