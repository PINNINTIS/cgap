#!/usr/local/bin/perl

#############################################################################
# CytSearch.pl
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

my $abnorm_op   = $query->param("abnorm_op");
my $abnormality = $query->param("abnormality");
my $soleabnorm  = $query->param("soleabnorm");
my $age         = $query->param("age");
my $author      = $query->param("author");
my $break_op    = $query->param("break_op");
my $breakpoint  = $query->param("breakpoint");
my $caseno      = $query->param("caseno");
my $country     = $query->param("country");
my $herdis      = $query->param("herdis");
my $immuno      = $query->param("immuno");
my $invno       = $query->param("invno");
my $journal     = $query->param("journal");
my $morph       = $query->param("morph");
my $nochrom     = $query->param("nochrom");
my $noclones    = $query->param("noclones");
my $prevmorph   = $query->param("prevmorph");
my $prevneo     = $query->param("prevneo");
my $prevtop     = $query->param("prevtop");
my $race        = $query->param("race");
my $refno       = $query->param("refno");
my $series      = $query->param("series");
my $sex         = $query->param("sex");
my $specherdis  = $query->param("specherdis");
my $specmorph   = $query->param("specmorph");
my $tissue      = $query->param("tissue");
my $top         = $query->param("top");
my $treat       = $query->param("treat");
my $year        = $query->param("year");
my $page        = $query->param("page");
my $totalcases  = $query->param("totalcases");

print "Content-type: text/plain\n\n";

Scan($page,        
     $abnorm_op,   
     $abnormality, 
     $soleabnorm,  
     $age,         
     $author,      
     $break_op,    
     $breakpoint,  
     $caseno,      
     $country,     
     $herdis,      
     $immuno,      
     $invno,       
     $journal,     
     $morph,       
     $nochrom,     
     $noclones,    
     $prevmorph,   
     $prevneo,     
     $prevtop,     
     $race,        
     $refno,       
     $series,      
     $sex,         
     $specherdis,  
     $specmorph,   
     $tissue,      
     $top,         
     $treat,       
     $year,        
     $totalcases);

print CytSearch_1($page,        
                  $abnorm_op,   
                  $abnormality, 
                  $soleabnorm,  
                  $age,         
                  $author,      
                  $break_op,    
                  $breakpoint,  
                  $caseno,      
                  $country,     
                  $herdis,      
                  $immuno,      
                  $invno,       
                  $journal,     
                  $morph,       
                  $nochrom,     
                  $noclones,    
                  $prevmorph,   
                  $prevneo,     
                  $prevtop,     
                  $race,        
                  $refno,       
                  $series,      
                  $sex,         
                  $specherdis,  
                  $specmorph,   
                  $tissue,      
                  $top,         
                  $treat,       
                  $year,        
                  $totalcases);

## exit(GetStatus());
