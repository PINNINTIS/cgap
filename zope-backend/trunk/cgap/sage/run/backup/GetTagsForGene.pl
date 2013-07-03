#!/usr/local/bin/perl

######################################################################
# GetTagsForGene.pl
#


use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SAGE;

######################################################################
# Assume:
#    Query only for human
#    Term can be accession, gene symbol, or cluster number
#
# If accession, look for:
#    (a) tags associated directly with the accession
#    (b) tags associated with the cluster containing the accession
#

## my (
##   $base,
##   $format,
##   $cid,
##   $acc,
##   $term,
##   $details
## ) = @ARGV;

my $query       = new CGI;
my $base        = $query->param("BASE");
my $format      = $query->param("FORMAT");
my $cid         = $query->param("CID");
my $acc         = $query->param("ACC");
my $term        = $query->param("TERM");
my $details     = $query->param("DETAILS");
my $org         = $query->param("ORG");
my $method      = $query->param("METHOD");

print "Content-type: text/plain\n\n";

print GetTagsForGene_1 ($base, $org, $method, $format, $cid, 
                                                       $acc, $term, $details);




