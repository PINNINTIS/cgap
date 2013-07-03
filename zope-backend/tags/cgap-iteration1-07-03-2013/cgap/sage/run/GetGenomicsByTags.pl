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
use Scan;
 
my $query     = new CGI;
my $base      = $query->param("BASE");
my $page      = $query->param("PAGE");
my $org       = $query->param("ORG");
my $tags      = $query->param("TAGS");
my $method    = $query->param("METHOD");
 
print "Content-type: text/plain\n\n";
 
Scan($base, $page, $org, $tags);
print GetGenomicsByTags_1($base, $page, $org, $tags, $method);
