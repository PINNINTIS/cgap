#!/usr/local/bin/perl

######################################################################
# GetTagList.pl
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

## my (
##   $format,
##   $rank_limit,
##   $what,                ## "c" or "a"
##   $card
## ) = @ARGV;

my $query      = new CGI;
my $rank_limit = $query->param("RANK");
my $format     = $query->param("FORMAT");
my $what       = $query->param("WHAT");
my $card       = $query->param("MAPCARD");

print "Content-type: text/plain\n\n";


Scan ($format, $rank_limit, $what, $card);
print GetTagList_1 ($format, $rank_limit, $what, $card);
