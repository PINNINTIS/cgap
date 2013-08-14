#!/usr/local/bin/perl

######################################################################
# GetSDGEDInfo.pl
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
use CGI;
 
my $query     = new CGI;
 
my $base      = cleanString($query->param("base"));
my $fn        = cleanString($query->param("FILE"));
 
print "Content-type: text/plain\n\n";

Scan($fn);
 
my (
      $base, $cache_id, $org, $page, $factor, $pvalue, $chr, $user_email,
      $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
      $setA, $setB, $method, $sdged_cache_id, $email);
 
open (INPF, $fn) or die "Cannot open $fn";
 
$base              = <INPF>; chop $base;
$cache_id          = <INPF>; chop $cache_id;
$org               = <INPF>; chop $org;
$page              = <INPF>; chop $page;
$factor            = <INPF>; chop $factor;
$pvalue            = <INPF>; chop $pvalue;
$chr               = <INPF>; chop $chr;
$user_email        = <INPF>; chop $user_email;
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
 
ComputeSDGED_1 
      ($base, $cache_id, $org, $page, $factor, $pvalue, $chr, $user_email,
       $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
       $setA, $setB, $method, $sdged_cache_id, $email);
