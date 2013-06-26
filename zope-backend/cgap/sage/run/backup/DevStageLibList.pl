#!/usr/local/bin/perl

######################################################################
# DevStageLibList.pl
#


use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SAGE;

my $query      = new CGI;
my $base = $query->param("BASE");

#my (
#  $base
#) = @ARGV;

print "Content-type: text/plain\n\n";

print DevStageLibList_1($base);
