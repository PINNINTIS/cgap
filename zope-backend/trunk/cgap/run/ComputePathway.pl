#!/usr/local/bin/perl

#############################################################################
# ComputePathway
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use PathwayServer;
use CGAPGene;
use Scan;

##my ($base, $page, $org, $term) = @ARGV;

my $query        = new CGI;
my $base         = $query->param("BASE");
my $path_from    = $query->param("PATH_FROM");
my $path_to      = $query->param("PATH_TO");
my $path_with    = $query->param("PATH_WITH");

print "Content-type: text/plain\n\n";

Scan($base, $path_from, $path_to, $path_with);
print ComputePathway_1($base, $path_from, $path_to, $path_with);

