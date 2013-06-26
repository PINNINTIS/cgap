#!/usr/local/bin/perl

######################################################################
# GLServer.pl
# (for GenesInLibsServer)

######################################################################

use strict;
use FileHandle;
use CGAPConfig;
use Paging;
use ServerSupport;
use DBI;
use Cache;

use constant MAX_CACHE => 500;
my $cache;

my $BASE;

my %BUILDS;

## my %complement;     ## defined $complement{$g} => $g is in complement of U
## my @partitions;     ## defined $partitions[$i]{$g} => $g is in partition $i
## my %partition_idx;  ## library_id -> Z
## my %num_partitions; ## $num_partitions{$g} > 1 => $g is not unique in
                    ## any partition in U

## my %known;

##
## following indexed by partition number
##
## my @ku;      ## known unique
## my @uu;      ## unknown unique
## my @kn;      ## known non-unique
## my @un;      ## unknown non-unique

## my $global_idx;        ## index to the phoney "global partition"
                       ## to represent the union
## my @label;
## my @lib_count;
## my @seq_count;
## my $lib_count_total;
## my $seq_count_total;

my $GLFILEPATH = "/cgap/schaefec/wuk/CGAP/cachefile";

## my $in_memory_query = '';
  ## hash string for the query that is currently in the @ku, etc. arrays.

##
## The XProfiler cache is necessarily different from the Summarizer
## cache. One can spec a given summary table with a handful of parameters,
## so it is not difficult to see if a current query for a given summary
## table is the same as a query whose resulting summary table is already
## cached. In contrast, the XProfiler operates on two library sets,
## each of which could be any subset of the entire set of libraries for
## an organism. Hence it is, in general,  not practical to check whether
## a current query is a repeat of a cached query. However, it is possible
## to associate a unique (for the current life of this GLServer process)
## id with each XProfiler query. Subsequent requests for cells in a
## XProfiler table can key off this unique id. But it does not make sense
## to preserve the data associated with a given unique id for long. The
## life of such cached data is essentially no longer than the life of
## the XProfiler table (for a given query) in the browser of the user.
## So we just need to cache a few (say, 5) of these. At present, we will
## cache only 1, and that only in memory.
##

## my $xprofile_cache_id = 0;

## $xprofile_cache_valid will be set to 0 after each call to
## GetSummaryTable or ListSummarizedGenes. It will be set to 1 after
## each call to GetXProfile.

## my $xprofile_cache_valid = 0;

my %hs_gl_data;
my %mm_gl_data;

######################################################################
sub InitializeDatabase {
  my ($org) = @_;
  my $gene;
  my $lib;
  my $hash_ref;
  my $cur_lib_ref;
  my ($ku, $uu, $kn, $un);

  $cache = new Cache(CACHE_ROOT, GL_CACHE_PREFIX);

  ## for $org ("Hs", "Mm") {
  if ($org eq "Hs") {
    open INPF, HS_GL_DATA or die "Cannot open HS_GL_DATA\n";
    $hash_ref = \%hs_gl_data;

  } else {
    open INPF, MM_GL_DATA or die "Cannot open MM_GL_DATA\n";;
    $hash_ref = \%mm_gl_data;
  }
  while (<INPF>) {
    chop;
    if (/^\d/) {
      $gene = $_;
      if ($ku)    { push @{ $$cur_lib_ref[0] }, $gene; }
      elsif ($uu) { push @{ $$cur_lib_ref[1] }, $gene; }
      elsif ($kn) { push @{ $$cur_lib_ref[2] }, $gene; }
      elsif ($un) { push @{ $$cur_lib_ref[3] }, $gene; }
      next;
    }
    if (/^(>lib)( +)(\d+)/) {
      $lib = $3;
      $$hash_ref{$lib} = [];
      $cur_lib_ref = \@{ $$hash_ref{$lib} };
      $$cur_lib_ref[0] = [];
      $$cur_lib_ref[1] = [];
      $$cur_lib_ref[2] = [];
      $$cur_lib_ref[3] = [];
      next;
    }
    if (/^>ku/) { $ku = 1; $uu = 0; $kn = 0; $un = 0; next; }
    if (/^>uu/) { $ku = 0; $uu = 1; $kn = 0; $un = 0; next; }
    if (/^>kn/) { $ku = 0; $uu = 0; $kn = 1; $un = 0; next; }
    if (/^>un/) { $ku = 0; $uu = 0; $kn = 0; $un = 1; next; }
  }
  close INPF;
  ## }

}

######################################################################
sub GetFileIdFromCache {
  my ($hash_str) = @_;
  my ($high_fname, $fname, $fhash, $found_fname, @entries, $e);
  my $valid = 0;
  if (-e CACHE_ID_FILE) {
    $high_fname = 0;
    open CF, CACHE_ID_FILE or return (undef, undef);
    while (<CF>) {
      chop;
      $e = $_;
      ($fhash, $fname) = split "\001";
      if ($fhash eq $hash_str) {
        $found_fname = $fname;
        $valid = 1;
      } else {
        push @entries, $e;
      }
      if (int($fname) > int($high_fname)) {
        $high_fname = $fname;
      }
    }
    ##
    ## @entries holds entire file except possibly for an entry
    ## with ($fhash eq $hash_str), in which case $found_fname holds
    ## the name of the associated file.
    ##
    if ($valid) {
      $fname = $found_fname;
    } else {
      if (int($high_fname) >= int(MAX_CACHE)) {
        (my $dummy, $fname) = split "\001", (pop @entries);
      } else {
        $fname = $high_fname + 1;
      }
    }
    close CF;
    open CF, (">" . CACHE_ID_FILE) or return (undef, undef);
    print CF "$hash_str\001$fname\n";
    for $e (@entries) {
      print CF "$e\n";
    }
    close CF;
    chmod 0666, CACHE_ID_FILE;
  } else {
    open CF, (">" . CACHE_ID_FILE) or return (undef, undef);
    $fname = '1';
    print CF "$hash_str\001$fname\n";
    close CF;
    chmod 0666, CACHE_ID_FILE;
  }
  return (CACHE_ROOT . "$fname", $valid);
}

######################################################################
sub WriteOneRowToCache {
  my ($part, $ku, $uu, $kn, $un) = @_;
  my $gene;

  print CF ">part\n";
  print CF ">ku\n";
  for $gene (@{ ${$ku}[$part] }) {
    print CF "$gene\n";
  }
  print CF ">uu\n";
  for $gene (@{ ${$uu}[$part] }) {
    print CF "$gene\n";
  }
  print CF ">kn\n";
  for $gene (@{ ${$kn}[$part] }) {
    print CF "$gene\n";
  }
  print CF ">un\n";
  for $gene (@{ ${$un}[$part] }) {
    print CF "$gene\n";
  }
}

######################################################################
sub WriteCache {
  my ($fname, $hash, $ku, $uu, $kn, $un, $global_idx) = @_;
  my ($part);

  open CF, ">$fname" or return undef;

  ##
  ## Write the hash so that a cache_id_file could be reconstructed
  ##
  print CF ">id $hash\n";

  for ($part = 0; $part <= $global_idx; $part++) {
    WriteOneRowToCache($part, $ku, $uu, $kn, $un);
  }
  close CF;
  chmod 0666, $fname;
}

######################################################################
sub ReadCache {
  my ($fname) = @_;

  ## Retrieve the named cache file.
  ## If the file cannot be opened, return undef.
  ## Otherwise, fill the global arrays (@ku, @uu, @kn, @un)
  ## and return the highest index of these arrays.

  my ($known, $unique, $gene);
  my @ku;
  my @uu;
  my @kn;
  my @un;

  my $idx = -1;

  ##
  ## just ignore a ">id" record; it simply records the hash
  ## (back link into cach_if_file)
  ##

  open CF, $fname or return undef;
  while (<CF>) {
    chop;
    if (/^\d/) {
      $gene = $_;
      if ($unique) {
        if ($known) {
          push @{ $ku[$idx] }, $gene;
        } else {
          push @{ $uu[$idx] }, $gene;
        }
      } else {
        if ($known) {
          push @{ $kn[$idx] }, $gene;
        } else {
          push @{ $un[$idx] }, $gene;
        }
      }
    }
    if (/^>part/) {
      $idx++;
    }

    if (/^>ku/) { $known = 1; $unique = 1; $ku[$idx] = []; next; }
    if (/^>uu/) { $known = 0; $unique = 1; $uu[$idx] = []; next; }
    if (/^>kn/) { $known = 1; $unique = 0; $kn[$idx] = []; next; }
    if (/^>un/) { $known = 0; $unique = 0; $un[$idx] = []; next; }

  }

  close CF;
  if ($idx < 0) {
    return undef;
  } else {
    return (\@ku, \@uu, \@kn, \@un);
  }

}

######################################################################
sub MapGenesToLibPartition {
  my ($org1, $scope1, $title1, $type1, $tissue1, $hist1, $prot1,
      $sort1, $partition) = @_;

##  my $build1 = ($org1 eq "Hs" ? UG_HS_BUILD : UG_MM_BUILD);
  my $build1 = $BUILDS{$org1};

  my $hash_str = join "|", ($build1, $org1, $scope1, $title1, $type1,
      $tissue1, $hist1, $prot1, $sort1);

  my $valid;

  ## if ($hash_str eq $in_memory_query) {
    ## pick size of one of the arrays (all have same size)
  ##   return scalar(@ku);
  ## }

  my @label;
  my @seq_count;
  my @lib_count;
  my $lib_count_total;
  my $seq_count_total;

  ## Param $partition
  ##    partition ::= <list of part>
  ##    part ::= <label> <seq_count> <set of ug_lid>
  ## Label and seq_count for "union" are *not* present in $partition

  my $row = 0;
  my ($p, $part, @temp, @libset);
  for $p (split "\001", $partition) {
    ($label[$row], $seq_count[$row], $part) = split "\002", $p;
    @temp = split "\003", $part;
    $lib_count[$row] = scalar(@temp);
    $lib_count_total = $lib_count_total + $lib_count[$row];
    $seq_count_total = $seq_count_total + $seq_count[$row];
    push @libset, (join "\002", @temp);
    $row++;
  }

  my ($fname, $valid) = GetFileIdFromCache($hash_str);
  if ($valid) {
    my @temp_ref = ReadCache($fname);
    if ( scalar(@temp_ref) > 1 ) {
      ## $in_memory_query = $hash_str;
      unshift @label, "<b><i>Union</i></b>";
      unshift @seq_count, $seq_count_total;
      unshift @lib_count, $lib_count_total;
      return ($temp_ref[0], $temp_ref[1], $temp_ref[2], $temp_ref[3],
              \@label, \@seq_count, $lib_count_total, $seq_count_total,
              \@lib_count);
    } else {
      ## invalidate in-memory cache
      ## $in_memory_query = "";
      print STDERR "GLServer: error reading cache\n";
      die "Error: error reading cache";
    }
  }

  ## Either it was not thought to be in cache or was thought to be
  ## but could not be read. Either way, compute from scratch.

  InitializeDatabase($org1);

  my @temp_ref = &MapGenesToLibPartitionFromScratch(
                                         $org1, (join "\001", @libset));
  unshift @label, "<b><i>Union</i></b>";
  unshift @seq_count, $seq_count_total;
  unshift @lib_count, $lib_count_total;
  ## $in_memory_query = $hash_str;
  WriteCache($fname, $hash_str, $temp_ref[0], $temp_ref[1], 
             $temp_ref[2], $temp_ref[3], $temp_ref[4]);

  return ($temp_ref[0], $temp_ref[1], $temp_ref[2], $temp_ref[3],
          \@label, \@seq_count, $lib_count_total, $seq_count_total,
          \@lib_count);

}

######################################################################
sub MapGenesToLibPartitionFromScratch {

#
# Input is a set U of sets of UniGene library ids.
# A given library id occurs in at most one of the given subsets LS[i] in U.
#
# --- non-unique ---
# For each LS[i] in U, compute the set of genes G[i] such that each gene in
# G[i] is in at least one library in LS[i] and is also in some library
# that is not in LS[i] (may be in a different partition or in the complement)
#
# --- unique ---
# For each LS[i] in U, compute the set of genes G[i] such that each gene in
# G[i] is in at least one library in LS[i] and is not in any library
# that is not in LS[i].
#
# --- "global non-unique" ---
# For the set of all libraries in U, compute the set of genes G such
# that each gene in G is in at least one library in U and is also in some
# library that is not in U (i.e., is in the complement).
#
# --- "global unique" ---
# For the set of all libraries in U, compute the set of genes G such
# that each gene in G is in at least one library in U and is not in any
# library that is not in U.


  my ($org, $libsets) = @_;

  my @ku;      ## known unique 
  my @uu;      ## unknown unique 
  my @kn;      ## known non-unique 
  my @un;      ## unknown non-unique 

  my %complement;
  my @partitions;
  my %partition_idx;
  my %num_partitions;
  my %known;

  my $global_idx;

  ## invalidate in-memory cache
  ## $in_memory_query = "";

  ##
  ## Construct a partial function partition_idx: library_id -> Z
  ##

  my ($i, $j, $ii);

  ## Explicit initialization needed for defined value
  $ii = 0;

  for $i (split("\001", $libsets)) {
    for $j (split("\002", $i)) {
      $partition_idx{$j} = $ii;
    }
    $partitions[$ii] = {};
    $ku[$ii]     = [];
    $uu[$ii]     = [];
    $kn[$ii]     = [];
    $un[$ii]     = [];
    $ii++;
  }

  ##
  ## Make a phoney "global partition" to represent the union
  ##

  $global_idx = $ii;
  $ku[$global_idx]     = [];
  $uu[$global_idx]     = [];
  $kn[$global_idx]     = [];
  $un[$global_idx]     = [];


  my @temp_ref = &ReadGLData($org, \@ku, \@uu, \@kn, \@un, 
                       \%partition_idx, \@partitions, $global_idx);

  %complement = %{$temp_ref[0]};
  %num_partitions = %{$temp_ref[1]};
  %known = %{$temp_ref[2]};
	

  my $p_idx;
  my ($gene, $val);

  ##
  ## Make the final lists for each partition.
  ## Genes unique to one library have already been put on the
  ## global list and the correct partition list
  ##

  for ($p_idx = 0; $p_idx < $global_idx; $p_idx++) {
    while (($gene, $val) = each %{ $partitions[$p_idx] }) {
      if ($num_partitions{$gene} == 1) {
        PlaceGeneOnList($p_idx, (not defined $complement{$gene}), $gene, 
                                       \@ku, \@uu, \@kn, \@un, \%known);
      } else {         ## num_partitions > 1
        PlaceGeneOnList($p_idx, 0, $gene, \@ku, \@uu, \@kn, \@un, \%known);
      }
    }
  }

  ##
  ## Make the final "global" lists.
  ## %num_partitions holds each gene that (a) is not unique to
  ## a single library, and (b) is in at least one library in U.
  ## We will walk %num_partitions to fill out "global"
  ##

  while (($gene, $val) = each %num_partitions) {
    PlaceGeneOnList($global_idx, (not defined $complement{$gene}), $gene, 
                                        \@ku, \@uu, \@kn, \@un, \%known);
  }

  ##
  ## Now, put the global lists in front of others (at [0])
  ##
  unshift @ku, (pop @ku);
  unshift @uu, (pop @uu);
  unshift @kn, (pop @kn);
  unshift @un, (pop @un);

  return (\@ku, \@uu, \@kn, \@un, $global_idx);

}

######################################################################
sub PlaceGeneOnList {
  my ($idx, $unique, $gene, $ku, $uu, $kn, $un, $known) = @_;

  if (${$known}{$gene}) {
    if ($unique) {
      push @{ ${$ku}[$idx] }, $gene;
    } else {
      push @{ ${$kn}[$idx] }, $gene;
    }
  } else {
    if ($unique) {
      push @{ ${$uu}[$idx] }, $gene;
    } else {
      push @{ ${$un}[$idx] }, $gene;
    }
  }
}

######################################################################
sub ReadGLData {

  my ($org, $ku_ref, $uu_ref, $kn_ref, $un_ref, $parti_idx, 
      $partitions, $global_idx) = @_;

  my %partition_idx = %{$parti_idx};

  my %complement;
  my %num_partitions;

  my $p_idx;
  my $unique;
  my $gene;
  my ($lib, $data);
  my $hash_ref;
  my $gl_ref;
  my %known;

  if ($org eq "Hs") {
    $gl_ref = \%hs_gl_data;
  } else {
    $gl_ref = \%mm_gl_data;
  }
  while (($lib, $data) = each %{ $gl_ref }) {
    if (defined $partition_idx{$lib}) {
      $p_idx = $partition_idx{$lib};
      $hash_ref = \%{ ${$partitions}[$p_idx] };
      for $gene (@{ $$data[0] }) {         ## ku
        $known{$gene} = 1;
        PlaceGeneOnList($p_idx,      1, $gene, 
                        $ku_ref, $uu_ref, $kn_ref, $un_ref, \%known);

        PlaceGeneOnList($global_idx, 1, $gene, 
                        $ku_ref, $uu_ref, $kn_ref, $un_ref, \%known);
      }
      for $gene (@{ $$data[1] }) {         ## uu
        PlaceGeneOnList($p_idx,      1, $gene, 
                        $ku_ref, $uu_ref, $kn_ref, $un_ref, \%known);

        PlaceGeneOnList($global_idx, 1, $gene, 
                        $ku_ref, $uu_ref, $kn_ref, $un_ref, \%known);
      }
      for $gene (@{ $$data[2] }) {         ## kn
        $known{$gene} = 1;
        if (not defined $$hash_ref{$gene}) {
          $$hash_ref{$gene} = 1;
          $num_partitions{$gene}++;
        }
      }
      for $gene (@{ $$data[3] }) {         ## un
        if (not defined $$hash_ref{$gene}) {
          $$hash_ref{$gene} = 1;
          $num_partitions{$gene}++;
        }
      }
    } else {
      ## if unique and in complement, blow it off
      ## just do non-uniques here
      for $gene (@{ $$data[2] }) {         ## kn
        $complement{$gene} = 1;
      }
      for $gene (@{ $$data[3] }) {         ## un
        $complement{$gene} = 1;
      }
    }
  }

  return (\%complement, \%num_partitions, \%known);
}

######################################################################
sub WrapGenesCell {
  my ($what, $val, $row, $common_params) = @_;
  if ($val) {

      return (
        "<td><a href=\"$BASE/Genes/ListSummarizedGenes?" .
        "$common_params&" .
        "PAGE=1&ROW=$row&WHAT=$what\">" . $val . "</a></td>" 
        );
  } else {
    return "<td>0</td>";
  }
}

######################################################################
sub GetSummaryTable_1 {
  my ($base, $org1, $scope1, $title1, $type1, $tissue1, $hist1, $prot1,
      $sort1, $partition) = @_;

  GetBuildIDs(\%BUILDS);
 
  ## InitializeDatabase($org1);

  $BASE = $base;
  
  my $hs_bld = $BUILDS{'Hs'};  $hs_bld =~ s/^1//;
  my $mm_bld = $BUILDS{'Mm'};  $mm_bld =~ s/^2//;

  my $params =
      ($org1    ? "$org1;"    : "") .
      ($scope1  ? "$scope1;"  : "") .
      ($title1  ? "$title1;"  : "") .
      ($type1   ? "$type1;"   : "") .
      ($tissue1 ? "$tissue1;" : "") .
      ($hist1   ? "$hist1;"   : "") .
      ($prot1   ? "$prot1;"   : "");

  $params =~ s/(;)([^\s])/$1 $2/g;

  my $page_header = "<table>" .
      "<tr valign=top><td><b>Query:</b></td>\n" .
      "<td>$params</td></tr>\n" .     
      "<tr valign=top><td><b>Summarize by:</b></td>\n" .
      "<td>$sort1</td></tr>\n" .     
      "<tr valign=top><td><b>UniGene build:</b></td>\n" .
      "<td>Hs.$hs_bld/Mm.$mm_bld</td></tr>\n" .     
      "</table>\n";

  if ($partition =~ /^\s*$/) {
    return "";
  }

  my (@temp_ref) = &MapGenesToLibPartition($org1, $scope1, $title1, 
              $type1, $tissue1, $hist1, $prot1, $sort1, $partition);

  my @ku              = @{$temp_ref[0]};
  my @uu              = @{$temp_ref[1]};
  my @kn              = @{$temp_ref[2]};
  my @un              = @{$temp_ref[3]};
  my @label           = @{$temp_ref[4]};
  my @seq_count       = @{$temp_ref[5]};
  my $lib_count_total = $temp_ref[6];
  my $seq_count_total = $temp_ref[7];
  my @lib_count       = @{$temp_ref[8]};

  ## $xprofile_cache_valid = 0;

  my $common_params = 
      "ORG=$org1&" .
      "SCOPE=$scope1&" .
      "TITLE=$title1&" .
      "TYPE=$type1&" .
      "TISSUE=$tissue1&" .
      "HIST=$hist1&" .
      "PROT=$prot1&" .
      "SORT=$sort1";
  $common_params =~ s/ /+/g;

  my $table_tag =
      "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr bgcolor=\"#666699\">" .
      "<td rowspan=2><font color=\"white\"><b>Subset</b></font></td>" .
      "<td rowspan=2><font color=\"white\"><b>Libraries</b></font></td>" .
      "<td rowspan=2><font color=\"white\"><b>Sequences</b></font></td>" .
      "<td colspan=2><font color=\"white\"><b>Unique Genes</b></font></td>" .
      "<td colspan=2><font color=\"white\"><b>Non-Unique Genes</b></font></td>" .
      "</tr>\n" .
      "<tr bgcolor=\"#666699\">" .
      "<td><font color=\"white\"><b>Known</b></font></td>" .
      "<td><font color=\"white\"><b>Unknown</b></font></td>" .
      "<td><font color=\"white\"><b>Known</b></font></td>" .
      "<td><font color=\"white\"><b>Unknown</b></font></td>" .
      "</tr>\n" ;

  my $s = "<h4>$page_header</h4>" . $table_tag;

  my ($n_ku, $n_uu, $n_kn, $n_un, $row);

  my @formatted_rows;
  my $row_count = 0;
  for ($row = 0; $row < scalar(@label); $row++) {

    $n_ku = scalar(@{ $ku[$row] });
    $n_uu = scalar(@{ $uu[$row] });
    $n_kn = scalar(@{ $kn[$row] });
    $n_un = scalar(@{ $un[$row] });

    $formatted_rows[$row] =
        "<tr>" .
        "<td>$label[$row]</td>" .
        "<td><a href=\"ListSummarizedLibraries?" .
        "$common_params&PAGE=1&ROW=$row\">" .
            "$lib_count[$row]</a></td>" .
        "<td>$seq_count[$row]</td>" .
        WrapGenesCell("ku", $n_ku, $row, $common_params) .
        WrapGenesCell("uu", $n_uu, $row, $common_params) .
        WrapGenesCell("kn", $n_kn, $row, $common_params) .
        WrapGenesCell("un", $n_un, $row, $common_params) .
        "</tr>\n";
    if (++$row_count % ROWS_PER_SUBTABLE == 0 and $row_count < scalar(@label)) {
      $formatted_rows[$row] = $formatted_rows[$row] . "</table>\n$table_tag";
    }
  }

  return ($s . join("", @formatted_rows) . "</table>");

}

######################################################################
sub ListSummarizedGenes_1 {
  my ($row1, $what1, $org1, $scope1, $title1, $type1,
      $tissue1, $hist1, $prot1, $sort1, $partition) = @_;

  my $items_ref;

  GetBuildIDs(\%BUILDS);
 
  ## InitializeDatabase($org1);

  my $cmd = "ListSummarizedGenes?" .
      "ROW=$row1&" .
      "WHAT=$what1&" .
      "ORG=$org1&" .
      "SCOPE=$scope1&" .
      "TITLE=$title1&" .
      "TYPE=$type1&" .
      "TISSUE=$tissue1&" .
      "HIST=$hist1&" .
      "PROT=$prot1&" .
      "SORT=$sort1";
  ## $cmd =~ s/ /+/g;

  my $nice_what =
      $what1 eq "ku" ? "known, unique"     :
      $what1 eq "uu" ? "unknown, unique"   :
      $what1 eq "kn" ? "known, non-unique" :
                       "unknown, non-unique";

  my $hs_bld = $BUILDS{'Hs'};  $hs_bld =~ s/^1//;
  my $mm_bld = $BUILDS{'Mm'};  $mm_bld =~ s/^2//;

  my $params =
      ($org1    ? "$org1;"    : "") .
      ($scope1  ? "$scope1;"  : "") .
      ($title1  ? "$title1;"  : "") .
      ($type1   ? "$type1;"   : "") .
      ($tissue1 ? "$tissue1;" : "") .
      ($hist1   ? "$hist1;"   : "") .
      ($prot1   ? "$prot1;"   : "");

  $params =~ s/(;)([^\s])/$1 $2/g;

  my (@temp_ref) = &MapGenesToLibPartition($org1, $scope1, $title1, $type1,
      $tissue1, $hist1, $prot1, $sort1, $partition);

  my @ku              = @{$temp_ref[0]};
  my @uu              = @{$temp_ref[1]};
  my @kn              = @{$temp_ref[2]};
  my @un              = @{$temp_ref[3]};
  my @label           = @{$temp_ref[4]};
  my @seq_count       = @{$temp_ref[5]};
  my $lib_count_total = $temp_ref[6];
  my $seq_count_total = $temp_ref[7];

  my $row_label = $label[$row1];
  ## get rid of formatting
  $row_label =~ s/<\/?[bi]>//g;
 
  my $page_header = "<table>" .
      "<tr valign=top><td><b>Query:</b></td>\n" .
      "<td>$params</td></tr>\n" .
      "<tr valign=top><td><b>Summarize by:</b></td>\n" .
      "<td>$sort1</td></tr>\n" .
      "<tr valign=top><td><b>Table cell:</b></td>\n" .
      "<td>$row_label, $nice_what</td></tr>\n" .
      "<tr valign=top><td><b>UniGene build:</b></td>\n" .
      "<td>Hs.$hs_bld/Mm.$mm_bld</td></tr>\n" .
      "</table>\n";

  ## $xprofile_cache_valid = 0;

  if ($what1 eq "ku") {
    $items_ref = $ku[$row1];
  } elsif ($what1 eq "uu") {
    $items_ref = $uu[$row1];
  } elsif ($what1 eq "kn") {
    $items_ref = $kn[$row1];
  } elsif ($what1 eq "un") {
    $items_ref = $un[$row1];
  } else {
    return "Bad request<br><br>\n";
  }
  if (@{ $items_ref } > 0) {
    return join "\001", (
        $cmd,
        $page_header,
        (join "\002", @{ $items_ref })
     );
  } else {
    SetStatus(S_NO_DATA);
    return "There are no genes matching the query<br><br>\n";
  }

}

######################################################################
sub ListXProfiledGenes_1 {
  my ($base, $cache_id, $page, $org, $row, $what) = @_;

  $BASE = $base;

  GetBuildIDs(\%BUILDS);
 
  InitializeDatabase($org);

  my $cmd = "$base/Genes/XProfiledThings?CACHE=$cache_id&ORG=$org&ROW=$row&WHAT=$what";
  my ($gref, $query, $header, $filename);

  if( ($filename = $cache->FindCacheFile($cache_id)) eq $CACHE_FAIL ) {
    return "Error: The data are missing, please go back to 'Pool A and B setup for Expression XProfiler' page and submit query again.<br><br>\n";
  }


  my @order;
  my @ku;      ## known unique
  my @uu;      ## unknown unique
  my @kn;      ## known non-unique
  my @un;      ## unknown non-unique
  my (@tempku, @tempuu, @tempkn, @tempun);

  
  open( GLIN,   "$filename" ) or die "Can't open $filename.";
  while (<GLIN>) {
     (@order) = split "\001";
  }     

  (@tempku) = split "\002", $order[0]; 
  (@tempuu) = split "\002", $order[1]; 
  (@tempkn) = split "\002", $order[2]; 
  (@tempun) = split "\002", $order[3]; 

  (@ku) =  split "\003", $tempku[$row];
  (@uu) =  split "\003", $tempuu[$row];
  (@kn) =  split "\003", $tempkn[$row];
  (@un) =  split "\003", $tempun[$row];

  if    ($what eq "ku") {
    $gref = \@ku;
    $query = "Known, Unique";
  } elsif ($what eq "uu") {
    $gref = \@uu; 
    $query = "Unknown, Unique";
  } elsif ($what eq "kn") {
    $gref = \@kn;
    $query = "Known, Non-Unique";
  } elsif ($what eq "un") {
    $gref = \@un;
    $query = "Unknown, Non-Unique";
  }

  my $hs_bld = $BUILDS{'Hs'};  $hs_bld =~ s/^1//;
  my $mm_bld = $BUILDS{'Mm'};  $mm_bld =~ s/^2//;

  my @labels = ("A or B", "A", "B", "A and B", "A minus B", "B minus A");
  $header = "<table>" .
      "<tr valign=top><td><b>Table cell:</b></td>\n" .
      "<td>$labels[$row], $query</td></tr>\n" .     
      "<tr valign=top><td><b>UniGene build:</b></td>\n" .
      "<td>Hs.$hs_bld/Mm.$mm_bld</td></tr>\n" .     
      "</table>\n";

  if (@{ $gref } > 0) {
    return join("\001", ($cmd, $header, (join "\002", @{ $gref })));
  } else {
    return "Error: There are no genes matching the query<br><br>\n";
  }

}

######################################################################
sub WrapProfileCell {
  my ($what, $row, $text) = @_;

##  ## Handle "A-B Unique" and "B-A Unique" differently
##  if (($row == 4 or $row == 5) and ($what eq "ku" or $what eq "uu")) {
##    return "<td>-</td>";
##  }

  if (int($text) > 0) {
    return "<td><a href=\"javascript:document.xpf.WHAT.value=\'$what\';" .
        "document.xpf.ROW.value=$row;" .
        "document.xpf.submit()\">$text</a></td>";
  } else {
    return "<td>$text</td>";
  }

}

######################################################################
sub ArrayArrayUnion {
  my ($a_ref, $b_ref) = @_;
  my %union;
  for my $x (@{ $a_ref }) {
    $union{$x} = 1;
  }
  for my $x (@{ $b_ref }) {
    $union{$x} = 1;
  }
  return \%union;
}

######################################################################
sub ArrayArrayDifference {
  my ($a_ref, $b_ref, $diff_ref) = @_;
  my (%temp);
  my ($x);
  for $x (@{ $b_ref }) {
    $temp{$x} = 1;
  }
  for $x (@{ $a_ref }) {
    if (not defined $temp{$x}) {
      push @{ $diff_ref }, $x;
    }
  }
}

######################################################################
sub A_Inter_B_All {

  my ($ku, $uu, $kn, $un) = @_; 

  my ($temp_ref, %known, %unknown);
  my $x;

  ##
  ## Known
  ##
  $temp_ref = ArrayArrayUnion(\@{ ${$ku}[1] }, \@{ ${$kn}[1] });
  for $x (@{ ${$ku}[2] }) {
    if (exists $$temp_ref{$x}) {
      $known{$x} = 1;
    }
  }
  for $x (@{ ${$kn}[2] }) {
    if (exists $$temp_ref{$x}) {
      $known{$x} = 1;
    }
  }

  ##
  ## Unknown
  ##
  $temp_ref = ArrayArrayUnion(\@{ ${$uu}[1] }, \@{ ${$un}[1] });
  for $x (@{ ${$uu}[2] }) {
    if (exists $$temp_ref{$x}) {
      $unknown{$x} = 1;
    }
  }
  for $x (@{ ${$un}[2] }) {
    if (exists $$temp_ref{$x}) {
      $unknown{$x} = 1;
    }
  }

  return (\%known, \%unknown);
}

######################################################################
sub ArrayHashInter {
  my ($aref, $href) = @_;
  my %inter;
  for my $x (@{ $aref }) {
    if (exists $$href{$x}) {
      $inter{$x} = 1;
    }
  }
  return \%inter;
}

######################################################################
sub ComputeXProfile {
  my ($org, $a_set, $b_set) = @_;

  my @ku;      ## known unique
  my @uu;      ## unknown unique
  my @kn;      ## known non-unique
  my @un;      ## unknown non-unique
 
 
  my @temp_ref = &MapGenesToLibPartitionFromScratch($org,
      join ("\001", (join("\002", @{ $a_set }), join("\002", @{ $b_set })))); 

  @ku = @{$temp_ref[0]};
  @uu = @{$temp_ref[1]};
  @kn = @{$temp_ref[2]};
  @un = @{$temp_ref[3]};

  ## $xprofile_cache_valid = 1;

  ##
  ## Make A*B sets...
  ##   G in A*B All        <=> G in (A Unique + A Non-Unique) and
  ##                           G in (B Unique + B Non-Unique)
  ##   G in A*B Unique     <=> G in A+B Unique and
  ##                           G in A*B All
  ##   G in A*B Non-Unique <=> G in A+B Non-Unique and
  ##                           G in A*B All
  
  my ($ab_k_all, $ab_u_all) = A_Inter_B_All(\@ku, \@uu, \@kn, \@un);

  my $ab_ku = ArrayHashInter(\@{ $ku[0] }, $ab_k_all);
  my $ab_uu = ArrayHashInter(\@{ $uu[0] }, $ab_u_all);
  my $ab_kn = ArrayHashInter(\@{ $kn[0] }, $ab_k_all);
  my $ab_un = ArrayHashInter(\@{ $un[0] }, $ab_u_all);

  ## A+B has position 0
  ## A   has position 1
  ## B   has position 2
  ## Let:
  ##   A*B have position 3
  ##   A-B have position 4
  ##   B-A have position 5

  my ($i, $dummy);
  for $i (3, 4, 5) {
    $ku[$i] = []; $uu[$i] = []; $kn[$i] = []; $un[$i] = [];
  }
  while (($i, $dummy) = each %{ $ab_ku }) {
    push @{ $ku[3] }, $i;
  }
  while (($i, $dummy) = each %{ $ab_uu }) {
    push @{ $uu[3] }, $i;
  }
  while (($i, $dummy) = each %{ $ab_kn }) {
    push @{ $kn[3] }, $i;
  }
  while (($i, $dummy) = each %{ $ab_un }) {
    push @{ $un[3] }, $i;
  }

  ##
  ## Make difference sets...
  ##   A-B Unique is equivalent to A Unique ... don't make, just copy
  ##   B-A unique is equivalent to B Unique ... don't make, just copy
  ##   A-B Non-Unique      <=> G in A Non-Unique and
  ##                           G not in B Non-Unique

  ## First, A-B

  for $i (@{ $ku[1] }) {
    push @{ $ku[4] }, $i
  }
  for $i (@{ $uu[1] }) {
    push @{ $uu[4] }, $i
  }

  ArrayArrayDifference($kn[1], $kn[2], $kn[4]);
  ArrayArrayDifference($un[1], $un[2], $un[4]);

  ## Now, B-A

  for $i (@{ $ku[2] }) {
    push @{ $ku[5] }, $i
  }
  for $i (@{ $uu[2] }) {
    push @{ $uu[5] }, $i
  }

  ArrayArrayDifference($kn[2], $kn[1], $kn[5]);
  ArrayArrayDifference($un[2], $un[1], $un[5]);

  return (\@ku, \@uu, \@kn, \@un);

}

######################################################################
sub GetXProfile_1 {
  my ($base, $org, $a_set, $b_set) = @_;

  my @ku;      ## known unique
  my @uu;      ## unknown unique
  my @kn;      ## known non-unique
  my @un;      ## unknown non-unique

  my (@tempku, @tempuu, @tempkn, @tempun);

  $BASE = $base;

  GetBuildIDs(\%BUILDS);
 
  InitializeDatabase($org);

  my @a_set = split ",", $a_set;
  my @b_set = split ",", $b_set;

  my @temp_ref = &ComputeXProfile($org, \@a_set, \@b_set);
  @ku = @{$temp_ref[0]};
  @uu = @{$temp_ref[1]};
  @kn = @{$temp_ref[2]};
  @un = @{$temp_ref[3]};
   

  my $lib;

  ## $xprofile_cache_id++;

  my ($gl_cache_id, $filename) = $cache->MakeCacheFile();

  my $hiddens = 
      "<input type=hidden name=\"CACHE\" value=\"$gl_cache_id\">\n";
  $hiddens = $hiddens .
      "<input type=hidden name=\"PAGE\" value=\"1\">\n";
  $hiddens = $hiddens .
      "<input type=hidden name=\"ORG\" value=\"$org\">\n";
  $hiddens = $hiddens .
      "<input type=hidden name=\"WHAT\" value=\"\">\n";
  $hiddens = $hiddens .
      "<input type=hidden name=\"ROW\" value=\"\">\n";
  for $lib (@a_set) {
    $hiddens = $hiddens .
        "<input type=hidden name=\"A_$lib\" value=\"A\">\n";
  }
  for $lib (@b_set) {
    $hiddens = $hiddens .
        "<input type=hidden name=\"B_$lib\" value=\"B\">\n";
  }

  my $lib_hrefs = "<table><tr>" .
      "<td>Libraries in A:</td>" .
      WrapProfileCell("a_libs", 0, scalar(@a_set)) .
      "</tr><tr>" .
      "<td>Libraries in B:</td>" .
      WrapProfileCell("b_libs", 0, scalar(@b_set)) . "</tr></table>" . "<br>";

  my $gene_table =
      "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr bgcolor=\"#666699\">" .
      "<th rowspan=2><font color=\"white\"><b>Subset</b></font></th>" .
      "<th colspan=2><font color=\"white\"><b>Unique Genes</b></font></th>" .
      "<th colspan=2><font color=\"white\"><b>Non-Unique Genes</b></font></th>" .
      "</tr>\n" .
      "<tr bgcolor=\"#666699\">" .
      "<th><font color=\"white\"><b>Known</b></font></th>" .
      "<th><font color=\"white\"><b>Unknown</b></font></th>" .
      "<th><font color=\"white\"><b>Known</b></font></th>" .
      "<th><font color=\"white\"><b>Unknown</b></font></th>" .
      "</tr>\n" ;

  my @labels = ("A or B", "A", "B", "A and B", "A minus B", "B minus A");

  
  for my $row (1, 2, 0, 3, 4, 5) {
    $gene_table = $gene_table .
        "<tr><td>$labels[$row]</td>" .
        WrapProfileCell("ku", $row, scalar(@{ $ku[$row] })) . "\n" .
        WrapProfileCell("uu", $row, scalar(@{ $uu[$row] })) . "\n" . 
        WrapProfileCell("kn", $row, scalar(@{ $kn[$row] })) . "\n" .
        WrapProfileCell("un", $row, scalar(@{ $un[$row] })) . "</tr>\n";

    $tempku[$row] = join "\003", @{ $ku[$row] };   
    $tempuu[$row] = join "\003", @{ $uu[$row] };   
    $tempkn[$row] = join "\003", @{ $kn[$row] };   
    $tempun[$row] = join "\003", @{ $un[$row] };   
  }

  $gene_table = $gene_table . "</table>";

  my $hs_bld = $BUILDS{'Hs'};  $hs_bld =~ s/^1//;
  my $mm_bld = $BUILDS{'Mm'};  $mm_bld =~ s/^2//;

  my $header = "<table>" .
      "<tr valign=top><td><b>UniGene build:</b></td>\n" .
      "<td>Hs.$hs_bld/Mm.$mm_bld</td></tr>\n" .     
      "</table>\n";

  my $s = $header .
      "<form name=\"xpf\" action=\"$BASE/Genes/XProfiledThings\" " .
      "method=POST>" .
      $hiddens . $lib_hrefs . $gene_table . "</form>";


  my $temp = join "\001", ( join "\002", @tempku), 
                          ( join "\002", @tempuu),
                          ( join "\002", @tempkn),
                          ( join "\002", @tempun);

  open( GLOUT,   ">$filename" ) or die "Can't open $filename.";
  printf GLOUT "%s", $temp;
  close GLOUT;


  return $s;
}

######################################################################
1;
