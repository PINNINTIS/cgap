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

my $query        = new CGI;
my $base         = $query->param("BASE");
my $org          = $query->param("ORG");
my $data_source  = $query->param("SRC");
my $cidlist      = $query->param("CIDS");
my $show_index   = $query->param("SHOW");
my $col          = $query->param("COLUMN");

print "Content-type: text/plain\n\n";
## print "Content-type: image/gif\n\n";

##  print "8888: $base, $org, $data_source, $cidlist, $show_index, $col<br>";
Scan($base, $org, $data_source, $cidlist, $show_index, $col);
my @cids = split (",", $cidlist);
for( my $i=0; $i<@cids; $i++ ) {
  Scan($cids[$i]);
}
print OrderRandomGenes_1($base, $org, $data_source, $cidlist, $show_index, $col);


