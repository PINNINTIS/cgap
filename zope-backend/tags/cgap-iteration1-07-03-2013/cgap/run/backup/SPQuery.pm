#!/usr/local/bin/perl

use strict;
use DBI;

my ($$$DB_INSTANCE, $DB_USER, $DB_PASS, $DB_SCHEMA) = 
    ("cgprod", "web", "readonly", "cgap");
#    ("lpgprod", "web", "readonly", "cgap");

if (-d "/app/oracle/product/dbhome/current") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/dbhome/current";
} elsif (-d "/app/oracle/product/8.1.7") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.7";
} elsif (-d "/app/oracle/product/8.1.6") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.6";
}

use constant ORACLE_LIST_LIMIT => 500;
use constant MAX_ROWS_PER_FETCH => 1000;

my $db = DBI->connect("DBI:Oracle:" . $$$DB_INSTANCE, $DB_USER, $DB_PASS);
if (not $db or $db->err()) {
  print STDERR "Cannot connect to " . $DB_USER . "@" . $$$DB_INSTANCE . "\n";
  exit;
}

#my @sps = ('P35227','O00109','O08527');
#my @lls = (10170,200014,20005);
#my @other = ('AAB51172','NP_001366','UniRef90_O00115');

#print "## LL2Acc\n";
#print join("\n", @{ LL2Acc(\@lls) }) . "\n";

#print "## LL2GO\n";
#print join("\n", @{ LL2GO(\@lls) }) . "\n";

#print "## SP2Xrefs\n";
#print join("\n", @{ SP2Xrefs(\@sps) }) . "\n";

#print "## Xrefs2SP\n";
#print join("\n", @{ Xrefs2SP(\@other) }) . "\n";

#print "## SPInfo\n";
#print join("\n", @{ SPInfo(\@sps) }) . "\n";

#print "## SP2GO\n";
#print join("\n", @{ SP2GO(\@sps) }) . "\n";

#print "## LL2SP\n";
#print join("\n", @{ LL2SP(\@lls) }) . "\n";

#print "## SP2LL\n";
#print join("\n", @{ SP2LL(\@sps) }) . "\n";

######################################################################
sub LL2Acc {
  my ($lls) = @_;


  my ($sql, $stm);
  my ($ll_id, $org, $acc, $type);
  my (%ll2acc, %hits);

  my %tmp;
  for my $a (@{ $lls }) {
    $tmp{$a} = 1;
  }
  my @lls = keys %tmp;
  my ($i, $list);


  for($i = 0; $i < @lls; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @lls) {
      $list = "'" . join("','", @lls[$i..$i+ORACLE_LIST_LIMIT-1]) .
          "'";
    } else {
      $list = "'" . join("','", @lls[$i..@lls-1]) . "'";
    }

    $sql = qq!
select
  l.ll_id,
  l.organism,
  l.accession,
  l.accession_type
from
  $DB_SCHEMA.ll2acc l
where
      l.ll_id in ($list)
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      return undef;
    }
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      return undef;
    }
    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($ll_id, $org, $acc, $type) = @{ $row };
        $hits{$type}{$acc} = 1;
        $ll2acc{$ll_id}{$acc} = $type;
      }
    }
  }

  ##
  ## Get mrna/prot pair where PROT is associated with LL
  ##

  my ($mrna, $prot, %mrna2prot, %prot2mrna);

  my @m_accs = keys %{ $hits{"m"} };
  for($i = 0; $i < @m_accs; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @m_accs) {
      $list = "'" . join("','", @m_accs[$i..$i+ORACLE_LIST_LIMIT-1]) .
          "'";
    } else {
      $list = "'" . join("','", @m_accs[$i..@m_accs-1]) . "'";
    }

    $sql = qq!
select
  x.mrna_accession,
  x.protein_accession
from
  $DB_SCHEMA.mrna2prot x
where
      x.mrna_accession in ($list)
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      return undef;
    }
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      return undef;
    }
    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($mrna, $prot) = @{ $row };
        $mrna2prot{$mrna}{$prot} = 1;
        $prot2mrna{$prot}{$mrna} = 1;
      }
    }
  }

  ##
  ## Get mrna/prot pair where PROT is associated with LL
  ##

  my @p_accs = keys %{ $hits{"p"} };
  for($i = 0; $i < @p_accs; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @p_accs) {
      $list = "'" . join("','", @p_accs[$i..$i+ORACLE_LIST_LIMIT-1]) .
          "'";
    } else {
      $list = "'" . join("','", @p_accs[$i..@p_accs-1]) . "'";
    }

    $sql = qq!
select
  x.mrna_accession,
  x.protein_accession
from
  $DB_SCHEMA.mrna2prot x
where
      x.protein_accession in ($list)
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      return undef;
    }
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      return undef;
    }
    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($mrna, $prot) = @{ $row };
        $mrna2prot{$mrna}{$prot} = 1;
        $prot2mrna{$prot}{$mrna} = 1;
      }
    }
  }

  ##
  ## Put it together
  ##

  my (@order);

  for $ll_id (keys %ll2acc) {
    for $acc (keys %{ $ll2acc{$ll_id} }) {
      $type = $ll2acc{$ll_id}{$acc};
      $ll2acc{$ll_id}{$acc} = "";      ## we've done this accession
      if ($type eq "m") {
        ($mrna, $prot) = ($acc, "");
        if (defined $mrna2prot{$mrna}) {
	  for $prot (keys %{ $mrna2prot{$mrna} }) {
            push @order, "$ll_id\t$mrna\t$prot";
            if (defined $ll2acc{$ll_id}{$prot}){
              $ll2acc{$ll_id}{$prot} = "";
	    }
	  }
        } else {
          push @order, "$ll_id\t$mrna\t$prot";
        }
      } elsif ($type eq "p") {
        ($mrna, $prot) = ("", $acc);
        if (defined $prot2mrna{$prot}) {
          for $mrna (keys %{ $prot2mrna{$prot} }) {
            push @order, "$ll_id\t$mrna\t$prot";
            if (defined $ll2acc{$ll_id}{$mrna}){
              $ll2acc{$ll_id}{$mrna} = "";
            }
          }
        } else {
          push @order, "$ll_id\t$mrna\t$prot";
        }
      } else {
        next;
      }
    }
  }

  if (@order) {
    unshift @order, join("\t", 
        "LocusLink",
        "mRNA Accession",
        "Protein Accession"
      );
  } else {
    unshift @order, "No data found";
  }
  return \@order;

}

######################################################################
sub LL2UG_Organism {
  my ($list, $org, $table, $ll2ug) = @_;

  my ($sql, $stm);
  my ($ll_id, $cid);

  $sql = qq!
select
  c.locuslink,
  c.cluster_number
from
  $DB_SCHEMA.$table c
where
      c.locuslink in ($list)
  !;

  $stm = $db->prepare($sql);
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    return undef;
  }
  if(!$stm->execute()) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    return undef;
  }
  my ($row, $rowcache);
  while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
    for $row (@{ $rowcache }) {
      ($ll_id, $cid) = @{ $row };
      $$ll2ug{$ll_id} = "$org.$cid";
    }
  }

}

######################################################################
sub LL2UG {
  my ($lls, $ll2ug) = @_;

  my ($sql, $stm);

  my %tmp;
  for my $a (@{ $lls }) {
    $tmp{$a} = 1;
  }
  my @lls = keys %tmp;
  my ($i, $list);
  my %results;

  for($i = 0; $i < @lls; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @lls) {
      $list = "'" . join("','", @lls[$i..$i+ORACLE_LIST_LIMIT-1]) .
          "'";
    } else {
      $list = "'" . join("','", @lls[$i..@lls-1]) . "'";
    }
    LL2UG_Organism($list, "Hs", "hs_cluster", $ll2ug);
    LL2UG_Organism($list, "Mm", "mm_cluster", $ll2ug);
  }
}

######################################################################
sub SP2LL {
  my ($accs) = @_;

  my ($sql, $stm);
  my ($sp_ac, $sp_primary, $ll_id, $org, $gene);
  my (@ll_hits, %ll2ug);

  my %tmp;
  for my $a (@{ $accs }) {
    $tmp{$a} = 1;
  }
  my @accs = keys %tmp;
  my ($i, $list);
  my %results;

  for($i = 0; $i < @accs; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @accs) {
      $list = "'" . join("','", @accs[$i..$i+ORACLE_LIST_LIMIT-1]) .
          "'";
    } else {
      $list = "'" . join("','", @accs[$i..@accs-1]) . "'";
    }

    $sql = qq!
select
  p.sp_id_or_secondary,
  l.sp_primary,
  l.ll_id,
  l.organism,
  g.symbol
from
  $DB_SCHEMA.sp_primary p,
  $DB_SCHEMA.ll2sp l,
  $DB_SCHEMA.ll_gene g
where
      p.sp_id_or_secondary in ($list)
  and p.sp_primary = l.sp_primary
  and g.ll_id = l.ll_id
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      return undef;
    }
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      return undef;
    }
    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($sp_ac, $sp_primary, $ll_id, $org, $gene) = @{ $row };
        push @{ $results{$sp_ac} }, join("\t",
            $sp_ac,
            $sp_primary,
            $ll_id,
            $org,
            $gene
          );
        push @ll_hits, $ll_id;
      }
    }
  }
  LL2UG(\@ll_hits, \%ll2ug);
  my (@order, $row);
  for my $a (@{ $accs } ) {
    if (defined $results{$a}) {
      for $row (@{ $results{$a} }) {
        ($sp_ac,
         $sp_primary,
         $ll_id,
         $org,
         $gene) = split(/\t/, $row);
        push @order, join("\t",
          $sp_ac,
          $sp_primary,
          $ll_id,
          $org,
          $gene,
          $ll2ug{$ll_id}
        );
      }
    }
  }
  if (@order) {
    unshift @order, join("\t", 
        "SP Accession",
        "SP Primary Accession",
        "LocusLink",
        "Organism",
        "Gene",
        "UniGene"
      );
  } else {
    unshift @order, "No data found";
  }
  return \@order;
}

######################################################################
sub SPInfo {
  my ($accs) = @_;
  my ($sql, $stm);
  my ($sp_ac, $sp_primary, $sp_id, $org, $gene, $desc);

  my %tmp;
  for my $a (@{ $accs }) {
    $tmp{$a} = 1;
  }
  my @accs = keys %tmp;
  my ($i, $list);
  my %results;

  for($i = 0; $i < @accs; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @accs) {
      $list = "'" . join("','", @accs[$i..$i+ORACLE_LIST_LIMIT-1]) .
          "'";
    } else {
      $list = "'" . join("','", @accs[$i..@accs-1]) . "'";
    }

    $sql = qq!
select
  p.sp_id_or_secondary,
  p.sp_primary,
  i.sp_id,
  i.organism,
  i.gene,
  i.description
from
  $DB_SCHEMA.sp_primary p,
  $DB_SCHEMA.sp_info i
where
      p.sp_id_or_secondary in ($list)
  and p.sp_primary = i.sp_primary
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      return undef;
    }
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      return undef;
    }
    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($sp_ac, $sp_primary, $sp_id, $org, $gene, $desc) = @{ $row };
        $results{$sp_ac} = join("\t",
            $sp_ac,
            $sp_primary,
            $sp_id,
            $org,
            $gene,
            $desc
          );
      }
    }
  }
  my @order;
  for my $a (@{ $accs } ) {
    if (defined $results{$a}) {
      push @order, $results{$a}
    }
  }
  if (@order) {
    unshift @order, join("\t", 
        "SP Accession",
        "SP Primary Accession",
        "SP ID",
        "Organism",
        "Gene",
        "Description"
      );
  } else {
    unshift @order, "No data found";
  }
  return \@order;
}

######################################################################
sub Xrefs2SP {
  my ($accs) = @_;

  my ($sql, $stm);
  my ($sp_primary, $sp_ac, $other, $other_type);
  my %tmp;
  for my $a (@{ $accs }) {
    $tmp{$a} = 1;
  }
  my @accs = keys %tmp;
  my ($i, $list);
  my (%results, %sp2primary);

  for($i = 0; $i < @accs; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @accs) {
      $list = "'" . join("','", @accs[$i..$i+ORACLE_LIST_LIMIT-1]) .
          "'";
    } else {
      $list = "'" . join("','", @accs[$i..@accs-1]) . "'";
    }

    $sql = qq!
select
  p.sp_primary,
  p.sp_id_or_secondary,
  upper(o.other_accession),
  o.other_type
from
  $DB_SCHEMA.sp_primary p,
  $DB_SCHEMA.sp2other o
where
      o.sp_accession = p.sp_id_or_secondary
  and upper(o.other_accession) in ($list)
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      return undef;
    }
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      return undef;
    }
    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($sp_primary, $sp_ac, $other, $other_type) = @{ $row };
        $sp2primary{$sp_ac} = $sp_primary;
        $results{$other}{$other_type}{$sp_ac} = 1;
      }
    }
  }

  my (@order, $line);
  for $other (@{ $accs } ) {
    if (defined $results{$other}) {
      for $other_type (keys %{ $results{$other} }) {
        for $sp_ac (keys %{ $results{$other}{$other_type} }) {
          push @order, "$other\t$other_type\t$sp_ac\t$sp2primary{$sp_ac}";
        }
      }
    }
  }
  if (@order) {
    unshift @order, join("\t", 
        "Other Accession",
        "Other Accession Type",
        "SP Accession",
        "SP Primary Accession"
      );
  } else {
    unshift @order, "No data found";
  }
  return \@order;
  
}

######################################################################
sub SP2Xrefs {
  my ($accs) = @_;

  my ($sql, $stm);
  my ($sp_ac, $sp_primary, $other, $other_type);
  my %tmp;
  for my $a (@{ $accs }) {
    $tmp{$a} = 1;
  }
  my @accs = keys %tmp;
  my ($i, $list);
  my (%results, %sp2primary);

  for($i = 0; $i < @accs; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @accs) {
      $list = "'" . join("','", @accs[$i..$i+ORACLE_LIST_LIMIT-1]) .
          "'";
    } else {
      $list = "'" . join("','", @accs[$i..@accs-1]) . "'";
    }

    $sql = qq!
select unique
  p1.sp_id_or_secondary,
  p1.sp_primary,
  o.other_accession,
  o.other_type
from
  $DB_SCHEMA.sp_primary p1,
  $DB_SCHEMA.sp_primary p2,
  $DB_SCHEMA.sp2other o
where
      o.sp_accession = p2.sp_id_or_secondary
  and p2.sp_primary = p1.sp_primary
  and p1.sp_id_or_secondary in ($list)
    !;
    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      return undef;
    }
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      return undef;
    }
    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($sp_ac, $sp_primary, $other, $other_type) = @{ $row };
        $sp2primary{$sp_ac} = $sp_primary;
        $results{$sp_ac}{$other_type}{$other} = 1;
      }
    }
  }
  my (@order, $line);
  for $sp_ac (@{ $accs } ) {
    if (defined $results{$sp_ac}) {
      $line = "$sp_ac\t$sp2primary{$sp_ac}";
      for $other_type ("EM", "EP", "GP", "RF", "PI", "U9") {
        if (defined $results{$sp_ac}{$other_type}) {
         $line .= "\t" . join(";", sort
              keys %{ $results{$sp_ac}{$other_type} });
        } else {
          $line .= "\t";
        }
      }
      push @order, $line;
    }
  }
  if (@order) {
    unshift @order, join("\t", 
        "SP Accession",
        "SP Primary Accession",
        "EMBL mRNA",
        "EMBL protein",
        "GenPept",
        "RefSeq",
        "PIR",
        "UniRef90"
      );
  } else {
    unshift @order, "No data found";
  }
  return \@order;
  
}

######################################################################
sub SP2GO {
  my ($accs, $go_categories) = @_;

  # go_ids is ref to hash containing go_ids to be used
  # in summary-level reporting

  my %ancestors;
  if ((defined $go_categories) && (keys %{ $go_categories } > 0)) {
    GetAncestors($go_categories, \%ancestors)
  }

  my ($sql, $stm);
  my ($query_acc, $sp_ac, $evid, $go_name, $go_id, $go_name, $go_class);
  my (%go2name, %go2class, %results);
  my %tmp;
  for my $a (@{ $accs }) {
    $tmp{$a} = 1;
  }
  my @accs = keys %tmp;
  my ($i, $list);
  my (%sp2id, %sp2secondary, %ll2sp);

  for($i = 0; $i < @accs; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @accs) {
      $list = "'" . join("','", @accs[$i..$i+ORACLE_LIST_LIMIT-1]) .
          "'";
    } else {
      $list = "'" . join("','", @accs[$i..@accs-1]) . "'";
    }

    $sql = qq!
select distinct
  p2.sp_id_or_secondary,
  s.sp_accession,
  s.evidence,
  g.go_id,
  g.go_name,
  g.go_class
from
  $DB_SCHEMA.sp2go s,
  $DB_SCHEMA.go_name g,
  $DB_SCHEMA.sp_primary p1,
  $DB_SCHEMA.sp_primary p2
where
      g.go_id = s.go_id
  and p2.sp_primary = p1.sp_primary
  and p1.sp_id_or_secondary = s.sp_accession
  and p2.sp_id_or_secondary in ($list)
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      return undef;
    }
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      return undef;
    }
    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($query_acc, $sp_ac, $evid, $go_id, $go_name, $go_class) = @{ $row };
        $go2name{$go_id} = $go_name;
        $go2class{$go_id} = $go_class;
        $results{$query_acc}{$sp_ac}{$evid}{$go_id} = 1;
      }
    }
  }
  my (@order, $line, %tally);
  for $query_acc (@{ $accs }) {
    if (defined $results{$query_acc}) {
      for $sp_ac (sort keys %{ $results{$query_acc} }) {
        for $evid (sort keys %{ $results{$query_acc}{$sp_ac} }) {
          for $go_id (sort keys %{ $results{$query_acc}{$sp_ac}{$evid} }) {
            if (defined $ancestors{$go_id}) {
              for my $a (keys %{ $ancestors{$go_id} }) {
                push @order, join("\t",
                  $query_acc,
                  $sp_ac,
                  $evid,
                  $go_id,
                  $go2name{$go_id},
                  $go2class{$go_id},
                  $a,
                  $ancestors{$go_id}{$a}
                );
              }
              $tally{"$a\t$ancestors{$go_id}{$a}"}{$query_acc} = 1;
            } else {
              push @order, join("\t",
                $query_acc,
                $sp_ac,
                $evid,
                $go_id,
                $go2name{$go_id},
                $go2class{$go_id},
                "",
                ""
              );
            }
          }
        }
      }
    }
  }
  for my $x (keys %tally) {
    my ($go_id, $go_name) = split("\t", $x);
    push @order, "#count\t$go_id\t$go_name\t" . scalar(keys %{ $tally{$x} });
  }
  if (@order) {
    if (defined $go_categories) {
      unshift @order, join("\t", 
          "Query Accession",
          "SP Primary",
          "Evidence",
          "GO ID",
          "GO Name",
          "GO Class",
          "Summary GO ID",
          "Summary GO Name"
        );
    } else {
      unshift @order, join("\t", 
          "Query Accession",
          "SP Primary",
          "Evidence",
          "GO ID",
          "GO Name",
          "GO Class"
        );
    }
  } else {
    unshift @order, "No data found";
  }
  return \@order;

}

######################################################################
sub LL2GO {
  my ($accs, $go_categories) = @_;

  # go_ids is ref to hash containing go_ids to be used
  # in summary-level reporting

  my %ancestors;
  if ((defined $go_categories) && (keys %{ $go_categories } > 0)) {
    GetAncestors($go_categories, \%ancestors)
  }

  my ($sql, $stm);
  my ($query_acc, $go_name, $go_id, $go_name, $go_class);
  my (%go2name, %go2class, %results);
  my %tmp;
  for my $a (@{ $accs }) {
    $tmp{$a} = 1;
  }
  my @accs = keys %tmp;
  my ($i, $list);

  for($i = 0; $i < @accs; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @accs) {
      $list = "'" . join("','", @accs[$i..$i+ORACLE_LIST_LIMIT-1]) .
          "'";
    } else {
      $list = "'" . join("','", @accs[$i..@accs-1]) . "'";
    }

    $sql = qq!
select distinct
  l.ll_id,
  g.go_id,
  g.go_name,
  g.go_class
from
  $DB_SCHEMA.go_name g,
  $DB_SCHEMA.ll_go l
where
      g.go_id = l.go_id
  and l.ll_id in ($list)
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      return undef;
    }
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      return undef;
    }
    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($query_acc, $go_id, $go_name, $go_class) = @{ $row };
        $go2name{$go_id} = $go_name;
        $go2class{$go_id} = $go_class;
        $results{$query_acc}{$go_id} = 1;
      }
    }
  }
  my (@order, $line, %tally);
  for $query_acc (@{ $accs }) {
    if (defined $results{$query_acc}) {
      for $go_id (sort keys %{ $results{$query_acc} }) {
        if (defined $ancestors{$go_id}) {
          for my $a (keys %{ $ancestors{$go_id} }) {
            push @order, join("\t",
              $query_acc,
              $go_id,
              $go2name{$go_id},
              $go2class{$go_id},
              $a,
              $ancestors{$go_id}{$a}
            );
            $tally{"$a\t$ancestors{$go_id}{$a}"}{$query_acc} = 1;
          }
        } else {
          push @order, join("\t",
            $query_acc,
            $go_id,
            $go2name{$go_id},
            $go2class{$go_id},
            "",
            ""
          );
        }
      }
    }
  }
  for my $x (keys %tally) {
    my ($go_id, $go_name) = split("\t", $x);
    push @order, "#count\t$go_id\t$go_name\t" . scalar(keys %{ $tally{$x} });
  }
  if (@order) {
    if (defined $go_categories) {
      unshift @order, join("\t", 
          "LocusLink",
          "GO ID",
          "GO Name",
          "GO Class",
          "Summary GO ID",
          "Summary GO Name"
        );
    } else {
      unshift @order, join("\t", 
          "LocusLink",
          "GO ID",
          "GO Name",
          "GO Class"
        );
    }
  } else {
    unshift @order, "No data found";
  }
  return \@order;

}

######################################################################
sub LL2SP {
  my ($lls) = @_;

  my ($sql, $stm);
  my ($ll_id, $org, $sp_primary, $sp_secondary, $type);
  my %tmp;
  for my $a (@{ $lls }) {
    $tmp{$a} = 1;
  }
  my @lls = keys %tmp;
  my ($i, $list);
  my (%sp2id, %sp2secondary, %ll2sp);

  for($i = 0; $i < @lls; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @lls) {
      $list = "'" . join("','", @lls[$i..$i+ORACLE_LIST_LIMIT-1]) .
          "'";
    } else {
      $list = "'" . join("','", @lls[$i..@lls-1]) . "'";
    }

    $sql = qq!
select
  l.ll_id,
  l.organism,
  l.sp_primary,
  p.sp_id_or_secondary,
  p.id_or_accession
from
  $DB_SCHEMA.ll2sp l,
  $DB_SCHEMA.sp_primary p
where
      l.sp_primary = p.sp_primary
  and l.ll_id in ($list)
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      return undef;
    }
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      return undef;
    }
    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($ll_id, $org, $sp_primary, $sp_secondary, $type) = @{ $row };
        if ($type eq "i") {
          $sp2id{$sp_primary} = $sp_secondary;
        } else {
          if ($sp_primary ne $sp_secondary) {
            $sp2secondary{$sp_primary}{$sp_secondary} = 1;
          }
        }
        $ll2sp{$ll_id}{$sp_primary} = $org;
      }
    }
  }
  my (@order, $line);
  for $ll_id (@{ $lls } ) {
    if (defined $ll2sp{$ll_id}) {
      for $sp_primary (keys %{ $ll2sp{$ll_id} }) {
        $line = join("\t",
            $ll_id,
            $ll2sp{$ll_id}{$sp_primary},
            $sp_primary,
            $sp2id{$sp_primary},
            join(";", keys %{ $sp2secondary{$sp_primary} })
        );
        push @order, $line;
      }
    }
  }
  if (@order) {
    unshift @order, join("\t", 
        "LocusLink",
        "Organism",
        "SP Primary Accession",
        "SP ID",
        "SP Alternate Accessions"
      );
  } else {
    unshift @order, "No data found";
  }
  return \@order
}

######################################################################
######################################################################
sub Summarize {
  my ($f, $column, $ancestor) = @_;

  my ($go_id, $go_num, $ancestor_id);

  open(INPF, $f) or die "cannot open $f";
    while (<INPF>) {
      chop;
      split /\t/;
      $go_id = $_[$column - 1];
      $go_num = $go_id;
      $go_num =~ s/^GO://;
      if (defined $$ancestor{$go_num}) {
        for $ancestor_id (keys %{ $$ancestor{$go_num}} ) {      
          print join("\t", @_[0..$column-2],
              "GO:$ancestor_id", $$ancestor{$go_num}{$ancestor_id},
              @_[$column-1..$#_]) . "\n";
        }
      } else {
        print join("\t", @_[0..$column-2],
            "", "",
            @_[$column-1..$#_]) . "\n";
      }

    }
  close INPF;
  
}

######################################################################
sub GetAncestors {
  my ($categories, $ancestor) = @_;

  my ($sql, $stm);
  my ($go_id, $go_ancestor_id, $go_name);

  $sql = qq!
select
  a.go_id,
  a.go_ancestor_id,
  n.go_name
from
  $DB_SCHEMA.go_ancestor a,
  $DB_SCHEMA.go_name n
where
  a.go_ancestor_id = n.go_id
  !;

  $stm = $db->prepare($sql);
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    exit();
  }
  if(!$stm->execute()) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    exit();
  }
  my ($row, $rowcache);
  while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
    for $row (@{ $rowcache }) {
      ($go_id, $go_ancestor_id, $go_name) = @{ $row };
      $go_id = FixGOId($go_id);
      $go_ancestor_id = FixGOId($go_ancestor_id);
      if (defined $$categories{$go_ancestor_id}) {
        $$ancestor{$go_id}{$go_ancestor_id} = $go_name;
      }
    }
  }
}

######################################################################
sub FixGOId {
  my ($x) = @_;

  while (length($x) < 7) {
    $x = "0$x";
  }
  return $x;
}


######################################################################
1;
