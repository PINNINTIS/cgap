#!/usr/local/bin/perl

#############################################################################
# GetGOGenes.pl
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

##my ($base, $page, $org, $goid) = @ARGV;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $page      = $query->param("PAGE");
my $org       = $query->param("ORG");
my $goid      = $query->param("GOID");

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $goid);
print GetGOGenes_1($base, $page, $org, $goid);
