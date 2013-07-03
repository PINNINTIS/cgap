#!/usr/local/bin/perl

######################################################################
# ComputeSDGED.pl
#
# 
# 


BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use strict;
use FileHandle;
use CGAPConfig;
use Scan;
use GXS;

my (
  $fn
) = @ARGV;
 
Scan($fn);
 
my (
      $cache_id, $org, $page, $factor, $pvalue, $chr,
      $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
      $setA, $setB, $method, $sdged_cache_id, $email);
);
 
print "Content-type: text/plain\n\n";

print "8888" . $fn;
exir();
open (INPF, $fn) or die "Cannot open $fn";
 
$cache_id          = <INPF>; chop $cache_id;
$org               = <INPF>; chop $org;
$page              = <INPF>; chop $page;
$factor            = <INPF>; chop $factor;
$pvalue            = <INPF>; chop $pvalue;
$chr               = <INPF>; chop $chr;
$total_seqsA       = <INPF>; chop $total_seqsA;
$total_seqsB       = <INPF>; chop $total_seqsB;
$total_libsA       = <INPF>; chop $total_libsA;
$total_libsB       = <INPF>; chop $total_libsB;
$setA              = <INPF>; chop $setA;
$setB              = <INPF>; chop $setB;
$method            = <INPF>; chop $method;
$sdged_cache_id    = <INPF>; chop $sdged_cache_id;
$email             = <INPF>; chop $email;
 
close INPF;
unlink $fn;
 

print "$cache_id, $org, $page, $factor, $pvalue, $chr,
       $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
       $setA, $setB, $method, $sdged_cache_id, $email";
print ComputeSDGED_1 
      ($cache_id, $org, $page, $factor, $pvalue, $chr,
       $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
       $setA, $setB, $method, $sdged_cache_id, $email);
