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
my $page     = $query->param("PAGE");
my $title    = $query->param("TITLE");
my $type     = $query->param("TYPE");
my $tissue   = $query->param("TISSUE");
my $hist     = $query->param("HIST");
my $keys     = $query->param("KEYS");
my $sort     = $query->param("SORT");
my $org      = $query->param("ORG");
my $method   = $query->param("METHOD");
my $stage    = $query->param("STAGE");

print "Content-type: text/plain\n\n";

Scan($base, $page, $title, $type,
     $tissue, $hist, $keys, $sort, $org, $method, $stage);

print GetSageLibrary_1($base, $page, $title, $type,
                       $tissue, $hist, $keys, $sort, $org, $method, $stage);
