#!/usr/local/bin/perl

#############################################################################
# ListSummarizedGenes.pl
#

use strict;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use GLServer;
use Scan;
use CGI;
 
my $query        = new CGI;
my $base         = $query->param("BASE");
my $row          = $query->param("ROW");
my $what         = $query->param("WHAT");
my $org          = $query->param("ORG");
my $scope        = $query->param("SCOPE");
my $title        = $query->param("TITLE");
my $type         = $query->param("TYPE");
my $tissue       = $query->param("TISSUE");
my $hist         = $query->param("HIST");
my $prot         = $query->param("PROT");
my $sort         = $query->param("SORT");
my $partition    = $query->param("PARTITION");
 
print "Content-type: text/plain\n\n";
 
Scan($row, $what, $org, $scope, $title, $type,
     $tissue, $hist, $prot, $sort, $partition);

print ListSummarizedGenes_1( $row, $what, $org, $scope, $title, $type, 
                             $tissue, $hist, $prot, $sort, $partition );

