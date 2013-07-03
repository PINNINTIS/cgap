#!/usr/local/bin/perl

#############################################################################
# GXSLibrarySelect.pl
#

use strict;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPLib;
use Blocks;
use Scan;
use CGI;
 
my $query        = new CGI;
my $base         = $query->param("BASE");
my $org          = $query->param("ORG");
my $scope        = $query->param("SCOPE");
my $min_seqs     = $query->param("SEQS");
my $sort         = $query->param("SORT");
my $title_a      = $query->param("TITLE_A");
my $title_b      = $query->param("TITLE_B");
my $type_a       = $query->param("TYPE_A");
my $type_b       = $query->param("TYPE_B");
my $tissue_a     = $query->param("TISSUE_A");
my $tissue_b     = $query->param("TISSUE_B");
my $hist_a       = $query->param("HIST_A");
my $hist_b       = $query->param("HIST_B");
my $prot_a       = $query->param("PROT_A");
my $prot_b       = $query->param("PROT_B");
my $comp_a       = $query->param("COMP_A");
my $comp_b       = $query->param("COMP_B");
 
print "Content-type: text/plain\n\n";
 


## my ($org, $scope, $min_seqs, $sort,
##     $title_a,  $title_b,
##     $type_a,   $type_b,
##     $tissue_a, $tissue_b,
##     $hist_a,   $hist_b,
##     $prot_a,   $prot_b,
##     $comp_a,   $comp_b) = @ARGV;

Scan($org, $scope, $min_seqs, $sort,
     $title_a,  $title_b,
     $type_a,   $type_b,
     $tissue_a, $tissue_b,
     $hist_a,   $hist_b,
     $prot_a,   $prot_b,
     $comp_a,   $comp_b);

print GXSLibrarySelect_1($org, $scope, $min_seqs, $sort,
                         $title_a,  $title_b,
                         $type_a,   $type_b,
                         $tissue_a, $tissue_b,
                         $hist_a,   $hist_b,
                         $prot_a,   $prot_b,
                         $comp_a,   $comp_b);

## exit GetStatus();
