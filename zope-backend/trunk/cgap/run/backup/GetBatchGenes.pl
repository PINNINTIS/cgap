#!/usr/local/bin/perl

#############################################################################
# GetBatchGenes.pl
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
my $base      = $query->param("BASE");
my $page      = $query->param("PAGE");
my $org       = $query->param("ORG");
my $filename  = $query->param("filenameFILE");
my $filedata  = $query->param("FILEDATA");

print "Content-type: text/plain\n\n";

if($filename) {
  Scan($base, $page, $org, $filename);
  print GetBatchGenes_1($base, $page, $org, $filename);
}
else {
  Scan($base, $page, $org, $filedata);
  print GetBatchGenes_1($base, $page, $org, $filedata);
}


