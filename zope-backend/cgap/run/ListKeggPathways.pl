#!/usr/local/bin/perl

#############################################################################
# ListKeggPathways.pl
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

##my ($base) = @ARGV;
my $query     = new CGI;
my $base      = $query->param("BASE");

print "Content-type: text/plain\n\n";

Scan($base);
print ListKeggPathways_1($base);
