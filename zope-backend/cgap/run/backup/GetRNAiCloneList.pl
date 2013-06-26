#!/usr/local/bin/perl

#############################################################################
# GetRNAiCloneList.pl
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

##my ($base, $page, $org) = @ARGV;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $page      = $query->param("PAGE");
my $org       = $query->param("ORG");

print "Content-type: text/plain\n\n";

Scan($base, $page, $org);
print GetRNAiCloneList_1($base, $page, $org);
