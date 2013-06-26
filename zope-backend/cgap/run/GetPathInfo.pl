#!/usr/local/bin/perl

#############################################################################
# GetPathInfo.pl
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

##my ($org, $bcid, $ecno, $llno) = @ARGV;
my $query     = new CGI;
my $org       = $query->param("ORG");
my $bcid      = $query->param("BCID");
my $ecno      = $query->param("ECNO");
my $llno      = $query->param("LLNO");

print "Content-type: text/plain\n\n";

Scan($org, $bcid, $ecno, $llno);
print GetPathInfo_1($org, $bcid, $ecno, $llno);
