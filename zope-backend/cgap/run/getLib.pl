#!/usr/local/bin/perl

######################################################################
# Diff.pl
#
######################################################################

use strict;
use FileHandle;
use CGAPConfig;
use Paging;
## use ServerSupport;
use DBI;
##use chisquare;
use FisherExact;
## use Bayesian;

######################################################################

my $BASE;

use constant LOG2 => log(2);

##
## Translate "neoplasia" to "cancer", etc.
##

my %nice_organism = (
    "Hs"   => "Homo sapiens",
    "Mm"   => "Mus musculus",
);

my %nice_histology_name = (
    "normal"         => "normal",
    "preneoplasia"   => "pre-cancer",
    "neoplasia"      => "cancer",
    "uncharacterized histology" => "uncharacterized histology",
    "multiple histology"        => "multiple histology"
);     

my (%vn_lib_count, %vn_seq_count, %code2tiss);

my $LIBRARY_LIST_TABLE_HEADER = "<table border=1 cellspacing=1 cellpadding=4>" .
        "<tr bgcolor=\"#38639d\">" .
        "<td><font color=\"white\"><b>Title</b></font></td>" .
        "<td><font color=\"white\"><b>Tissue</b></font></td>" .
        "<td><font color=\"white\"><b>Histology</b></font></td>" .
        "<td><font color=\"white\"><b>Type</b></font></td>" .
        "<td><font color=\"white\"><b>Protocol</b></font></td>" .
        "<td><font color=\"white\"><b>Keywords</b></font></td>" .
        "</tr>";

my @tissue_types = (
    "adipose tissue",
    "adrenal cortex",
    "adrenal medulla",
    "bone",
    "bone marrow",
    "brain",
    "mammary gland",
    "cartilage",
    "cerebellum",
    "cerebrum",
    "cervix",
    "colon",
    "ear",
    "embryonic tissue",
    "endocrine",
    "esophagus",
    "eye",
    "gastrointestinal tract",
    "genitourinary",
    "germ cell",
    "head and neck",
    "heart",
    "kidney",
    "limb",
    "liver",
    "lung",
    "lymph node",
    "lymphoreticular",
    "mammary gland",
    "muscle",
    "nervous",
    "ovary",
    "pancreas",
    "pancreatic islet",
    "parathyroid",
    "peripheral nervous system",
    "pineal gland",
    "pituitary gland",
    "placenta",
    "prostate",
    "retina",
    "salivary gland",
    "skin",
    "soft tissue",
    "spleen",
    "stem cell",
    "stomach",
    "synovium",
    "testis",
    "thymus",
    "thyroid",
    "uterus",
    "vascular",
    "white blood cell",
    "uncharacterized tissue"
);

my ($base, $page, $org1, $scope1, $title1, $type1, $tissue1, $hist1,
    $prot1, $keys1, $sort1);

my %id2keyword;

InitializeDatabase();

## use constant RUNNING_$DB_INSTANCE => 'cgdev';
## use constant RUNNING_$DB_INSTANCE => 'cgprod';
## use constant $DB_INSTANCE => 'cgprod';
## my $scope1 = "cgap,mgc,orestes,est";
$page = 0;
$title1 = "NCI_CGAP_HN*";
$org1 = "Hs";
## for ( my $i=0; $i<@tissue_types; $i++ ) {
  print GetLibrary_1($base, $page, $org1, $scope1, $title1, $type1, $tissue1, $hist1,
      $prot1, $keys1, $sort1);
## }
$org1 = "Mm";
## for ( my $i=0; $i<@tissue_types; $i++ ) {
  print GetLibrary_1($base, $page, $org1, $scope1, $title1, $type1, $tissue1, $hist1,
      $prot1, $keys1, $sort1);
## }
 

######################################################################
sub UNILIB_URL {
  my ($org, $lid) = @_;
  return "http://www.ncbi.nlm.nih.gov/UniGene/library.cgi?ORG=$org&LID=$lid";
}

######################################################################
sub DividerBar {
  my ($title) = @_;
  return "<table width=95% cellpadding=2>" .
      "<tr bgcolor=\"#38639d\"><td align=center>" .
      "<font color=\"white\"><b>$title</b></font>" .
      "</td></tr></table>\n";
}

#####################################################################
sub InitializeDatabase {

  my ($sql, $stm);
  my ($src, $tissue_code, $tissue, $histology_code, $lib_count, $seq_count);
 
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }
 
  for my $org ("Hs", "Mm") {
    $sql =
        "select LIBRARY_ID, KEYWORD " .
        "from $CGAP_SCHEMA.library_keyword ";
 
## Accept only histology=1 (cancer) or histology=2 (normal)
## Accept only categories with seq_count >= 2000
 
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
      while(my ($id, $keyword) = $stm->fetchrow_array) {
        $id2keyword{$id}{$keyword} = 1;
      }
    }
 
  }
 
  $db->disconnect();

}

######################################################################
sub FormatOneLib {
  my ($what, $org, $info, $tissue) = @_;
  my ($lid, $title, $keys, $seqs, $ug_lid,
      $the_tiss, $the_hist, $the_prep, $the_prot) = split("\t", $info);

  $the_hist = $nice_histology_name{$the_hist};

  $the_tiss or $the_tiss = '-';
  $the_hist or $the_hist = '-';
  $the_prep or $the_prep = '-';
  $the_prot or $the_prot = '-';
  $keys or $keys = "";

  my $s;
  if ($what eq "HTML") {
    $s = "<tr valign=top>".
        "<td>" .
            "<a href=\"" . $BASE .
            "/Tissues/LibInfo?ORG=$org&LID=$lid\">$title</a>" .
        "</td>" . 
        "<td>" . $the_tiss  . "</td>" .
        "<td>" . $the_hist  . "</td>" .
        "<td>" . $the_prep  . "</td>" .
        "<td>" . $the_prot  . "</td>" .
        "<td>" . $keys      . "</td>" .
        "</tr>";
  } else {
    ## $s = "$title\t$tissue\t$the_hist\t$the_prep\t$the_prot\t$keys";
    ## $title =~ s/<br>//i;
    ## $s = "$org\t$tissue\t$title\t$keys";
    $s = $lid. "\t" . $title;
    for my $keyword ( sort keys %{$id2keyword{$lid}} ) {
      $s = $s . "\n\t$keyword";
    }
  }
  return $s;

}

######################################################################
sub FormatLibs {
  my ($page, $org, $cmd, $page_header, $items_ref, $tissue) = @_;

  if (scalar(@{ $items_ref }) == 0) {
    ## return "<h4>$page_header</h4><br><br>" .
    ##     "There are no libraries matching the query<br><br>";
  }
  if ($page < 1) {
    my $i;
    my $s;
    for ($i = 0; $i < scalar(@{ $items_ref }); $i++) {
      $s = $s . FormatOneLib("TEXT", $org, $$items_ref[$i], $tissue) . "\n";
    }
    return $s;
  } else {
    return PageResults($page, $org, $cmd, $page_header,
        $LIBRARY_LIST_TABLE_HEADER, \&FormatOneLib, $items_ref);
  }

}

######################################################################
sub BuildLibPage_1 {

  my ($base, $org, $lid) = @_;

  $BASE = $base;

  my ( 
    $library_id,
    $clones_date,
    $description,
    $ids_lib_tissue_sample,
    $keyword,
    $lab_host,
    $lib_name,
    $organism,
    $producer,
    $r_site1,
    $r_site2,
    $sequences_date,
    $strain,
    $tissue_desc,
    $tissue_supplier,
    $unigene_id,
    $vector,
    $vector_type,
    $the_tiss,
    $the_hist,
    $the_prep,
    $the_prot
  );

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }

  my $sql =
      "select * from $CGAP_SCHEMA.All_Libraries a " .
      "where a.library_id = $lid";

  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      ( 
        $library_id,
        $clones_date,
        $description,
        $ids_lib_tissue_sample,
        $keyword,
        $lab_host,
        $lib_name,
        $org,
        $producer,
        $r_site1,
        $r_site2,
        $sequences_date,
        $strain,
        $tissue_desc,
        $tissue_supplier,
        $unigene_id,
        $vector,
        $vector_type,
        $the_tiss,
        $the_hist,
        $the_prep,
        $the_prot
      ) = $stm->fetchrow_array();
      $stm->finish;
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  if ($library_id == 0) {
    $db->disconnect();
    return "Library not found";
  }

  my ($other_libs, $lid, $lname, @lines);

  if ($ids_lib_tissue_sample) {
    $sql = "select a.library_id, a.lib_name " .
        "from $CGAP_SCHEMA.All_Libraries a " .
        "where a.library_id in " .
        "('" . join("', '", split(" +", $ids_lib_tissue_sample)) . "')" .
        "and a.org = '$org'";
    my $stm = $db->prepare($sql);
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    } else {
      if ($stm->execute()) {
        while (($lid, $lname) = $stm->fetchrow_array()) {
          $other_libs .=
              "<br><a href=\"LibInfo?ORG=$org&LID=$lid\">" .
              "$lname</a>";
        }      
        $stm->finish;
        $other_libs =~ s/^<br>//;       ## remove leading separator
        $ids_lib_tissue_sample = $other_libs;
      } else {
        print "execute failed\n";
        $db->disconnect();
        return "";
      }
    }
  }

  $db->disconnect();

  push @lines, "<br>" . DividerBar("Library ID") . "<br>";
  push @lines, "<table>\n" .
    "<tr><td valign=top><b>Library Name:</b></td><td>$lib_name</td></tr>\n" .
    "<tr><td valign=top><b>Organism:</b></td><td>$nice_organism{$org}</td></tr>\n" .
    ($org eq "Mm" ?
        "<td valign=top><b>Strain:</b></td><td>$strain</td></tr>\n" :
        ""
    ) .
    ($keyword !~ /SAGE/ ? 
        ("<tr><td valign=top><b>UniGene Library ID:</b></td><td>" .
          "<a href=javascript:spawn(\"" .
          UNILIB_URL($org, $unigene_id) .
          "\")>$unigene_id</a></td></tr>\n")
        : "") .
    "<tr><td valign=top><b>Tissue Description:</b></td><td>$tissue_desc</td></tr>\n" .
    "<tr><td valign=top><b>Library Keywords:</b></td><td>$keyword</td></tr>\n" .
    "</table>";

  push @lines, "<br>" . DividerBar("Clones and Sequences") . "<br>";
  push @lines, "<table>\n" .
    "<tr><td valign=top><b>#Clones Generated to Date:</b></td>" .
        "<td>$clones_date</td></tr>\n" .
    "<tr><td valign=top><b>#" .
        ($keyword =~ /SAGE/ ? "Tags" : "Sequences") .
        " Generated to Date:</b></td>".
        "<td>$sequences_date</td></tr>\n" .
    "</table>";

  if ($ids_lib_tissue_sample) {
    push @lines, "<br>" . DividerBar("Other Libraries from Same Tissue Sample") .
       "<br>" . $ids_lib_tissue_sample . "<br>";
  }

  push @lines, "<br>" . DividerBar("Library Preparation Details") . "<br>";
  push @lines, "<table>\n" .
    "<tr><td valign=top><b>Description:</b></td><td>$description</td></tr>\n" .
    "<tr><td valign=top><b>R. Site1:</b></td><td>$r_site1</td></tr>\n" .
    "<tr><td valign=top><b>R. Site2:</b></td><td>$r_site2</td></tr>\n" .
    "<tr><td valign=top><b>Lab Host:</b></td><td>$lab_host</td></tr>\n" .
    "<tr><td valign=top><b>Vector:</b></td><td>$vector</td></tr>\n" .
    "<tr><td valign=top><b>Vector Type:</b></td><td>$vector_type</td></tr>\n" .
    "<tr><td valign=top><b>Tissue Supplier:</b></td><td>$tissue_supplier</td></tr>\n" .
    "<tr><td valign=top><b>Library Producer:</b></td><td>$producer</td></tr>\n" .
    "</table>";

  return join "\n", @lines;

}

######################################################################
sub GetLibrary_1 {
  my ($base, $page, $org1, $scope1, $title1, $type1, $tissue1, $hist1,
      $prot1, $keys1, $sort1) = @_;

  ## print "$tissue1<br>";
  $BASE = $base;

  my (@items, @info);

  my $tt = $tissue1;
  my $params = join "; ", ($org1, $scope1, $type1, $prot1, $tissue1, $hist1, $title1, $keys1);
  while ($params =~ /; ;/) {
    $params =~ s/; ;/;/g;
  }
  $params =~ s/; $//;

  my $page_header = "<table>\n" .
      "<tr align=top><td><b>Library Finder Query:</b></td><td>$params</td></tr>\n" .
      "<tr align=top><td><b>Order By:</b></td><td>$sort1</td></td>\n" .
      "</table>\n";

  SelectLibrarySet(\@items, \@info, $org1, $scope1, $title1, $type1,
      $tissue1, $hist1, $prot1, $keys1, $sort1, 0);

  if (scalar(@items) == 0) {
    ## return $page_header . "<br><br>" .
    ##     "There are no libraries matching the query<br><br>";
  } else {

  ##
  ## Set up for paging results
  ##
    my $cmd = "LibraryQuery?" .
        "ORG=$org1&" .
        "SCOPE=$scope1&" .
        "TITLE=$title1&" .
        "TYPE=$type1&" .
        "TISSUE=$tissue1&" .
        "HIST=$hist1&" .
        "PROT=$prot1&" .
        "KEYS=$keys1&" .
        "SORT=$sort1";

    return FormatLibs($page, $org1, $cmd, $page_header, \@info, $tt);

  }

}

###
### BEGIN OF GXS STUFF
###

######################################################################
sub GXSLibsOfCluster_1 {
  my ($base, $org, $cid, $lib_set) = @_;

  $BASE = $base;

  my @lib_set = split ",", $lib_set;
  if (@lib_set < 1) {
    return "No libraries found<br>";
  }
  my (%lib_set);
  for my $i (@lib_set) {
    $lib_set{$i} = 1;
  }

  my (@info);

  QueryLibsOfCluster($org, $cid, "est", \@info);

  if (@info < 1) {
    return "No libraries found<br>";
  }

  ## don't bother paging this stuff

  my (@lines);

  push @lines, $LIBRARY_LIST_TABLE_HEADER;

  my ($lid, $title, $keys, $seqs, $ug_lid, $the_tiss, $the_hist,
      $the_prep, $the_prot);

  for (@info) {
    ($lid, $title, $keys, $seqs, $ug_lid, $the_tiss, $the_hist,
        $the_prep, $the_prot) = split "\t";
    if (defined $lib_set{$ug_lid}) {
      push @lines, FormatOneLib("HTML", $org, $_);
    }
  }

  push @lines, "</table>";

  return join("\n", @lines);
}

######################################################################
sub GXSLibrarySelect_1 {
  my ($org, $scope, $min_seqs, $sort,
      $title_a,  $title_b,
      $type_a,   $type_b,
      $tissue_a, $tissue_b,
      $hist_a,   $hist_b,
      $prot_a,   $prot_b,
      $comp_a,   $comp_b) = @_;
  my (@set_a, @set_b);
  my (@info_a, @info_b, %both_info);

  ##
  ## following is wasteful (looping through all libraries twice)
  ##
  SelectLibrarySet(\@set_a, \@info_a, $org, $scope,
      $title_a, $type_a, $tissue_a, $hist_a, $prot_a, "", $sort, $comp_a);
  SelectLibrarySet(\@set_b, \@info_b, $org, $scope,
      $title_b, $type_b, $tissue_b, $hist_b, $prot_b, "", $sort, $comp_b);

  ##
  ## must return UniGene library ids
  ## also need a global (across a, b) ordering
  ## also need to check for duplicate entries, so put in a hash
  ##
  my (%set_a, %set_b, %both_info);
  my (@rows, $info);
  my ($lid, $title, $keys, $seqs, $ug_lid, $the_tiss, $the_hist,
      $the_prep, $the_prot);
  my ($idx, $i, $j, $A, $B);

  for ($i = 0; $i < @set_a; $i++) {
    ($lid, $title, $keys, $seqs, $ug_lid, $the_tiss, $the_hist,
        $the_prep, $the_prot) = split("\t", $info_a[$i]);
    if ((not $min_seqs) or ($min_seqs <= $seqs)) {
      $set_a{$set_a[$i]} = 1;
      if ($sort eq "title") {
        $idx = $title;
      } elsif ($sort eq "tissue") {
        $idx = $the_tiss;
      } elsif ($sort eq "histology") {
        $idx = $the_hist;
      } elsif ($sort eq "preparation") {
        $idx = $the_prep;
      } elsif ($sort eq "protocol") {
        $idx = $the_prot;
      }
      $both_info{$idx}{$lid} = $info_a[$i];
    }
  }
  for ($i = 0; $i < @set_b; $i++) {
    ($lid, $title, $keys, $seqs, $ug_lid, $the_tiss, $the_hist,
        $the_prep, $the_prot) = split("\t", $info_b[$i]);
    if ((not $min_seqs) or ($min_seqs <= $seqs)) {
      $set_b{$set_b[$i]} = 1;
      if ($sort eq "title") {
        $idx = $title;
      } elsif ($sort eq "tissue") {
        $idx = $the_tiss;
      } elsif ($sort eq "histology") {
        $idx = $the_hist;
      } elsif ($sort eq "preparation") {
        $idx = $the_prep;
      } elsif ($sort eq "protocol") {
        $idx = $the_prot;
      }
      $both_info{$idx}{$lid} = $info_b[$i];
    }
  }

  if (keys %both_info == 0) {
    return "";
  }

  for $j (sort keys %both_info) {
    while (($i, $info) = each %{ $both_info{$j} }) {
      $A = defined $set_a{$i} ? "A" : "";
      $B = defined $set_b{$i} ? "B" : "";
      ($lid, $title, $keys, $seqs, $ug_lid, $the_tiss, $the_hist,
          $the_prep, $the_prot) = split("\t", $info);
      push @rows, join("\002", $ug_lid,$i,$A,$B,$title,$seqs,$keys);
    }
  }
  return join("\001", @rows);
}

###
### END OF GXS STUFF
###

######################################################################
sub SelectLibrarySet {
  ## This does a "liberal" selection. That is, if tissue=liver
  ## is specified, it will select any library that has a keyword
  ## k such that IsKindOf($k, 'liver'), even if the library is also
  ## keyworded for tissues that are not 'liver').

  my ($items_ref, $info_ref, $org1, $scope1, $title1, $type1,
      $tissue1, $hist1, $prot1, $keys1, $sort1, $complement_tissue) = @_;
  my ($choices);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ##print STDERR "Cannot connect to " .$DB_USER . "\/" . $DB_INSTANCE . "<br>";
    ## print STDERR "$DBI::errstr" . "<br>";
    print "Cannot connect to database \n";
    return "";
  }

  my $sql =
      "select /*+ RULE */ distinct k.library_id, a.lib_name, a.keyword, " .
      "a.sequences_date, a.unigene_id, " .
      "a.the_tiss, a.the_hist, a.the_prep, a.the_prot " .
      "from $CGAP_SCHEMA.all_libraries a, $CGAP_SCHEMA.library_keyword k " .
      "where a.org = '$org1' " .
      "and a.library_id = k.library_id ";

  if ($title1) {
    my $uc_title = $title1;
    $uc_title =~ tr/A-Z/a-z/;
    $uc_title =~ s/\*/%/g;
    $sql .= " and lower(a.lib_name) like '%$uc_title%'";
  }

  if ($tissue1) {
    ## $choices = "('" . join("', '", split(",", $tissue1)). "')";
    my @tmp_keys = split(",", $tissue1);
    my @all_keys;
    for (my $i=0; $i<@tmp_keys; $i++) {
      ## push @all_keys, "'%" . $tmp_keys[$i] . "%'";
      push @all_keys, "'" . $tmp_keys[$i] . "'";
    }
    $choices = "(k1.keyword = "
                      . join(" or k1.keyword = ", @all_keys) . ")";
    $sql .= " and " . ($complement_tissue ? "not " : "") .
            "exists (select k1.library_id " .
        "from $CGAP_SCHEMA.library_keyword k1 " .
        "where k1.library_id = k.library_id and " .
        "$choices" . ")";
  }

  if ($scope1) {
    $choices = "('" . join("', '", split(",", $scope1)). "')";
    $sql .= " and exists (select k2.library_id " .
        "from $CGAP_SCHEMA.library_keyword k2 " .
        "where k2.library_id = k.library_id and " .
        "k2.keyword in $choices)"
  }

  if ($type1) {
    $choices = "('" . join("', '", split(",", $type1)). "')";
    $sql .= " and exists (select k3.library_id " .
        "from $CGAP_SCHEMA.library_keyword k3 " .
        "where k3.library_id = k.library_id and " .
        "k3.keyword in $choices)"
  }

  if ($hist1) {
    $choices = "('" . join("', '", split(",", $hist1)). "')";
    $sql .= " and exists (select k4.library_id " .
        "from $CGAP_SCHEMA.library_keyword k4 " .
        "where k4.library_id = k.library_id and " .
        "k4.keyword in $choices)"
  }

  if ($prot1) {
    $choices = "('" . join("', '", split(",", $prot1)). "')";
    $sql .= " and exists (select k5.library_id " .
        "from $CGAP_SCHEMA.library_keyword k5 " .
        "where k5.library_id = k.library_id and " .
        "k5.keyword in $choices)"
  }

  if ($keys1) {
    my $lc_keys = $keys1;
    $lc_keys =~ tr/A-Z/a-z/;
    $lc_keys =~ s/\*/%/g;
    ## $sql .= " and lower(k.keyword) like '%$lc_keys%'";
    $sql .= " and lower(k.keyword) = '$lc_keys'";
  }

  if ($sort1 eq "title") {
    $sql .= " order by a.lib_name"; 
  } elsif ($sort1 eq "tissue") {
    $sql .= " order by a.the_tiss"; 
  } elsif ($sort1 eq "histology") {
    $sql .= " order by a.the_hist"; 
  } elsif ($sort1 eq "preparation") {
    $sql .= " order by a.the_prep"; 
  } elsif ($sort1 eq "protocol") {
    $sql .= " order by a.the_prot"; 
  }

  my ($lid, $name, $keys, $seqs, $ug_lid, $the_tiss,
      $the_hist, $the_prep, $the_prot);

  ## print "8888: $sql";
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (
          ($lid, $name, $keys, $seqs, $ug_lid, $the_tiss,
              $the_hist, $the_prep, $the_prot) = $stm->fetchrow_array()) {
        push @{ $items_ref }, $lid;
        push @{ $info_ref }, join("\t",
          $lid, $name, $keys, $seqs, $ug_lid, $the_tiss, $the_hist, $the_prep,
          $the_prot);
        if( $lid eq "2901" ) {
          print "<br>8888: $lid, $name, $keys,<br>";
        }
      }      
      $stm->finish;
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  $db->disconnect();

}

######################################################################
sub GetPartition_1 {
  my ($org1, $scope1, $title1, $type1, $tissue1, $hist1, $prot1, $sort1)
      = @_;

  my (@items, @info, %partition, $partition_idx,
      @partition_order, %seq_counts, @temp);
  my ($lid, $title, $keys, $seqs, $ug_lid,
      $the_tiss, $the_hist, $the_prep, $the_prot);
  my ($i);

  SelectLibrarySet(\@items, \@info, $org1, $scope1, $title1, $type1,
      $tissue1, $hist1, $prot1, "", $sort1, 0);

  if (scalar(@items) == 0) {
    return "";
  }

  for ($i = 0; $i < @info; $i++) {
    ($lid, $title, $keys, $seqs, $ug_lid,
        $the_tiss, $the_hist, $the_prep, $the_prot) = split("\t", $info[$i]);


    ##
    ## use the fixed user view of library classes
    ##
    if ($sort1 eq 'tissue') {
      $partition_idx = $the_tiss;
    } elsif ($sort1 eq 'preparation') {
      $partition_idx = $the_prep;
    } elsif ($sort1 eq 'protocol') {
      $partition_idx = $the_prot;
    } elsif ($sort1 eq 'histology') {
      $partition_idx = $the_hist;
    } elsif ($sort1 eq 'title') {
      $partition_idx = $title;
    }
    push @{ $partition{$partition_idx} }, $ug_lid;
    $seq_counts{$partition_idx} = $seq_counts{$partition_idx} + $seqs;
  }

  my @partition_order = sort keys %partition;

  for $partition_idx (@partition_order) {
    push @temp,
        (join "\002",
            $partition_idx,
            $seq_counts{$partition_idx},
            (join "\003", @{ $partition{$partition_idx} })
        );
  }

  return (join "\001", @temp);
}

######################################################################
sub FormatLibraryList_1 {
  my ($base, $page, $org, $cmd, $header, $lib_set) = @_;

  $BASE = $base;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }

  my ($sql, $stm, @row, @rows, $i, $rn, %index, $list);
  my @libs = split ",", $lib_set;
 
  for($i = 0; $i < @libs; $i += 1000) {
    if(($i + 1000 - 1) < @libs) {
      $list = join(",", @libs[$i..$i+1000-1]);
    }
    else {
      $list = join(",", @libs[$i..@libs-1]);
    }

    $sql =
        "select distinct a.library_id, a.lib_name, a.keyword, " .
        "a.sequences_date, a.unigene_id, " .
        "a.the_tiss, a.the_hist, a.the_prep, a.the_prot " .
        "from $CGAP_SCHEMA.all_libraries a " .
        "where a.unigene_id in ($list) " .
        "and a.org = '$org'";

    $stm = $db->prepare($sql);
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    } else {
      if ($stm->execute()) {
        while (@row = $stm->fetchrow_array()) {
          push @rows, join("\t", @row);
          $index{lc($row[1])} = $rn++;
        }
        $stm->finish;
      } else {
        print "execute failed\n";
        $db->disconnect();
        return "";
      }
    }
  }

  $db->disconnect();

  my @sorted_rows;
  for (sort keys %index) {
    push @sorted_rows, $rows[$index{$_}];
  }

  if (@rows == 0) {
    return "Library not found";
  } else {
    return FormatLibs($page, $org, $cmd, $header, \@sorted_rows);
  }

}    

######################################################################
sub ListSummarizedLibraries_1 {
  my ($base, $page, $row1, $org1, $scope1, $title1, $type1, $tissue1,
      $hist1, $prot1, $sort1) = @_;

  $BASE = $base;

  my (@items, @info);
  my (%partition);
  my ($items_ref, $row_label, $i);
  my $row = $row1;
  my ($lid, $title, $keys, $seqs, $ug_lid,
      $the_tiss, $the_hist, $the_prep, $the_prot);

  SelectLibrarySet(\@items, \@info, $org1, $scope1, $title1, $type1,
      $tissue1, $hist1, $prot1, "", $sort1, 0);

  ##
  ## row1 == 0 means the union of all libraries in the selected set
  ##
  if ($row1 == 0) {
    $row_label = "Union";
    $items_ref = \@info;
  } else {

    ##
    ## From here on, $row will correspond to the index into partition array
    ##
    $row--;

    ##
    ## Must return CGAP library ids
    ##

    for ($i = 0; $i < @items; $i++) {
      ##
      ## use the fixed user view of library classes
      ##
      ($lid, $title, $keys, $seqs, $ug_lid,
          $the_tiss, $the_hist, $the_prep, $the_prot) = split("\t", $info[$i]);

      if ($sort1 eq 'tissue') {
        push @{ $partition{$the_tiss} }, $info[$i];
      } elsif ($sort1 eq 'preparation') {
        push @{ $partition{$the_prep} }, $info[$i];
      } elsif ($sort1 eq 'protocol') {
        push @{ $partition{$the_prot} }, $info[$i];
      } elsif ($sort1 eq 'histology') {
        push @{ $partition{$the_hist} }, $info[$i];
      } elsif ($sort1 eq 'title') {
        push @{ $partition{$title} }, $info[$i];
      }
    }
    $row_label = (sort keys %partition)[$row];
    $items_ref = \@{ $partition{$row_label} };
  }

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
      "<tr valign=top><td><b>Row:</b></td>\n" .
      "<td>$row_label</td></tr>\n" .     
      "</table>\n";

  my $cmd = "ListSummarizedLibraries?" .
      "ROW=$row1&" .
      "ORG=$org1&" .
      "SCOPE=$scope1&" .
      "TITLE=$title1&" .
      "TYPE=$type1&" .
      "TISSUE=$tissue1&" .
      "HIST=$hist1&" .
      "PROT=$prot1&" .
      "SORT=$sort1";

  return FormatLibs($page, $org1, $cmd, $page_header, $items_ref);

}

######################################################################
sub QueryLibsOfCluster {
  my ($org, $cid, $scope, $info_ref) = @_;

  my ($est, $sage);
  for (split(",", $scope)) {
    if ($_ =~ /^est$/i) {
      $est = 1;
    } elsif ($_ =~ /^sage$/i) {
      $sage = 1;
    }
  }

  my ($sql, $stm, @row);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }

  if ($est) {
    $sql =
        "select distinct a.library_id, a.lib_name, a.keyword, " .
        "a.sequences_date, a.unigene_id, " .
        "a.the_tiss, a.the_hist, a.the_prep, a.the_prot " .
        "from $CGAP_SCHEMA.all_libraries a, $CGAP_SCHEMA." .
        ($org eq "Hs" ? "Hs_EST" : "Mm_EST") . " b " .
        "where b.cluster_number = $cid and " .
        "a.org = '$org' and " .
        "a.unigene_id = b.library_id " .
        "order by a.the_tiss";

    $stm = $db->prepare($sql);
    if (not $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    } else {
      if ($stm->execute()) {
        while (@row = $stm->fetchrow_array()) {
          push @{ $info_ref }, join("\t", @row);
        }      
        $stm->finish;
      } else {
        print "execute failed\n";
        $db->disconnect();
        return "";
      }
    }
  }

  $db->disconnect();

}

######################################################################
sub GetLibsOfCluster_1 {
  my ($base, $page, $org, $cid) = @_;

  $BASE = $base;

  my @info;

  QueryLibsOfCluster($org, $cid, "est", \@info);

  if (@info) {
    ##
    ## Set up for paging results
    ##
    my $cmd = "LibsOfCluster?" .
        "ORG=$org&" .
        "CID=$cid&";

    return FormatLibs($page, $org, $cmd,
        "Libraries for cluster $org.$cid", \@info);

  } else {
    return "No libraries found for cluster $org.$cid<br><br>";
  }

}

######################################################################
sub SelectLibraryIDs_1 {
  my ($org, $scope, $title, $type, $tissue, $hist, $prot) = @_;

  my (@items, @info);

  SelectLibrarySet(\@items, \@info, $org, $scope, $title, $type, $tissue,
      $hist, $prot, "", "", 0);

  if (@items == 0) {
    ## return "There are no libraries matching the query<br><br>\n";
  } else {
    return join(",", @items)
  }

}

######################################################################
sub LogScale {
  my ($x, $scale) = @_;

  for (my $i = 0; $i < @{ $scale }; $i++) {
    if ($x < $$scale[$i]) {
      return $i;
    }
  }
  return scalar(@{ $scale });
}

######################################################################
#sub ChiSquared {
#  my ($G_A, $G_B, $TotalA, $TotalB) = @_;
#  my $chisq_value      = 0;
#  
#  my $a = $G_A;
#  my $b = $TotalA - $G_A;
#  my $c = $G_B;
#  my $d = $TotalB - $G_B;
#
#  $chisq_value =
#  ($a+$b+$c+$d)*($a*$d-$b*$c)*($a*$d-$b*$c)/(($a+$b)*($c+$d)*($a+$c)*($b+$d));
#
#  my $p_value = chisquare::chisquare($chisq_value);
#  
#  $p_value = sprintf "%.2e", $p_value;
#  $chisq_value = sprintf "%.2f", $chisq_value;
#
#  return ($chisq_value, $p_value)
#}

######################################################################
sub VNCell {
  my ($seq_count, $total, $text_only) = @_;

  my $DENOM = 200000;
  my @LOGSCALE = (2, 4, 8, 16, 32, 64, 128, 256, 512, $DENOM);

  my ($spot, $nums, $rate, $lograte);

  if ($total < 1) {
    if ($text_only) {
      $spot = "";
      $nums = "";
    } else {
      $spot = "<td>--</td>";
      $nums = "<td>--</td>";
    }
    return ($spot, $nums);
  }

  $rate = sprintf "%f", ($seq_count*$DENOM)/$total;

  if ($rate < 0.0001) {    ## i.e., < 1 in 2B)
    $spot = "<td>&nbsp;</td>";
    if ($text_only) {
      $nums = "$seq_count / $total";
    } else {
      $nums = "<td>$seq_count / $total</td>";
    }
  } else {
##          $lograte = sprintf "%d", log($rate)/LOG2;
    $lograte = LogScale($rate, \@LOGSCALE);
    if ($lograte > 9) {
      $lograte = 9;
    }
    $spot =
        "<td><img src=\"" . IMG_DIR . "/northern/spot" .
        ($lograte) . ".gif\" width=30 height=10 " .
        "alt=\"$seq_count / $total\"></td>";
    if ($text_only) {
      $nums = "$seq_count / $total";
    } else {
      $nums =
          "<td>$seq_count / $total</td>";
    }
  }
  return ($spot, $nums);
}

######################################################################
sub ComputeVN_1 {
  my ($base, $org, $cid, $text_only) = @_;

  $BASE = $base;

  InitializeDatabase();

  my ($src, $tissue_code, $histology_code, $tissue, $histology,
      $seq_count, $total, $rate, $lograte,
      %results, %nums, @rows, $found);

  my ($a, $b, $A, $B, $P, $chi2, $temp, %pval);
  my ($spot_cell, $num_cell, %all_all);

  my %all = (
    "E" => {
       "1" => 0,
       "2" => 0
      },
    "S" => {
       "1" => 0,
       "2" => 0
      }
  );

  my @histology_order = (
    "normal",
    "neoplasia"
  );
  my %hist2code = (
    "neoplasia"                 => 1,
    "normal"                    => 2
  );

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }

  my $sql =
      "select source, tissue_code, histology_code, seq_count " .
      "from $CGAP_SCHEMA." . ($org eq "Hs" ? "Hs_VN" : "Mm_VN") . " " .
      "where cluster_number = $cid " .
      "and histology_code in (1,2) ";

## Accept only histology=1 (cancer) or histology=2 (normal)

  my $stm = $db->prepare($sql);

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
    while(($src, $tissue_code, $histology_code, $seq_count) =
        $stm->fetchrow_array) {
      $all{$src}{$histology_code} += $seq_count;
      $tissue = $code2tiss{$tissue_code};
      if (defined $vn_seq_count{$org}{$src}{"$tissue_code,$histology_code"}) {
        $total = $vn_seq_count{$org}{$src}{"$tissue_code,$histology_code"};
        $found++;

        ($spot_cell, $num_cell) = VNCell($seq_count, $total, $text_only);
        $results{$src}{$tissue}{$histology_code} = $spot_cell;
        $nums{$src}{$tissue}{$histology_code} = $num_cell;
      }
    }
  }
  
  $db->disconnect();

  if ($found == 0) {
    return "No data for cluster: $org.$cid";
  }

  for $src ("E", "S") {
    for my $tiss_hist (keys %{ $vn_lib_count{$org}{$src} }) {
      ($tissue_code, $histology_code) = split ",", $tiss_hist;
      $tissue = $code2tiss{$tissue_code};
      $all_all{$src}{$histology_code} +=
          $vn_seq_count{$org}{$src}{"$tissue_code,$histology_code"};
      if (not defined $results{$src}{$tissue}{$histology_code}) {
        $seq_count = 0;
        $total = $vn_seq_count{$org}{$src}{"$tissue_code,$histology_code"};
        $results{$src}{$tissue}{$histology_code} =
            "<td>&nbsp;</td>";
        if ($text_only) {
          $nums{$src}{$tissue}{$histology_code} =
              "$seq_count / $total";
        } else {
          $nums{$src}{$tissue}{$histology_code} =
              "<td>$seq_count / $total</td>";
        }
      }
      if (not defined $pval{$src}{$tissue}) {
        if (defined $nums{$src}{$tissue}{1}) {  ## cancer
          $temp = $nums{$src}{$tissue}{1};
          $temp =~ s/<td>|<\/td>//g;
          ($a, $A) = split " / ", $temp;
        } else {
          undef $a;
        }
        if (defined $results{$src}{$tissue}{2}) {  ## normal
          $temp = $nums{$src}{$tissue}{2};
          $temp =~ s/<td>|<\/td>//g;
          ($b, $B) = split " / ", $temp;
        } else {
          undef $b;
        }
        if (   defined $a
            && defined $b
            && $A > 0
            && $B > 0
            && ($a || $b)
            ) {
          if ($a/$A > $b/$B) {
            ## $P = sprintf "%.2f",
            $P = sprintf "%.2e",
                         FisherExact::FisherExact($a, $b, $A, $B);
                         ## 1 - Bayesian::Bayesian(1, $a, $b, $A, $B);
          } else {
            ## $P = sprintf "%.2f",
            $P = sprintf "%.2e",
                         FisherExact::FisherExact($b, $a, $B, $A);
                         ## 1 - Bayesian::Bayesian(1, $b, $a, $B, $A);
          }
          $pval{$src}{$tissue} = $P;
        }
      }
    }

    $a = $all{$src}{1};
    $A = $all_all{$src}{1};
    ($spot_cell, $num_cell) = VNCell($a, $A, $text_only);
    $results{$src}{"all tissues"}{1} = $spot_cell;
    $nums{$src}{"all tissues"}{1} = $num_cell;
    $b = $all{$src}{2};
    $B = $all_all{$src}{2};
    ($spot_cell, $num_cell) = VNCell($b, $B, $text_only);
    $results{$src}{"all tissues"}{2} = $spot_cell;
    $nums{$src}{"all tissues"}{2} = $num_cell;
    if (   defined $a
        && defined $b
        && $A > 0
        && $B > 0
        && ($a || $b)
        ) {
      if ($a/$A > $b/$B) {
        $P = sprintf "%.2e", FisherExact::FisherExact($a, $b, $A, $B);
        ## $P = sprintf "%.2f", 1 - Bayesian::Bayesian(1, $a, $b, $A, $B);
      } else {
        $P = sprintf "%.2e", FisherExact::FisherExact($b, $a, $B, $A);
        ## $P = sprintf "%.2f", 1 - Bayesian::Bayesian(1, $b, $a, $B, $A);
      }
      $pval{$src}{"all tissues"} = $P;
    } else {
      $pval{$src}{"all tissues"} = ($text_only ? "" : "--");
    }
  }

  if ($text_only) {
    my @row;
    push @rows, join("\t",
        "Tissue",
        "ESTs Normal",
        "ESTs Cancer",
        "ESTs P",
        "SAGE Normal",
        "SAGE Cancer",
        "SAGE P"
    );
    for $tissue ("all tissues", sort values %code2tiss) {
      undef @row;
      push @row, $tissue;
      for $src ("E", "S") {
        for $histology (@histology_order) {
          push @row, $nums{$src}{$tissue}{$hist2code{$histology}};
        }
        push @row, $pval{$src}{$tissue};
      }
      push @rows, join("\t", @row);
    }
    return join("\n", @rows) . "\n";
  }

  push @rows, "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr bgcolor=\"#38639d\">" .
      "<td rowspan=2><font color=\"white\"><b>Tissue</b></font></td>" .
      "<td colspan=2 align=center><font color=\"white\">" .
          "<b>EST Data</b></font></td>" .
      "<td colspan=2 align=center><font color=\"white\">" .
          "<b>SAGE Data</b></font></td>" .
      "<td colspan=3 align=center><font color=\"white\">" .
          "<b>EST Data</b></font></td>" .
      "<td colspan=3 align=center><font color=\"white\">" .
          "<b>SAGE Data</b></font></td>" .
      "</tr><tr bgcolor=\"#38639d\">" .
      "<td><font color=\"white\"><b>Normal</b></font></td>" .
      "<td><font color=\"white\"><b>Cancer</b></font></td>" .
      "<td><font color=\"white\"><b>Normal</b></font></td>" .
      "<td><font color=\"white\"><b>Cancer</b></font></td>" .
      "<td><font color=\"white\"><b>Normal</b></font></td>" .
      "<td><font color=\"white\"><b>Cancer</b></font></td>" .
      "<td><font color=\"white\"><b>P</b></font></td>" .
      "<td><font color=\"white\"><b>Normal</b></font></td>" .
      "<td><font color=\"white\"><b>Cancer</b></font></td>" .
      "<td><font color=\"white\"><b>P</b></font></td>" .
      "</tr>";

  for $tissue ("all tissues", sort values %code2tiss) {
    push @rows, "<tr><td>" .
        ($tissue eq "all tissues" ? "<b>ALL TISSUES</b>" : $tissue) .
        "</td>";
    for $src ("E", "S") {
      for $histology (@histology_order) {
        if (defined $results{$src}{$tissue}{$hist2code{$histology}}) {
          push @rows, $results{$src}{$tissue}{$hist2code{$histology}};
        } else {
          push @rows, "<td align=center>--</td>";
        }
      }
    }
    for $src ("E", "S") {
      for $histology (@histology_order) {
        if (defined $nums{$src}{$tissue}{$hist2code{$histology}}) {
          push @rows, $nums{$src}{$tissue}{$hist2code{$histology}};
        } else {
          push @rows, "<td align=center>--</td>";
        }
      }
      if (defined $pval{$src}{$tissue}) {
        $P = $pval{$src}{$tissue};
        if ($P < 0.05) {
          $P = "<font color=red>$P</font>";
        } else {
          $P = "<font color=blue>$P</font>";
        }
      } else {
        $P = "--";
      }
      push @rows, "<td>$P</td>";
    }
    push @rows, "</tr>";
  }
  push @rows, "</table>";
  return join "\n", @rows;

}


######################################################################
1;
