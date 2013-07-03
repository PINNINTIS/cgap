#!/usr/local/bin/perl

#############################################################################
# CommonGeneQuery.pl
#

use strict;
use CGI;
use Scan;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPGene;

##my ($base, $page, $org, $ckbox, $page_header, $genes) = @ARGV;
my $query            = new CGI;
my $base             = $query->param("BASE");
my $page             = $query->param("PAGE");
my $org              = $query->param("ORG");
my $ckbox            = $query->param("CKBOX");
my $page_header      = $query->param("PAGE_HEADER");
my $genes            = $query->param("CIDS");
my $gene_ids         = $query->param("GENE_IDS");
my $gene_syms        = $query->param("GENE_SYMS");
my $order_gene_ids   = $query->param("ORDER_GENE_IDS");
my $order_gene_syms  = $query->param("ORDER_GENE_SYMS");

print "Content-type: text/plain\n\n";

Scan($base, $page, $org, $ckbox, $page_header, $genes, $gene_ids, $gene_syms);
my @order_locs = split ",", $order_gene_ids;
my @order_syms = split ",", $order_gene_syms;
for (my $i=0; $i<@order_locs; $i++ ) {
  Scan($order_locs[$i]);
}
for (my $i=0; $i<@order_syms; $i++ ) {
  Scan($order_syms[$i]);
}
print CommonGeneQuery_1($base, $page, $org, $ckbox, $page_header, $genes, $gene_ids, $gene_syms, $order_gene_ids, $order_gene_syms);
