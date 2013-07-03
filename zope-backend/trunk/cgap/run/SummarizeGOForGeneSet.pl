#!/usr/local/bin/perl

######################################################################
# SummarizeGOForGeneSet.pl
######################################################################

use strict;
use DBI;
use CGI;


BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPConfig;
use GOBrowser;
use Scan;

my $query   = new CGI;
my $base    = $query->param("BASE");
my $org     = $query->param("ORG");
my @cids    = $query->param("CIDS");

use constant ORACLE_LIST_LIMIT  => 500;
use constant MAX_ROWS_PER_FETCH => 1000;
use constant MAX_LONG_LEN       => 16384;

my (%go2cid, %go2name, %go2class);
my (%cids);
my (%total, %direct_total);
my ($total_annotated_genes);

print "Content-type: text/plain\n\n";

if( $cids[0] =~ /,/ ) {
  my $tmp = $cids[0];
  @cids = split ",", $tmp;
}

## print "8888" . join (",", @cids) . "\n";
Scan($base, $org, \@cids);
print SummarizeGOForGeneSet_1($base, $org, \@cids);






