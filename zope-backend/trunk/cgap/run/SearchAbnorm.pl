#!/usr/local/bin/perl

#############################################################################
# SearchAbnorm.pl
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

my $base      = $query->param("BASE");
my $breakpoint  = $query->param("breakpoint");
my $tissue  = $query->param("tissue");
my $neopl  = $query->param("neopl");
my $type  = $query->param("type");
my $gene  = $query->param("gene");
my $structural  = $query->param("structural");
my $numerical  = $query->param("numerical");
my $chromosome  = $query->param("chromosome");
my $num_type  = $query->param("num_type");
my $page  = $query->param("page");
my $top_size    = $query->param("top_size");
my $morph_size  = $query->param("morph_size");
my $gene_size  = $query->param("gene_size");

print "Content-type: text/plain\n\n";

Scan($base, 
     $breakpoint, 
     $type, 
     $tissue, 
     $neopl, 
     $gene, 
     $structural, 
     $numerical, 
     $chromosome, 
     $num_type, 
     $page,
     $top_size,
     $morph_size,
     $gene_size);

if( $page > 2 and ($top_size > 0 or $morph_size > 0 and $gene_size > 0) ) {
  print Build_new_RCA_form_1($base, 
                             $breakpoint, 
                             $type, 
                             $tissue, 
                             $neopl, 
                             $gene, 
                             $structural, 
                             $numerical, 
                             $chromosome, 
                             $num_type, 
                             $page, 
                             $top_size, 
                             $morph_size, 
                             $gene_size);
}
else {
  print SearchAbnorm_1($base, 
                       $breakpoint, 
                       $type, 
                       $tissue, 
                       $neopl, 
                       $gene, 
                       $structural, 
                       $numerical, 
                       $chromosome, 
                       $num_type, 
                       $page);
}
## exit(GetStatus());
