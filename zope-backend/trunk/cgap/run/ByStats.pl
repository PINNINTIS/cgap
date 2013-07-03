#!/usr/local/bin/perl

#############################################################################
# ByStats.pl
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

my $query                        = new CGI;
my $base                         = $query->param("BASE");
my $show_index                   = $query->param("SHOW");
my $org                          = $query->param("ORG");
my $data_src                     = $query->param("SRC");
my $scope                        = $query->param("SCOPE");
my $columns                      = $query->param("COLUMNS");
my $what                         = $query->param("WHAT");
my $selected_detail_coln         = $query->param("COLUMN");

print "Content-type: text/plain\n\n";

Scan($base, $show_index, $org, $data_src, $scope, $columns, $what,
             $selected_detail_coln);
print ByStats_1($base, $show_index, $org, $data_src, $scope, $columns, $what,
             $selected_detail_coln);


