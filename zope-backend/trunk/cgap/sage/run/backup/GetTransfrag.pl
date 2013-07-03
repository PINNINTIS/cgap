#!/usr/local/bin/perl

#############################################################################
# GetTransfrag.pl
#
 
use strict;
use CGI;
 
BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
use SAGE;
 
my $query                = new CGI;
my $base                 = $query->param("BASE");
my $page                 = $query->param("PAGE");
my $org                  = $query->param("ORG");
my $chr                  = $query->param("CHR");
my $start_pos            = $query->param("CHR_START");
my $end_pos              = $query->param("CHR_END");
 
print "Content-type: text/plain\n\n";

print GetTransfrag_1($base, $page, $org, $chr, $start_pos, $end_pos); 
