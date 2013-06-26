#!/usr/local/bin/perl

#############################################################################
# GetPathwayGenes.pl
#

use strict;
use CGI;
use PathwayServer;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPGene;
use Scan;

##my ($base, $page, $org, $term) = @ARGV;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $gene      = $query->param("PATH_GENE");

print "Content-type: text/plain\n\n";

Scan($base, $gene);
print GetPathwayGenes_1($base, $gene);

