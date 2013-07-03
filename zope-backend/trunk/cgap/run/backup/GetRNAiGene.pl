#!/usr/local/bin/perl

#############################################################################
# GetRNAiGene.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use RNAi;
use Scan;

##my ($base, $page, $org, $sym, $key, $acc, $ugid) = @ARGV;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $page      = $query->param("PAGE");
my $org       = $query->param("ORG");
my $sym       = $query->param("SYM");
my $key       = $query->param("KEY");
my $acc       = $query->param("ACC");
my $ugid      = $query->param("UGID");

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $sym, $key, $acc, $ugid);
print GetRNAiGene_1($base, $page, $org, $sym, $key, $acc, $ugid);
