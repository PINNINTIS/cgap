#!/usr/local/bin/perl

use strict;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use GXS;
use Scan;

my (
  $fn
) = @ARGV;

my($cache_id, $org, $page, $factor, $pvalue, 
      $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
      $setA, $setB, $chr);

open (INPF, $fn) or die "Cannot open $fn";

$cache_id    = <INPF>; chop $cache_id;
$org         = <INPF>; chop $org;
$page        = <INPF>; chop $page;
$factor      = <INPF>; chop $factor;
$pvalue      = <INPF>; chop $pvalue;
$total_seqsA = <INPF>; chop $total_seqsA;
$total_seqsB = <INPF>; chop $total_seqsB;
$total_libsA = <INPF>; chop $total_libsA;
$total_libsB = <INPF>; chop $total_libsB;
$setA        = <INPF>; chop $setA;
$chr         = <INPF>; chop $chr;

close INPF;
unlink $fn;

Scan($cache_id, $org, $page, $factor, $pvalue, 
     $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
     $setA, $setB, $chr);
print ComputeSDGED_1($cache_id, $org, $page, $factor, $pvalue, 
      $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
      $setA, $setB, $chr);
