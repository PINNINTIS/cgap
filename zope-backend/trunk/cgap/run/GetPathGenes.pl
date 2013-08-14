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
$base      = cleanString($base);
my $page      = $query->param("PAGE");
$page      = cleanString($page);
my $org       = $query->param("ORG");
$org       = cleanString($org);
my $path      = $query->param("PATH");
$path      = cleanString($path);

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $path);
print GetPathGenes_1($base, $page, $org, $path);
