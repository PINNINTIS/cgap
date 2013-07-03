#!/usr/local/bin/perl

#############################################################################
# GetGOTerms.pl
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

##my ($pattern, $validate) = @ARGV;
my $query     = new CGI;
my $base      = $query->param("BASE");
my $pattern   = $query->param("PATTERN");
my $validate  = $query->param("VALIDATE");

print "Content-type: text/plain\n\n";

Scan($pattern, $validate);
print GetGOTerms_1($pattern, $validate);
