#!/usr/local/bin/perl

#############################################################################
# GetLibrary.pl
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

##my ($base, $page, $org1, $scope1, $title1, $type1,
##    $tissue1, $hist1, $prot1, $keys1, $sort1) = @ARGV;

my $query    = new CGI;
my $base     = $query->param("BASE");
$base     = cleanString($base);
my $page     = $query->param("PAGE");
$page     = cleanString($page);
my $org      = $query->param("ORG");
$org      = cleanString($org);
my $scope    = $query->param("SCOPE");
$scope    = cleanString($scope);
my $title    = $query->param("TITLE");
$title    = cleanString($title);
my $type     = $query->param("TYPE");
$type     = cleanString($type);
my $tissue   = $query->param("TISSUE");
$tissue   = cleanString($tissue);
my $hist     = $query->param("HIST");
$hist     = cleanString($hist);
my $prot     = $query->param("PROT");
$prot     = cleanString($prot);
my $keys     = $query->param("KEYS");
$keys     = cleanString($keys);
my $sort     = $query->param("SORT");
$sort     = cleanString($sort);

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $scope, $title, $type,
            $tissue, $hist, $prot, $keys, $sort);
print GetLibrary_1($base, $page, $org, $scope, $title, $type,
                   $tissue, $hist, $prot, $keys, $sort);
