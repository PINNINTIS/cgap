#!/usr/local/bin/perl

#############################################################################
# RNAiViewer.pl
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

##my ($base, $org, $acc, $sym) = @ARGV;

my $query     = new CGI;
my $base      = $query->param("BASE");
my $org       = $query->param("ORG");
my $acc       = $query->param("ACC");
my $sym       = $query->param("SYM");

print "Content-type: text/plain\n\n";

Scan($base, $org, $acc, $sym);
print RNAiViewer_1($base, $org, $acc, $sym);
