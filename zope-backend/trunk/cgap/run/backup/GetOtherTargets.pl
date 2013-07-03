#!/usr/local/bin/perl

#############################################################################
# GetOtherTargets.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use RNAi;
use Scan;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $org       = $query->param("ORG");

##my ($base, $org) = @ARGV;

print "Content-type: text/plain\n\n";

Scan($base, $org);
print GetOtherTargets_1($base, $org);
