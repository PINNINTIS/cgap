#!/usr/local/bin/perl

#############################################################################
# GetAntibodyList.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use Antibody;
use Scan;

my $query     = new CGI;
my $base      = $query->param("BASE");

print "Content-type: text/plain\n\n";

Scan($base);
print GetAntibodyList_1($base);
