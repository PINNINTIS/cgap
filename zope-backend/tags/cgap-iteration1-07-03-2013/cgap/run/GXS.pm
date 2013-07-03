#!/usr/local/bin/perl

######################################################################
# GXS.pm
#
######################################################################

use strict;
use FileHandle;
use CGAPConfig;
use Paging;
use ServerSupport;
use DBI;
use Bayesian;
use Bayesian_no_C_lib;
use Cache;
use Sys::Hostname;
use Scan_Server;
use FisherExact;

# constant determining whether to use Oracle or flat file
# as data source
use constant MANY_SAGE_LIBRARIES => 0;
## use constant MANY_SAGE_LIBRARIES => 20;

my $cache;
use constant GXS_ROWS_PER_PAGE => 300;
use constant GXS_ROWS_PER_SUBTABLE => 100;
use constant ORACLE_LIST_LIMIT => 500;
## use constant ORACLE_LIST_LIMIT => 350;
use constant MITO_ACC => "X93334";

my $HELP_DESK_EMAIL = "wuko\@mail.nih.gov";

my %org_method_2_protocol;
$org_method_2_protocol{"Hs"} = {
  "SS10"  =>  "A",
  "LS10"  =>  "B",
  "LS17"  =>  "C",
  "LS21"  =>  "D",
  "LS26"  =>  "E"
};
$org_method_2_protocol{"Mm"} = {
  "SS10"  =>  "K",
  "LS10"  =>  "L",
  "LS17"  =>  "M",
  "LS21"  =>  "N",
  "LS26"  =>  "O"
};

InitializeDatabase();

######################################################################
sub InitializeDatabase {
  $cache = new Cache(CACHE_ROOT, GXS_CACHE_PREFIX);
}


######################################################################
## GXS variables

my (%setA, %setB, %seqA, %seqB, %libA, %libB, %tallied_clus);

######################################################################
sub Init {
  undef %setA;
  undef %setB;
  undef %seqA;
  undef %seqB;
  undef %libA;
  undef %libB;
  undef %tallied_clus;
}

######################################################################
sub MayBeDifferent {
  my ($factor, $a, $b, $A, $B) = @_;

  my ($big, $small, $a_ratio, $b_ratio);
  $a_ratio = $a/$A;
  $b_ratio = $b/$B;

  if ($a_ratio == $b_ratio) {
    return 0;
  } elsif ($factor == 1) {
    return 1;
  } else {
    if ($a_ratio > $b_ratio) {
      $big   = $a_ratio;
      $small = $b_ratio;
    } else {
      $big   = $b_ratio;
      $small = $a_ratio;
    }
    if ($big > $factor * $small) {
      return 1;
    } else {
      return 0;
    }
  }
}

######################################################################
sub OddsRatio {
  my ($G_A, $G_B, $TotalA, $TotalB) = @_;
  ## G_A: number of ESTs in Set A that hit gene G
  ## TotalA: number of ESTs in Set A
  ## BarG_A: number of ESTS in Set A that do not hit gene G

  my $BarG_A = $TotalA - $G_A;
  my $BarG_B = $TotalB - $G_B;

  if ($G_A == 0) {
    return 0;
  } elsif ($G_B == 0) {
    return "NaN";
  } else {
    return sprintf("%.2f", ($G_A * $BarG_B) / ($G_B * $BarG_A));
  }
  
}

######################################################################
sub numerically { $a <=> $b };
sub r_numerically { $b <=> $a };


######################################################################
# EST GXS specific
######################################################################

######################################################################
sub ReadClusterData {
  my ($org) = @_;
  my ($total_seqsA, $total_seqsB, $total_libsA, $total_libsB);

  my ($clu, $lid, $num_seqs);

  if ($org eq "Hs") {
    open (CLUF, HS_GXS_DATA)  or die "Cannot open " . HS_GXS_DATA;
  } else {
    open (CLUF, MM_GXS_DATA)  or die "Cannot open " . MM_GXS_DATA;
  }

  while (<CLUF>) {
    chop;
    ($clu, $lid, $num_seqs) = split "\t";
    if (defined $setA{$lid}) {
      $tallied_clus{$clu} = 1;
      $seqA{$clu} += $num_seqs;
      $libA{$clu}++;
      $total_seqsA += $num_seqs;
      $total_libsA++;
    }
    if (defined $setB{$lid}) {
      $tallied_clus{$clu} = 1;
      $seqB{$clu} += $num_seqs;
      $libB{$clu}++;
      $total_seqsB += $num_seqs;
      $total_libsB++;
    }
  }

  $total_seqsA = sprintf "%d", $total_seqsA + .05;
  $total_seqsB = sprintf "%d", $total_seqsB + .05;

  close CLUF;
  return join "\001", $total_seqsA, $total_seqsB;
}

######################################################################
sub ComputeDifferences {
  my ($factor, $pvalue, $total_seqsA, $total_seqsB, $org, $result) = @_;
 
  my %exists;
  my ($clu, $sym);
  my ($odds_ratio, $P);
  my ($G_A, $G_B, $libsA, $libsB);
  my (%order, %NaN);
  my (@clus, %clu2accs);


  if( $pvalue =~ /^e/ ) {
      $pvalue = "1" . $pvalue;
  } 

  my (@all_P, @all_info, @all_cids, @all_odds_rario, @all_G_A, @BH_P);

  for $clu (keys %tallied_clus) {
    $G_A = $seqA{$clu}; $G_A or $G_A = 0;
    $G_B = $seqB{$clu}; $G_B or $G_B = 0;
    $libsA = $libA{$clu}; $libsA or $libsA = 0;
    $libsB = $libB{$clu}; $libsB or $libsB = 0;

    if (not MayBeDifferent($factor,
        $G_A, $G_B, $total_seqsA, $total_seqsB)) {
      next;
    }

    if ($G_A or $G_B) {
      $odds_ratio =
          OddsRatio($G_A, $G_B, $total_seqsA, $total_seqsB);

      if( defined $exists{"$G_A,$G_B"} ) {
        $P = $exists{"$G_A,$G_B"};
      }  
      else {

        $total_seqsA = $total_seqsA * 1.0; 
        $total_seqsB = $total_seqsB * 1.0; 
        if ($G_A/$total_seqsA > $G_B/$total_seqsB) {
          $P = FisherExact::FisherExact(
          ## $P = 1 - Bayesian_no_C_lib::Bayesian($factor,
                   $G_A, $G_B, $total_seqsA, $total_seqsB);
          $exists{"$G_A,$G_B"} = $P;
        } else {
          $P = FisherExact::FisherExact(
          ## $P = 1 - Bayesian_no_C_lib::Bayesian($factor,
                   $G_B, $G_A, $total_seqsB, $total_seqsA);
          $exists{"$G_A,$G_B"} = $P;
        }
 
      }  

      ## if ($P <= $pvalue) {
        ## $P = sprintf "%.2f", $P;
      push @all_P, $P; 
      push @all_G_A, $G_A; 
        ## $P = sprintf "%.3f", $P;
        ## if ($odds_ratio eq "NaN") {
        ##   push @{ $NaN{$G_A} }, 
      push @all_odds_rario, $odds_ratio;
      push @all_info,
            "$clu\t$libsA\t$libsB\t$G_A\t$G_B\t" .
            "$odds_ratio";
      push @all_cids, $clu;
        ## } else {
        ##   push @{ $order{$odds_ratio} },
        ##     "$clu\t$libsA\t$libsB\t$G_A\t$G_B\t" .
        ##     "$odds_ratio\t$P";
        ##   push @clus, $clu;
        ## }
      ## }
    }
  }

  my $file = CACHE_ROOT . GXS_CACHE_PREFIX . ".txt";
 
  if (not (-e $file)) {
    print "<center><b>Error: Cache flag file is missing, please contact help desk. Sorry for inconvenient</b></center>";
    exit();
  }
 
  %exists = ();
  undef %exists;

  my ($BH_filename, $R_filename, $BH_output_file);
  open(IN, "$file") or die "Cannot open file $file\n";
  while(<IN>) {
    my $cache_id = $_;
    ## $BH_filename =  "/tmp/GXS" . "." . $cache_id . ".BH_IN";
    ## $R_filename =  "/tmp/GXS" . "." . $cache_id . ".R";
    ## $BH_output_file = "/tmp/GXS" . "." . $cache_id . ".BH_OUT";
    $BH_filename =  "/share/content/CGAP/data/cache/GXS" . "." . $cache_id . ".BH_IN";
    $R_filename =  "/share/content/CGAP/data/cache/GXS" . "." . $cache_id . ".R";
    $BH_output_file = "/share/content/CGAP/data/cache/GXS" . "." . $cache_id . ".BH_OUT";
  }
  close IN;
 
  if (open(BHOUT, ">$BH_filename") or die "Cannot open file $BH_filename\n") {
    printf BHOUT join("\t", @all_P) . "\n";
    close BHOUT;
    chmod 0666, $BH_filename;
  }
  @all_P = ();
  undef @all_P;
 
  if (open(ROUT, ">$R_filename")) {
    printf ROUT "p<-scan(\"$BH_filename\")\n";
    printf ROUT "p_BH<-p.adjust(p,\"BH\")\n";
    printf ROUT "write(file = \"$BH_output_file\", p_BH, sep = \"\n\", append=T)\n";
    printf ROUT "q(save = \"no\")\n";
    close ROUT;
    chmod 0666, $R_filename;
  }
 
  system( "/usr/local/bin/R --slave --no-save < $R_filename > /dev/null 2>&1" );
  my @tmps;
  open(IN, "$BH_output_file") or die "failed to open file $BH_output_file\n";
  while(<IN>) {
    chop;
    my @tmp = split " ", $_;
    for( my $i=0; $i<@tmp; $i++ ) {
      push @BH_P, $tmp[$i];
    }
  }
  close IN;
 
  unlink $BH_filename;
  unlink $R_filename;
  unlink $BH_output_file;
 
  for( my $i=0; $i<@BH_P; $i++ ) {
    if ($BH_P[$i] <= $pvalue) {
      push @clus, $all_cids[$i];
      $P = sprintf "%.2e", $BH_P[$i];
      if ($all_odds_rario[$i] eq "NaN") {
        push @{ $NaN{$all_G_A[$i]} },
          $all_info[$i] . "\t$P";
      } else {
        push @{ $order{$all_odds_rario[$i]} },
          $all_info[$i] . "\t$P";
      }
    }
  }

  my ($clu2accs, $clu2sym) = &GetAccessions ($org, \@clus);
 
  if( !(defined $clu2accs) ) {
    return undef;
  }
    
  my ($k, $x, $cid, @temps);
  for $k (sort r_numerically keys %NaN) {
    for $x (@{ $NaN{$k} }) {
      @temps = split "\t", $x;
      $cid = $temps[0];
      push @{ $result }, join("\t",
            $$clu2sym{$cid},
            $cid,
            $$clu2accs{$cid},
            @temps[1..6]
          );
    }
  }
  for $k (sort r_numerically keys %order) {
    for $x (@{ $order{$k} }) {
      @temps = split "\t", $x;
      $cid = $temps[0];
      push @{ $result }, join("\t",
            $$clu2sym{$cid},
            $cid,
            $$clu2accs{$cid},
            @temps[1..6]
          );
    }
  }
}

######################################################################
sub GetAccessions {
 
  my ($org, $clus_num) = @_;
  my @clus = @{$clus_num};
  my %clu2accs;
  my %clu2sym;

  my ($cluster_number, $sequence, $sym);
  my ($i, $list);
  my ($sql, $stm);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS, {AutoCommit=>0});
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print STDERR "$DBI::errstr\n";
    die "Error: Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE;
    return undef;
  }

  $sql = "delete from $CGAP_SCHEMA.gene_tmp_cluster";

  $stm = $db->prepare($sql);
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
  }

  if(!$stm->execute()) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    die "Error: execute call $sql failed with message $DBI::errstr";
  }

  $sql = "insert into $CGAP_SCHEMA.gene_tmp_cluster values (?)";

  $stm = $db->prepare($sql);
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
  }

  for( my $i=0; $i<@clus; $i++ ) {
    if(!$stm->execute($clus[$i])) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      die "Error: execute call $sql failed with message $DBI::errstr";
    }
  }

  my $table_name = ($org eq "Hs" ?
             "$CGAP_SCHEMA.hs_cluster" : "$CGAP_SCHEMA.mm_cluster");

  $sql = "select a.CLUSTER_NUMBER, a.SEQUENCES, a.GENE from " .
            "$table_name a, $CGAP_SCHEMA.gene_tmp_cluster b " . 
            " where a.CLUSTER_NUMBER = b.CLUSTER_NUMBER ";

  $stm = $db->prepare($sql);

  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
    return undef;
  }
  else {
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      die "Error: execute call $sql failed with message $DBI::errstr";
      return undef;
    }  
    $stm->bind_columns(\$cluster_number, \$sequence, \$sym);
    while($stm->fetch) {
      $clu2accs{$cluster_number} = $sequence;
      if ($sym) {
        $clu2sym{$cluster_number} = $sym
      } else {
        $clu2sym{$cluster_number} = "-";
      }
    }  
  }  

  $db->disconnect();

  return (\%clu2accs, \%clu2sym);

}

######################################################################
sub ComputeGXS_1 {
  my ($cache_id, $org, $page, $factor, $pvalue, $chr,
      $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
      $setA, $setB) = @_;
  my $test = Scan ($cache_id, $org, $page, $factor, $pvalue, $chr,
                   $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
                   $setA, $setB);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  my (@order);
  my ($filename, $gxs_cache_id, %all_same_libs);

  $chr =~ s/x/X/;
  $chr =~ s/y/Y/;
  $chr =~ s/a/A/;
  $chr =~ s/L/l/g;
  $chr =~ s/\ +//g;

  if ( $chr eq "" ) {
    $chr = "All";
  }

  if( ( $chr > 22 or $chr < 1 ) and
      ( ($chr ne "X") and ($chr ne "Y") and ($chr ne "All") ) ) {
    return "Not correct chromosome $chr";
  }


  if ($cache_id == 0 || $cache->FindCacheFile($cache_id) eq $CACHE_FAIL) {
    Init();
    for (split(",", $setA)) {
      $setA{$_} = 1 ;
    }
    for (split(",", $setB)) {
      $setB{$_} = 1 ;
    }
 
    $total_libsA = scalar(keys %setA);
    $total_libsB = scalar(keys %setB);
 
    ($total_seqsA, $total_seqsB) =
        split "\001", ReadClusterData($org);
 
    if ($total_seqsA == 0) {
      return "No sequences in A";
    }
    if ($total_seqsB == 0) {
      return "No sequences in B";
    }

    for my $libA (keys %setA) {    
      if( defined $setB{$libA} ) {      
        $all_same_libs{$libA} = 1;
      }  
    }
    for my $libB (keys %setB) {
      if( defined $setA{$libB} ) {
        $all_same_libs{$libB} = 1;
      }
    }
 
    my $common = scalar(keys %all_same_libs);
 
    if( $common > 0 ) {
      my $lib_ids = join(",", keys %all_same_libs);
      my $flag = "DGED";
      return GetLibNames($lib_ids, $flag);
    }


    ComputeDifferences($factor, $pvalue, $total_seqsA, $total_seqsB,
        $org, \@order);

    ($gxs_cache_id, $filename) = $cache->MakeCacheFile();

    if ($gxs_cache_id != $CACHE_FAIL) {
      if (open(GXSOUT, ">$filename")) {
        for (@order) {
          printf GXSOUT "$_\n";
        }
        close GXSOUT;
        chmod 0666, $filename;
      } else {
        $gxs_cache_id = 0;
      }
    }

  } else {
    my $filename = $cache->FindCacheFile($cache_id);
    open(GXSIN, "$filename") or die "Can't open $filename.";
    while (<GXSIN>) {
      chop;
      push @order, $_;
    } 
    $gxs_cache_id = $cache_id;
    close (GXSIN);
  }

  my @filtered;
  if( $chr ne "All" ) {
    my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
    if (not $db or $db->err()) {
      print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
      print STDERR "$DBI::errstr\n";
      die "Error: Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE;
      return undef;
    }

    @filtered = filterByChr( $db, $org, $chr, \@order );

    $db->disconnect();
  }
  else {
    @filtered = @order;
  }



  my ($lo, $hi);
  if ($page > 0) {
    $lo = 0 + ($page - 1) * GXS_ROWS_PER_PAGE;
    $hi = $lo + GXS_ROWS_PER_PAGE - 1;
    if ($hi > @filtered) {
      $hi = @filtered - 1;
    }
  } else {
    $lo = 0;
    $hi = @filtered - 1 ;
  }

  my $n_genes = scalar(@filtered);

  return (
      "$gxs_cache_id|$n_genes|$total_seqsA|$total_seqsB|" .
      "$total_libsA|$total_libsB|" .
      join("\n", @filtered[$lo..$hi]) . "|" .
      join("\n", @filtered)
  );
}

######################################################################
# SAGE
######################################################################

######################################################################
sub GetSymsOfCIDs {
  my ($db, $cids_hit, $cid2sym, $cid2title, $org) = @_;

  my ($sql, $stm);
  my ($cluster_number, $gene, $title);
  my ($i, $list);
  my @cids = keys %{ $cids_hit };

  if (@cids == 0) {
    return;
  }

  $sql = "delete from $CGAP_SCHEMA.gene_tmp_cluster";

  $stm = $db->prepare($sql);
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
  }

  if(!$stm->execute()) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    die "Error: execute call $sql failed with message $DBI::errstr";
  }

  $sql = "insert into $CGAP_SCHEMA.gene_tmp_cluster values (?)";

  $stm = $db->prepare($sql);
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
  }

  for( my $i=0; $i<@cids; $i++ ) {
    if(!$stm->execute($cids[$i])) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      die "Error: execute call $sql failed with message $DBI::errstr";
    }
  }

  my $cluster_table =
    ($org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster" : "$CGAP_SCHEMA.mm_cluster");

  $sql = "select a.cluster_number, a.gene, a.description " . 
      "from $cluster_table a, $CGAP_SCHEMA.gene_tmp_cluster b " .
      "where a.cluster_number = b.cluster_number";

  $stm = $db->prepare($sql);
  if (not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
    return;
  }
  if (not $stm->execute()) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    die "Error: execute call $sql failed with message $DBI::errstr";
    return;
  }
  while (($cluster_number, $gene, $title) = $stm->fetchrow_array()) {
    if ($gene) {
      $$cid2sym{$cluster_number} = $gene;
    }
    if ($title) {
      $$cid2title{$cluster_number} = $title;
    }
  }
}

######################################################################
sub GetAccMapsOfTags {
  my ($db, $tags, $tag2acc, $org, $method) = @_;

  my ($tag, $accession, $protocol);
  my ($sql, $stm);
  my ($i, $list);
  my %query_protocol;

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select a.tag, a.accession " .
      "from $CGAP_SCHEMA.sagebest_tag2acc a, " .
      "$CGAP_SCHEMA.sageprotocol b, " .
      "$CGAP_SCHEMA.sage_tmp_tag c " .
      "where a.tag = c.tag " .
      "and b.ORGANISM = '$org' " . 
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and a.PROTOCOL  = b.CODE ";

  $stm = $db->prepare($sql);
  if (not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
    return;
  }
  if (not $stm->execute()) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    die "Error: execute call $sql failed with message $DBI::errstr";
    return;
  }
  while (($tag, $accession) = $stm->fetchrow_array()) {
    $$tag2acc{$tag} = $accession;
  }
}

######################################################################
sub GetBestMapsOfTags {
  my ($db, $tags, $tag2cid, $tag2acc, $cid2sym, $org, $method) = @_;

  my ($sql, $stm);
  my ($i, $list, $tag, $cluster_number, $protocol, %tags_seen, @missing_cids, %cids_hit,
      %cid2loc);

  $sql = "delete from $CGAP_SCHEMA.sage_tmp_tag";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    ## print STDERR "prepare call failed\n";
    ##  "Error: prepare call $sql failed with message $DBI::errstr";
    return "Error: prepare call failed in GetBestMapsOfTags";
  }

  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    ## print STDERR "execute call failed\n";
    ## die "Error: execute call $sql failed with message $DBI::errstr";
    return "Error: execute call failed in GetBestMapsOfTags";
  }

  my %query_protocol;

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  ## my @tmp_list;
  ## my @tmp = split ",", $method;
  ## for( my $i=0; $i<@tmp; $i++ ) {
  ##   ## push @tmp_list, "'$org_method_2_protocol{$org}{$tmp[$i]}'";
  ##   $query_protocol{$org_method_2_protocol{$org}{$tmp[$i]}} = 1;
  ## }

  $sql = "insert into $CGAP_SCHEMA.sage_tmp_tag values (?)";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    ## print STDERR "prepare call failed\n";
    ## die "Error: prepare call $sql failed with message $DBI::errstr";
    return "Error: prepare call failed in GetBestMapsOfTags";
  }

  for( my $i=0; $i<@{ $tags }; $i++ ) {
    if(!$stm->execute(@{ $tags }[$i])) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      ## print STDERR "execute call failed\n";
      ## die "Error: execute call $sql failed with message $DBI::errstr";
      return "Error: execute call failed in GetBestMapsOfTags";
    }
  }

  my @tag_list;

  $sql = "select a.tag, a.cluster_number " .
    "from $CGAP_SCHEMA.sagebest_tag2clu a, " .
    "$CGAP_SCHEMA.sageprotocol b, " .
    "$CGAP_SCHEMA.sage_tmp_tag c " .
    "where a.tag = c.tag " .
    "and b.ORGANISM = '$org' " .
    "and b.PROTOCOL in ( '$method_list' ) " .
    "and a.PROTOCOL  = b.CODE ";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    ## print STDERR "prepare call failed\n";
    ## die "Error: prepare call $sql failed with message $DBI::errstr";
    return "Error: prepare call failed in GetBestMapsOfTags";
  }

  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    ## print STDERR "execute call failed\n";
    ## die "Error: execute call $sql failed with message $DBI::errstr";
    return "Error: execute call failed in GetBestMapsOfTags";
  }

  $stm->bind_columns(\$tag, \$cluster_number);
  while($stm->fetch) {
    ## print "$tag, $cluster_number \n";
    $tags_seen{$tag} = 1;
    $$tag2cid{$tag} = $cluster_number;
    $cids_hit{$cluster_number} = 1;
  }

  GetSymsOfCIDs($db, \%cids_hit, $cid2sym, \%cid2loc, $org);

  for $tag (@{ $tags }) {
    if (not defined $tags_seen{$tag}) {
      push @missing_cids, $tag;
    }
  }

  if (@missing_cids > 0) {
    GetAccMapsOfTags($db, \@missing_cids, $tag2acc, $org, $method);
  }

  ## $db->rollback();
  ## $db->commit;

}

######################################################################
sub SummarizeTagFreqs {
  my ($db, $lid_list, $tagfreqs, $libcounts, $totalfreqs,
      $tags_hit) = @_;

  my ($sql, $stm);
  my ($tag, $tagfreq, $libcount);

  $sql = "select " .
      "tag, sum(frequency), count(sage_library_id) ".
      "from $CGAP_SCHEMA.sagefreq " .
      "where sage_library_id in ($lid_list) " .
      "group by tag";

  $stm = $db->prepare($sql);
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
  }
  if(!$stm->execute()) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "execute call failed\n";
    die "Error: execute call $sql failed with message $DBI::errstr";
  }
  while(($tag, $tagfreq, $libcount) = $stm->fetchrow_array()) {
    $$tags_hit{$tag} = 1;
    $$tagfreqs{$tag} = $tagfreq;
    $$libcounts{$tag} = $libcount;
    $$totalfreqs += $tagfreq;
  }

}

######################################################################
sub Readsagefreqdat {
  my ($setA, $tagfreqsA, $libcountsA, $totalfreqsA,
      $setB, $tagfreqsB, $libcountsB, $totalfreqsB,
      $tags_hit, $org, $method) = @_;

  my ($sql, $stm);
  my ($tag, $tagfreq, $libcount);
  my %exit_protocol;
  my @tmp = split ",", $method;
  for( my $i=0; $i<@tmp; $i++ ) {
    $exit_protocol{$org_method_2_protocol{$org}{$tmp[$i]}} = 1;
  }
  
  for my $lid (keys %{ $setA }) {
    my $file_name = INIT_SAGE_DATA_HOME . "sagefreq/$lid";
    open (SAGEFREQIN, $file_name)  or die "Cannot open $file_name \n";
    while (<SAGEFREQIN>) {
      chop;
      my ($tag, $lid, $freq, $protocol) = split "\t", $_;
      if( defined $exit_protocol{$protocol} ) {
        $$tags_hit{$tag} = 1;
        $$tagfreqsA{$tag} += $freq;
        $$libcountsA{$tag}++;
        $$totalfreqsA += $freq;
      }
    }
    close(SAGEFREQIN);
  }   

  for my $lid (keys %{ $setB }) {
    my $file_name = INIT_SAGE_DATA_HOME . "sagefreq/$lid";
    open (SAGEFREQIN, $file_name)  or die "Cannot open $file_name \n";
    while (<SAGEFREQIN>) {
      chop;
      my ($tag, $lid, $freq, $protocol) = split "\t", $_;
      if( defined $exit_protocol{$protocol} ) {
        $$tags_hit{$tag} = 1;
        $$tagfreqsB{$tag} += $freq;
        $$libcountsB{$tag}++;
        $$totalfreqsB += $freq;
      }
    }
    close(SAGEFREQIN);
  }   

}

######################################################################
sub SAGEComputeDifferences {
  my ($db, $factor, $pvalue, $tags_hit,
        $total_seqsA, $total_seqsB,
        $freqsA,     $freqsB, 
        $nlibsA,     $nlibsB,
        $result, $org, $method) = @_;

  my %exists;
 
  if ($factor < 1) {
    $factor = 1;
  }

##  if ($pvalue =~ /^e/) {
##      $pvalue = "1" . $pvalue;
##  } 

  my ($tag);
  my ($odds_ratio, $P);
  my ($G_A, $G_B, $libsA, $libsB);
  my (%order, %NaN);
  my (@tags_hit, %tag2cid, %tag2acc, %cid2sym);
  my ($cid, $sym);
  my (@all_P, @all_info, @all_tags, @all_odds_rario, @all_G_A, @BH_P);

  my $file = CACHE_ROOT . GXS_CACHE_PREFIX . ".txt";
 
  if (not (-e $file)) {
    print "<center><b>Error: Cache flag file is missing, please contact help desk. Sorry for inconvenient</b></center>";
    ## exit();
    return "Error: Cache flag file is missing, please contact help desk. Sorry for inconvenient";
  }
 
  my ($BH_filename, $R_filename, $BH_output_file);
  my ($ALL_TAGS_filename, $ALL_G_A_filename, $ALL_ODDS_RARIO_filename, $ALL_INFO_filename);

  open(IN, "$file") or return "Error: Cannot open file $file, please contact help desk. Sorry for inconvenient\n";
  while(<IN>) {
    my $cache_id = $_;
    ## $BH_filename =  "/tmp/SAGEGXS" . "." . $cache_id . ".BH_IN";
    ## $R_filename =  "/tmp/SAGEGXS" . "." . $cache_id . ".R";
    ## $BH_output_file = "/tmp/SAGEGXS" . "." . $cache_id . ".BH_OUT";
    $BH_filename =  "/share/content/CGAP/data/cache/SAGEGXS" . "." . $cache_id . ".BH_IN";
    $R_filename =  "/share/content/CGAP/data/cache/SAGEGXS" . "." . $cache_id . ".R";
    $BH_output_file = "/share/content/CGAP/data/cache/SAGEGXS" . "." . $cache_id . ".BH_OUT";
    $ALL_TAGS_filename =  "/share/content/CGAP/data/cache/SAGEGXS" . "." . $cache_id . ".ALL_TAGS";
    $ALL_G_A_filename =  "/share/content/CGAP/data/cache/SAGEGXS" . "." . $cache_id . ".ALL_G_A";
    $ALL_ODDS_RARIO_filename =  "/share/content/CGAP/data/cache/SAGEGXS" . "." . $cache_id . ".ALL_ODDS_RARIO";
    $ALL_INFO_filename =  "/share/content/CGAP/data/cache/SAGEGXS" . "." . $cache_id . ".ALL_INFO";
  }
  close IN;

  open(ALL_TAGS_OUT, ">$ALL_TAGS_filename") or return "Error: Cannot open file $ALL_TAGS_filename\n"; 
  open(ALL_G_A_OUT, ">$ALL_G_A_filename") or return "Error: Cannot open file $ALL_G_A_filename\n"; 
  open(ALL_ODDS_RARIO_OUT, ">$ALL_ODDS_RARIO_filename") or return "Error: Cannot open file $ALL_ODDS_RARIO_filename\n"; 
  open(ALL_INFO_OUT, ">$ALL_INFO_filename") or return "Error: Cannot open file $ALL_INFO_filename\n"; 

  for $tag (keys %{ $tags_hit }) {

    $G_A = $$freqsA{$tag}; $G_A or $G_A = 0;
    $G_B = $$freqsB{$tag}; $G_B or $G_B = 0;

    if (not MayBeDifferent($factor,
        $G_A, $G_B, $total_seqsA, $total_seqsB)) {
      next;
    }

    $libsA = $$nlibsA{$tag}; $libsA or $libsA = 0;
    $libsB = $$nlibsB{$tag}; $libsB or $libsB = 0;

    if ($G_A or $G_B) {
      $odds_ratio =
          OddsRatio($G_A, $G_B, $total_seqsA, $total_seqsB);

      if( defined $exists{"$G_A,$G_B"} ) {
        $P = $exists{"$G_A,$G_B"};
      }
      else {
 
        if ($G_A/$total_seqsA > $G_B/$total_seqsB) {
          $P = FisherExact::FisherExact(
          ## $P = 1 - Bayesian::Bayesian($factor,
          ## $P = 1 - Bayesian_no_C_lib::Bayesian($factor,
                   $G_A, $G_B, $total_seqsA, $total_seqsB);
          $exists{"$G_A,$G_B"} = $P;
        } else {
          $P = FisherExact::FisherExact(
          ## $P = 1 - Bayesian::Bayesian($factor,
          ## $P = 1 - Bayesian_no_C_lib::Bayesian($factor,
                   $G_B, $G_A, $total_seqsB, $total_seqsA);
          $exists{"$G_A,$G_B"} = $P;
        }
 
      }  

      ## if ($P <= $pvalue) {
        ## push @tags_hit, $tag;
      ## push @all_tags, $tag;
      ## push @all_G_A, $G_A;
      ## push @all_odds_rario, $odds_ratio;
      ## push @all_info,
      ##   "$tag\001$libsA\t$libsB\t$G_A\t$G_B\t" .
      ##   "$odds_ratio";
      print ALL_TAGS_OUT $tag . "\n";
      print ALL_G_A_OUT $G_A . "\n";
      print ALL_ODDS_RARIO_OUT $odds_ratio . "\n";
      print ALL_INFO_OUT "$tag\001$libsA\t$libsB\t$G_A\t$G_B\t" .
                         "$odds_ratio" . "\n";

      push @all_P, $P;
        ## $P = sprintf "%.2f", $P;
        ## if ($odds_ratio eq "NaN") {
        ##   push @{ $NaN{$G_A} }, 
        ##     "$tag\001$libsA\t$libsB\t$G_A\t$G_B\t" .
        ##     "$odds_ratio\t$P";
        ## } else {
        ##   push @{ $order{$odds_ratio} },
        ##     "$tag\001$libsA\t$libsB\t$G_A\t$G_B\t" .
        ##     "$odds_ratio\t$P";
        ## }
      ## }
    }
  }

  close ALL_TAGS_OUT;
  close ALL_G_A_OUT;
  close ALL_ODDS_RARIO_OUT;
  close ALL_INFO_OUT; 

  if (open(BHOUT, ">$BH_filename") or return "Error: Cannot open file $BH_filename, please contact help desk. Sorry for inconvenient\n") {
    printf BHOUT join("\t", @all_P) . "\n";
    close BHOUT;
    chmod 0666, $BH_filename;
  }
  @all_P = ();
  undef @all_P;
  
 
  if (open(ROUT, ">$R_filename")) {
     ## printf ROUT "options(max.print=Inf)\n";
    printf ROUT "p<- scan(\"$BH_filename\")\n";
    printf ROUT "p_BH<-p.adjust(p,\"BH\")\n";
    printf ROUT "write(file = \"$BH_output_file\", p_BH, sep = \"\n\", append=T)\n";
    printf ROUT "q(save = \"no\")\n";
    close ROUT;
    chmod 0666, $R_filename;
  }
 
  system( "/usr/local/bin/R --slave --no-save < $R_filename > /dev/null 2>&1" );
 
  my @tmps;
  open(IN, "$BH_output_file") or return "Error: failed to open file $BH_output_file, please contact help desk. Sorry for inconvenient\n";
  while(<IN>) {
    chop;
    ## my @tmp = split " ", $_;
    ## for( my $i=0; $i<@tmp; $i++ ) {
    ##   push @BH_P, $tmp[$i];
    ## }
    push @BH_P, $_;
  }
  close IN;
 
  unlink $BH_filename;
  unlink $R_filename;
  unlink $BH_output_file;


  open(ALL_TAGS_IN, "$ALL_TAGS_filename") or return "Error: Cannot open file $ALL_TAGS_filename\n";
  open(ALL_G_A_IN, "$ALL_G_A_filename") or return "Error: Cannot open file $ALL_G_A_filename\n";
  open(ALL_ODDS_RARIO_IN, "$ALL_ODDS_RARIO_filename") or return "Error: Cannot open file $ALL_ODDS_RARIO_filename\n";
  open(ALL_INFO_IN, "$ALL_INFO_filename") or return "Error: Cannot open file $ALL_INFO_filename\n";
  while(<ALL_TAGS_IN>) {
    chop;
    push @all_tags, $_;
  }
  close ALL_TAGS_IN;
  while(<ALL_G_A_IN>) {
    chop;
    push @all_G_A, $_;
  }
  close ALL_G_A_IN;
  while(<ALL_ODDS_RARIO_IN>) {
    chop;
    push @all_odds_rario, $_;
  }
  close ALL_ODDS_RARIO_IN;
  while(<ALL_INFO_IN>) {
    chop;
    push @all_info, $_;
  }
  close ALL_INFO_IN;

  unlink $ALL_TAGS_filename;
  unlink $ALL_G_A_filename;
  unlink $ALL_ODDS_RARIO_filename;
  unlink $ALL_INFO_filename;

  for( my $i=0; $i<@BH_P; $i++ ) {
    if ($BH_P[$i] <= $pvalue) {
      push @tags_hit, $all_tags[$i];
      $P = sprintf "%.2e", $BH_P[$i];
      if ($all_odds_rario[$i] eq "NaN") {
        push @{ $NaN{$all_G_A[$i]} },
          $all_info[$i] . "\t$P";
      } else {
        push @{ $order{$all_odds_rario[$i]} },
          $all_info[$i] . "\t$P";
      }
    }
  }
 
  @all_tags = ();
  undef @all_tags; 
  @all_G_A = ();
  undef @all_G_A; 
  @all_odds_rario = ();
  undef @all_odds_rario;
  @all_info = ();
  undef @all_info;


  my $info = GetBestMapsOfTags($db, \@tags_hit, \%tag2cid, \%tag2acc, \%cid2sym, $org, $method);
  if( $info =~ /^Error:/ ) {
    return $info;
  }

  my ($rest);

  my ($k, $x);
  for $k (sort r_numerically keys %NaN) {
    for $x (@{ $NaN{$k} }) {

      ($tag, $rest) = split(/\001/, $x);
      if (defined $tag2cid{$tag}) {
        $cid = $tag2cid{$tag};
        if (defined $cid2sym{$cid}) {
          $sym = $cid2sym{$cid};
        } else {
          ## $sym = "Hs.$cid";
          $sym = "$org.$cid";
        }
      } else {
        $cid = "";
        $sym = $tag2acc{$tag};
      }

      push @{ $result }, "$tag\t$cid\t$sym\t$rest";
    }
  }
  for $k (sort r_numerically keys %order) {
    for $x (@{ $order{$k} }) {

      ($tag, $rest) = split(/\001/, $x);
      if (defined $tag2cid{$tag}) {
        $cid = $tag2cid{$tag};
        if (defined $cid2sym{$cid}) {
          $sym = $cid2sym{$cid};
        } else {
          ## $sym = "Hs.$cid";
          $sym = "$org.$cid";
        }
      } else {
        $cid = "";
        $sym = $tag2acc{$tag};
      }

      push @{ $result }, "$tag\t$cid\t$sym\t$rest";
    }
  }

}

######################################################################
sub MoveUploadFileToLocal_1 { 

  my ($sdged_cache_id) = @_; 
  my $test = Scan ($sdged_cache_id); 
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  my ($cache_id, $host_name) = split "HOSTNAME", $sdged_cache_id; 
  my $local_hostname = hostname();
  if( $local_hostname eq $host_name ) {
    return $cache_id;
  }

  my $path;
  if( $host_name eq "cbiodev104.nci.nih.gov" ) {
    $path = "/cgap/webcontent/CGAP/dev/data/cache";
  }
  elsif( $host_name eq "cbioapp101.nci.nih.gov" ) {
    $path = "/cgap/webcontent/CGAP/staging/data/cache";
  }
  elsif( $host_name eq "cbioapp102.nci.nih.gov" ) {
    $path = "/cgap/webcontent/CGAP/prod/data/cache";
  }
  elsif( $host_name eq "cbioapp104.nci.nih.gov" ) {
    $path = "/cgap/webcontent/CGAP/prod/data/cache";
  }

  my $sdged_filename = $path . "/" . SDGED_CACHE_PREFIX . ".$cache_id";

  my $cache_sdged = new Cache(CACHE_ROOT, SDGED_CACHE_PREFIX);
  my ($sdged_cache_id, $filename) = $cache_sdged->MakeCacheFile();
  if ($sdged_cache_id != $CACHE_FAIL) {
    my $cmd = "cp $sdged_filename $filename";
    system($cmd);
    return $sdged_cache_id;
  }
  else {
    return "";
  }
}

######################################################################
sub ComputeSDGED_1 {

  my ($base, $cache_id, $org, $page, $factor, $pvalue, $chr, $user_email,
      $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
      $setA, $setB, $method, $sdged_cache_id, $email) = @_;
  ## user_email is real user email, email is cache_id.

  my $info = Scan ($base, $cache_id, $org, $page, $factor, $pvalue, $chr,
                   $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
                   $setA, $setB, $method, $sdged_cache_id);
  if( $info =~ /Error in input/ ) {
    Mail_Info($user_email, $info);
    $info = "<br><center><b>" . $info . "</center></b>";
    Write_Info($email, $info);
    return $info;
  }


  my $start_time = time();
  ## print STDERR "8888:  $start_time\n";
  if (($setA eq "") && ($sdged_cache_id eq "")) {
    my $info = "No libraries in Pool A";
    Mail_Info($user_email, $info);
    $info = "<br><center><b>" . $info . "</center></b>";
    Write_Info($email, $info);
    return "No libraries in Pool A";
  }
  if (($setB eq "") && ($sdged_cache_id eq "")) {
    my $info = "No libraries in Pool B";
    Mail_Info($user_email, $info);
    $info = "<br><center><b>" . $info . "</center></b>";
    Write_Info($email, $info);
    return "No libraries in Pool B";
  }

  $chr =~ s/x/X/;
  $chr =~ s/y/Y/;
  $chr =~ s/a/A/;
  $chr =~ s/L/l/g;
  $chr =~ s/\ +//g;

  if ( $chr eq "" ) {
    $chr = "All";
  }

  if( ( $chr > 22 or $chr < 1 ) and 
      ( ($chr ne "X") and ($chr ne "Y") and ($chr ne "All") ) ) {
    my $info = "Not correct chromosome $chr";
    Mail_Info($user_email, $info);
    $info = "<br><center><b>" . $info . "</center></b>";
    Write_Info($email, $info);
    return "Not correct chromosome $chr";
  }

  my ($cache, $filename, $gxs_cache_id);
  my ($db);
  my (%setA, %setB, %freqsA, %freqsB, %nlibsA, %nlibsB, %tags_hit);
  my ($tag, $tagfreq);

  my (@order);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS, {AutoCommit=>0});
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    ## print STDERR "$DBI::errstr\n";
    ## die "Error: Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE;
    my $info = "Cannot connect to database. Please contact help desk.";
    Mail_Info($user_email, $info);
    Mail_Info($HELP_DESK_EMAIL, $info);
    $info = "<br><center><b>" . $info . "</center></b>";
    Write_Info($email, $info);
    return undef;
  }

  $cache = new Cache(CACHE_ROOT, GXS_CACHE_PREFIX);
  if ($cache_id == 0 || $cache->FindCacheFile($cache_id) eq $CACHE_FAIL) {

    Init();

    my (%all_same_libs);
    for (split(",", $setA)) {
      $setA{$_} = 1 ;
    }
    $setA = join(",", keys %setA);
    $total_libsA = scalar(keys %setA);

    for (split(",", $setB)) {
      $setB{$_} = 1 ;
    }
    $setB = join(",", keys %setB);
    $total_libsB = scalar(keys %setB);

    for my $libA (keys %setA) {
      if( defined $setB{$libA} ) {      
        $all_same_libs{$libA} = 1;
      }  
    }
 
    for my $libB (keys %setB) {
      if( defined $setA{$libB} ) {
        $all_same_libs{$libB} = 1;
      }
    }
 
    my $common = scalar(keys %all_same_libs);
 
    if( $common > 0 ) {
      my $lib_ids = join(",", keys %all_same_libs);
      my $flag = "SDGED";
      my $info = GetLibNames($lib_ids, $flag);
      Mail_Info($user_email, $info);
      $info = "<br><center><b>" . $info . "</center></b>";
      Write_Info($email, $info);
    }
    Readsagefreqdat(\%setA, \%freqsA, \%nlibsA, \$total_seqsA,
        \%setB, \%freqsB, \%nlibsB, \$total_seqsB, \%tags_hit, 
        $org, $method);

    if ($sdged_cache_id) {
      my $sdged_B = 1;
      my $sdged_cache = new Cache(CACHE_ROOT, SDGED_CACHE_PREFIX);
      my $sdged_filename = $sdged_cache->FindCacheFile($sdged_cache_id);
      if ($sdged_filename) {
        if( open(SIN, "$sdged_filename") ) { 
          while (<SIN>) {
            $_ =~ s/[\n\r]+//g;
            next if (/^$/);
            if (/#################/) {
              $sdged_B = 0;
              next;
            }
            s/[\t\s]+/\t/;
            ($tag, $tagfreq) = split "\t";
            $tags_hit{$tag} = 1;
            if ($sdged_B) {
              $total_libsB = 1;
              $freqsB{$tag} = int($tagfreq + 0.5); ## for decimal input
              $total_seqsB += int($tagfreq + 0.5);
            } else {
              $total_libsA = 1;
              $freqsA{$tag} = int($tagfreq + 0.5);
              $total_seqsA += int($tagfreq + 0.5);
            }
          }
          close (SIN);
        }
        else {
          my $info = "Can not open user uploaded filr $sdged_filename ";
          Mail_Info($user_email, $info);
          Mail_Info($HELP_DESK_EMAIL, $info);
          $info = "<br><center><b>" . $info . "</center></b>";
          Write_Info($email, $info);
        }
      }
    }

    if ($total_seqsA == 0) {
      my $info = "No sequences in A";
      Mail_Info($user_email, $info);
      $info = "<br><center><b>" . $info . "</center></b>";
      Write_Info($email, $info);
      return "No sequences in A";
    }
    if ($total_seqsB == 0) {
      my $info = "No sequences in B";
      Mail_Info($user_email, $info);
      $info = "<br><center><b>" . $info . "</center></b>";
      Write_Info($email, $info);
      return "No sequences in B";
    }

    ## my $start_time_2 = time();
    ## my $t_diff = $start_time_2 - $start_time;
    ## print STDERR "8888:  $start_time_2 and $t_diff \n";
    my $info = SAGEComputeDifferences($db, $factor, $pvalue, \%tags_hit,
                                           $total_seqsA, $total_seqsB,
                                           \%freqsA,     \%freqsB, 
                                           \%nlibsA,     \%nlibsB,
                                           \@order,      $org, $method);
    if( $info =~ /^Error:/ ) {
      Mail_Info($user_email, $info);
      $info = "<br><center><b>" . $info . "</center></b>";
      Write_Info($email, $info);
      my $info = $info . 
                 join ("; ", $base, $cache_id, $org, $page, $factor, 
                       $pvalue, $chr, $user_email,
                       $total_seqsA, $total_seqsB, $total_libsA, $total_libsB,
                       $setA, $setB, $method, $sdged_cache_id, $email);
      Mail_Info($HELP_DESK_EMAIL, $info);
      return "Error";
    }

    ## my $start_time_3 = time();
    ## my $t_diff = $start_time_3 - $start_time_2;
    ## print STDERR "8888:  $start_time_3 and $t_diff \n";
    
    ($gxs_cache_id, $filename) = $cache->MakeCacheFile();
    if ($gxs_cache_id != $CACHE_FAIL) {
      if (open(GXSOUT, ">>$filename")) {
        for (@order) {
          printf GXSOUT "$_\n";
        }
        ## printf GXSOUT "8888" . $email . "\n";
        close GXSOUT;
        chmod 0666, $filename;
      } else {
        $gxs_cache_id = 0;
      }
    }
    if( $user_email ne "" ) {     
       open(MAIL, "|/usr/lib/sendmail -t");      
       print MAIL "To: $user_email\n";      
       print MAIL "From: ncicb\@pop.nci.nih.gov\n";      
       if ( $email != 0 ) {        
         my $url = $base . "/SAGE/GetUserResult?CACHE=$email"; 
         print MAIL "Subject: your search is completed\n";        
         print MAIL "Your search is completed\n";        
         print MAIL "Please click the hyper link to get you results\n";        
         print MAIL "$url\n";        
         print MAIL "Please note that the system keeps your result file one day only\n";
      }
      else {
        print MAIL "Subject: your search failed\n";
        print MAIL "Your search failed\n";
        print MAIL "Please contact Help desk\n";
      }
      close (MAIL);
    }

  } else {
    $filename = $cache->FindCacheFile($cache_id);
    open(GXSIN, "$filename") or die "Can't open $filename.";
    while (<GXSIN>) {
      chop;
      push @order, $_;
    } 
    $gxs_cache_id = $cache_id;
    close (GXSIN);
  }

  my @filtered;
  if( $chr ne "All" ) {
    @filtered = SAGEfilterByChr( $db, $org, $chr, \@order );
  }
  else {
    @filtered = @order;
  }

  my ($lo, $hi);
  if ($page > 0) {
    $lo = 0 + ($page - 1) * GXS_ROWS_PER_PAGE;
    $hi = $lo + GXS_ROWS_PER_PAGE - 1;
    if ($hi > @filtered) {
      $hi = @filtered - 1;
    }
  } else {
    $lo = 0;
    $hi = @filtered - 1 ;
  }

  $db->disconnect();

  my $n_genes = scalar(@filtered);
######################################################################
######################################################################
  if( $email ne "" and $email =~ /\d/ ) {

    my @lines;
    my $url = "/Genes/RunUniGeneQuery";
    push @lines, "<form name=\"geneList\" action=" . $url . " method=POST>";    
    push @lines, "<input type=hidden name=\"PAGE\" value=" . $page . ">";
    push @lines, "<input type=hidden name=\"ORG\" value=" . $org . ">";
    for (my $i=0; $i<@filtered; $i++) {
      my ($sym, $clu, $accs, $la, $lb, $sa, $sb, $odds, $p) 
            = split "\t", $filtered[$i];
      if ($clu ne "") {
        if( $odds =~ /NaN/ ) {
          push @lines, "<input type=hidden name=\"TERM\" value=" . $clu . "_A" . ">";
        }
        elsif( $odds > 1 ) {
          push @lines, "<input type=hidden name=\"TERM\" value=" . $clu . "_A" . ">";
        }
        elsif( $odds < 1 ) {
          push @lines, "<input type=hidden name=\"TERM\" value=" . $clu . "_B" . ">";
        }
        elsif( $odds == 1 ) {
          push @lines, "<input type=hidden name=\"TERM\" value=" + $clu . "_E" + ">";
        }
      }
    }
    push @lines, "<br>";
    push @lines, "Get Gene List: &nbsp;&nbsp; "; 
    my $tmp_page_1 = $page+200000;
    push @lines, "<a href=\"javascript:" . "document.geneList.PAGE.value=" . $tmp_page_1 . ";" .
         "document.geneList.submit()\">" . "<b>[ A > B ]</b></a>&nbsp;&nbsp; ";
    my $tmp_page_2 = $page+300000;
    push @lines, "<a href=\"javascript:" . "document.geneList.PAGE.value=" . $tmp_page_2 . ";" . "document.geneList.submit()\">" . "<b>[ A < B ]</b></a>&nbsp;&nbsp; ";
    my $tmp_page_3 = $page+400000;
    push @lines, "<a href=\"javascript:" . "document.geneList.PAGE.value=" . $tmp_page_3 . ";" . "document.geneList.submit()\">" . "<b>[ All ]</b></a><br><br>";
    push @lines, "</form>";
 
    my $npages = $n_genes / GXS_ROWS_PER_PAGE;
    if ( ($n_genes % GXS_ROWS_PER_PAGE) > 0 ) {
      $npages = int($npages) + 1;
    }
    
    push @lines, "<form name=\"gxs\" action=\"SDGEDResults\" method=POST>";
    push @lines, "<input type=hidden name=\"PAGE\">";
    push @lines, "<input type=hidden name=\"WHAT\">";
    push @lines, "<input type=hidden name=\"PVALUE\" value=" . $pvalue . ">";
    push @lines, "<input type=hidden name=\"CID\">";
    push @lines, "<input type=hidden name=\"EMAIL\">";
    push @lines, "<input type=hidden name=\"ORG\" value=" . $org . ">";
    push @lines, "<input type=hidden name=\"FACTOR\" value=" . $factor  . ">";
    push @lines, "<input type=hidden name=\"CACHE\" value=" . $gxs_cache_id . ">"; 
    push @lines, "<input type=hidden name=\"ASEQS\" value=" . $total_seqsA . ">";    
    push @lines, "<input type=hidden name=\"BSEQS\" value=" . $total_seqsB . ">";  
    push @lines, "<input type=hidden name=\"ALIBS\" value=" . $total_libsA . ">";
    push @lines, "<input type=hidden name=\"BLIBS\" value=" . $total_libsB . ">"; 
    push @lines, "<input type=hidden name=\"METHOD\" value=" . $method . ">";
    push @lines, "<input type=hidden name=\"SDGED_CACHE\" value=" . $cache_id . ">";
    for (split(",", $setA)) {
      push @lines, "<input type=hidden name=\"" . "A_" . $_ . "\" checked>";
    }
    for (split(",", $setB)) {
      push @lines, "<input type=hidden name=\"" . "B_" . $_ . "\" checked>";
    }

    push @lines, "Displaying " . $lo . " thru " . $hi . " of " .  $n_genes . " tags &nbsp;&nbsp;&nbsp;"; 
    if ( $page < $npages ) {
      my $tmp_page = $page+1;
      push @lines, "<a href=\"javascript:" . 
        "document.gxs.PAGE.value=" . $tmp_page . ";" .
        "document.gxs.WHAT.value=&quot;genes&quot;;" .  
        "document.gxs.submit()\">" .
        "Next Page</a> &nbsp;&nbsp;&nbsp;";
    }
    if ( $page > 1 ) {
      my $tmp_page = $page-1;
      push @lines, "<a href=\"javascript:" .
          "document.gxs.PAGE.value=" . $tmp_page . ";" .
          "document.gxs.WHAT.value=&quot;genes&quot;;" .
          "document.gxs.submit()\">" .
          "Prev Page</a> &nbsp;&nbsp;&nbsp;";
     }
     push @lines, "<a href=\"javascript:" .
       "document.gxs.PAGE.value=0;" .
       "document.gxs.WHAT.value=&quot;genes&quot;;" .
       "document.gxs.submit()\">" .
       "<b>[Full Text]</b></a>";
    push @lines, ## param_table
      "<blockquote><table border=0 cellspacing=1 cellpadding=4>\n" .
      "<tr>\n" .
        "<td><b>Total tags in Pool A:</b></td>" .
        "<td>" . $total_seqsA . "</td>\n" .
      "</tr>\n" .
      "<tr>\n" .
        "<td ><b>Total tags in Pool B:</b></td>" .
        "<td>" . $total_seqsB . "</td>\n" .
      "</tr>\n" .
      "<tr>\n" .
        "<td><b>Total libraries in Pool A:</b></td>" .
        "<td>" . $total_libsA . "</td>\n" .
      "</tr>\n" .
      "<tr>\n" .
        "<td ><b>Total libraries in Pool B:</b></td>" .
        "<td>" . $total_libsB . "</td>\n" .
      "</tr>\n" .
      "<tr>\n" .
        "<td><b>F (expression factor):</b></td>" .
        "<td>" . $factor . "X</td>\n" .
      "</tr>\n" .
      "<tr>\n" .
        "<td><b>Q (False discovery rate):</b></td>" .
        "<td>" . $pvalue . "</td>\n" .
      "</tr>\n" .
      "<tr>\n" .
        "<td><b>Chromosome:</b></td>" .
        "<td>" . $chr . "</td>\n" .
      "</tr>\n" .
      "<tr>\n" .
        "<td><b><label for=\"Chromosome\">Enter Chromosome:</label></b></td>" .
        "<td>" . "<input type=text name=\"CHR\" id=\"Chromosome\" value=\"" . $chr . "\" size=3 >" . "</td>\n" .
        "<td>" . 
          "<a href=\"javascript:" .
          "document.gxs.PAGE.value=1;" .
          "document.gxs.WHAT.value=&quot;genes&quot;;" .
          "document.gxs.submit()\">" .
          "<b>[Submit]</b></a> &nbsp;&nbsp;&nbsp;" .
          "</td>\n" .
      "</tr>\n" .
      "</table></blockquote\n";
    push @lines, "<p>";

    my $html_table_header = 
      "<table border=1 cellspacing=1 cellpadding=4>\n" .
      "<tr bgcolor=\"#38639d\" valign=top>\n" .
      "<td rowspan=2><font color=\"white\"><b>Tag</b></font></td>\n" .
      "<td rowspan=2><font color=\"white\"><b>Gene or<br>Accession</b></font></td>\n" .
      "<td colspan=2 witdh=16%><font color=\"white\"><b>Libraries</b></font></td>\n" .
      "<td colspan=2 width=16%><font color=\"white\"><b>Tags</b></font></td>\n" .
      "<td rowspan=2><font color=\"white\"><b>Tag Odds A:B</b></font></td>\n" .
      "<td rowspan=2><font color=\"white\"><b>Q</b></font></td>\n" .
      "</tr>\n" .
      "<tr bgcolor=\"#38639d\" valign=top>\n" .
      "<td width=8%><font color=\"white\"><b>A</b></font></td>\n" .
      "<td width=8%><font color=\"white\"><b>B</b></font></td>\n" .
      "<td width=8%><font color=\"white\"><b>A</b></font></td>\n" .    
      "<td width=8%><font color=\"white\"><b>B</b></font></td>\n" .
    "</tr>"; 
    push @lines, $html_table_header;
    my $j = 0;
    for (my $i=$lo; $i<=$hi; $i++) { 
      $j = $j + 1;
      if ( $j > 1 and $j % GXS_ROWS_PER_SUBTABLE == 1 ) {
        push @lines, "</table>";
        push @lines, $html_table_header;
      } 
      my ($tag, $clu, $sym, $la, $lb, $sa, $sb, $odds, $p) 
                                 = split "\t", $filtered[$i];
      push @lines, "<tr>";
      push @lines, "<td><a href=\"" . "/SAGE/GeneByTag?" .  
        "ORG=" . $org . "&METHOD=" . $method . "&FORMAT=html&MAGIC_RANK=0&TAG=" . $tag . "\">" . $tag . "</a></td>";
      if ( $clu ne "") {
        push @lines, "<td><a href=\"" . "/Genes/GeneInfo?" .
          "ORG=" . $org . "&CID=" . $clu . "\">" . $sym . "</a></td>";
      }
      else {
        if ($sym eq "") {
          $sym = "&nbsp;"
        }
        elsif ($sym eq MITO_ACC) {
          $sym = "<font color=red>mitochondria</font>" 
        } 
        push @lines, "<td>" . $sym . "</td>";
     
      }
      if (int($la) > 0) {
        push @lines, "<td>" . $la . "</td>";
      }
      else {
        push @lines, "<td>" . $la . "</td>";
      }
      if (int($lb) > 0) {
        push @lines, "<td>" . $lb . "</td>";
      }
      else {
        push @lines, "<td>" . $lb . "</td>";
      }
      push @lines, "<td>" . $sa . "</td>";
      push @lines, "<td>" . $sb . "</td>";
      push @lines, "<td>" . $odds . "</td>";
      push @lines, "<td nowrap>" . $p . "</td>";
      push @lines, "</tr>";
    }
    push @lines, "</table>";
    push @lines, "</form>";

    ##my ($GXS_cache_id, $Filename) = $cache->MakeCacheFile();
    my $filename = $cache->FindCacheFile($email);
    if (open(GXSOUT, ">>$filename")) {
      for (@lines) {
        printf GXSOUT "$_\n";
      }
      close GXSOUT;
      chmod 0666, $filename;
    } else {
      ## $GXS_cache_id = 0;
    }

  }
######################################################################
  else {
    print (
      "$gxs_cache_id|$n_genes|$total_seqsA|$total_seqsB|" .
      "$total_libsA|$total_libsB|" .
      join("\n", @filtered[$lo..$hi]) . "|" .
      join("\n", @filtered)
    );
  } 
}

######################################################################
sub  filterByChr {
  my ($db, $org, $chr, $order_ref) = @_;
  my (@acc, %clu2index, @filtered);
  my %orders;
  my @order = @$order_ref;
  for( my $i=0; $i<@order; $i++ ) {
    my @tmp = split "\t", $order[$i];
    $clu2index{$tmp[1]} = $i;
  }
  my $sql = "select CLUSTER_NUMBER from $CGAP_SCHEMA.UCSC_MRNA " .
            "where CHROMOSOME = '$chr' and ORGANISM = '$org' ";

  my $stm = $db->prepare($sql);

  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
    return undef;
  }
  else {
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      die "Error: execute call $sql failed with message $DBI::errstr";
      return undef;
    }
    my ($accession, $cluster_number);
    $stm->bind_columns(\$cluster_number);
    while($stm->fetch) {
      if( defined $clu2index{$cluster_number} ) {
        $orders{$clu2index{$cluster_number}} = 1;
      }
    }
  }

  for my $k (sort numerically keys %orders) {
    push @filtered, $order[$k];
  }


  return @filtered;

}

######################################################################
sub  SAGEfilterByChr {
  my ($db, $org, $chr, $order_ref) = @_; 
  my (@acc, %clu_tag2index, @filtered);
  my %orders;
  my @order = @$order_ref;
  for( my $i=0; $i<@order; $i++ ) {
    my @tmp = split "\t", $order[$i];
    $clu_tag2index{$tmp[1]}{$tmp[0]} = $i;
  } 
  my $sql = "select CLUSTER_NUMBER from $CGAP_SCHEMA.UCSC_MRNA " .
            "where CHROMOSOME = '$chr' and ORGANISM = '$org' ";

  my $stm = $db->prepare($sql);

  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
    return undef;
  }
  else {
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      die "Error: execute call $sql failed with message $DBI::errstr";
      return undef;
    }
    my ($accession, $cluster_number);
    $stm->bind_columns(\$cluster_number);
    while($stm->fetch) {
      if( defined $clu_tag2index{$cluster_number} ) {
        for my $tag ( keys %{$clu_tag2index{$cluster_number}} ) {
          $orders{$clu_tag2index{$cluster_number}{$tag}} = 1;
        }
      } 
    }
  }

  for my $k (sort numerically keys %orders) {
    push @filtered, $order[$k];
  }


  return @filtered;

}
######################################################################
sub TimeStamp {
  my ($sec, $min, $hr, $mday, $mon, $year, $wday, $yday, $isdst) =
      localtime(time);
  my $month = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec')[$mon];
  return sprintf "%s%2.2d_%2.2d_%2.2d_%2.2d",
      $month, $mday, $hr, $min, $sec;
}

######################################################################
sub GetLibNames {
  my ($lib_ids, $flag) = @_;

  my ($table, $sql, $names);
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS, {AutoCommit=>0});
  if (not $db or $db->err()) {
    return "Error: There is an error, please contact help desk.";
  }
 
  if( $flag eq "DGED" ) {
    $sql =
      "select LIB_NAME from $CGAP_SCHEMA.all_libraries " .
      "where unigene_id in( $lib_ids ) ";
  } 
  elsif ( $flag eq "SDGED" ) {
    $sql =
      "select name from $CGAP_SCHEMA.sagelibnames " .
      "where sage_library_id in( $lib_ids ) ";
  }
  my $stm = $db->prepare($sql);
  if(not $stm) {
    $db->disconnect();
    return "Error: There is an error, please contact help desk.";
  }
  if(!$stm->execute()) {
    $db->disconnect();
    return "Error: There is an error, please contact help desk.";    
  }

  while( my ($name) = $stm->fetchrow_array()) {
    if( $names eq "" ) {
      $names = $name;
    }
    else {
      $names = $names . "<td nowrap></tr><tr></td>" . $name;
    }
  }
  my $output = "<table width=40%><tr><td nowrap>$names</td></tr></table>";
  $db->disconnect();    
  return "<br><br><center><b>Error: a library may not appear in both Pool A and Pool B. The following libraries appear in both pools:</b></center><br><center>$output<br></center>";
}
######################################################################
sub Mail_Info {
  my ($user_email, $message) = @_;
  if( $user_email ne "" ) {
    open(MAIL, "|/usr/lib/sendmail -t");
    print MAIL "To: $user_email\n";
    print MAIL "From: ncicb\@pop.nci.nih.gov\n";
    print MAIL "Subject: your search failed \n";
    print MAIL "Your search failed:\n";
    print MAIL "$message\n";
    close (MAIL);
  }

}

######################################################################
sub Write_Info {
  my ($email, $message) = @_;
  my $filename = $cache->FindCacheFile($email);
  if (open(GXSOUT, ">>$filename")) {
    printf GXSOUT "$message\n";
  } 
  close GXSOUT;
  chmod 0666, $filename;
}

######################################################################
1;
######################################################################
