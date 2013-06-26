#!/usr/local/bin/perl

######################################################################
# CGAPGene.pm
#
######################################################################

use strict;
use FileHandle;
use CGAPConfig;
use Paging;
use ServerSupport;
use DBI;
## use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);

require LWP::UserAgent;

######################################################################

use constant ORACLE_LIST_LIMIT  => 500;
use constant MAX_ROWS_PER_FETCH => 1000;
use constant MAX_LONG_LEN => 16384;

my $CLONE_PAGE     = 1000000;

my $BASE;

my $UCSC_DB = "";

my %BUILDS;
GetBuildIDs(\%BUILDS);

##
## temp set method = SS10,LS10;
##
my $method = "SS10,LS10";

my $query;
my $where_flag;

my $DEBUG_FLAG;

my ($MAX_MOTIF_SCORE, $MIN_MOTIF_SCORE);

my %motif_info_dup;

my %cid2input;
my %input2cid;

##
## GO stuff
##
my $GO_ROOT = "0003673";
my %GO_OBSOLETE = (
  "0008370" => "CC",
  "0008369" => "MF",
  "0008371" => "BP" 
);
my $GO_OBSOLETE_LIST = "'" . join("','", keys %GO_OBSOLETE) . "'";

my %cluster_table = (
  "Hs" => "hs_cluster",
  "Mm" => "mm_cluster"
);

my %org_2_code = (
  "Hs" => 1,
  "Mm" => 2
);

my %org_2_fullname = (
  "Hs" => "Homo_sapiens",
  "Mm" => "Mus_musculus"
);

######################################################################
sub r_numerically { $b <=> $a };

######################################################################
sub LL_URL {
  my ($ll_id) = @_;
  return "http://www.ncbi.nlm.nih.gov/LocusLink/LocRpt.cgi?l=$ll_id";
}

######################################################################
sub ENTREZ_GENE_URL {
  my ($gene_id) = @_;
  return "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=gene&" .
      "list_uids=$gene_id&cmd=Retrieve" ;
}

######################################################################
sub GENE_INFO_URL {
  my ($org, $cid) = @_;
  return "$BASE/Genes/GeneInfo?ORG=$org&CID=$cid";
}

######################################################################
sub GENPEPT_URL {
  my ($acc) = @_;
  return "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?" .
      "db=Protein&CMD=Search&term=$acc";
}

######################################################################
sub DividerBar {
  my ($title) = @_;
  return "<table width=95% cellpadding=2>" .
      "<tr bgcolor=\"#38639d\"><td align=center>" .
      "<font color=\"white\"><b>$title</b></font>" .
      "</td></tr></table>\n";
}

######################################################################
sub InitMotifInfo {

  my ($db) = @_;

  my ($sql, $stm);

  ## Get min and max scores for protein motif

  $sql = "select max(score), min(score) from $CGAP_SCHEMA.motif_info";
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
     ## print STDERR "$sql\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
     $db->disconnect();
     return "";
  }
  $stm->bind_columns(\$MAX_MOTIF_SCORE, \$MIN_MOTIF_SCORE);
 
  while($stm->fetch) { };

}

###!!!!!!!!!!!! BEGIN EXTRA STUFF FOR MOTIF

######################################################################
sub LookForAccWithMotifInfo {
  my ($db, $org, $cid, $acc_array) = @_;

  my ($sql, $stm, $acc);

  my $e_value = 0.1;
  my $score = 20;

  my $ug_sequence =
    ($org eq "Hs") ? "hs_ug_sequence" : "mm_ug_sequence";
  $sql = "select distinct m.protein_accession from " .
      "$CGAP_SCHEMA.motif_info m, " .
      "$CGAP_SCHEMA.$ug_sequence s, " .
      "$CGAP_SCHEMA.mrna2prot t " .
      "where s.accession = t.mrna_accession " .
      "and t.protein_accession = m.protein_accession " .
      "and s.cluster_number = $cid " .
      "and to_number(m.e_value) < $e_value " .
      "and m.score > $score "; 

  $stm = $db->prepare($sql);

  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  else {

    if(!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       $db->disconnect();
       return "";
    }

    $stm->bind_columns(\$acc);
    while($stm->fetch) {
      push @{ $acc_array }, $acc
    }
  }

}

######################################################################
sub GetPfamInfoForAcc {
  my ($db, $accession) = @_;

  my ($sql, $stm);
  my ($PF_ID, $FAMILY_NAME, $SCORE, $E_VALUE);
  my ($pfam_id);
  my (@output);
  my (%unique_PF);

  $sql = "select MOTIF_ID, MOTIF_NAME, SCORE, E_VALUE " .
      " from $CGAP_SCHEMA.motif_info " .
      " where PROTEIN_ACCESSION = '$accession' ";

  $stm = $db->prepare($sql);

  ## &debug_print( "sql: $sql \n");

  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    $stm->bind_columns(\$PF_ID, \$FAMILY_NAME, \$SCORE, \$E_VALUE);

    while($stm->fetch) {
      &debug_print( " PF_ID: $PF_ID \n" );
      if( not defined $unique_PF{$PF_ID} ) {
        $unique_PF{$PF_ID} = 1;
        $pfam_id = $PF_ID;
        $pfam_id =~ s/^PF/pfam/;
        push @output,
          "<tr>" .
             "<TD><a href=javascript:spawn(\"" .
               "http://www.ncbi.nlm.nih.gov/Structure/cdd/cddsrv.cgi?" .
               "uid=$pfam_id\")>$PF_ID</a></TD>" .
             "<TD>$FAMILY_NAME</TD>" .
             "<TD>$SCORE</TD>" .
             "<TD>$E_VALUE</TD>" .
          "</tr>"; 
      }
    }

    if (@output  > 0 ) {
      unshift @output,"<p>
      <b>Pfam Motif Info For Accession $accession</b><br><br>
      <TABLE WIDTH=\"510\" BORDER=\"1\" CELLSPACING=\"1\" CELLPADDING=\"4\">
        <TR BGCOLOR=\"#38639d\">
          <TD WIDTH=\"140\"><font color=\"white\">
            <B>Pfam ID</B></font>
          </TD>
          <TD WIDTH=\"140\"><font color=\"white\">
            <B>Model</B></font>
          </TD>
          <TD WIDTH=\"90\"><font color=\"white\">
            <B>Score</B></font>
          </TD>
          <TD WIDTH=\"70\"><font color=\"white\">
            <B>E-value</B></font>
          </TD>
        </TR>";

      push @output, "</table>";
      return (1, join("\n", @output));
 
    } else {
      return (0, "<BR><B>There is no protein motif information " .
          "for $accession in the database.</B>");
    }

  }

}

######################################################################
sub GetMotifInfo {
  my ($db, $acc, $e_value, $score, $p_value, $acc2pval, $pval2acc,
      $np_accs) = @_;

  my ($ACC, $PF, $SCORE);
  my (%in_probe, %in_non_probe, %max_non_probe_score, %non_probes);
  my ($sql, $stm);
  my %dups;

  $sql = 
    "select distinct m3.protein_accession, m3.motif_id, m3.score " .
    "from " .
    "$CGAP_SCHEMA.motif_info m1, " .
    "$CGAP_SCHEMA.motif_info m2, " .
    "$CGAP_SCHEMA.motif_info m3 " .
    "where " .
    "m1.protein_accession = '$acc' " .
    "and m1.motif_id = m2.motif_id " .
    "and m2.protein_accession = m3.protein_accession " .
    ($e_value ne "" ?
      ("and to_number(m1.e_value) < $e_value " .
       "and to_number(m2.e_value) < $e_value " .
       "and to_number(m3.e_value) < $e_value ")
      : ""      
    ) .
    ($score ne "" ?
      ("and m1.score > $score " .
       "and m2.score > $score " .
       "and m3.score > $score")
      : ""
    );

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    $stm->bind_columns(\$ACC, \$PF, \$SCORE);
    while($stm->fetch) {
      if ($acc eq $ACC) {
        $in_probe{$PF} = 1;
      } else {
        $in_non_probe{$PF} = 1;
        ## if( defined $max_non_probe_score{$ACC}{$PF} ) {
          if ($SCORE > $max_non_probe_score{$ACC}{$PF}) {
            $max_non_probe_score{$ACC}{$PF} = $SCORE;
          }
        ## } 
        ## else {
        ##   $max_non_probe_score{$ACC}{$PF} = $SCORE;
        ## }
      }
    }
  } 

######################################################################
# Let x: accession = the probe accession
# motifs: accession -> Set Of motif
# Let A = {a: accession | exists m: motif such that
#   m isin motifs(x) and m is in motifs(a)}, defined
#   for some e-value e and some score s
# Let M = {m: motif | m isin motifs(a) for some a in A}
#
# foreach accession a in A
#     prob = 1
#   foreach motif m in M
#     if    m isin motifs(a)  and m isin  motifs(x)
#       prob = prob * (max_score(a,m)-MIN)/(MAX-MIN)
#     elsif m isin motifs(a)  and m notin motifs(x)
#       prob = prob * 0.01
#     elsif m notin motifs(a) and m isin  motifs(x)
#       prob = prob * 0.01
#     elsif m notin motifs(a) and m notin motifs(x)
#       prob = prob * (max_score(a,m)-MIN)/(MAX-MIN)
#   append(prob_list, prob)
#   prob_sum = prob_sum + prob
# for p prob_list
#   append(accession_prob, p / prob_sum)
#
######################################################################

  my ($prob, $cum_prob);

  for my $a (keys %max_non_probe_score) {
    $prob = 1;
    for my $p (keys %in_non_probe) {
      if (defined $max_non_probe_score{$a}{$p}) {
        if (defined $in_probe{$p}) {
          $prob *= ($max_non_probe_score{$a}{$p} -
              $MIN_MOTIF_SCORE)/($MAX_MOTIF_SCORE - $MIN_MOTIF_SCORE);
        } else {
          $prob *= 0.01;
        }
      } else {
        if (defined $in_probe{$p}) {
          $prob *= 0.01;
        } else {
          $prob *= ($max_non_probe_score{$a}{$p} -
              $MIN_MOTIF_SCORE)/($MAX_MOTIF_SCORE - $MIN_MOTIF_SCORE);
        }
      }
    }
    $cum_prob += $prob;
    $$acc2pval{$a} = $prob;
  }
  for my $a (keys %{ $acc2pval }) {
    $$acc2pval{$a} = sprintf "%.2e", ($$acc2pval{$a} / $cum_prob);
    if ($$acc2pval{$a} > $p_value) {
      push @{ $np_accs }, $a;
      push @{ $$pval2acc{$$acc2pval{$a}} }, $a;
    } else {
      delete $$acc2pval{$a};
    }
  }
}

######################################################################
sub SimilarityByMotif_1 {

  my ($base, $page, $accession, $e_value, $score, $p_value, $org) = @_;

  $BASE = $base;
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }

  ## $e_value or $e_value = 1;
  $e_value or $e_value = 0.1;
  ## $score or $score     = 0;
  $score or $score     = 20;
  ## $p_value or $p_value = 0;
  $p_value or $p_value = 0.00001;

  my (@NPresults, %acc2pval, %pval2acc,
      %acc2cid, %cid2desc, %cid2sym, %cid2acc);

  my $param = join "\t", $accession, $e_value, $score, $p_value;

  if ($p_value =~ /^e/ ) {
    $p_value = "1" . $p_value;
  }

  if ($e_value =~ /^e/ ) {
    $e_value = "1" . $e_value;
  }

  $accession =~ s/ +//g;
  $accession = uc($accession);

  &debug_print( "$accession, $e_value, $score, $p_value" );

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    ## print STDERR "$DBI::errstr\n";
    print "Cannot connect to database\n";
    return "";
  }

  InitMotifInfo($db);

  my ($status, $pf_info_output) = GetPfamInfoForAcc($db, $accession);
  if (not $status) {
    $db->disconnect();
    return $pf_info_output;
  }

  GetMotifInfo($db, $accession, $e_value, $score, $p_value,
      \%acc2pval, \%pval2acc, \@NPresults);

  if( @NPresults >  0 )  {
    GetInfoForSimilarGenes($db, \@NPresults, 
        \%acc2cid, \%cid2desc, \%cid2sym, \%cid2acc, $page, $org)
  } else {
    return $pf_info_output .
        "<br><br>There are no accessions similar to $accession " .
        "for e-value = $e_value, score = $score, p_value = $p_value<br>\n";
  }

  $db->disconnect();

  return BuildPageForSimilarGenes($page, $org,
      $accession, $e_value, $score, $p_value,
      $pf_info_output, \%acc2pval, \%pval2acc, 
      \%acc2cid, \%cid2desc, \%cid2sym, \%cid2acc);

}

######################################################################
sub BuildPageForSimilarGenes {
  my ($page, $org, $accession, $e_value, $score, $p_value, 
      $pf_info_output, $acc2pval, $pval2acc, $acc2cid, $cid2desc, 
      $cid2sym, $cid2acc) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($pval, $acc, $cid, @rows);

  my $table_header = "<table border=1 cellspacing=1 cellpadding=4>" .
    "<tr bgcolor=\"#38639d\">".
    "<td nowrap width=\"15%\"><font color=\"white\"><b>Symbol</b></font></td>".
    "<td nowrap width=\"45%\"><font color=\"white\"><b>Name</b></font></td>" .
    "<td nowrap width=\"15%\"><font color=\"white\"><b>Accession</b></font></td>" .
    "<td nowrap width=\"10%\"><font color=\"white\"><b>P-value</b></font></td>" .
    "<td nowrap><font color=\"white\"><b>CGAP Gene Info</b></font></td>" .
    "</tr>";

  if ($page > 0) {
    push @rows, $pf_info_output;
    push @rows, "<br><br>";
    push @rows,
        "<p><b>Accessions with motif content similar to $accession</b>" .
        "&nbsp;&nbsp;&nbsp;&nbsp;" .
        "<a href=\"$BASE/Structure/GetSimMotifs?" .
            "ORG=$org&ACCESSION=$accession&EVALUE=$e_value&SCORE=$score&" .
            "PVALUE=$p_value&PAGE=0\"><b>[Full Text]</b></a><br><br>";
    push @rows, $table_header;
    for $pval (sort r_numerically keys %{ $pval2acc }) {
      for $acc (sort numerically @{ $$pval2acc{$pval} }) {
        if( defined $$acc2cid{$acc} ) {
          $cid = $$acc2cid{$acc};
          push @rows,
            "<tr>" .
            "<td>$$cid2sym{$cid}</td>" .
            "<td>$$cid2desc{$cid}</td>" .
            "<td>$acc</td>" .
            "<td>$pval</td>" .
            "<td><a href=$BASE/Genes/GeneInfo?ORG=$org&CID=$cid>" .
                "Gene Info</a></td>" .
            "</tr>";
         }
         else {
           my $desc = "-";
           my $sym = "-";
           my $Gene_Info = "-";
           push @rows,
              "<tr>" .
              "<td>$sym</td>" .
              "<td>$desc</td>" .
              "<td>$acc</td>" .
              "<td>$pval</td>" .
              "<td>$Gene_Info</td>" .
              "</tr>";
         }
      }
    }
    push @rows, "</table>";
  } else {
    for $pval (sort r_numerically keys %{ $pval2acc }) {
      for $acc (sort numerically @{ $$pval2acc{$pval} }) {
        if( defined $$acc2cid{$acc} ) {
          $cid = $$acc2cid{$acc};
          push @rows,
            "$org.$cid\t" .
            "$$cid2sym{$cid}\t" .
            "$$cid2desc{$cid}\t" .
            "$acc\t" .
            "$pval";
         }
         else { 
           my $desc = "-"; 
           my $sym = "-";
           push @rows,
             "$org\t" . 
             "$sym\t" . 
             "$desc\t" . 
             "$acc\t" .
             "$pval"; 
         } 
      }
    }
  }

  return join "\n", @rows;
}

######################################################################
sub GetInfoForSimilarGenes {
  my ($db, $np_accs, $acc2cid, $cid2desc, 
      $cid2sym, $cid2acc, $page, $org) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  ## Some MGC accessions might not yet be in the UniGene Build,
  ## so look in MGC tables for association to a gene (cluster)

  my ($sql, $stm);
  my ($cid, $acc, $sym, $desc);

  my $ug_sequence =
    ($org eq "Hs") ? "hs_ug_sequence" : "mm_ug_sequence";

  $sql = "select " .
      "c.cluster_number, " .
      "t.protein_accession, c.gene, " .
      "c.description " .
      "from " .
      "$CGAP_SCHEMA.hs_cluster c, " .
      "$CGAP_SCHEMA.$ug_sequence s, " .
      "$CGAP_SCHEMA.mrna2prot t " .
      "where c.cluster_number = s.cluster_number " .
      "and s.accession = t.mrna_accession " .
      "and t.protein_accession in ('" . join("', '", @{ $np_accs }) . "')";
  $stm = $db->prepare($sql);
  if (not $stm) {
    ## print STDERR "sql: $sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } 
  if ($stm->execute()) {
    $stm->bind_columns(\$cid, \$acc, \$sym, \$desc);
    while ($stm->fetch) {
      $$acc2cid{$acc} = $cid;
      $desc or $desc = "-"; 
      $sym or $sym = "-";
      $$cid2desc{$cid} = $desc;
      $$cid2sym{$cid} = $sym;
    }
  } else {
    ## print STDERR "$sql\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
}

######################################################################
sub TranslateGeneIDs {
  my ($list_ref) = @_;
  my $i;
  for ($i = 0; $i < scalar(@{ $list_ref }); $i++) {
    $$list_ref[$i] =~ s/(Hs|Mm).//;
  }
  return $list_ref;
}

######################################################################
sub FormatOneGeneWithInput {
  my ($what, $org, $cids) = @_;
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($input, $cid, $symbol, $title, $loc, $gb)
       = split(/\001/, $cids);

##  my ($symbol, $title, $accession) = split(/\001/, $cid);


  $symbol or $symbol = '-';
  $title or $title = '-';

  my $s;
  if ($what eq 'HTML') {
    $gb =~ s/ /<br>/g;
    $s = "<tr valign=top>" .
        "<td>" . $input . "</td>" .
        "<td>" . $symbol . "</td>" .
        "<td>" . $title . "</td>" .
        "<td>" . $gb . "</td>" .
        "<td><a href=GeneInfo?ORG=$org&CID=$cid&LLNO=$loc>Gene Info</a></td>" .
        "</tr>" ;

  } else {                                      ## $what == TEXT
    $loc or $loc = "-";
    $s = "$input\t$symbol\t$title\t$gb\t$org.$cid\t$loc";
  } 

  return $s;
}

######################################################################
sub FormatOneGene {
  my ($what, $org, $cids) = @_;
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($cid, $symbol, $title, $loc, $gb)
       = split(/\001/, $cids);

##  my ($symbol, $title, $accession) = split(/\001/, $cid);


  $symbol or $symbol = '-';
  $title or $title = '-';
  $gb or $gb = '-';

  my $s;
  if ($what eq 'HTML') {
    $gb =~ s/ /<br>/g;
    $s = "<tr valign=top>" .
        "<td>" . $symbol . "</td>" .
        "<td>" . $title . "</td>" .
        "<td>" . $gb . "</td>" .
        "<td><a href=GeneInfo?ORG=$org&CID=$cid&LLNO=$loc>Gene Info</a></td>" .
        "</tr>" ;

  } else {                                      ## $what == TEXT
    $loc or $loc = "-";
    $s = "$symbol\t$title\t$gb\t$org.$cid\t$loc";
  }
  return $s;
}

######################################################################
sub FormatGenesWithInput {
  my ($page, $org, $cmd, $page_header, $items_ref, $garbage_ref, $locs_ref, $syms_ref) = @_;
  my ($good, $bad);
 
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  ## for BatchGeneFinder there is $input at the first of the line in $items_ref

  if( $page == $CLONE_PAGE ) {
    my $temp = "";
    return GetClones_1( $org, $items_ref, 1, "" );
  }
 
  if ($page < 1) {
    my $i;
    my @s;
    for ($i = 0; $i < scalar(@{ $items_ref }); $i++) {
      $s[$i] = FormatOneGeneWithInput("TEXT", $org, $$items_ref[$i]) . "\n";
    }
    my $len = @{$garbage_ref};
    if( $len > 0 ) {
      for ( my $i=0; $i<@{$garbage_ref}; $i++ ) {
        push @s, "$$garbage_ref[$i]\t\t\t\t\t" . "\n";
      }
    }
    return (join "", @s);
  }
 
  my $table_header = "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr bgcolor=\"#38639d\">".
      "<td width=\"10%\"><font color=\"white\"><b>Query</b></font></td>".
      "<td width=\"10%\"><font color=\"white\"><b>Symbol</b></font></td>".
      "<td width=\"45%\"><font color=\"white\"><b>Name</b></font></td>" .
      "<td width=\"20%\"><font color=\"white\"><b>Sequence ID</b></font></td>" .      "<td><font color=\"white\"><b>CGAP Gene Info</b></font></td>" .
      "</tr>";
  my $formatter_ref = \&FormatOneGeneWithInput;
  my $form_name     = "pform";
  my @hidden_names;
  my @hidden_vals;
  my ($action, $params) = split /\?/, $cmd;
  my $i = 0;
  for (split /\&/, $params) {
    ($hidden_names[$i], $hidden_vals[$i]) = split "=";
    $i++;
  }
 
  my (@order_locs, @order_syms);
  for (@{ $items_ref }) {
    my ($input, $cid, $symbol, $title, $loc, $gb) = split /\001/;
    ($hidden_names[$i], $hidden_vals[$i]) = ("CIDS", $cid);
    push @order_locs, $loc;
    push @order_syms, $symbol;
    $i++;
  }
 
  for (@order_locs) {
    ($hidden_names[$i], $hidden_vals[$i]) = ("ORDER_GENE_IDS", $_);
    $i++;
  }
 
  for (@order_syms) {
    ($hidden_names[$i], $hidden_vals[$i]) = ("ORDER_GENE_SYMS", $_);
    $i++;
  }
 
  if( defined $locs_ref and $locs_ref ne "" ) {
    for( my $j=0; $j<@{$locs_ref}; $j++ ) {      
      ($hidden_names[$i], $hidden_vals[$i]) = ("GENE_IDS", $$locs_ref[$j]);
      $i++;
    }
  }
 
  if( defined $syms_ref and $syms_ref ne "" ) {
    for( my $k=0; $k<@{$syms_ref}; $k++ ) {      
      ($hidden_names[$i], $hidden_vals[$i]) = ("GENE_SYMS", $$syms_ref[$k]);
      $i++;
    }
  }

  $good = PageGeneList(
      $BASE, $page, $org, $page_header, $table_header,
      $action, $form_name, \@hidden_names, \@hidden_vals,
      $formatter_ref, $items_ref);
 
  my $len = @{$garbage_ref};
  if( $len > 0 ) {
    $bad = "<br><br><b> There are no matches for the following: </b><br><br>";
    $bad = $bad . "<blockquote>";
    for ( my $i=0; $i<@{$garbage_ref}; $i++ ) {
      $bad = $bad .
        "$$garbage_ref[$i]<br>";
    }
 
    $bad = $bad . "</blockquote>";
 
    $good = $good . $bad;
  }
  return $good;
 
}

######################################################################
sub FormatGenes {
  my ($page, $org, $cmd, $page_header, $items_ref, $locs_ref, $syms_ref) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  if( $page == $CLONE_PAGE ) {
    my $temp = "";
    return GetClones_1( $org, $items_ref, 1, "" ); 
  } 

  if ($page < 1) {
    my $i;
    my @s;
    for ($i = 0; $i < scalar(@{ $items_ref }); $i++) {
      $s[$i] = FormatOneGene("TEXT", $org, $$items_ref[$i]) . "\n";
    }
    return (join "", @s);
  }

  my $table_header = "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr bgcolor=\"#38639d\">".
      "<td width=\"10%\"><font color=\"white\"><b>Symbol</b></font></td>".
      "<td width=\"45%\"><font color=\"white\"><b>Name</b></font></td>" .
      "<td width=\"20%\"><font color=\"white\"><b>Sequence ID</b></font></td>" .
      "<td><font color=\"white\"><b>CGAP Gene Info</b></font></td>" .
      "</tr>";
  my $formatter_ref = \&FormatOneGene;
  my $form_name     = "pform";
  my @hidden_names;
  my @hidden_vals;
  my ($action, $params) = split /\?/, $cmd;
  my $i = 0;
  for (split /\&/, $params) {
    ($hidden_names[$i], $hidden_vals[$i]) = split "=";
    $i++;
  }

  my (@order_locs, @order_syms);
  for (@{ $items_ref }) {    
    my ($cid, $symbol, $title, $loc, $gb) = split /\001/;
    ($hidden_names[$i], $hidden_vals[$i]) = ("CIDS", $cid);    
    push @order_locs, $loc;
    push @order_syms, $symbol;    
    $i++;  
  }
 
  for (@order_locs) {
    ($hidden_names[$i], $hidden_vals[$i]) = ("ORDER_GENE_IDS", $_);
    $i++;
  }
 
  for (@order_syms) {    ($hidden_names[$i], $hidden_vals[$i]) = ("ORDER_GENE_SYMS", $_);
    $i++;
  }

  if( defined $locs_ref and $locs_ref ne "" ) {
    for( my $j=0; $j<@{$locs_ref}; $j++ ) {      ($hidden_names[$i], $hidden_vals[$i]) = ("GENE_IDS", $$locs_ref[$j]);
      $i++;
    }
  }
 
  if( defined $syms_ref and $syms_ref ne "" ) {
    for( my $k=0; $k<@{$syms_ref}; $k++ ) {      ($hidden_names[$i], $hidden_vals[$i]) = ("GENE_SYMS", $$syms_ref[$k]);
      $i++;
    }
  }

  return PageGeneList(
      $BASE, $page, $org, $page_header, $table_header,
      $action, $form_name, \@hidden_names, \@hidden_vals,
      $formatter_ref, $items_ref);



#### begin old stuff

  my $by_form;

  &debug_print( "in FormatGenes org: $org, cmd: $cmd \n" );
 
  if (scalar(@{ $items_ref }) == 0) {
    return "<h4>$page_header</h4><br><br>" .
        "There are no genes matching the query<br><br>";
  }

  my $num_pages = int(scalar(@{ $items_ref }) / ITEMS_PER_PAGE);
  if (int(scalar(@{ $items_ref }) % ITEMS_PER_PAGE)) {
    $num_pages++;
  }
 
  my $form_name = "";
  if ($cmd =~ /(javascript:)(.*)(document\.)([^\.]+)(\.submit\(\))$/i) {
    $form_name = $4;
    $by_form = 1;
  } else {
    $form_name = "pform1";
    $by_form = 0;
  }

  my $s = "";

  if (not $by_form) {

    $s = "<form name=$form_name action=\"" .
                     (split /\?/, $cmd)[0] . "\">";
    my ($inp_name, $inp_val);
    for my $input (split "&", ((split /\?/, $cmd)[1])) {

      ($inp_name, $inp_val) = split "=", $input;
      if ($inp_name !~ /^PAGE$/) {
         $s = $s .
            "<input type=hidden name=$inp_name value=\"$inp_val\">\n";
      }  
    }  
  }
 
  $s = $s . "<input type=hidden name=PAGE>\n";


  $s = $s .
        "<p><a href=\"javascript:" .
        "document.$form_name.PAGE.value=$CLONE_PAGE;" .
        "document.$form_name.submit()\"" .
	    "><b>[Create Clone List]</b></a>" ;

  $s = $s . "</form>\n";

  $page_header = $page_header . $s;

  if( $page == $CLONE_PAGE ) {
    my $temp = "";
    return GetClones_1( $org, $items_ref, 1, "" ); 
  } 
  elsif ($page < 1) {
    my $i;
    my @s;
    for ($i = 0; $i < scalar(@{ $items_ref }); $i++) {
      $s[$i] = FormatOneGene("TEXT", $org, $$items_ref[$i]) . "\n";
    }
    return (join "", @s);
  } else {
    my $table_header = "<table border=1 cellspacing=1 cellpadding=4>" .
        "<tr bgcolor=\"#38639d\">".
        "<td width=\"10%\"><font color=\"white\"><b>Symbol</b></font></td>".
        "<td width=\"45%\"><font color=\"white\"><b>Name</b></font></td>" .
        "<td width=\"20%\"><font color=\"white\"><b>Sequence ID</b></font></td>" .
        "<td><font color=\"white\"><b>CGAP Gene Info</b></font></td>" .
        "</tr>";

    return PageResults($page, $org, $cmd, $page_header,
        $table_header, \&FormatOneGene, $items_ref);
  }
}

######################################################################
sub FormatGeneList_1 {
  my ($base, $page, $org, $data) = @_;
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }

  $BASE = $base;
 
  my ($cmd, $page_header, $items) = split "\001", $data;
  my @items = split "\002", $items;
  if ($page == $CLONE_PAGE) {
    my (@temp);
    OrderGenesByCluster(\@items, \@temp);
    return FormatGenes($page, $org, $cmd, $page_header, \@temp);
  }
  else {
    return FormatGenes($page, $org, $cmd, $page_header,
      OrderGenesBySymbol($page, $org, \@items));
  }	
}

######################################################################
sub OrderGenesByCluster { 
  my ($items, $sorted_items) = @_;
  for (sort numerically @{ $items }) {
    push @{ $sorted_items }, $_;
  }
}

######################################################################
sub numerically   { $a <=> $b; }
sub r_numerically { $b <=> $a; }




######################################################################
sub GetClones_1 {
 
  my ($org1, $items_ref, $items_in_memory, $filedata) = @_;
  my (%ug_access_to_clones, %ug_syms);
    
  if( not defined $cluster_table{$org1} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  &debug_print( "$org1, $items_ref, $items_in_memory, $filedata \n");
 
  my (@row, @rows, @accs, @lls);
  my @tempArray;
  my @good;
  my @bad;
  my %query2cid;
    
  if( $items_in_memory == 1 ) {
 
     @rows = @{ $items_ref };
     for( my $i=0; $i<@rows; $i++ ) {
       $tempArray[$i] = $org1 . "." . $rows[$i];;
     }
 
  } else {      ## items were read from file; have to parse out cids
 
    &debug_print ("filedata: $filedata \n");
 
    my ($this_org, $this_cid);
    ## $org1 = "";
 
    if( $filedata =~ /\r/ ) {
      @tempArray = split "\r", $filedata;
    }
    else {
      @tempArray = split "\n", $filedata;
    }
 
    for ( my $k = 0; $k < @tempArray; $k++ ) {
      $tempArray[$k] =~  s/\s+//g;
      if ($tempArray[$k] =~ /(hs|mm)\.(\d+)/i) { # cluster
        ($this_org, $this_cid) = ($1, $2);
        if ( lc($org1) eq lc($this_org) ) {
          push @rows, $this_cid;
        }
      } elsif ($tempArray[$k] =~ /[A-Z]{1,2}_?\d{1,6}/) { # accession
        push @accs, $tempArray[$k];
      } elsif ($tempArray[$k] =~ /^\d+$/)  { # locuslink
        push @lls, $tempArray[$k];
      }
    }
  }
    
  GetUGCloneList($org1, \@rows, \%ug_access_to_clones,
                 \@accs, \@lls, $items_in_memory, \@tempArray, \%query2cid);
 
  my ($i, @s, $temp, $accession);
  push @s, "Query\tSymbol\tTitle\tCLuster\tAccession\tImage\tLength\tEnd\tType\n";  
 
  for ( my $k = 0; $k < @tempArray; $k++ ) {
    $tempArray[$k] =~  s/\s+//;
    if ($tempArray[$k] =~ /(hs|mm)\.(\d+)/i) { # cluster
      if( defined $query2cid{lc($tempArray[$k])} ) {
        my ($tmp_cid, $tmp_sym, $tmp_title) =
                   split "\t", $query2cid{lc($tempArray[$k])};
        $temp = $org1 . "." . $tmp_cid;
        for $accession (keys %{ $ug_access_to_clones{$tmp_cid} }) {
          push @s, "$tempArray[$k]\t$tmp_sym\t$tmp_title\t$temp\t$accession\t" .
                             "$ug_access_to_clones{$tmp_cid}{$accession}\n";
        }
      }
      else {
        push @bad,  $tempArray[$k] . "\n";
      }
    }
    elsif( defined $query2cid{$tempArray[$k]} ) {
      my ($tmp_cid, $tmp_sym, $tmp_title) =
                   split "\t", $query2cid{$tempArray[$k]};
      $temp = $org1 . "." . $tmp_cid;
      for $accession (keys %{ $ug_access_to_clones{$tmp_cid} }) {
        push @s, "$tempArray[$k]\t$tmp_sym\t$tmp_title\t$temp\t$accession\t" .
                           "$ug_access_to_clones{$tmp_cid}{$accession}\n";
      }
      ## delete $tempArray[$k];
      ## splice @tempArray, $k, 1;
    }
    else{
      push @bad,  $tempArray[$k] . "\n";
    }
  }
    
 
  ## for ($i = 0; $i < scalar(@rows); $i++) {
  ##  $temp = $org1 . "." . $rows[$i];
  ##  if( defined ($ug_access_to_clones{$rows[$i]}) ) {
  ##    for $accession (keys %{ $ug_access_to_clones{$rows[$i]} }) {
  ##      my ($tmp_sym, $tmp_title) = split "\t", $ug_syms{$rows[$i]};
  ##      push @s, "$temp\t$tmp_sym\t$tmp_title\t$temp\t$accession\t" .
  ##          "$ug_access_to_clones{$rows[$i]}{$accession}\n";
  ##    }
  ##    push @good, $temp;
  ##  }
  ## }
    
  if( @bad > 0 ) {
    push @s, (join "", @bad);
  }
    
  return (join "", @s);
}

######################################################################
sub GetUGCloneList {
 
  my ($org, $refer, $clone_info, $accs_ref, $lls_ref,
                    $items_in_memory, $tempArray_ref, $query2cid_ref) = @_;
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my @accs = @{$accs_ref};
  my @lls = @{$lls_ref};
  my $i;
  my ($sql, $stm);
  my $list;
  my %clu2accimageid;
  my $title;
  my ($acc_list, $ll_list, $a, $l);
    
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }
    
  $sql =
      "select " .
        "u.CLUSTER_NUMBER, m.ACCESSION, m.IMAGE_ID " .
      "from " .
        "$CGAP_SCHEMA.MGC_MRNA m, $CGAP_SCHEMA.mgc_organism g, " .
        "$CGAP_SCHEMA.$cluster_table{$org} u " .
      "where " .
        "g.org_code = m.organism and g.org_abbrev = '$org' " .
        "and u.locuslink(+) = m.locuslink " .
        "and m.clone_status = 'A'";
 
  $stm = $db->prepare($sql);
 
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  else {
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
 
    my ( $cluster_number, $accession, $image_id);
    $stm->bind_columns( \$cluster_number, \$accession, \$image_id );
 
    while($stm->fetch) {
      $clu2accimageid{$cluster_number} = $accession . "\t" . $image_id;
    }
  }
    
  my $table_name1 =
      ($org eq "Hs" ? "$CGAP_SCHEMA.HS_UG_CLONES" : "$CGAP_SCHEMA.MM_UG_CLONES");
  my $table_name2 =
      ($org eq "Hs" ? "$CGAP_SCHEMA.HS_CLUSTER" : "$CGAP_SCHEMA.MM_CLUSTER");
 
  for($i = 0; $i < @{$refer}; $i += ORACLE_LIST_LIMIT) {
 
    if(($i + ORACLE_LIST_LIMIT - 1) < @{$refer}) {
      $list = join(",", @{$refer}[$i..$i+ORACLE_LIST_LIMIT-1]);
    }
    else {
      $list = join(",", @{$refer}[$i..@{$refer}-1]);
    }
 
    $sql = "select g.GENE, c.CLUSTER_NUMBER, c.ACCESSION, c.IMAGE_ID, " .
        "c.LENGTH, c.END, c.TYPE, g.DESCRIPTION " .
        "from $table_name1 c, $table_name2 g " .
        "where " .
        "c.CLUSTER_NUMBER in (" .  $list . " ) " .
        "and c.CLUSTER_NUMBER = g.CLUSTER_NUMBER";
 
    &debug_print( "sql in UGClone: $sql");
    &debug_print( "\n");
 
    $stm = $db->prepare($sql);
 
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    else {
      if(!$stm->execute()) {
        ## print STDERR "$sql\n";
        ## print STDERR "$DBI::errstr\n";
        print "execute call failed\n";
        $db->disconnect();
        return "";
      }
 
      my ($symbol, $cluster_number, $accession, $image_id, $length,
          $end, $type);
 
      $stm->bind_columns(\$symbol, \$cluster_number, \$accession,
          \$image_id, \$length, \$end, \$type, \$title);
 
      while($stm->fetch) {
        $symbol or $symbol = "-";
        &debug_print ("$symbol, $cluster_number, $accession, " .
            "$image_id, $length, $end, $type \n");
        if( defined $clu2accimageid{$cluster_number} ) {
          my ($acc, $id) = split "\t", $clu2accimageid{$cluster_number};
          $type = "MGC";
          $accession = $acc;
          $image_id = $id;
          $length = "";
          $end = "";
        }
        $$clone_info{$cluster_number}{$accession} =
             join "\t", $image_id, $length, $end, $type;
        my $tmp_cid =
          ($org eq "Hs" ? "hs.$cluster_number" : "mm.$cluster_number");
        $$query2cid_ref{$tmp_cid} = $cluster_number . "\t" . $symbol . "\t" . $title;
      }
    }
  }
    
  if (@accs) {
    for ($a = 0; $a < @accs; $a += ORACLE_LIST_LIMIT) {
      if (($a + ORACLE_LIST_LIMIT - 1) < @accs) {
        $acc_list = "'" . join("','", @accs[$a..$a+ORACLE_LIST_LIMIT-1]) . "'";
      } else {
        $acc_list = "'" . join("','", @accs[$a..$#accs]) . "'";
      }
 
      my $ug_sequence =
        ($org eq "Hs") ? "$CGAP_SCHEMA.hs_ug_sequence" : "$CGAP_SCHEMA.mm_ug_sequence";
 
      $sql = "select g.GENE, c.CLUSTER_NUMBER, c.ACCESSION, c.IMAGE_ID, " .
        "c.LENGTH, c.END, c.TYPE, g.DESCRIPTION, u.ACCESSION " .
        "from $table_name1 c, $table_name2 g, $ug_sequence u " .
        "where " .
        "u.ACCESSION in (" . $acc_list . " ) " .
        "and c.CLUSTER_NUMBER = g.CLUSTER_NUMBER " .
        "and u.CLUSTER_NUMBER = g.CLUSTER_NUMBER " .
        "and u.CLUSTER_NUMBER = c.CLUSTER_NUMBER ";
 
      $stm = $db->prepare($sql);
 
      if(not $stm) {
        ## print STDERR "$sql\n";
        ## print STDERR "$DBI::errstr\n";
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      else {
        if(!$stm->execute()) {
          ## print STDERR "$sql\n";
          ## print STDERR "$DBI::errstr\n";
          print "execute call failed\n";
          $db->disconnect();
          return "";
        }
 
        my ($symbol, $cluster_number, $accession, $image_id, $length,
                                                     $end, $type, $query_accs);
        $stm->bind_columns(\$symbol, \$cluster_number, \$accession,
                    \$image_id, \$length, \$end, \$type, \$title, \$query_accs); 
        while($stm->fetch) {
          $symbol or $symbol = "-";
          &debug_print ("$symbol, $cluster_number, $accession, " .
                               "$image_id, $length, $end, $type \n");
          if( defined $clu2accimageid{$cluster_number} ) {
            my ($acc, $id) = split "\t", $clu2accimageid{$cluster_number};
            $type = "MGC";
            $accession = $acc;
            $image_id = $id;
            $length = "";
            $end = "";
          }
          $$clone_info{$cluster_number}{$accession} =
               join "\t", $image_id, $length, $end, $type;
          $$query2cid_ref{$query_accs} = $cluster_number . "\t" . $symbol . "\t" . $title;
 
        }
      }
    }
  }

  if (@lls) {
    for ($l = 0; $l < @lls; $l += ORACLE_LIST_LIMIT) {
      if (($l + ORACLE_LIST_LIMIT - 1) < @lls) {
        $ll_list = join(",", @lls[$l..$l+ORACLE_LIST_LIMIT-1]);
      } else {
        $ll_list = join(",", @lls[$l..$#lls]);
      }
 
      $sql = "select g.GENE, c.CLUSTER_NUMBER, c.ACCESSION, c.IMAGE_ID, " .
        "c.LENGTH, c.END, c.TYPE, g.DESCRIPTION, g.LOCUSLINK " .
        "from $table_name1 c, $table_name2 g " .
        "where " .
        "g.LOCUSLINK in (" . $ll_list . " ) " .
        "and c.CLUSTER_NUMBER = g.CLUSTER_NUMBER ";
 
      $stm = $db->prepare($sql);
 
      if(not $stm) {
        ## print STDERR "$sql\n";
        ## print STDERR "$DBI::errstr\n";
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      else {
        if(!$stm->execute()) {
          ## print STDERR "$sql\n";
          ## print STDERR "$DBI::errstr\n";
          print "execute call failed\n";
          $db->disconnect();
          return "";
        }
 
        my ($symbol, $cluster_number, $accession, $image_id, $length,
                                                     $end, $type, $locuslink);
        $stm->bind_columns(\$symbol, \$cluster_number, \$accession,
                    \$image_id, \$length, \$end, \$type, \$title, \$locuslink);
        while($stm->fetch) {
          $symbol or $symbol = "-";
          &debug_print ("$symbol, $cluster_number, $accession, " .
                               "$image_id, $length, $end, $type \n");
          if( defined $clu2accimageid{$cluster_number} ) {
            my ($acc, $id) = split "\t", $clu2accimageid{$cluster_number};
            $type = "MGC";
            $accession = $acc;
            $image_id = $id;
            ## $length = "";
            $end = "";
          }
          $$clone_info{$cluster_number}{$accession} =
               join "\t", $image_id, $length, $end, $type;
          $$query2cid_ref{$locuslink} = $cluster_number . "\t" . $symbol . "\t"
. $title;
 
        }
      }
    }
  }
}
 
######################################################################
sub OrderGenesBySymbol {

  my ($page, $org, $refer, $symbol_loc2info_ref) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my %hs_cid2sym;
  my %mm_cid2sym;
  my @ordered_genes;
  my @tempArray;
  my $sql_lines;
  my %by_symbol;
  my ($sql, $stm);
  my $key;
  my ($list, $cid, $gene);
  my ($i, $k, $m);
  my $temp;
  my $j=0;

  my $total = @{$refer};
  &debug_print("org: $org \n");
  &debug_print("total in: $total \n");

  my ($cluster_number, $symbol, $title, $loc, $gb);

  if( defined $symbol_loc2info_ref and $symbol_loc2info_ref ne "" ) {
    for my $symbol (keys %{$symbol_loc2info_ref}) {
      for my $loc (keys %{$$symbol_loc2info_ref{$symbol}}) {
        for my $cid (keys %{$$symbol_loc2info_ref{$symbol}{$loc}}) {
          push @{$by_symbol{$symbol}}, $$symbol_loc2info_ref{$symbol}{$loc}{$cid};
        }
      }
    }
  }

  if( @{ $refer } ) {

    my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
    if (not $db or $db->err()) {
      ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
      print "Cannot connect to database\n";
      return "";
    }

    &debug_print ("start ordering. \n");


    for($i = 0; $i < @{$refer}; $i += ORACLE_LIST_LIMIT) {

      if(($i + ORACLE_LIST_LIMIT - 1) < @{$refer}) {
        $list = join(",", @{$refer}[$i..$i+ORACLE_LIST_LIMIT-1]);
      }
      else {
        $list = join(",", @{$refer}[$i..@{$refer}-1]);
      }

      my $table_name = ($org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster" : "$CGAP_SCHEMA.mm_cluster");

      $sql = "select CLUSTER_NUMBER, GENE, DESCRIPTION, LOCUSLINK, " .
             "SEQUENCES from " . $table_name . " where " .
             " CLUSTER_NUMBER in (" .  $list . " )";

      $stm = $db->prepare($sql);

      if(not $stm) {
        ## print STDERR "$sql\n";
        ## print STDERR "$DBI::errstr\n";
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      else {

        if(!$stm->execute()) {
          ## print STDERR "$sql\n";
          ## print STDERR "$DBI::errstr\n";
          $db->disconnect();
          return undef;
        }

        $stm->bind_columns(\$cluster_number, \$symbol, \$title, \$loc, \$gb);

        while($stm->fetch) {
           
          $temp =  "$cluster_number\001$symbol\001$title\001$loc\001$gb";

          if( $symbol ne "" ) {

             push @{$by_symbol{$symbol}}, $temp;
          }
          else {
            push @tempArray, $temp;
          }
        }
      }
    }

    $db->disconnect();

  }

  for $symbol (sort keys %by_symbol) {
    foreach $temp ( @{$by_symbol{$symbol}} ) {
      push @ordered_genes, $temp;
    }
  }

  for ($i = 0; $i < @tempArray; $i++) {
    push @ordered_genes, $tempArray[$i];
  }

  &debug_print ("finish ordering. \n");

  return \@ordered_genes;

}

######################################################################
sub OrderGenesByInput {

  my ($page, $org, $refer, $input_ref, $cid2info_ref, $input2loc_ref) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my @ordered_genes;
  my @tempArray;
  my $sql_lines;
  my ($sql, $stm);
  my $key;
  my ($list, $cid, $gene);
  my %cid2info; 
  my $total = @{$refer};
  my ($cluster_number, $symbol, $title, $loc, $gb);
  my %cid_input;

  my $table_name = 
      ($org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster" : "$CGAP_SCHEMA.mm_cluster");

  if( defined $cid2info_ref and $cid2info_ref ne "" ) {
    for my $cluster_id (keys %{$cid2info_ref}) {
      for my $input (keys %{$$cid2info_ref{$cluster_id}}) {
        ## $cid2info{$cluster_id}{$input} = $$cid2info_ref{$cluster_id}{$input};
        $cid_input{$cluster_id}{$input} = 1;
      }
    }
  }

  if( @{ $refer } ) {

    my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
    if (not $db or $db->err()) {
      ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
      print "Cannot connect to database\n";
      return "";
    }

    for(my $i = 0; $i < @{$refer}; $i += ORACLE_LIST_LIMIT) {

      if(($i + ORACLE_LIST_LIMIT - 1) < @{$refer}) {
        $list = join(",", @{$refer}[$i..$i+ORACLE_LIST_LIMIT-1]);
      }
      else {
        $list = join(",", @{$refer}[$i..@{$refer}-1]);
      }

      $sql = "select CLUSTER_NUMBER, GENE, DESCRIPTION, LOCUSLINK, " .
             "SEQUENCES from " . $table_name . " where " .
             " CLUSTER_NUMBER in (" .  $list . " )";

      $stm = $db->prepare($sql);

      if(not $stm) {
        ## print STDERR "$sql\n";
        ## print STDERR "$DBI::errstr\n";
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      else {

        ## my $t0 = [gettimeofday]; 
        if(!$stm->execute()) {
          ## print STDERR "$sql\n";
          ## print STDERR "$DBI::errstr\n";
          print "execute call failed\n";
          $db->disconnect();
          return undef;
        }
        $stm->bind_columns(\$cluster_number, \$symbol, \$title, \$loc, \$gb);
        while($stm->fetch) {
          $cid2info{$cluster_number} = 
             "$cluster_number\001$symbol\001$title\001$loc\001$gb";
        }
        ## my $elapsed = tv_interval ($t0, [gettimeofday]);
        ## print "8888  order $elapsed\n<br>";
      }
    }
  }

  for ( my $i=0; $i<@{$input_ref}; $i++ ) {
    if( defined $input2cid{$$input_ref[$i]} ) { 
      for my $cid ( keys %{ $input2cid{$$input_ref[$i]} } ) {
        if( defined $cid_input{$cid}{$$input_ref[$i]} ) {
          push @ordered_genes, $$input_ref[$i] . "\001" . 
                  $$cid2info_ref{$cid}{$$input_ref[$i]}
                    ## $cid2info{$cid}{$$input_ref[$i]};
        }
        elsif ( defined $cid2info{ $cid } ) {
          my $output;
          if( defined $$input2loc_ref{$$input_ref[$i]} ) {
            my ($cluster_number, $symbol, $title, $loc, $gb) = split "\001", $cid2info{$cid};
            $output = "$cluster_number\001$symbol\001$title\001$$input2loc_ref{$$input_ref[$i]}\001$gb"; 
          }
          else {
            $output = $cid2info{$cid};
          } 
          push @ordered_genes, $$input_ref[$i] . "\001" . 
                  $output;
        }
      }
    }
  } 

  return \@ordered_genes;

}



######################################################################
sub InitQuery {
  my ($upto_wheres) = @_;
  $query = $upto_wheres;
  $where_flag = 0;
}

######################################################################
sub Add {
  my ($s) = @_;
  if ($s) {
    if (not $where_flag) {
      $where_flag = 1;
      $query = "$query where $s"
    } else {
      $query = "$query and $s";
    }
  }
}


## assume a table clus2lib (build_id, cluster_number, ug_lib_id)

######################################################################
sub BuildSQL {
  my ($org1, $sym1, $title1, $go1, $pathway1, $cyt1, $tissue) = @_;

  if( not defined $cluster_table{$org1} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($go_num, $go_name);

  my $tissue_only = ($tissue and not
      ($title1 or $go1 or $pathway1 or $cyt1));

  ## tissue_only queries are much faster if we don't join with
  ## ug_cluster

  my $table_name = ($org1 eq "Hs" ? " $CGAP_SCHEMA.hs_gene_tissue b " :
                                    " $CGAP_SCHEMA.mm_gene_tissue b ");

  my $gene_cluster_table = ($org1 eq "Hs" ? " $CGAP_SCHEMA.hs_cluster c " :
                                            " $CGAP_SCHEMA.mm_cluster c ");

  my $gene_tissue_table = ($org1 eq "Hs" ? " $CGAP_SCHEMA.hs_gene_tissue c " :
                                           " $CGAP_SCHEMA.mm_gene_tissue c ");

  my $keyword_table = ($org1 eq "Hs" ? "hs_gene_keyword" : "mm_gene_keyword");

  if ($tissue_only) {
    InitQuery("select distinct b.cluster_number from $table_name,
        $CGAP_SCHEMA.tissue_selection s");
  } elsif ($go1) {
    if ($go1 =~ /[0-9]{7}/) {
      $go_num = $go1;
      $go_num =~ s/GO://;
    } else {
      $go_name = $go1;
    }
    InitQuery(
        "select distinct c.cluster_number from $gene_cluster_table" .
        ($tissue  ? ", $table_name, $CGAP_SCHEMA.tissue_selection s " : "") .
        ($title1  ? ", $CGAP_SCHEMA.$keyword_table k" : "") .
        ($go_num || $go_name  ?
            ", $CGAP_SCHEMA.ll_go g, $CGAP_SCHEMA.go_ancestor a" : "") .
        ($go_name     ? ", $CGAP_SCHEMA.go_name n" : "") .
        ($cyt1    ? ", $CGAP_SCHEMA.cyto t"          : "") 
    );
  } elsif($tissue) {
    InitQuery(
        "select distinct c.cluster_number from $gene_tissue_table, " .
            "$CGAP_SCHEMA.tissue_selection s " .
        ($title1   ? ", $CGAP_SCHEMA.$keyword_table k" : "") .
        ($cyt1     ? ", $CGAP_SCHEMA.cyto t"         : "") 
    );
  }
  else {
    InitQuery(
        "select distinct c.cluster_number from $gene_cluster_table " .
        ($title1   ? ", $CGAP_SCHEMA.$keyword_table k" : "") .
        ($cyt1     ? ", $CGAP_SCHEMA.cyto t"         : "") 
    );
  }

  my $build_id = $BUILDS{$org1};

  if ($title1) {
    Add("c.cluster_number = k.cluster_number");
  }

  if ($go_num || $go_name) {
    Add("c.locuslink = g.ll_id");
  }

  if ($cyt1) {
    Add("t.cluster_number = c.cluster_number");
    Add("t.build_id = $build_id");
  }

  if ($title1) {
    my $title2 = $title1;
    $title2 =~ tr/A-Z/a-z/;
    $title2 =~ s/\*/%/g;
    $title2 =~ s/ +/ /g;
    $title2 =~ s/^ //;
    $title2 =~ s/ $//;
    my @temp;
    for my $i (split " ", $title2) {
      push @temp, "k.keyword like '$i'";
    }
    Add("(" . join(" or ", @temp) . ")");
  }

  if ($tissue) {
    if( $tissue_only ) {
      Add("b.tissue_code = s.tissue_code");
      Add("s.tissue_name='$tissue'");
    }
    elsif( !($go_num || $go_name) ) {
      Add("c.tissue_code = s.tissue_code");
      Add("s.tissue_name='$tissue'");
    }
    else {
      Add("b.cluster_number = c.cluster_number");
      Add("b.tissue_code = s.tissue_code");
      Add("s.tissue_name='$tissue'");
    }
  }

  if ($go_name) {
    my $lower_go = $go_name;
    $lower_go =~ tr/A-Z/a-z/;
    $lower_go =~ s/\*/%/g;
    $lower_go =~ s/'/`/g;
    $lower_go =~ s/ +/ /g;
    $lower_go =~ s/^ //;
    $lower_go =~ s/ $//;
    Add("lower(n.go_name) like '$lower_go'");
    Add("a.go_ancestor_id = n.go_id");
    Add("g.go_id = a.go_id");
  } elsif ($go_num) {
    Add("a.go_ancestor_id = $go_num");
    Add("g.go_id = a.go_id");
  }

  if ($cyt1) {
    my ($chr,$low,$high);
    if ($org1 eq 'Hs') {
      ($chr,$low,$high) = TransformHsCyt($cyt1);
    } else {
      ($chr,$low,$high) = TransformMmCyt($cyt1);
    }
    Add("t.chr = '$chr'");
    Add("((t.low>=$low and t.low<=$high) or
        (t.high>=$low and t.high<=$high))");
  }

  &debug_print(" sql in BuildSQL: $query \n" );

  return $query;
}

######################################################################
sub LibsOfTissue {
  my ($db, $org, $tissue) = @_;
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my $sql =
    "select distinct a.unigene_id " . 
    "from $CGAP_SCHEMA.all_libraries a, $CGAP_SCHEMA.library_keyword w " .
    "where a.library_id = w.library_id and " .
    "a.org = '$org' and " .
    "a.unigene_id is not null and " .
    "w.keyword in ('" .
        join("', '", split(",", $tissue)) .
    "')";
  my (@row, @libset);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (@row = $stm->fetchrow_array()) {
        push @libset, $row[0];
      }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  return @libset;

}

######################################################################
sub GetGene_1 {

  my ($base, $page, $org1, $sym1, $title1, $go1, $pathway1, $cyt1,
      $tissue1) = @_;

  if( not defined $cluster_table{$org1} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  $BASE = $base;

  my ($libset);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  ##
  ## Check for legal GO name
  ##

  if (($go1 ne "") && ($go1 !~ /[0-9]{7}/)) {
    my $go2 = $go1;
    $go2 =~ tr/A-Z/a-z/;
    $go2 =~ s/'/`/g;
    $go2 =~ s/\*/%/g;
    my $sql = "select distinct go_name from $CGAP_SCHEMA.Go_Name " .
            "where lower(go_name) like '$go2'";

    my ($name, @names);
    my $stm = $db->prepare($sql);
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    } else {
      if ($stm->execute()) {
        $stm->bind_columns(\$name);
        while ($stm->fetch) {
          push @names, $name
        }
        if (@names == 0) {
          ## SetStatus(S_NO_DATA);
          return "<B>No Gene Ontology Names match the term \"$go1\"<B>";
        }
      } else {
        print "execute failed\n";
        $db->disconnect();
        return "";
      }
    }
  }

  ##
  ## Tried to include the libs-of-tissue subquery in the main
  ## query, and the result is something that runs like molasses,
  ## so we'll pull it out and execute it separately
  ##
  #if ($tissue1) {
  #  $libset = join(",", LibsOfTissue($db, $org1, $tissue1));
  #}

  my $sql = BuildSQL($org1, $sym1, $title1, $go1, $pathway1, $cyt1, 
      $tissue1);

  my (@row, @rows);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (@row = $stm->fetchrow_array()) {
        push @rows, $row[0];
      }
      ## if (@rows == 0) {
        ## SetStatus(S_NO_DATA);
      ## }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }
  $db->disconnect();

  my $cmd = "GeneQuery?" .
      "ORG=$org1&" .
      "SYM=$sym1&" .
      "TITLE=$title1&" .
      "CUR=$go1&" .
      "PATH=$pathway1&" .
      "CYT=$cyt1&" .
      "TISSUE=$tissue1";

  my $hs_bld = $BUILDS{'Hs'};  $hs_bld =~ s/^1//;
  my $mm_bld = $BUILDS{'Mm'};  $mm_bld =~ s/^2//;

  my $page_header = "<table><tr valign=top>" .
      "<td><b>GeneFinder Results For</b>:</td>" .
      "<td>" .
          "$org1; " .
          ($title1   ? $title1   . "; " : "") .
          ($go1      ? $go1      . "; " : "") .
          ($cyt1     ? $cyt1     . "; " : "") .
          ($pathway1 ? $pathway1 . "; " : "") .
          ($tissue1  ? $tissue1  . "; " : "") .
          "</td></tr>" .
      "<tr><td><b>UniGene Build</b>:</td>" .
      "<td>Hs.$hs_bld/Mm.$mm_bld</td></tr></table>";

  if ($page == $CLONE_PAGE) {
    return (FormatGenes($page, $org1, $cmd, $page_header, \@rows));
  }
  else {
    return
      (FormatGenes($page, $org1, $cmd, $page_header,
       OrderGenesBySymbol($page, $org1, \@rows)));
  }
}

######################################################################
sub TransformHsCyt {
  my ($cyt) = @_;

  my ($chr, $low, $high);
  my (@terms, $i, $c);

  ## for mouse and human, trim leading, trailing, multiple spaces
  $cyt =~ s/ +/ /g;
  $cyt =~ s/^ +//;
  $cyt =~ s/ +$//;
  
  ## for mouse and human, standardize ranges and alternatives
  $cyt =~ s/ or / , /ig;
  $cyt =~ s/ *- */-/g;
  $cyt =~ s/ *, */,/g;

  $cyt =~ s/\s//g;
  $cyt = lc($cyt);
  $cyt =~ tr/xy/XY/;

  ## for human
  ## watch out for alternatives
  $c = $cyt;
  for $cyt (split ",", $c) {
    $chr = $low = $high = "";
    $cyt =~ /^(X|Y|\d+)(.*)$/;       ## grab the chromosome
    $chr = $1;
    $cyt = $2;
    @terms = split "-", $cyt;
    for ($i = 0; $i < @terms; $i++) {
      $terms[$i] =~ s/^p//;
      $terms[$i] =~ s/^q/-/;
##      $terms[$i] =~ s/(tel|ter)/200/;
      $terms[$i] =~ s/(tel|ter)/201/;   ## distinguish "pter" from "p"
      $terms[$i] =~ s/cen/0/;
      if ($terms[$i] =~ /^-?$/) {
        $terms[$i] = "$terms[$i]200";   ## bare 'q' or 'p'
      }
    }
    if (@terms == 0) {
      $low  = -200;                     ## bare chromosome
      $high = 200;
    } elsif (@terms == 1) {
      if ($terms[0] == 200) {           ## bare 'p'
        $low  = 0;
        $high = 200;
      } elsif ($terms[0] == -200) {     ## bare 'q'
        $low  = -200;
        $high = 0;
      } elsif ($terms[0] == 201) {
        $low  = 199.99;
        $high = 200;
      } elsif ($terms[0] == -201) {
        $low  = -200;
        $high = -199.99;
      } else {                          ## numbered band
        $low = $high = $terms[0];
      }
    } else {
      if ($terms[1] =~ /^\.(\d+)$/) {
	$terms[0] =~ /(-?)(\d+)(.*)$/;
        $terms[1] = "$1" . "$2" . "$terms[1]";
      }
      if ($terms[0] < $terms[1]) {
        $low  = $terms[0];
        $high = $terms[1];
      } else {
        $low  = $terms[1];
        $high = $terms[0];
      }
    }
    $low  = -200 if $low  == -201;
    $high =  200 if $high ==  201;
    if ($low < 0) {
      if ($low !~ /\./) {
        $low = "$low.99";
      } elsif ($low !~ /\.\d\d/) {
        $low = $low . "9";
      }
    }
    if ($high > 0) {
      if ($high !~ /\./) {
        $high = "$high.99";
      } elsif ($high !~ /\.\d\d/) {
        $high = $high . "9";
      }
    }

    return ($chr, $low, $high);

  }

}

######################################################################
sub TransformMmCyt {
  my ($cyt) = @_;

  my ($chr, $low, $high);

  ## for mouse and human, trim leading, trailing, multiple spaces
  $cyt =~ s/ +/ /g;
  $cyt =~ s/^ +//;
  $cyt =~ s/ +$//;
  
  ## for mouse and human, standardize ranges and alternatives
  $cyt =~ s/ or / , /ig;
  $cyt =~ s/ *- */-/g;
  $cyt =~ s/ *, */,/g;

  $cyt =~ s/ ?cm//i;
  $cyt =~ tr/xy/XY/;
  ## for mouse
  ## mouse data appears not to have alternatives
  if (not $cyt =~ / [a-h]/i) {
    ## radiation hybrid; no ranges
##    $cyt =~ s/ cM$//;
    split " ", $cyt;
    $chr = $_[0];
    $low = $high = $_[1];
    if (not $low) {
      $low = -200;
      $high = 200;  
    }
  } else {
    ## A-H style, maybe just a bare chromosome
    split " ", $cyt;
    $chr = $_[0];
    if (@_ > 1) {     ## has band designator(s)
      $_[1] =~ tr/[A-H]/[1-8]/;
##      print "$_[1]\n";
      my @x = split "-", $_[1];  ## look for a range
      if (@x == 1) {     ## is not a range
        if (length($_[1])==1) {
	  $high = -$_[1] * 10;
          $low = $high - 9;
        } else {
          $low = $high = "-$_[1]";
        }
      } else {           ## is a range
        ## order in ranges is standardized
        $low  = "-$x[1]";
        $high = "-$x[0]";
      }
      $low  =~ s/^(\d\.)(\d)$/$1$2\9/;
      if ($low !~ /\./) {
        $low = "$low.99";
      } elsif ($low =~ /\.(\d)$/) {
	$low = $low . "9";
      }
    } else {          ## bare chromosome
      $low  = -200;
      $high = 200;
    }
  }

  return ($chr, $low, $high);

}

######################################################################
my %mgc_status_codes = (
  'A' => "Full Length",
  'B' => "Incomplete",
  'C' => "No CDS",
  'D' => "TBD",
  'K' => "Dropped: 3",      ## "Chimeric",
  'L' => "Dropped: 4",      ## "Frame Shifted",
  'M' => "Dropped: 5",      ## "Contaminated",
  'N' => "Dropped: 6",      ## "Incomplete Processing",
  'S' => "Dropped: 100",    ## "Mixed wells",
  'T' => "Dropped: 101",    ## "No growth",
  'U' => "Dropped: 102",    ## "No insert",
  'V' => "Dropped: 103",    ## "No 5' EST match",
  'W' => "Dropped: 104",    ## "No cloning site/microdeletion"
);

######################################################################
sub GetMGCClonesOfCluster {
  my ($db, $org, $cid) = @_;
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my $build_id = $BUILDS{$org};
  my $sql =
      "select distinct " .
        "m.image_id, m.clone_status, m.accession, m.defline " .
      "from " .
        "$CGAP_SCHEMA.mgc_mrna m, $CGAP_SCHEMA.mgc_organism g, " .
        "$CGAP_SCHEMA.$cluster_table{$org} u " .
      "where " .
        "g.org_abbrev = '$org' and g.org_code = m.organism " .
        "and u.locuslink = m.locuslink " .
        "and u.cluster_number = $cid " .
        "and m.accession is not null " .
      "order by m.clone_status, m.image_id, m.accession";

  ## 0 image_id
  ## 1 clone_status
  ## 2 accession
  ## 3 def line

  my ($image_id, $clone_status, $accession, $defline, @lines);

  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (($image_id, $clone_status, $accession, $defline)
          = $stm->fetchrow_array()) {
        $defline or $defline = "&nbsp;";
        push @lines, 
            "<tr valign=top>" .
            "<td><a href=javascript:spawn(\"" . "http://mgc.nci.nih.gov" .
              "/Reagents/CloneInfo?ORG=$org&IMAGE=$image_id\")>" .
              "$image_id</a></td>" .
            "<td>$mgc_status_codes{$clone_status}</td>" .
            "<td><a href=javascript:spawn(" .
              "\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?" .
              "db=Nucleotide&" .
              "CMD=Search&term=$accession\")>$accession</a></td>" .
              "<td>$defline</td></tr>";
      }
    }
    else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  if (@lines) {
    return
        "<table border=1 cellspacing=1 cellpadding=4>" .
        "<tr>" .
        "<th><font color=\"#38639d\"><b>IMAGE Id</b></font></th>" .
        "<th><font color=\"#38639d\"><b>Status</b></font></th>" .
        "<th><font color=\"#38639d\"><b>Accession</b></font></th>\n" .
        "<th><font color=\"#38639d\"><b>GenBank Def Line</b></font></th></tr>\n" .
        join("\n", @lines) .
        "</table>";
  } else { 
    return "";
  }

}


######################################################################
sub GetDiseaseInfo {
  my ($org, $db, $loc, $cid) = @_;

  my $sql =
      "select unique omim, disease " .
      "from $CGAP_SCHEMA.GENE_MIM_DISEASE " .
      "where LOCUSLINK = $loc order by disease";
 
  my (@lines, $omim, $disease, %exist);
 
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (($omim, $disease) = $stm->fetchrow_array()) {
        if( not defined $exist{$omim} ) {
          my $another_genes = Get_Other_Genes($org, $loc, $cid, $omim); 
          push @lines,
            "<tr valign=top>" .
            "<td align=left><a href=javascript:spawn(\"" . 
            "http://www.ncbi.nlm.nih.gov/" .
            "omim/$omim\")>" .
            "$disease</a></td>$another_genes</tr>";
          $exist{$omim} = 1;
        }
      }
    }
    else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }
 
  if (@lines) {
    return
        "<center><table border=1 cellspacing=1 cellpadding=4>" .
        "<tr>" .
        "<th><font color=\"#38639d\"><b>Disease</b></font></th>" .
        "<th><font color=\"#38639d\"><b>Other Genes</b></font></th><tr>" .
        join("\n", @lines) .
        "</table></center>";
  } else {
    return "";
  }
 
}
 
######################################################################
sub GetFusionGeneInfo {
  my ($BASE, $org, $db, $sym) = @_;
 
  my (@lines_M, @lines_C);

  my $sql =
      "select distinct r.Abbreviation, r.journal, c.Refno, c.InvNo, c.Morph, " .      
      "c.Top, c.KaryShort, c.Geneshort, c.immunology " .
      "from $CGAP_SCHEMA.MolBiolClinAssoc c, $CGAP_SCHEMA.Reference r, " .
      "$CGAP_SCHEMA.MolClinGene k where c.Refno = r.Refno and " .
      "c.MolClin = 'M' and c.RefNo = k.RefNo and c.InvNo = k.InvNo and " .
      "k.molclin = 'M' and ( k.gene like '$sym/%' or k.gene like '%/$sym' ) "; 

 
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while ( my ($Abbreviation, $journal, $Refno, $InvNo, $Morph, 
                  $Top, $KaryShort, $Geneshort, $immunology) 
                                     = $stm->fetchrow_array()) {
        push @lines_M, join ("\t", $Abbreviation, $journal, $Refno, $InvNo, 
                                  $Morph, $Top, $KaryShort, $Geneshort, 
                                  $immunology );
      }
    }
    else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }
 
    my $sql =
      "select distinct r.Abbreviation, r.journal, c.Refno, c.InvNo, c.Morph, " .            
      "c.Top, c.KaryShort, c.Geneshort, c.immunology " .
      "from $CGAP_SCHEMA.MolBiolClinAssoc c, $CGAP_SCHEMA.Reference r, " .
      "$CGAP_SCHEMA.MolClinGene k where c.Refno = r.Refno and " .
      "c.MolClin = 'C' and c.RefNo = k.RefNo and c.InvNo = k.InvNo and " .
      "k.molclin = 'C' and ( k.gene like '$sym/%' or k.gene like '%/$sym' ) ";
 
 
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while ( my ($Abbreviation, $journal, $Refno, $InvNo, $Morph,
                  $Top, $KaryShort, $Geneshort, $immunology)
                                     = $stm->fetchrow_array()) {
        push @lines_C, join ("\t", $Abbreviation, $journal, $Refno, $InvNo,
                                  $Morph, $Top, $KaryShort, $Geneshort,
                                  $immunology );
      }
    }
    else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }
 

  my ($M_line, $C_line);
  if (@lines_M) {
    $M_line = 
           "<table><tr>" .
           "<td><font color=\"#38639d\"><b>Molecular Biology Association List</b></font>:</td>" .
           "<td>" . ($org eq "Hs" && @lines_M ? "<a href=\"" . $BASE .
           "/Chromosomes/MCList_for_Gene_info?base=BASE&op=M&page=1&gene=$sym\">" .
        "Mitelman Fusion Gene Data For Molecular Biology</a>" : " ") . "</td></tr></table>";
  }
  if (@lines_C) {
    $C_line = 
           "<table><tr>" .
           "<td><font color=\"#38639d\"><b>Clinical Association List</b></font>:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>" .
           "<td>" . ($org eq "Hs" && @lines_C ? "<a href=\"" . $BASE .
           "/Chromosomes/MCList_for_Gene_info?base=BASE&op=C&page=1&gene=$sym\">" .
        "Mitelman Fusion Gene Data For Clinic</a>" : " ") . "</td></tr></table>";
  }
 
  if( $M_line or $C_line ) {
    return $M_line . $C_line; 
  }
  else {
    return "";
  }
}


######################################################################
sub FormatHomoloGeneDataOneRow {
  my ($row, $rows, $total_rows, $this_row_id) = @_;

  my %taxon_id2org = (9606 => "Hs", 10090 => "Mm");

  my ($taxon_id1, $org1, $loc1, $sym1, $cid1, $prot1,
      $taxon_id2, $org2, $loc2, $sym2, $cid2, $prot2,
      $similarity) = split("\t", $row);
  if (!$sym1) {
    $sym1 = "\&nbsp;";
  }
  if (!$sym2) {
    $sym2 = "\&nbsp;";
  }
  push @{ $rows }, "<tr>";
  if ($total_rows > 0 && $this_row_id == 1) {
    push @{ $rows }, "<td rowspan=$total_rows valign=top>$org1</td>";
    push @{ $rows }, "<td rowspan=$total_rows valign=top>$sym1</td>";
    push @{ $rows }, "<td rowspan=$total_rows valign=top><a href=\""
        . GENPEPT_URL($prot1) . "\">$prot1</a></td>";
   } elsif ($total_rows < 0) {
    push @{ $rows }, "<td>$org1</td>";
    push @{ $rows }, "<td>$sym1</td>";
    push @{ $rows }, "<td><a href=\"" . GENPEPT_URL($prot1) .
        "\">$prot1</a></td>";
  }
  push @{ $rows }, "<td>$org2</td>";
  push @{ $rows }, "<td>$sym2</td>";
  if ($loc2) {
    push @{ $rows }, "<td><a href=\"" . ENTREZ_GENE_URL($loc2) .
        "\">$loc2</a></td>";
  } else {
    push @{ $rows }, "<td>\&nbsp;</td>";
  }
  if ($cid2) {
    push @{ $rows }, "<td><a href=\"" .
        GENE_INFO_URL($taxon_id2org{$taxon_id2}, $cid2) .
        "\">Gene Info</a></td>";
  } else {
    push @{ $rows }, "<td>\&nbsp;</td>";
  }
  push @{ $rows }, "<td><a href=\"" . GENPEPT_URL($prot2) .
      "\">$prot2</a></td>";
  push @{ $rows }, "<td>$similarity</td>";
  push @{ $rows }, "</tr>";

}

######################################################################
sub FormatHomoloGeneData {
  my ($org, $ll_id, $data) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my (@rows, $rowcount);
  if (scalar(keys %{ $data }) > 1) {
    $rowcount = -1;
  } else {
    for my $loc1 (sort keys %{ $data }) {
      for my $prot1 (sort keys %{ $$data{$loc1} }) {
        for my $sim (sort r_numerically keys %{ $$data{$loc1}{$prot1} }) {
          for my $org2 (sort keys %{ $$data{$loc1}{$prot1}{$sim} }) {
            $rowcount += @{ $$data{$loc1}{$prot1}{$sim}{$org2} };
          }
        }
      }
    }
  }
  my $r = 0;
  for my $loc1 (sort keys %{ $data }) {
    for my $prot1 (sort keys %{ $$data{$loc1} }) {
      for my $sim (sort r_numerically keys %{ $$data{$loc1}{$prot1} }) {
        for my $org2 (sort keys %{ $$data{$loc1}{$prot1}{$sim} }) {
          for my $row (@{ $$data{$loc1}{$prot1}{$sim}{$org2} }) {
            $r++;
            FormatHomoloGeneDataOneRow($row, \@rows, $rowcount, $r);
          }
        }
      }
    }
  }
  if (@rows) {
    unshift @rows, join("\n",
          "<table border=1 cellspacing=1 cellpadding=4>",
          "<tr>",
          "<td rowspan=2><font color=\"#38639d\"><b>Organism</b></font></td>",
          "<td rowspan=2><font color=\"#38639d\"><b>Symbol</b></font></td>",
          "<td rowspan=2><font color=\"#38639d\"><b>Protein</b></font></td>",
          "<td colspan=5 align=center><font color=\"#38639d\"><b>Homolog</b></font></td>",
          "<td rowspan=2><font color=\"#38639d\"><b>Similarity<br>(% aa unchanged)</b></font></td>",
          "</tr>",
          "<tr>",
          "<td><font color=\"#38639d\"><b>Organism</b></font></td>",
          "<td><font color=\"#38639d\"><b>Symbol</b></font></td>",
          "<td><font color=\"#38639d\"><b>Entrez<br>Gene</b></font></td>",
          "<td><font color=\"#38639d\"><b>Gene Info</b></font></td>",
          "<td><font color=\"#38639d\"><b>Protein</b></font></td>",
          "</tr>"
      );
    push @rows, "</table>";
  }
  return \@rows;
}

######################################################################
sub HomoloGeneData {
  my ($db, $org, $ll_id) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($sql, $stm);
  my ($entry_id, $taxon_id, $locus_id, $symbol, $prot_acc, $prot_len,
      $nuc_acc);
  my ($prot_acc1, $taxon_id1, $organism1,
      $prot_acc2, $taxon_id2, $organism2, $similarity);
  my (%entries, %acc2loc, %loc2sym);
  my ($cluster_number, %loc2cid, $locus_list);
  my %org2taxon_id = ("Hs" => 9606, "Mm" => 10090);

## It looks like any given entry may contain multiple LocusLink ids for a 
## given organism (athough 1 is typical), but it seems that a given
## LocusLink is associated with only one protein accession.

  ##
  ## Find entries
  ## 

  $sql = qq!
select
  e2.entry_id,
  e2.taxon_id,
  e2.locus_id,
  e2.symbol,
  e2.prot_acc,
  e2.prot_len,
  e2.nuc_acc
from
  $CGAP_SCHEMA.hg_entry e1,
  $CGAP_SCHEMA.hg_entry e2
where
      e1.locus_id = $ll_id
  and e1.entry_id = e2.entry_id
  !;

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return undef;
  }
  my ($row, $rowcache);
  while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
    for $row (@{ $rowcache }) {
      ($entry_id, $taxon_id, $locus_id, $symbol, $prot_acc, $prot_len,
          $nuc_acc) = @{ $row };
      $entries{$entry_id}{$taxon_id}{$locus_id} = 1;
      $acc2loc{$prot_acc} = $locus_id;
      $loc2sym{$locus_id} = $symbol;
      if ($taxon_id eq $org2taxon_id{"Hs"} ||
          $taxon_id eq $org2taxon_id{"Mm"}) {
        $loc2cid{$taxon_id}{$locus_id} = "";
      } 
    }
  }
 
  my $entry_list = join(",", keys %entries);

  ## 
  ## Find UniGene clusters for Hs
  ##  

  if (defined keys %{ $loc2cid{$org2taxon_id{"Hs"}} }) {
    $locus_list = join(",", keys %{ $loc2cid{$org2taxon_id{"Hs"}} });
    $locus_list =~ s/\s+//g;
    if( $locus_list ne "" ) {

      $sql = qq!
select
  c.cluster_number,
  c.locuslink
from
  $CGAP_SCHEMA.hs_cluster c
where
      c.locuslink in ( $locus_list )
      !;

      $stm = $db->prepare($sql);
      if(not $stm) {
        ## print STDERR "$sql\n";
        ## print STDERR "$DBI::errstr\n";
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      if(!$stm->execute()) {
        ## print STDERR "$sql\n";
        ## print STDERR "$DBI::errstr\n";
        print "execute call failed\n";
        $db->disconnect();
        return undef;
      }
      my ($row, $rowcache);
      while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
        for $row (@{ $rowcache }) {
          ($cluster_number, $locus_id) = @{ $row };
          $loc2cid{$locus_id} = $cluster_number;
        }
      }
    }
  }
 

  ## 
  ## Find UniGene clusters for Mm
  ##  

  if (defined keys %{ $loc2cid{$org2taxon_id{"Mm"}} }) {
    $locus_list = join(",", keys %{ $loc2cid{$org2taxon_id{"Mm"}} });
    $locus_list =~ s/\s+//g;
    if( $locus_list ne "" ) {

      $sql = qq!
  select
    c.cluster_number,
    c.locuslink
  from
    $CGAP_SCHEMA.mm_cluster c
  where
        c.locuslink in ( $locus_list )
      !;
  
      $stm = $db->prepare($sql);
      if(not $stm) {
        ## print STDERR "$sql\n";
        ## print STDERR "$DBI::errstr\n";
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      if(!$stm->execute()) {
        ## print STDERR "$sql\n";
        ## print STDERR "$DBI::errstr\n";
        print "execute call failed\n";
        $db->disconnect();
        return undef;
      }
      my ($row, $rowcache);
      while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
        for $row (@{ $rowcache }) {
          ($cluster_number, $locus_id) = @{ $row };
          $loc2cid{$locus_id} = $cluster_number;
        }
      }
    }
  }
 

  ##
  ## Find stats
  ##

  $entry_list =~ s/\s+//g;
  if( $entry_list ne "" ) {
    $sql = qq!
select
  s.entry_id,
  s.prot_acc1,
  s.taxon_id1,
  o1.short_name,
  s.prot_acc2,
  s.taxon_id2,
  o2.short_name,
  s.similarity
from
  $CGAP_SCHEMA.hg_stats s,
  $CGAP_SCHEMA.hg_organism o1,
  $CGAP_SCHEMA.hg_organism o2
where
      s.entry_id in ( $entry_list )
  and s.taxon_id1 = o1.taxon_id
  and s.taxon_id2 = o2.taxon_id
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>$sql Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
      return undef;
    }
  }
  my ($row, $rowcache, %data, $loc1, $loc2);
  while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
    for $row (@{ $rowcache }) {
      ($entry_id, $prot_acc1, $taxon_id1, $organism1, $prot_acc2, $taxon_id2,
          $organism2, $similarity) = @{ $row };
      ($loc1, $loc2) = ($acc2loc{$prot_acc1}, $acc2loc{$prot_acc2});
      if ($taxon_id1 eq $org2taxon_id{$org} && $loc1 eq $ll_id) {
        push @{ $data{$loc1}{$prot_acc1}{$similarity}{$organism2} }, join("\t",
            $taxon_id1,
            $organism1,
            $loc1,
            $loc2sym{$loc1},
            $loc2cid{$loc1},
            $prot_acc1,
            $taxon_id2,
            $organism2,
            $loc2,
            $loc2sym{$loc2},
            $loc2cid{$loc2},
            $prot_acc2,
            $similarity
            );
      } elsif ($taxon_id2 eq $org2taxon_id{$org} && $loc2 eq $ll_id) {
        push @{ $data{$loc2}{$prot_acc2}{$similarity}{$organism2} }, join("\t",
            $taxon_id2,
            $organism2,
            $loc2,
            $loc2sym{$loc2},
            $loc2cid{$loc2},
            $prot_acc2,
            $taxon_id1,
            $organism1,
            $loc1,
            $loc2sym{$loc1},
            $loc2cid{$loc1},
            $prot_acc1,
            $similarity
            );
      }
    }
  }

  if( defined %data ) {
    return join("\n",
      @{ FormatHomoloGeneData($org, $ll_id, \%data) }) . "\n";
  }
  else {
    return "";
  }

}

######################################################################
sub BuildHomologLine {
  my ($db, $org, $cid) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  &debug_print( "org: $org, cid: $cid \n");
  my $protsims = GetProtSims($db, $org, $cid);

  my $orthologs;
  my ($org1, $protgi, $protid, $pct, $aln);
  my @protsims = split "\001", $protsims;
  $protsims = "";
  for my $protsim (@protsims) {
    ($org1, $protgi, $protid, $pct, $aln) = split "\002", $protsim;
    $org1 or $org1 = "-";
    $protsims = $protsims . "<tr>" .
        "<td>$org1</td>" .
        "<td><a href=javascript:spawn(" .
            "\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=Protein&" .
            "CMD=Search&term=$protgi\")>$protid</a></td>" .
        "<td>$pct%</td>" .
        "<td>$aln</td>" .
        "</tr>";
  }

  if ($protsims) {
    $protsims =
        "<table border=1 cellspacing=1 cellpadding=4><tr>" .
        "<td><font color=\"#38639d\"><b>Organism</b></font></td>" .
        "<td><font color=\"#38639d\"><b>Protein ID</b></font></td>" .
        "<td><font color=\"#38639d\"><b>% Similarity</b></font></td>" .
        "<td><font color=\"#38639d\"><b>Aligned aa</b></font></td>" .
        "</tr>" .
        $protsims .
        "</table>\n";
  }

  my ($sql_map);
  my (%ortho_pct, %orthos);
  my ($ortho_cid);
  my $ortho_org = $org eq "Hs" ? "Mm" : "Hs";
  my ($sym, $title, $libs, $loc, $cyt, $gb, $omim);

  my $table_name = ($ortho_org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster b " : "$CGAP_SCHEMA.mm_cluster b ");

  if ($org eq "Hs") {
      $sql_map = "select a.MM_CLUSTER_NUMBER, a.SIMILARITY, " .
                 " b.GENE, b.DESCRIPTION, b.SEQUENCES from " .
                 " $CGAP_SCHEMA.HS_TO_MM a, " . $table_name .
                 " where a.HS_CLUSTER_NUMBER = $cid " .
                 " and b.CLUSTER_NUMBER = a.MM_CLUSTER_NUMBER ";
  } else {
      $sql_map = "select a.HS_CLUSTER_NUMBER, a.SIMILARITY, " .
                 " b.GENE, b.DESCRIPTION, b.SEQUENCES from " .
                 " $CGAP_SCHEMA.MM_TO_HS a, " . $table_name .
                 " where a.MM_CLUSTER_NUMBER = $cid " .
                 " and b.CLUSTER_NUMBER = a.HS_CLUSTER_NUMBER ";
  }

  &debug_print( "sql_map: $sql_map \n");

  my $stm = $db->prepare($sql_map);
  if(!$stm) {
    ## print STDERR "$sql_map\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }

  if(!$stm->execute()) {

    ## print STDERR "$sql_map\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute failed.";
    $db->disconnect();
    return "";
  }

  &debug_print ("Finish execute. \n");

  $stm->bind_columns(\$ortho_cid, \$pct, \$sym, \$title, \$gb);

  while($stm->fetch) {

    &debug_print ("MAP EACH: $ortho_cid, $pct \n");
    if ($pct =~ /^\d+\.\d+$/) {
      $ortho_pct{$ortho_cid} = $pct;
    }
    $sym or $sym = "-";
    $orthos{$ortho_cid} = join "\032", $sym, $title, $gb;
  }

  for my $ortho_cid (keys %orthos) {
    ($sym, $title, $gb) = split(/\032/, $orthos{$ortho_cid});
    $gb =~ s/ +/<br>/g;
    $orthologs = $orthologs . "<tr valign=top>" .
      "<td>$sym</td>" .
      "<td>$title</td>" .
      "<td>$gb</td>" .
      "<td><a href=\"" . $BASE .
          "/Genes/GeneInfo?ORG=$ortho_org&CID=$ortho_cid\">Gene Info</a></td>" .
      "<td>" . ($ortho_pct{$ortho_cid} ? $ortho_pct{$ortho_cid} : "-") .
      "</td></tr>\n";
  }

  if ($orthologs) {
    $orthologs =
      "<table border=1 cellspacing=1 cellpadding=4><tr>" .
      "<td><font color=\"#38639d\"><b>Symbol</b></font></td>".
      "<td><font color=\"#38639d\"><b>Name</b></font></td>" .
      "<td><font color=\"#38639d\"><b>Sequence</b></font></td>" .
      "<td><font color=\"#38639d\"><b>CGAP Gene Info</b></font></td>" .
      "<td><font color=\"#38639d\"><b>% Similarity</b></font></td></tr>\n" .
      $orthologs .
      "</table>\n";
  }

  return ($protsims, $orthologs);
}

######################################################################
sub TissuesOfCluster {
  my ($db, $org, $cid) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($tissue, @rows, $x, $prefix, $suffix);

  my $sql = "select distinct s.tissue_name " .
      "from $CGAP_SCHEMA.tissue_selection s, $CGAP_SCHEMA." .
      ($org eq "Hs" ? "hs_gene_tissue" : "mm_gene_tissue") . " c " .
      "where s.tissue_code = c.tissue_code and " .
      "c.cluster_number = $cid " .
      "order by s.tissue_name";

  my $stm = $db->prepare($sql);

  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (($tissue) = $stm->fetchrow_array()) {
        push @rows, $tissue;
      }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  return join ", ", @rows;
}

######################################################################
sub BuildPIDPathwayLine {
  my ($db, $org, $loc) = @_;
 
 
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($pathway_line, $pidid, $pidname, @bcids);
  my ($pathway_name, $pathway_display);
 
  my $sql =
            "select distinct " .
              ## "c.source_name, " .
              "p.pathway_id, " .
              ## "p.ext_pathway_id, " .
              "p.pathway_name " .
              ## "g.ll_id, " .
              ## "g.symbol " .
            "from " .
              "pid.pw_pathway_atom pa, " .
              "pid.pw_edge e, " .
              "pid.pw_mol_mol mm_outer_family, " .
              "pid.pw_mol_mol mm_inner_family, " .
              "pid.pw_mol_mol mm_complex, " .
              "pid.pw_mol_srch s, " .
              "pid.pw_pathway p, " .
              "pid.pw_source c, " .
              "cgap.ll_gene g " .
            "where " .
                  "s.map_name = to_char(g.ll_id) " .
              "and s.mol_id = mm_inner_family.mol_id_2 " .
              "and mm_outer_family.mol_id_2 = mm_complex.mol_id_2 " .
              "and mm_complex.mol_id_1 = mm_inner_family.mol_id_1 " .
              "and e.mol_id = mm_outer_family.mol_id_1 " .
              "and mm_complex.relation in ('s','c','i') " .
              "and mm_outer_family.relation in ('s','m','i') " .
              "and mm_inner_family.relation in ('s','m','i') " .
              "and e.atom_id = pa.atom_id " .
              "and pa.pathway_id = p.pathway_id " .
              "and c.source_id = p.pathway_source_id " .
              "and c.source_name = 'NATURE' " .
              "and g.ll_id = '$loc'";
 
  my $stm = $db->prepare($sql);
  if (!$stm) {
    ## print "$sql\n";
    ## print "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
 
 
  if (!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
 
  $stm->bind_columns(\$pidid, \$pidname);
  while ($stm->fetch) {
    $pathway_line = $pathway_line .
          "<li><a href=javascript:spawn(\"" .
          "http://pid.nci.nih.gov/search/pathway_landing.shtml?pathway_id=$pidid&what=graphic&jpg=on&ppage=1&genes_a=$loc\")>" .
          $pidname . "</a>\n";
  }
  $stm->finish;
 
  if ($pathway_line) {
    $pathway_line = "<ul>" .  $pathway_line . "</ul>";
  }
  return $pathway_line;
}

######################################################################
sub BuildPathwayLine {
  my ($db, $org, $loc) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($pathway_line, $bcid, @bcids);
  my ($pathway_name, $pathway_display);

  my $sql = "select distinct bc_id " .
            "from $CGAP_SCHEMA.BioGenes "  .
            "where organism = '$org' " .
            "and locus_id = $loc";

  my $stm = $db->prepare($sql);
  if (!$stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }

  if (!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  $stm->bind_columns(\$bcid);
  while ($stm->fetch) {
    push @bcids, $bcid;
  }
  $stm->finish;

  if (@bcids) {
    my $temp = "'" . join("','",@bcids) . "'";
    my $sql_pathway = "select distinct pathway_name, pathway_display " .
                      "from $CGAP_SCHEMA.BioPaths "  .
                      "where organism = '$org' " .
                      "and BC_ID in ( $temp ) " .
                      "order by pathway_display";

    my $stm = $db->prepare($sql_pathway);
    if (!$stm) {
       ## print STDERR "$sql_pathway\n";
       ## print STDERR "$DBI::errstr\n";
       print "<br><b><center>Error in input</b>!</center>";
       $db->disconnect();
       return "";
    }


    if (!$stm->execute()) {
       ## print STDERR "$sql_pathway\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute failed.";
       $db->disconnect();
       return "";
    }

    $stm->bind_columns(\$pathway_name, \$pathway_display);

    while ($stm->fetch) {
      if ($pathway_display) {
        $pathway_line = $pathway_line .
          "<li><a href=\"" . $BASE .
          "/Pathways/BioCarta/$pathway_name\">" .
          $pathway_display . "</a>\n";
      }
    }

    if ($pathway_line) {
      $pathway_line = "<ul>" .  $pathway_line . "</ul>";
    }
  }
  return $pathway_line;
}

######################################################################
sub WalkParentPath {
  my ($x, $relation, $path, $sum) = @_;

  my $term = $x;
  if ($path eq "") {
    $path = $term;
  } else {
    $path .= ",$term";
  }
  if (! defined $$relation{$x}) {
    return $path;
  }
  for my $y (keys %{ $$relation{$x} }) {
    push @{ $sum }, WalkParentPath($y, $relation, $path, $sum);
  }
}

######################################################################
sub BuildGOLine {
  my ($db, $org, $loc) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($go_id, $go_name, $go_class, $ancestor_id, $parent_id, @lines);
  my (%name2go, %class2name, %go2ancestor, %parent, $init_nodes);
  my (@all_paths);

  my $sql = "select g.go_id, n.go_name, n.go_class, a.go_ancestor_id, " .
            "p.go_parent_id " .
            "from $CGAP_SCHEMA.ll_go g, $CGAP_SCHEMA.go_ancestor a, " .
            "$CGAP_SCHEMA.go_name n, $CGAP_SCHEMA.go_parent p " .
            "where n.go_id = g.go_id " .
            "and g.ll_id = $loc " .
            "and a.go_id = g.go_id " .
            "and p.go_id = a.go_ancestor_id";

  my $stm = $db->prepare($sql);

  if (! $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if (! $stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while (($go_id, $go_name, $go_class, $ancestor_id, $parent_id) =
      $stm->fetchrow_array()) {
    $parent{$ancestor_id}{$parent_id} = 1;
    $name2go{$go_name} = $go_id;
    $class2name{$go_class}{$go_name} = 1;
    $go2ancestor{$go_id}{$ancestor_id} = 1;
  }
  for $go_class (sort keys %class2name) {
    for $go_name (sort keys %{ $class2name{$go_class} }) {
      $go_id = $name2go{$go_name};
      undef @all_paths;
      WalkParentPath($go_id, \%parent, "", \@all_paths);
      for my $p (@all_paths) {
        if ($p) {
          $init_nodes = '%27' . join("%27,%27", $GO_ROOT,
              reverse split(",", $p)) . '%27';
          push @lines, 
#            "<li>[$go_class] <a href=javascript:GOOpenWindow(\"" . $BASE .
#            "/Genes/GOBrowser?SHOW_GENES=1&INIT_NODES=$init_nodes\")>$go_name</a>" ;
           "<li>[$go_class] <a href=\"GOBrowser?NODE=$go_id\" " .
           "target=GOBrowser>$go_name</a>";

          last;
        }
      }
    }
  }
  if (@lines) {
    unshift @lines, "<ul>\n";
    push @lines, "</ul>\n";
    return join("\n", @lines) . "\n";
  } else {
    return "";
  }

}

######################################################################
sub BuildKeggLine {
  my ($db, $loc) = @_;

  my ($sql_pathway);
  my ($pathway_line, $ecno, @ecnos);
  my ($path_id, $pathway_name);
  my (%path_id, %coords, $x1, $y1, $x2, $y2);

  ## my $sql = "select distinct ecno " .
  ##           "from $CGAP_SCHEMA.KeggGenes "  .
  ##           "where locus_id = $loc";

  ## my $stm = $db->prepare($sql);

  ## if (!$stm->execute()) {
  ##   SetStatus(S_RESPONSE_FAIL);
  ##   print STDERR "$sql\n";
  ##   print STDERR "$DBI::errstr\n";
  ##   print STDERR "execute call failed\n";
  ##   return "";
  ## }

  ## $stm->bind_columns(\$ecno);
  ## while ($stm->fetch) {
  ##   push @ecnos, $ecno;
  ## }      
  ## $stm->finish;

  ## if (@ecnos) {
  ##   my $temp = "'" . join("','",@ecnos) . "'";
  ##   $sql_pathway = "select distinct p.path_id, p.pathway_name " .
  ##                  "from $CGAP_SCHEMA.KeggComponents k, " .
  ##                  "$CGAP_SCHEMA.KeggPathNames p " .
  ##                  "where k.path_id = p.path_id " .
  ##                  "and (k.ecno in ($temp) " .
  ##                  "or k.ecno = '$loc') " .
  ##                  "order by p.pathway_name";
  ## } else {

  $ecno = $loc;
  $sql_pathway = "select distinct p.path_id, p.pathway_name " .
                 "from $CGAP_SCHEMA.KeggComponents k, " .
                 "$CGAP_SCHEMA.KeggPathNames p " .
                 "where k.path_id = p.path_id " .
                 "and k.ecno = '$ecno' " .
                 "order by p.pathway_name";

  ## }

  if ($ecno) {
    my $stm = $db->prepare($sql_pathway);
    if (!$stm) {
       ## print STDERR "$sql_pathway\n";
       ## print STDERR "$DBI::errstr\n";
       print "<br><b><center>Error in input</b>!</center>";
       $db->disconnect();
       return "";
    }


    if (!$stm->execute()) {
       ## print STDERR "$sql_pathway\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       $db->disconnect();
       return "";
    }

    $stm->bind_columns(\$path_id, \$pathway_name);

    while ($stm->fetch) {
      $path_id{$pathway_name} = $path_id;
    }
    $stm->finish;

    for $path_id (values %path_id) {
      my $sql = "select distinct x1,y1,x2,y2 " .
                "from $CGAP_SCHEMA.KeggCoords "  .
                "where path_id = '$path_id' " .
                "and ecno = '$ecno'";

      my $stm = $db->prepare($sql);
      if (!$stm) {
        ## print STDERR "$sql_pathway\n";
        ## print STDERR "$DBI::errstr\n";
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }

      if (!$stm->execute()) {
        ## print STDERR "$sql\n";
        ## print STDERR "$DBI::errstr\n";
        print "execute call failed\n";
        $db->disconnect();
        return "";
      }

      $stm->bind_columns(\$x1,\$y1,\$x2,\$y2);
      while ($stm->fetch) {
        if (defined $coords{$path_id}) {
          $coords{$path_id} .= ';' . "$x1,$y1,$x2,$y2";
        } else {
          $coords{$path_id} = "$x1,$y1,$x2,$y2";
        }
      }
      $stm->finish;
    }

    my @sorted_paths = sort keys %path_id;
    for $pathway_name (@sorted_paths) {
      $path_id = $path_id{$pathway_name};
        $pathway_line = $pathway_line . "<li>" .
        "<a href=javascript:ColoredPath(\"$BASE/Pathways/Kegg/$path_id\",\"$coords{$path_id}\",\"$ecno\")>$pathway_name</a>";
    }

    if ($pathway_line) {
      $pathway_line = "<ul>" .  $pathway_line . "</ul>";
    }
  }

  return $pathway_line;
}

######################################################################
sub GetBestSAGETag {
  my ($db, $org, $cid) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($sql, $stm);
  my ($tag, $t);

  $sql = "select tag " .
      "from $CGAP_SCHEMA.sagebest_cluster b, " .
      "$CGAP_SCHEMA.sageprotocol p " .
      "where b.cluster_number = $cid " .
      "and p.organism = '$org' " .
      "and p.protocol in ('SS10', 'LS10') " .
      "and p.code = b.protocol";

  $stm = $db->prepare($sql);
  if (not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if (not $stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while (($t) = $stm->fetchrow_array()) {
    $tag = $t;
  }
  ## take the last one
  return $tag;
}

######################################################################
sub GeneExpressionSection {
  my ($db, $org, $cid) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my (@lines);

  my $tissues_line = TissuesOfCluster($db, $org, $cid);
  my $tag = GetBestSAGETag($db, $org, $cid);

  push @lines, "<ul>";
  push @lines, "<li>This gene is found in these";
  push @lines, "<a href=\"" . $BASE . "/Tissues/LibsOfCluster?" .
             "PAGE=1&ORG=$org&CID=$cid\">" .
             "cDNA libraries</a> ";
  push @lines, "from the following tissue types: " .
             "<blockquote>$tissues_line</blockquote>";
  if ($tag) {
    if ($org eq 'Mm') {
      push @lines, "<li><a href=\"" . $BASE . "/SAGE/MEMatrix?" .
        "ORG=$org&METHOD=$method&FORMAT=html&TAG=$tag&STATE=\">SAGE Expression Matrix</a>";
      push @lines, "<br><br>";
    } else {
      push @lines, "<li>SAGE Anatomic Viewer";
      push @lines, "<ul>";
      push @lines, "<li><a href=\"" . $BASE . "/SAGE/Viewer?" .
        "TAG=$tag&CELL=0&ORG=$org&METHOD=$method\">Tissues only</a>";
      push @lines, "<li><a href=\"" . $BASE . "/SAGE/Viewer?" .
        "TAG=$tag&CELL=1&ORG=$org&METHOD=$method\">Cell lines only</a>";
      push @lines, "<li><a href=\"" . $BASE . "/SAGE/Viewer?" .
        "TAG=$tag&CELL=2&ORG=$org&METHOD=$method\">Tissues and cell lines</a>";
      push @lines, "</ul>";
      push @lines, "<br>";
    }
    push @lines, "<li><a href=\"" . $BASE . "/SAGE/FreqsOfTag?" .
        "ORG=$org&METHOD=$method&FORMAT=html&TAG=$tag\">SAGE Digital Northern</a>";
    push @lines, "<br><br>";
  }
  push @lines, "<li><a href=\"" . $BASE . "/Tissues/VirtualNorthern?" .
      "TEXT=0&ORG=$org&CID=$cid\">Monochromatic SAGE/cDNA Virtual Northern</a>"; 
  push @lines, "<br><br>";
  if ($org eq "Hs") {
    push @lines, "<li><a href=\"$BASE/Microarray/" .
      "MicroarrayAccessions?ORG=Hs&CID=$cid\">" .
      "Two-dimensional array displays</a> " .
      "(similar expression pattern in " .
      "NCI60 microarray data or SAGE data)";
  }
  elsif ($org eq "Mm") {
    push @lines, "<li><a href=\"$BASE/Microarray/" .
      "MicroarrayAccessions?ORG=Mm&CID=$cid\">" .
      "Two-dimensional array displays</a> " .
      "(similar expression pattern in " .
      "SAGE data)";
  }

  push @lines, "</ul>";

  return join("\n", @lines);
}

######################################################################
sub FindGenePage_1 {
  my ($base, $org, $bcid, $ecno, $llno, $cid) = @_;
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($id);

  $BASE = $base;

  if ($cid eq '') {
    $id = GetPathInfo_1($org, $bcid, $ecno, $llno);
    if( $id eq "" ) {
      return "";
    }
  } else {
    $id = $cid;
  }
# return $id;
  print "<h3 align=center>Gene Info</h3>";
  return BuildGenePage_1($base, $org, $id, $llno);
}

######################################################################
sub SearchLICR {
  my ($org, $cid, $db, $gb) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my @accs = split / +/, $gb;
  my $acc_list = "'" . join("','",@accs) . "'";
  my (@licrs, $licr_id, $accession, $src_db);

  ## my $sql = "select unique LICR_ID " .
  ##           " from $CGAP_SCHEMA.LICR_HS_SEQUENCE " .
  ##           " where ACCESSION in ( $acc_list ) " .
  ##           " and (SRC_DB = 'M' or SRC_DB = 'R') ";

  my $licr_sequence = "$CGAP_SCHEMA.licr_sequence";
 
  my $ug_sequence = ($org eq "Hs" ? "$CGAP_SCHEMA.hs_ug_sequence" : "$CGAP_SCHEMA.mm_ug_sequence");

  my $sql = "select unique b.LICR_ID " .
            " from $ug_sequence a, " .
            "      $licr_sequence b " .  
            " where a.ACCESSION = b.ACCESSION " .
            " and a.CLUSTER_NUMBER = $cid " .
            " and ( b.SRC_DB = 'M' or b.SRC_DB = 'R' ) ";
 
  my $stm = $db->prepare($sql);
  if (not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
 
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
 
  $stm->bind_columns(\$licr_id);

  while($stm->fetch) {
    ## push @licrs, (join "\t", $licr_id, $accession, $src_db);  
    push @licrs, $licr_id;  
  }

  my $licr_count = @licrs;

  my $licr_ids = join "=", @licrs;

  return ($licr_count, $licr_ids);
}

######################################################################
sub LookForRNAi {
  my ($db, $org, $cid) = @_;
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($sql, $stm);
  $sql = qq!
select
  count(r.oligo_id)
from
  $CGAP_SCHEMA.rnai2ug r
where
      r.organism = '$org'
  and r.cluster_number = $cid
  !;
  $stm = $db->prepare($sql);
  if (! $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    print "execute failed.";
    $db->disconnect();
    return 0;
  }
  my ($count) = $stm->fetchrow_array();
  return $count; 
}

######################################################################
sub LookForCGWB {
  my ($db, $org, $sym) = @_;
  my ($sql, $stm);
  $sql = qq!
select
  gene
from
  $CGAP_SCHEMA.CGWB_GENE
where
      organism = '$org'
  and GENE = '$sym'
  !;
  $stm = $db->prepare($sql);
  if (! $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    print "execute failed.";
    $db->disconnect();
    return 0;
  }
  my ($gene) = $stm->fetchrow_array();
  return $gene;
}


######################################################################
sub BuildGenePage_1 {
  my ($base, $org, $cid, $loc_id) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  $BASE = $base;

  my ($sym, $title, $loc, $cyt, $gb, $omim, $gene_id);
  my ($count, $band, $count1, $count2, $list, $url, $count3, $url500);
  my ($chrom, $chrom_from, $chrom_to, $exon_info);
  my ($ensembl_url, $ensembl_gene, $hprd_id, $vega_id);

  my ($sql, $stm);
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  if( $loc_id ne "" and $loc_id != 0 ) {
 
    $sql = "select GENE, DESCRIPTION, LOCUSLINK, " 
. 
           " SEQUENCES, OMIM, CYTOBAND from " .
           " $CGAP_SCHEMA.GENE_INFO where " .
           " LOCUSLINK = $loc_id " .
           " and ORGANISM = '$org'";
 
    $stm = $db->prepare($sql);
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if ($stm->execute()) {
      $stm->bind_columns(\$sym, \$title, \$loc, \$gb, \$omim, \$cyt);
      while($stm->fetch) {
        &debug_print ("EACH: $cid, $sym, $title, $loc, $gb, $omim \n");
      }
    } else {
        ## print STDERR "$sql\n";
        print "execute call failed\n";
        $db->disconnect();
        return "";
    }

  }
  else {
  
    my $table_name = ($org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster" : "$CGAP_SCHEMA.mm_cluster");
  
    my $sql_lines = "select GENE, DESCRIPTION, LOCUSLINK, CYTOBAND, " .
        "SEQUENCES, OMIM from " . $table_name . " where " .
        " CLUSTER_NUMBER = $cid ";
  
    &debug_print( "sql_lines: $sql_lines \n");
  
    my $stm = $db->prepare($sql_lines);
    if (! $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
  
    if(!$stm->execute()) {
  
      ## print STDERR "$sql_lines\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
  
    &debug_print ("Finish execute. \n");
  
    $stm->bind_columns(\$sym, \$title, \$loc, \$cyt, \$gb, \$omim);
  
    while($stm->fetch) {
      &debug_print ("EACH: $cid, $sym, $title, $loc, $cyt, $gb, $omim \n");
    }
  }
  my $gene_id_list = $loc;
  $gene_id = $loc;
  if ($loc) {
    my ($temp_gene_id, @temp_gene_id); 
    my $sql = "select gene_id from $CGAP_SCHEMA.gene2unigene " .
        "where organism = '$org' and cluster_number = $cid";
    my $stm = $db->prepare($sql);
    if (! $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql_lines\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    $stm->bind_columns(\$temp_gene_id);
    while($stm->fetch) {
      if ( $temp_gene_id eq $loc_id ) {
        $loc_id = "";
      }
      push @temp_gene_id, $temp_gene_id;
    }
    $gene_id_list = join(",", @temp_gene_id);
  }
  if( defined $loc_id and $loc_id ne "" ) {
    if( $gene_id_list eq "" ) {
      $gene_id_list = $loc_id;
    }
    else {
      $gene_id_list = $loc_id . "," . $gene_id_list;
    }
  }

  if ($db) {
    if ($org eq "Hs") {
      ($count1, $list) =  CountAssoc($db, $sym);
      ($count2, $url) = CountDTP($db, $cid, $sym);
      ($band, $count) =  CountBreakpoints($db, $cyt);
      ($count3, $url500) = Count500($sym);
    }

    my @ref_nm_acc;
    for (split / +/, $gb) {
      if (/^NM_/) {
        push @ref_nm_acc, $_;
      }
    }

    ($chrom, $chrom_from, $chrom_to, $exon_info) = ChromPos($db, $org, $cid, \@ref_nm_acc);
  }

  # To search for SNPs or assemblies, if there is a gene symbol, go with that,
  # else use the cluster number. If cluster numbering has changed since the last
  # SNP/Assembly build, then we won't find the assembly. Chances with gene symbol
  # are better.
  my ($snp_asm_attr_name, $snp_asm_attr_val);
  if ($sym) {
    $snp_asm_attr_name = "keyword";
    $snp_asm_attr_val  = $sym;
  } else {
    $sym = "-";
    $snp_asm_attr_name = "gb";
    $snp_asm_attr_val = "$org.$cid";
  }

  my $snp_asm_org = ($org eq "Hs" ? "Homo+sapiens" : "Mus+musculus");

  my $rnai = LookForRNAi($db, $org, $cid);

  $title or $title = '-';

  ## my ($licr_count, $licr_ids) = SearchLICR ($org, $cid, $db, $gb);
  my ($licr_count, $licr_ids);

  my $gb_list;
  my $nm_acc;
  for (split / +/, $gb) {
    $gb_list = $gb_list .
        "<a href=javascript:spawn(" .
        "\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=Nucleotide&" .
        "CMD=Search&term=$_\")>$_</a><br>\n";
    if (/^NM_/ && !$nm_acc) {
      $nm_acc = $_;
    }
  }

  ## to check if sym is in CGWB list
  my $cgwb_gene = "";
  if($sym) {
    ## $cgwb_gene = LookForCGWB($db, $org, $sym);
  }
 
  my $header_table = "<table><tr valign=top>".
      "<td><b>Gene Information For:</b></td>" .
      "<td>$org. $sym, $title</td></tr>" .
      "<tr valign=top><td><b>Sequence ID:</b></td>" .
      "<td>$gb_list</td>" .
      "</tr>" ;
  if( $gene_id ne "" ) {
    $header_table = $header_table .
      getRSGID( $db, $org, $gene_id );
    $header_table = $header_table . 
      "<tr valign=top><td><b>Entrez Gene ID:</b></td>" .
      "<td>" .
      "<a href=javascript:spawn(" .
      "\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?" .
      "db=gene&cmd=Retrieve&dopt=full_report&" .
      "list_uids=$gene_id_list\")>$gene_id</a>" .
      "</td>" .
      "</tr>" ;
    ($ensembl_url, $ensembl_gene) = split "\t", getENSEMBL( $db, $org, $gene_id );
    $header_table = $header_table . $ensembl_url;
    $hprd_id = getHPRD_ID( $db, $org, $gene_id );
    $vega_id = getVEGA_ID( $db, $org, $gene_id );
  }

  $header_table = $header_table . "</table>";

  my $button_table = "<table cellspacing=1 cellpadding=4><tr>" .

      "<td><a href=javascript:spawn(" .
          "\"http://www.ncbi.nlm.nih.gov/UniGene/clust.cgi?" .
          "ORG=$org&CID=$cid\")>" .
          "UniGene</a></td>" .

      ## "<td>" . ( $loc ?
      "<td>" . ( $gene_id_list ?
          ( "<a href=javascript:spawn(" .
            "\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?" .
            "db=gene&cmd=Retrieve&dopt=full_report&" .
            "list_uids=$gene_id_list\")>Entrez Gene</a>"
          ) : "" ) . "</td>" .

     ($cgwb_gene  ?
          ("<td><a href=javascript:spawn(" .
          "\"http://cgwb.nci.nih.gov/cgi-bin/fwd?gene=$cgwb_gene\")>" .
          "CGWB" .
          "</a></td>") : "") .

      ($omim ?
          ("<td><a href=javascript:spawn(" .
          "\"http://www.ncbi.nlm.nih.gov/" .
          "omim/$omim\")>" .
          "OMIM</a></td>") : "") .

      ($ensembl_gene ?
          ("<td><a href=javascript:spawn(" .
          "\"http://uswest.ensembl.org/$org_2_fullname{$org}/Gene/Summary?g=" .
          "$ensembl_gene\")>" .
          "Ensembl Gene</a></td>") : "") .

      ($hprd_id ?
          ("<td><a href=javascript:spawn(" .
          "\"http://www.hprd.org/protein/" .
          "$hprd_id\")>" .
          "HPRD</a></td>") : "") .

      ($vega_id ?
          ("<td><a href=javascript:spawn(" .
          "\"http://vega.sanger.ac.uk/id/" .
          "$vega_id\")>" .
          "Vega</a></td>") : "") .

      ($count2 ?
          ("<td><a href=javascript:spawn(" .
          "\"$url\")>" .
          "DTP" .
          "</a></td>") : "") .

      ## "<td><a href=javascript:spawn(" .
      ##     "\"http://gai.nci.nih.gov/cgi-bin/GeneViewer.cgi?" .
      ##     "qt=1&query=" . ($org eq "Hs" ? "hs" : "mm") . ".$cid" .
      ##     "\")>SNPViewer</a></td>".

      "<td><a href=javascript:spawn(" .
          "\"http://www.ncbi.nlm.nih.gov/gene?" .
          "Db=snp&DbFrom=gene&Cmd=Link&LinkName=gene_snp&LinkReadableName=SNP&IdsFromResult=$gene_id" .
          "\")>SNP</a></td>" .

      "<td><a href=javascript:spawn(" .
          "\"http://www.ncbi.nlm.nih.gov" .
          "/SNP/snp_ref.cgi?locusId=$gene_id" .
          "\")>SNP: GeneView</a></td>" .

      "<td><a href=javascript:spawn(" .
          "\"http://www.ncbi.nlm.nih.gov" .
          "/sites/varvu?gene=$gene_id" .
          "\")>SNP: VarView</a></td>" .

      "<td><a href=javascript:spawn(" .
          "\"http://lpgws.nci.nih.gov/perl/snpbr?st=2&org=$snp_asm_org&" .
          "$snp_asm_attr_name=$snp_asm_attr_val" .
          "\")>Assemblies</a></td>" .

      ($count1  ?
          ("<td><a href=\"" . $BASE .
          "/Chromosomes/MCList?op=M&gene_op=o&gene=$list&page=1\">" .
          "Cancer Aberrations" .
          "</a></td>") : "") .

      ($count3  ?
          ("<td><a href=javascript:spawn(" .
          "\"$url500\")>" .
          "SNP500Cancer" .
          "</a></td>") : "") .

      ($licr_count  ?
          ("<td><a href=\"" . $BASE .
          "/LICR/LICRGeneInfo?ORG=$org&CID=$cid&LICR_ID=$licr_ids\">" .
          "LICR" .
          "</a></td>") : "") .
      
      ($rnai ?
          ("<td><a href=\"" . $BASE .
          "/RNAi/RNAiGeneQuery?PAGE=1&ORG=$org&UGID=$cid\">" .
          "RNAi" .
          "</a></td>") : "") .

      "</tr></table>" ;

#  &debug_print( "Before run BuildHomologLine \n"); 
#  my ($protsims_line, $homolog_line) = BuildHomologLine($db, $org, $cid);
#  &debug_print( "After run BuildHomologLine \n"); 

  my ($protsims_line, $homolog_line);
  if ($loc) {
    $homolog_line = HomoloGeneData($db, $org, $loc);
  }
 
  my $disease_line = GetDiseaseInfo($org, $db, $loc, $cid);

  ## my $fusion_gene_info_line;
  ## if($sym) {
  ##   $fusion_gene_info_line = GetFusionGeneInfo($BASE, $org, $db, $sym);
  ## }
 
  my $cyt_line = "<table><tr>" .
    "<td><font color=\"#38639d\"><b>Cytogenetic Location</b></font>:</td>" .
    "<td>" . ($cyt ? join(',',  split(/\002/, $cyt)) : "Unknown") . "</td>" .
    "<td>" . ($org eq "Hs" && $count ? "<a href=\"" . $BASE .
        "/Chromosomes/CytList?breakpoint=$band&page=1\">" .
        "Mitelman Breakpoint Data</a>" : " ") . "</td></tr></table>";

  my $chrom_url = "";
  if( $chrom ) {
    if( $org eq "Hs" ) {
      $chrom_url = 
        "<a href=javascript:spawn(\"" .
        "http://genome.ucsc.edu/cgi-bin/hgTracks?clade=vertebrate" .
        "&org=$org&db=$UCSC_DB&position=chr$chrom:$chrom_from-$chrom_to" .
        "&pix=620\")>$chrom: $chrom_from - $chrom_to</a>";
    }
    elsif( $org eq "Mm" ) {
      $chrom_url = "$chrom: $chrom_from - $chrom_to";
    }
  }
  my $chrom_line = "<table><tr>" .
    "<td><font color=\"#38639d\"><b>Chromosomal Position</b></font>:</td>" .
    "<td>" . ($chrom ? $chrom_url : "Unknown") . "</td>" .
    "</tr></table>";

  my $mgc_clones_line = GetMGCClonesOfCluster($db, $org, $cid);

  my $motif_sim_line;
  my @acc_array;
  LookForAccWithMotifInfo($db, $org, $cid, \@acc_array);
  if (@acc_array) {
    $motif_sim_line =
        "<p>Find gene products sharing protein motifs with: &nbsp;";
    for my $a (@acc_array) {
      $motif_sim_line .=
         "<a href=\"$BASE/Structure/GetSimMotifs?ACCESSION=$a" .
         "&EVALUE=1e-3&SCORE=&PVALUE=0&PAGE=1&ORG=$org\">$a</a>" .
         " &nbsp;";
    }
    $motif_sim_line .= "<br>";
  }

  ## Protein Info
  my $protein_info_line;
  $protein_info_line = Protein_section($db, $org, $cid);

  my $gene_ontology_line;
  my $gene_ontology_credits = 
          "<font size=\"-2\" color=\"#38639d\">" .
          "Gene classification by the " .
          "<a href=javascript:spawn(" .
          "\"http://www.ebi.ac.uk/Databases\")>" .
          "European Bioinformatics Institute</a>" .
          ", as recorded in GOA (GO Annotation\@EBI)</font>";
  my $pid_pathway_line;
  my $pathway_line;
  my $pathway_credits = 
          "<font size=\"-2\" color=\"#38639d\">" .
          "Pathway information courtesy of " .
          "<a href=javascript:spawn(" .
          "\"http://www.biocarta.com" .
          "\")>BioCarta</a>" .
          "</font>";
  my $kegg_line;
  my $kegg_credits = 
          "<font size=\"-2\" color=\"#38639d\">" .
          "Pathway information courtesy of " .
          "<a href=javascript:spawn(" .
          "\"http://www.genome.ad.jp/kegg" .
          "\")>Kegg</a>" .
          "</font>";

  if ($loc) {
    $pid_pathway_line = BuildPIDPathwayLine($db, $org, $loc);
    $pathway_line = BuildPathwayLine($db, $org, $loc);
    ## $kegg_line = BuildKeggLine($db, $loc);
    $gene_ontology_line = BuildGOLine($db, $org, $loc);
  }

  my $temp = $header_table . "\n" .
           "<br>\n" .
         DividerBar("Database Links") .
           "<br>\n" .
             $button_table .
           "<br>\n" .
         DividerBar("Gene Expression Data") .
           "<br>\n" .
             GeneExpressionSection($db, $org, $cid) .
#             "<p>This gene is found in these " .
#             "<a href=\"" . $BASE . "/Tissues/LibsOfCluster?" .
#             "PAGE=1&ORG=$org&CID=$cid\">" .
#             "cDNA libraries</a> " .
#             "from the following tissue types: " .
#             "<blockquote>$tissues_line</blockquote>" .
#             $microarray_search .
           "<br>\n";
     if( $disease_line ) {
       $temp = $temp .  
           DividerBar("Associated Diseases (from OMIM)") .
           "<br>\n" .
             "$disease_line" .
           "<br>\n"; 
     } 
     ## if( $fusion_gene_info_line ) {
     ##   $temp = $temp .  
     ##       DividerBar("Fusion Gene Info (from Mitelman Database)") .
     ##       "<br>\n" .
     ##         "$fusion_gene_info_line" .
     ##       "<br>\n"; 
     ## } 
     $temp = $temp .  
         DividerBar("Cytogenetic Location (from UniGene)") .
           "<br>\n" .
             "$cyt_line" .
           "<br>\n" .
         DividerBar("Chromosomal Position (from UCSC)") .
           "<br>\n" .
             "$chrom_line <br>" .
             "$exon_info " .
           "<br>\n" .
         ($mgc_clones_line ?
             DividerBar("Full-Length MGC Clones for This Gene") .
           "<br>\n" .
             "$mgc_clones_line" .
           "<br>\n"
           : "") .
         ($motif_sim_line ?
             DividerBar("Protein Similarities Based on Shared Motif Content") .
           "<br>\n" .
             "$motif_sim_line" .
           "<br>\n"
           : "") .
         ($protein_info_line ?
             DividerBar("Protein Infomation") .
           "<br>\n" .
             "$protein_info_line" .
           "<br>\n"
           : "") .
         ($protsims_line ?
             DividerBar("Protein Similarities (from UniGene)") .
           "<br>\n" .
             "$protsims_line" .
           "<br>\n"
           : "") .
         ($homolog_line ?
#             DividerBar(($org eq "Mm" ? "Homo Sapiens" : "Mus Musculus") .
#                 " Orthologs (from HomoloGene)") .
             DividerBar("Homologs (from HomoloGene)") .
           "<blockquote><font color=red>Note:</font> Both orthologs and \n" .
           "paralogs are included.</blockquote>\n" .
             "$homolog_line" .
           "<br>\n"
           : "") .
         ($gene_ontology_line ?
             DividerBar("Gene Ontology") .
             "$gene_ontology_credits<br>\n" .
             "$gene_ontology_line<br>\n" : "") .
         ($pid_pathway_line ?
             DividerBar("NCI-Nature Pathway Interaction Database") .
             "$pid_pathway_line<br>\n"       : "") .
         ($pathway_line ?
             DividerBar("BioCarta Pathways") .
             "$pathway_credits<br>\n" .
             "$pathway_line<br>\n"       : ""); 
         ## ($kegg_line ?
         ##     DividerBar("Kegg Pathways") .
         ##     "$kegg_credits<br>\n" .
         ##     "$kegg_line<br>\n"       : "") ;

  if ($db) {
    $db->disconnect();
  }

  return $temp;

}


#####################################################################
sub getRSGID {
  my ($db, $org, $gene_id) = @_;

  $org = "Hs"; #### it will be removed!
  my $sql = "select ACCESSION, GI from $CGAP_SCHEMA.LL2REFSEQGENE " .
    "where ORGANISM = '$org' and LOCUSLINK = $gene_id";

  my (@row);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      my ($acc, $gi) = $stm->fetchrow_array();
      if( $acc ) {
        return 
          "<tr valign=top><td><b>RefSeqGene ID:</b></td>" .
          "<td><a href=javascript:spawn(" .
          "\"http://www.ncbi.nlm.nih.gov/nuccore/$gi\")>" .
          "$acc</a></td>" . 
          "</tr>" ;
       
      }
      else {
        return ""; 
      }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }
}

#####################################################################
sub getENSEMBL {
  my ($db, $org, $gene_id) = @_;
 
  my $sql = "select ENSEMBL_GENE from $CGAP_SCHEMA.LL2ENSEMBL " .
    "where ORGANISM = '$org' and LOCUSLINK = $gene_id";
 
  my (@row);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      my ($gene) = $stm->fetchrow_array();
      if( $gene ) {
        return
          "<tr valign=top><td><b>Ensembl ID:</b></td>" .
          "<td><a href=javascript:spawn(" .
          "\"http://uswest.ensembl.org/$org_2_fullname{$org}/Gene/Summary?g=$gene\")>" .
          "$gene</a></td>" .
          "</tr>" . "\t" . $gene;
 
      }
      else {
        return "";
      }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }
}
 
#####################################################################
sub getVEGA_ID {
  my ($db, $org, $gene_id) = @_;
 
  my $sql = "select VEGA_GENE from $CGAP_SCHEMA.LL2VEGA " .
    "where ORGANISM = '$org' and LOCUSLINK = $gene_id";
 
  my (@row);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      my ($gene) = $stm->fetchrow_array();
      if( $gene ) {
        return $gene;
      }
      else {
        return "";
      }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }
}

#####################################################################
sub getHPRD_ID {
  my ($db, $org, $gene_id) = @_;
 
  my $sql = "select HPRD_GENE from $CGAP_SCHEMA.LL2HPRD " .
    "where ORGANISM = '$org' and LOCUSLINK = $gene_id";
 
  my (@row);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      my ($gene) = $stm->fetchrow_array();
      if( $gene ) {
        ## $gene = sprintf("%05d", $gene); 
        return $gene;
      }
      else {
        return "";
      }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }
}
 
#####################################################################
sub CountBreakpoints {
  my ($db, $break) = @_;
  if ($break =~ /^(X|Y|\d+)(p|q)(\d+)/) {
    $break = "$1$2$3";
  } else {
    return ("", 0);
  }
  my $count = 0;

  my $sql = "select count(invno) from $CGAP_SCHEMA.KaryBreak ".
    "where Breakpoint = '$break'";

  my (@row);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      @row = $stm->fetchrow_array();
      $count=$row[0];
      $stm->finish;
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  return ($break,$count);
}

#####################################################################
sub CountAssoc {
  my ($db, $gene) = @_;
  my $count = 0;

  my $sql1 = "select g.gene_uc from $CGAP_SCHEMA.hs_gene_alias g where " . 
    "exists (select h.cluster_number from $CGAP_SCHEMA.hs_gene_alias h, " .
    "$CGAP_SCHEMA.hs_cluster b " .
    "where h.gene_uc = '$gene' " .
    "and h.cluster_number = g.cluster_number and " .
    "h.cluster_number = b.cluster_number)";

  my (@items,@row,@rows);
  my $stm = $db->prepare($sql1);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (@row = $stm->fetchrow_array()) {
        push @rows, @row;
      }      
      $stm->finish;
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }
  
  for( my $i=0; $i<@rows; $i++ ) {
    $rows[$i] = convrtSingleToDoubleQuote($rows[$i]);
  }
  my $temp = "'" . join("','",@rows) . "'";

  my $sql2 = "select /*+ RULE */count(invno) from $CGAP_SCHEMA.MolClinGene ".
    "where Gene in ($temp)";

  my (@row);
  my $stm = $db->prepare($sql2);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      @row = $stm->fetchrow_array();
      $count=$row[0];
      $stm->finish;
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  $temp =~ s/'//g;

  return ($count,$temp);
}


#####################################################################
sub CountDTP {
  my ($db, $cid, $sym) = @_;

  my $sql =
    "select d.molt_number,d.molt_id " .
    "from $CGAP_SCHEMA.dtp_accession d, " .
    "$CGAP_SCHEMA.hs_ug_sequence s " .
    "where s.cluster_number = $cid " .
    "and d.accession = s.accession " ;

  my $count;

  my (@row,@rows);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (@row = $stm->fetchrow_array()) {
        push @rows, [@row];
      }
      $stm->finish;
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  if (@rows) {
    $count = 1;
  } else {
    $count = "";
  }

  my $molt_nbr = $rows[0][0];
  my $molt_id = $rows[0][1];

  my $url;

  if ($sym) {
    $url = "http://dtp.cancer.gov/mtweb/hugosearch?genecard=$sym";
  } else {
    $url = "http://dtp.cancer.gov/mtweb/targetinfo?moltid=$molt_id&moltnbr=$molt_nbr";
  }

  return ($count,$url);
}

#####################################################################
sub Count500 {
  my ($sym) = @_;

  my $count = 0;
  my $url;

  if ($sym) {
    my $ua = LWP::UserAgent->new;

    my $request = HTTP::Request->new('GET',
      "http://snp500cancer.nci.nih.gov/cgap_gene_list.cfm?genelist=('$sym')");

    my $response = $ua->request($request);

    if ($response->is_success) {
      if ($response->content =~ /^\s+$sym/) {
        $url = "http://snp500cancer.nci.nih.gov/snplist.cfm?gene_id=$sym&mode=valid";
        $count = 1;
      }
    }
  }
  return ($count,$url);
}

######################################################################
sub FindExonInfo_1 {
  my ($base, $org, $nm_acc, $chrom_to) = @_;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }
  my ($blockcount, $blocksizes, $trans_starts, $chr_starts);
  if( $nm_acc ne "" ) {
    my $sql =
      "select BLOCKCOUNT, BLOCKSIZES, BLOCK_TRANSCRIPT_STARTS, BLOCK_CHR_STARTS " .
      "from $CGAP_SCHEMA.exon_info " .
      "where ACCESSION = '$nm_acc' " .
      "and organism = '$org' " ;
 
    my $stm = $db->prepare($sql);
 
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
 
    if (!$stm->execute()) {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
 
    $stm->bind_columns(\$blockcount, \$blocksizes, \$trans_starts, \$chr_starts);
 
    $stm->fetch;
    $stm->finish;
  }
 
  print "<h3 align=center>Exon Info</h3>";

  my @trans_starts = split ",", $trans_starts;
  my @chr_starts = split ",", $chr_starts;
  my @sizes = split ",", $blocksizes;
  my @lines;
  for (my $i=0; $i<@sizes; $i++ ) {
    my $trans_end = $trans_starts[$i] + $sizes[$i] - 1;
    my $chr_end = $chr_starts[$i] + $sizes[$i] - 1;
    ## if( $chr_end > $chrom_to ) {
    ##   last;
    ## }
    push @lines, "<tr><td>$trans_starts[$i]</td>" .
                 "<td>$trans_end</td>" .
                 "<td>$chr_starts[$i]</td>" .
                 "<td>$chr_end</td></tr>";
  }
  my $exon_info = "<font color=\"#38639d\"><b>$nm_acc</b></font>:<br><br>";
  $exon_info = $exon_info .
    "<table border=1 cellspacing=1 cellpadding=4>" .
    "<tr>" .
    "<th><font color=\"#38639d\"><b>Transcript Start</b></font></th>" .
    "<th><font color=\"#38639d\"><b>Transcript End</b></font></th>" .
    "<th><font color=\"#38639d\"><b>Chromosomal Start</b></font></th>\n" .
    "<th><font color=\"#38639d\"><b>Chromosomal End</b></font></th></tr>\n" .
    join("\n", @lines) .
    "</table>";

  $db->disconnect();

  return $exon_info;

}

######################################################################
sub ChromPos {
  my ($db, $org, $cid, $ref_nm_acc) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($chrom, $chrom_from, $chrom_to, $acc);

  my $sql =
    "select chromosome, chr_start, chr_end, ACCESSION " .
    "from $CGAP_SCHEMA.ucsc_mrna " .
    "where cluster_number = $cid " .
    "and organism = '$org' " ;

  my $stm = $db->prepare($sql);

  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }

  if (!$stm->execute()) {
    print "execute failed\n";
    $db->disconnect();
    return "";
  }

  $stm->bind_columns(\$chrom, \$chrom_from, \$chrom_to, \$acc);

  $stm->fetch;
  $stm->finish;

  my ($blockcount, $blocksizes, $trans_starts, $chr_starts); 
  
  my $exon_info = "";
  if( @{$ref_nm_acc} == 0 ) {
    return ($chrom, $chrom_from, $chrom_to, $exon_info);
  }
  elsif( @{$ref_nm_acc} == 1 ) {
    my $sql =
      "select BLOCKCOUNT, BLOCKSIZES, BLOCK_TRANSCRIPT_STARTS, BLOCK_CHR_STARTS " .
      "from $CGAP_SCHEMA.exon_info " .
      "where ACCESSION = '@{$ref_nm_acc}[0]' " .
      "and organism = '$org' " ;
   
    my $stm = $db->prepare($sql);
   
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
   
    if (!$stm->execute()) {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
   
    $stm->bind_columns(\$blockcount, \$blocksizes, \$trans_starts, \$chr_starts);
   
    $stm->fetch;
    $stm->finish;

  if( not defined $blockcount or $blockcount eq "" ) {
    $exon_info = "";
  }
  elsif( $blockcount <= 10 ) {
    my @trans_starts = split ",", $trans_starts;
    my @chr_starts = split ",", $chr_starts;
    my @sizes = split ",", $blocksizes;
    my @lines;
    for (my $i=0; $i<@sizes; $i++ ) {
      my $trans_end = $trans_starts[$i] + $sizes[$i] - 1;
      my $chr_end = $chr_starts[$i] + $sizes[$i] - 1;
      ## if( $chr_end > $chrom_to ) {
      ##   last;
      ## }
      push @lines, "<tr><td>$trans_starts[$i]</td>" .
                   "<td>$trans_end</td>" .     
                   "<td>$chr_starts[$i]</td>" .     
                   "<td>$chr_end</td></tr>"; 
    }
    $exon_info = "<font color=\"#38639d\"><b>@{$ref_nm_acc}[0] exon info from UCSC</b></font>:<br><br>";
    $exon_info = $exon_info . 
      "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr>" .
      "<th><font color=\"#38639d\"><b>Transcript Start</b></font></th>" .
      "<th><font color=\"#38639d\"><b>Transcript End</b></font></th>" .
      "<th><font color=\"#38639d\"><b>Chromosomal Start</b></font></th>\n" .
      "<th><font color=\"#38639d\"><b>Chromosomal End</b></font></th></tr>\n" .
      join("\n", @lines) .
      "</table>";
    }
    else {
      $exon_info = "<a href=\"/Genes/ExonInfo?ORG=$org&ACC=@{$ref_nm_acc}[0]&CHR_TO=$chrom_to\"><font color=\"#38639d\">@{$ref_nm_acc}[0]</font></a>";
      $exon_info = "<font color=\"#38639d\"><b>&nbsp;Exon Info From UCSC</b></font>:" . "<center><table>" . $exon_info . "</table></center>";

    }
  
    return ($chrom, $chrom_from, $chrom_to, $exon_info);
  }
  else {
    my $count = 0;
    my $tmp_exon_info;
    my @tmp_exon_infos;
    for ( my $i=0; $i<@{$ref_nm_acc}; $i++ ) {
      my ($blockcount, $blocksizes, $trans_starts, $chr_starts);
      my $sql =
        "select BLOCKCOUNT, BLOCKSIZES, BLOCK_TRANSCRIPT_STARTS, BLOCK_CHR_STARTS " .
        "from $CGAP_SCHEMA.exon_info " .
        "where ACCESSION = '@{$ref_nm_acc}[$i]' " .
        "and organism = '$org' " ;
    
      my $stm = $db->prepare($sql);
    
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
    
      if (!$stm->execute()) {
        print "execute failed\n";
        $db->disconnect();
        return "";
      }
   
      $stm->bind_columns(\$blockcount, \$blocksizes, \$trans_starts, \$chr_starts);
   
      $stm->fetch;
      $stm->finish;
   
      if( not defined $blockcount or $blockcount eq "" ) {
        ## $exon_info = "";
        next;
      }

      $count++;
   
      if( $blockcount <= 10 and $count < 2 ) {
        my @trans_starts = split ",", $trans_starts;
        my @chr_starts = split ",", $chr_starts;
        my @sizes = split ",", $blocksizes;
        my @lines;
        for (my $i=0; $i<@sizes; $i++ ) {
          my $trans_end = $trans_starts[$i] + $sizes[$i] - 1;
          my $chr_end = $chr_starts[$i] + $sizes[$i] - 1;
          ## if( $chr_end > $chrom_to ) {
          ##   last;
          ## }
          push @lines, "<tr><td>$trans_starts[$i]</td>" .
                       "<td>$trans_end</td>" .
                       "<td>$chr_starts[$i]</td>" .
                       "<td>$chr_end</td></tr>";
        }
        $tmp_exon_info = "<font color=\"#38639d\"><b>Exon Info From UCSC</b></font>:<br><br>";
        $tmp_exon_info = $exon_info .
          "<table border=1 cellspacing=1 cellpadding=4>" .
          "<tr>" .
        "<th><font color=\"#38639d\"><b>Transcript Start</b></font></th>" .
        "<th><font color=\"#38639d\"><b>Transcript End</b></font></th>" .
        "<th><font color=\"#38639d\"><b>Chromosomal Start</b></font></th>\n" .
        "<th><font color=\"#38639d\"><b>Chromosomal End</b></font></th></tr>\n" .
        join("\n", @lines) .
        "</table>";
      }
      push @tmp_exon_infos, "<tr><td align=left><a href=\"/Genes/ExonInfo?ORG=$org&ACC=@{$ref_nm_acc}[$i]&CHR_TO=$chrom_to\"><font color=\"#38639d\">@{$ref_nm_acc}[$i]</font></a></tr>";
    }
    if( @tmp_exon_infos == 0 ) {
      $exon_info = "";
    }
    elsif ( @tmp_exon_infos == 1 ) {
      $exon_info = $tmp_exon_info;
    }
    else {
      $exon_info = "<font color=\"#38639d\"><b>&nbsp;Exon Info From UCSC</b></font>:" . "<center><table>" . join ("", @tmp_exon_infos) . "</table></center>";
    }
    return ($chrom, $chrom_from, $chrom_to, $exon_info);
  }
}

######################################################################
sub Get_Other_Genes {
  my ($org, $loc, $cid, $omim) = @_;
 
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($sql, $stm, @lines);
 
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }
 
  my $cluster_table =
      ($org eq "Hs") ? "$CGAP_SCHEMA.hs_cluster"
                     : "$CGAP_SCHEMA.mm_cluster";

  $sql = "select unique a.CLUSTER_NUMBER, a.GENE, b.LOCUSLINK " .
         " from $CGAP_SCHEMA.GENE_INFO a, " .
         "      $CGAP_SCHEMA.GENE_MIM_DISEASE b " .
         " where b.OMIM = $omim and b.LOCUSLINK != $loc " .
         "       and a.LOCUSLINK = b.LOCUSLINK " .
         "       and a.LOCUSLINK != $loc " .
         "       and a.CLUSTER_NUMBER != $cid " .
         "       and a.ORGANISM = '$org' order by a.GENE ";
 
   $stm = $db->prepare($sql);
   if (not $stm) {
     print "<br><b><center>Error in input</b>!</center>";
     $db->disconnect();
     return "";
   }
   if ($stm->execute()) {
     while ( my($a_cid, $symbol, $a_loc)
                        = $stm->fetchrow_array() ) {
       push @lines,  "<a href=GeneInfo?ORG=$org&CID=$a_cid&LLNO=$a_loc>$symbol</a><br>" 
     }
   } else {
      ## print STDERR "$sql\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
   }
   
   my $len = @lines;
   if( $len == 0 ) {
     return "<td>&nbsp;</td>";
   }
   else {
     return "<td>" . join ("", @lines) . "</td>";
   }
}


######################################################################
sub GetChromPosList_1 {
  my ($page, $org, $cids, $gene_ids, $syms) = @_;
 
  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($organism, $cluster_number, $accession);
  my ($chrom, $chrom_from, $chrom_to, $locuslink, $gene);
  my (@rows, @cids, @scid, $cid_list, $c);
  my ($sql, $stm, %cid_gene_id2sym);
  my (%query_accs, %exit_accs);
 
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }
 
  push @rows, "Org\tCluster\tAccession\tLocusLink\tGene\tChrom: from - to";
 
  my $cluster_table =
      ($org eq "Hs") ? "$CGAP_SCHEMA.hs_cluster"
                     : "$CGAP_SCHEMA.mm_cluster";
 
  my @lls = split ",", $gene_ids;
  my @tmp_syms = split ",", $syms;
  my @syms;
  if( @tmp_syms ) {
    for(my $i=0; $i<@tmp_syms; $i++) {
      $syms[$i] = "'$tmp_syms[$i]'";
    }
  }

  if (@lls) {
    my ($list, $sql);
    for(my $i = 0; $i < @lls; $i += ORACLE_LIST_LIMIT) {
      if(($i + ORACLE_LIST_LIMIT - 1) < @lls) {
        $list = join(",", @lls[$i..$i+ORACLE_LIST_LIMIT-1]);
      }
      else {
        $list = join(",", @lls[$i..@lls-1]);
      }
 
 
      $sql = "select CLUSTER_NUMBER, GENE, LOCUSLINK " .
             " from $CGAP_SCHEMA.GENE_INFO where " .
             " LOCUSLINK in (" .  $list . " ) " .
             "and ORGANISM = '$org'";
 
      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      if ($stm->execute()) {
        while ( my($cid, $symbol, $loc)
                                  = $stm->fetchrow_array() ) {
          $cid_gene_id2sym{$cid}{$loc} = $symbol;
        }
      } else {
        ## print STDERR "$sql\n";
        print "execute call failed\n";
        $db->disconnect();
        return "";
      }
    }
  }

  if (@syms) {
    my %genes_got_info;
    my $acc_list;
    for ($a = 0; $a < @syms; $a += ORACLE_LIST_LIMIT) {
      if (($a + ORACLE_LIST_LIMIT - 1) < @syms) {
        $acc_list = join ",", @syms[$a..$a+ORACLE_LIST_LIMIT-1];
      } else {
        $acc_list = join ",", @syms[$a..$#syms];
      }

      ## doing search in ll2acc.dat for acc first
      my $sql;
      my @sub_syms;
      my @target_accs = split ",", $acc_list;
      my %query_accs;
      my %exit_accs;
      for( my $i=0; $i<@target_accs; $i++ ) {
        $target_accs[$i] =~ s/'//g;
        $query_accs{$target_accs[$i]} = 1;
      }

      $sql =
        "select b.CLUSTER_NUMBER, b.GENE, b.DESCRIPTION, a.LL_ID, " .
        " a.ACCESSION from $CGAP_SCHEMA.ll2acc a, $CGAP_SCHEMA.GENE_INFO b " .
        "where a.ACCESSION in (" . $acc_list .
        ") and a.ORGANISM = '$org' and b.ORGANISM = '$org' " .
        " and a.LL_ID = b.LOCUSLINK ";
        ## " and a.ACCESSION_TYPE = 'm' ";
 
      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      } else {
        ## my $t0 = [gettimeofday];
        if ($stm->execute()) {
          my ($cid, $locuslink, $symbol, $title, $gb);
          $stm->bind_columns(\$cid, \$symbol, \$title, \$locuslink, \$gb);
          while ($stm->fetch) {
            $cid_gene_id2sym{$cid}{$locuslink} = $symbol; 
          }
 
        } else {
          print "execute failed\n";
          $db->disconnect();
          return "";
        }
      }
 
      if( defined %query_accs ) {
        for my $acc (keys %query_accs) {
          push @sub_syms, "'$acc'";
        }
      }

      if (@sub_syms) {
        my $list = join ",", @sub_syms;

        $sql = "select CLUSTER_NUMBER, GENE, LOCUSLINK " .
               " from $CGAP_SCHEMA.GENE_INFO where " .
               "GENE in ( $list " .
               ") and ORGANISM = '$organism'";
 
        $stm = $db->prepare($sql);
        if (not $stm) {
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        } else {
          $stm = $db->prepare($sql);
          if (not $stm) {
            print "<br><b><center>Error in input</b>!</center>";
            $db->disconnect();
            return "";
          } else {
            my ($cid, $loc, $symbol);
            if ($stm->execute()) {
              $stm->bind_columns(\$cid, \$symbol, \$loc);
              while ($stm->fetch) {
                $cid_gene_id2sym{$cid}{$loc} = $symbol;
              }
            } else {
              print "execute failed\n";
              $db->disconnect();
              return "";
            }
          }
        }
      }
    }
  }

  @cids = split ",", $cids;
  @scid = sort numerically @cids;
 
  if (@scid) {
    for ($c = 0; $c < @scid; $c += ORACLE_LIST_LIMIT) {
      if (($c + ORACLE_LIST_LIMIT - 1) < @scid) {
        $cid_list = join(",", @scid[$c..$c+ORACLE_LIST_LIMIT-1]);
      } else {
        $cid_list = join(",", @scid[$c..$#scid]);
      }
 
      my $sql =
        "select u.organism, u.cluster_number, u.accession, " .
        "       u.chromosome, u.chr_start, u.chr_end, " .
        "       c.locuslink, c.gene " .
        "from $CGAP_SCHEMA.ucsc_mrna u, $cluster_table c " .
        "where u.cluster_number in ($cid_list) " .
        "and u.organism = '$org' " .
        ## "and u.locuslink = c.locuslink " .
        "and u.cluster_number = c.cluster_number " .
        "order by u.cluster_number " ;
 
      my $stm = $db->prepare($sql);
 
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
 
      if (!$stm->execute()) {
        print "execute failed\n";
        $db->disconnect();
        return "";
      }
 
      $stm->bind_columns(\$organism, \$cluster_number, \$accession,
                         \$chrom, \$chrom_from, \$chrom_to,
                         \$locuslink, \$gene);
 
      while ($stm->fetch) {
        
        if( defined $cid_gene_id2sym{$cluster_number} ) {
          for my $loc (keys %{$cid_gene_id2sym{$cluster_number}}) {
            push @rows, 
              "$organism\t$cluster_number\t$accession\t" .
              "$loc\t$cid_gene_id2sym{$cluster_number}{$loc}\t" .
              "$chrom: $chrom_from - $chrom_to";
          } 
        }
        else {
          push @rows, "$organism\t$cluster_number\t$accession\t" .
                      "$locuslink\t$gene\t" .
                      "$chrom: $chrom_from - $chrom_to";
        }
      }
    }
  }
 
  $db->disconnect();
 
  return join "\n", @rows;
}
 
######################################################################
sub GetGeneByNumber_1 {
  my ($base, $page, $org, $term) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><menter>Error in input</b>!</center>";
    return "";
  }
  my $A_GREATER = 200000;
  my $B_GREATER = 300000;
  my $ALL       = 400000;

  my %uni_cid;
  my %symbol_loc2info;
  my (%acc2loc, %cid_acc);
  my (@gene_ids, @gene_syms);
  my (@ensembl_gene, @ensembl_acc, @ensembl_protein_acc);
  my (@refseqgene);

  $BASE = $base;

  $term =~ s/\\'/'/g;
  ## Look for gene given (a) putative cluster number, or (b)
  ## putatitve GenBank Accession number of constitutent of cluster

  my $build_id = $BUILDS{$org};

  my $hs_bld = $BUILDS{'Hs'};  $hs_bld =~ s/^1//;
  my $mm_bld = $BUILDS{'Mm'};  $mm_bld =~ s/^2//;

  my $cmd = "" . $BASE . "/Genes/RunUniGeneQuery?ORG=$org&TERM=$term";

  my $page_header; 
  my $leng = length($term);
  if( $leng < 50 ) {
    $page_header = "<table><tr>" . 
      "<td><b>GeneFinder Results For</b>:</td>" .
      "<td>$org; $term</td></tr>" .
      "<tr><td><b>UniGene Build</b>:</td>" .
      "<td>Hs.$hs_bld/Mm.$mm_bld</td></tr></table>";
  }
  else {
    $page_header = "<table><tr>" . 
      "<td><b>GeneFinder Results For</b>:</td>" .
      "<td>$org</td></tr>" .
      "<tr><td><b>UniGene Build</b>:</td>" .
      "<td>Hs.$hs_bld/Mm.$mm_bld</td></tr></table>";
  }

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  my ($cid, @cids);
  my (@row, @rows);
  my (@terms, @nums, @syms, @clus, @ug_sp_acc, @prot_acc, @sp_acc, @sp_id);
  my ($sql_clu, $sql_acc, $sql_sym);
  my ($stm, $cluster, $type, $gene, $cids);
  my (%official, %preferred, %alias, $wild, %acc2loc);

  if( $page > $A_GREATER and $page < $CLONE_PAGE ) {
    my @picked_term;
    my %no_dup_cids;
    for $term (split (",", $term)) {
      my ($cid, $flag) = split "_", $term; 
      if( $page > $A_GREATER and $page < $B_GREATER ) {
        if( $flag eq "A" ) {
          $no_dup_cids{$cid} = 1;
        }
      }
      elsif( $page > $B_GREATER and $page < $ALL ) {
        if( $flag eq "B" ) {
          $no_dup_cids{$cid} = 1;
        }
      }
      elsif( $page > $ALL and $page < $CLONE_PAGE ) {
        $no_dup_cids{$cid} = 1;
      }
    }

    for my $clu_id (keys %no_dup_cids) {
      if( not defined $uni_cid{$clu_id} ) {
        push @cids, $clu_id;
        $uni_cid{$clu_id} = 1;
      }
      
      ## push @picked_term, $clu_id;
      push @picked_term, $org . "." . $clu_id;
    }  

    if( $page > $A_GREATER and $page < $B_GREATER ) {
      $page = $page - $A_GREATER;
    }
    elsif( $page > $B_GREATER and $page < $ALL ) {
      $page = $page - $B_GREATER;
    }
    elsif( $page > $ALL and $page < $CLONE_PAGE ) {
      $page = $page - $ALL;
    }

    my $terms = join ",", @picked_term;
    my $cmd = "" . $BASE . "/Genes/RunUniGeneQuery?ORG=$org&TERM=$terms";

    return(FormatGenes($page, $org, $cmd, $page_header,
               OrderGenesBySymbol($page, $org, \@cids)));
  } 

  $term =~ s/ //g;
  $term =~ tr/a-z/A-Z/;
  $term =~ tr/*/%/;
  $term =~ s/%{2,}/%/g;

  my $cluster_flag;
  for $term (split (",", $term)) {
    $cluster_flag = 0;
    if ($term =~ /^(HS\.|MM\.)(\d+)/) {
      if (($org eq "Hs" && $1 eq "HS.") or ($org eq "Mm" && $1 eq "MM.")) {
        $term =~ s/^(HS\.|MM\.)//;
        $cluster_flag = 1;
      } else {
        next;
      }
    }
    if ($term =~ /^\d+$/) {
      if ($cluster_flag) {
        push @clus, $term;
        $cluster_flag = 0;
      } else {
        push @nums, $term;
      }
    } else {
      my $tmp_value = convrtSingleToDoubleQuote($term);
      push @syms, "'$tmp_value'";
      if( ($term =~ /^NP_/) or ($term =~ /^XP_/) ) {
        push @prot_acc, "'$tmp_value'";
      }
      elsif( $term =~ /^NG_/ ) {
        push @refseqgene, "'$tmp_value'";
      }
      elsif( $term =~ /^ENSG/ ) {
        push @ensembl_gene, "'$tmp_value'";
      }
      elsif( $term =~ /^ENSMUSG/ ) {
        push @ensembl_gene, "'$tmp_value'";
      }
      elsif( $term =~ /^ENST/ ) {
        push @ensembl_acc, "'$tmp_value'";
      }
      elsif( $term =~ /^ENSMUST/ ) {
        push @ensembl_acc, "'$tmp_value'";
      }
      elsif( $term =~ /^ENSP/ ) {
        push @ensembl_protein_acc, "'$tmp_value'";
      }
      elsif( $term =~ /^ENSMUSP/ ) {
        push @ensembl_protein_acc, "'$tmp_value'";
      }
      else {
        push @ug_sp_acc, "'$tmp_value'";
      }
    }
  }

  if (@clus) {
    my $gene_cluster_table = ($org eq "Hs" ? " $CGAP_SCHEMA.hs_cluster " : " $CGAP_SCHEMA.mm_cluster ");

    my $list;
    for(my $i = 0; $i < @clus; $i += ORACLE_LIST_LIMIT) {
      if(($i + ORACLE_LIST_LIMIT - 1) < @clus) {
        $list = join(",", @clus[$i..$i+ORACLE_LIST_LIMIT-1]);
      }
      else {
        $list = join(",", @clus[$i..@clus-1]);
      }

      $sql_clu = 
        "select distinct cluster_number from $gene_cluster_table " .
        "where cluster_number in (" . $list . ")";
      $stm = $db->prepare($sql_clu);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      if ($stm->execute()) {
        while (($cid) = $stm->fetchrow_array()) {
          if( not defined $uni_cid{$cid} ) {
            push @cids, $cid;
            $uni_cid{$cid} = 1;
          }
        }
      } else {
        ## print STDERR "$sql_clu\n";
        print "execute call failed\n";
        $db->disconnect();
        return "";
      }
    }
  }

  if (@nums) {

    my ($list, $sql);
    for(my $i = 0; $i < @nums; $i += ORACLE_LIST_LIMIT) {
      if(($i + ORACLE_LIST_LIMIT - 1) < @nums) {
        $list = join(",", @nums[$i..$i+ORACLE_LIST_LIMIT-1]);
      }
      else {
        $list = join(",", @nums[$i..@nums-1]);
      }

 
      $sql = "select CLUSTER_NUMBER, GENE, DESCRIPTION, LOCUSLINK, " .
             "SEQUENCES from $CGAP_SCHEMA.GENE_INFO where " .
             " LOCUSLINK in (" .  $list . " ) " .
             "and ORGANISM = '$org'";

      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      if ($stm->execute()) {
        while ( my($cid, $symbol, $title, $locuslink, $gb) 
              = $stm->fetchrow_array() ) {
          push @gene_ids, $locuslink;
          $symbol_loc2info{$symbol}{$locuslink}{$cid} =
             "$cid\001$symbol\001$title\001$locuslink\001$gb";
        }
      } else {
        ## print STDERR "$sql\n";
        print "execute call failed\n";
        $db->disconnect();
        return "";
      }
    }
  }

  if (@syms) {
  
    my $ug_sequence = ($org eq "Hs") ? "hs_ug_sequence" : "mm_ug_sequence";
  
    if(@ug_sp_acc) {

      ## doing ug acc 
      my $acc_list;
      for ($a = 0; $a < @ug_sp_acc; $a += ORACLE_LIST_LIMIT) {
        if (($a + ORACLE_LIST_LIMIT - 1) < @ug_sp_acc) {
          $acc_list = join ",", @ug_sp_acc[$a..$a+ORACLE_LIST_LIMIT-1];
        } else {
          $acc_list = join ",", @ug_sp_acc[$a..$#ug_sp_acc];
        }

        ## doing search in ll2acc.dat for acc first 
        my $sql;
        my @sub_accs;
        my @target_accs = split ",", $acc_list;
        my %query_accs;
        my %exit_accs;
        for( my $i=0; $i<@target_accs; $i++ ) {
          $target_accs[$i] =~ s/'//g;
          $query_accs{$target_accs[$i]} = 1;
        }
        $sql = 
          "select b.CLUSTER_NUMBER, b.GENE, b.DESCRIPTION, a.LL_ID, " .
          " a.ACCESSION from $CGAP_SCHEMA.ll2acc a, $CGAP_SCHEMA.GENE_INFO b " .
          "where a.ACCESSION in (" . $acc_list .
          ") and a.ORGANISM = '$org' and b.ORGANISM = '$org' " .
          " and a.LL_ID = b.LOCUSLINK "; 
          ## " and a.ACCESSION_TYPE = 'm' ";
 
        $stm = $db->prepare($sql);
        if (not $stm) {
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        } else {
          ## my $t0 = [gettimeofday];
          if ($stm->execute()) {
            my ($loc, $accession);
            my ($cid, $locuslink, $symbol, $title, $gb);
            $stm->bind_columns(\$cid, \$symbol, \$title, \$locuslink, \$gb);
            while ($stm->fetch) {
              if( not defined $exit_accs{$gb} ) {
                push @gene_syms, $gb;
                $symbol_loc2info{$symbol}{$locuslink}{$cid} =
                   "$cid\001$symbol\001$title\001$locuslink\001$gb";
                if( defined $query_accs{$gb} ) {
                  delete $query_accs{$gb}; 
                }
                $exit_accs{$gb} = 1;
              }
            }
            ## my $elapsed = tv_interval ($t0, [gettimeofday]);
            ## print "8888 $elapsed\n<br>";
   
          } else {
            print "execute failed\n";
            $db->disconnect();
            return "";
          }
        }

        if( defined %query_accs ) {
          for my $acc (keys %query_accs) {
            push @sub_accs, "'$acc'";
          }
        }

        ## search ug for remaining
        if (@sub_accs) {
          my $list = join ",", @sub_accs;
          $sql_acc =
            "select distinct cluster_number, accession " .
            "from $CGAP_SCHEMA.$ug_sequence " .
            "where accession in (" . $list . ")";
          $stm = $db->prepare($sql_acc);
          if (not $stm) {
            print "<br><b><center>Error in input</b>!</center>";
            $db->disconnect();
            return "";
          }
          if ($stm->execute()) {
            while (my ($cid, $acc) = $stm->fetchrow_array()) {
              if( not defined $uni_cid{$cid} ) {
                push @cids, $cid;
                $uni_cid{$cid} = 1;
              }
            }
          } else {
            ## print STDERR "$sql_acc\n";
            print "execute call failed\n";
            $db->disconnect();
            return "";
          }
        } 

        ## doing sp acc and id
        $sql_acc =
          "select distinct g.cluster_number from " .
          "$CGAP_SCHEMA.sp_primary p, " .
          "$CGAP_SCHEMA.ll2sp s, " .
          "$CGAP_SCHEMA.gene2unigene g, " .
          "$CGAP_SCHEMA.sp_info i " .
          "where p.sp_id_or_secondary in (" . $acc_list . ") " .
          "and p.sp_primary = s.sp_primary " .
          "and i.sp_primary = p.sp_primary " .
          "and i.organism = '$org' " .
          "and g.gene_id = s.ll_id " .
          "and g.organism = '$org' ";
        $stm = $db->prepare($sql_acc);
        if (not $stm) {
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        }
        if ($stm->execute()) {
          while (($cid) = $stm->fetchrow_array()) {
            if( not defined $uni_cid{$cid} ) {
              push @cids, $cid;
              $uni_cid{$cid} = 1;
            }
          }
        } else {
          ## print STDERR "$sql_acc\n";
          print "execute call failed\n";
          $db->disconnect();
          return "";
        }
      }
    }

    if (@prot_acc) {
      my $acc_list;
      for ($a = 0; $a < @prot_acc; $a += ORACLE_LIST_LIMIT) {
        if (($a + ORACLE_LIST_LIMIT - 1) < @prot_acc) {
          $acc_list = join ",", @prot_acc[$a..$a+ORACLE_LIST_LIMIT-1];
        } else {
          $acc_list = join ",", @prot_acc[$a..$#prot_acc];
        }

        $sql_acc =
          "select distinct a.cluster_number " .
          "from $CGAP_SCHEMA.$ug_sequence a, $CGAP_SCHEMA.MRNA2PROT b " .
          "where b.protein_accession in (" . $acc_list . ") " .
          "and a.accession  = b.mrna_accession"; 
        $stm = $db->prepare($sql_acc);
        if (not $stm) {
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        }
        if ($stm->execute()) {
          while (($cid) = $stm->fetchrow_array()) {
            if( not defined $uni_cid{$cid} ) {
              if( not defined $uni_cid{$cid} ) {
                push @cids, $cid;
                $uni_cid{$cid} = 1;
              }
            }
          }
        } else {
          ## print STDERR "$sql_acc\n";
          print "execute call failed\n";
          $db->disconnect();
          return "";
        }
      }
    }

    $wild = 1 if ($term =~ /\%/);
    my $cluster_table =
        ($org eq "Hs") ? "$CGAP_SCHEMA.hs_cluster"
                       : "$CGAP_SCHEMA.mm_cluster";
    my $alias_table = $org eq "Hs" ? "hs_gene_alias" : "mm_gene_alias";
    my ($acc_list, $sql);
    my %genes_got_info;
    for ($a = 0; $a < @syms; $a += ORACLE_LIST_LIMIT) {
      if (($a + ORACLE_LIST_LIMIT - 1) < @syms) {
        $sql = "select CLUSTER_NUMBER, GENE, DESCRIPTION, LOCUSLINK, " .
               "SEQUENCES from $CGAP_SCHEMA.GENE_INFO where " .
               "GENE in (" .
                join(",", @syms[$a..$a+ORACLE_LIST_LIMIT-1]) .
               ") and ORGANISM = '$org'";
      } else {
        $sql = "select CLUSTER_NUMBER, GENE, DESCRIPTION, LOCUSLINK, " .
               "SEQUENCES from $CGAP_SCHEMA.GENE_INFO where " .
               "GENE in (" .
                join(",", @syms[$a..$#syms]) .
               ") and ORGANISM = '$org'";
      }
 
      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      } else {
        $stm = $db->prepare($sql);
        if (not $stm) {
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        } else {
          my ($locuslink, $symbol, $title, $gb);
          ## my $t0 = [gettimeofday];
          if ($stm->execute()) {
            $stm->bind_columns(\$cid, \$symbol, \$title, \$locuslink, \$gb);
            while ($stm->fetch) {
              push @gene_syms, $symbol;
              $genes_got_info{$symbol} = 1;
              $symbol_loc2info{$symbol}{$locuslink}{$cid} = 
                 "$cid\001$symbol\001$title\001$locuslink\001$gb";
            }
            ## my $elapsed = tv_interval ($t0, [gettimeofday]);
            ## print "8888  ll $elapsed\n<br>";
          } else {
            print "execute failed\n";
            $db->disconnect();
            return "";
          }
        }
      }
    }
 
    if( defined %genes_got_info ) {
      for my $gene (keys %genes_got_info) {
        for( my $i=0; $i<@syms; $i++ ) {
          if( $syms[$i] eq "'$gene'" ) {
            splice @syms, $i, 1;
          }
        }
      }
    }

    for ($a = 0; $a < @syms; $a += ORACLE_LIST_LIMIT) {
      my @tmp_sym;
      if (($a + ORACLE_LIST_LIMIT - 1) < @syms) {
        @tmp_sym = @syms[$a..$a+ORACLE_LIST_LIMIT-1];
      } else {
        @tmp_sym = @syms[$a..$#syms];
      }

      $sql_sym =
        ## "select distinct a.cluster_number, a.gene_uc, a.type " .
        ## "from $CGAP_SCHEMA.$alias_table a, $cluster_table b " .
        "select distinct a.cluster_number, b.gene, a.type " .
        "from $CGAP_SCHEMA.$alias_table a, $CGAP_SCHEMA.GENE_INFO b " .
        "where (a.gene_uc like " .
           join(" or a.gene_uc like ", @tmp_sym) . 
                  ") and a.cluster_number = b.cluster_number";
      $stm = $db->prepare($sql_sym);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      if ($stm->execute()) {
        while (($cid, $gene, $type) = $stm->fetchrow_array()) {
          if ($type eq 'OF') {
            $official{$gene}{$cid} = 1;
          } elsif ($type eq 'PF') {
            $preferred{$gene}{$cid} = 1;
          } elsif ($type eq 'AL') {
            $alias{$gene}{$cid} = 1;
          }
        }
        while (($gene, $cids) = each(%official)) {
          while ($cid = each(%$cids)) {
            if( not defined $uni_cid{$cid} ) {
              push @cids, $cid;
              $uni_cid{$cid} = 1; 
              delete $preferred{$gene};
              delete $alias{$gene};
            }
          }
        }
        if (! $wild) {
          while (($gene, $cids) = each(%preferred)) {
            while ($cid = each(%$cids)) {
              if( not defined $uni_cid{$cid} ) {
                push @cids, $cid;
                $uni_cid{$cid} = 1; 
                delete $alias{$gene};
              }
            }
          }
          while (($gene, $cids) = each(%alias)) {
            while ($cid = each(%$cids)) {
              if( not defined $uni_cid{$cid} ) {
                push @cids, $cid;
                $uni_cid{$cid} = 1; 
              }
            }
          }
        }
        undef %official;
        undef %preferred;
        undef %alias;
      } else {
        ## print STDERR "$sql_sym\n";
        print "execute call failed\n";
        $db->disconnect();
        return "";
      }
    }

    if ( @refseqgene ) {
      $sql =
        "select distinct a.cluster_number " .
        "from $cluster_table a, $CGAP_SCHEMA.LL2REFSEQGENE b where " .
        "( b.ACCESSION like " .
        join(" or b.ACCESSION like ", @refseqgene ) .
        ") " .
        " and ORGANISM = '$org' and a.LOCUSLINK = b.LOCUSLINK";
      $stm = $db->prepare($sql);
      if (not $stm) {
        ## print "$sql\n<br>";
        ## print "$DBI::errstr<br>\n";
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      if ($stm->execute()) {
        while (($cid) = $stm->fetchrow_array()) {
            if( not defined $uni_cid{$cid} ) {
              push @cids, $cid;
              $uni_cid{$cid} = 1;
            }
        }
      } 
      else {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
    }

    if ( @ensembl_gene or @ensembl_acc or @ensembl_protein_acc ) {
      $sql =
        "select distinct a.cluster_number " .
        "from $cluster_table a, $CGAP_SCHEMA.LL2ENSEMBL b where ";
      if ( @ensembl_gene ) {
        $sql = $sql .
                  "( ( b.ENSEMBL_GENE like " .
                  join(" or b.ENSEMBL_GENE like ", @ensembl_gene ) .
                  ") ";
      }
      if ( @ensembl_acc ) {
        if ( @ensembl_gene ) {
          $sql = $sql .
               " or " .
               " ( b.ENSEMBL_ACCESSION like " .
               join(" or b.ENSEMBL_ACCESSION like ", @ensembl_acc ) .
               ") ";
        }
        else {
          $sql = $sql .
               " ( ( b.ENSEMBL_ACCESSION like " .
               join(" or b.ENSEMBL_ACCESSION like ", @ensembl_acc ) .
               ") ";
        }
      }
      if( @ensembl_protein_acc ) {
        if ( @ensembl_gene or @ensembl_acc ) {
          $sql = $sql .
               " or " .
               " ( b.ENSEMBL_PROTEIN_ACCESSION like " .
               join(" or b.ENSEMBL_PROTEIN_ACCESSION like ", @ensembl_protein_acc )  .
               ") ";
        }
        else {
          $sql = $sql .
               " ( ( b.ENSEMBL_PROTEIN_ACCESSION like " .
               join(" or b.ENSEMBL_PROTEIN_ACCESSION like ", @ensembl_protein_acc )  .
               ") ";
        }
      }
      $sql = $sql .
               ") and ORGANISM = '$org' and a.LOCUSLINK = b.LOCUSLINK";
      $stm = $db->prepare($sql);
      if (not $stm) {
        ## print "$sql\n<br>";
        ## print "$DBI::errstr<br>\n";
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      if ($stm->execute()) {
        while (($cid) = $stm->fetchrow_array()) {
            if( not defined $uni_cid{$cid} ) {
              push @cids, $cid;
              $uni_cid{$cid} = 1;
            }
        }
      }
      else {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
    }

  }

  if ($page == $CLONE_PAGE) {
    return(FormatGenes($page, $org, $cmd, $page_header, \@cids)) ;
  }
  else {
    return(FormatGenes($page, $org, $cmd, $page_header,
      OrderGenesBySymbol($page, $org, \@cids, \%symbol_loc2info), \@gene_ids, \@gene_syms));
  }
}

######################################################################
sub GetProtSims {
  my ($db, $org, $cid) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my $build = $BUILDS{$org};

  if (not $db) {
    return "";
  }

  ## load ORG_CODE_TABLE
  my ($ORGANISM_ID, $ORGANISM_CODE);
  my %ORG_CODE_TABLE;
  my ($sql, $stm);

  $sql = "select ORGANISM_ID, ORGANISM_CODE from $RFLP_SCHEMA.organism ";
 
  $stm = $db->prepare($sql);
 
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
 
  if(!$stm->execute()) {
     ## print STDERR "$sql\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
     $db->disconnect();
     return "";
  }
 
  $stm->bind_columns(\$ORGANISM_ID, \$ORGANISM_CODE);
 
  while($stm->fetch) {
    $ORG_CODE_TABLE{$ORGANISM_ID} = $ORGANISM_CODE;
  }

  my $sql = "select organism_id, gi, protid, pct, aln " .
      "from $RFLP_SCHEMA.ug_protsim\@RFLP where " .
      (sprintf "cluster_number = %d", $cid) . " and " .
      (sprintf "build_id = %d", $build);

  my (@protsim, @protsims);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    ## print STDERR "prepare call failed\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (@protsim = $stm->fetchrow_array()) {
        $protsim[0] = $ORG_CODE_TABLE{$protsim[0]};
        push @protsims, (join "\002", @protsim);
      }
      ## if (@protsims == 0) {
      ##   SetStatus(S_NO_DATA);
      ## }
    }
    else {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
  }

  return (join "\001", @protsims);

}



######################################################################
sub GetBatchGenes_1 {
  my ($base, $page, $organism, $filedata) = @_;

  if( not defined $cluster_table{$organism} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  $BASE = $base;

  my ($org, $cid);
  my (@rows, @accs, @lls, %cids, @ug_sp_accs, @prot_accs, @syms, %syms, %cid2info, %input2loc);
  my ($acc_list, $ll_list, $a, $l);
  my ($sql, $stm, $type, $gene, $cids);
  my %goodInput;
  my @garbage;
  my (%official, %preferred, %alias, $wild, @symbols);
  my (@gene_ids, @gene_syms);

  my $cluster_table = ($organism eq "Hs") ? "hs_cluster" : "mm_cluster";
  my $ug_sequence = ($organism eq "Hs") ? "hs_ug_sequence" : "mm_ug_sequence";
  my (@filtered_filedata, $new_filedata);
  my (@ensembl_gene, @ensembl_acc, @ensembl_protein_acc);
  my (@refseqgene);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  } 

  my @tempArray;
  if( $filedata =~ /\r/ ) {
    @tempArray = split "\r", $filedata;
  } 
  else {
    @tempArray = split "\n", $filedata;
  } 
  for (my $t = 0; $t < @tempArray; $t++ ) {
    $tempArray[$t] =~  s/\s//g;
    next if ($tempArray[$t] eq "");
    next if ($tempArray[$t] =~ /\?/);
    if ($tempArray[$t] =~ /\*/){
      push @filtered_filedata, $tempArray[$t];
      next;
    }
    push @filtered_filedata, $tempArray[$t];
    if ($tempArray[$t] =~ /(hs|mm)\.(\d+)/i) { # cluster
      ($org, $cid) = ($1, $2);
      next if (lc($organism) ne lc($org));

      $sql = "select distinct cluster_number, GENE from " .
             "$CGAP_SCHEMA.$cluster_table " .
             "where cluster_number = $cid";
 
      $stm = $db->prepare($sql);
      if (not $stm) {
        ## print STDERR "prepare call failed\n";
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      } else {
        if ($stm->execute()) {
          $stm->bind_columns(\$cid, \$gene);
          if ($stm->fetch) {
            if (not $cids{$cid}) {
              push @rows, $cid;
            }
            $cid2input{$cid} = $tempArray[$t];
            $input2cid{$tempArray[$t]}{$cid} = 1;
            $goodInput{$tempArray[$t]} = 1;
            $cids{$cid} = 1;
          }
          $stm->finish();
        } else {
          print "execute failed\n";
          $db->disconnect();
          return "";
        }
      }
    } elsif ($tempArray[$t] =~ /^\d+$/) { # locuslink
      push @lls, $tempArray[$t];
    } else { # accession symbol
      $tempArray[$t] =~ s/ //g;
      $tempArray[$t] =~ tr/a-z/A-Z/;
      my $tmp_value = convrtSingleToDoubleQuote($tempArray[$t]);
      $syms{$tempArray[$t]} = 1;
      ## push @syms, "'$tmp_value'";
      ## my $tmp_sym = "'$tmp_value'";
      if( ($tempArray[$t] =~ /^NP_/) or ($tempArray[$t] =~ /^XP_/) ) {
        push @prot_accs, "'$tmp_value'";
      }
      elsif( $tempArray[$t] =~ /^NG_/ ) {
        push @refseqgene, "'$tmp_value'";
      }
      elsif( $tempArray[$t] =~ /^ENSG/ ) {
        push @ensembl_gene, "'$tmp_value'";
      }
      elsif( $tempArray[$t] =~ /^ENSMUSG/ ) {
        push @ensembl_gene, "'$tmp_value'";
      }
      elsif( $tempArray[$t] =~ /^ENST/ ) {
        push @ensembl_acc, "'$tmp_value'";
      }
      elsif( $tempArray[$t] =~ /^ENSMUST/ ) {
        push @ensembl_acc, "'$tmp_value'";
      }
      elsif( $tempArray[$t] =~ /^ENSP/ ) {
        push @ensembl_protein_acc, "'$tmp_value'";
      }
      elsif( $tempArray[$t] =~ /^ENSMUSP/ ) {
        push @ensembl_protein_acc, "'$tmp_value'";
      }
      else {
        push @ug_sp_accs, "'$tmp_value'";
      }
    }
  }
    
  if (@ug_sp_accs) {
    for ($a = 0; $a < @ug_sp_accs; $a += ORACLE_LIST_LIMIT) {
      if (($a + ORACLE_LIST_LIMIT - 1) < @ug_sp_accs) {
        $acc_list = join(",", @ug_sp_accs[$a..$a+ORACLE_LIST_LIMIT-1]);
      } else {
        $acc_list = join(",", @ug_sp_accs[$a..$#ug_sp_accs]);
      }

      ## doing search in ll2acc.dat for acc first
      my $sql;
      my @sub_accs;
      my @target_accs = split ",", $acc_list;
      my %query_accs;
      my %exit_accs;
      for( my $i=0; $i<@target_accs; $i++ ) {
        $target_accs[$i] =~ s/'//g;
        $query_accs{$target_accs[$i]} = 1;
      }
      $sql =
        "select unique b.CLUSTER_NUMBER, b.GENE, b.DESCRIPTION, a.LL_ID, " .
        " a.ACCESSION from $CGAP_SCHEMA.ll2acc a, $CGAP_SCHEMA.GENE_INFO b " .
        "where a.ACCESSION in (" . $acc_list .
        ") and a.ORGANISM = '$organism' and b.ORGANISM = '$organism' " .
        " and a.LL_ID = b.LOCUSLINK "; 
        ## " and a.ACCESSION_TYPE = 'm' ";
 
      $stm = $db->prepare($sql);
      if (not $stm) {
        ## print "$sql\n";
        ## print "$DBI::errstr\n";
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      } else {
        ## my $t0 = [gettimeofday];
        if ($stm->execute()) {
          my ($loc, $accession);
          my ($cid, $locuslink, $symbol, $title, $gb);
          $stm->bind_columns(\$cid, \$symbol, \$title, \$locuslink, \$gb);
          while ($stm->fetch) {
            if( not defined $exit_accs{$gb} ) { 
              $exit_accs{$gb} = 1;
              push @gene_syms, $gb;
              $cid2input{$cid} = $gb;
              $input2cid{$gb}{$cid} = 1;
              $goodInput{$gb} = 1;
              $cids{$cid} = 1;
              $cid2info{$cid}{$gb} =
                 "$cid\001$symbol\001$title\001$locuslink\001$gb";
              if( defined $query_accs{$gb} ) {
                delete $query_accs{$gb};
              }
              if( defined $syms{ $gb } ) {
                delete $syms{$gb};
              }
            }
          }
          ## my $elapsed = tv_interval ($t0, [gettimeofday]);
          ## print "8888 $elapsed\n<br>";
 
        } else {
          print "execute failed\n";
          $db->disconnect();
          return "";
        }
      }
 
      if( defined %query_accs ) {
        for my $acc (keys %query_accs) {
          push @sub_accs, "'$acc'";
        }
      }
 
      ## search ug for remaining
      if (@sub_accs) {
        my $list = join ",", @sub_accs;
        $sql =
          "select distinct cluster_number, accession " .
          "from $CGAP_SCHEMA.$ug_sequence " .
          "where accession in (" . $list . ")";
        $stm = $db->prepare($sql);
        if (not $stm) {
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        }
        if ($stm->execute()) {
          while (my ($cid, $acc) = $stm->fetchrow_array()) {
            ## if (not $cids{$cid}) {
            push @rows, $cid;
            ## }
            $cid2input{$cid} = $acc;
            $input2cid{$acc}{$cid} = 1;
            $goodInput{$acc} = 1;
            $cids{$cid} = 1;
            if( defined $syms{ $acc } ) {
              delete $syms{$acc};
            }
          }
        } else {
          ## print STDERR "$sql_acc\n";
          print "execute call failed\n";
          $db->disconnect();
          return "";
        }
      }
 
      ## doing sp acc and id
      $sql =
        "select distinct g.cluster_number, p.sp_id_or_secondary from " .
        "$CGAP_SCHEMA.sp_primary p, " .
        "$CGAP_SCHEMA.ll2sp s, " .
        "$CGAP_SCHEMA.gene2unigene g, " .
        "$CGAP_SCHEMA.sp_info i " .
        "where p.sp_id_or_secondary in (" . $acc_list . ") " .
        "and p.sp_primary = s.sp_primary " .
        "and i.sp_primary = p.sp_primary " .
        "and i.organism = '$organism' " .
        "and g.gene_id = s.ll_id " .
        "and g.organism = '$organism' ";
      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      } 
      ## my $t0 = [gettimeofday];
      if ($stm->execute()) {
        while ( my($cid, $sp_id_or_secondary) = $stm->fetchrow_array()) {
          if (not $cids{$cid}) {
            push @rows, $cid;
          }
          $cid2input{$cid} = $sp_id_or_secondary;
          $input2cid{$sp_id_or_secondary}{$cid} = 1;
          $goodInput{$sp_id_or_secondary} = 1;
          $cids{$cid} = 1;
          if( defined $syms{ $sp_id_or_secondary } ) {
            delete $syms{$sp_id_or_secondary};
          }
        }
      } else {
        ## print STDERR "$sql\n";
        print "execute call failed\n";
        $db->disconnect();
        return "";
      }
      ## my $elapsed = tv_interval ($t0, [gettimeofday]);
      ## print "8888  doing sp acc and id $elapsed\n";
    }
  }


  if (@prot_accs) {
    for ($a = 0; $a < @prot_accs; $a += ORACLE_LIST_LIMIT) {
      if (($a + ORACLE_LIST_LIMIT - 1) < @prot_accs) {
        $acc_list = join(",", @prot_accs[$a..$a+ORACLE_LIST_LIMIT-1]);
      } else {
        $acc_list = join(",", @prot_accs[$a..$#prot_accs]);
      }
      $sql = "select distinct a.cluster_number, a.accession, " .
             "c.protein_accession from " .
             "$CGAP_SCHEMA.$ug_sequence a, " .
             "$CGAP_SCHEMA.MRNA2PROT c " .
             "where c.protein_accession in (" . $acc_list . ") " .
             "and a.accession = c.mrna_accession ";
 
      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      } else {
        ## my $t0 = [gettimeofday];
        if ($stm->execute()) {
          my $accession;
          my $protein_accession;
          $stm->bind_columns(\$cid, \$accession, \$protein_accession);
          while ($stm->fetch) {
            if (not $cids{$cid}) {
              push @rows, $cid;
            }
            $cid2input{$cid} = $protein_accession;
            $input2cid{$protein_accession}{$cid} = 1;
            $goodInput{$protein_accession} = 1;
            $cids{$cid} = 1;
            if( defined $syms{ $protein_accession } ) {
              delete $syms{$protein_accession};
            }
          }
          ## my $elapsed = tv_interval ($t0, [gettimeofday]);
          ## print "8888  prot_accs $elapsed\n<br>";
        } else {
          print "execute failed\n";
          $db->disconnect();
          return "";
        }
      }
    }
  }
  ## my $t0 = [gettimeofday];
  undef @syms;
  for my $tmp_str (keys %syms) {
    push @syms, "'$tmp_str'";
  }
  if (@syms) {
    my %genes_got_info;
    for ($a = 0; $a < @syms; $a += ORACLE_LIST_LIMIT) {
      if (($a + ORACLE_LIST_LIMIT - 1) < @syms) {
        $sql = "select CLUSTER_NUMBER, GENE, DESCRIPTION, LOCUSLINK, " .
               "SEQUENCES from $CGAP_SCHEMA.GENE_INFO where " .
               "GENE in (" .
                join(",", @syms[$a..$a+ORACLE_LIST_LIMIT-1]) .
               ") and ORGANISM = '$organism'";
      } else {
        $sql = "select CLUSTER_NUMBER, GENE, DESCRIPTION, LOCUSLINK, " .
               "SEQUENCES from $CGAP_SCHEMA.GENE_INFO where " .
               "GENE in (" .
                join(",", @syms[$a..$#syms]) .
               ") and ORGANISM = '$organism'";
      }

      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      } else {
        $stm = $db->prepare($sql);
        if (not $stm) {
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        } else {
          my ($locuslink, $symbol, $title, $gb);
          ## my $t0 = [gettimeofday];
          if ($stm->execute()) {
            $stm->bind_columns(\$cid, \$symbol, \$title, \$locuslink, \$gb);
            while ($stm->fetch) {
              ## if (not $cids{$cid}) {
              ##   push @rows, $cid;
              ## }
              push @gene_syms, $symbol;
              $cid2input{$cid} = $symbol;
              $input2cid{$symbol}{$cid} = 1;
              $goodInput{$symbol} = 1;
              $cids{$cid} = 1;
              $genes_got_info{$symbol} = 1;
              $cid2info{$cid}{$symbol} =
                "$cid\001$symbol\001$title\001$locuslink\001$gb";
            }
            ## my $elapsed = tv_interval ($t0, [gettimeofday]);
            ## print "8888  ll $elapsed\n<br>";
          } else {
            print "execute failed\n";
            $db->disconnect();
            return "";
          }
        }
      }
    } 

    if( defined %genes_got_info ) {
      for( my $i=0; $i<@syms; $i++ ) {
        for my $gene (keys %genes_got_info) {
          if( $syms[$i] eq $gene ) {
            splice @syms, $i, 1;
            last;
          }
        }
      }
    }

    my $cluster_table =

       ($organism eq "Hs") ? "$CGAP_SCHEMA.hs_cluster"
                      : "$CGAP_SCHEMA.mm_cluster";
 
    my $alias_table = $organism eq "Hs" ? "hs_gene_alias" : "mm_gene_alias";
    for ($a = 0; $a < @syms; $a += ORACLE_LIST_LIMIT) {
      if (($a + ORACLE_LIST_LIMIT - 1) < @syms) {
        $sql =
          "select distinct a.cluster_number, a.gene_uc, a.type " .
          "from $CGAP_SCHEMA.$alias_table a, $cluster_table b " .
          "where a.gene_uc in (" .
             join(",", @syms[$a..$a+ORACLE_LIST_LIMIT-1]) . 
             ") and a.cluster_number = b.cluster_number";
      } else {
        $sql =
          "select distinct a.cluster_number, a.gene_uc, a.type " .
          "from $CGAP_SCHEMA.$alias_table  a, $cluster_table b " .
          "where a.gene_uc in (" .
              join(",", @syms[$a..$#syms]) . 
              ") and a.cluster_number = b.cluster_number";
      }
 
      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      ## my $t0 = [gettimeofday];
      if ($stm->execute()) {
        while (($cid, $gene, $type) = $stm->fetchrow_array()) {
          if ($type eq 'OF') {
            $official{$gene}{$cid} = 1;
          } elsif ($type eq 'PF') {
            $preferred{$gene}{$cid} = 1;
          } elsif ($type eq 'AL') {
            $alias{$gene}{$cid} = 1;
          }
        }
        ## my $elapsed = tv_interval ($t0, [gettimeofday]);
        ## print "8888  sym $elapsed\n<br>";
        while (($gene, $cids) = each(%official)) {
          while ($cid = each(%$cids)) {
            if (not $cids{$cid}) {
              push @rows, $cid;
            }
            $cid2input{$cid} = $gene;
            $input2cid{$gene}{$cid} = 1;
            $goodInput{$gene} = 1;
            delete $preferred{$gene};
            delete $alias{$gene};
            $cids{$cid} = 1;
          }
        }
        while (($gene, $cids) = each(%preferred)) {
          while ($cid = each(%$cids)) {
            if (not $cids{$cid}) {
              push @rows, $cid;
            }
            $cid2input{$cid} = $gene;
            $input2cid{$gene}{$cid} = 1;
            $goodInput{$gene} = 1;
            delete $alias{$gene};
            $cids{$cid} = 1;
          }
        }
        while (($gene, $cids) = each(%alias)) {
          while ($cid = each(%$cids)) {
            if (not $cids{$cid}) {
              push @rows, $cid;
            }
            $cid2input{$cid} = $gene;
            $input2cid{$gene}{$cid} = 1;
            $goodInput{$gene} = 1;
            $cids{$cid} = 1;
          }
        }
        undef %official;
        undef %preferred;
        undef %alias;
      } else {
        ## print STDERR "$sql\n";
        print "execute call failed\n";
        $db->disconnect();
        return "";
      }
    }

    if ( @refseqgene ) {
      for ($a = 0; $a < @refseqgene; $a += ORACLE_LIST_LIMIT) {
        if (($a + ORACLE_LIST_LIMIT - 1) < @refseqgene) {
          $sql =
            "select distinct a.cluster_number , b.ACCESSION " .
            "from $cluster_table a, $CGAP_SCHEMA.LL2REFSEQGENE b where " .
            "b.ACCESSION in (" .
            join(",", @refseqgene[$a..$a+ORACLE_LIST_LIMIT-1]) .
            ") and ORGANISM = '$organism' and a.LOCUSLINK = b.LOCUSLINK";
        } else {
          $sql =
            "select distinct a.cluster_number , b.ACCESSION " .
            "from $cluster_table a, $CGAP_SCHEMA.LL2REFSEQGENE b where " .
            "b.ACCESSION in (" .
            join(",", @refseqgene[$a..$#refseqgene]) .
            ") and ORGANISM = '$organism' and a.LOCUSLINK = b.LOCUSLINK";
        }
 
        $stm = $db->prepare($sql);
        if (not $stm) {
          ## print "$sql\n<br>";
          ## print "$DBI::errstr<br>\n";
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        }
        if ($stm->execute()) {
          while (my ($cid, $acc) = $stm->fetchrow_array()) {
              if (not $cids{$cid}) {
                push @rows, $cid;
              }
              $cid2input{$cid} = $acc;
              $input2cid{$acc}{$cid} = 1;
              $goodInput{$acc} = 1;
              $cids{$cid} = 1;
          }
        }
        else {
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        }
      }
    }


    if ( @ensembl_gene ) {
      for ($a = 0; $a < @ensembl_gene; $a += ORACLE_LIST_LIMIT) {
        if (($a + ORACLE_LIST_LIMIT - 1) < @ensembl_gene) {
          $sql =
            "select distinct a.cluster_number , b.ENSEMBL_GENE " .
            "from $cluster_table a, $CGAP_SCHEMA.LL2ENSEMBL b where " .
            "b.ENSEMBL_GENE in (" . 
            join(",", @ensembl_gene[$a..$a+ORACLE_LIST_LIMIT-1]) .
            ") and ORGANISM = '$organism' and a.LOCUSLINK = b.LOCUSLINK";
        } else {
          $sql =
            "select distinct a.cluster_number , b.ENSEMBL_GENE " .
            "from $cluster_table a, $CGAP_SCHEMA.LL2ENSEMBL b where " .
            "b.ENSEMBL_GENE in (" .
            join(",", @ensembl_gene[$a..$#ensembl_gene]) .
            ") and ORGANISM = '$organism' and a.LOCUSLINK = b.LOCUSLINK";
        }
  
        $stm = $db->prepare($sql);
        if (not $stm) {
          ## print "$sql\n<br>";
          ## print "$DBI::errstr<br>\n";
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        }
        if ($stm->execute()) {
          while (my ($cid, $gene) = $stm->fetchrow_array()) {
              if (not $cids{$cid}) {
                push @rows, $cid;
              }
              $cid2input{$cid} = $gene;
              $input2cid{$gene}{$cid} = 1;
              $goodInput{$gene} = 1;
              $cids{$cid} = 1;
          }
        }
        else {
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        }
      }
    }
 
    if ( @ensembl_acc ) {
      for ($a = 0; $a < @ensembl_acc; $a += ORACLE_LIST_LIMIT) {
        if (($a + ORACLE_LIST_LIMIT - 1) < @ensembl_acc) {
          $sql =
            "select distinct a.cluster_number , b.ENSEMBL_ACCESSION " .
            "from $cluster_table a, $CGAP_SCHEMA.LL2ENSEMBL b where " .
            "b.ENSEMBL_ACCESSION in (" .
            join(",", @ensembl_acc[$a..$a+ORACLE_LIST_LIMIT-1]) .
            ") and ORGANISM = '$organism' and a.LOCUSLINK = b.LOCUSLINK";
        } else {
          $sql =
            "select distinct a.cluster_number , b.ENSEMBL_ACCESSION " .
            "from $cluster_table a, $CGAP_SCHEMA.LL2ENSEMBL b where " .
            "b.ENSEMBL_ACCESSION in (" .
            join(",", @ensembl_acc[$a..$#ensembl_acc]) .
            ") and ORGANISM = '$organism' and a.LOCUSLINK = b.LOCUSLINK";
        }
   
        $stm = $db->prepare($sql);
        if (not $stm) {
          ## print "$sql\n<br>";
          ## print "$DBI::errstr<br>\n";
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        }
        if ($stm->execute()) {
          while (my ($cid, $acc) = $stm->fetchrow_array()) {
              if (not $cids{$cid}) {
                push @rows, $cid;
              }
              $cid2input{$cid} = $acc;
              $input2cid{$acc}{$cid} = 1;
              $goodInput{$acc} = 1;
              $cids{$cid} = 1;
          }
        }
        else {
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        }
      }
    }
  
    if ( @ensembl_protein_acc ) {
      for ($a = 0; $a < @ensembl_protein_acc; $a += ORACLE_LIST_LIMIT) {
        if (($a + ORACLE_LIST_LIMIT - 1) < @ensembl_protein_acc) {
          $sql =
            "select distinct a.cluster_number , b.ENSEMBL_PROTEIN_ACCESSION " .
            "from $cluster_table a, $CGAP_SCHEMA.LL2ENSEMBL b where " .
            "b.ENSEMBL_PROTEIN_ACCESSION in (" .
            join(",", @ensembl_protein_acc[$a..$a+ORACLE_LIST_LIMIT-1]) .
            ") and ORGANISM = '$organism' and a.LOCUSLINK = b.LOCUSLINK";
        } else {
          $sql =
            "select distinct a.cluster_number, b.ENSEMBL_PROTEIN_ACCESSION " .
            "from $cluster_table a, $CGAP_SCHEMA.LL2ENSEMBL b where " .
            "b.ENSEMBL_PROTEIN_ACCESSION in (" .
            join(",", @ensembl_protein_acc[$a..$#ensembl_protein_acc]) .
            ") and ORGANISM = '$organism' and a.LOCUSLINK = b.LOCUSLINK";
        }
   
        $stm = $db->prepare($sql);
        if (not $stm) {
          ## print "$sql\n<br>";
          ## print "$DBI::errstr<br>\n";
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        }
        if ($stm->execute()) {
          while (my ($cid, $acc) = $stm->fetchrow_array()) {
              if (not $cids{$cid}) {
                push @rows, $cid;
              }
              $cid2input{$cid} = $acc;
              $input2cid{$acc}{$cid} = 1;
              $goodInput{$acc} = 1;
              $cids{$cid} = 1;
          }
        }
        else {
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        }
      }
    }
  }

  ## my $elapsed = tv_interval ($t0, [gettimeofday]);
  ## print "8888  sym $elapsed\n<br>";
 
  if (@lls) {
    for ($l = 0; $l < @lls; $l += ORACLE_LIST_LIMIT) {
      if (($l + ORACLE_LIST_LIMIT - 1) < @lls) {
        $ll_list = join(",", @lls[$l..$l+ORACLE_LIST_LIMIT-1]);
      } else {
        $ll_list = join(",", @lls[$l..$#lls]);
      }

      $sql = "select CLUSTER_NUMBER, GENE, DESCRIPTION, LOCUSLINK, " .
             "SEQUENCES from $CGAP_SCHEMA.GENE_INFO where " .
             " LOCUSLINK in (" .  $ll_list . " ) " .
             "and ORGANISM = '$organism'"; 

      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      } else {
        my ($locuslink, $symbol, $title, $gb);
        ## my $t0 = [gettimeofday];
        if ($stm->execute()) {
          $stm->bind_columns(\$cid, \$symbol, \$title, \$locuslink, \$gb);
          while ($stm->fetch) {
            ## if (not $cids{$cid}) {
            ##   push @rows, $cid;
            ## }
            push @gene_ids, $locuslink;
            $cid2input{$cid} = $locuslink;
            $input2cid{$locuslink}{$cid} = 1;
            $goodInput{$locuslink} = 1;
            $cids{$cid} = 1;
            $cid2info{$cid}{$locuslink} =
             "$cid\001$symbol\001$title\001$locuslink\001$gb";
          }
          ## my $elapsed = tv_interval ($t0, [gettimeofday]);
          ## print "8888  ll $elapsed\n<br>";
        } else {
          print "execute failed\n";
          $db->disconnect();
          return "";
        }
      }
    }
  }
 
  $db->disconnect();
 
  for (my $t = 0; $t < @tempArray; $t++ ) {
    if( not defined $goodInput{$tempArray[$t]} ) {
      if( $tempArray[$t] =~ /\*/ ) {
        push @garbage, 
          $tempArray[$t] . ": wild card is not allowed in batch search.";
      }
      elsif( $tempArray[$t] =~ /\?/ ) {
        push @garbage,
          $tempArray[$t] . ": wild card is not allowed in batch search.";
      }
      else {
        push @garbage, $tempArray[$t];
      }
    }
  }
 
  $new_filedata = join ("\n", @filtered_filedata) . "\n";
  my $cmd = "" . $BASE . "/Genes/GetBatchGenes?ORG=$organism&FILEDATA=$new_filedata&filenameFILE=";
 
  my $hs_bld = $BUILDS{'Hs'};  $hs_bld =~ s/^1//;
  my $mm_bld = $BUILDS{'Mm'};  $mm_bld =~ s/^2//;
 
  my $page_header = "<table><tr valign=top>" .
      "<td><b>Batch GeneFinder Results For</b>:</td>" .
      "<td>" .
      "$organism; " .
      "</td></tr>" .
      "<tr><td><b>UniGene Build</b>:</td>" .
      "<td>Hs.$hs_bld/Mm.$mm_bld</td></tr></table>";
 
  if($page == $CLONE_PAGE) {
    return (FormatGenesWithInput($page, $organism, $cmd, $page_header, \@rows));
  }
  else {
    return
      (FormatGenesWithInput($page, $organism, $cmd, $page_header,
       OrderGenesByInput($page, $organism, \@rows, \@tempArray, \%cid2info, \%input2loc), \@garbage, \@gene_ids, \@gene_syms));
  }
}
 
######################################################################
sub GetGOGenes_1 {

  my $sql_clu;
  my ($base, $page, $org, $go_id) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  $BASE = $base;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  my ($goname);
  my $sql = "select distinct go_name from $CGAP_SCHEMA.Go_Name " .
            "where go_id = '$go_id'";

  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      $stm->bind_columns(\$goname);
      $stm->fetch;
      $stm->finish();
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

#my $cluster_table = ($org eq "Hs" ? "hs_cluster" : "mm_cluster");

my $sql = qq!
  select unique c.cluster_number
  from
    $CGAP_SCHEMA.ll_go l,
    $CGAP_SCHEMA.go_ancestor a,
    $CGAP_SCHEMA.gene2unigene c
  where
        a.go_ancestor_id = '$go_id'
    and l.organism = '$org'
    and l.go_id = a.go_id
    and c.gene_id = l.ll_id
    and not exists (
      select
        a1.go_id
      from
        $CGAP_SCHEMA.go_ancestor a1
      where
            a1.go_id = '$go_id'
        and a1.go_ancestor_id in ($GO_OBSOLETE_LIST)
    )
!;

  my ($row, @rows);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (($row) = $stm->fetchrow_array()) {
          push @rows, $row
      }
      ## if (@rows == 0) {
      ##   SetStatus(S_NO_DATA);
      ## }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }
  $db->disconnect();

  my $cmd = "GoGeneQuery?" .
      "ORG=$org&" .
      "GOID=$go_id";

  my $hs_bld = $BUILDS{'Hs'};  $hs_bld =~ s/^1//;
  my $mm_bld = $BUILDS{'Mm'};  $mm_bld =~ s/^2//;

  my $page_header = "<table><tr valign=top>" .
      "<td><b>GeneFinder Results For</b>:</td>" .
      "<td>" .
          "$org; " .
          ($goname   ? $goname   . "; " : "")   .
          "</td></tr>" .
      "<tr><td><b>UniGene Build</b>:</td>" .
      "<td>Hs.$hs_bld/Mm.$mm_bld</td></tr></table>";

  if( $page == $CLONE_PAGE ) {
    return (FormatGenes($page, $org, $cmd, $page_header, \@rows));
  }
  else {
    return
      (FormatGenes($page, $org, $cmd, $page_header,
      OrderGenesBySymbol($page, $org, \@rows)));
  }
}

######################################################################
sub GetGOTerms_1 {

  my ($pattern, $validate) = @_;
  my $options;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  $pattern =~ tr/A-Z/a-z/;
  $pattern =~ s/'/`/g;
  $pattern =~ s/\*/%/g;
  my $sql = "select distinct go_name from $CGAP_SCHEMA.Go_Name n, " .
            "$CGAP_SCHEMA.ll_go g " .
            "where lower(n.go_name) like '$pattern'" .
            "and n.go_id = g.go_id";

  my ($name, @names);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      $stm->bind_columns(\$name);
      while ($stm->fetch) {
        push @names, $name
      }
      if (@names == 0) {
        ## SetStatus(S_NO_DATA);
        print "no data\n";
      }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }

  }
  $db->disconnect();

  if (@names == 0) {
    if ($validate eq "1") {
      $options = "No Matching Terms";
    } else {
      $options = "<OPTION>No Matching Terms</OPTION>";
    }
  } else {
    $options = "<OPTION>" . join("</OPTION><OPTION>",@names) . "</OPTION>";
  }

  return $options;
}

######################################################################
sub GetKeggTerms_1 {

  my ($pattern) = @_;
  my ($name, @names, $options);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  $pattern =~ tr/A-Z/a-z/;
  $pattern =~ s/\\'/''/g;
  $pattern =~ s/\*/%/g;

  my $sql = "select distinct name from $CGAP_SCHEMA.KeggEnzymes " .
            "where lower(name) like '$pattern'";

  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      $stm->bind_columns(\$name);
      while ($stm->fetch) {
        push @names, ucfirst $name
      }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }
  my $sql = "select distinct name from $CGAP_SCHEMA.KeggCompounds " .
            "where lower(name) like '$pattern'";

  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      $stm->bind_columns(\$name);
      while ($stm->fetch) {
        push @names, ucfirst $name
      }
      if (@names == 0) {
        ## SetStatus(S_NO_DATA);
        print "no data\n";
      }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  $db->disconnect();

  if (@names == 0) {
    $options = "<OPTION>No Matching Terms</OPTION>";
  } else {
    $options = "<OPTION>" . join("</OPTION><OPTION>", sort @names) . "</OPTION>";
  }

  return $options;
}

######################################################################
sub GetPathInfo_1 {

  my ($org, $bcid, $ecno, $llno) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  my ($stm, $sql, $sql_clu);
  if ($bcid ne '') {
    my $tmp_bcid = lc($bcid);
    $sql = "select locus_id from $CGAP_SCHEMA.BioGenes " .
           "where organism = '$org' " .
           "and lower(bc_id) = '$tmp_bcid'";
  } elsif ($ecno ne '') {
    $sql = "select locus_id from $CGAP_SCHEMA.KeggGenes " .
           "where organism = '$org' " .
           "and ecno = '$ecno'";
  }

  my ($loc, $cid, @locs);
  if ($llno ne '') {
    $loc = $llno;
    push @locs, $loc; 
  } else {
    $stm = $db->prepare($sql);
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    } else {
      if ($stm->execute()) {
        $stm->bind_columns(\$loc);
        while($stm->fetch) { 
          push @locs, $loc; 
        };
        $stm->finish;
      } else {
        print "execute failed\n";
        $db->disconnect();
        return "";
      }
    }
  }

  my $total = @locs;
  if ($total == 1) {
    $loc = $locs[0];
    my $cluster_table =
      ($org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster" : "$CGAP_SCHEMA.mm_cluster");
    $sql_clu = 
      "select distinct cluster_number " .
      "from $cluster_table " .
      "where locuslink = $loc";
#return "$sql_clu";
    $stm = $db->prepare($sql_clu);
    if (not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }

    if ($stm->execute()) {
      $stm->bind_columns(\$cid);
      $stm->fetch;
      $stm->finish;
      ## if (! $cid) {
      ##   SetStatus(S_NO_DATA);
      ## }
    } else {
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    $db->disconnect();

    return($cid);
  } 
  elsif ( $total > 1 ) {
    my $base = "";
    my $page = 1;
    my $term = join ",", @locs;
    print "<h3 align=center>Gene List</h3>";
    print GetGeneByNumber_1($base, $page, $org, $term);
    $db->disconnect();
    return "";
  }

}

######################################################################
sub ListBioCartaPathways_1 {
  my ($base) = @_;

  $BASE = $base;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  my ($pathway_page, $pathway_alpha, $gene, @genes);
  my ($path_id, $pathway_name);
  my ($first, $pfirst, $no_h, $no_m, $pnum, $pair);
  my (%paths, %m_paths);

  my $sql_pathway = "select distinct p.path_id, p.pathway_name " .
                    "from $CGAP_SCHEMA.BioPathway_name p " .
                    "order by upper(p.pathway_name)";

  my $stm = $db->prepare($sql_pathway);
  if (not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }

  if (!$stm->execute()) {
     ## print STDERR "$sql_pathway\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
     $db->disconnect();
     return "";
  }

  $stm->bind_columns(\$path_id, \$pathway_name);

  $pathway_page = "<TBODY><TR><TD valign=top align=left>";
  $pathway_alpha = "<THEAD><TR><TD align=center>";
  $first = ""; $pnum = 0;
  while ($stm->fetch) {
    if ($pathway_name) {
      if ($path_id =~ /^h_/) {
        $no_h = substr($path_id,2);
        $paths{$pnum++} = $no_h . '@' . $pathway_name;
      } elsif ($path_id =~ /^m_/) {
        $no_m = substr($path_id,2);
        $m_paths{$no_m} = 1;
      } else {
        print STDERR "New Organism? $path_id\n";
        return "";
      } 
    }
  }

  foreach $pnum (sort numerically keys %paths) {
    ($path_id,$pathway_name) = split '@', $paths{$pnum};
    $pfirst = uc substr($pathway_name,0,1);
    if ($first ne $pfirst) {
      if ($first ne "") {
        $pathway_page .= "</UL>";
      }
      $first = $pfirst;
      if( $first =~ /\W/ ) {
        $first = "&#063;";
      }
      $pathway_alpha .= "<A HREF=\"BioCarta_Pathways#" . $first . "\"><FONT face=Verdana color=#009999 size=2><B>" . $first . "</B></FONT></A> &nbsp;";
      $pathway_page .=
        "&nbsp;&nbsp;&nbsp;&nbsp;\n" .
        "<A NAME=\"" . $first . 
        "\"><FONT face=Verdana color=#009999 size=4><B>" .
        $first . "</B></FONT></A>\n<UL>";
    }

    $pathway_page .= 
    "<LI><A class=genesrch href=\"" . $BASE .
    "/Pathways/BioCarta/h_$path_id\">" . $pathway_name . "</A>\n" .
    "<A href=\"" . $BASE . "/Pathways/BioCarta/h_$path_id\"> " .
    "<IMG SRC=\"" . IMG_DIR . "/BioCarta/buttonH.gif\" border=0 alt=\"Human Pathway\" title=\"Human Pathway\"></A>\n";
    if ($m_paths{$path_id}) {
      $pathway_page .= 
      "<A class=genesrch href=\"" . $BASE .
      "/Pathways/BioCarta/m_$path_id\">" .
      "<IMG SRC=\"" . IMG_DIR . "/BioCarta/buttonM.gif\" border=0 alt=\"Mouse Pathway\" title=\"Mouse Pathway\"></A>\n";
    }
  }
  $stm->finish;
  if (not $first) {
    $pathway_page = "&nbsp;</TD></TR><TR><TD><B>No Pathways Found</B></TD></TR><TR><TD>";
  }
  $pathway_page .=  "</UL></TD></TR></TBODY>\n";
  $pathway_alpha .= "</TD></TR>";
  $pathway_alpha .= "</THEAD>";

  $db->disconnect();

  return $pathway_alpha . $pathway_page;
}

######################################################################
sub GetPathGenes_1 {

  my ($base, $page, $org, $path) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }

  $BASE = $base;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  my (%path_id, %pathway);
  my ($path_id, $path_name);
  my ($sql, $stm);

  $sql = "select distinct path_id, pathway_name " .
         "from $CGAP_SCHEMA.KeggPathNames" ;

  $stm = $db->prepare($sql);

  if (not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  else {

    if (!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       $db->disconnect();
       return "";
    }

    $stm->bind_columns(\$path_id, \$path_name);

    while ($stm->fetch) {
      $path_id{lc $path_name} = $path_id;
      $pathway{$path_id} = 1;
    }
  }

  my $cluster_table =
      ($org eq "Hs") ? "hs_cluster" : "mm_cluster";
  $sql  = "select distinct c.cluster_number from $CGAP_SCHEMA.$cluster_table c";
  if (defined $pathway{$path}) {
    $sql .= ", $CGAP_SCHEMA.keggcomponents kp " .
            "where kp.path_id = '$path' " .
            "and to_char(c.locuslink) = kp.ecno";
  } else { ##if (defined $bc_pathway{$path}) {
    $sql .= ", $CGAP_SCHEMA.biopaths bp, $CGAP_SCHEMA.biogenes bg " .
            " where bp.pathway_name = '$path' " .
            " and c.locuslink = bg.locus_id " .
            " and lower(bp.bc_id) = lower(bg.bc_id)";
            ## " and bp.bc_id = bg.bc_id";
  }
  my ($cid, @cids);
  $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      $stm->bind_columns(\$cid);
      while ($stm->fetch) {
        push @cids, $cid;
      }
      $stm->finish();
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  $db->disconnect();

  my $cmd = "PathGeneQuery?" .
      "ORG=$org&" .
      "PATH=$path";

  my $hs_bld = $BUILDS{'Hs'};  $hs_bld =~ s/^1//;
  my $mm_bld = $BUILDS{'Mm'};  $mm_bld =~ s/^2//;

  my $page_header =
      "<table><tr>" .
      "<td><b>GeneFinder Results For</b>:</td>" .
      "<td>" .
          "$org; " .
          "$path " .
      "</td></tr>" .
      "<tr valign=top><td><b>UniGene Build</b>:</td>" .
      "<td>Hs.$hs_bld/Mm.$mm_bld</td>" .
      "</tr></table>" ;

  if ($page == $CLONE_PAGE) {
    return
      (FormatGenes($page, $org, $cmd, $page_header, \@cids));
  }
  else {
    return
      (FormatGenes($page, $org, $cmd, $page_header,
       OrderGenesBySymbol($page, $org, \@cids)));
  }
}

######################################################################
sub ListKeggPathways_1 {

  my ($base) = @_;

  $BASE = $base;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  my ($pathway_page, $pathway_alpha);
  my ($path_id, $pathway_name);
  my ($first, $pfirst, $pnum);
  my (%paths);

  my $sql_pathway = "select distinct p.path_id, p.pathway_name " .
                    "from $CGAP_SCHEMA.KeggPathNames p " .
                    "order by upper(p.pathway_name)";

  my $stm = $db->prepare($sql_pathway);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }

  if (!$stm->execute()) {
     ## print STDERR "$sql_pathway\n";
     ## print STDERR "$DBI::errstr\n";
     print "execute call failed\n";
     $db->disconnect();
     return "";
  }

  $stm->bind_columns(\$path_id, \$pathway_name);

  $pathway_page = "<TBODY><TR><TD valign=top align=left>";
  $pathway_alpha = "<THEAD><TR><TD align=center>";
  $first = ""; $pnum = 0;
  while ($stm->fetch) {
    if ($pathway_name) {
      $paths{$pnum++} = $path_id . '@' . $pathway_name;
    }
  }

  foreach $pnum (sort numerically keys %paths) {
    ($path_id,$pathway_name) = split '@', $paths{$pnum};
    $pfirst = uc substr($pathway_name,0,1);
    if ($first ne $pfirst) {
      if ($first ne "") {
        $pathway_page .= "</UL>";
      }
      $first = $pfirst;
      $pathway_alpha .= "<A HREF=\"Kegg_Standard_Pathways#" . $first . "\"><FONT face=Verdana color=#009999 size=2><B>" . $first . "</B></FONT></A> &nbsp;";
      $pathway_page .=
        "&nbsp;&nbsp;&nbsp;&nbsp;\n" .
        "<A NAME=\"" . $first . 
        "\"><FONT face=Verdana color=#009999 size=4><B>" .
        $first . "</B></FONT></A>\n<UL>";
    }

    $pathway_page .= 
    "<LI><A class=genesrch href=\"" . $BASE .
    "/Pathways/Kegg/$path_id\">" . $pathway_name . "</A>\n" ;
  }
  $stm->finish;
  if (not $first) {
    $pathway_page = "&nbsp;</TD></TR><TR><TD><B>No Pathways Found</B></TD></TR><TR><TD>";
  }
  $pathway_page .=  "</UL></TD></TR></TBODY>\n";
  $pathway_alpha .= "</TD></TR>";
  $pathway_alpha .= "</THEAD>";

  $db->disconnect();

  return $pathway_alpha . $pathway_page;
}

######################################################################
sub CommonGeneQuery_1 {
  my ($base, $page, $org, $ckbox, $page_header, $genes, $gene_ids, $gene_syms, $order_gene_ids, $order_gene_syms) = @_;

  $BASE = $base;

  my @ckbox = split ",", $ckbox;
  if (@ckbox < 1) {
    ## SetStatus(S_NO_DATA);
    return;
  }
#
# 0=CytLoc  1=Pathway  2=Ontology  3=Tissue  4=Motif  5=SNP
#

  my @genes = split ",", $genes;
  if (@genes < 1) {
    ## SetStatus(S_NO_DATA);
    return;
  }

  my @order_locs = split ",", $order_gene_ids;
  my @order_syms = split ",", $order_gene_syms;
  my @locs = split ",", $gene_ids;
  my @syms = split ",", $gene_syms;

  if( $page == $CLONE_PAGE ) {
    my $cmd = "";
    return (FormatGenes($page, $org, $cmd, $page_header, \@genes));
  } 

  my ($i, $j);
  if ($page == 0) {
    $i = 0;
    $j = $#genes;
  } else {
    $i = ($page - 1) * ITEMS_PER_PAGE;
    $j = $i + ITEMS_PER_PAGE - 1;
    if ($j > $#genes) {
      $j = $#genes;
    }
  }

  my @genes_page = @genes[$i..$j];
  my $genes_page = join ",", @genes_page;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  my ($row, $trow, @rows, @scrollers);
  my ($cid, $g, $genes_list);
  my ($gene, $name, $loc, $cyt, $snp, $path);
  my ($sql, $sql1, $sql2, $sql3, $stm, $fetched, $lastbr, $source);
  my (%motifs, %snps, %tsnps, %tissues, %cid_gene_id_sym2desc);

  my $table_name   = ($org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster"
                                   : "$CGAP_SCHEMA.mm_cluster");
  my $tissue_table = ($org eq "Hs" ? "hs_gene_tissue"
                                   : "mm_gene_tissue");
  my $table_header = 
    "<table border=1 cellspacing=1 cellpadding=4>" .
    "<tr bgcolor=\"#38639d\" height=26>" .
    "<th width=\"5%\" ><font color=\"white\"><b>Symbol</b></font></th>" .
    "<th width=\"20%\"><font color=\"white\"><b>Name</b></font></th>";
  my $headless = 1;
  my $rows = 0;
  my %width = ("Pathway"  => 225,
               "Ontology" => 225,
               "Tissue"   => 85,
               "Motif"    => 85,
               "Snp"      => 130
              );

  if ($ckbox =~ /3/) {
    for ($g = 0; $g < @genes_page; $g += ORACLE_LIST_LIMIT) {
      if (($g + ORACLE_LIST_LIMIT - 1) < @genes_page) {
        $genes_list = join(",", @genes_page[$g..$g+ORACLE_LIST_LIMIT-1]);
      } else {
        $genes_list = join(",", @genes_page[$g..$#genes_page]);
      }
      $sql = "select distinct c.cluster_number, s.tissue_name " .
             "from $CGAP_SCHEMA.tissue_selection s, " .
             "$CGAP_SCHEMA.$tissue_table c " .
             "where s.tissue_code = c.tissue_code " .
             "and c.cluster_number in ($genes_list) " .
             "order by s.tissue_name";
      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      if (!$stm->execute()) {
        print "execute failed\n";
        $db->disconnect();
        return "";
      }

      $stm->bind_columns(\$cid, \$name);
      while ($stm->fetch) {
        $tissues{$cid} .= "$name<br>";
      }
    }
  }
  if ($ckbox =~ /4/) {
    my $ug_sequence =
      ($org eq "Hs") ? "hs_ug_sequence" : "mm_ug_sequence";

    for ($g = 0; $g < @genes_page; $g += ORACLE_LIST_LIMIT) {
      if (($g + ORACLE_LIST_LIMIT - 1) < @genes_page) {
        $genes_list = join(",", @genes_page[$g..$g+ORACLE_LIST_LIMIT-1]);
      } else {
        $genes_list = join(",", @genes_page[$g..$#genes_page]);
      }
      $sql =
        "select /*+ RULE */ distinct s.cluster_number, m.motif_name " .
        "from $CGAP_SCHEMA.motif_info m, " .
        "$CGAP_SCHEMA.$ug_sequence s, " .
        "$CGAP_SCHEMA.mrna2prot t " .
        "where s.accession = t.mrna_accession " .
        "and t.protein_accession = m.protein_accession " .
        "and s.cluster_number in ($genes_list) " .
        "order by m.motif_name";

      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      if (!$stm->execute()) {
        print "execute failed\n";
        $db->disconnect();
        return "";
      }

      $stm->bind_columns(\$cid, \$name);
      while ($stm->fetch) {
        $motifs{$cid} .= "$name<br>";
      }
    }
  }
  if ($ckbox =~ /5/) {
    for ($g = 0; $g < @genes_page; $g += ORACLE_LIST_LIMIT) {
      if (($g + ORACLE_LIST_LIMIT - 1) < @genes_page) {
        $genes_list = join(",", @genes_page[$g..$g+ORACLE_LIST_LIMIT-1]);
      } else {
        $genes_list = join(",", @genes_page[$g..$#genes_page]);
      }
      $sql = "select distinct b.cluster_number, a.new_id, s.cds_change " .
             "from $RFLP_SCHEMA.snpblast\@RFLP s, " .
             ## "$RFLP_SCHEMA.mrna2ug\@RFLP m, " .
             "$CGAP_SCHEMA.mgc_mrna m, " .
             "$RFLP_SCHEMA.snp_list\@RFLP l, " .
             "$RFLP_SCHEMA.snp_alias\@RFLP a, " .
             "$CGAP_SCHEMA.$cluster_table{$org} b " .
             ## "$CGAP_SCHEMA.build_id b " .
             "where m.organism = $org_2_code{$org} " .
             ## "and b.build_id = m.build_id " .
             "and m.accession = s.accession " .
             "and b.LOCUSLINK = m.LOCUSLINK " .
             "and b.cluster_number in ($genes_list) " .
             "and s.snp_id = a.new_id " .
             "and a.old_id = l.snp_id " .
             "and l.status = 'V' " .
             "and s.identity_percent >= 98 " .
             "and s.snp_type = 2 " .
             "order by a.new_id";

      $stm = $db->prepare($sql);
      if (not $stm) {
        ## print "$sql\n";
        ## print "$DBI::errstr\n";
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      }
      if (!$stm->execute()) {
        print "execute failed\n";
        $db->disconnect();
        return "";
      }

      $stm->bind_columns(\$cid, \$snp, \$name);
      while ($stm->fetch) {
        $snps{$cid} .= "<a href=javascript:spawn(\"" . "http://gai.nci.nih.gov/cgi-bin/GeneViewer.cgi?qt=1&query=hs.$cid\")>" . "$snp</a>\011$name<br>";
        $tsnps{$cid} .= "$snp\t$name<br>";
      }
    }
  }

  my $ll_list;
  if (@locs) {
    for (my $l = 0; $l < @locs; $l += ORACLE_LIST_LIMIT) {
      if (($l + ORACLE_LIST_LIMIT - 1) < @locs) {
        $ll_list = join(",", @locs[$l..$l+ORACLE_LIST_LIMIT-1]);
      } else {
        $ll_list = join(",", @locs[$l..$#locs]);
      }
 
      $sql = "select CLUSTER_NUMBER, GENE, DESCRIPTION, LOCUSLINK " .
             " from $CGAP_SCHEMA.GENE_INFO where " .
             " LOCUSLINK in (" .  $ll_list . " ) " .
             "and ORGANISM = '$org'";
 
      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      } else {
        my ($locuslink, $symbol, $title);
        ## my $t0 = [gettimeofday];
        if ($stm->execute()) {
          $stm->bind_columns(\$cid, \$symbol, \$title, \$locuslink);
          while ($stm->fetch) {
            $cid_gene_id_sym2desc{$cid}{$locuslink}{$symbol} = $title; 
          }
          ## my $elapsed = tv_interval ($t0, [gettimeofday]);
          ## print "8888  ll $elapsed\n<br>";
        } else {
          print "execute failed\n";
          $db->disconnect();
          return "";
        }
      }
    }
  }


  my %genes_got_info;
  for (my $a = 0; $a < @syms; $a += ORACLE_LIST_LIMIT) {
    if (($a + ORACLE_LIST_LIMIT - 1) < @syms) {
      $sql = "select CLUSTER_NUMBER, GENE, DESCRIPTION, LOCUSLINK, " .
             "SEQUENCES from $CGAP_SCHEMA.GENE_INFO where " .
             "GENE in (" .
              "'" . join("','", @syms[$a..$a+ORACLE_LIST_LIMIT-1]) . "'" .
             ") and ORGANISM = '$org'";
    } else {
      $sql = "select CLUSTER_NUMBER, GENE, DESCRIPTION, LOCUSLINK " .
             " from $CGAP_SCHEMA.GENE_INFO where " .
             " GENE in (" .
             "'" . join(",", @syms[$a..$#syms]) . "'" .
             ") and ORGANISM = '$org'";
    }
 
    $stm = $db->prepare($sql);
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    } else {
      $stm = $db->prepare($sql);
      if (not $stm) {
        print "<br><b><center>Error in input</b>!</center>";
        $db->disconnect();
        return "";
      } else {
        my ($locuslink, $symbol, $title, $gb);
        ## my $t0 = [gettimeofday];
        if ($stm->execute()) {
          $stm->bind_columns(\$cid, \$symbol, \$title, \$locuslink);
          while ($stm->fetch) {
            $cid_gene_id_sym2desc{$cid}{$locuslink}{$symbol} = $title; 
          }
          ## my $elapsed = tv_interval ($t0, [gettimeofday]);
          ## print "8888  ll $elapsed\n<br>";
        } else {
          print "execute failed\n";
          $db->disconnect();
          return "";
        }
      }
    }
  }


  for(my $i=0; $i<@genes_page; $i++) {
    my $cid  = $genes_page[$i];
    my $loc  = $order_locs[$i];
    my $gene = $order_syms[$i];
    $sql = "select DESCRIPTION, CYTOBAND " .
           "from " . $table_name . " where " .
           "CLUSTER_NUMBER = $cid";

    $stm = $db->prepare($sql);
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
    $stm->bind_columns(\$name, \$cyt);
    $stm->fetch;
    $stm->finish;

    if( defined $cid_gene_id_sym2desc{$cid}{$loc}{$gene} ) {
      $name = $cid_gene_id_sym2desc{$cid}{$loc}{$gene};
    }
    $gene = '-' if ($gene eq '');
    $lastbr = (length $gene <= 8) ? "<br>&nbsp;" : "";
    $rows++;
    $row  = "<tr valign=top height=85>";
    $row .= "<td>$gene<br>&nbsp;<br>&nbsp;<br>&nbsp;$lastbr</td>";
    $row .= "<td>$name<br>&nbsp;<br><a href=GeneInfo?ORG=$org&CID=$cid&LLNO=$loc>Gene Info</a></td>";
    $trow = "$gene\t$name\t$org.$cid\t$loc";

    foreach (@ckbox) {
      $sql = ''; $sql1 = ''; $sql2 = ''; $sql3 = '';
      $fetched = 0;
      my $divid = '';
      SWITCH: {
        /0/ && do {      ## Cyt Loc
          $table_header .=
          "<th width=\"5%\" nowrap><font color=\"white\"><b>Cyt Loc</b></font></th>"
          if ($headless);
          $cyt = ($cyt ? join(',',  split(/\002/, $cyt)) : "Unknown");
          last SWITCH;
        };
   
        /1/ && do {      ## Pathways
          $table_header .=
          "<th width=\"25%\"><font color=\"white\"><b>Pathways</b></font></th>"
          if ($headless);

          ## $sql = "select distinct p.path_id, p.pathway_name " .
          ##        "from $CGAP_SCHEMA.KeggComponents k, " .
          ##        "$CGAP_SCHEMA.KeggPathNames p " .
          ##        "where k.path_id = p.path_id " .
          ##        "and k.ecno = '$loc' " if ($loc ne '');

          ## $sql1 = "select distinct p.path_id, p.pathway_name " .
          ##         "from $CGAP_SCHEMA.KeggComponents kp, " .
          ##         "     $CGAP_SCHEMA.KeggGenes kg, " .
          ##         "     $CGAP_SCHEMA.KeggPathNames p " .
          ##         "where kp.path_id = p.path_id " .
          ##         "and kp.ecno = kg.ecno " .
          ##         "and kg.locus_id = $loc " if ($loc ne '');

          $sql2 = "select distinct pathway_name, pathway_display " .
                  "from $CGAP_SCHEMA.BioPaths " .
                  "where organism = '$org' " .
                  "and BC_ID in ( " .
                     "select distinct bc_id " .
                     "from $CGAP_SCHEMA.BioGenes "  .
                     "where organism = '$org' " .
                     "and locus_id = $loc " .
                  ") " if ($loc ne '');

          $sql3 = "select distinct " .
                  "c.source_name, " .
                  "p.pathway_id, " .
                  ## "p.ext_pathway_id, " .
                  "p.pathway_name, " .
                  "g.ll_id " .
                  ## "g.symbol " .
                  "from " .
                  "pid.pw_pathway_atom pa, " .
                  "pid.pw_edge e, " .
                  "pid.pw_mol_mol mm_outer_family, " .
                  "pid.pw_mol_mol mm_inner_family, " .
                  "pid.pw_mol_mol mm_complex, " .
                  "pid.pw_mol_srch s, " .
                  "pid.pw_pathway p, " .
                  "pid.pw_source c, " .
                  "cgap.ll_gene g " .
                  "where " .
                  "s.map_name = to_char(g.ll_id) " .
                  "and s.mol_id = mm_inner_family.mol_id_2 " .
                  "and mm_outer_family.mol_id_2 = mm_complex.mol_id_2 " .
                  "and mm_complex.mol_id_1 = mm_inner_family.mol_id_1 " .
                  "and e.mol_id = mm_outer_family.mol_id_1 " .
                  "and mm_complex.relation in ('s','c','i') " .
                  "and mm_outer_family.relation in ('s','m','i') " .
                  "and mm_inner_family.relation in ('s','m','i') " .
                  "and e.atom_id = pa.atom_id " .
                  "and pa.pathway_id = p.pathway_id " .
                  "and c.source_id = p.pathway_source_id " .
                  "and c.source_name = 'NATURE' " .
                  "and g.ll_id = '$loc'" if ($loc ne '');
 
          $divid = 'Pathway';
          last SWITCH;
        };
   
        /2/ && do {      ## Ontology
          $table_header .=
          "<th width=\"25%\"><font color=\"white\"><b>Ontology</b></font></th>"
          if ($headless);
          $sql = "select distinct go_name " .
                 "from $CGAP_SCHEMA.Go_Name gn, " .
                 "$CGAP_SCHEMA.ll_go g " .
                 "where gn.go_id = g.go_id " .
                 "and g.ll_id = $loc" if ($loc ne '');
   
          $divid = 'Ontology';
          last SWITCH;
        };
   
        /3/ && do {      ## Tissues
          $table_header .=
           "<th width=\"10%\"><font color=\"white\"><b>Tissues</b></font></th>"
          if ($headless);
          $sql = "";
   
          $divid = 'Tissue';
          last SWITCH;
        };
   
        /4/ && do {      ## Motifs
          $table_header .=
          "<th width=\"10%\"><font color=\"white\"><b>Motifs</b></font></th>"
          if ($headless);
          $sql = "";
   
          $divid = 'Motif';
          last SWITCH;
        };
   
        /5/ && do {      ## SNPs
          $table_header .=
           "<th width=\"15%\"><font color=\"white\"><b>SNP Id/Changes</b></font></th>"
          if ($headless);
          $sql = "";
   
          $divid = 'Snp';
          last SWITCH;
        };
   
        DEFAULT:  print "$_ : No Match\n";
      }
      if ($sql eq '' && $sql2 eq '' && $sql3 eq '') {
        if ($divid eq 'Tissue') {
          if (defined $tissues{$cid}) {
            $row .= "<td>$tissues{$cid}";
            my @tissues = split "<br>", $tissues{$cid};
            $trow .= "\t" . join("|", @tissues);
            $fetched = @tissues;
          } else {
            $row .= "<td>";
            $trow .= "\t";
          }
        } 
        elsif ($divid eq 'Motif') {
          if (defined $motifs{$cid}) {
            $row .= "<td>$motifs{$cid}";
            my @motifs = split "<br>", $motifs{$cid};
            $trow .= "\t" . join("|", @motifs);
            $fetched = @motifs;
          } else {
            $row .= "<td>";
            $trow .= "\t";
          }
        } 
        elsif ($divid eq 'Snp') {
          if (defined $snps{$cid}) {
            $row .= "<td><pre>$snps{$cid}</pre>";
            my @snps = split "<br>", $snps{$cid};
            my @tsnps = split "<br>", $tsnps{$cid};
            $trow .= "\t" . join("|", @tsnps);
            $fetched = @snps;
          } else {
            $row .= "<td>";
            $trow .= "\t";
          }
        } else {
          if ($cyt ne '') {
            $row .= "<td>$cyt";
            $trow .= "\t$cyt";
            $cyt = '';
          } else {
            $row .= "<td>";
            $trow .= "\t";
          }
        }
      } else {
        my @row;
        my @tmp_trow;
        $row .= "<td>";
        if ($sql ne '') {
          $stm = $db->prepare($sql);
          if (not $stm) {
            print "<br><b><center>Error in input</b>!</center>";
            $db->disconnect();
            return "";
          }
          if (!$stm->execute()) {
            print "execute failed\n";
            $db->disconnect();
            return "";
          }

          if ($divid eq 'Pathway') {
            $stm->bind_columns(\$path, \$name);
          } else {
            $stm->bind_columns(\$name);
          }
          $trow .= "\t";
          while ($stm->fetch) {
            $name =~ s/\+/&#043/g;
            if ($sql2 ne '') {     ## doing pathways
              ## push @row, "<a style=\"color:#000000;text-decoration:none\" href=\"$BASE/Pathways/Kegg/$path\">$name \[Kegg\]</a>";
              push @row, "<a href=\"$BASE/Pathways/Kegg/$path\">$name \[Kegg\]</a>";
              push @tmp_trow, $name;
            } else {
              $row .= "$name<br>";
              $trow .= "$name|";
              $fetched++;
            }
          }
        }
        ## if ($sql1 ne '') {
        ##   $stm = $db->prepare($sql1);
        ##   if (not $stm) {
        ##     print STDERR "prepare call failed\n";
        ##     SetStatus(S_RESPONSE_FAIL);
        ##     return "";
        ##   }
        ##   if (!$stm->execute()) {
        ##     print STDERR "execute failed\n";
        ##     SetStatus(S_RESPONSE_FAIL);
        ##     return "";
        ##   }

        ##   $stm->bind_columns(\$path, \$name);
        ##   while ($stm->fetch) {
        ##     $name =~ s/\+/&#043/g;
        ##     push @row, "<a style=\"color:#000000;text-decoration:none\" href=\"$BASE/Pathways/Kegg/$path\">$name</a>";
        ##     push @tmp_trow, $name;
        ##   }
        ## }
        if ($sql2 ne '') {
          $stm = $db->prepare($sql2);
          if (not $stm) {
            print "<br><b><center>Error in input</b>!</center>";
            $db->disconnect();
            return "";
          }
          if (!$stm->execute()) {
            print "execute failed\n";
            $db->disconnect();
            return "";
          }

          $stm->bind_columns(\$path, \$name);
          while ($stm->fetch) {
            $name =~ s/\+/&#043/g;
            ## push @row, "<a style=\"color:#000000;text-decoration:none\" href=\"$BASE/Pathways/BioCarta/$path\">$name \[BioCarta\]</a>";
            push @row, "<a href=\"$BASE/Pathways/BioCarta/$path\">$name \[BioCarta\]</a>";
            push @tmp_trow, $name;
          }
        }
        if ($sql3 ne '') {
          $stm = $db->prepare($sql3);
          if (not $stm) {
            print "<br><b><center>Error in input</b>!</center>";
            $db->disconnect();
            return "";
          }
          if (!$stm->execute()) {
            print "execute failed\n";
            $db->disconnect();
            return "";
          }
 
          $stm->bind_columns(\$source, \$path, \$name, \$loc);
          while ($stm->fetch) {
            $name =~ s/\+/&#043/g;
            ## push @row, "<a style=\"color:#000000;text-decoration:none\" href=javascript:spawn(\"http://pid.nci.nih.gov/search/pathway_landing.shtml?pathway_id=$path&what=graphic&jpg=on&ppage=1&genes_a=$loc\")>$name \[$source\]</a>";
            push @row, "<a href=javascript:spawn(\"http://pid.nci.nih.gov/search/pathway_landing.shtml?pathway_id=$path&what=graphic&jpg=on&ppage=1&genes_a=$loc\")>$name \[$source\]</a>";
            push @tmp_trow, $name;
          }
        }

        if (@row > 0) {
          my @srow = sort @row;
          my @urow;
          for (my $s = 0 ; $s < $#srow ; $s++) {
            if ($srow[$s] !~ $srow[$s+1]) {
              push @urow, $srow[$s];
            } 
          }
          push @urow, $srow[$#srow];
          $row .= join "<br>", @urow;

          my @tmp_tsrow = sort @tmp_trow;
          my @tmp_turow;
          for (my $s = 0 ; $s < $#tmp_tsrow ; $s++) {
            if ($tmp_tsrow[$s] !~ $tmp_tsrow[$s+1]) {
              push @tmp_turow, $tmp_tsrow[$s];
            }
          }
          push @tmp_turow, $tmp_tsrow[$#tmp_tsrow];
          $trow .= join "|", @tmp_turow;
          $fetched = @urow;
        }
      }
      if ($fetched == 0) {
        $row .= "&nbsp;";
      }
      $row .= "</td>";
    }
    $row .= "</tr>";
    if ($page == 0) {
      push @rows, $trow;
    } else {
      push @rows, $row;
    }
    $table_header .= "</tr>" if ($headless);
    $headless = 0;
  }
  $db->disconnect();

  if ($page != 0) {                         ## Shotgun Approach ##
  my ($r, $crow, $td);
  my (@tds, @color, @sect1, @sect2, @sect3, @sect4);
  my @palette = ("","red","green","green","maroon");
  my $c = 1;
  my $rind = 0;
  foreach (@ckbox) {
    next if (/0/ || /5/);
    $color[$c++] = $palette[$_]; 
  }

  my @crows = @rows;
  foreach $crow (@crows) {
    $crow =~ s/^.*?<td>//;
    $crow =~ s/<\/td>(?!<td>).*$//;
    @tds = split "</td><td>", $crow;
    foreach (@tds) {
      s/^<div [^>]*>//;
      s/<B>.*$//;
    }
    $td = ($ckbox =~ /0/) ? 3 : 2;
    @sect1 = split "<br>", $tds[$td++];
    @sect2 = split "<br>", $tds[$td++];
    @sect3 = split "<br>", $tds[$td++];
    @sect4 = split "<br>", $tds[$td];

    for ($r = $rind + 1; $r < @rows; $r++) {
      ## foreach $name (@sect1) {
      ##   next if ($name =~ /&nbsp;/);
      ##   my $cname = $name;
      ##   $cname =~ s/(\[|\(|\)|\+|\])/\\$1/g;
      ##   if ($rows[$r] =~ />$cname<(br|\/td)>/) {
          ## $rows[$r] =~ s/#000000/$color[1]/;
          ## $rows[$rind] =~ s/#000000/$color[1]/;
      ##   }
      ## }
      foreach $name (@sect2) {
        my $cname = $name;
        $cname =~ s/(\[|\(|\)|\+|\])/\\$1/g;
        if ($rows[$r] =~ />$cname<(br|\/td)>/) {
          my $brtd = $1;
          $rows[$r] =~ s/>$cname<$brtd>/><font color=$color[2]>$name<\/font><$brtd>/;
          $rows[$rind] =~ s/>$cname<(br|\/td)>/><font color=$color[2]>$name<\/font><$1>/;
        }
      }
      foreach $name (@sect3) {
        my $cname = $name;
        $cname =~ s/(\[|\(|\)|\+|\])/\\$1/g;
        if ($rows[$r] =~ />$cname<(br|\/td)>/) {
          my $brtd = $1;
          $rows[$r] =~ s/>$cname<$brtd>/><font color=$color[3]>$name<\/font><$brtd>/;
          $rows[$rind] =~ s/>$cname<(br|\/td)>/><font color=$color[3]>$name<\/font><$1>/;
        }
      }
      foreach $name (@sect4) {
        my $cname = $name;
        $cname =~ s/(\[|\(|\)|\+|\])/\\$1/g;
        if ($rows[$r] =~ />$cname<(br|\/td)>/) {
          my $brtd = $1;
          $rows[$r] =~ s/>$cname<$brtd>/><font color=$color[4]>$name<\/font><$brtd>/;
          $rows[$rind] =~ s/>$cname<(br|\/td)>/><font color=$color[4]>$name<\/font><$1>/;
        }
      }
    }
    $rind++;
  }
  }
  if ($page == 0) {
    return (join "\n", @rows) . "\n";
  }

  my $action    = "CommonView";
  my $form_name = "pform";
  my @hidden_names;
  my @hidden_vals;

  $hidden_names[0] = "CKBOX"; $hidden_vals[0] = $ckbox;

  my $i = 2;
  for $cid (@genes) {
    ($hidden_names[$i], $hidden_vals[$i]) = ("CIDS", $cid);
    $i++;
  }

  for (@order_locs) {
    ($hidden_names[$i], $hidden_vals[$i]) = ("ORDER_GENE_IDS", $_);
    $i++;
  }
 
  for (@order_syms) {
    ($hidden_names[$i], $hidden_vals[$i]) = ("ORDER_GENE_SYMS", $_);
    $i++;
  }

  for my $loc (@locs) {
    ($hidden_names[$i], $hidden_vals[$i]) = ("GENE_IDS", $loc);
    $i++;
  }

  for my $sym (@syms) {
    ($hidden_names[$i], $hidden_vals[$i]) = ("GENE_SYMS", $sym);
    $i++;
  }

  return PageCommonGeneList(
      $BASE, $page, $org, $page_header, $table_header,
      $action, $form_name, \@hidden_names, \@hidden_vals,
      \@rows, \@scrollers, \@genes);
}

######################################################################
sub debug_print {
  my @args = @_;
  my $i = 0;
  if(defined($DEBUG_FLAG) && $DEBUG_FLAG) {
    for($i = 0; $i <= $#args; $i++) {
      print " $args[$i]\n";
    }
  }
}

######################################################################
sub Protein_section {

  my ($db, $org, $cid) = @_;
  
  $db->{LongReadLen} = MAX_LONG_LEN;
  my $np2sp_flag = 0;
  my $non_np2sp_flag = 0;
  
  ## get mrna,protein pairs for this Gene id
    
  my $sql = qq!
  select distinct
    l1.ll_id,
    m.mrna_accession,
    m.protein_accession
  from
    $CGAP_SCHEMA.ll2acc l1,
    $CGAP_SCHEMA.ll2acc l2,
    $CGAP_SCHEMA.mrna2prot m,
    $CGAP_SCHEMA.gene2unigene g
  where
        g.cluster_number = $cid
    and g.organism = '$org'
    and l1.ll_id = g.gene_id
    and l2.ll_id = g.gene_id
    and l1.accession = m.mrna_accession
    and l2.accession = m.protein_accession
  !;
  
  my ($ll_id, $mrna, $prot);
  my ($sp);
  my (%prot2mrna, %prot2sp, %sp2ec);
  
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (($ll_id, $mrna, $prot)
          = $stm->fetchrow_array()) {
        $prot2mrna{$prot}{$mrna} = 1;
      }
    } else {
      print "Execute failed\n";
      $db->disconnect();
      return "";
    }
  }
  
  if (! defined %prot2mrna) {
    return "";
  }

  ## get SP ids
  
  my $list = "'" . join("','", keys %prot2mrna) . "'";
  $sql = qq!
    select
      s.other_accession,
      p.sp_primary
    from
      $CGAP_SCHEMA.sp2other s,
      $CGAP_SCHEMA.sp_primary p,
      $CGAP_SCHEMA.sp_info i
    where
           s.other_accession in ($list)
       and p.sp_id_or_secondary = s.sp_accession
       and p.id_or_accession = 'a'
       and i.sp_primary = p.sp_id_or_secondary
       and i.organism = '$org'
  !;
  
  $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (($prot, $sp)
          = $stm->fetchrow_array()) {
        if( $prot =~ /^NP_/ and $sp ne "" ) {
          $np2sp_flag = 1;
        }
        else {
          $non_np2sp_flag = 1;
        }
        $prot2sp{$prot}{$sp} = 1;
      }
    } else {
      print "Execute failed\n";
      $db->disconnect();
      return "";
    }
  }
  
  ## get EC
 
  my $sp_list;
  if ( defined %prot2sp ) {
    my %all_list;
    for $prot (sort keys %prot2sp) { 
      for my $sp (sort keys %{ $prot2sp{$prot} }) { 
        $all_list{$sp} = 1;
      }
    }
    $sp_list = "'" . join("','", keys %all_list) . "'";
    $sql = qq!
      select
        SP_ACCESSION,
        EC_NUMBER
      from
        $CGAP_SCHEMA.sp2ec
    where
        SP_ACCESSION in ($sp_list)
    !;
   
    $stm = $db->prepare($sql);
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    } else {
      if ($stm->execute()) {
        while (my ($sp_acc, $ec_number)
            = $stm->fetchrow_array()) {
          ## print "8888: $sp_acc,$ec_number<br>";
          $sp2ec{$sp_acc}{$ec_number} = 1;
        }
      } else {
        print "Execute failed\n";
        $db->disconnect();
        return "";
      }
    }
  }

  ## get motif info
  
  my (%motif2name, %motif2type, %prot2motif);
  my ($motif_id, $motif_name, $motif_type);
  
  my $list = "'" . join("','", keys %prot2mrna) . "'";
  $sql = qq!
    select distinct
      m.protein_accession,
      m.motif_id,
      m.motif_type,
      m.motif_name
    from
      $CGAP_SCHEMA.motif_info m
    where
          m.protein_accession in ($list)
      and m.score >= 20
  !;
  
  $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (($prot, $motif_id, $motif_type, $motif_name)
          = $stm->fetchrow_array()) {
        $motif2type{$motif_id} = $motif_type;
        $motif2name{$motif_id} = $motif_name;
        $prot2motif{$prot}{$motif_id} = 1;
      }
    } else {
      print "Execute failed\n";
      $db->disconnect();
      return "";
    }
  }
  
  my (@temp, @lines, @np_lines, @other_lines);
  
  for $prot (sort keys %prot2mrna) {
    undef @temp;
    my @mrna_array = map
        { "<a href=\"" . GB_URL($_) . "\" target=_blank>$_</a>" }
        keys %{ $prot2mrna{$prot} };
    my @sp_array = map
        { "<a href=\"" . SP_URL($_) . "\" target=_blank>$_</a>" }
        keys %{ $prot2sp{$prot} };
    my @ec_array;
    for my $sp ( keys %{ $prot2sp{$prot} } ) {
      if( defined $sp2ec{$sp} ) {
        push @ec_array, map
          { "<a href=\"" . EC_URL($_) . "\" target=_blank>EC $_</a>" }
          keys %{ $sp2ec{$sp} };
      } 
    }
    my ($mrnas, $sps, $ec, $motifs);
    if (@mrna_array) {
      $mrnas = join("<br>", @mrna_array);
    } else {
      $mrnas = "\&nbsp;";
    }
    if (@sp_array) {
      $sps = join("<br>", @sp_array);
    } else {
      $sps = "\&nbsp;";
    }
    if (@ec_array) {
      $ec = join("<br>", @ec_array);
    } else {
      $ec = "\&nbsp;";
    }
    if (defined $prot2motif{$prot}) {
      my @motif_array;
      for $motif_id (sort keys %{ $prot2motif{$prot} }) {
        push @motif_array, "<a href=\"" .
            MOTIF_URL($motif_id, $motif2type{$motif_id}) .
            "\" target=_blank>$motif2name{$motif_id}</a>";
      }
      $motifs = join("<br>", @motif_array);
    } else {
      $motifs = "\&nbsp;";
    }
    push @temp, "<tr>";
    push @temp, "<td NOWRAP>";
    push @temp, $mrnas;
    push @temp, "</td>";
    push @temp, "<td NOWRAP>";
    push @temp, "<a href=\"" . GP_URL($prot) . "\" target=_blank>$prot</a>";
    push @temp, "</td>";
    push @temp, "<td NOWRAP>";
    push @temp, $sps;
    push @temp, "</td>";
    if( $prot =~ /^NP_/ and $np2sp_flag == 1 ) {
      if( defined %sp2ec ) {
        push @temp, "<td NOWRAP>";
        push @temp, $ec;
        push @temp, "</td>";
      }
    }
    if ($prot =~ /^NP_/) {
      push @temp, "<td NOWRAP>";
      push @temp, $motifs;
      push @temp, "</td>";
    }
    if( !($prot =~ /^NP_/) and $non_np2sp_flag == 1 ) {
      if( defined %sp2ec ) {
        push @temp, "<td NOWRAP>";
        push @temp, $ec;
        push @temp, "</td>";
      }
    }
    push @temp, "</tr>";
    if ($prot =~ /^NP_/) {
      push @np_lines, @temp;
    } else {
      push @other_lines, @temp;
    }
  }
  
  if (@np_lines) {
    push @lines, "<b>RefSeq</b>";
    push @lines, "<blockquote>";
    push @lines, "<table border=1 width=80%>";
    if( $np2sp_flag == 1 ) {
      if ( defined %sp2ec ) {
        push @lines, "<tr>" .
          "<td width=16%><font color=\"#38639d\"><b>mRNA</b></font></td>" .
          "<td width=16%><font color=\"#38639d\"><b>Protein</b></font></td>" .
          "<td width=16%><font color=\"#38639d\"><b>SwissProt</b></font></td>" .
          "<td width=16%><font color=\"#38639d\"><b>Enzyme</b></font></td>" . 
          "<td width=16%><font color=\"#38639d\"><b>Pfam</b></font></td>" .
          "</tr>";
      }
      else {
        push @lines, "<tr>" .
          "<td width=20%><font color=\"#38639d\"><b>mRNA</b></font></td>" .
          "<td width=20%><font color=\"#38639d\"><b>Protein</b></font></td>" .
          "<td width=20%><font color=\"#38639d\"><b>SwissProt</b></font></td>" .
          "<td width=20%><font color=\"#38639d\"><b>Pfam</b></font></td>" .
          "</tr>";
      }
    }
    else {
      push @lines, "<tr>" .
        "<td width=20%><font color=\"#38639d\"><b>mRNA</b></font></td>" .
        "<td width=20%><font color=\"#38639d\"><b>Protein</b></font></td>" .
        "<td width=20%><font color=\"#38639d\"><b>SwissProt</b></font></td>" .
        "<td width=20%><font color=\"#38639d\"><b>Pfam</b></font></td>" .
        "</tr>";
    }
    push @lines, @np_lines;
    push @lines, "</table>";
    push @lines, "</blockquote>";
  }
  
  if (@other_lines) {
    push @lines, "<p><b>Related Sequences</b><br><br>";
    push @lines, "<table border=0 width=65%>";
    push @lines, "<tr>";
    push @lines, "<td width=5%>&nbsp;</td>";
    push @lines, "<td width=60%>";
    push @lines, "<table border=1 width=100% >";
    if( $non_np2sp_flag == 1 ) {
      if ( defined %sp2ec ) {
        push @lines, "<tr>" .
          "<td width=25%><font color=\"#38639d\"><b>mRNA</b></font></td>" .
          "<td width=25%><font color=\"#38639d\"><b>GenPept</b></font></td>" .
          "<td width=25%><font color=\"#38639d\"><b>SwissProt</b></font></td>" .
          "<td width=25%><font color=\"#38639d\"><b>Enzyme</b></font></td>" . 
                 "</tr>";
      }
      else {
        push @lines, "<tr>" .
          "<td width=33%><font color=\"#38639d\"><b>mRNA</b></font></td>" .
          "<td width=33%><font color=\"#38639d\"><b>GenPept</b></font></td>" .
          "<td width=33%><font color=\"#38639d\"><b>SwissProt</b></font></td>" .
                   "</tr>";
      }
    }
    else {
      push @lines, "<tr>" .
         "<td width=33%><font color=\"#38639d\"><b>mRNA</b></font></td>" .
         "<td width=33%><font color=\"#38639d\"><b>GenPept</b></font></td>" .
         "<td width=33%><font color=\"#38639d\"><b>SwissProt</b></font></td>" .
                 "</tr>";
    }
    push @lines, @other_lines;
    push @lines, "</table>";
    push @lines, "</td>";
    push @lines, "</tr>";
    push @lines, "</table>";
  }
  ## print "<html>\n";
  ## print join("\n", @lines) . "\n";
  return join("\n", @lines) . "\n";

}

######################################################################
sub MOTIF_URL {
  my ($id, $type) = @_;
  if ($type eq "PFAM") {
    return "http://pfam.janelia.org/family/$id";
    ## return "http://pfam.janelia.org/cgi-bin/getdesc?acc=$id";
  } else {
    return "";
  }
}

######################################################################
sub SP_URL {
  my ($acc) = @_;
  return "http://www.uniprot.org/uniprot/$acc";
  ## return "http://us.expasy.org/cgi-bin/niceprot.pl?$acc";
}

######################################################################
sub GB_URL {
  my ($acc) = @_;
  return "http://www.ncbi.nih.gov/entrez/query.fcgi?db=nucleotide" .
      "&cmd=search&term=$acc";
}

######################################################################
sub EC_URL {
  my ($ec) = @_;
  return "http://us.expasy.org/cgi-bin/nicezyme.pl?$ec";
}


######################################################################
sub GP_URL {
  my ($acc) = @_;
  return "http://www.ncbi.nih.gov/entrez/query.fcgi?db=protein" .
      "&cmd=search&term=$acc";
}

######################################################################
sub convrtSingleToDoubleQuote {
  my ($temp) = @_;
 
  $temp =~ s/'/''/g;
 
  return $temp
}

######################################################################

1;
