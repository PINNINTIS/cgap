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
$base        = cleanString($base);
my $op          = $query->param("op");
$op          = cleanString($op);
my $abnorm_op   = $query->param("abnorm_op");
$abnorm_op   = cleanString($abnorm_op);
my $abnormality = $query->param("abnormality");
$abnormality = cleanString($abnormality);
my $author      = $query->param("author");
$author      = cleanString($author);
my $break_op    = $query->param("break_op");
$break_op    = cleanString($break_op);
my $breakpoint  = $query->param("breakpoint");
$breakpoint  = cleanString($breakpoint);
my $gene_op     = $query->param("gene_op");
$gene_op     = cleanString($gene_op);
my $gene        = $query->param("gene");
$gene        = cleanString($gene);
my $immuno      = $query->param("immuno");
$immuno      = cleanString($immuno);
my $invno       = $query->param("invno");
$invno       = cleanString($invno);
my $journal     = $query->param("journal");
$journal     = cleanString($journal);
my $morph       = $query->param("morph");
$morph       = cleanString($morph);
my $refno       = $query->param("refno");
$refno       = cleanString($refno);
my $top         = $query->param("top");
$top         = cleanString($top);
my $year        = $query->param("year");
$year        = cleanString($year);
my $page        = $query->param("page");
$page        = cleanString($page);
my $top_size    = $query->param("top_size");
$top_size    = cleanString($top_size);
my $morph_size  = $query->param("morph_size");
$morph_size  = cleanString($morph_size);
my $gene_size   = $query->param("gene_size");
$gene_size   = cleanString($gene_size);

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

if( $page > 2 and ($top_size > 0 or $morph_size > 0 or $gene_size > 0) ) {
  print Create_new_interface_MSearch_1(
                  $base,
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
                  $year,
                  $top_size,
                  $morph_size,
                  $gene_size);
 
}
else {
  print MCSearch_1(
                  $base,
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
}

## exit(GetStatus());
