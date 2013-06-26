#!/usr/local/bin/perl

#############################################################################
# GetChromPosList.pl
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

##my ($page, $org, $cids) = @ARGV;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $page      = $query->param("PAGE");
my $org       = $query->param("ORG");
my $cids      = $query->param("CIDS");

print "Content-type: text/plain\n\n";

Scan($page, $org, $cids);
print GetChromPosList_1($page, $org, $cids);
