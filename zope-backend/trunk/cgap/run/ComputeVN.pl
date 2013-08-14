#!/usr/local/bin/perl

#############################################################################
# ComputeVN.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPLib;
use Scan;

##my ($base, $org, $cid, $text_only) = @ARGV;

my $query = new CGI;

my $query     = new CGI;
my $base      = $query->param("BASE");
$base      = cleanString($base);
my $org       = $query->param("ORG");
$org       = cleanString($org);
my $cid       = $query->param("CID");
$cid       = cleanString($cid);
my $text_only = $query->param("TEXT");
$text_only = cleanString($text_only);

print "Content-type: text/plain\n\n";

Scan($base, $org, $cid, $text_only);
if( $text_only == 0 ) {
  print "<span style=\"float:left\">Expression Pattern for cluster " .
      "<b>$org.$cid<\/b><\/span><span style=\"float:right\"><a href=\"VirtualNorthern\?TEXT=1&ORG=$org&CID=$cid\">Text<\/a> <a href=VNLegend>Legend<\/a><\/span><br><br>";
}

print ComputeVN_1($base, $org, $cid, $text_only);
