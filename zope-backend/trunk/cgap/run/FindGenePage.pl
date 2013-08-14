#!/usr/local/bin/perl

#############################################################################
# FindGenePage.pl
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

##my ($base, $org, $cid) = @ARGV;
my $query     = new CGI;
my $base      = $query->param("BASE");
$base      = cleanString($base);      
my $org       = $query->param("ORG");
$org       = cleanString($org);       
my $bcid      = $query->param("BCID");
$bcid      = cleanString($bcid);      
my $ecno      = $query->param("ECNO");
$ecno      = cleanString($ecno);      
my $llno      = $query->param("LLNO");
$llno      = cleanString($llno);
my $cid       = $query->param("CID");
$cid       = cleanString($cid);       

print "Content-type: text/plain\n\n";

Scan($base, $org, $bcid, $ecno, $llno, $cid);
print FindGenePage_1($base, $org, $bcid, $ecno, $llno, $cid);
