#!/usr/local/bin/perl

use strict;
use CGAPConfig;
use DBI;
use URI::Escape;
use FisherExact;

if (-d "/app/oracle/product/10gClient") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/10gClient"
} elsif (-d "/app/oracle/product/dbhome/current") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/dbhome/current";
} elsif (-d "/app/oracle/product/8.1.7") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.7";
} elsif (-d "/app/oracle/product/8.1.6") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.6";
}

my $BASE;

my $BPP_EXP_ID = 1;

use constant MAX_ROWS_PER_FETCH => 1000;
use constant MAX_LONG_LEN       => 16384;
use constant ORACLE_LIST_LIMIT  => 500;

##
## GO stuff
##

my $GO_ROOT = "0003673";
my %GO_OBSOLETE = (
  "0008370" => "CC",
  "0008369" => "MF",
  "0008371" => "BP" 
);
my %GO_CLASS_ID = (
  "0008150" => "BP",
  "0003674" => "MF",
  "0005575" => "CC" ,
  "biological_process" => "0008150",
  "molecular_function" => "0003674",
  "cellular_component" => "0005575",
  "BP" => "biological_process",
  "MF" => "molecular_function",
  "CC" => "cellular_component"
);

my $GO_OBSOLETE_LIST = "'" . join("','", keys %GO_OBSOLETE) . "'";


######################################################################
sub numerically { $a <=> $b; }

######################################################################
sub GO_IMAGE_TAG {
  my ($image_name) = @_;
  return "<image src=\"$BASE/images/$image_name\" " .
      "width=15 height=15 border=0>";
}

######################################################################
sub GO_PROTEIN_URL {
  my ($go_name) = @_;
  return "http://bpp-dev.nci.nih.gov/ProteinList?PAGE=1&ORG=Hs&" .
      "TERM=" . uri_escape("GO:$go_name");
}

######################################################################
sub GO_GENE_URL {
  my ($go_id, $org) = @_;
  return "$BASE/Genes/GoGeneQuery?PAGE=1&ORG=$org&" .
      "GOID=$go_id";
}

######################################################################
sub GetGeneCounts {
  my ($db, $id2name, $counts) = @_;

  my ($sql, $stm);
  my ($go_id, $organism, $count);
  my $list = "'" . join("','", keys %{ $id2name }) . "'";

#  $sql = qq!
#select /*+ */
#  a.go_ancestor_id,
#  l.organism,
#  count (unique l.ll_id)
#from
#  $CGAP_SCHEMA.ll_go l,
#  $CGAP_SCHEMA.go_ancestor a
#where
#      a.go_ancestor_id in ($list)
#  and a.go_id = l.go_id
#group by
#  a.go_ancestor_id,
#  l.organism
#  !;

  $sql = qq!
select
  c.go_id,
  c.organism,
  c.ug_count
from
  $CGAP_SCHEMA.go_count c
where
      c.go_id in ($list)
  !;

  $stm = $db->prepare($sql);
  if (!$stm) {
    ## print STDERR "sql: $sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</certer>";
    $db->disconnect();
    return "";
  } 
  if (!$stm->execute()) {
    ## print STDERR "$sql\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while (($go_id, $organism, $count) = $stm->fetchrow_array()) {
    if ($count) {
      $$counts{$go_id}{$organism} = $count;
    }
  }

}

######################################################################
sub GetProteinCounts {
  my ($db, $id2name, $counts) = @_;

  my ($sql, $stm);
  my ($go_id, $count);

  my $list = "'" . join("','", keys %{ $id2name }) . "'";

  $sql = qq!
select /*+ */
  a.go_ancestor_id,
  count(unique s.sp_accession)
from
  $CGAP_SCHEMA.go_ancestor a,
  $CGAP_SCHEMA.bpp_exp_prot b,
  $CGAP_SCHEMA.sp2go s
where
      a.go_id = s.go_id
  and a.go_ancestor_id in ($list)
  and b.exp_id = 1
  and b.sp_ac = s.sp_accession
group by
  a.go_ancestor_id
  !;

  $stm = $db->prepare($sql);
  if (!$stm) {
    print "<br><b><center>Error in input</b>!</certer>";
    $db->disconnect();
    return "";
  } 
  if (!$stm->execute()) {
    ## print STDERR "$sql\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while (($go_id, $count) = $stm->fetchrow_array()) {
    $$counts{$go_id} = $count;
  }
}

######################################################################
sub AddAncestors {
  my ($db, $focal_node, $nodes) = @_;

  my ($sql, $stm);
  my ($go_ancestor_id, $go_class);

  $$nodes{$focal_node} = 1;
  my $list = "'" . join("','", keys %{ $nodes }) . "'";

  $sql = qq!
select
  a.go_ancestor_id, n.go_class
from
  $CGAP_SCHEMA.go_ancestor a,
  $CGAP_SCHEMA.go_name n
where
      a.go_id in ($list)
  and n.go_id = a.go_id
  !;

  $stm = $db->prepare($sql);
  if (!$stm) {
    ## print STDERR "sql: $sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</certer>";
    $db->disconnect();
    return "";
  } 
  if (!$stm->execute()) {
    ## print STDERR "$sql\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while (($go_ancestor_id, $go_class) = $stm->fetchrow_array()) {
    $$nodes{$go_ancestor_id} = 1;
    ## ancestor table does not include the three top-level ancestors
    ## so add them now, if appropriate.
    if (defined $GO_CLASS_ID{$go_class}) {
      $$nodes{$GO_CLASS_ID{$GO_CLASS_ID{$go_class}}} = 1; 
    }
  }
}

######################################################################
sub CloseNodes {
  my ($db, $focal_node, $nodes) = @_;

  my ($sql, $stm);
  my ($go_id);

  delete $$nodes{$focal_node};

  if (defined $GO_CLASS_ID{$focal_node}) {
    $sql = qq!
select
  a.go_id
from
  $CGAP_SCHEMA.go_ancestor a
where
      a.go_ancestor_id = '$focal_node'
  or a.go_ancestor_id in (
    select
      p.go_id
    from
      $CGAP_SCHEMA.go_parent p
    where
      p.go_parent_id = '$focal_node'
  )
    !;
  } else {
    $sql = qq!
select
  a.go_id
from
  $CGAP_SCHEMA.go_ancestor a
where
      a.go_ancestor_id = '$focal_node'
    !;
  }
  $stm = $db->prepare($sql);
  if (!$stm) {
    print "<br><b><center>Error in input</b>!</certer>";
    $db->disconnect();
    return "";
  } 
  if (!$stm->execute()) {
    ## print STDERR "$sql\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while (($go_id) = $stm->fetchrow_array()) {
    delete $$nodes{$go_id};
  }

}

######################################################################
sub Descend {
  my ($level, $node, $kids_name, $name2id, $lines) = @_;

  my ($name, $parent_type);

  for $name (sort keys %{ $$kids_name{$node} }) {
    $parent_type = $$kids_name{$node}{$name};
    push @{ $lines }, "$level\t$parent_type\t$name\t$$name2id{$name}";
    Descend($level+1, $name, $kids_name, $name2id, $lines);
  }
}

######################################################################
sub GetAllParents {
  my ($db, $all_parents) = @_;

  my ($sql, $stm);
  my ($go_parent_id);

  $sql = qq!
select unique
  p.go_parent_id
from
  $CGAP_SCHEMA.go_parent p
  !;

  $stm = $db->prepare($sql);
  if (!$stm) {
    ## print STDERR "sql: $sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</certer>";
    $db->disconnect();
    return "";
  } 
  if (!$stm->execute()) {
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while (($go_parent_id) = $stm->fetchrow_array()) {
    $$all_parents{$go_parent_id} = 1;
  }
}

######################################################################
sub GOTree {
  my ($db, $nodes, $kids_id, $kids_name, $id2name, $name2id, $lines) = @_;

  my ($sql, $stm);
  my ($go_name, $go_class, $go_id, $go_parent_name,
      $go_parent_id, $parent_type);
  my $list = "'" . join("','", keys %{ $nodes }) . "'";

  $sql = qq!
select
  nc.go_name,
  nc.go_class,
  nc.go_id,
  np.go_name,
  p.go_parent_id,
  p.parent_type
from
  $CGAP_SCHEMA.go_parent p,
  $CGAP_SCHEMA.go_name np,
  $CGAP_SCHEMA.go_name nc
where
      p.go_parent_id in ($list)
  and np.go_id = p.go_parent_id
  and nc.go_id = p.go_id
  !;

  $stm = $db->prepare($sql);
  if (!$stm) {
    print "<br><b><center>Error in input</b>!</certer>";
    $db->disconnect();
    return "";
  } 
  if (!$stm->execute()) {
    ## print STDERR "$sql\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while (($go_name, $go_class, $go_id, $go_parent_name,
      $go_parent_id, $parent_type) = $stm->fetchrow_array()) {

    if (defined $GO_OBSOLETE{$go_id}) {
      next;
    }
    $$kids_id{$go_parent_id}{$go_id}       = $parent_type;
    $$kids_name{$go_parent_name}{$go_name} = $parent_type;
    $$id2name{$go_id}   = $go_name;
    $$name2id{$go_name} = $go_id;
    $$id2name{$go_parent_id}   = $go_parent_name;
    $$name2id{$go_parent_name} = $go_parent_id;
  }
  Descend(0, "", $kids_name, $name2id, $lines);
}

######################################################################
sub FormatOneLine {
  my ($what, $target, $focal_node, $nodes, $all_parents, $counts, $line,
      $lines_out) = @_;

  my ($level, $type, $name, $id) = split(/\t/, $line);
  my ($open_close_url, $count);
  if (defined $$nodes{$id}) {
    ##
    ## id is currently "open"
    ##
    $open_close_url = "<a href=\"javascript:" .
        "document.bf.NODE.value='$id';" .
        "document.bf.CMD.value='close';" .
        "document.bf.submit()\">" .
        GO_IMAGE_TAG("minus.gif") . "</a>";
  } elsif (defined $$all_parents{$id}) {
    ##
    ## id is currently "closed" but has kids
    ##
    $open_close_url = "<a href=\"javascript:" .
        "document.bf.NODE.value='$id';" .
        "document.bf.CMD.value='open';" .
        "document.bf.submit()\">" .
        GO_IMAGE_TAG("plus.gif") . "</a>";
  } else {
    $open_close_url = GO_IMAGE_TAG($type eq "P" ? "partof.gif" : "isa.gif");
  }
  if ($$counts{$id}) {
    if ($what eq "PROTEIN") {
      $count = "&nbsp;<a href=\"" . GO_PROTEIN_URL($name) .
          "\" target=$target>\[$$counts{$id}\]<a>";
    } elsif ($what eq "GENE") {
      my $h = $$counts{$id};
      for my $org ("Hs", "Mm") {
        my $c = $$h{$org};
        if ($c) {
          $count .= "&nbsp;<a href=\"" . GO_GENE_URL($id, $org) .
            "\" target=$target>\[$org:$c\]</a>";
        }
      }
    }
  }
  if ($id eq $focal_node) {
    $name = "<font color=green>$name</font>";
  }
  my $indent;
  for (my $i = 1; $i <= $level; $i++) {
#    $indent .= "&nbsp;&nbsp;&nbsp;&nbsp;"
    $indent .= GO_IMAGE_TAG("blank.gif");
  }
  push @{ $lines_out },
      $indent . $open_close_url . "&nbsp;" . $name . $count . "<br>";
  if ($id eq $focal_node) {
    return 1;
  } else {
    return 0;
  }
}

######################################################################
sub FormatLines {
  my ($what, $url, $target, $focal_node, $nodes, $all_parents, $counts, $lines,
      $lines_out) = @_;

  push @{ $lines_out },
      "<form name=bf method=post action=\"$url\">";
  push @{ $lines_out },
      "<input type=hidden name=CMD>";
  push @{ $lines_out },
      "<input type=hidden name=NODE>";
  for my $n (keys %{ $nodes }) {
    if ($n) {
      push @{ $lines_out },
          "<input type=hidden name=GOIDS value=\"$n\">";
    }
  }

  my ($i, $is_focal, $focal_point);
  for my $line (@{ $lines }) {
    $i++;
    $is_focal =
        FormatOneLine($what, $target, $focal_node, $nodes,
            $all_parents, $counts, $line, $lines_out);
    if ($is_focal) {
      $focal_point = $i;
    }
  }

  push @{ $lines_out }, "</form>\n";

  return $focal_point;
}

######################################################################
sub GOBrowser_1 {
  my ($base, $gene_or_prot, $cmd, $url, $target,
      $focal_node, $context_node_list) = @_;

  $BASE = $base;

  my (%nodes, @lines, %all_parents, %counts,
      %kids_id, %kids_name, %id2name, %name2id);

  my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    print STDERR "Cannot connect to database \n";
    ## print STDERR "$DBI::errstr\n";
    return;
  }

  $nodes{$GO_ROOT} = 1;
  for my $i (split(",", $context_node_list)) {
    $nodes{$i} = 1;
  }

  if ($cmd eq "") {
    $cmd = "open";
  }
  if ($focal_node eq "") {
    $focal_node = $GO_ROOT;
  }

  if ($cmd eq "open") {
    $nodes{$focal_node} = 1;
    AddAncestors($db, $focal_node, \%nodes);
  } elsif ($cmd eq "close") {
    CloseNodes($db, $focal_node, \%nodes);
  } else {
    print STDERR "Illegal action: $cmd\n";
  }
 
  GOTree($db, \%nodes, \%kids_id, \%kids_name, \%id2name, \%name2id, \@lines);
  GetAllParents($db, \%all_parents);
  if ($gene_or_prot eq "PROTEIN") {
    GetProteinCounts($db, \%id2name, \%counts);
  } elsif ($gene_or_prot eq "GENE") {
    GetGeneCounts($db, \%id2name, \%counts);
  }
  $db->disconnect();

  my @lines_out;
  my $BANNER_ETC_LINES = 12;
  my $focal_line = FormatLines($gene_or_prot, $url, $target, $focal_node,
      \%nodes, \%all_parents, \%counts, \@lines, \@lines_out) + 
      $BANNER_ETC_LINES;
  my $PIXELS_PER_LINE = 16;
  my $y_coord = $focal_line * $PIXELS_PER_LINE;
  push @lines_out,
      qq!
<script>
  window.scrollTo(0,$y_coord);
</script>
      !;
  return join("\n", @lines_out) . "\n";

}

######################################################################
sub SummarizeGOForGeneSet_1 {
  my ($base, $org, $cids) = @_;

  $BASE = $base;

  my ($a, $b, $A, $B, $P);
  my ($dir);
  my (@lines, %temp);
  my (%cache);

  my (%go2cid, %go2name, %go2class);
  my (%total, %direct_total);
  my ($total_annotated_genes);

  my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    ## print STDERR "$DBI::errstr\n";
    print "Cannot connect to database \n";
    return "";
  }
  $db->{LongReadLen} = MAX_LONG_LEN;

  GetGOAnnotations($db, $org, $cids, \%go2cid);
  GetGONames($db, \%go2cid, \%go2name, \%go2class);
  GetGOTotals($db, $org, \%go2cid, \%total, \%direct_total);
  GetTotalAnnotatedGenes($db, $org, \$total_annotated_genes);

  $db->disconnect();

  for my $go_id (keys %go2cid) {
    ($a, $b, $A, $B) = (
      scalar(keys %{ $go2cid{$go_id} }),
      scalar($total{$go_id}),
      scalar(@{ $cids }),
      $total_annotated_genes);
    if ($a/$A > $b/$B) {
      $dir = "HI";
      if (defined $cache{"$a,$b,$A,$B"}) {
        $P = $cache{"$a,$b,$A,$B"};
      } else {
        $P = sprintf "%.2e",
            FisherExact::FisherExact($a, $b, $A, $B);
#        $P = sprintf "%.2f",
#             1 - Bayesian::Bayesian(1, $a, $b, $A, $B);
        $cache{"$a,$b,$A,$B"} = $P;
      }
    } else {
      $dir = "LO";
      ## if (defined $cache{"$a,$b,$A,$B"}) { ## looks wrong here.
      if (defined $cache{"$b,$a,$A,$B"}) {
        $P = $cache{"$b,$a,$B,$A"};
      } else {
        $P = sprintf "%.2e",
            FisherExact::FisherExact($b, $a, $B, $A);
#        $P = sprintf "%.2f",
#             1 - Bayesian::Bayesian(1, $b, $a, $B, $A);
        $cache{"$b,$a,$B,$A"} = $P;
      }
    }
    if ($dir eq "HI" && $P <= 0.05) {
      push @{ $temp{$P}{$go2class{$go_id}} },
          join("\t", $go2class{$go_id}, "GO:$go_id", $go2name{$go_id},
          $a . "/" . $A, $b . "/" . $B, $P);
    }

  }
  if (defined %temp) {
    push @lines, join("\t", "Class", "GO Id", "GO Term",
        "Hits in list", "All annotated genes", "Fisher Exact");
    for my $P (sort numerically keys %temp) {
      for my $c ("BP", "MF", "CC") {
        if (defined $temp{$P}{$c}) {
          push @lines, @{ $temp{$P}{$c} };
        }
      }
    }
  } else {
    push @lines, "No significantly over-represented GO annotations found";
  }
  return join("\n", @lines) . "\n";
}

######################################################################
sub GetTotalAnnotatedGenes {
  my ($db, $org, $total_annotated_genes) = @_;

  my ($sql, $stm);

  $sql = qq!
select
  count(unique u.cluster_number)
from
  $CGAP_SCHEMA.gene2unigene u,
  $CGAP_SCHEMA.ll_go l
where
      l.organism = '$org'
  and u.organism = '$org'
  and l.ll_id = u.gene_id
  !;
  $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</certer>";
    $db->disconnect();
    return "";
  }
  if (!$stm->execute()) {
    print "Execute failed\n";
    $db->disconnect();
    return;
  }
  ($$total_annotated_genes) = $stm->fetchrow_array();
  $stm->finish();

}

######################################################################
sub GetGOTotals {
  my ($db, $org, $go2cid, $total, $direct_total) = @_;

  my ($i, $list, $sql, $stm);
  my ($go_id, $tot, $direct_tot);
  my ($row, $rowcache);

  my @go_ids = keys %{ $go2cid };

  for($i = 0; $i < @go_ids; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @go_ids) {
      $list = join(",", @go_ids[$i..$i+ORACLE_LIST_LIMIT-1]);
    }
    else {
      $list = "'"  . join("','", @go_ids[$i..@go_ids-1]) . "'";
    }
    $sql = qq!
select
  go_id,
  ug_count,
  direct_ug_count
from
  $CGAP_SCHEMA.go_count
where
      organism = '$org'
  and go_id in ($list)
    !;
    $stm = $db->prepare($sql);
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</certer>";
      $db->disconnect();
      return "";
    }
    if (!$stm->execute()) {
      print "Execute failed\n";
      $db->disconnect();
      return;
    }
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($go_id, $tot, $direct_tot) = @{ $row };
        $$total{$go_id} = $tot;
        $$direct_total{$go_id} = $direct_tot;
      }
    }
  }
}

######################################################################
sub GetGONames {
  my ($db, $go2cid, $go2name, $go2class) = @_;

  my ($list, $i, $sql, $stm);
  my ($go_id, $go_name, $go_class);
  my ($rowcache, $row);

  my @go_ids = keys %{ $go2cid };

  for($i = 0; $i < @go_ids; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @go_ids) {
      $list = join(",", @go_ids[$i..$i+ORACLE_LIST_LIMIT-1]);
    }
    else {
      $list = "'"  . join("','", @go_ids[$i..@go_ids-1]) . "'";
    }
    $sql = qq!
select
  n.go_id,
  n.go_name,
  n.go_class
from
  $CGAP_SCHEMA.go_name n
where
      n.go_id in ($list)
    !;

    $stm = $db->prepare($sql);
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</certer>";
      $db->disconnect();
      return "";
    }
    if (!$stm->execute()) {
      print "Execute failed\n";
      $db->disconnect();
      return;
    }
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($go_id, $go_name, $go_class) = @{ $row };
        $$go2name{$go_id} = $go_name;
        $$go2class{$go_id} = $go_class;
      }
    }
  }
}

######################################################################
sub GetGOAnnotations {
  my ($db, $org, $cids, $go2cid) = @_;

  my ($list, $i, $sql, $stm);
  my ($go_id, $cid);
  my ($rowcache, $row);

  for($i = 0; $i < @{ $cids }; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @{ $cids }) {
      $list = join(",", @{ $cids }[$i..$i+ORACLE_LIST_LIMIT-1]);
    }
    else {
      $list = join(",", @{ $cids }[$i..@{ $cids } - 1]);
    }
    $sql = qq!
select
  a.go_ancestor_id,
  u.cluster_number
from
  $CGAP_SCHEMA.ll_go l,
  $CGAP_SCHEMA.gene2unigene u,
  $CGAP_SCHEMA.go_ancestor a
where
      l.ll_id = u.gene_id
  and a.go_id = l.go_id
  and u.cluster_number in ($list)
  and u.organism = '$org'
    !;

    $stm = $db->prepare($sql);
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</certer>";
      $db->disconnect();
      return "";
    }
    if (!$stm->execute()) {
      print "Execute failed\n";
      $db->disconnect();
      return;
    }
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($go_id, $cid) = @{ $row };
        $$go2cid{$go_id}{$cid} = 1;
      }
    }
  }
}

######################################################################
1;







