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

my $query      = new CGI;
my $base       = $query->param("BASE");
$base       = cleanString($base);
my $cmd        = $query->param("CMD");
$cmd        = cleanString($cmd);
my $url        = $query->param("URL");
$url        = cleanString($url);
my $target        = $query->param("TARGET");
$target        = cleanString($target);        
my $focal_node = $query->param("NODE");
$focal_node = cleanString($focal_node); 
my $goids = $query->param("GOIDS");
$goids = cleanString($goids);
my $context_node_list = join(",", $goids);

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
