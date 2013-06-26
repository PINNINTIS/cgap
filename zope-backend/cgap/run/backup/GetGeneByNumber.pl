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
my $page      = $query->param("PAGE");
my $org       = $query->param("ORG");
my $term      = $query->param("TERM");

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $term);
print GetGeneByNumber_1($base, $page, $org, $term);

