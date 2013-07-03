#!/usr/local/bin/perl

######################################################################
# SAGELibPage.pl
#


use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

my $query       = new CGI;
my $description = $query->param("DESCRIPTION");
my $filename    = $query->param("filenameFILE");

print "Content-type: text/plain\n\n";

print "8888: $description, $filename ";
