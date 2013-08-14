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
$base      = cleanString($base);
my $page      = $query->param("PAGE");
$page      = cleanString($page);
my $accession = $query->param("ACCESSION");
$accession = cleanString($accession);
my $e_value   = $query->param("E_VALUE");
$e_value   = cleanString($e_value);
my $score     = $query->param("SCORE");
$score     = cleanString($score);
my $p_value   = $query->param("P_VALUE");
$p_value   = cleanString($p_value);
my $org       = $query->param("ORG");
$org       = cleanString($org);

print "Content-type: text/plain\n\n";

Scan($base, $page, $accession, $e_value, $score, $p_value, $org);
print SimilarityByMotif_1($base, $page, $accession, $e_value, $score, $p_value, $org);

