#!/usr/local/bin/perl

use strict;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use GXS;

my (
  $fn
) = @ARGV;

my($cache_id, $org, $page, $factor, $pvalue, 
      $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
      $setA, $setB);

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
$setB        = <INPF>; chop $setB;

close INPF;
unlink $fn;

print ComputeGXS_1($cache_id, $org, $page, $factor, $pvalue, 
      $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
      $setA, $setB);
