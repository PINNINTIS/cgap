#!/usr/local/bin/perl

#############################################################################
# OrderRandomGenes.pl
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

##my ($base, $page, $org, $term) = @ARGV;

my $query        = new CGI;
my $base         = $query->param("BASE");
my $org          = $query->param("ORG");
my $data_source  = $query->param("SRC");
my $acclist      = $query->param("ACCS");
my $column       = $query->param("COLUMN");
my $col          = $query->param("COLN");
my $show_index   = $query->param("SHOW");

print "Content-type: text/plain\n\n";

Scan($base, $org, $data_source, $acclist, $column, $col, $show_index);
print PivotOnColumn_1($base, $org, $data_source, $acclist, $column, $col, $show_index);


