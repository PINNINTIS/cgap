#!/usr/local/bin/perl

######################################################################
# GetFreqsOfTag.pl
#


use strict;
use DBI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use GXS;

my (
  $format,
  $tag
) = @ARGV;

print GetFreqsOfTag_1 ($format, $tag);

