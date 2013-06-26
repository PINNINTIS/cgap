#!/usr/local/bin/perl

#############################################################################
# FindNeighbors.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use MicroArrayServer;
use CGAPGene;
use Scan;


my $query        = new CGI;
my $base         = $query->param("BASE");
my $org          = $query->param("ORG");
my $data_source  = $query->param("SRC");
my $accession    = $query->param("ACCESSION");
my $show_index   = $query->param("SHOW");
my $col          = $query->param("COLUMN");

print "Content-type: text/plain\n\n";

Scan($base, $org, $data_source, $accession, $show_index, $col);
print FindNeighbors_1($base, $org, $data_source, $accession, $show_index, $col);


