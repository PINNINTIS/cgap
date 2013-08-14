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
$base             = cleanString($base);             
my $page             = $query->param("PAGE");
$page             = cleanString($page);             
my $org              = $query->param("ORG");
$org              = cleanString($org);              
my $ckbox            = $query->param("CKBOX");
$ckbox            = cleanString($ckbox);            
my $page_header      = $query->param("PAGE_HEADER");
$page_header      = cleanString($page_header);      
my $genes            = $query->param("CIDS");
$genes            = cleanString($genes);            
my $gene_ids         = $query->param("GENE_IDS");
$gene_ids         = cleanString($gene_ids);         
my $gene_syms        = $query->param("GENE_SYMS");
$gene_syms        = cleanString($gene_syms);        
my $order_gene_ids   = $query->param("ORDER_GENE_IDS");
$order_gene_ids   = cleanString($order_gene_ids);   
my $order_gene_syms  = $query->param("ORDER_GENE_SYMS");
$order_gene_syms  = cleanString($order_gene_syms);  

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
