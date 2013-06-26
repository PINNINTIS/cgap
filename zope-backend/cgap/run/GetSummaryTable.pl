#!/usr/local/bin/perl

#############################################################################
# GetSummaryTable.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use GLServer;
use Scan;

my $query        = new CGI;
my $base         = $query->param("BASE");
my $org1         = $query->param("ORG");
my $scope1       = $query->param("SCOPE");
my $title1       = $query->param("TITLE");
my $type1        = $query->param("TYPE");
my $tissue1      = $query->param("TISSUE");
my $hist1        = $query->param("HIST");
my $prot1        = $query->param("PROT");
my $sort1        = $query->param("SORT");
my $partition    = $query->param("PARTITION");
 
print "Content-type: text/plain\n\n";


Scan($base, $org1, $scope1, $title1, $type1, $tissue1, $hist1, $prot1,
      $sort1, $partition);
print GetSummaryTable_1($base, $org1, $scope1, $title1, $type1, $tissue1, $hist1, $prot1, $sort1, $partition);
