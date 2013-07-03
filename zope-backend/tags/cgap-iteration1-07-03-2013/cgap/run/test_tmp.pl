#!/usr/local/bin/perl

#############################################################################
# MCSearch_for_Gene_info.pl
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

my ($base,
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

my $query     = new CGI;

$base        = $query->param("BASE");
$op          = $query->param("op");
$gene        = $query->param("gene");
$page        = $query->param("page");

print "Content-type: text/plain\n\n/;

$abnorm_op = "a";
$abnormality = "";
$author = "";
$break_op = "a";
$breakpoint = "";
$gene_op = "a";
$immuno = "";
$invno = "";
$journal = "";
$morph = "";
$refno = "";
$top = "";
$year = "";

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

print MCSearch_for_Gene_info_1(
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

