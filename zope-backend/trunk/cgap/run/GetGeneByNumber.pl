#!/usr/local/bin/perl

#############################################################################
# GetGeneByNumber.pl
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

##my ($base, $page, $org, $term) = @ARGV;

my $query     = new CGI;
my $base      = $query->param("BASE");
$base      = cleanString($base);
my $page      = $query->param("PAGE");
$page      = cleanString($page);
my $org       = $query->param("ORG");
$org       = cleanString($org);
my $term      = $query->param("TERM");
$term      = cleanString($term);

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $term);
print GetGeneByNumber_1($base, $page, $org, $term);

