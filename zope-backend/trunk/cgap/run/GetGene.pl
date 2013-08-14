#!/usr/local/bin/perl

#############################################################################
# GetGene.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPGene;
use Scan;

##my ($base, $page, $org1, $sym1, $title1, $go1, $pathway1, $cyt1, $tissue1) = @ARGV;

my $query     = new CGI;
my $base      = $query->param("BASE");
$base      = cleanString($base);            
my $page      = $query->param("PAGE");
$page      = cleanString($page);      
my $org1      = $query->param("ORG");
$org1      = cleanString($org1);
my $sym1      = $query->param("SYM");
$sym1      = cleanString($sym1);
my $title1    = $query->param("TITLE");
$title1    = cleanString($title1);
my $go1       = $query->param("CUR");
$go1       = cleanString($go1);
my $pathway1  = $query->param("PATH");
$pathway1  = cleanString($pathway1);
my $cyt1      = $query->param("CYT");
$cyt1      = cleanString($cyt1);
my $tissue1   = $query->param("TISSUE");
$tissue1   = cleanString($tissue1);

print "Content-type: text/plain\n\n";

Scan($base, $page, $org1, $sym1, $title1,
     $go1, $pathway1, $cyt1, $tissue1);

print GetGene_1($base, $page, $org1, $sym1, $title1,
                $go1, $pathway1, $cyt1, $tissue1);

