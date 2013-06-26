#!/usr/local/bin/perl

#############################################################################
# GetBatchGenomics.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SAGE;
use Scan;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $page      = $query->param("PAGE");
my $org       = $query->param("ORG");
my $filename  = $query->param("filenameFILE");
my $order     = $query->param("ORDER");
my $method    = $query->param("METHOD");
my $email     = $query->param("EMAIL");

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $filename, $order, $method, $email);
print GetBatchGenomics_1($base, $page, $org, $filename, $order, $method, $email);

