#!/usr/local/bin/perl

#############################################################################
# ListXProfiledGenes.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use GLServer;
use Scan;

my $query        = new CGI;
my $base         = $query->param("BASE");
my $cache_id     = $query->param("CACHE");
my $page         = $query->param("PAGE");
my $org          = $query->param("ORG");
my $row          = $query->param("ROW");
my $what         = $query->param("WHAT");
 
print "Content-type: text/plain\n\n";


Scan($base, $cache_id, $page, $org, $row, $what);
print ListXProfiledGenes_1($base, $cache_id, $page, $org, $row, $what);

