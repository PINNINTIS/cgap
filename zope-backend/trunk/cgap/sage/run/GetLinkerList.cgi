#!/usr/local/bin/perl

######################################################################
# GetLinkerList.cgi
#


use strict;
use CGI;
## use SAGEConfig;

print "Content-type: text/plain\n\n";

my $query       = new CGI;
my $type  = $query->param("TYPE");

print GetLinkerList($type);

######################################################################
sub GetLinkerList {
  my ($type) = @_;
  my @all_lines;
  my $dir = "/share/content/CGAP/data";
  my $filename;
  if( $type eq "LONG" ) {
    $filename = $dir . "/Linkers_17.txt";
  }
  elsif( $type eq "SHORT" ) {
    $filename = $dir . "/Linkers_10.txt";
  }

  open( IN, $filename ) or die "Can not open $filename \n";
  while (<IN>) {
    push @all_lines, $_;
  }
  return join "", @all_lines;
}

######################################################################
