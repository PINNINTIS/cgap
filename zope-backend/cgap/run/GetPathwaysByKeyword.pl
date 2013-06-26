#!/usr/local/bin/perl

#############################################################################
# GetPathwaysByKeyword.pl
#

use strict;
use CGI;
use PathwayServer;

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
my $key      = $query->param("PATH_KEY");

print "Content-type: text/plain\n\n";

Scan($base, $key);
print  GetPathwaysByKeyword_1($base, $key);

