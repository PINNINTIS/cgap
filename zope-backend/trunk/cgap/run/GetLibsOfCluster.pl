#!/usr/local/bin/perl

#############################################################################
# GetLibsOfCluster.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPLib;
use Scan;

##my ($base, $page, $org, $cid) = @ARGV;

my $query = new CGI;

my $query    = new CGI;
my $base     = $query->param("BASE");
$base     = cleanString($base);
my $page     = $query->param("PAGE");
$page     = cleanString($page);
my $org      = $query->param("ORG");
$org      = cleanString($org);
my $cid      = $query->param("CID");
$cid      = cleanString($cid);

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $cid);
print GetLibsOfCluster_1($base, $page, $org, $cid);
