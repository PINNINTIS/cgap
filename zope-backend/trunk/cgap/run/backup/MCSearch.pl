#!/usr/local/bin/perl

#############################################################################
# MCSearch.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CytSearchServer;
use Scan;

my $query     = new CGI;

my $base        = $query->param("BASE");
my $op          = $query->param("op");
my $abnorm_op   = $query->param("abnorm_op");
my $abnormality = $query->param("abnormality");
my $author      = $query->param("author");
my $break_op    = $query->param("break_op");
my $breakpoint  = $query->param("breakpoint");
my $gene_op     = $query->param("gene_op");
my $gene        = $query->param("gene");
my $immuno      = $query->param("immuno");
my $invno       = $query->param("invno");
my $journal     = $query->param("journal");
my $morph       = $query->param("morph");
my $refno       = $query->param("refno");
my $top         = $query->param("top");
my $year        = $query->param("year");
my $page        = $query->param("page");

print "Content-type: text/plain\n\n";

Scan ($base,
      $page,
      $abnorm_op,
      $abnormality,
      $author,
      $break_op,
      $breakpoint,
      $gene_op,
      $gene,
      $immuno,
      $invno,
      $journal,
      $morph,
      $op,
      $refno,
      $top,
      $year);

print MCSearch_1($base,
                $page,
                $abnorm_op,
                $abnormality,
                $author,
                $break_op,
                $breakpoint,
                $gene_op,
                $gene,
                $immuno,
                $invno,
                $journal,
                $morph,
                $op,
                $refno,
                $top,
                $year);

exit(GetStatus());
