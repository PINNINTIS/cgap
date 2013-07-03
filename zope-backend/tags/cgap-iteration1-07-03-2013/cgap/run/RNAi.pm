#!/usr/local/bin/perl

######################################################################
# RNAi.pm
#
######################################################################

use strict;
use FileHandle;
use CGAPConfig;
use Paging;
use ServerSupport;
use DBI;
use GD;
use Cache;

require LWP::UserAgent;

use constant ORACLE_LIST_LIMIT => 500;

## my $CGAP_SCHEMA = "cgap2";
my $CLONE_PAGE = 1000000;
my $BASE;
my $DEBUG_FLAG;
my %BUILDS;
GetBuildIDs(\%BUILDS);

my $LAST_UPDATE = "(07/16/09)";


my $cache = new Cache(CACHE_ROOT, RNAi_CACHE_PREFIX);

## my $IMAGE_HEIGHT        = 450;
## my $IMAGE_WIDTH         = 600;
## my $IMAGE_MARGIN        = 5;
## my $VERT_MARGIN         = 50;
## my $HORZ_MARGIN         = 75;
my $IMAGE_HEIGHT        = 900;
my $IMAGE_WIDTH         = 600;
my $IMAGE_MARGIN        = 5;
my $VERT_MARGIN         = 10;
my $HORZ_MARGIN         = 70;
my %COLORS;


my (%orf_from, %orf_to, %nt, %oligo, @oligo);
my (%motif_family, %motif_from, %motif_to, %motif_evalue, %motif_pos);

######################################################################
sub numerically   { $a <=> $b; }
sub r_numerically { $b <=> $a; }


######################################################################
sub GetStatusTable_1 {
  my ($base) = @_;

  my ($sql, $stm);
  my ($oligos, $accs, $others, $org);
  my (%oligos, %accs, %others, %avg);
  my (@lines, $shared);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print STDERR "Cannot connect to database \n";
    return "";
  }

  # shRNA clones (total)
  ## $sql = 
  ##   "select count(oligo_id), organism " .
  ##   "from $CGAP_SCHEMA.rnai_oligo " .
  ##   "group by organism" ;
  $sql = 
    "select count(unique OLIGO_SEQ), organism " .
    "from $CGAP_SCHEMA.rnai_oligo " .
    "group by organism" ;

  $stm = $db->prepare($sql);
  if (! $stm) {
    ## print STDERR "$sql\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if (! $stm->execute()) {
    ## print STDERR "$sql\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  $stm->bind_columns(\$oligos, \$org);

  while($stm->fetch) {
    $oligos{$org} = $oligos;
  }

  # UniGene Targets
  $sql = 
    "select count(distinct accession), organism " .
    "from $CGAP_SCHEMA.rnai2ug " .
    "group by organism" ;

  $stm = $db->prepare($sql);
  if (! $stm) {
    ## print STDERR "$sql\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if (! $stm->execute()) {
    ## print STDERR "$sql\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  $stm->bind_columns(\$accs, \$org);

  while($stm->fetch) {
    $accs{$org} = $accs;
  }

  # Other Targets
  $sql = 
    "select count(distinct r.accession), r.organism " .
    "from $CGAP_SCHEMA.rnai_oligo r " .
    "where r.accession not like 'NG_%' " .
    "and not exists " .
    "  (select u.oligo_id " .
    "   from $CGAP_SCHEMA.rnai2ug u " .
    "   where u.oligo_id = r.oligo_id and u.organism = r.organism) " .
    "group by organism " ;

  $stm = $db->prepare($sql);
  if (! $stm) {
    ## print STDERR "$sql\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if (! $stm->execute()) {
    ## print STDERR "$sql\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  $stm->bind_columns(\$others, \$org);

  while($stm->fetch) {
    $others{$org} = $others;
  }
  if ( (not defined $others) or ($others eq "") ) {
    $org = "Hs";
    $others{$org} =  0;
    $org = "Mm";
    $others{$org} =  0;
  }

  # Shared Targets
  $sql = 
    "select count(distinct o1.oligo_id) " .
    "from $CGAP_SCHEMA.rnai_oligo o1, $CGAP_SCHEMA.rnai_oligo o2 " .
    "where o1.organism = 'Hs' " .
    "and o2.organism = 'Mm' " .
    "and o1.oligo_id = o2.oligo_id " ;

  $stm = $db->prepare($sql);
  if (! $stm) {
    ## print STDERR "$sql\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if (! $stm->execute()) {
    ## print STDERR "$sql\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  $stm->bind_columns(\$shared);
  $stm->fetch;
  $stm->finish;

  $db->disconnect();

  # Average number shRNA clones/target
  $avg{Hs} = sprintf "%.1f", $oligos{Hs} / ($accs{Hs} + $others{Hs});
  $avg{Mm} = sprintf "%.1f", $oligos{Mm} / ($accs{Mm} + $others{Mm});

  push @lines, "<center>";
  push @lines, "<table border=1 cellspacing=0 cellpadding=1>";
  push @lines, "<tr BGcolor=38639d>";
  push @lines, "<td align=center width=170>&nbsp;</td>";
  push @lines, "<td align=center width=100><font color=ffffff><b>Human<br>Last Updated<br>$LAST_UPDATE</b></font></td>";
  push @lines, "<td align=center width=100><font color=ffffff><b>Mouse<br>Last Updated<br>$LAST_UPDATE</b></font></td>";
  push @lines, "</tr>";

  push @lines, "<tr>";
  push @lines, "<td align=left><font color=ff0000>shRNA clones (total) </font></td>";
  push @lines, "<td align=center>$oligos{Hs}<!--font color=red><b>**</b></font--></td>";
  push @lines, "<td align=center>$oligos{Mm}<!--font color=red><b>**</b></font--></td>";
  push @lines, "</tr>";

  push @lines, "<tr>";
  push @lines, "<td align=left><font color=ff0000>UniGene targets </font></td>";
  push @lines, "<td align=center>$accs{Hs}</td>";
  push @lines, "<td align=center>$accs{Mm}</td>";
  push @lines, "</tr>";

  push @lines, "<tr>";
  push @lines, "<td align=left><font color=ff0000>Other targets</font></td>";
  push @lines, "<td align=center><a href=\"OtherTargets?ORG=Hs\">$others{Hs}</a></td>";
  push @lines, "<td align=center><a href=\"OtherTargets?ORG=Mm\">$others{Mm}</a></td>";
  push @lines, "</tr>";

  push @lines, "<tr>";
  push @lines, "<td align=left><font color=ff0000>Average number shRNA clones/target</font></td>";
  push @lines, "<td align=center>$avg{Hs}</td>";

  push @lines, "<td align=center>$avg{Mm}</td>";
  push @lines, "</tr>";
  push @lines, "</table>";
# push @lines, "<P><font color=red><b>**</b></font> $shared of the oligos target both human and mouse.";
  push @lines, "</center>";

  return join("\n", @lines) . "\n";
}

######################################################################
sub GetOtherTargets_1 {
  my ($base, $org) = @_;

  my ($sql, $stm);
  my $NCOLS = 5;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print STDERR "Cannot connect to database \n";
    return "";
  }

  my $org_o;
  if( $org eq "Hs" ) {
    $org_o = "Mm"; 
  } 
  else {
    $org_o = "Hs"; 
  }
  my $ug_sequence =
    ($org_o eq "Hs") ? "hs_ug_sequence" : "mm_ug_sequence"; 
  $sql = qq!
select distinct
  r.accession
from
  $CGAP_SCHEMA.rnai_oligo r
where
     r.accession not like 'NG_%'
  and r.organism = '$org'
  and not exists
    (select u.oligo_id
    from $CGAP_SCHEMA.rnai2ug u
    where u.oligo_id = r.oligo_id)
  and not exists
    (select c.CLUSTER_NUMBER
    from $CGAP_SCHEMA.$ug_sequence c
    where c.accession  = r.accession)
order by
  r.accession
  !;
  $stm = $db->prepare($sql);
  if (! $stm) {
    ## print STDERR "$sql\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if (! $stm->execute()) {
    ## print STDERR "$sql\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  my $aref = $stm->fetchall_arrayref();
  $db->disconnect();
  my ($n, @lines, $acc);
  for my $a (@{ $aref }) {
    if ($n % $NCOLS == 0) {
      if ($n != 0) {
        push @lines, "</tr><tr>";
      } else {
        push @lines, "<tr>";
      }
    }
    push @lines, "<td>$$a[0]</td>";
    $n++;
  } 
  if ($n > 0) {
    while ($n % $NCOLS != 0) {
      push @lines, "<td>\&nbsp;</td>";
      $n++
    };
    push @lines, "</tr>";
  }
  if (@lines) {
    unshift @lines, "<table border=1 cellspacing=1 cellpadding=5>";
    push @lines, "</table>";
  } else {
    push @lines, "No data found";
    push @lines, "$sql";
  }
  unshift @lines, "<p><center>";
  push @lines, "</center>";
  return join("\n", @lines) . "\n";
}

######################################################################
sub GetRNAiGene_1 {
  my ($base, $page, $org, $sym, $key, $acc, $ugid) = @_;

  $BASE = $base;

  my $build_id = $BUILDS{$org};

  my $hs_bld = $BUILDS{'Hs'};  $hs_bld =~ s/^1//;
  my $mm_bld = $BUILDS{'Mm'};  $mm_bld =~ s/^2//;

  my $cmd = "" . $BASE . 
            "/RNAi/RNAiGeneQuery?ORG=$org&SYM=$sym&KEY=$key&ACC=$acc&UGID=$ugid";

  my $page_header; 
  my $term;
  if ($sym) {
    $term = $sym;
  } elsif ($key) {
    $term = $key;
  } elsif ($acc) {
    return "<H6 style='color:#ff0000'>Not Yet Implemented.</H6>";
    $term = $acc;
  } elsif ($ugid) {
    $term = $ugid;
  }

  if (! $term) {
    return "<H6 style='color:#ff0000'>Please enter a Search Term</H6>";
  }

  $page_header = "<table><tr>" . 
    "<td><b>RNAi Gene Query Results For</b>:</td>" .
    "<td>$org; $term</td></tr>" .
    "<tr><td><b>UniGene Build</b>:</td>" .
    "<td>Hs.$hs_bld/Mm.$mm_bld</td></tr></table>";

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print STDERR "Cannot connect to database \n";
    return "";
  }

  my ($cid, @cids);
  my (@row, @rows);
  my (@terms, @nums, @syms, @clus, @keys, @temp);
  my ($sql, $stm, $ky);


  if (! $key) {
    $term =~ s/ //g;
    $term =~ tr/a-z/A-Z/;
    $term =~ tr/\*/%/;
    $term =~ s/%{2,}/%/g;
  }

  for $term (split (",", $term)) {
    if ($ugid) {
      $term =~ s/^(HS\.|MM\.)//;
      push @clus, $term;
    } elsif ($acc) {
      push @nums, $term;
    } elsif ($key) {
        push @keys, "$term";
    } elsif ($sym) {
        push @syms, "'$term'";
    }
  }

  my $cluster_table = 
     ($org eq "Hs") ? "$CGAP_SCHEMA.hs_cluster"
                    : "$CGAP_SCHEMA.mm_cluster";
  if (@clus) {
    $sql = 
        "select distinct r.cluster_number " .
        "from $CGAP_SCHEMA.rnai2ug r, " .
        "     $cluster_table c " .
        "where r.cluster_number in (" . join(", ", @clus) . ") " .
        "and r.organism = '$org' " .
        "and r.cluster_number = c.cluster_number " ;
    $stm = $db->prepare($sql);
    if (! $stm) {
      ## print STDERR "$sql\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if ($stm->execute()) {
      while (($cid) = $stm->fetchrow_array()) {
        push @cids, $cid;
      }
    } else {
      ## print STDERR "$sql\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
  }

  if (@nums) {
    $sql = 
        "select distinct r.cluster_number " .
        "from $CGAP_SCHEMA.rnai2ug r, " .
        "     $cluster_table c " .
        "where r.organism = '$org' " .
        "and r.cluster_number = c.cluster_number " .
        "and c.locuslink in (" . join(", ", @nums) . ") " ;
    $stm = $db->prepare($sql);
    if (! $stm) {
      ## print STDERR "$sql\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if ($stm->execute()) {
      while (($cid) = $stm->fetchrow_array()) {
        push @cids, $cid;
      }
    } else {
      ## print STDERR "$sql\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
  }

  if (@syms) {
    my $ug_sequence =
      ($org eq "Hs") ? "$CGAP_SCHEMA.hs_ug_sequence"
                     : "$CGAP_SCHEMA.mm_ug_sequence";

    $sql = 
      "select distinct r.cluster_number " .
      "from $CGAP_SCHEMA.rnai2ug r, " .
      "     $ug_sequence c " .
      "where r.organism = '$org' " .
      "and r.cluster_number = c.cluster_number " .
      "and c.accession in (" . join(", ", @syms) . ") " ;
    $stm = $db->prepare($sql);
    if (! $stm) {
      ## print STDERR "$sql\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if ($stm->execute()) {
      while (($cid) = $stm->fetchrow_array()) {
        push @cids, $cid;
      }
    } else {
      ## print STDERR "$sql\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }

    my $alias_table = $org eq "Hs" ? "$CGAP_SCHEMA.hs_gene_alias" 
                                   : "$CGAP_SCHEMA.mm_gene_alias";
    $sql = 
      "select distinct r.cluster_number " .
      "from $CGAP_SCHEMA.rnai2ug r, " .
      "     $alias_table c " .
      "where r.organism = '$org' " .
      "and r.cluster_number = c.cluster_number " .
      "and (c.gene_uc like " . 
         join(" or c.gene_uc like ", @syms) . ") " ;
    $stm = $db->prepare($sql);
    if (! $stm) {
      ## print STDERR "$sql\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if ($stm->execute()) {
      while (($cid) = $stm->fetchrow_array()) {
        push @cids, $cid;
      }
    } else {
      ## print STDERR "$sql\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
  }

  if (@keys) {
    my $keyword_table =
       ($org eq "Hs") ? "$CGAP_SCHEMA.hs_gene_keyword"
                      : "$CGAP_SCHEMA.mm_gene_keyword";

    foreach $ky (@keys) {
      $ky =~ tr/A-Z/a-z/;
      $ky =~ s/\*/%/g;
      $ky =~ s/ +/ /g;
      $ky =~ s/^ //;
      $ky =~ s/ $//;
      for my $i (split " ", $ky) {
        push @temp, "k.keyword like '$i'";
      }
    }

    $sql = 
      "select distinct r.cluster_number " .
      "from $CGAP_SCHEMA.rnai2ug r, " .
      "     $cluster_table c, " .
      "     $keyword_table k " .
      "where r.organism = '$org' " .
      "and r.cluster_number = c.cluster_number " .
      "and r.cluster_number = k.cluster_number " .
      "and (" . join(" or ", @temp) . ")";

    $stm = $db->prepare($sql);
    if (! $stm) {
      ## print STDERR "$sql\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if ($stm->execute()) {
      while (($cid) = $stm->fetchrow_array()) {
        push @cids, $cid;
      }
    } else {
      ## print STDERR "$sql\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
  }

  if ($page == $CLONE_PAGE) {
    return(FormatGenes($page, $org, $cmd, $page_header, \@cids)) ;
  }
  else {
    return(FormatGenes($page, $org, $cmd, $page_header,
               OrderGenesBySymbol($page, $org, \@cids)));
  }
}

######################################################################
sub GetRNAiCloneList_1 {

  my ($base, $page, $org) = @_;
  my (@cids, $cid);
    
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
      ##print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
      print STDERR "Cannot connect to database \n";
      return "";
  }
    
  my $sql =
     "select distinct cluster_number " .
     "from $CGAP_SCHEMA.rnai2ug " .
     "where organism = '$org' " ;
 
  my $stm = $db->prepare($sql);
 
  if (not $stm) {
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
 
  $stm->bind_columns(\$cid);

  while($stm->fetch) {
    push @cids, $cid;
  }

  return(FormatGenes($page, $org, '', '',
             OrderGenesBySymbol($page, $org, \@cids)));
}

######################################################################
sub GetRNAiOtherCloneList_1 {

  my ($base, $page, $org) = @_;
  my ($oligo_id, $oligo_seq, $oligo_acc);
  my (@others);
    
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
      ##print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
      print STDERR "Cannot connect to database \n";
      return "";
  }
    
  my $sql = 
    "select distinct r.oligo_id, r.oligo_seq, r.accession " .
    "from $CGAP_SCHEMA.rnai_oligo r " .
    "where r.accession not like 'NG_%' " .
    "and r.organism = '$org' " .
    "and not exists " .
    "  (select u.oligo_id " .
    "   from $CGAP_SCHEMA.rnai2ug u " .
    "   where u.oligo_id = r.oligo_id) " ;

  my $stm = $db->prepare($sql);
  if (! $stm) {
    ## print STDERR "$sql\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if (! $stm->execute()) {
    ## print STDERR "$sql\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  $stm->bind_columns(\$oligo_id, \$oligo_seq, \$oligo_acc);

  while($stm->fetch) {
    push @others, "$oligo_id\t$oligo_seq\t$oligo_acc\n"
  }

  return(FormatGenes($page, $org, 'OTHERS', '', \@others)) ;
}

######################################################################
sub RNAiViewer_1 {

  my ($base, $org, $acc, $sym) = @_;

  my $ORG = $org;
  $org = ($org eq 'Hs') ? 1 : 2;

  my ($orf_start, $orf_end, $nt);
  my ($oligo_id, $oligo_pos);
  my ($pf_id, $family_name, $seq_from, $seq_to, $e_value, $pf, $pf2, $overlap);
  my ($im, $image_cache_id, $imagemap_cache_id);
  my (@image_map);
    
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
      ##print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
      print STDERR "Cannot connect to database \n";
      return "";
  }
   
  my $sql =
     "select cds_from, cds_to, accession_length " .
     "from $CGAP_SCHEMA.mrna_cds " .
     "where mrna_accession = '$acc' " ;

  my $stm = $db->prepare($sql);
 
  if (not $stm) {
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
 
  $stm->bind_columns(\$orf_start, \$orf_end, \$nt);

  while($stm->fetch) {
    $orf_from{$acc} = $orf_start;
    $orf_to{$acc}   = $orf_end;
    $nt{$acc}       = $nt;
  }

  my $sql =
     "select oligo_id, oligo_pos " .
     "from $CGAP_SCHEMA.rnai_oligo " .
     "where accession = '$acc' and ORGANISM = '$ORG' " .
     "and oligo_pos is not null " .
     "order by oligo_pos " ;

  my $stm = $db->prepare($sql);
 
  if (not $stm) {
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
 
  $stm->bind_columns(\$oligo_id, \$oligo_pos);

  my %unique_oligo;
  while($stm->fetch) {
    $oligo{$oligo_id} = $oligo_pos;
    if( not defined $unique_oligo{$oligo_id} ) {
      push @oligo, $oligo_id;
      $unique_oligo{$oligo_id} = 1;
    }
  }

  my $sql =
     "select i.motif_id, i.motif_name, i.seq_from, i.seq_to, i.e_value " .
     "from $CGAP_SCHEMA.motif_info i, $CGAP_SCHEMA.mrna2prot p " .
     "where p.mrna_accession = '$acc' " .
     "and p.protein_accession = i.protein_accession " .
     "order by to_number(i.e_value), i.seq_from " ;

  my $stm = $db->prepare($sql);
 
  if (not $stm) {
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
 
  $stm->bind_columns(\$pf_id, \$family_name, \$seq_from, \$seq_to, \$e_value);

  while($stm->fetch) {
    $overlap = 0;
    for $pf (keys %motif_from) {
      for $pf2 (keys %{ $motif_from{$pf} }) {
      if (($seq_from <= $motif_from{$pf}{$pf2} && $seq_to >= $motif_from{$pf}{$pf2})
      ||  ($seq_from >= $motif_from{$pf}{$pf2} && $seq_to <= $motif_to{$pf}{$pf2})
      ||  ($seq_from <= $motif_to{$pf}{$pf2}   && $seq_to >= $motif_to{$pf}{$pf2})
      ||  ($seq_from <= $motif_from{$pf}{$pf2} && $seq_to >= $motif_to{$pf}{$pf2})) {
        $overlap = 1;
        if ($e_value < $motif_evalue{$pf}{$pf2}) {
          undef $motif_from{$pf}{$pf2};
          undef $motif_to{$pf}{$pf2};
          undef $motif_family{$pf};
          undef $motif_evalue{$pf}{$pf2};
          undef $motif_pos{$pf2};
        }
      }
      }
    }
    if (! $overlap) {
      $motif_family{$pf_id} = $family_name;
      $motif_from{$pf_id}{$seq_from} = $seq_from;
      $motif_to{$pf_id}{$seq_from} = $seq_to;
      $motif_evalue{$pf_id}{$seq_from} = $e_value;
      $motif_pos{$seq_from} = $pf_id;
    }
  }

  $db->disconnect();

  my $test = "<TABLE><TR>";
  for $acc (keys %orf_from) {
    $test .= "<TD>Accession $acc from $orf_from{$acc} to $orf_to{$acc} NT $nt{$acc}</TD>";
  }
  $test .= "</TR><TR>";
  for $oligo_id (keys %oligo) {
    $test .= "<TD>Oligo $oligo_id from $oligo{$oligo_id}</TD>";
  }
  $test .= "</TR><TR>";
  for $pf_id (keys %motif_from) {
    $test .= "<TD COLSPAN=5>Motif $pf_id $motif_family{$pf_id} from $motif_from{$pf_id} to $motif_to{$pf_id} $motif_evalue{$pf_id}</TD>";
  }
  $test .= "</TR><TR>";
  for my $pf_pos (sort numerically keys %motif_pos) {
    $pf_id = $motif_pos{$pf_pos};
    $test .= "<TD>Pos $pf_pos Motif $pf_id</TD>";
  }
  $test .= "</TR></TABLE>";

# return "$test";

  $im = InitializeImage();

  push @image_map, "<map name=\"rnaimap\">";

  DrawGrid($im, $acc, $sym, \@image_map);

  push @image_map, "</map>";

  if (GD->require_version() > 1.19) {
    $image_cache_id = WriteRNAiToCache($im->png);
  } else {
    $image_cache_id = WriteRNAiToCache($im->gif);
  }

  if (! $image_cache_id) {
    return "Cache failed";
  }

  my @lines;
  push @lines,
  "<TABLE><TR><TD style='color:#000000;font-weight:normal;'>";
  push @lines,
  "<b>Gene Symbol:</b> &nbsp; $sym";
  push @lines,
  "</TD></TR><TR><TD style='color:#000000;font-weight:normal;'>";
  push @lines,
  "<b>Accession:</b> &nbsp; <A href=javascript:spawn(" .
              "\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?" .
              "db=Nucleotide&" .
              "CMD=Search&term=$acc\") >$acc</A>";
  push @lines,
  "</TD></TR><TR><TD style='color:#000000;font-weight:normal;'>";
  push @lines,
  "<b>Transcript Length:</b> &nbsp; $nt{$acc} nt";
  push @lines,
  "</TD></TR><TR><TD style='color:#000000;font-weight:normal;'>";
  push @lines,
  "<b>CDS:</b> &nbsp; nt $orf_from{$acc} - $orf_to{$acc}";
  push @lines,
  "</TD></TR></TABLE>";

  push @lines,
      "<image src=\"RNAiImage?CACHE=$image_cache_id\" " .
      "alt=\"RNAi_Image\" border=0 " .
      "usemap=\"#rnaimap\">";
  push @lines, @image_map;

  push @lines,
  "<BLOCKQUOTE style='font-size:9pt'>";
  push @lines,
  "Above is a representation of the complete gene transcript showing the relative";
  push @lines,
  "position of each shRNA.  The numbers above the transcript are the oligo IDs,";
  push @lines,
  "and the numbers below the transcript indicate the nucleotide position of each";
  push @lines,
  "shRNA start.";
  push @lines,
  "</BLOCKQUOTE>";
  push @lines,
  "<BLOCKQUOTE style='font-size:9pt'>";
  push @lines,
  "The protein domains are predicted by CGAP using the public Pfam motif database ";
  push @lines,
  "and the HMMR software.  Since CGAP performs this process twice a year, the ";
  push @lines,
  "motifs may be based on a version of Pfam that is one or two versions behind ";
  push @lines,
  "the most current version.";
  push @lines,
  "</BLOCKQUOTE>";
  return
      join("\n", @lines);
}

######################################################################
sub WriteRNAiToCache {
  my ($data) = @_;

  my ($rnai_cache_id, $filename) = $cache->MakeCacheFile();
  if ($rnai_cache_id != $CACHE_FAIL) {
    if (open(ROUT, ">$filename")) {
      print ROUT $data;
      close ROUT;
      chmod 0666, $filename;
    } else {
      $rnai_cache_id = 0;
    }
  }
  return $rnai_cache_id;
}

######################################################################
sub FormatGenes {
  my ($page, $org, $cmd, $page_header, $items_ref) = @_;

  if ( $page == $CLONE_PAGE ) {
    my $temp = "";
    return GetClones_1( $org, $items_ref, 1, "" ); 
  } 

  if ($page < 1) {
    my $i;
    my @s;
    if ($cmd eq "OTHERS") {
      for ($i = 0; $i < scalar(@{ $items_ref }); $i++) {
        $s[$i] = FormatOneOther("TEXT", $org, $$items_ref[$i]) . "\n";
      }
    } else {
      for ($i = 0; $i < scalar(@{ $items_ref }); $i++) {
        $s[$i] = FormatOneGene("TEXT", $org, $$items_ref[$i]) . "\n";
      }
    }
    return (join "", @s);
  }

  my $table_header = "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr bgcolor=\"#38639d\">".
      "<td width=\"10%\"><font color=\"white\"><b>Symbol</b></font></td>".
      "<td width=\"15%\"><font color=\"white\"><b>Oligo ID</b></font></td>" .
      "<td width=\"15%\"><font color=\"white\"><b>Sequence</b></font></td>" .
      "<td width=\"15%\"><font color=\"white\"><b>RNAi View</b></font></td>" .
      "<td width=\"35%\"><font color=\"white\"><b>Description</b></font></td>" .
      "<td><font color=\"white\"><b>CGAP</b></font></td>" .
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

  my ($cid);
  for (@{ $items_ref }) {
    ($cid) = split /\001/;
    ($hidden_names[$i], $hidden_vals[$i]) = ("CIDS", $cid);
    $i++;
  }

  return PageGeneList(
      $BASE, $page, $org, $page_header, $table_header,
      $action, $form_name, \@hidden_names, \@hidden_vals,
      $formatter_ref, $items_ref);
}

######################################################################
sub FormatOneGene {
  my ($what, $org, $cids) = @_;
  my ($cid, $symbol, $oligo, $seq, $acc, $title)
       = split(/\001/, $cids);

  $symbol or $symbol = '-';
  $oligo or $oligo = '-';
  $seq or $seq = '-';
  $acc or $acc = '-';
  $title or $title = '-';

  my ($s, $acc_link);
  if ($what eq 'HTML') {
    if ($acc ne '-') {
      if ($acc =~ /V$/) {
        $acc =~ s/V$//;
        $acc_link = $acc;
        $acc_link = 
          "<a href=\"" . $BASE .
          "/RNAi/RNAiViewer?ORG=$org&ACC=$acc&SYM=$symbol\">$acc</a>" ;
      } else {
        $acc_link = $acc;
      }
    } else {
      $acc_link = $acc;
    }

    $s = "<tr valign=top>" .
         "<td>" . $symbol . "</td>" .
         "<td style='font-size:9pt;font-family:courier new;'>" . $oligo . "</td>" .
         "<td style='font-size:9pt;font-family:courier new;'>" . $seq   . "</td>" .
         "<td>" . $acc_link . "</td>" .
         "<td>" . $title . "</td>" .
         "<td><a href=\"" . $BASE .
         "/Genes/GeneInfo?ORG=$org&CID=$cid\">Gene Info</a></td>" .
         "</tr>" ;

  } else {                                      ## $what == TEXT
    $s = "$symbol\t$oligo\t$seq\t$acc\t$title\t$org.$cid";
  }
  return $s;
}

######################################################################
sub FormatOneOther {
  my ($what, $org, $others) = @_;
  my ($oligo, $seq, $acc) = split(/\t/, $others);

  chomp $acc;
  $oligo or $oligo = '-';
  $seq or $seq = '-';
  $acc or $acc = '-';

  my $s = "$oligo\t$seq\t$acc";

  return $s;
}

######################################################################
sub OrderGenesBySymbol {

  my ($page, $org, $refer) = @_;

  my %hs_cid2sym;
  my %mm_cid2sym;
  my @ordered_genes;
  my @ordered_results;
  my @tempArray;
  my $sql_lines;
  my %by_symbol;
  my %viewlink;
  my ($sql, $stm);
  my ($key, $list, $cid, $gene);
  my ($all_oligo, $all_seq, $last_gene, $vacc);
  my ($i, $k, $m);
  my $temp;
  my $j=0;
  my $count=0;

  my $total = @{$refer};

  my ($cluster_number, $symbol, $oligo, $seq, $acc, $title);

  if ( @{ $refer } ) {

    my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
    if (not $db or $db->err()) {
      ##print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
      print STDERR "Cannot connect to database \n";
      return "";
    }

    if ( $page == 0 ) {

      for($i = 0; $i < @{$refer}; $i += ORACLE_LIST_LIMIT) {

        if (($i + ORACLE_LIST_LIMIT - 1) < @{$refer}) {
          $list = join(",", @{$refer}[$i..$i+ORACLE_LIST_LIMIT-1]);
        }
        else {
          $list = join(",", @{$refer}[$i..@{$refer}-1]);
        }

        my $table_name = ($org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster"
                                       : "$CGAP_SCHEMA.mm_cluster");

        $sql = "select r.cluster_number, c.gene, c.description, " .
               "       o.oligo_id, o.oligo_seq, o.accession " .
               "from $CGAP_SCHEMA.rnai2ug r, " .
               "     $CGAP_SCHEMA.rnai_oligo o, " .
               "     $table_name c " .
               "where r.organism = '$org' " .
               "and r.cluster_number in (" .  $list . " ) " .
               "and r.cluster_number = c.cluster_number " .
               "and r.oligo_id = o.oligo_id " ;

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
            return undef;
          }

          $stm->bind_columns(\$cluster_number, \$symbol, \$title, \$oligo, \$seq, \$acc);

          my %unique;
          while($stm->fetch) {
 
            if( defined $unique{$cluster_number}{$gene}{$title}{$oligo}{$seq}{$acc} ) {
              next;
            }
            else {
              $unique{$cluster_number}{$gene}{$title}{$oligo}{$seq}{$acc} = 1;
            }

            $temp =  "$cluster_number\001$symbol\001$oligo\001$seq\001$acc\001$title";

            if ( $symbol ne "" ) {

               push @{$by_symbol{$symbol}}, $temp;
            }
            else {
              push @tempArray, $temp;
            }
          }
        }
      }

      for $symbol (sort keys %by_symbol) {
        foreach $temp ( @{$by_symbol{$symbol}} ) {
          ## push @ordered_genes, $temp;
          push @ordered_results, $temp;
        }
      }

      for ($i = 0; $i < @tempArray; $i++) {
        ## push @ordered_genes, $tempArray[$i];
        push @ordered_results, $tempArray[$i];
      }
    }
    else {

      $sql = "select cluster_number, gene from $CGAP_SCHEMA." . 
          ($org eq "Hs" ? "hs_cluster" : "mm_cluster") . " " .
          "where gene is not null";
      $stm = $db->prepare($sql);
      if (not $stm) {
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
        return undef;
      }
      while (($cid, $gene) = $stm->fetchrow_array()) {
        if ($org eq "Hs") {
          $hs_cid2sym{$cid} = $gene;
        } else {
          $mm_cid2sym{$cid} = $gene;
        } 
      }

      if ( $org eq "Hs" ) {

        while (@{ $refer }) {
          $cid = shift @{ $refer };
          if ( defined ($gene = $hs_cid2sym{ $cid }) ) {
            push @{$by_symbol{$gene}}, $cid;
          }
          else {
            push @tempArray, $cid;
          }
        }
      }
      else {

        while (@{ $refer }) {
          $cid = shift @{ $refer };
          if ( defined ($gene = $mm_cid2sym{ $cid }) ) {
            push @{$by_symbol{$gene}}, $cid;
          }
          else {
            push @tempArray, $cid;
          }
        }
      }

      for $gene (sort keys %by_symbol) {
        foreach $cid ( @{$by_symbol{$gene}} ) {
          push @ordered_genes, $cid;
        }
      }

      for($m=0; $m< @tempArray; $m++) {
        push @ordered_genes, $tempArray[$m];
      }

      $i = ($page - 1) * ITEMS_PER_PAGE;

      if (($i + 300-1) < @ordered_genes) {
        $list = join(",", @ordered_genes[$i..$i+300-1]);
      }
      else {
        $list = join(",", @ordered_genes[$i..@ordered_genes-1]);
      }

      # don't hyperlink accession if no motif info
      my $ug_sequence =
        ($org eq "Hs") ? "hs_ug_sequence" : "mm_ug_sequence";
      $sql = "select r.cluster_number, r.accession " .
             "from $CGAP_SCHEMA.rnai2ug r, " .
             "     $CGAP_SCHEMA.mrna_cds m, " .
             "     $CGAP_SCHEMA.$ug_sequence n " .
             "where r.organism = '$org' " .
             "and r.cluster_number in (" .  $list . " ) " .
             "and r.accession = m.mrna_accession " .
             "and r.accession = n.accession " .
             "and r.cluster_number = n.cluster_number " ;
 
      ## print "8888: $sql \n<br>"; 
      $stm = $db->prepare($sql);
 
      if (not $stm) {
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
 
      $stm->bind_columns(\$cluster_number, \$acc);

      while($stm->fetch) {
        $viewlink{$cluster_number}{$acc} = 'V';
      }

      my $table_name = ($org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster"
                                     : "$CGAP_SCHEMA.mm_cluster");

      $sql = "select r.cluster_number, c.gene, c.description, " .
             "       o.oligo_id, o.oligo_seq, o.accession " .
             "from $CGAP_SCHEMA.rnai2ug r, " .
             "     $CGAP_SCHEMA.rnai_oligo o, " .
             "     $table_name c, " .
             "     $CGAP_SCHEMA.$ug_sequence n " .
             "where r.organism = '$org' " .
             "and r.cluster_number in (" .  $list . " ) " .
             "and r.cluster_number = c.cluster_number " .
             "and r.oligo_id = o.oligo_id " .
             "and o.accession = n.accession " .
             "and r.cluster_number = n.cluster_number " .
             "order by c.gene, o.accession, o.oligo_seq, r.oligo_id";

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
          return undef;
        }

        $stm->bind_columns(\$cluster_number, \$gene, \$title, \$oligo, \$seq, \$acc);

        my %unique;
        my %acc2oligo;
        my %acc2seq;
        my %acc2info;
        ## my %unique_seq;
        my $change_flag = 0;
        my %unique_gene_acc;
        while($stm->fetch) {

          if( defined $unique{$cluster_number}{$gene}{$title}{$oligo}{$seq}{$acc} ) {
            next;
          }
          else {
            $unique{$cluster_number}{$gene}{$title}{$oligo}{$seq}{$acc} = 1;
          }

          my $oligo_link = "<A href=javascript:spawn(" .
            "\"http://www.openbiosystems.com/Query/?i=0&q=$oligo\")>$oligo</A>";
          if ($last_gene) {
            if ($last_gene eq $cluster_number) {
              if( not defined $acc2info{$acc} ) {
                ## $acc2oligo{$acc} = $oligo;
                $acc2oligo{$acc} = $oligo_link;
                $acc2seq{$acc} = $seq;
                if( not defined $unique_gene_acc{$gene}{$acc} ) {
                  $unique_gene_acc{$gene}{$acc} = 1;
                  $change_flag = 0;
                }
                $change_flag = 0;
                ## $unique_seq{$seq} = 1;
                $vacc = "$acc" . "$viewlink{$cluster_number}{$acc}";
                $acc2info{$acc} = "$cluster_number\001$gene\001OLIGOSEQ\001$vacc\001$title";
              ## }
              ## elsif ($count % 2) {
              ##   $acc2oligo{$acc} = $acc2oligo{$acc} . "<BR><span style='background-color:f2f2f2'>$oligo</span>";
              ##   $acc2seq{$acc} = $acc2seq{$acc} . "<BR><span style='background-color:f2f2f2'>$seq</span>";
              ## } else {
              } else {
                ## $acc2oligo{$acc} = $acc2oligo{$acc} . "<BR>$oligo";
                $acc2oligo{$acc} = $acc2oligo{$acc} . "<BR>$oligo_link";
                if( !($acc2seq{$acc} =~ /$seq/) ) {
                  if( $change_flag == 0 ) {
                    $change_flag = 1;
                    $acc2seq{$acc} = $acc2seq{$acc} . "<BR><font color=\"FF0000\">$seq<\/font>";
                  }
                  elsif ( $change_flag == 1 ) {
                    $change_flag = 0;
                    $acc2seq{$acc} = $acc2seq{$acc} . "<BR>$seq";
                  }
                }
                else {
                  if( $change_flag == 0 ) {
                    $acc2seq{$acc} = $acc2seq{$acc} . "<BR>$seq"; 
                  }
                  elsif ( $change_flag == 1 ) {
                    $acc2seq{$acc} = $acc2seq{$acc} . "<BR><font color=\"FF0000\">$seq<\/font>";
                  }

                }
              }
              $count++;
            } else {
              for my $acc (keys %acc2info ) {
                $acc2info{$acc} =~ s/OLIGOSEQ/$acc2oligo{$acc}\001$acc2seq{$acc}/; 
                $ordered_results[$i] = $acc2info{$acc};
                $i++;
              }
              ## undef %unique_seq;
              $change_flag = 0;
              undef %acc2info;
              undef %acc2oligo;
              undef %acc2seq;
              $last_gene = $cluster_number;
              ## $acc2oligo{$acc} = $oligo;
              $acc2oligo{$acc} = $oligo_link;
              $acc2seq{$acc} = $seq;
              $change_flag = 0;
              ## $unique_seq{$seq} = 1;
              $vacc = "$acc" . "$viewlink{$cluster_number}{$acc}";
              $acc2info{$acc} = "$cluster_number\001$gene\001OLIGOSEQ\001$vacc\001$title";
              $count = 1;
            }
          } else {
            $last_gene = $cluster_number;
            ## $acc2oligo{$acc} = $oligo;
            $acc2oligo{$acc} = $oligo_link;
            $acc2seq{$acc} = $seq;
            ## $unique_seq{$seq} = 1;
            $change_flag = 0; 
            $vacc = "$acc" . "$viewlink{$cluster_number}{$acc}";
            $acc2info{$acc} = "$cluster_number\001$gene\001OLIGOSEQ\001$vacc\001$title";
            $count = 1;
          }
        }
        for my $acc (keys %acc2info ) { 
          $acc2info{$acc} =~ s/OLIGOSEQ/$acc2oligo{$acc}\001$acc2seq{$acc}/;
          $ordered_results[$i] = $acc2info{$acc};
          $i++;
        }
      }
    }

    $db->disconnect();

  }

  return \@ordered_results;

}

######################################################################
sub GetClones_1 {
 
  my ($org1, $items_ref, $items_in_memory, $filedata) = @_;
  my (%ug_access_to_clones, %ug_syms);
    
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
 
    my ($this_org, $this_cid);
    ## $org1 = "";
 
    if( $filedata =~ /\r/ ) {
      @tempArray = split "\r", $filedata;
    }
    else {
      @tempArray = split "\n", $filedata;
    }
 
    for ( my $k = 0; $k < @tempArray; $k++ ) {
      $tempArray[$k] =~  s/\s+//;
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
      splice @tempArray, $k, 1;
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
      ##print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
      print STDERR "Cannot connect to database \n";
      return "";
  }
    
  $sql =
      "select " .
        "m.CLUSTER_NUMBER, m.ACCESSION, m.IMAGE_ID " .
      "from " .
        "$CGAP_SCHEMA.MGC_MRNA m, $CGAP_SCHEMA.mgc_organism g " .
      "where " .
        "g.org_code = m.organism and g.org_abbrev = '$org' " .
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
            $length = "";
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
sub InitializeImage {

  my $im = new GD::Image($IMAGE_WIDTH, $IMAGE_HEIGHT);
 
  # allocate some colors
##
## Apparently, the first color allocated becomes the background color of
## the image by default
##
  $COLORS{white}       = $im->colorAllocate(255,255,255);
  $COLORS{black}       = $im->colorAllocate(0,0,0);
  $COLORS{darkblue}    = $im->colorAllocate(0,0,139);
  $COLORS{darkred}     = $im->colorAllocate(196,0,0);
  $COLORS{teal}        = $im->colorAllocate(0,148,145);
  $COLORS{orange}      = $im->colorAllocate(245,174,29);
  $COLORS{purple}      = $im->colorAllocate(154,37,185);
  $COLORS{midblue}     = $im->colorAllocate(0,147,208);
  $COLORS{pink}        = $im->colorAllocate(238,162,173);
  $COLORS{gold}        = $im->colorAllocate(238,216,174);
  $COLORS{lightblue}   = $im->colorAllocate(178,238,238);
  $COLORS{midgreen}    = $im->colorAllocate(0,186,7);
  $COLORS{midyellow}   = $im->colorAllocate(251,247,157);
  $COLORS{orchid}      = $im->colorAllocate(184,88,153);
  $COLORS{olive}       = $im->colorAllocate(128,128,0);
  $COLORS{darkgreen}   = $im->colorAllocate(0,100,0);
  $COLORS{darksalmon}  = $im->colorAllocate(233,150,122);
  $COLORS{red}         = $im->colorAllocate(255,0,0);
  $COLORS{blue}        = $im->colorAllocate(0,0,255);
  $COLORS{maroon}      = $im->colorAllocate(176,48,96);

# $COLORS{lightblue}   = $im->colorAllocate(173,216,230);
# $COLORS{green}       = $im->colorAllocate(0,128,0);
# $COLORS{yellow}      = $im->colorAllocate(255,255,0);
# $COLORS{violet}      = $im->colorAllocate(238,130,238);
# $COLORS{yellowgreen} = $im->colorAllocate(154,205,50);

# $COLORS{gray}        = $im->colorAllocate(128,128,128);
# $COLORS{lightgray}   = $im->colorAllocate(211,211,211);
# $COLORS{gray}        = $im->colorAllocate(200,200,200);
# $COLORS{mediumgray}  = $im->colorAllocate(220,220,220);
# $COLORS{lightgray}   = $im->colorAllocate(240,240,240);

  $im->transparent($COLORS{white});
# $im->interlaced("true");

  return $im;
}

######################################################################
sub DrawGrid {
  my ($im, $acc, $sym, $image_map) = @_;

  my ($nt, $nt_from, $nt_to, $pf_id, $pf_pos, $oligo_id);
  my ($x0, $x1, $y0, $y1, $bottom, $show_from, $show_to);
  ## my $ohio = 30;
  my $ohio = 80;
  my (%motif_color, $color, $this_color);
  my @palette = 
    ("","darkred","teal","orange","purple","midblue",
        "pink","gold","lightblue","midgreen","midyellow",
        "orchid", "olive", "darkgreen", "darksalmon",
        "red", "blue", "maroon");

  my $PIX_FACTOR = ($IMAGE_WIDTH - ($HORZ_MARGIN*2)) / $nt{$acc};

  $im->string(gdLargeFont, $HORZ_MARGIN*2, $VERT_MARGIN, 
    "Location of RNAi Targets in Transcript", $COLORS{darkblue});

  ## 5' - 3'  :- black line
  $x0 = $HORZ_MARGIN;
  ## $x1 = $IMAGE_WIDTH - $HORZ_MARGIN;
  $x1 = $IMAGE_WIDTH - $HORZ_MARGIN/4;
  $y0 = ($IMAGE_HEIGHT / 3);
  $y1 = ($IMAGE_HEIGHT / 3);

  $im->filledRectangle (
      $x0,
      $y0,
      $x1,
      $y1,
      $COLORS{black}
  );

  $im->string(gdSmallFont, $x0 - 15, $y0 - 5, "5'", $COLORS{black});
  $im->string(gdSmallFont, $x1 +  5, $y0 - 5, "3'", $COLORS{black});

  $im->string(gdTinyFont, $IMAGE_MARGIN, $y1 - 20, "Oligo ID", $COLORS{black});
  $im->string(gdTinyFont, $IMAGE_MARGIN, $y1 + 18, "Nucleotide#", $COLORS{black});

  ## OLIGOS

  my $total = @oligo;
  my $count = 0;
  my $HIGH = $total * 10;

  my %unique; 
  my %pos2id;
  for $oligo_id (@oligo) {
    
    $nt_from = $PIX_FACTOR * $oligo{$oligo_id};

    $ohio = $HIGH - $count * 10;
    $count++;
    ## $ohio = ($ohio == 10) ? 20 : (($ohio == 20) ? 30 : 10);
    $x0 = ($HORZ_MARGIN + $nt_from);
    $x1 = ($HORZ_MARGIN + $nt_from);
    $y1 = ($IMAGE_HEIGHT / 3);
    $y0 = $y1 - $ohio;

    if( defined $unique{$oligo{$oligo_id}} ) {
      ## $im->string(gdTinyFont, $x0, $y0-10, "$oligo_id", $COLORS{red});
      $im->string(gdTinyFont, $x0, $y0-10, "$oligo_id", $COLORS{black});
      $x0 = $x0 + 5 * $unique{$oligo{$oligo_id}};
      $y0 = $y0 - 20;
      $im->string(gdTinyFont, $x0, $y0, ",", $COLORS{black});
      $unique{$oligo{$oligo_id}} = length($oligo_id);
      next;
    }
    else{
      $im->string(gdTinyFont, $x0, $y0-10, "$oligo_id", $COLORS{black});
      $unique{$oligo{$oligo_id}} = length($oligo_id);
    }

    $pos2id{$oligo{$oligo_id}}{$oligo_id} = 1; 

    $im->filledRectangle (
      $x0,
      $y0,
      $x1,
      $y1,
      $COLORS{black}
    );

    ## Nucleotide#
    $y0 = $y1 + $ohio + 2;

    $im->string(gdTinyFont, $x0, $y0+5, "$oligo{$oligo_id}", $COLORS{black});

    $im->filledRectangle (
      $x0,
      $y1,
      $x1,
      $y0,
      $COLORS{black}
    );
  }

  my $NT_MARGIN1 = $HORZ_MARGIN + ($PIX_FACTOR * $orf_from{$acc});
  my $NT_MARGIN2 = $HORZ_MARGIN + ($PIX_FACTOR * $orf_to{$acc});

  ## NT  :- blue line
  $x0 = $NT_MARGIN1;
  $x1 = $NT_MARGIN2;
  $y0 = ($IMAGE_HEIGHT / 3) - 2;
  $y1 = ($IMAGE_HEIGHT / 3) + 2;

  $im->filledRectangle (
      $x0,
      $y0,
      $x1,
      $y1,
      $COLORS{darkblue}
  );

  ## MOTIFS  :- color line
  $color = 1;
  ## $bottom = (($IMAGE_HEIGHT / 3) * 2) - 50;
  $bottom = (($IMAGE_HEIGHT / 3) * 2) - 20;
  $im->string(gdSmallFont, $HORZ_MARGIN, $bottom, "CDS: ", $COLORS{darkblue});
  $x0 = ($HORZ_MARGIN + 50);
  $x1 = $x0 + 40;
  $bottom += 5;
  $im->filledRectangle (
    $x0,
    $bottom,
    $x1,
    $bottom + 5,
    $COLORS{darkblue}
  );
  $bottom += 15;
  $im->string(gdSmallFont, $HORZ_MARGIN, $bottom, "motifs: ", $COLORS{darkblue});
  $bottom += 3;
  for $pf_pos (sort numerically keys %motif_pos) {
    $pf_id = $motif_pos{$pf_pos};
    next if (! $motif_from{$pf_id}{$pf_pos});
    $show_from = ($orf_from{$acc} + ($motif_from{$pf_id}{$pf_pos} * 3));
    $show_to   = ($orf_from{$acc} + ($motif_to{$pf_id}{$pf_pos} * 3));
    $nt_from = $PIX_FACTOR * $show_from;
    $nt_to   = $PIX_FACTOR * $show_to;

    $x0 = ($HORZ_MARGIN + $nt_from);
    $x1 = ($HORZ_MARGIN + $nt_to);
    $y0 = ($IMAGE_HEIGHT / 3) - 4;
    $y1 = ($IMAGE_HEIGHT / 3) + 4;

    if (! $motif_color{$pf_id}) {
      $motif_color{$pf_id} = $color;
      $color++;
    }
    $this_color = $motif_color{$pf_id};

    $im->filledRectangle (
      $x0,
      $y0,
      $x1,
      $y1,
      $COLORS{$palette[$this_color]}
    );

    $im->string(gdSmallFont, ($HORZ_MARGIN + 70), $bottom, "$motif_family{$pf_id}   (nt $show_from - $show_to)", $COLORS{darkblue});
    $x0 = ($HORZ_MARGIN + 50);
    $x1 = $x0 + 10;
    $im->filledRectangle (
      $x0,
      $bottom,
      $x1,
      $bottom + 10,
      $COLORS{$palette[$this_color]}
    );
    $bottom += 15;
  }

}

######################################################################
sub TranslateBPAxis {
  my ($x0_bp, $x_bp) = @_;

  ## 'x' does NOT imply x-axis
  ## $x0_bp: origin, in SCALED base pair units, of the zoomed data area
  ## $x_bp:  position on genome in SCALED base pair units
  ## returns position as pixel

  return ($x_bp - $x0_bp);
}

######################################################################
sub TranslatePixelAxis {
  my ($x0_pix, $x_pix) = @_;

  ## 'x' does NOT imply x-axis
  ## $x0_pix: pixel coordinate of origin of the drawn axis
  ## $x_pix:  distance, in pixels, from origin of drawn axis

  return $x0_pix + $x_pix;

}

######################################################################
sub GetRNAiFromCache_1 {
  my ($base, $cache_id) = @_;

  $BASE = $base;

  return ReadRNAiFromCache($cache_id);
}

######################################################################
sub ReadRNAiFromCache {
  my ($cache_id) = @_;

  my ($s, @data);

  if ($cache->FindCacheFile($cache_id) eq $CACHE_FAIL) {
    return "Cache expired";
  }
  my $filename = $cache->FindCacheFile($cache_id);
  open(RIN, "$filename") or die "Can't open $filename.";
  while (read RIN, $s, 16384) {
    push @data, $s;
  }
  close (RIN);
  return join("", @data);

}

######################################################################
sub debug_print {
  my @args = @_;
  my $i = 0;
  if (defined($DEBUG_FLAG) && $DEBUG_FLAG) {
    for($i = 0; $i <= $#args; $i++) {
      print " $args[$i]\n";
    }
  }
}


######################################################################

1;
