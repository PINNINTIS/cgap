#!/usr/local/bin/perl

#############################################################################
# FindGenePage.pl
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

##my ($base, $org, $cid) = @ARGV;
my $query     = new CGI;
my $base      = $query->param("BASE");
my $org       = $query->param("ORG");
my $acc       = $query->param("ACC");
my $chr_to    = $query->param("CHR_TO");

print "Content-type: text/plain\n\n";

Scan($base, $org, $acc, $chr_to);
print FindExonInfo_1($base, $org, $acc, $chr_to);
