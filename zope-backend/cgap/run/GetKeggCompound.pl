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
my $cno      = $query->param("CNO");

print "Content-type: text/plain\n\n";

Scan($base, $cno);
print  GetKeggCompound_1($base, $cno);

