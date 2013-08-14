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
$base      = cleanString($base);
my $page      = $query->param("PAGE");
$page      = cleanString($page);
my $org       = $query->param("ORG");
$org       = cleanString($org);
my $sym       = $query->param("SYM");
$sym       = cleanString($sym);
my $key       = $query->param("KEY");
$key       = cleanString($key);
my $acc       = $query->param("ACC");
$acc       = cleanString($acc);
my $ugid      = $query->param("UGID");
$ugid      = cleanString($ugid);

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $sym, $key, $acc, $ugid);
print GetRNAiGene_1($base, $page, $org, $sym, $key, $acc, $ugid);
