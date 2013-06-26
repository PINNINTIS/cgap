#!/usr/local/bin/perl

#############################################################################
# ProcessGeneBatchFile.pl
#

use strict;
use DBI;

use constant ITEMS_PER_PAGE    => 300;
use constant ROWS_PER_SUBTABLE => 100;
use Time::HiRes qw(usleep ualarm gettimeofday tv_interval);

BEGIN {
  push @INC, "/share/content/CGAP/run";
}

use  CGAPConfig;
use constant ORACLE_LIST_LIMIT  => 500;
use constant MAX_ROWS_PER_FETCH => 1000;
use constant MAX_LONG_LEN => 16384;
## use constant LIMIT_LENGTH => 5000;
use constant LIMIT_LENGTH => 0;
## use constant CACHE_ROOT => "/share/content/CGAP/data/cache";
use URI::Escape;
use FisherExact;

my $CLONE_PAGE     = 1000000;
 
my $BASE;
 
my (%cid2input, %input2cid);

opendir (DATADIR, CACHE_ROOT) or die "Can not open dir CACHE_ROOT \n";

while( my $filename = readdir(DATADIR) ) {
  if( $filename =~ /^GENE\.\d+\.input/ ) {
    my $file_1 = CACHE_ROOT . "/" . $filename;
    my $file_2 = CACHE_ROOT . "/" . "tmp_" . $filename;
    my $cmd = "mv $file_1 $file_2";
    system($cmd);
    
    my ($base, $page, $org, $filename, $flag);
    $flag = 1;
    GetBatchGenes_1($base, $page, $org, $file_2, $flag);
    my $cmd = "unlink $file_2";
    system($cmd);
  }
  else {
    next;
  }
}
closedir (DATADIR);

######################################################################
sub GetBatchGenes_1 {
  my ($base, $page, $organism, $filedata, $flag ) = @_;
 
  $BASE = $base;
 
  my ($org, $cid);
  my (@rows, @accs, @lls, %cids, @ug_sp_accs, @prot_accs, @syms,, %syms);
  my ($acc_list, $ll_list, $a, $l);
  my ($sql, $stm, $type, $gene, $cids);
  my $cache_id;
  my %goodInput;
  my @garbage;
  my (%official, %preferred, %alias, $wild, @symbols);
  my @tempArray;
  my $total_input;
  my $cmd;
 
  open ( IN, $filedata ) or die "Can not open $filedata \n";
  my $count = 0;
  while (<IN>) {
    chop;
    if( $count == 0 ) {
      ($page, $organism, $cache_id) = split "\t", $_;
    }
    else {
      push @tempArray, $_;
    }
    $count++;
  }
 
  my $cluster_table = ($organism eq "Hs") ? "hs_cluster" : "mm_cluster";
  my $ug_sequence = ($organism eq "Hs") ? "hs_ug_sequence" : "mm_ug_sequence";
 
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    return "";
  }
 
  my $t0 = [gettimeofday];
  for (my $t = 0; $t < @tempArray; $t++ ) {
    $tempArray[$t] =~  s/\s//g;
    next if ($tempArray[$t] eq "");
    next if ($tempArray[$t] =~ /\*/);
    if ($tempArray[$t] =~ /(hs|mm)\.(\d+)/i) { # cluster
      ($org, $cid) = ($1, $2);
      next if (lc($organism) ne lc($org));
 
      $sql = "select distinct cluster_number, GENE from " .
             "$CGAP_SCHEMA.$cluster_table " .
             "where cluster_number = $cid";
 
      $stm = $db->prepare($sql);
      if (not $stm) {
        print STDERR "prepare call failed\n";
        return "";
      } else {
        if ($stm->execute()) {
          $stm->bind_columns(\$cid, \$gene);
          if ($stm->fetch) {
            if (not $cids{$cid}) {
              push @rows, $cid;
            }
            $cid2input{$cid} = $tempArray[$t];
            $input2cid{$tempArray[$t]} = $cid;
            $goodInput{$tempArray[$t]} = 1;
            $cids{$cid} = 1;
          }
          $stm->finish();
        } else {
          print STDERR "execute failed\n";
          return "";
        }
      }
    } elsif ($tempArray[$t] =~ /^\d+$/) { # locuslink
      push @lls, $tempArray[$t];
    } else { # accession symbol
      $tempArray[$t] =~ s/ //g;
      $tempArray[$t] =~ tr/a-z/A-Z/;
      my $tmp_value = convrtSingleToDoubleQuote($tempArray[$t]);
      push @syms, "'$tmp_value'";
      $syms{$tempArray[$t]} = 1;
      if( ($tempArray[$t] =~ /^NP_/) or ($tempArray[$t] =~ /^XP_/) ) {
        push @prot_accs, "'$tmp_value'";
      }
      else {
        push @ug_sp_accs, "'$tmp_value'";
      }
    }
  }
  my $elapsed = tv_interval ($t0, [gettimeofday]);
  print "8888 in processing tempArray: $elapsed\n";
   
  if (@ug_sp_accs) {
    for ($a = 0; $a < @ug_sp_accs; $a += ORACLE_LIST_LIMIT) {
      if (($a + ORACLE_LIST_LIMIT - 1) < @ug_sp_accs) {
        $acc_list = join(",", @ug_sp_accs[$a..$a+ORACLE_LIST_LIMIT-1]);
      } else {
        $acc_list = join(",", @ug_sp_accs[$a..$#ug_sp_accs]);
      }
 
      ## doing ug acc
      $sql = "select distinct cluster_number, accession from " .
             "$CGAP_SCHEMA.$ug_sequence " .
             "where accession in (" . $acc_list . ") ";
 
      $stm = $db->prepare($sql);
      if (not $stm) {
        print STDERR "prepare call failed\n";
        return "";
      } else {
        my $t0 = [gettimeofday];
        if ($stm->execute()) {
          my $accession;
          $stm->bind_columns(\$cid, \$accession);
          while ($stm->fetch) {
            if (not $cids{$cid}) {
              push @rows, $cid;
            }
            $cid2input{$cid} = $accession;
            $input2cid{$accession} = $cid;
            $goodInput{$accession} = 1;
            $cids{$cid} = 1;
          }
          my $elapsed = tv_interval ($t0, [gettimeofday]);
          print "8888 in ug_sequence: $elapsed\n";
        } else {
          print STDERR "execute failed\n";
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
      my $t0 = [gettimeofday];
      if ($stm->execute()) {
        while ( my($cid, $sp_id_or_secondary) = $stm->fetchrow_array()) {
          if (not $cids{$cid}) {
            push @rows, $cid;
          }
          $cid2input{$cid} = $sp_id_or_secondary;
          $input2cid{$sp_id_or_secondary}= $cid;
          $goodInput{$sp_id_or_secondary} = 1;
          $cids{$cid} = 1;
        }
        my $elapsed = tv_interval ($t0, [gettimeofday]);
        print "8888 in sp_primary: $elapsed\n";
      } else {
        print STDERR "$sql\n";
        print STDERR "execute call failed\n";
        return "";
      }
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
        print STDERR "prepare call failed\n";
        return "";
      } else {
        my $t0 = [gettimeofday];
        if ($stm->execute()) {
          my $accession;
          my $protein_accession;
          $stm->bind_columns(\$cid, \$accession, \$protein_accession);
          while ($stm->fetch) {
            if (not $cids{$cid}) {
              push @rows, $cid;
            }
            $cid2input{$cid} = $protein_accession;
            $input2cid{$protein_accession} = $cid;
            $goodInput{$protein_accession} = 1;
            $cids{$cid} = 1;
          }
          my $elapsed = tv_interval ($t0, [gettimeofday]);
          print "8888 in MRNA2PROT: $elapsed\n";
        } else {
          print STDERR "execute failed\n";
          return "";
        }
      }
    }
  }
 
  if (@syms) {
    my $alias_table = $organism eq "Hs" ? "hs_gene_alias" : "mm_gene_alias";
    $sql =
       "select cluster_number, gene_uc, type " .
       "from $CGAP_SCHEMA.$alias_table "; 
 
    $stm = $db->prepare($sql);
    my $t0 = [gettimeofday];
    if ($stm->execute()) {
      while (($cid, $gene, $type) = $stm->fetchrow_array()) {
        if( defined $syms{$gene} ) {  
          if ($type eq 'OF') {
            $official{$gene}{$cid} = 1;
          } elsif ($type eq 'PF') {
            $preferred{$gene}{$cid} = 1;
          } elsif ($type eq 'AL') {
            $alias{$gene}{$cid} = 1;
          }
        }
      }
      my $elapsed = tv_interval ($t0, [gettimeofday]);
      print "8888 in alias_table: $elapsed\n";
      while (($gene, $cids) = each(%official)) {
        while ($cid = each(%$cids)) {
          if (not $cids{$cid}) {
            push @rows, $cid;
          }
          $cid2input{$cid} = $gene;
          $input2cid{$gene} = $cid;
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
          $input2cid{$gene} = $cid;
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
          $input2cid{$gene} = $cid;
          $goodInput{$gene} = 1;
          $cids{$cid} = 1;
        }
      }
      undef %official;
      undef %preferred;
      undef %alias;
    } else {
      print STDERR "$sql\n";
      print STDERR "execute call failed\n";
      return "";
    }
  }
 
  if (@lls) {
    for ($l = 0; $l < @lls; $l += ORACLE_LIST_LIMIT) {
      if (($l + ORACLE_LIST_LIMIT - 1) < @lls) {
        $ll_list = join(",", @lls[$l..$l+ORACLE_LIST_LIMIT-1]);
      } else {
        $ll_list = join(",", @lls[$l..$#lls]);
      }
 
      $sql = "select distinct cluster_number, locuslink " .
             "from $CGAP_SCHEMA.$cluster_table " .
             "where locuslink in (" .  $ll_list . ")";
 
      $stm = $db->prepare($sql);
      if (not $stm) {
        print STDERR "prepare call failed\n";
        return "";
      } else {
        my $locuslink;
        my $t0 = [gettimeofday];
        if ($stm->execute()) {
          $stm->bind_columns(\$cid, \$locuslink);
          while ($stm->fetch) {
            if (not $cids{$cid}) {
              push @rows, $cid;
            }
            $cid2input{$cid} = $locuslink;
            $input2cid{$locuslink} = $cid;
            $goodInput{$locuslink} = 1;
            $cids{$cid} = 1;
          }
          my $elapsed = tv_interval ($t0, [gettimeofday]);
          print "8888 in cluster_table: $elapsed\n";
        } else {
          print STDERR "execute failed\n";
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
      else {
        push @garbage, $tempArray[$t];
      }
    }
  }
 
  my $ordered_ref = OrderGenesByInput($page, $organism, \@rows, \@tempArray);
 
  my $all_cids = join ",", @rows;
  my $chrom_pos = GetChromPosList_1 ($page, $org, $all_cids);

  my $go_info = SummarizeGOForGeneSet_1 ($base, $org, \@rows);

  my $data = join ("\n", @{$ordered_ref}) . "\n";
  $data = $data . "//GARBAGE" . "\n";
  $data = $data . join ("\n", @garbage) . "\n";
  $data = $data . "//ROWS" . "\n";
  $data = $data . join ("\n", @rows) . "\n";
  $data = $data . "//CHROM_POS" . "\n";
  $data = $data . $chrom_pos;
  $data = $data . "//GO_INFO" . "\n";
  $data = $data . $go_info;
  my $gene_cache_id = WriteGeneToCache($cache_id, $data);
  if( ! $gene_cache_id ) {
    return "Cache failed<br>";
  }
}


######################################################################
sub OrderGenesByInput {
 
  my ($page, $org, $refer, $input_ref) = @_;
 
  my @ordered_genes;
  my @tempArray;
  my $sql_lines;
  my ($sql, $stm);
  my $key;
  my ($list, $cid, $gene);
  my %cid2info;
  my $total = @{$refer};
  my ($cluster_number, $symbol, $title, $loc, $gb);
 
  my $table_name =
      ($org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster" : "$CGAP_SCHEMA.mm_cluster");
 
  if( @{ $refer } ) {
 
    my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
    if (not $db or $db->err()) {
      print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
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
        print STDERR "$sql\n";
        print STDERR "$DBI::errstr\n";
        print STDERR "prepare call failed\n";
        return undef;
      }
      else {
        my $t0 = [gettimeofday];  
        if(!$stm->execute()) {
          print STDERR "$sql\n";
          print STDERR "$DBI::errstr\n";
          print STDERR "execute call failed\n";
          return undef;
        }
        $stm->bind_columns(\$cluster_number, \$symbol, \$title, \$loc, \$gb);
        while($stm->fetch) {
          $cid2info{$cluster_number} =
             "$cluster_number\001$symbol\001$title\001$loc\001$gb";
        }
        my $elapsed = tv_interval ($t0, [gettimeofday]);
        print "8888 in cluster: $elapsed\n";
      }
    }
  }
 
  for ( my $i=0; $i<@{$input_ref}; $i++ ) {
    if ( defined $cid2info{ $input2cid{$$input_ref[$i]} } ) {
      push @ordered_genes, $$input_ref[$i] . "\001" .
                    $cid2info{ $input2cid{$$input_ref[$i]} };
    }
  }
 
  return \@ordered_genes;
 
}

######################################################################
 
sub WriteGeneToCache {
  my ($cache_id, $data) = @_;
 
  my $fname = CACHE_ROOT . "/" . GENE_CACHE_PREFIX . "." . $cache_id;
  if (open(OUT, ">$fname")) {
    print OUT $data;
    close OUT;
    chmod 0666, $fname;
  } else {
    $cache_id = 0;
  }
  return $cache_id;
 
}

######################################################################
sub convrtSingleToDoubleQuote {
  my ($temp) = @_;
 
  $temp =~ s/'/''/g;
 
  return $temp
}
 
######################################################################

sub GetChromPosList_1 {
  my ($page, $org, $cids) = @_;
 
  my ($organism, $cluster_number, $accession);
  my ($chrom, $chrom_from, $chrom_to, $locuslink, $gene);
  my (@rows, @cids, @scid, $cid_list, $c);
 
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
      print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
      return "";
  }
 
  push @rows, "Org\tCluster\tAccession\tLocusLink\tGene\tChrom: from - to";
 
  my $cluster_table =
      ($org eq "Hs") ? "$CGAP_SCHEMA.hs_cluster"
                     : "$CGAP_SCHEMA.mm_cluster";
 
  @cids = split ",", $cids;
  @scid = sort numerically @cids;
 
  if (@scid) {
    for ($c = 0; $c < @scid; $c += ORACLE_LIST_LIMIT) {
      if (($c + ORACLE_LIST_LIMIT - 1) < @scid) {
        $cid_list = "'" . join("','", @scid[$c..$c+ORACLE_LIST_LIMIT-1]) . "'";
      } else {
        $cid_list = "'" . join("','", @scid[$c..$#scid]) . "'";
      }
 
      my $sql =
        "select u.organism, u.cluster_number, u.accession, " .
        "       u.chromosome, u.chr_start, u.chr_end, " .
        "       c.locuslink, c.gene " .
        "from $CGAP_SCHEMA.ucsc_mrna u, $cluster_table c " .
        "where c.cluster_number in ($cid_list) " .
        "and u.organism = '$org' " .
        "and u.cluster_number = c.cluster_number " .
        "order by c.cluster_number " ;

        ## "where u.cluster_number in ($cid_list) " .
        ## "and u.organism = '$org' " .
        ## "and u.cluster_number = c.cluster_number " .
        ## "order by u.cluster_number " ;
 
 
      my $stm = $db->prepare($sql);
 
      if (not $stm) {
        print STDERR "prepare call failed\n";
        return "";
      }
 
      my $t0 = [gettimeofday];
      if (!$stm->execute()) {
        print STDERR "execute failed\n";
        return "";
      }
 
      $stm->bind_columns(\$organism, \$cluster_number, \$accession,
                         \$chrom, \$chrom_from, \$chrom_to,
                         \$locuslink, \$gene);
 
      while ($stm->fetch) {
        push @rows, "$organism\t$cluster_number\t$accession\t" .
                    "$locuslink\t$gene\t" .
                    "$chrom: $chrom_from - $chrom_to";
      }
      my $elapsed = tv_interval ($t0, [gettimeofday]);
      print "8888 in ucsc_mrna: $elapsed\n";
    }
  }
 
  $db->disconnect();
 
  return join ("\n", @rows) . "\n";
}

######################################################################
sub numerically   { $a <=> $b; }
sub r_numerically { $b <=> $a; }

######################################################################

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

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print STDERR "$DBI::errstr\n";
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
      if (defined $cache{"$a,$b,$A,$B"}) {
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
      push @{ $temp{$go2class{$go_id}} },
          join("\t", $go2class{$go_id}, "GO:$go_id", $go2name{$go_id},
          $a . "/" . $A, $b . "/" . $B, $P);
    }
  }
  if (defined %temp) {
    push @lines, join("\t", "Class", "GO Id", "GO Term",
        "Hits in list", "All annotated genes", "Fisher Exact");
    for my $c ("BP", "MF", "CC") {
      if (defined $temp{$c}) {
        push @lines, @{ $temp{$c} };
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
    print STDERR "prepare call failed\n";
    return;
  }
  if (!$stm->execute()) {
    print STDERR "Execute failed\n";
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
      print STDERR "prepare call failed\n";
      return;
    }
    if (!$stm->execute()) {
      print STDERR "Execute failed\n";
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
      print STDERR "prepare call failed\n";
      return;
    }
    if (!$stm->execute()) {
      print STDERR "Execute failed\n";
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
  and u.organism = '$org'
  and u.cluster_number in ($list)
    !;

    $stm = $db->prepare($sql);
    if (not $stm) {
      print STDERR "prepare call failed\n";
      return;
    }
    my $t0 = [gettimeofday];
    if (!$stm->execute()) {
      print STDERR "Execute failed\n";
      return;
    }
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($go_id, $cid) = @{ $row };
        $$go2cid{$go_id}{$cid} = 1;
      }
    }
    my $elapsed = tv_interval ($t0, [gettimeofday]);
    print "8888 in gene2unigene: $elapsed\n";
  }
}

######################################################################
1;









