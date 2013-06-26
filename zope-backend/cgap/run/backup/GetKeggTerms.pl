#!/usr/local/bin/perl

#############################################################################
# GetKeggTerms.pl
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

my $query     = new CGI;
my $pattern   = $query->param("PATTERN");

print "Content-type: text/plain\n\n";

Scan($pattern);
print GetKeggTerms_1($pattern);
