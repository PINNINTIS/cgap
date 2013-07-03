#!/usr/local/bin/perl

#############################################################################
# GetGenomicsByTags.pl
#
 
use strict;
use CGI;
 
BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
use SAGE;
 
my $query     = new CGI;
my $base      = $query->param("BASE");
my $acc       = $query->param("ACC");
my $org       = $query->param("ORG");
 
print "Content-type: text/plain\n\n";
 
print ATF_Info_1($base, $acc, $org);
