#!/usr/local/bin/perl

#############################################################################
# ListBioCartaPathways.pl
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
print ListBioCartaPathways_1($base);
