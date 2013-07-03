#!/usr/local/bin/perl

#############################################################################
# FindGenePage.pl
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

##my ($base, $org, $cid) = @ARGV;
my $query     = new CGI;
my $base      = $query->param("BASE");
my $org       = $query->param("ORG");
my $bcid      = $query->param("BCID");
my $ecno      = $query->param("ECNO");
my $llno      = $query->param("LLNO");
my $cid       = $query->param("CID");

print "Content-type: text/plain\n\n";

Scan($base, $org, $bcid, $ecno, $llno, $cid);
print FindGenePage_1($base, $org, $bcid, $ecno, $llno, $cid);
