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
my $page      = $query->param("PAGE");
my $org1      = $query->param("ORG");
my $sym1      = $query->param("SYM");
my $title1    = $query->param("TITLE");
my $go1       = $query->param("CUR");
my $pathway1  = $query->param("PATH");
my $cyt1      = $query->param("CYT");
my $tissue1   = $query->param("TISSUE");

print "Content-type: text/plain\n\n";

Scan($base, $page, $org1, $sym1, $title1,
     $go1, $pathway1, $cyt1, $tissue1);

print GetGene_1($base, $page, $org1, $sym1, $title1,
                $go1, $pathway1, $cyt1, $tissue1);

