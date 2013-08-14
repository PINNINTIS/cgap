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
use CGI;
 
my $query     = new CGI;
 
my $base      = cleanString($query->param("base"));
my $fn        = cleanString($query->param("FILE"));
 
print "Content-type: text/plain\n\n";

my ( $cache_id, $org, $page, $factor, $pvalue, $chr,
     $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
     $setA, $setB );

my $file = CACHE_ROOT . GXS_CACHE_PREFIX . ".txt";
 
if (not (-e $file)) {
  print "<center><b>Error: Cache flag file is missing, please contact help desk. Sorry for inconvenient</b></center>";
  exit();
}
 
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
  
Scan ( $cache_id, $org, $page, $factor, $pvalue, $chr,
       $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
       $setA, $setB
     );


close INPF;
## print "Content-type: text/plain\n\n";
print ComputeGXS_1 
           ($cache_id, $org, $page, $factor, $pvalue, $chr,
            $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
            $setA, $setB);
