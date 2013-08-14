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
my $base         = cleanString($query->param("BASE"));
my $org          = cleanString($query->param("ORG"));
my $scope        = cleanString($query->param("SCOPE"));
my $min_seqs     = cleanString($query->param("SEQS"));
my $sort         = cleanString($query->param("SORT"));
my $title_a      = cleanString($query->param("TITLE_A"));
my $title_b      = cleanString($query->param("TITLE_B"));
my $type_a       = cleanString($query->param("TYPE_A"));
my $type_b       = cleanString($query->param("TYPE_B"));
my $tissue_a     = cleanString($query->param("TISSUE_A"));
my $tissue_b     = cleanString($query->param("TISSUE_B"));
my $hist_a       = cleanString($query->param("HIST_A"));
my $hist_b       = cleanString($query->param("HIST_B"));
my $prot_a       = cleanString($query->param("PROT_A"));
my $prot_b       = cleanString($query->param("PROT_B"));
my $comp_a       = cleanString($query->param("COMP_A"));
my $comp_b       = cleanString($query->param("COMP_B"));
 
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
