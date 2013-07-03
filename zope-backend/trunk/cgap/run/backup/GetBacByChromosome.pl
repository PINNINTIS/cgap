#!/usr/local/bin/perl

#############################################################################
# GetBacByChromosome.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CytSearchServer;
use Scan;

my $query     = new CGI;

my $chromosome  = $query->param("CHR");

print "Content-type: text/plain\n\n";

Scan($chromosome);
print GetBacByChromosome_1($chromosome);

exit(GetStatus());
