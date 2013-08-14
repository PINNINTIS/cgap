#!/usr/local/bin/perl

#############################################################################
# GetTransfrag.pl
#
 
use strict;
use CGI;
 
BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
use SAGE;
use Scan;
 
my $query                = new CGI;
my $base                 = $query->param("BASE");
$base                 =  cleanString($base);
my $page                 = $query->param("PAGE");
$page                 =  cleanString($page);
my $org                  = $query->param("ORG");
$org                  =  cleanString($org);
my $chr                  = $query->param("CHR");
$chr                  =  cleanString($chr);
my $start_pos            = $query->param("CHR_START");
$start_pos            =  cleanString($start_pos);
my $end_pos              = $query->param("CHR_END");
$end_pos              = cleanString($end_pos); 
 
print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $chr, $start_pos, $end_pos); 
print GetTransfrag_1($base, $page, $org, $chr, $start_pos, $end_pos); 
