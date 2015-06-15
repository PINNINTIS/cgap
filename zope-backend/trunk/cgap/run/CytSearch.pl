#!/usr/local/bin/perl

#############################################################################
# CytSearch.pl
#

use strict;
use CGI;
use String::Clean::XSS;
use CGI qw(:standard);

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CytSearchServer;
use Scan;
my $query     = new CGI;

print "Content-type: text/html\n\n";

my  $abnorm_op      = $query->param("abnorm_op");
$abnorm_op=cleanString($abnorm_op);
my $abnormality    = $query->param("abnormality");
$abnormality=cleanString($abnormality);
my $soleabnorm     = $query->param("soleabnorm");
$soleabnorm=cleanString($soleabnorm);
my $age            = $query->param("age");
$age=cleanString($age);
my $author         = $query->param("author");
$author=cleanString($author);
my $break_op       = $query->param("break_op");
$break_op=cleanString($break_op);
my $breakpoint     = $query->param("breakpoint");
$breakpoint=cleanString($breakpoint);
my $caseno         = $query->param("caseno");
$caseno=cleanString($caseno);
my $country        = $query->param("country");
$country=cleanString($country);
my $herdis         = $query->param("herdis");
$herdis=cleanString($herdis);
my $immuno         = $query->param("immuno");
$immuno=cleanString($immuno);
my $invno          = $query->param("invno");
$invno=cleanString($invno);
my $journal        = $query->param("journal");
$journal=cleanString($journal);
my $morph          = $query->param("morph");
$morph=cleanString($morph);
my $nochrom        = $query->param("nochrom");
$nochrom=cleanString($nochrom);
my $noclones       = $query->param("noclones");
$noclones=cleanString($noclones);
my $prevmorph      = $query->param("prevmorph");
$prevmorph=cleanString($prevmorph);
my $prevneo        = $query->param("prevneo");
$prevneo=cleanString($prevneo);
my $prevtop        = $query->param("prevtop");
$prevtop=cleanString($prevtop);
my $race           = $query->param("race");
$race=cleanString($race);
my $refno          = $query->param("refno");
$refno=cleanString($refno);
my $series         = $query->param("series");
$series=cleanString($series);
my $sex            = $query->param("sex");
$sex=cleanString($sex);
my $specherdis     = $query->param("specherdis");
$specherdis=cleanString($specherdis);
my $specmorph      = $query->param("specmorph");
#my $speh = clean_XSS($specmorph);
#my $speh_escape = escapeHTML($speh);
#my $OK_CHARS='-a-zA-Z0-9_.@';
#s/[^$OK_CHARS]/$speh_escape/go;
#if (defined $specmorph) {print "specmorph is before clean  ".$specmorph."\n"} {$speh  = convert_XSS($query->param("specmorph")); {print "specmorph is after".$speh."\n"}}
$specmorph = cleanString($specmorph); 
my $tissue         = $query->param("tissue");
$tissue=cleanString($tissue);
my $top            = $query->param("top");
$top=cleanString($top);
my $treat          = $query->param("treat");
$treat=cleanString($treat);
my $year           = $query->param("year");
$year=cleanString($year);
my $page           = $query->param("page");
$page=cleanString($page);
my $totalcases     = $query->param("totalcases");
$totalcases=cleanString($totalcases);
my $top_size       = $query->param("top_size");
$top_size=cleanString($top_size);
my $prevtop_size   = $query->param("prevtop_size");
$prevtop_size=cleanString($prevtop_size);
my $morph_size     = $query->param("morph_size");
$morph_size=cleanString($morph_size);
my $prevmorph_size = $query->param("prevmorph_size");
$prevmorph_size=cleanString($prevmorph_size);
my $country_size   = $query->param("country_size");
$country_size=cleanString($country_size);

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
     $totalcases,
     $top_size,
     $prevtop_size,
     $morph_size,
     $prevmorph_size,
     $country_size);

if( $page > 2 and ( $top_size > 0 or $top_size > 0 or $morph_size > 0 or $prevmorph_size > 0 or $country_size > 0 ) ) {
  print Create_new_interface_1(
                    $page,
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
                    $totalcases,
                    $top_size,
                    $prevtop_size,
                    $morph_size,
                    $prevmorph_size,
                    $country_size);

}
else {
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
}


