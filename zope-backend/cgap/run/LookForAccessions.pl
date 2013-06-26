#!/usr/local/bin/perl

#############################################################################
# LookForAccessions.pl
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
my $cid          = $query->param("CID");

print "Content-type: text/plain\n\n";

Scan($base, $org, $cid);
print LookForAccessions_1($base, $org, $cid);


