#!/usr/local/bin/perl

######################################################################
# SDGEDLibrarySelect.pl
#
# 
# 

use strict;
use DBI;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SAGE;
use Scan;

my %ORG = (
  "Hs" => 1,
  "Mm" => 1
);

my $query       = new CGI;
my $base        = $query->param("BASE");
my $fn          = $query->param("TMP_FILE");
my $fn_user_a   = $query->param("USER_FILE_A");
my $fn_user_b   = $query->param("USER_FILE_B");


Scan($fn, $fn_user_b, $fn_user_a);

print "Content-type: text/plain\n\n";

my (
  $seqs,
  $sort,
  $title_a,
  $tissue_a,
  $hist_a,
  $comp_a,
  $cell_a,
  $lib_a,
  $stage_a,
  $comp_stage_a,
  $user_file_a,
  $user_data_a,
  $title_b,
  $tissue_b,
  $hist_b,
  $comp_b,
  $cell_b,
  $lib_b,
  $stage_b,
  $comp_stage_b,
  $user_file_b,
  $user_data_b,
  $org,
  $method
);

open (INPF, $fn) or die "Cannot open $fn";

$seqs          = <INPF>; chop $seqs;
$sort          = <INPF>; chop $sort;
$title_a       = <INPF>; chop $title_a;
$tissue_a      = <INPF>; chop $tissue_a;
$hist_a        = <INPF>; chop $hist_a;
$comp_a        = <INPF>; chop $comp_a;
$cell_a        = <INPF>; chop $cell_a;
$lib_a         = <INPF>; chop $lib_a;
$stage_a       = <INPF>; chop $stage_a;
$comp_stage_a  = <INPF>; chop $comp_stage_a;
$user_file_a   = <INPF>; chop $user_file_a;
$title_b       = <INPF>; chop $title_b;
$tissue_b      = <INPF>; chop $tissue_b;
$hist_b        = <INPF>; chop $hist_b;
$comp_b        = <INPF>; chop $comp_b;
$cell_b        = <INPF>; chop $cell_b;
$lib_b         = <INPF>; chop $lib_b;
$stage_b       = <INPF>; chop $stage_b;
$comp_stage_b  = <INPF>; chop $comp_stage_b;
$user_file_b   = <INPF>; chop $user_file_b;
$org           = <INPF>; chop $org;
$method        = <INPF>; chop $method;

if( not defined $ORG{$org} ) {
  print "<br><b><center>Error in input</b>!</center>";
  return "";
}

close INPF;
unlink $fn;

if ($fn_user_b) {
  my ($tag, $freq);
  my %tag2freq;
  open (INPF, $fn_user_b) or die "Cannot open $fn_user_b";
  while (<INPF>) {
    if( $_ =~ /\r/ ) {
      my @tempArray = split "\r", $_;
      for (my $i=0; $i<@tempArray; $i++) {
        ($tag, $freq) = split "\s", $tempArray[$i];
        if( defined $tag2freq{$tag} ) { 
          $tag2freq{$tag} = $tag2freq{$tag} + $freq;
        }
        else {
          $tag2freq{$tag} = $freq;
        }
      }
    }
    else {
      chop;
      ($tag, $freq) = split "\s";
      if( defined $tag2freq{$tag} ) { 
        $tag2freq{$tag} = $tag2freq{$tag} + $freq;
      }
      else {
        $tag2freq{$tag} = $freq;
      }
    }
  }
  close INPF;
  for my $tag ( keys %tag2freq ) {
    $user_data_b .= "$tag\t$tag2freq{$tag}\n";
  }
  unlink $fn_user_b;
}

if ($fn_user_a) {
  my ($tag, $freq);
  my %tag2freq;
  open (INPF, $fn_user_a) or die "Cannot open $fn_user_a";
  while (<INPF>) {
    if( $_ =~ /\r/ ) {
      my @tempArray = split "\r", $_;
      for (my $i=0; $i<@tempArray; $i++) {
        ($tag, $freq) = split "\s", $tempArray[$i];
        if( defined $tag2freq{$tag} ) {
          $tag2freq{$tag} = $tag2freq{$tag} + $freq;
        }
        else {
          $tag2freq{$tag} = $freq;
        }
      }
    }
    else {
      chop;
      ($tag, $freq) = split "\s";
      if( defined $tag2freq{$tag} ) { 
        $tag2freq{$tag} = $tag2freq{$tag} + $freq;
      }
      else {
        $tag2freq{$tag} = $freq;
      }
    }
  }
  close INPF;
  for my $tag ( keys %tag2freq ) {
    $user_data_a .= "$tag\t$tag2freq{$tag}\n";
  }
  unlink $fn_user_a;
}

Scan(
    $seqs,
  $sort,
  $title_a,
  $tissue_a,
  $hist_a,
  $comp_a,
  $cell_a,
  $lib_a,
  $stage_a,
  $comp_stage_a,
  $user_file_a,
  $user_data_a,
  $title_b,
  $tissue_b,
  $hist_b,
  $comp_b,
  $cell_b,
  $lib_b,
  $stage_b,
  $comp_stage_b,
  $user_file_b,
  $user_data_b,
  $org,
  $method
);

print SDGEDLibrarySelect_1 (
  $seqs,
  $sort,
  $title_a,
  $tissue_a,
  $hist_a,
  $comp_a,
  $cell_a,
  $lib_a,
  $stage_a,
  $comp_stage_a,
  $user_file_a,
  $user_data_a,
  $title_b,
  $tissue_b,
  $hist_b,
  $comp_b,
  $cell_b,
  $lib_b,
  $stage_b,
  $comp_stage_b,
  $user_file_b,
  $user_data_b,
  $org,
  $method
);

