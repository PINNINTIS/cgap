#!/usr/local/bin/perl

use strict;
use DBI;
use CGI;
use URI::Escape;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use GOBrowser;
use Scan;

if (-d "/app/oracle/product/dbhome/current") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/dbhome/current";
} elsif (-d "/app/oracle/product/8.1.7") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.7";
} elsif (-d "/app/oracle/product/8.1.6") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.6";
}

my $query      = new CGI;
my $base       = $query->param("BASE");
my $cmd        = $query->param("CMD");
my $url        = $query->param("URL");
my $target        = $query->param("TARGET");
my $focal_node = $query->param("NODE");
my $context_node_list = join(",", $query->param("GOIDS"));

my $gene_or_prot = "GENE";

#my (
#  $base,
#  $action,
#  $focal_node,
#  $context_node_list
#  ) = @ARGV;

print "Content-type: text/html\n\n";

Scan($base, $gene_or_prot, $cmd, $url, $target,
     $focal_node, $context_node_list);
print GOBrowser_1($base, $gene_or_prot, $cmd, $url, $target,
                  $focal_node, $context_node_list);
