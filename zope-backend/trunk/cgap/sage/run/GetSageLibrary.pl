#!/usr/local/bin/perl

#############################################################################
# GetSageLibrary.pl
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

##my ($base, $page, $title1, $type1,
##    $tissue1, $hist1, $keys1, $sort1) = @ARGV;

my $query    = new CGI;
my $base     = $query->param("BASE");
$base     = cleanString($base);
my $page     = $query->param("PAGE");
$page     = cleanString($page);
my $title    = $query->param("TITLE");
$title    = cleanString($title);
my $type     = $query->param("TYPE");
$type     = cleanString($type);
my $tissue   = $query->param("TISSUE");
$tissue   = cleanString($tissue);
my $hist     = $query->param("HIST");
$hist     = cleanString($hist);
my $keys     = $query->param("KEYS");
$keys     = cleanString($keys);
my $sort     = $query->param("SORT");
$sort     = cleanString($sort);
my $org      = $query->param("ORG");
$org      = cleanString($org);
my $method   = $query->param("METHOD");
$method   = cleanString($method);
my $stage    = $query->param("STAGE");
$stage    = cleanString($stage);

print "Content-type: text/plain\n\n";

Scan($base, $page, $title, $type,
     $tissue, $hist, $keys, $sort, $org, $method, $stage);

print GetSageLibrary_1($base, $page, $title, $type,
                       $tissue, $hist, $keys, $sort, $org, $method, $stage);
