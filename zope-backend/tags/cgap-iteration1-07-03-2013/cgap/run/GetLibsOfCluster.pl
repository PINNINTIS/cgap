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
my $page     = $query->param("PAGE");
my $org      = $query->param("ORG");
my $cid      = $query->param("CID");

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $cid);
print GetLibsOfCluster_1($base, $page, $org, $cid);
