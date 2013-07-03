#!/usr/local/bin/perl

#############################################################################
# GetBatchDKMicrobe.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use Scan;
use DKView;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $page      = $query->param("PAGE");
my $filename  = $query->param("filenameFILE");

print "Content-type: text/plain\n\n";

Scan($base, $page, $filename);
if( $filename eq "" ) {
  print "please enter file name";
  return;
}
print GetBatchDKMicrobe_1($base, $page, $filename);

