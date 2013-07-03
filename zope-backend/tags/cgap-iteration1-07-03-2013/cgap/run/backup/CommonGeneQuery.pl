#!/usr/local/bin/perl

#############################################################################
# CommonGeneQuery.pl
#

use strict;
use CGI;
use Scan;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPGene;

##my ($base, $page, $org, $ckbox, $page_header, $genes) = @ARGV;
my $query       = new CGI;
my $base        = $query->param("BASE");
my $page        = $query->param("PAGE");
my $org         = $query->param("ORG");
my $ckbox       = $query->param("CKBOX");
my $page_header = $query->param("PAGE_HEADER");
my $genes       = $query->param("CIDS");

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $ckbox, $page_header, $genes);
print CommonGeneQuery_1($base, $page, $org, $ckbox, $page_header, $genes);
