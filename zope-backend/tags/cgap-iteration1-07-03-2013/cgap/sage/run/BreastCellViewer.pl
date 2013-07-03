#!/usr/local/bin/perl

######################################################################
# BreastCellViewer.pl
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

## my ( $base, $tag, $org, $method ) = @ARGV;

my $query  = new CGI;
my $base   = $query->param("BASE");
my $tag    = $query->param("TAG");
my $org    = $query->param("ORG");
my $method = $query->param("METHOD");

print "Content-type: text/plain\n\n";

Scan ($base, $tag, $org, $method);
print BreastCellViewer_1 ($base, $tag, $org, $method);
