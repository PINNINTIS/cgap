#!/usr/local/bin/perl

######################################################################
# LICRGene.pm
#
######################################################################

use strict;
use DBI;
use CGAPConfig;
use CGAPGene;
use Bayesian;
use Cache;
use GD;

my $DENOM       = 200000;
my $BP_SCALE    = 100000;

## my $IMAGE_HEIGHT        = 1800;
my $IMAGE_HEIGHT        = 1400;
my $IMAGE_WIDTH         = 800;
my $ZOOMED_AXIS_LENGTH  = 1600;  ## i.e., 800 pixels * SCALED_BPS_TO_PIXEL
my $VERT_MARGIN         = 45;
my $GENE_BAR_CONSTANT   = 10;
my $SCALED_BPS_TO_PIXEL = 2;
my %COLORS;
my $SCALE_WIDTH = 600;

my (%vn_lib_count, %vn_seq_count, %code2tiss, %tiss2code);

my $BASE;

my $cache = new Cache(CACHE_ROOT, LICR_CACHE_PREFIX);

if (-d "/app/oracle/product/8.1.7") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.7";
} else {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.6";
}

######################################################################
sub numerically { $a <=> $b ;}

######################################################################
sub r_numerically { $b <=> $a; }

######################################################################
sub DividerBar {
  my ($title) = @_;
  return "<table width=95% cellpadding=2>" .
      "<tr bgcolor=\"#666699\"><td align=center>" .
      "<font color=\"white\"><b>$title</b></font>" .
      "</td></tr></table>\n";
}

######################################################################
sub InitializeImage {

  my $im = new GD::Image($IMAGE_WIDTH, $IMAGE_HEIGHT);
 
  # allocate some colors
##
## Apparently, the first color allocated becomes the background color of
## the image by default
##
  $COLORS{white}       = $im->colorAllocate(255,255,255);
  $COLORS{black}       = $im->colorAllocate(0,0,0);
  $COLORS{red}         = $im->colorAllocate(255,0,0);
  $COLORS{blue}        = $im->colorAllocate(0,0,255);
  $COLORS{lightblue}   = $im->colorAllocate(173,216,230);
  $COLORS{green}       = $im->colorAllocate(0,128,0);
  $COLORS{yellow}      = $im->colorAllocate(255,255,0);
#  $COLORS{olive}       = $im->colorAllocate(128,128,0);
#  $COLORS{darkred}     = $im->colorAllocate(139,0,0);
#  $COLORS{violet}      = $im->colorAllocate(238,130,238);
#  $COLORS{yellowgreen} = $im->colorAllocate(154,205,50);
#  $COLORS{darksalmon}  = $im->colorAllocate(233,150,122);
#  $COLORS{darkblue}    = $im->colorAllocate(0,0,139);
#  $COLORS{darkgreen}   = $im->colorAllocate(0,100,0);
  $COLORS{purple}      = $im->colorAllocate(128,0,128);

  $COLORS{gray}        = $im->colorAllocate(200,200,200);
  $COLORS{mediumgray}  = $im->colorAllocate(220,220,220);
  $COLORS{lightgray}   = $im->colorAllocate(240,240,240);

  $COLORS{gneg}        = $COLORS{white};
  $COLORS{gpos25}      = $COLORS{lightgray};
  $COLORS{gpos50}      = $COLORS{mediumgray};
  $COLORS{gpos75}      = $COLORS{gray};
  $COLORS{gpos100}     = $COLORS{black};
  $COLORS{stalk}       = $COLORS{white};

  $im->transparent($COLORS{white});
##  $im->interlaced("true");

  return $im;
}

######################################################################
sub FindLICRGenePage_1 {
  my ($base, $org, $cid, $licr_ids) = @_;

  $BASE = $base;

  my ($sym, $title, $loc, $cyt, $gb, $omim, $sv_clones);
  my ($count, $band, $count1, $count2, $list, $url, $count3, $url500);
  my (@licr_ids, @genes, @titles, @src_dbs);
  my (@gene_infos);
  my (%graph_contigs, %accessions, %graph_data);
  my ($image_cache_id);

  my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    $db = "";
  }

  undef %graph_contigs;
  my $gene_info_ref = getGeneContigInfo($db, $org, $licr_ids, \%graph_contigs);

  my $cids = getUGcids($db, $org, $licr_ids);

      ## "<td width=\"10%\"><font color=\"white\"><b>LICR id</b></font></td>".

  my $table_header = "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr bgcolor=\"#666699\">".
      "<td><font color=\"white\"><b>LICR id</b></font></td>".
      "<td><font color=\"white\"><b>Symbol</b></font></td>" .
      "<td><font color=\"white\"><b>Name</b></font></td>" .
      "<td><font color=\"white\"><b>Swissprot</b></font></td>" . 
      "<td><font color=\"white\"><b>mRNA</b></font></td>" .
      "<td><font color=\"white\"><b>All seqs</b></font></td>" .
      "</tr>\n";


  my $licr_line = $table_header;
  for my $licr_id ( sort keys %{$gene_info_ref} ) {
    my (@genes, @titles, @spts);
    for my $swissprot ( sort keys %{$$gene_info_ref{$licr_id}} ) {
      my ($title, $gene) = split "\001", $$gene_info_ref{$licr_id}{$swissprot};
      $gene = ($gene) ? $gene : "-";
      $title = ($title) ? $title : "&nbsp;";
      $swissprot = ($swissprot) ? $swissprot : "&nbsp;";
      push @genes, $gene;
      push @titles, $title;
      push @spts, $swissprot; 
    }
    my $tmp_gene = join "<br><br>", @genes;
    my $tmp_title = join "<br><br>", @titles;
    my $tmp_spt = join "<br><br>", @spts;

    my $count=getGraphData ($db, $org, $graph_contigs{$licr_id}, \%graph_data);
    my $mrna;
    my $tmp_contig = $graph_contigs{$licr_id};
    $tmp_contig =~ s/=/<br>/g;
    if( $count == 0 ) {
      $mrna = $tmp_contig;
    }
    else {
      $mrna="<a href=GetmRNA?ORG=$org&LICR_ID=$licr_id&CONTIG=$graph_contigs{$licr_id}>$tmp_contig</a>";
    }       

    if( @genes > 1 ) {
      $licr_line = $licr_line .
        "<tr>" .
        "<td ><a href=UniGeneInfo?ORG=$org&CID=$cids&LICR_ID=$licr_id>" .
                    "$licr_id</a></td>" .
        "<td valign=bottom>$tmp_gene</td>" .
        "<td valign=bottom>$tmp_title</td>" .
        "<td valign=bottom>$tmp_spt</td>" .
        "<td>$mrna</td>" .
        "<td><a href=GetAllSeqs?ORG=$org&LICR_ID=$licr_id>All seqs</a></td>" .
        "</tr>"; 
    }
    else {
      $licr_line = $licr_line .
        "<tr>" .
        "<td ><a href=UniGeneInfo?ORG=$org&CID=$cids&LICR_ID=$licr_id>" .
                    "$licr_id</a></td>" .
        "<td>$tmp_gene</td>" .
        "<td>$tmp_title</td>" .
        "<td>$tmp_spt</td>" .
        "<td>$mrna</td>" .
        "<td><a href=GetAllSeqs?ORG=$org&LICR_ID=$licr_id>All seqs</a></td>" .
        "</tr>"; 
    }

  }

  $licr_line = $licr_line . "</table>";

  my $header_line = "<br><b>LICR clusters corresponding to UniGene:<b> " .
    " &nbsp;&nbsp;&nbsp;&nbsp; $org.$cid. " . "<br><br>";
    
  my @lines;
  push @lines, $header_line;
  push @lines, $licr_line;

  return
      join("\n", @lines);

}

######################################################################
sub FindUniGenePage_1 {
  my ($base, $org, $cids, $licr_id) = @_;

  $BASE = $base;

  my ($sym, $title, $loc, $cyt, $gb, $omim, $sv_clones);
  my ($count, $band, $count1, $count2, $list, $url, $count3, $url500);
  my (@licr_ids, @genes, @titles, @src_dbs);
  my (@gene_infos);
  my (%graph_contigs, %accessions, %graph_data);
  my ($image_cache_id);

  my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    $db = "";
  }

  my $gene_info_ref = getGeneContigInfo($db, $org, $licr_id, \%graph_contigs);


  my $table_header = "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr bgcolor=\"#666699\">".
      "<td><font color=\"white\"><b>Symbol</b></font></td>" .
      "<td><font color=\"white\"><b>Name</b></font></td>" .
      "<td><font color=\"white\"><b>Swissprot</b></font></td>" .
      "<td><font color=\"white\"><b>mRNA</b></font></td>" .
      "<td><font color=\"white\"><b>All seqs</b></font></td>" .
      "</tr>\n";

  my $licr_line = $table_header;
  my (@genes, @titles, @spts);
  for my $swissprot ( sort keys %{$$gene_info_ref{$licr_id}} ) {
    my ($title, $gene) = split "\001", $$gene_info_ref{$licr_id}{$swissprot};
    $gene = ($gene) ? $gene : "-";
    $title = ($title) ? $title : "&nbsp;";
    $swissprot = ($swissprot) ? $swissprot : "&nbsp;";
    push @genes, $gene;
    push @titles, $title;
    push @spts, $swissprot;
  }
  my $tmp_gene = join "<br><br>", @genes;
  my $tmp_title = join "<br><br>", @titles;
  my $tmp_spt = join "<br><br>", @spts;
 
  my $count=getGraphData ($db, $org, $graph_contigs{$licr_id}, \%graph_data);
  my $mrna;
  my $tmp_contig = $graph_contigs{$licr_id};
  $tmp_contig =~ s/=/<br>/g;
  if( $count == 0 ) {
    $mrna = $tmp_contig;
  }
  else {
    $mrna="<a href=GetmRNA?ORG=$org&LICR_ID=$licr_id&CONTIG=$graph_contigs{$licr_id}>$tmp_contig</a>";  
  }      
 
  if( @genes > 1 ) {
    $licr_line = $licr_line .
      "<tr>" .
      "<td valign=bottom>$tmp_gene</td>" .
      "<td valign=bottom>$tmp_title</td>" .
      "<td valign=bottom>$tmp_spt</td>" .
      "<td>$mrna</td>" .
      "<td><a href=GetAllSeqs?ORG=$org&LICR_ID=$licr_id>All seqs</a></td>" .
      "</tr>";
  }
  else {
    $licr_line = $licr_line .
      "<tr>" .
      "<td>$tmp_gene</td>" .
      "<td>$tmp_title</td>" .
      "<td>$tmp_spt</td>" .
      "<td>$mrna</td>" .
      "<td><a href=GetAllSeqs?ORG=$org&LICR_ID=$licr_id>All seqs</a></td>" .
      "</tr>";
  }
 
  $licr_line = $licr_line . "</table>";
 



  my $header_table = "<br><b>LICR cluster $licr_id:<b><br><br>";

  my @lines;
  push @lines, $header_table;
  push @lines, $licr_line;

  my $page = 1;
  my $uniGeneInfo = getUniGenepage($db, $base, $page, $org, $cids, $licr_id);  
  push @lines, $uniGeneInfo;

  return
      join("\n", @lines);

}

######################################################################
sub GetAllSeqs_1 {
  my ($base, $org, $licr_id) = @_;

  $BASE = $base;

  my ($sym, $title, $loc, $cyt, $gb, $omim, $sv_clones);
  my ($count, $band, $count1, $count2, $list, $url, $count3, $url500);
  my (@licr_ids, @genes, @titles, @src_dbs);
  my (@gene_infos);
  my (%graph_contigs, %accessions, %graph_data);
  my ($image_cache_id);

  my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    $db = "";
  }

  my $seq_info = getAllSeqspage($db, $org, $licr_id);

  my @lines;
  push @lines, "Sequences in LICR cluster $licr_id";
  push @lines, "accession\ttype";
  push @lines, $seq_info;

  return
      join("\n", @lines);

}

######################################################################
sub getAllSeqspage {
  my ($db, $org, $licr_id) = @_;
    
  ## Look for gene given (a) putative cluster number, or (b)
  ## putatitve GenBank Accession number of constitutent of cluster
    
  my ($cid, @cids);
  my (@row, @rows);
  my (@terms, @nums, @syms);
  my ($sql, $stm);
  my (@accs);
 
  my $licr_sequence_table = ($org eq "Hs" ? " $CGAP_SCHEMA.licr_hs_sequence " : " $CGAP_SCHEMA.licr_mm_sequence ");
 
  $sql =
        "select distinct accession, src_db from $licr_sequence_table " .
        "where licr_id = '$licr_id' order by src_db";
  $stm = $db->prepare($sql);
  if ($stm->execute()) {
    while (my ($acc, $src_db) = $stm->fetchrow_array()) {
      push @accs, $acc . "\t" . $src_db . "\n";
    }
  } else {
    SetStatus(S_RESPONSE_FAIL);
    print STDERR "$sql\n";
    print STDERR "execute call failed\n";
    return "";
  }

  return (join "", @accs);
}


######################################################################
sub getUniGenepage {    
  my ($db, $base, $page, $org, $term, $licr_id) = @_;

  ## Look for gene given (a) putative cluster number, or (b)
  ## putatitve GenBank Accession number of constitutent of cluster
 
  my ($cid, @cids);
  my (@row, @rows);
  my (@terms, @nums, @syms);
  my ($sql, $sql_clu, $sql_acc, $sql_sym);
  my ($stm);
 
  for $term (split (",", $term)) {
    push @nums, $term   
  } 
    
  my $gene_cluster_table = ($org eq "Hs" ? " $CGAP_SCHEMA.hs_cluster " : " $CGAP_SCHEMA.mm_cluster ");

  $sql_clu = 
        "select distinct cluster_number from $gene_cluster_table " .
        "where cluster_number in (" . join(", ", @nums) . ")";
  $stm = $db->prepare($sql_clu);
  if ($stm->execute()) { 
    while (($cid) = $stm->fetchrow_array()) {
      push @cids, $cid;  
    }
  } else {
    SetStatus(S_RESPONSE_FAIL);
    print STDERR "$sql_clu\n";
    print STDERR "execute call failed\n";
    return "";
  }

  my $clusters = join ",",  @cids;

  my $page_header = "<br><br><br><b>UniGene cluster(s) corresponding to $licr_id:<b><br><br>";

  my $orderedGenesBySymbol =  OrderGenesBySymbol($page, $org, \@cids);

  return(FormatUniGenes($base, $page, $org, $page_header, $orderedGenesBySymbol) );
}

######################################################################
sub FormatUniGenes {
  my ($base, $page, $org, $page_header, $items_ref) = @_;
  my $i;
  my @s;
  if ($page < 1) {
    for ($i = 0; $i < scalar(@{ $items_ref }); $i++) {
      $s[$i] = FormatOneGene("TEXT", $org, $$items_ref[$i]) . "\n";
    }
    return (join "", @s);
  } 
  else {
    for ($i = 0; $i < scalar(@{ $items_ref }); $i++) {
      $s[$i] = FormatOneUniGene("HTML", $base, $org, $$items_ref[$i]) . "\n";
    }
  }

  my $table_header = "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr bgcolor=\"#666699\">".
      "<td width=\"10%\"><font color=\"white\"><b>Symbol</b></font></td>".
      "<td width=\"45%\"><font color=\"white\"><b>Name</b></font></td>" .
      "<td width=\"20%\"><font color=\"white\"><b>Sequence ID</b></font></td>" .      "<td><font color=\"white\"><b>CGAP Gene Info</b></font></td>" .
      "</tr>\n";
    
  return $page_header . $table_header . (join "", @s) . "</table><br><br>";
 
}

######################################################################
sub FormatOneUniGene {
  my ($what, $base, $org, $cids) = @_;
  my ($cid, $symbol, $title, $loc, $gb) = split(/\001/, $cids);

  $BASE = $base;

  my $url = "" . $BASE . "/Genes/GeneInfo?ORG=$org&CID=$cid";

  $symbol or $symbol = '-';
  $title or $title = '-';

  my $s;
  if ($what eq 'HTML') {
    $gb =~ s/ /<br>/g;
    $s = "<tr valign=top>" .
        "<td>" . $symbol . "</td>" .
        "<td>" . $title . "</td>" .
        "<td>" . $gb . "</td>" .
        "<td><a href=$url>Gene Info</a></td>" .
        "</tr>" ;

  } else {                                      ## $what == TEXT
    $loc or $loc = "-";
    $s = "$symbol\t$title\t$gb\t$org.$cid\t$loc";
  }
  return $s;
}

######################################################################
sub GetmRNA_1 {
  my ($base, $org, $licr_id, $contigs) = @_;

  $BASE = $base;

  my ($sym, $title, $loc, $cyt, $gb, $omim, $sv_clones);
  my ($count, $band, $count1, $count2, $list, $url, $count3, $url500);
  my (@licr_ids, @genes, @titles, @src_dbs);
  my (@gene_infos);
  my (%graph_contigs, %accessions, %graph_data);

  my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    $db = "";
  }

  my @lines;
  my @image_cache_ids;
  my @contig_array = split "=", $contigs;

  getGraphData ($db, $org, $contigs, \%graph_data);

  my $im = InitializeImage(); 
  my $red = $COLORS{red}; 
 
  my $orig_x = 400;
  my $orig_y = 400;
  my $radi = 150;
  my @pies;

  $pies[0] = 0;
  $pies[1] = 10;
  $pies[2] = 30;
  $pies[3] = 40;
  $pies[4] = 20;

  drawGraph($im, $orig_x, $orig_y, $radi, \@pies);
 
  my @image_map;
  push @image_map, "<map name=\"piemap\">";

  getMap($orig_x, $orig_y, $radi, \@pies, \@image_map);

  push @image_map, "</map>";

  my ($image_cache_id);
  if (GD->require_version() > 1.19) {
    $image_cache_id = WriteToCache($im->png);
  } else {
    $image_cache_id = WriteToCache($im->gif);
  }  
    
  if (! $image_cache_id) {
    return "Cache failed";
  } 
   
  push @lines, "<center><h2>mRNA Structure for LICR cluster $licr_id</h2></center><br><br><br>\n";
  push @lines,
    "<image src=\"LICRImage?CACHE=$image_cache_id\" " .
    "border=0 width=800 height=1400 " .
    "usemap=\"#piemap\">";
  push @lines, @image_map;

  if ($db) {
    $db->disconnect();
  }
    
  return
      join("\n", @lines);

}

######################################################################
sub FindLICRGenePage_1_bak {
  my ($base, $org, $licr_ids) = @_;

  $BASE = $base;

  my ($sym, $title, $loc, $cyt, $gb, $omim, $sv_clones);
  my ($count, $band, $count1, $count2, $list, $url, $count3, $url500);
  my (@licr_ids, @genes, @titles, @src_dbs);
  my (@gene_infos);
  my (%graph_contigs, %accessions, %graph_data);
  my ($image_cache_id);

  my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    $db = "";
  }

  my $gene_info_list = getGeneContigInfo($db, $org, $licr_ids, \%graph_contigs);

  getGraphData ($db, $org, \%graph_contigs, \%accessions, \%graph_data);

  my $gb_list;
  for my $access (sort keys %accessions) {
    $gb_list = $gb_list .
        "<a href=javascript:spawn(" .
        "\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=Nucleotide&" .
        "CMD=Search&term=$access\")>$access</a><br>\n";
  }

  my $header_table = "<table><tr valign=top>".
    "<td width=20%><b>Gene Information For:</b></td>" .
    "<td>$gene_info_list</td></tr>" .
    "<tr valign=top><td><b>Sequence ID:</b></td>" .
    "<td>$gb_list</td>" .
    "</tr></table>" ;


  if ($db) {
    $db->disconnect();
  }

  my $im = InitializeImage();

  my $red = $COLORS{red}; 
 
  my $x1 = 200;
  my $x2 = 300;
  my $y1 = 200;
  my $y2 = 300;
  
  ## $im->filledRectangle ($x1, $y1, $x2, $y2, $red);

  drawGraph($im, $org, \%graph_contigs, \%graph_data);
 
  if (GD->require_version() > 1.19) {
    $image_cache_id = WriteToCache($im->png);
  } else {
    $image_cache_id = WriteToCache($im->gif);
  }
    
  if (! $image_cache_id) {
    return "Cache failed";
  }
    
  my @lines;
  push @lines, $header_table;
  push @lines, "<br>\n" .
               DividerBar("LICR Graph") .
               "<br>\n"; 

  push @lines,
      "<image src=\"LICRImage?CACHE=$image_cache_id\" " .
      "border=0 width=1000 height=1800 " .
      "usemap=\"#chrmap\">";
    
  return
      join("\n", @lines);

}

######################################################################
sub getUGcids {
  my ($db, $org, $licr_ids) = @_;
  my %geneInfo;
  my @gene_info_list;
  my %licrwithcontigs;
  my ($cid, @cids);

  my $licr_sequence = ($org eq "Hs" ? "$CGAP_SCHEMA.licr_hs_sequence" : "$CGAP_SCHEMA.licr_mm_sequence");
 
  my $ug_sequence = ($org eq "Hs" ? "$CGAP_SCHEMA.hs_ug_sequence" : "$CGAP_SCHEMA.mm_ug_sequence");
 
  my @licrids = split "=", $licr_ids;
  my $licr_id_list = "'" . join("','", @licrids) . "'";

  my (@licrs, $licr_id, $accession, $src_db, $title, $gene, $swissprot, 
              $graph_contig, $chromosome);
 
  my $sql_lines = "select unique a.CLUSTER_NUMBER " .
                  " from $ug_sequence a, " .
                  "      $licr_sequence b " .
                  " where a.ACCESSION = b.ACCESSION " .
                  " and b.LICR_ID in ( $licr_id_list ) " .
                  " and ( b.SRC_DB = 'M' or b.SRC_DB = 'R' ) ";
 
  my $stm = $db->prepare($sql_lines);
 
  if(!$stm->execute()) {
 
    print STDERR "$sql_lines\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    $db->disconnect(); 
    return "";
  }

  $stm->bind_columns(\$cid);
 
 
  while($stm->fetch) {
    push @cids, $cid;
  }

  return join ",", @cids;

}

######################################################################
sub getGeneContigInfo {
  my ($db, $org, $licr_ids, $graph_contigs) = @_;
  my %geneInfo;
  my @gene_info_list;
  my %licrwithcontigs;

  my $licr_sequence = ($org eq "Hs" ? "$CGAP_SCHEMA.licr_hs_sequence" : "$CGAP_SCHEMA.licr_mm_sequence");
 
  my $licr_graph = ($org eq "Hs" ? "$CGAP_SCHEMA.licr_hs_graph" : "$CGAP_SCHEMA.licr_mm_graph");
 
  my $licr_gene = ($org eq "Hs" ? "$CGAP_SCHEMA.licr_hs_gene" : "$CGAP_SCHEMA.licr_mm_gene");
 
  my @licrids = split "=", $licr_ids;
  my $licr_id_list = "'" . join("','", @licrids) . "'";

  my (@licrs, $licr_id, $accession, $src_db, $title, $gene, $swissprot, 
              $graph_contig, $chromosome);
 
  my $sql_lines = "select unique a.LICR_ID, b.TITLE, b.GENE, " .
                  " b.SWISSPROT, c.GRAPH_CONTIG, c.CHROMOSOME " .
                  " from $licr_sequence a, " .
                  "      $licr_graph b, " .
                  "      $licr_gene c " .
                  " where a.LICR_ID = b.LICR_ID and a.LICR_ID = c.LICR_ID " .
                  " and a.LICR_ID in ( $licr_id_list ) " .
                  " and ( a.SRC_DB = 'M' or a.SRC_DB = 'R' ) ";
 
  my $stm = $db->prepare($sql_lines);
 
  if(!$stm->execute()) {
 
    print STDERR "$sql_lines\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    $db->disconnect(); 
    return "";
  }

  $stm->bind_columns(\$licr_id, \$title, \$gene, \$swissprot,
                     \$graph_contig, \$chromosome);
 
 
  my %distinct;
  while($stm->fetch) {
    ## $gene_info_list = $gene_info_list .  "$org, $licr_id, $gene, $title <br> \n";
    ## print "AAAAA: $licr_id, $title, $gene, $swissprot, $graph_contig, $chromosome<br>";
    $geneInfo{$licr_id}{$swissprot} = join "\001", $title, $gene;
    if( not defined $distinct{licr_id}{$graph_contig} ) {
      $distinct{licr_id}{$graph_contig} = 1;
      if( not defined $$graph_contigs{$licr_id} ) {
        $$graph_contigs{$licr_id} = $graph_contig;
      }
      else {
        $$graph_contigs{$licr_id} = $$graph_contigs{$licr_id} . "=" . $graph_contig;
      }
    }
  }

  return \%geneInfo;

}

######################################################################
sub getGraphData {
  my ($db, $org, $graph_contigs, $graph_data) = @_;

  my %graph_data;
  my $graph_contig_list;
 
  my @contis  = split "=", $graph_contigs; 

  $graph_contig_list = "'" . join("','", @contis) . "'";
 
  my ($GRAPH_CONTIG, $EXON_ID, $ACCESSION, $TRANSCRIPT_START,
      $TRANSCRIPT_END, $CONTIG_START, $CONTIG_END);
 
  my $licr_sequence = ($org eq "Hs" ? "$CGAP_SCHEMA.licr_hs_sequence" : "$CGAP_SCHEMA.licr_mm_sequence");

  my $licr_gene = ($org eq "Hs" ? "$CGAP_SCHEMA.licr_hs_gene" : "$CGAP_SCHEMA.licr_mm_gene");

  my $sql = "select a.GRAPH_CONTIG, a.EXON_ID, a.ACCESSION, " .
            " b.CONTIG_START, b.CONTIG_END " .
            " from $CGAP_SCHEMA.LICR_ETRANSCRIPT a, " .
            " $CGAP_SCHEMA.LICR_EXON b, " .
            " $licr_gene c, " .
            " $licr_sequence d " .
            " where a.GRAPH_CONTIG in ( $graph_contig_list ) " .
            " and a.GRAPH_CONTIG  = b.GRAPH_CONTIG " .
            " and a.EXON_ID  = b.EXON_ID " .
            " and a.ACCESSION  = d.ACCESSION " .
            " and a.GRAPH_CONTIG  = c.GRAPH_CONTIG " .
            " and c.LICR_ID = d.LICR_ID " .
            " and ( d.SRC_DB = 'M' or d.SRC_DB= 'R' ) ";
 
  ## print "AAAAA: $sql<br>";

  my $stm = $db->prepare($sql);
 
  if(!$stm->execute()) {
 
    ## SetStatus(S_RESPONSE_FAIL);
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    $db->disconnect();
    return "";
  }
 
  $stm->bind_columns(\$GRAPH_CONTIG, \$EXON_ID, \$ACCESSION,
                     \$CONTIG_START, \$CONTIG_END);
 
  my $count = 0;
  while($stm->fetch) {
    ## print "$GRAPH_CONTIG, $EXON_ID, $ACCESSION, $TRANSCRIPT_START,
    ##                      $TRANSCRIPT_END, $CONTIG_START, $CONTIG_END<br>";
    $$graph_data{$GRAPH_CONTIG}{$ACCESSION}{$EXON_ID} = 
       join ";", $CONTIG_START, $CONTIG_END;
    $count++;
  }

  return $count;

} 

######################################################################
sub drawGraph {
  my ($im, $orig_x, $orig_y, $radi, $pies_ref) = @_;

  my ($x1, $x2, $y1, $y2, $order, @coords);
  my ($name, $start, $end, $stain, $bcolor);

  my @pies = @{$pies_ref};

  my $height = $radi * 2;
  my $width = $radi * 2;
  $im->arc($orig_x, $orig_y, $width, $height, 0, 360, $COLORS{red});
  $im->fill($orig_x, $orig_y, $COLORS{red});
  $im->arc($orig_x, $orig_y, $width, $height, 0, 360, $COLORS{black});
  my $alpha = 0;
  for (my $i=0; $i<@pies; $i++) {
    $alpha = $alpha + $pies[$i];
    my ($x, $y) = getCoordinate($radi, $alpha);
    my $x1 = $orig_x + $x;
    my $y1 = $orig_y - $y;
    $im->line($orig_x, $orig_y, $x1, $y1, $COLORS{black});
  }
}

######################################################################
sub getMap {
  my ($orig_x, $orig_y, $radi, $pies_ref, $image_map) = @_;

  my ($x1, $x2, $y1, $y2, $order, @coords);
  my ($name, $start, $end, $stain, $bcolor);

  my @pies = @{$pies_ref};
  my @coordinates;

  my $alpha = 0;
  for (my $i=0; $i<@pies; $i++) {
    $alpha = $alpha + $pies[$i];
    my ($x, $y) = getCoordinate($radi, $alpha);
    my $x1 = $orig_x + $x;
    my $y1 = $orig_y - $y;
    push @coordinates, join "\t", ($x1, $y1);
  }

  
  for (my $i=0; $i<@coordinates; $i++) {
    if( $i>0 ) {
      my ($x1, $y1) = split "\t", $coordinates[$i-1];
      my ($x2, $y2) = split "\t", $coordinates[$i];
      if( $i == 1 ) {
        push @{ $image_map },
        "<area shape=\"POLYGON\" coords=\"$orig_x,$orig_y,$x1,$y1,$x2,$y2\" " .
        "href=\"http://www.cnn.com\">";
      }
      if( $i == 2 ) {
        push @{ $image_map },
        "<area shape=POLYGON coords=\"$orig_x,$orig_y,$x1,$y1,$x2,$y2\" " .
        "href=\"http://www.abcnews.com\">";
      }
      if( $i == 3 ) {
        push @{ $image_map },
        "<area shape=POLYGON coords=\"$orig_x,$orig_y,$x1,$y1,$x2,$y2\" " .
        "href=\"http://www.msnbc.com\">";
      }
      if( $i == 4 ) {
        push @{ $image_map },
        "<area shape=POLYGON coords=\"$orig_x, $orig_y,$x1,$y1,$x2,$y2\" " .
        "href=\"http://www.foxnews.com\">";
      }
    ## push @{ $image_map },
    ##    "<area shape=rect coords=\"$x1,$y1,$x2,$y2\" " .
    ##    "href=\"" . $BASE . "/Genes/GeneInfo?ORG=$org&" .
    ##    "CID=$cluster_number\" " .
    ##    "alt=\"$sym\">";
    }
  }
}

######################################################################
sub getCoordinate {
  my ($radi, $piece) = @_;
  my $alpha = ($piece/100) * 2 * 3.1415;
  my $x = $radi * (cos $alpha); 
  my $y = $radi * (sin $alpha); 
  return ($x, $y);
}

######################################################################
sub GetFromCache_1 {
  my ($base, $cache_id) = @_;
 
  $BASE = $base;
 
  return ReadFromCache($cache_id);
}
 
######################################################################
sub ReadFromCache {
  my ($cache_id) = @_;
 
  my ($s, @data);
 
  if ($cache->FindCacheFile($cache_id) eq $CACHE_FAIL) {
    return "Cache expired";
  }
  my $filename = $cache->FindCacheFile($cache_id);
  open(IN, "$filename") or die "Can't open $filename.";
  while (read IN, $s, 16384) {
    push @data, $s;
  }
  close (IN);
  return join("", @data);
 
}
 
 
######################################################################
sub WriteToCache {
  my ($data) = @_;
 
  my ($cache_id, $filename) = $cache->MakeCacheFile();
  if ($cache_id != $CACHE_FAIL) {
    if (open(OUT, ">$filename")) {
      print OUT $data;
      close OUT;
      chmod 0666, $filename;
    } else {
      $cache_id = 0;
    }
  }  
  return $cache_id;
}
 
######################################################################
1;
