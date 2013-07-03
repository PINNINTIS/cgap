#!/usr/local/bin/perl

#############################################################################
# FormatGeneList.pl
#

use strict;
use CGI;
 
BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
 
use CGAPGene;
use Blocks;
use Scan;

my $query     = new CGI;
my $base       = $query->param("BASE");
my $page       = $query->param("PAGE");
my $org        = $query->param("ORG");
my $data       = $query->param("GENES");
 
print "Content-type: text/plain\n\n";
## print "$base, $page, $org, $data\n\n";

Scan($base, $page, $org, $data);
print FormatGeneList_1($base, $page, $org, $data);
## return FormatGeneList_1($base, $page, $org, $data);

## exit GetStatus();
