#!/usr/local/bin/perl

#############################################################################
# GetPathGenes.pl
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

##my ($base, $page, $org, $path) = @ARGV;
my $query     = new CGI;
my $base      = $query->param("BASE");
my $page      = $query->param("PAGE");
my $org       = $query->param("ORG");
my $path      = $query->param("PATH");

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $path);
print GetPathGenes_1($base, $page, $org, $path);
