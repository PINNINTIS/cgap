#!/usr/local/bin/perl

#############################################################################
# ListSummarizedLibraries.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPLib;
use Scan;

##my ($base, $page, $row1, $org1, $scope1, $title1, $type1,
##    $tissue1, $hist1, $prot1, $sort1) = @ARGV;

my $query = new CGI;

my $query    = new CGI;
my $base     = $query->param("BASE");
my $page     = $query->param("PAGE");
my $row      = $query->param("ROW");
my $org      = $query->param("ORG");
my $scope    = $query->param("SCOPE");
my $title    = $query->param("TITLE");
my $type     = $query->param("TYPE");
my $tissue   = $query->param("TISSUE");
my $hist     = $query->param("HIST");
my $prot     = $query->param("PROT");
my $sort     = $query->param("SORT");

print "Content-type: text/plain\n\n";

Scan($base, $page, $row, $org, $scope, $title, $type,
     $tissue, $hist, $prot, $sort);
print ListSummarizedLibraries_1($base, $page, $row, $org, $scope, $title, $type,
                                $tissue, $hist, $prot, $sort);
