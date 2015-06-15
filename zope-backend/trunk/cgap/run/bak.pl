#!/usr/local/bin/perl

######################################################################
# CytSearchServer.pm
#
######################################################################

use strict;
use FileHandle;
use CGAPConfig;
use ServerSupport;
use DBI;
use URI::Escape;

my %morph_codes;
my %topo_codes;
my %country_codes;
my %herdis_codes;
my %treat_codes;
my %tissue_codes;

my $BASE;

my $query;
my $where_flag;

my $DEBUG_FLAG;
my $ROWS_PER_SUBTABLE = 100;
my $temp_header =
  "<TABLE WIDTH=\"485\" BORDER=\"1\" CELLSPACING=\"1\" CELLPADDING=\"4\">
    <TR BGCOLOR=\"#38639d\">
      <TD WIDTH=\"35\">
        <font color=\"white\">
          <B>
            Band
          </B>
        </font>
      </TD>
      <TD WIDTH=\"120\">
        <font color=\"white\">
          <B>
            Abnormality
          </B>
        </font>
      </TD>
      <TD WIDTH=\"125\">
        <font color=\"white\">
          <B>
            Morphology
          </B>
        </font>
      </TD>
      <TD WIDTH=\"120\">
        <font color=\"white\">
          <B>
            Topography
          </B>
        </font>
      </TD>
      <TD WIDTH=\"20\">
        <font color=\"white\">
          <B>
            Cases
          </B>
        </font>
      </TD>
      <TD WIDTH=\"60\">
        <font color=\"white\">
          <B>
            Genes
          </B>
        </font>
      </TD>
    </TR>";

my $bal_header =
 "<B>
    Balanced Chromosomal Abnormalities
  </B>
  <br>" . $temp_header;

my $unbal_header =
 "<B>
    Unbalanced Chromosomal Abnormalities
  </B>
  <br>" . $temp_header;


my $num_temp_header =
  "<TABLE WIDTH=\"485\" BORDER=\"1\" CELLSPACING=\"1\" CELLPADDING=\"4\">
    <TR BGCOLOR=\"#38639d\">
      <TD WIDTH=\"120\">
        <font color=\"white\">
          <B>
            Abnormality
          </B>
        </font>
      </TD>
      <TD WIDTH=\"125\">
        <font color=\"white\">
          <B>
            Morphology
          </B>
        </font>
      </TD>
      <TD WIDTH=\"120\">
        <font color=\"white\">
          <B>
            Topography
          </B>
        </font>
      </TD>
      <TD WIDTH=\"20\">
        <font color=\"white\">
          <B>
            Cases
          </B>
        </font>
      </TD>
      <TD WIDTH=\"60\">
        <font color=\"white\">
          <B>
            Genes
          </B>
        </font>
      </TD>
    </TR>";


my $trisomy_header =
 "<B>
    Numerical Chromosomal Trisomy Abnormalities
  </B>
  <br>" . $num_temp_header;
    
my $monosomy_header =
 "<B>
    Numerical Chromosomal Monosomy Abnormalities
  </B>
  <br>" . $num_temp_header;



######################################################################
sub InitializeDatabase {

  my $sql = "select distinct KodTyp, Kod, Benamning from $CGAP_SCHEMA.Koder " .
    "where KodTyp in ('MORPH', 'TOP','GEO','TISSUE','HER','TREAT')";

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    die "Cannot connect to database\n";
  }

  my (@row);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (@row = $stm->fetchrow_array()) {
        if ($row[0] eq 'MORPH') {
          $morph_codes{$row[1]} = $row[2];
        } elsif ($row[0]eq 'TOP') {
          $topo_codes{$row[1]} = $row[2];
        } elsif ($row[0] eq 'GEO') {
          $country_codes{$row[1]} = $row[2];
        } elsif ($row[0] eq 'HER') {
          $herdis_codes{$row[1]} = $row[2];
        } elsif ($row[0] eq 'TREAT') {
          $treat_codes{$row[1]} = $row[2];
        } elsif ($row[0] eq 'TISSUE') {
          $tissue_codes{$row[1]} = $row[2];
        }
      }
    } else {
      $db->disconnect();
      die "execute failed\n";
    }
  }
  $db->disconnect();

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

######################################################################
sub DoRange {
  my ($field, $val, $is_numeric) = @_;

  my $quote = $is_numeric ? "" : "'";
  $val =~ s/ //g;
  if ($val =~ /^([<>])(.+)/) {
    my $op = $1;
    my $val = $2;
    return "$field $op $quote$val$quote";
  } elsif ($val =~ /-/) {
    my ($lo, $hi) = split "-", $val;
    return "$field between $quote$lo$quote and $quote$hi$quote"
  } else {
    return "$field = $quote$val$quote"
  }
}

######################################################################
sub DoIn {
  my ($field, $list) = @_;
  if (not $list) {
    return "";
  }
  my @temp;
  for my $p (split(",", $list)) {
    push @temp, "'$p'";
  }
  return "$field in (" . (join ", ", @temp) . ")";
}

######################################################################
sub DoOpList {
  my ($field, $op, $val, $is_numeric) = @_;
  if (not $val) {
    return "";
  }
  ## $pre_wc is here only for PrevTreat, which, regrettably, may
  ## have multiple, comma-separated single-character treatment
  ## values
  my $pre_wc = ($op eq "like" and not $is_numeric) ? "%" : "";
  my $post_wc = $op eq "like" ? "%" : "";
  my $quote = $post_wc eq "%" ? "'" : ($is_numeric ? "" : "'");
  my @vals = split ",", $val;
  return
      (@vals > 1 ? "(" : "") .
      "$field $op $quote$pre_wc" .
      (join "$post_wc$quote or $field $op $quote$pre_wc", @vals) .
      "$post_wc$quote" .
      (@vals > 1 ? ")" : "") ;
}

######################################################################
sub ParseTerm {
  my ($part) = @_;

  if ($part =~ /\"([^\"]*)\"/) {
    return ("=", $1);
  } else {
    return ("like", $part);
  }
}

######################################################################
sub FixAuthorInput {

  my ($string) = @_;

  $string =~ tr/A-Z/a-z/;
  $string =~ tr/*'/%_/;
  my @authors = split(",", $string);

  for my $p (@authors) {

    $p =~ s/^ +//;
    $p =~ s/ +$//;
    $p =~ s/ +/ /g;

    if ($p !~ / /) {
      $p = $p . " %";
    }
  }

  return @authors;
}


######################################################################
sub DoAndOrPile {
  my ($table, $var, $field, $log_op, @parts) = @_;
  my (@positive_terms, @negative_terms);
  my ($i, $j, $s, $term, $wc, $op, @temp);
  for $i (@parts) {
    $i =~ s/^ +//;
    $i =~ s/ +$//;
    if ($i =~ /^(not +)(.*)/i) {
      push @negative_terms, $2;
    } else {
      push @positive_terms, $i;
    }
  }
  if (@positive_terms > 0) {
    ($op, $term) = ParseTerm($positive_terms[0]);
    $wc = $op eq "like" ? "%" : "";
#   if ($op eq "like") {
#     if (($field eq "Abnormality") or ($field eq "Bit")) {
#       $wc = "";
#     } else {
#       $wc = "%";
#     }
#   } else {
#     $wc = "";
#   }
    if( $log_op eq "n" ) {
      $s = "lower($var.$field) $op '$term' ";
    }
    else {
      $s = "lower($var.$field) $op '$term$wc' ";
    }
    for ($i = 1; $i < @positive_terms; $i++) {
      ($op, $term) = ParseTerm($positive_terms[$i]);
      $wc = $op eq "like" ? "%" : "";

  ##  $log_op = a represents the general "and" case
      if ($log_op eq "a") {
        $s = "$s and exists " .
            "( select $field from $CGAP_SCHEMA.$table $var$i " .
            "where c.RefNo = $var$i.RefNo and " .
            (($table ne 'MolClinAbnorm') ?
            "c.CaseNo = $var$i.CaseNo and " : "") .
	    "c.InvNo = $var$i.InvNo and " .
            "lower($var$i.$field) $op '$term$wc' ) ";

  ##  $log_op = c represents the "and" case for reference associated vars
      } elsif ($log_op eq "c") {
        $s = "$s and exists " .
            "( select $field from $CGAP_SCHEMA.$table $var$i " .
            "where c.RefNo = $var$i.RefNo and " .
            "lower($var$i.$field) $op '$term$wc' ) ";

  ##  $log_op = d represents the "and" case for reference search
      } elsif ($log_op eq "d") {
        $s = "$s and exists " .
            "( select $field from $CGAP_SCHEMA.$table $var$i " .
            "where r.RefNo = $var$i.RefNo and " .
            "lower($var$i.$field) $op '$term$wc' ) ";

  ##  $log_op = o represents the general "or" case
      } elsif ($log_op eq "o") {
        $s = "$s or lower($var.$field) $op '$term$wc' ";
  ##  $log_op = n represents the general "or" case and no wildcards
      } elsif ($log_op eq "n") {
        $s = "$s or lower($var.$field) $op '$term' ";
      } else {
        print STDERR "illegal logical operator\n";
      }
    }
  }
  if (@positive_terms == 0) {
    $i = "";
  }
  if (@negative_terms > 0) {
    $s = $s . ($s ? " and " : "") . "not exists ".
      "( select $field from $CGAP_SCHEMA.$table $var$i " .
       "where c.RefNo = $var$i.RefNo and " .
       (($table ne 'MolClinAbnorm') ?
       "c.CaseNo = $var$i.CaseNo and " : "") .
       "c.InvNo = $var$i.InvNo and ( ";
    for ($j = 0; $j < @negative_terms; $j++) {
      ($op, $term) = ParseTerm($negative_terms[$j]);
      $wc = $op eq "like" ? "%" : "";
      push @temp, "lower($var$i.$field) $op '$term$wc' ";
    }
    $s = "$s " . join("or ", @temp) . " ) )";
  }
  return $s;
}

######################################################################
sub DoGenePile {
  my ($table, $var, $field, $log_op, @parts) = @_;
  my (@positive_terms, @negative_terms);
  my ($i, $j, $s, $term, $wc, $op, @temp);
  for $i (@parts) {
    $i =~ s/^ +//;
    $i =~ s/ +$//;
    if ($i =~ /^(not +)(.*)/i) {
      push @negative_terms, $2;
    } else {
      push @positive_terms, $i;
    }
  }
  if (@positive_terms > 0) {
    $positive_terms[0] =~ /(\+|-)*([^+-]+)(\+|-)*/;
    my $prefix = $1;
    my $gene = $2;
    my $suffix = $3;
    $gene =~ tr/a-z/A-Z/;
    if ($prefix) {
      $s = "k.prefix = '$prefix' and ";
    }
    $s = $s . "k.gene like '$gene'";
    if ($suffix) {
      $s = $s . " and k.suffix = '$suffix'";
    } 
   
    for ($i = 1; $i < @positive_terms; $i++) {
      $positive_terms[$i] =~ /(\+|-)*([^+-]+)(\+|-)*/;
      my $prefix = $1;
      my $gene = $2;
      my $suffix = $3;
      $gene =~ tr/a-z/A-Z/;
      if ($log_op eq "a") {
        $s = "$s and exists " .
            "( select $field from $CGAP_SCHEMA.MolClinGene k$i " .
            "where c.RefNo = k$i.RefNo and " .
            "c.InvNo = k$i.InvNo and ";
        if ($prefix) {
          $s = $s . "k$i.prefix = '$prefix' and ";
        }
        $s = $s . "k$i.gene like '$gene'";
        if ($suffix) {
          $s = $s . " and k$i.suffix = '$suffix'";
        } 
        $s = $s . ")";
      } elsif ($log_op eq "o") {
        $s = "$s or exists " .
            "( select $field from $CGAP_SCHEMA.MolClinGene k$i " .
            "where c.RefNo = k$i.RefNo and " .
            "c.InvNo = k$i.InvNo and ";
        if ($prefix) {
          $s = $s . "k$i.prefix = '$prefix' and ";
        }
        $s = $s . "k$i.gene like '$gene'";
        if ($suffix) {
          $s = $s . " and k$i.suffix = '$suffix'";
        } 
        $s = $s . ")";
      }
    }
  }
  if (@positive_terms == 0) {
    $i = "";
  }
  if (@negative_terms > 0) {
    $s = $s . ($s ? " and " : "") . "not exists ".
      "( select $field from $CGAP_SCHEMA.MolClinGene k$i " .
       "where c.RefNo = k$i.RefNo and " .
       "c.InvNo = k$i.InvNo and ( ";
    for ($j = 0; $j < @negative_terms; $j++) {
      $negative_terms[$j] =~ /(\+|-)*([^+-]+)(\+|-)*/;
      my $prefix = $1;
      my $gene = $2;
      my $suffix = $3;
      $gene =~ tr/a-z/A-Z/;      
      my $t = "(";
      if ($prefix) {
        $t = $t . "k$i.prefix = '$prefix' and ";
      }
      $t = $t . "k$i.gene like '$gene'";
      if ($suffix) {
        $t = $t . " and k$i.suffix = '$suffix'";
      } 
      $t = $t . ")";      
      push @temp, $t
    }
    $s = "$s " . join("or ", @temp) . " ) )";
  }
  return $s;
}

######################################################################
sub DoWildCardable {
  my ($field, $val) = @_;
  my (@parts, @parts_wc);
  for my $p (split(",", $val)) {
    if ($p =~ /\%/) {
      $p =~ s/\%+$//;
      push @parts_wc, $p;
    } else {
      push @parts, $p;
    }
  }
  my $both = (@parts > 0 and @parts_wc > 0);
  return
      ($both ? "(" : "") .
      DoIn($field, join(",", @parts)) .
      ($both ? " or " : "") .
      DoOpList($field, "like", join(",", @parts_wc), 1) .
      ($both ? ")" : "") ;
}

######################################################################
sub FixSpecChar {
  my ($str) = @_;
  my @new_str;
  my @tmp = split "", $str;
  for (my $i=0; $i<@tmp; $i++) {
    my $value = ord($tmp[$i]);
    if( $value <= 127 and $value != 64 ) {
      push @new_str, $tmp[$i];
    }
    else {
      $value = "&#" . $value;
      push @new_str, $value;
    }
  }
  return join("",@new_str);

}

######################################################################
sub FixSearchChar {
  my ($str) = @_;
  my @new_str;
  my @tmp = split "", $str;
  for (my $i=0; $i<@tmp; $i++) {
    my $value = ord($tmp[$i]);
    if( $value <= 127 and $value != 64 and $value != 39 ) {
      push @new_str, $tmp[$i];
    }
    else {
      push @new_str, "_" . $value . "_";
    }
  }
  return join("",@new_str);

}

######################################################################
sub FixTextChar {
  my ($string) = @_;

  $string =~ s/\224/o/g;
  $string =~ s/\206/a/g;
  $string =~ s/\202/e/g;
  $string =~ s/\204/a/g;
  $string =~ s/\201/u/g;
  $string =~ s/\231/O/g;
  $string =~ s/\217/A/g;
  $string =~ s/\264/'/g;
  $string =~ s/\351/e/g;
  $string =~ s/@/E/g;

  return $string;
}
######################################################################
sub FormatKary {
  my ($temp) = @_;

## originally 85 for table width = 600
##  use constant KARY_LINE_LENGTH => 85

## try 75 for table width=500 
  use constant KARY_LINE_LENGTH => 75;

# Messing up karyotypes like "+7 or der(7)"
# $temp =~ s/ //g; 
  my @x;
  my $pos=0;     
  for (my $i=0; $i <= length($temp); $i=$pos+1) {
    if(rindex($temp, ",", $i + KARY_LINE_LENGTH) >
        rindex($temp, "(", $i + KARY_LINE_LENGTH)) {
      $pos = rindex($temp,",",$i+KARY_LINE_LENGTH);
    } else {
      $pos = rindex($temp, "(", $i + KARY_LINE_LENGTH) - 1;
    }
    if ($i + KARY_LINE_LENGTH < length($temp)) {
      push @x, substr($temp, $i, $pos - $i+1) . " ";
    } else {
      push @x, substr($temp, $i, length($temp) - $i+1) . " ";
      last;
    }
  } 
  my $Kary =  join("", @x);
  return $Kary;
}

######################################################################
sub BuildSearchQuery {
  my (
    $page,
    $abnorm_op,
    $abnormality,
    $soleabnorm,
    $age,
    $author,
    $break_op,
    $breakpoint,
    $caseno,
    $country,
    $herdis,
    $immuno,
    $invno,
    $journal,
    $morph,
    $nochrom,
    $noclones,
    $prevmorph,
    $prevneo,
    $prevtop,
    $race,
    $refno,
    $series,
    $sex,
    $specherdis,
    $specmorph,
    $tissue,
    $top,
    $treat,
    $year,
    $totalcases
  ) = @_;

  InitQuery(
    "select distinct r.Abbreviation, r.Journal, " .
    "c.Refno, c.CaseNo, c.InvNo, y.Morph, y.Topo, c.KaryShort, " .
    "c.KaryLength, c.KaryLong, r.Volume from $CGAP_SCHEMA.CytogenInv c, " .
    "$CGAP_SCHEMA.Reference r, $CGAP_SCHEMA.Cytogen y " .
    (($nochrom or $soleabnorm) ? ", $CGAP_SCHEMA.KaryClone k"        : "") .
    ($abnormality        ? ", $CGAP_SCHEMA.KaryBit a"       : "") .
    ($breakpoint         ? ", $CGAP_SCHEMA.KaryBreak br"       : "") .
    ($author             ? ", $CGAP_SCHEMA.AuthorReference ar" : "")
  );
  
###      (($year or $journal) ? ", Reference r"        : "")

  Add("y.RefNo = c.RefNo and y.CaseNo = c.CaseNo");
  Add("c.Refno = r.Refno");

## NOTE: we now have "c.Refno = r.Refno" specified potentially 
## more than once

  if ($nochrom or $soleabnorm) {
    Add("c.RefNo = k.RefNo and c.CaseNo = k.CaseNo and c.InvNo = k.InvNo");
  }
  
  if ($author and ($year or $journal)) {
    Add("r.RefNo = ar.RefNo and c.RefNo = r.RefNo");
  } else {
    if ($author) {
      Add("c.RefNo = ar.RefNo");
    }
    if ($year or $journal) {
      Add("c.RefNo = r.RefNo");
    }
  }

  if ($year) {
    Add(DoRange("r.year", $year, 1));
  }
  
  if ($abnormality) {
    Add("c.RefNo = a.RefNo and c.CaseNo = a.CaseNo and c.InvNo = a.InvNo");
  }
  
  if ($soleabnorm) {
    Add("k.SoleAbnorm = 'T'");
  }

  if ($abnormality and $soleabnorm) {
      Add("a.CloneNo = k.CloneNo");
  }

  if ($breakpoint) {
    Add("c.RefNo = br.RefNo and c.CaseNo = br.CaseNo and c.InvNo = br.InvNo");
  }
  
  if ($refno) {
    Add(DoRange("c.RefNo", $refno, 1));
  }
  
  if ($caseno) {
    Add(DoRange("c.CaseNo", $caseno, 0));
  }
  
  if ($invno) {
##    Add(DoRange("c.InvNo", $invno, 1));
## We are to intrepret this as meaning find all investigations for
## every (refno, caseno) that has at least one invno  meeting the
## invno constraint.

    Add(
        "exists (select c1.InvNo from $CGAP_SCHEMA.CytogenInv c1 where " .
        "c1.RefNo = c.RefNo and c1.CaseNo = c.CaseNo and " .
        DoRange("c1.InvNo", $invno, 1) .
        ")"
    );
  }
  

  if ($immuno) {
    Add(DoOpList("y.Immunology", "=", $immuno, 0));
  }
  
  if ($sex) {
    Add("y.sex = '$sex'");
  }
  
  if ($age) {
    Add(DoRange("y.age", $age, 1));
  }
  
  if ($specmorph) {
    $specmorph =~ tr/*/%/;
    $specmorph =~ tr/A-Z/a-z/;
    Add("lower(y.SpecMorph) like '$specmorph%'");
  }
  
  if ($specherdis) {
    $specherdis =~ tr/*/%/;
    $specherdis =~ tr/A-Z/a-z/;
    Add("lower(y.SpecHerDis) like '$specherdis%'");
  }
  
  if ($race) {
    Add(DoIn("y.Race", $race));
  }
  
  if ($prevneo) {
    Add("y.PrevTum = '$prevneo'");
  }
  
  if ($treat and $prevneo ne " ") {
    Add(DoOpList("y.PrevTreat", "like", $treat, 0));
  }
  
  if ($herdis) {
    Add(DoIn("y.HerDis", $herdis));
  }
  
  if ($prevmorph and $prevneo ne " ") {
    Add(DoWildCardable("y.PrevMorph", $prevmorph));
  }
  
  if ($prevtop and $prevneo ne " ") {
    Add(DoWildCardable("y.PrevTopo", $prevtop));
  }
  
  if ($morph) {
    Add(DoWildCardable("y.Morph", $morph));
  }
  
  if ($top) {
    Add(DoWildCardable("y.Topo", $top));
  }
  
  if ($series) {
    Add("y.Series = '$series'");
  }
  
  if ($country) {
    Add(DoWildCardable("y.Country", $country));
  }
  
  if ($tissue) {
    Add(DoIn("c.Tissue", $tissue));
  }
  
  if ($noclones) {
    Add(DoRange("c.Clones", $noclones, 1));
  }
  
  if ($nochrom) {
  ## cannot call DoRange; this is a more complicated case
    my ($lo, $hi);
    $nochrom =~ s/ //g;
    if ($nochrom =~ /^(<)(.+)/) {
      $hi = $2;
      Add("k.ChromoMax < $hi and k.ChromoMin <> 0");
    } elsif ($nochrom =~ /^(>)(.+)/) {
      $lo = $2;
      Add("k.ChromoMin > $lo");
    } else {
      if ($nochrom =~ /-/) {
        ($lo, $hi) = split "-", $nochrom;
      } else {
        $lo = $hi = $nochrom;
      }
      Add("k.ChromoMax >= $lo and k.ChromoMin <= $hi");
    }
  }

  if ($author) {
##    my @authors = split(",", $author);
    my @authors = FixAuthorInput($author);
    Add(
        "( " .
        DoAndOrPile("AuthorReference", "ar", "Name", "c", @authors) .
        " )"
    );
  }

  if ($journal) {
    $journal =~ tr/A-Z/a-z/;
    $journal =~ tr/*/%/;
    my @journals = split(",", $journal);
    Add(
        "( " .
        DoAndOrPile("Reference", "r", "Journal", "c", @journals) .
        " )"
    );
  }
  
  if ($abnormality) {
    $abnormality =~ tr/A-Z/a-z/;
    #$abnormality =~ tr/*/%/;
    my @parts;
    if( $totalcases eq "Y" ) {
      my $plusone = "+" . $abnormality;
      $parts[0] = $abnormality;
      $parts[1] = $plusone;
      if( $abnorm_op ne "n" ) {
        $abnorm_op = "o";
      }
    } else {
      @parts = split(",", $abnormality);
    }
    Add(
      "( " .
           DoAndOrPile("KaryBit", "a", "Bit", $abnorm_op, @parts) .
      " )"
    );
  }

  if ($breakpoint) {
    $breakpoint =~ tr/A-Z/a-z/;
    $breakpoint =~ tr/*/%/;
    my @parts = split(",", $breakpoint);
    Add(
        "( " .
        DoAndOrPile("KaryBreak", "br", "Breakpoint", $break_op, @parts) .
        " )"
    );
  }

  $query = "$query order by r.Abbreviation, c.Refno, c.CaseNo, c.Invno";
  return $query;

}

######################################################################
sub Checked {
  my ($in, $value) = @_;
  print "8888: $in, $value<br>";
  if( $in eq $value ) {
    return "checked";
  }
  else {
    return "";
  }
}
######################################################################
sub  BuildFullSearchNewInterface {
  my (
    $page,
    $abnorm_op,
    $abnormality,
    $soleabnorm,
    $age,
    $author,
    $break_op,
    $breakpoint,
    $caseno,
    $country,
    $herdis,
    $immuno,
    $invno,
    $journal,
    $morph,
    $nochrom,
    $noclones,
    $prevmorph,
    $prevneo,
    $prevtop,
    $race,
    $refno,
    $series,
    $sex,
    $specherdis,
    $specmorph,
    $tissue,
    $top,
    $treat,
    $year,
    $totalcases,
    $top_size, 
    $prevtop_size,
    $morph_size,
    $prevmorph_size
  ) = @_;
  my ($checked_a, $checked_b, $checked_c, $checked_d, %checked_race, $page_new_value, $link_name);
  my $html = 
       "<H3>Mitelman Cases Full Searcher</H3>" .
       "" .
       "<blockquote>" .
       "The Cases Full Searcher finds the same" .
       "individual patient cases as the Quick Searcher. However, the Full Searcher has additional " .
       "search fields for cytogenetics, patient and tumor characteristics, and reference. The search engine finds all cases that match" .
       "the chosen criteria, organizes them by lead author in the reference, and provides" .
       "a link to the individual patient information and to the reference itself." .
       "</blockquote>" .
       "<P><table width=100% cellpadding=4>" .
       "<tr>" .
       "   <td bgcolor=\"#38639d\">" .
       "      <font color=\"white\"><b>Cases Full Searcher</b></font>" .
       "   </td>" .
       "</table>" .
       "<blockquote>" .
       "Brief instructions for using the Full Searcher:" .
       " <UL>" .
       "       <LI>Check \"Yes\" in the \"Sole Abnormality\" " .
       "        field to view cases with only one aberration, irrespective of other items selected." .
       "       <LI>Choose any one or more individual sections (e.g., Cytogenetic " .
       "       Characteristics, Patient Characteristics, etc.). N.B. Check \"Sole " .
       "       Abnormality\" to view cases with only one aberration irrespective of any other item." .
       "     <LI>Complete as many fields within an individual section as required." .
       "     <LI>The default setting for all expanded select boxes is all items. Or" .
       "         select single or multiple items." .
       "     <LI>Click the link at Special Hereditary Disorder to view" .
       "         a list of all special hereditary disorder terms. " .
       "     <Li>Click the link at Special Morphology to view" .
       "         a list of all special morphology terms. " .
       "     <li>Press Submit Query, or press Reset to begin a new search." .
       " </UL>" .
       "</blockquote>" .
       "<form name=\"pform\" method=\"GET\" action=\"CytList\">" .
       "<input type=hidden name=\"page\" value=1>" .
       "<input type=hidden name=\"morph_size\" value=5>" .
       "<input type=hidden name=\"prevmorph_size\" value=5>" .
       "<input type=hidden name=\"top_size\" value=5>" .
       "<input type=hidden name=\"prevtop_size\" value=5>" .
       "<P><B>Cytogenetic Characteristics</b>" .
       "<table border=0 cellpadding=3 cellspacing=4 width=\"100%\">" .
       " <TR>" .
       "   <td align=right>Sole Abnormality:</TD>" .
       "   <TD valign=top>";
       $checked_a = ($soleabnorm eq "0" ? "checked" : "");
       $checked_b = ($soleabnorm eq "1" ? "checked" : "");
       $html = $html .

       "     <input type=\"radio\" name=\"soleabnorm\" id=\"No\" value=\"0\" $checked_a>" .
       "        <label for=\"No\"> No</label>  " .
       "     <input type=\"radio\" name=\"soleabnorm\" id=\"Yes\" value=\"1\" $checked_b>" .
       "        <label for=\"Yes\"> Yes</lanel>" .
       "   </TD>" .
       " </TR>" .
       "<tr>" .
       " <td valign=top width=23%  align=right>Abnormality:</td>" .
       " <td valign=top>"; 
       $checked_a = ($abnorm_op eq "a" ? "checked" : ""); 
       $checked_b = ($abnorm_op eq "o" ? "checked" : ""); 
       $html = $html . 
       "  <input type=radio name=abnorm_op id=\"And\" value=\"a\" $checked_a>" .
       "    <label for=\"And\"> And</label>" .
       "  <input type=radio name=abnorm_op id=\"Or\" value=\"o\" $checked_b>" .
       "    <label for=\"Or\"> Or</label>" .
       " <BR><label for=\"Abnormality\"></label>" .
       "  <input type=\"text\" name=\"abnormality\" id=\"Abnormality\" value=\"$abnormality\" size=32 maxlength=50>" .
       "   &nbsp;&nbsp;" .
       "   </td>" .
       "</tr>" .
       "<tr>" .
       " <td valign=top align=right>" .
       "    <label for=\"breakpoint\">Breakpoint:</label>" .
       " </td>" .
       " <td>";
       $checked_a = ($break_op eq "a" ? "checked" : ""); 
       $checked_b = ($break_op eq "o" ? "checked" : ""); 
       $html = $html . 
       "  <input type=radio name=break_op id=\"And\" value=\"a\" $checked_a>" .
       "    <label for=\"And\"> And</label>" .
       "  <input type=radio name=break_op id=\"Or\" value=\"o\" $checked_b>" .
       "    <label for=\"Or\"> Or</label>" .
       "   <br>" .
       "  <input type=\"text\" name=\"breakpoint\" id=\"breakpoint\" value=\"$breakpoint\" size=32 maxlength=50>" .
       "   </td>" .
       "</tr>" .
       "<tr>" .
       "   <td valign=top align=right>" .
       "      <label for=\"noclones\">Number of Clones:</label>" .
       "   </td>" .
       "   <td>" .
       "    <input type=\"text\" name=\"noclones\" id=\"noclones\" value=\"$noclones\" size=10 maxlength=5>" .
       "   </td>" .
       "</tr>" .
       "<tr>" .
       "   <td valign=top align=right>" .
       "      <label for=\"nochrom\">Number of Chromosomes:</label>" .
       "   </td>" .
       "   <td>" .
       "    <input type=\"text\" name=\"nochrom\" id=\"nochrom\" value=\"$nochrom\" size=10 maxlength=7>" .
       "   </td>" .
       "</tr>" .
       "</table>" .
       "<P><b>Patient Characteristics</b>" .
       "<table border=0 cellpadding=3 cellspacing=4 width=\"100%\">" .
       "<tr>" .
       "   <td valign=top align=right width=25%>" .
       "      Sex:" .
       "   </td>" .
       "   <td>"; 
       $checked_a = "";
       $checked_b = "";
       $checked_c = "";
       if( $sex eq "M" ) {
         $checked_b = "checked";
       }
       elsif( $sex eq "F" ) {
         $checked_c = "checked";
       }
       elsif( $sex eq "" ) {
         $checked_a = "checked";
       } 
       $html = $html .
       "<input type=\"radio\" name=\"sex\" id=\"Any\" value=\"\" $checked_a>" .
       "  <label for=\"Any\">Any</label><BR>" .
       "<input type=\"radio\" name=\"sex\" id=\"Male\" value=\"M\" $checked_b>" .
       "  <label for=\"Male\">Male</label><BR>" .
       "<input type=\"radio\" name=\"sex\" id=\"Female\" value=\"F\" $checked_c>" .
       "  <label for=\"Female\">Female</label>" .
       "     </td>" .
       "</tr>" .
       "<tr>" .
       "   <td valign=top align=right>" .
       "      <label for=\"age\">Age:</label>" .
       "   </td>" .
       "   <td>" .
       "      <input type=\"text\" name=\"age\" id=\"age\" value=\"$age\" size=10 maxlength=7>" .
       "   </td>" .
       "</tr>" .
       "<tr>" .
       "   <td valign=top align=right>" .
       "      Race:" .
       "   </td>" .
       "   <td>"; 
       undef %checked_race;
       my @races = split ",", $race;
       for( my $i=0; $i<@races; $i++ ) {
         $checked_race{$races[$i]} = "checked";
       }
       $html = $html .
       "  <input type=\"checkbox\" name=\"race\" id=\"Asian\" value=\"A\" $checked_race{A}>" .
       "    <label for=\"Asian\">Asian<BR></label>" .
       "  <input type=\"checkbox\" name=\"race\" id=\"Black\" value=\"B\" $checked_race{B}>" .
       "    <label for=\"Black\">Black<BR></label>" .
       "  <input type=\"checkbox\" name=\"race\" id=\"White\" value=\"W\" $checked_race{W}>" .
       "    <label for=\"White\">White<BR></label>" .
       "  <input type=\"checkbox\" name=\"race\" id=\"Other\" value=\"O\" $checked_race{O}>" .
       "    <label for=\"Other\">Other</label>" .
       "   </td>" .
       "</tr>" .
####       "<tr>" .
####       "   <td valign=top align=right>" .
####       "      <label for=\"country\">Country:</label>" .
####       "   </td>" .
####       "   <td>" .
####       "     " .
####       "     <select name=country id=\"country\" size=5 multiple>" .
####       "         <dtml-var \"BackEnd('',0,CGAPCGI,BASE,'GetSelectMenu.pl','','TABLE',REQUEST,{'TABLE':'MITELMAN_COUNTRY'})\">" .
####       "     </select>" .
####       "   </td>" .
####       "</tr>" .
####       "<tr>" .
####       "   <td valign=top align=right>" .
####       "      <label for=\"series\">Series:</label>" .
####       "   </td>" .
####       "   <td>" .
####       "      <select name=\"series\" id=\"series\" size=1>" .
####       "         <option value=\"\">[Any]" .
####       "         <option value=\"S\">Selected" .
####       "         <option value=\"U\">Unselected" .
####       "      </select>" .
####       "   </td>" .
####       "</tr>" .
####       "<tr>" .
####       "   <td valign=top align=right>" .
####       "       Hereditary Disorder:" .
####       "   </td>" .
####       "   <td>" .
####       "     <dtml-var \"BackEnd('',0,CGAPCGI,BASE,'GetSelectMenu.pl','','TABLE',REQUEST,{'TABLE':'MITELMAN_HERDIS'})\">" .
####       "   </td>" .
####       "</tr>" .
####       "<tr>" .
####       "   <td valign=top align=right>" .
####       "      <label for=\"specherdis\"><a href=javascript:spawn(\"<dtml-var BASE_HEAD>/Chromosomes/HelpLists?FIELDNAME=specherdis&TABLENAME=cytogen\")>Special Hereditary Disorder:</A></label>" .
####       "   </td>" .
####       "   <td>" .
####       "      <input type=\"text\" name=\"specherdis\" id=\"specherdis\" size=32 maxlength=50>" .
####       "   </td>" .
####       "</tr>" .
       "</table>"; 
####       "" .
####       "<P>" .
####       "<b>Present Tumor</b> " .
####       "<table border=0 cellpadding=3 cellspacing=4 width=\"100%\">" .
####       "<tr><td>" .
####       "    </td>" .
####       "    <td>" .
####       "       <a href=\"javascript:document.pform.action='CytSearchFormForDiffMenu';document.pform.top_size.value=40;document.pform.page.value=7;document.pform.submit()\">Expanding Viewable List:</A>" .
####       "    </td>" .
####       "</tr>" .
####       "<TR>" .
####       "   <td valign=top align=right width=25%>" .
####       "      Topography:" .
####       "   </td>" .
####       "   <td>" .
####       "      <select name=top id=\"topography\" size=5 multiple>" .
####       "         <dtml-var \"BackEnd('',0,CGAPCGI,BASE,'GetSelectMenu.pl','','TABLE',REQUEST,{'TABLE':'MITELMAN_TOP'})\">" .
####       "      </select>" .
####       "   </td>" .
####       "</tr>" .
####       "<tr>" .
####       "   <td valign=top align=right>" .
####       "      Immunophenotype:" .
####       "   </td>" .
####       "   <td>" .
####       "      <input type=\"checkbox\" name=\"immuno\" id=\"B_Lineage\" value=\"B\"><label for=\"B_Lineage\">B Lineage</label><BR>" .
####       "<!--      <input type=\"checkbox\" name=\"immuno\" value=\"N\">N</font> &nbsp;&nbsp;&nbsp;&nbsp;-->" .
####       "      <input type=\"checkbox\" name=\"immuno\" id=\"T_Lineage\" value=\"T\"><label for=\"T_Lineage\">T Lineage</label>" .
####       "   </td>" .
####       "</tr>" .
####       "<tr><td></td>" .
####       "    <td>" .
####       "        <a href=\"javascript:document.pform.action='CytSearchFormForDiffMenu';document.pform.morph_size.value=40;document.pform.page.value=9;document.pform.submit()\">Expanding Viewable List:</A>" .
####       "    </td>" .
####       "</tr>" .
####       "<tr>" .
####       "   <td valign=top align=right>" .
####       "      Morphology:" .
####       "   </td>" .
####       "   <td>" .
####       "      <select name=morph id=\"morphology\" size=5 multiple>" .
####       "         <dtml-var \"BackEnd('',0,CGAPCGI,BASE,'GetSelectMenu.pl','','TABLE',REQUEST,{'TABLE':'MITELMAN_MORPH'})\">" .
####       "      </select>" .
####       "   </td>" .
####       "</tr>" .
####       "<tr>" .
####       "   <TD><label for=\"specmorph\"><a href=javascript:spawn(\"<dtml-var BASE_HEAD>/Chromosomes/HelpLists?FIELDNAME=specmorph&TABLENAME=cytogen\")>Special Morphology:</A></label>" .
####       "      </td>" .
####       "   </td>" .
####       "   <td>" .
####       "      <input type=\"text\" name=\"specmorph\" id=\"specmorph\" size=32 maxlength=50>" .
####       "   </td>" .
####       "</tr>" .
####       "<tr>" .
####       "   <td valign=top align=right>" .
####       "     <label for=\"tissue\">Tissue:</label>" .
####       "   </td>" .
####       "   <td>" .
####       "      <select name=tissue id=\"tissue\" size=1>" .
####       "         <option value=\"\">[Any]</option>" .
####       "         <dtml-var \"BackEnd('',0,CGAPCGI,BASE,'GetSelectMenu.pl','','TABLE',REQUEST,{'TABLE':'MITELMAN_TISSUE'})\">" .
####       "      </select>" .
####       "   </td>" .
####       "</tr>" .
####       "</table>" .
####       "<P>" .
####       "<b>Previous Tumor</b> " .
####       "" .
####       "<table border=0 cellpadding=3 cellspacing=4 width=\"100%\">" .
####       "<TR>" .
####       "   <td valign=top align=right width=25%>" .
####       "      Previous Tumor:" .
####       "   </td>" .
####       "   <td>" .
####       "      <input type=\"radio\" name=\"prevneo\" id=\"Any\" value=\"\" checked><label for=\"Any\">Any</label><BR>" .
####       "      <input type=\"radio\" name=\"prevneo\" id=\"Yes\" value=\"Y\" ><label for=\"Yes\">Yes</label><BR>" .
####       "      <input type=\"radio\" name=\"prevneo\" id=\"No_Unknown\" value=\" \" ><label for=\"No_Unknown\">No/Unknown</label> " .
####       "      " .
####       "   </td>" .
####       "</tr>" .
####       "<tr><td>" .
####       "    </td>" .
####       "    <td>" .
####       "       <a href=\"javascript:document.pform.action='CytSearchFormForDiffMenu';document.pform.prevtop_size.value=40;document.pform.page.value=11;document.pform.submit()\">Expanding Viewable List:</A>" .
####       "    </td>" .
####       "</tr>" .
####       "<tr>" .
####       "   <td valign=top align=right>" .
####       "      Topography:" .
####       "   </td>" .
####       "   <td>" .
####       "      <select name=prevtop id=\"Topography\" size=5 multiple>" .
####       "         <dtml-var \"BackEnd('',0,CGAPCGI,BASE,'GetSelectMenu.pl','','TABLE',REQUEST,{'TABLE':'MITELMAN_TOP'})\">" .
####       "      </select>" .
####       "   </td>" .
####       "</tr>" .
####       "<tr><td></td>" .
####       "    <td>" .
####       "        <a href=\"javascript:document.pform.action='CytSearchFormForDiffMenu';document.pform.prevmorph_size.value=40;document.pform.page.value=13;document.pform.submit()\">Expanding Viewable List:</A>" .
####       "    </td>" .
####       "</tr>" .
####       "<tr>" .
####       "   <td valign=top align=right>" .
####       "      Morphology:" .
####       "   </td>" .
####       "   <td>" .
####       "      <select name=prevmorph id=\"Morphology\" size=5 multiple>" .
####       "         <dtml-var \"BackEnd('',0,CGAPCGI,BASE,'GetSelectMenu.pl','','TABLE',REQUEST,{'TABLE':'MITELMAN_MORPH'})\">" .
####       "      </select>" .
####       "   </td>" .
####       "</tr>" .
####       "" .
####       "<tr>" .
####       "   <td valign=top align=right>" .
####       "      <label for=\"Treatment\">Treatment:</label>" .
####       "   </td>" .
####       "   <td>" .
####       "      <select name=treat id=\"Treatment\" size=1>" .
####       "         <option value=\"\">[Any]</option>" .
####       "         <dtml-var \"BackEnd('',0,CGAPCGI,BASE,'GetSelectMenu.pl','','TABLE',REQUEST,{'TABLE':'MITELMAN_TREAT'})\">" .
####       "      </select>" .
####       "   </td>" .
####       "</tr>" .
####       "</table>" .
####       "<P>" .
####       "" .
####       "" .
####       "<b>Reference</b>" .
####       "<table cellpadding=3 cellspacing=4 width=\"100%\">" .
####       "<TR>" .
####       "   <td valign=top align=right width=25%><label for=\"Authors\">Authors:</label>" .
####       "   </td>" .
####       "   <td><input type=\"text\" name=\"author\" id=\"Authors\" size=30 maxlength=80>" .
####       "   </td>" .
####       "</tr>" .
####       "<tr>" .
####       "   <td valign=top align=right>" .
####       "      <label for=\"Journal\">Journal:</label>" .
####       "   </td>" .
####       "   <td>" .
####       "      <input type=\"text\" name=\"journal\" id=\"Journal\" size=30 maxlength=80 >" .
####       "   </td>" .
####       "</tr>" .
####       "<tr>" .
####       "   <td valign=top align=right>" .
####       "      <label for=\"Year\">Year:</label>" .
####       "   </td>" .
####       "   <td>" .
####       "      <input type=\"text\" name=\"year\" id=\"Year\" size=10 maxlength=11>" .
####       "   </td>" .
####       "</tr>" .
####       "" .
####       "<tr><TD valign=top>" .
####       "" .
####       "    <table align=right><tr><td valign=top align=right>Specific ID Number:</td></TR>" .
####       "     <tr><td valign=top align=right> &nbsp; </td></TD></TR>" .
####       "    <tr><td valign=top align=right> &nbsp; </td></tr>" .
####       "    </table>" .
####       "   </td><TD>" .
####       "  <table>" .
####       "    <tr><td valign=top><label for=\"refno\">Ref. No.</label></TD>" .
####       "        <TD><input type=\"text\" name=\"refno\" id=\"refno\" size=5 maxlength=5></TD>" .
####       "    </TR>" .
####       "    <TR>" .
####       "       <TD valign=top><label for=\"caseno\">Case No.</label></TD>" .
####       "       <TD><input type=\"text\" name=\"caseno\" id=\"caseno\" size=5 maxlength=5></TD>" .
####       "    </TR>" .
####       "    <TR><td valign=top><label for=\"invno\">Inv. No.</label></TD>" .
####       "        <TD><input type=\"text\" name=\"invno\" id=\"invno\" size=5 maxlength=5></TD>" .
####       "    </TR>" .
####       "  </Table>" .
####       "   </td>" .
####       "</tr>" .
####       "" .
####       "<TR>" .
####       "  <TD> &nbsp; </td><TD> " .
####       "                        <input type=submit> or <input type=reset value=\"Reset Form\">" .
####       "                   </TD>" .
####       "</TR>" .
####       "" .
####       "</table>" .
####       "" .
####       "</form>" .
####       "" .
####       "<blockquote>" .
####       "<P><dtml-var Yellow>" .
####       "</blockquote>" .
####       "" .
####       "" .
####
####
####
}

######################################################################
sub  BuildNewInterface {
  my (
    $page,
    $abnorm_op,
    $abnormality,
    $soleabnorm,
    $age,
    $author,
    $break_op,
    $breakpoint,
    $caseno,
    $country,
    $herdis,
    $immuno,
    $invno,
    $journal,
    $morph,
    $nochrom,
    $noclones,
    $prevmorph,
    $prevneo,
    $prevtop,
    $race,
    $refno,
    $series,
    $sex,
    $specherdis,
    $specmorph,
    $tissue,
    $top,
    $treat,
    $year,
    $totalcases,
    $top_size, 
    $prevtop_size,
    $morph_size,
    $prevmorph_size
  ) = @_;
 
  ## print "8888: $top, $morph <br>";
  my ($checked_a, $checked_b, $page_new_value, $link_name);
  my $html = "<H3>Mitelman Cases Quick Searcher</H3>" .
             "<blockquote><p>The Quick Searcher, like the Full Searcher, analyzes the individual " .
             "patient cases in the Mitelman Database. However, unlike the Full Searcher, it limits " .
             "the search fields to four criteria: abnormality, " .
             "breakpoint, topography, and morphology. It finds all cases that match" .
             "the chosen criteria, organizes them by lead author in the reference, and provides" .
             " a link to the individual patient information and to the reference itself." .
             "              </p>" .
             "              </blockquote>" .
             "<form name=\"pform\" method=\"POST\" action=\"CytList\">" .
             "<input type=hidden name=\"page\" value=1>" .
             "<input type=hidden name=\"morph_size\" value=$morph_size>" .
             "<input type=hidden name=\"prevmorph_size\" value=$prevmorph_size>" .
             "<input type=hidden name=\"top_size\" value=$top_size>" .
             "<input type=hidden name=\"prevtop_size\" value=$prevtop_size>" .
             "<table width=100% cellpadding=4>" .
             "<tr>" .
             "   <td bgcolor=\"#38639d\">" .
             "      <font color=\"white\"><b>Cases Quick Searcher</b></font>" .
             "   </td>" .
             "</table>" .
             "" .
             "<blockquote>" .
             "Brief instructions for using the Quick Searcher:" .
             "<UL>" .
             "<LI>Check \"Yes\" in the \"Sole Abnormality\" field to view cases with only " .
             " one aberration, irrespective of any other item selected." .
             "<LI>Choose one or more of the following five fields to query the database. " .
             "<LI>The default setting for both the Topography and Morphology fields is all items." .
             "     Or select one or more items in each scroll down box." .
             "<LI>Click the link at Special Morphology to view a list of all special morphology terms." .
             "<li>Press Submit Query, or press Reset to begin a new search.</UL>" .
             "</blockquote>" .
             "<table border=\"0\" width=100% cellpadding=4>" .
             "<TR><td align=right>Sole Abnormality:</TD>"; 
             $checked_a = ($soleabnorm eq "0" ? "checked" : ""); 
             $checked_b = ($soleabnorm eq "1" ? "checked" : ""); 
             $html = $html . 
             "<TD valign=top>" .
             "<input type=\"radio\" name=\"soleabnorm\" id=\"No\" value=\"0\" $checked_a><label for=\"No\"> No</label>" .  
             "<input type=\"radio\" name=\"soleabnorm\" id=\"Yes\" value=\"1\" $checked_b><label for=\"Yes\"> Yes</label>" . 
             "</TD>" .  "</TR>" .
             "<tr>" . 
             "<td valign=top width=23%  align=right><label for=\"abnormality\">Abnormality:</label></td>" .
             "<td valign=top>"; 
             $checked_a = ($abnorm_op eq "a" ? "checked" : ""); 
             $checked_b = ($abnorm_op eq "o" ? "checked" : ""); 
             $html = $html . 
             "<input type=radio name=\"abnorm_op\" id=\"And\" value=\"a\" $checked_a><label for=\"And\"> And</label>" .
             "<input type=radio name=\"abnorm_op\" id=\"Or\" value=\"o\" $checked_b><label for=\"Or\"> Or</label>" .
             "<BR>" .
             "<input type=\"text\" name=\"abnormality\" size=32 value=\"$abnormality\" id=\"abnormality\" maxlength=50>" . 
             "</td>" .
             "</td>" .
             "</tr>" . 
             "<tr>" .
             "<td valign=top align=right><label for=\"breakpoint\">Breakpoint:</label>" .
             "</td><TD>";
             $checked_a = ($break_op eq "a" ? "checked" : ""); 
             $checked_b = ($break_op eq "o" ? "checked" : ""); 
             $html = $html . 
             "<input type=radio name=break_op id=\"And\" value=\"a\" $checked_a><label for=\"And\"> And</label>" .
             "<input type=radio name=break_op id=\"Or\" value=\"o\" $checked_b><label for=\"Or\"> Or</label><BR>" .
             "<input type=\"text\" name=\"breakpoint\" id=\"breakpoint\" value=\"$breakpoint\" size=32 maxlength=50>" .
             "</td>" .
             "</tr>" .
             "<tr><td></td><td>";
             if( $page == 3 || $top_size == 40 ) {
               $html = $html . 
                         "<a href=\"javascript:document.pform.action='AbnCytSearchFormForDiffMenu';document.pform.top_size.value=5;document.pform.page.value=4;document.pform.submit()\">"; 
               $link_name = "Collapsing Viewable List";
             }
             elsif( $page == 4 || $top_size == 5 ) {
               $html = $html .               
                         "<a href=\"javascript:document.pform.action='AbnCytSearchFormForDiffMenu';document.pform.top_size.value=40;document.pform.page.value=3;document.pform.submit()\">";          
               $link_name = "Expanding Viewable List";
             }
             $html = $html . 
               $link_name . 
               "</A>" .
               "</td>" .
               "</tr>" .
               "<tr>" .
               "<td valign=top align=right>" .
               "<label for=\"topography\">Topography:</label>" .
               "</td>" .
               "<td valign=top>";
               if( $page == 3 || $top_size == 40 ) {
                 $html = $html . 
                   "<select name=top id=\"topography\" size=\"40\" multiple>"; 
               } 
               elsif( $page == 4 || $top_size == 5 ) {
                 $html = $html .              
                   "<select name=top id=\"topography\" size=\"5\" multiple>";     
               }
               $html = $html .              
                 GetSelectMenu_2('MITELMAN_TOP', $top) .
               "</select> " .
               "</td>" .
               "</tr>" .
               "<tr><td></td><td>";
             if( $page == 5 || $morph_size == 40 ) {
               $html = $html .
                         "<a href=\"javascript:document.pform.action='AbnCytSearchFormForDiffMenu';document.pform.morph_size.value=5;document.pform.page.value=6;document.pform.submit()\">";
               $link_name = "Collapsing Viewable List";
             }
             elsif( $page == 6 || $morph_size == 5 ) {
               $html = $html .             
                         "<a href=\"javascript:document.pform.action='AbnCytSearchFormForDiffMenu';document.pform.morph_size.value=40;document.pform.page.value=5;document.pform.submit()\">";
               $link_name = "Expanding Viewable List";
             }             
             $html = $html .
               $link_name .
               "</A>" .
               "</td>" .
               "</tr>" .
               "<tr>" .
               "   <td valign=top align=right>" .
               "      <label for=\"morphology\">Morphology:</label>" .
               "   </td>" .
               "   <td>"; 
               if( $page == 5 || $morph_size == 40) {
                 $html = $html .
                   "<select name=morph id=\"morphology\" size=40 multiple>"; 
               }
               elsif( $page == 6 || $morph_size == 5 ) {
                 $html = $html .
                   "<select name=morph id=\"morphology\" size=5 multiple>"; 
               }
               $html = $html .
                 GetSelectMenu_2('MITELMAN_MORPH', $morph) .

               "      </select>" .
               "   </td>" .
               "</tr>" .
               "<tr>" .
               "   <td align=right>" .
               "<label for=\"specmorph\">" .
               "<a href=javascript:spawn(\"/Chromosomes/HelpLists?FIELDNAME=specmorph&TABLENAME=cytogen\")>Special Morphology:</A>" .
               "</label>" .
               "      </td>" .
               "   <td valign=top>" .
               "      <input type=\"text\" name=\"specmorph\" id=\"specmorph\" value=\"$specmorph\" size=32 maxlength=50>" .
               "   </td>" .
               "</tr>" .
               "<tr><td &nbsp;></td><td colspan=2><input type=submit> or <input type=reset value=\"Reset Form\">" .
               "</td>" .
               "</table>" .
               "</form>"; 
##        "<blockquote>" .
##        "<dtml-var Yellow>" .
##        "</blockquote>" .

  return $html;
}


######################################################################
sub CytSearch_1 {
  my (
    $page,
    $abnorm_op,
    $abnormality,
    $soleabnorm,
    $age,
    $author,
    $break_op,
    $breakpoint,
    $caseno,
    $country,
    $herdis,
    $immuno,
    $invno,
    $journal,
    $morph,
    $nochrom,
    $noclones,
    $prevmorph,
    $prevneo,
    $prevtop,
    $race,
    $refno,
    $series,
    $sex,
    $specherdis,
    $specmorph,
    $tissue,
    $top,
    $treat,
    $year,
    $totalcases
  ) = @_;

  InitializeDatabase();

  my $sql = BuildSearchQuery (
    $page,
    $abnorm_op,
    $abnormality,
    $soleabnorm,
    $age,
    $author,
    $break_op,
    $breakpoint,
    $caseno,
    $country,
    $herdis,
    $immuno,
    $invno,
    $journal,
    $morph,
    $nochrom,
    $noclones,
    $prevmorph,
    $prevneo,
    $prevtop,
    $race,
    $refno,
    $series,
    $sex,
    $specherdis,
    $specmorph,
    $tissue,
    $top,
    $treat,
    $year,
    $totalcases
  );

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database. \n";
    return "";
  }

  my (@row, @rows);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (@row = $stm->fetchrow_array()) {
        push @rows, [ @row ];
      }
      ## if (@rows == 0) {
      ##   SetStatus(S_NO_DATA);
      ## }
    } else {
      print "execute failed"; 
      $db->disconnect();
      return "";
    }
  }
  $db->disconnect();

  my $cmd = 
      ($abnorm_op ? "abnorm_op=$abnorm_op&" : "") .
      ($abnormality ? "abnormality=$abnormality&" : "") .
      ($soleabnorm ? "soleabnorm=$soleabnorm&" : "") .
      ($break_op ? "break_op=$break_op&" : "") .
      ($breakpoint ?"breakpoint=$breakpoint&" : "") .
      ($noclones ? "noclones=$noclones&" : "") .
      ($nochrom ? "nochrom=$nochrom&" : "") .
      ($sex ? "sex=$sex&" : "") .
      ($age ? "age=$age&" : "") .
      ($race ? "race=$race&" : "") .
      ($country ? "country=$country&" : "") .
      ($series ? "series=$series&" : "") .
      ($herdis ? "herdis=$herdis&" : "") .
      ($specherdis ? "specherdis=$specherdis&" : "") .    
      ($top ? "top=$top&" : "") .
      ($immuno ? "immuno=$immuno&" : "") .
      ($morph ? "morph=$morph&" : "") .    
      ($specmorph ? "specmorph=$specmorph&" : "") .
      ($tissue ? "tissue=$tissue&" : "") .
      ($prevneo ? "prevneo=$prevneo&" : "") .    
      ($prevtop ? "prevtop=$prevtop&" : "") .
      ($prevmorph ? "prevmorph=$prevmorph&" : "") .
      ($treat ? "treat=$treat&" : "") .
      ($author ? "author=$author&" : "") .    
      ($journal ? "journal=$journal&" : "") .
      ($year ? "year=$year&" : "") .
      ($refno ? "refno=$refno&" : "") .
      ($caseno ? "caseno=$caseno&" : "") .    
      ($invno ? "invno=$invno&" : "");

  my $cmd1 = "CytList?" . $cmd;

  $cmd =~ s/\(/%28/g;
  $cmd =~ s/\)/%29/g;
  $cmd =~ s/;/%3B/g;
  $cmd =~ s/, */%2C/g;
  $cmd =~ s/\?/%3F/g;
  $cmd =~ s/\"/%22/g;
  $cmd =~ s/\+/%2B/g;
  $cmd =~ s/ /+/g;

  $cmd = "CytList?" . $cmd;

  if (@rows) {
    return 
        (join "", @{ FormatRows(\@rows, $page, $cmd, $cmd1) });
  } else {
    ## return "<!-- $sql -->\n" .
    return "No data matching the query<br><br>\n";
  }
}

######################################################################
sub Create_new_interface_1 {
  my (
    $page,
    $abnorm_op,
    $abnormality,
    $soleabnorm,
    $age,
    $author,
    $break_op,
    $breakpoint,
    $caseno,
    $country,
    $herdis,
    $immuno,
    $invno,
    $journal,
    $morph,
    $nochrom,
    $noclones,
    $prevmorph,
    $prevneo,
    $prevtop,
    $race,
    $refno,
    $series,
    $sex,
    $specherdis,
    $specmorph,
    $tissue,
    $top,
    $treat,
    $year,
    $totalcases,
    $top_size, 
    $prevtop_size,
    $morph_size,
    $prevmorph_size
  ) = @_;
 
  if( $page == 3 || $page == 4 || $page == 5 || $page == 6 ) {
    return BuildNewInterface (
      $page,
      $abnorm_op,
      $abnormality,
      $soleabnorm,
      $age,
      $author,
      $break_op,
      $breakpoint,
      $caseno,
      $country,
      $herdis,
      $immuno,
      $invno,
      $journal,
      $morph,
      $nochrom,
      $noclones,
      $prevmorph,
      $prevneo,
      $prevtop,
      $race,
      $refno,
      $series,
      $sex,
      $specherdis,
      $specmorph,
      $tissue,
      $top,
      $treat,
      $year,
      $totalcases,
      $top_size, 
      $prevtop_size,
      $morph_size,
      $prevmorph_size
    );
  }
  elsif( $page == 7  || $page == 8  || $page == 9  || $page == 10 ||
         $page == 11 || $page == 12 || $page == 13 || $page == 14  ) {
    return BuildFullSearchNewInterface (
      $page,
      $abnorm_op,
      $abnormality,
      $soleabnorm,
      $age,
      $author,
      $break_op,
      $breakpoint,
      $caseno,
      $country,
      $herdis,
      $immuno,
      $invno,
      $journal,
      $morph,
      $nochrom,
      $noclones,
      $prevmorph,
      $prevneo,
      $prevtop,
      $race,
      $refno,
      $series,
      $sex,
      $specherdis,
      $specmorph,
      $tissue,
      $top,
      $treat,
      $year,
      $totalcases,
      $top_size,
      $prevtop_size,
      $morph_size,
      $prevmorph_size
    );
  }
}


######################################################################
sub FormatRows {
  my ($aref, $p, $href, $href1) = @_;
  my ($i, @temp, $start, $stop, $num_pages,$cas,$ref,$inv,$Kary,$tempkary);

  if ($p==0) {
    push @temp, 
        "Reference Number\t" .
        "Case Number\t" .
        "Investigation Number\t" .
        "Author, Year\t" .
        "Journal Name\t" .
        "Volume, Page\t" .
        "Morphology\t" .
        "Topography\t" .
        "Short Karyotype\n";
    for (my $i = 0; $i < @{ $aref }; $i++)  {    
      $$aref[$i][5] = FixTextChar($morph_codes{$$aref[$i][5]});
      $$aref[$i][6] = $topo_codes{$$aref[$i][6]}; 
      $$aref[$i][0] = FixTextChar($$aref[$i][0]);
      push @temp, "$$aref[$i][2]\t$$aref[$i][3]\t$$aref[$i][4]\t".
        "$$aref[$i][0]\t$$aref[$i][1]\t$$aref[$i][10]\t$$aref[$i][5]\t".
        "$$aref[$i][6]\t";
      if ($$aref[$i][8] < 255) {
	push @temp, "$$aref[$i][7]\n";
      } else {
        push @temp, "$$aref[$i][9]\n";
      }
    }
  } else {
    
    ($num_pages, $start, $stop) =
        PagingHeader('Cyt', scalar(@{$aref}), $href, $href1, \@temp, $p);
    my $ref = 1;
    my $cas = 1;
    my $inv = 1;
    for (my $i = 1; $i < @{ $aref }; $i++)  {
      if ($$aref[$i][2] ne $$aref[$i-1][2]) {$ref++;}
      if ($$aref[$i][3] ne $$aref[$i-1][3]) {$cas++;}
      elsif ($$aref[$i][2] ne $$aref[$i-1][2]) {$cas++;}
      $inv++
    }
    push @temp, "<tr><td colspan=3>".
      "<b>Displaying Investigations $start to $stop of $inv found".
      "<br>From $ref References and $cas Cases</b><br></td>\n".
      "</tr></table>\n".
      "<table width=600 border=0>\n";  
    unshift @{ $aref }, ['-','-','-','-','-','-','-'];

    for (my $i = $start; $i <= $stop; $i++)  {
        ##
        ## Reference.Abbreviation
        ## Reference.Journal
        ## CytogenInv.RefNo
        ## CytogenInv.CaseNo
        ## CytogenInv.InvNo
        ## Cytogen.Morph (morphology)
        ## Cytogen.Topo (topography)
        ## CytogenInv.KaryShort
        ## CytogenInv.KaryLength
        ## CytogenInv.KaryLong
        ## Reference.Volume
        ##
        $$aref[$i][5] = $morph_codes{$$aref[$i][5]};
        $$aref[$i][6] = $topo_codes{$$aref[$i][6]};
        $$aref[$i][0] = FixSpecChar($$aref[$i][0]);
        $$aref[$i][5] = FixSpecChar($$aref[$i][5]);  

      if ($$aref[$i][8] > 255) {
        $Kary = FormatKary($$aref[$i][9]);   
      } else {
        $Kary = FormatKary($$aref[$i][7]);   
      }

      ## check for new reference
      if ($$aref[$i][2] ne $$aref[$i-1][2] or $i==$start) {
	push @temp, BuildRefLine($$aref[$i][0],$$aref[$i][1],$$aref[$i][2],'1');
      }  

      ## check for new case
      if ($$aref[$i][3] ne $$aref[$i-1][3] 
       or $$aref[$i][2] ne $$aref[$i-1][2] 
       or $i==$start) {
        push @temp,"<tr>".
          "<td width=100 align=left nowrap>\n".
          "<a href=\"CytCaseInfo?REF=$$aref[$i][2]&CASE=$$aref[$i][3]\">" .
	  "<font color=\"003366\"><b>Case No. $$aref[$i][3]</font></a></td>\n".
	  "<td width=300><font color=\"#993333\"><b>$$aref[$i][5]</font></td>\n".
	  "<td width=198><font color=\"#993333\"><b>$$aref[$i][6]</font></td></tr>\n";
     }

      push @temp,"<tr><td align=center valign=top></td>".
        "<td colspan=3>$Kary</td></tr>\n";
      }    
      push @temp, "</table>\n";


      if ($num_pages > 1) {
        push @temp, "<br>\n" .
	  "<table width=500><tr><td align=center>\n";
        if ($p != 1) { 
          push @temp, "<a href=\"$href" . "page=" . ($p-1) . "\">".
            "<img src=\"". IMG_DIR ."/PrevPage.gif\" border=0 alt=\"PrevPage\"></a>\n";
        }
        if ($p != $num_pages) {           
          push @temp, "<a href=\"$href" . "page=" . ($p+1) . "\">".
            "<img src=\"". IMG_DIR ."/NextPage.gif\" border=0 alt=\"NextPage\"></a>\n";
        }   
        push @temp, "</td></tr></table>";
      }

    }

    for(my $i=0; $i<@temp; $i++) {
      $temp[$i] = convert_special_chr_to_html_code($temp[$i]);

    }
    return \@temp;
  }
 

#####################################################################
sub PagingHeader {

  my ($action,$count,$href,$href1,$temp,$p) = @_;
  my ($num_pages,$start,$stop,$type);  

  if ($action eq 'Cyt') {
    $type = 'cases';
  } elsif ($action eq 'MC') {
    $type = 'investigations';
  } elsif ($action eq 'Ref') {
    $type = 'references';
  }
  
  $action = $action . "List";

  if ($count==0) { 
    push @{$temp}, "<p><b>No $type Found";
  } else { 
    $start = ($p * 100) - 99;
    if ( (($p*100)+1) <= $count ) {
      $stop = ($p * 100);
    } elsif ( (($p*100)+1) > $count ) {
      $stop = $count
    }
  $num_pages = int(scalar($count) / 100);
  if (scalar($count) % 100 > 0) {
    $num_pages = $num_pages + 1;
  }  
  if ($num_pages != 1) {
    push @{$temp}, "<table width=500 border=0><tr>".
      "<td width=\"16%\">";
    if ($num_pages<=25) {
      push @{$temp}, "<b>Go to page:</td><td align=left>\n";
      for (my $a = 1; $a <= $num_pages; $a++) {
        if ($a == $p) {
          push @{$temp}, "<b>$a</b>\n  ";
        } else {
          push @{$temp}, "<a href=\"$href" . "page=$a\"><b>$a</b></a>\n  ";
        }  
      } 
    } else {
      my ($i,$name,$val);
      push @{$temp}, "<form name=pform action=\"$action\" method=GET>\n".
        "<a href=\"javascript:document.pform.submit()\">".
        "<b>Go to page:</td><td align=left>\n";
      my $list = substr $href1, index($href,"?") + 1;
      for $i (split "\&",$list) {
	($name,$val) = split "=",$i;
        push @{$temp}, "<input type=hidden name=$name value=\"$val\">\n";
      }
      push @{$temp}, "<select name=page>";
      for (my $a = 1; $a <= $num_pages; $a++) {
	if ($p==$a) {
	  push @{$temp}, "<option value=$a selected>$a</option>\n";
	} else {
	  push @{$temp}, "<option value=$a>$a</option>\n";
        }
      }
      push @{$temp}, "</select>\n</form>\n";
    }

    push @{$temp}, "<a href=\"$href" . "page=0\"><b>[Full Text]</b></a>\n  ";
    push @{$temp}, "</td><td width=90 align=right>";
    if ($p != 1) { 
      push @{$temp}, "<a href=\"$href" . "page=" . ($p-1) . "\">".
        "<img src=\"". IMG_DIR ."/PrevPage.gif\" border=0 alt=\"PrevPage\"></a>\n";
    }
    if ($p != $num_pages) {           
      push @{$temp}, "<a href=\"$href" . "page=" . ($p+1) . "\">".
        "<img src=\"". IMG_DIR ."/NextPage.gif\" border=0 alt=\"NextPage\"></a>\n";
    }  
    push @{$temp}, "</td></tr>\n";
    } else {push @{$temp}, "<table width=500 border=0><tr><td>".
      "<a href=\"$href" . "page=0\"><b>[Full Text]</b></a>\n ";
    }
}
  return ($num_pages,$start,$stop);

}

######################################################################
sub BuildRefLine {

  my ($abbr,$journal,$refno,$type) = @_;
  my $hr;

  if ($type == 1) {
    $hr = "<hr noshade color=\"003366\">";
  } else {
    $hr = "";
  }

  my $temp = "<tr>\n<td colspan=4>" .
    "<table width=500 cellspacing=0".
    " cellpadding=0 border=0><tr><td bgcolor=\"FFFFFF\">".
    "<a href=\"CytRefInfo?REF=$refno\">" .
    "$hr".
    "<font color=\"003366\"><b>$abbr, $journal" .
    "</font>".
    "$hr".
    "</a>".
    "</td></tr></table></td></tr>\n";

  return $temp;
}
  
######################################################################
use constant HIGHEST_PID_ERROR_CODE => 100;

######################################################################
sub RefFormatRows {
  my ($row) = @_;
  my (@temp);
  my ($count1, $count2, $count3) = CountByRefNo($$row[0]);
    if ($$row[7] >= 256) {
      $$row[2] = $$row[8];
    }
    my $disp = FixSpecChar($$row[2]);
    my $search = FixSearchChar($$row[2]);
    $$row[1] = FixSpecChar($$row[1]);    

    my $c = " ";
    my @d = split (", ",$disp);
    my @s = split (", ",$search); 
    for (my $i=0; $i < @d;$i++) {
      $s[$i] =~ s/ /+/g;
      $c = $c . "<a href=\"RefList?author=$s[$i]&page=1\">$d[$i]</a>,\n";
    }
    my $row3 = $$row[3];
    $row3 =~ s/ /+/g;
    ##
    ## Reference.RefNo
    ## Reference.TitleShort
    ## Reference.AuthorsShort
    ## Reference.Journal
    ## Reference.Volume
    ## Reference.Year
    ## Reference.PubMed
    ## Reference.AuthorsLength
    ## Reference.AuthorsLong
    ##
      
    push @temp,"<tr><td colspan=2 bgcolor=\"#38639d\">\n".
      "<font color=\"white\"><b>Reference Info</b></font></td></tr>\n".
      
      "<tr><td align=right valign=top><b>Reference Number</td>\n".
      "<td valign=top>$$row[0]</td></tr>\n".
      
      "<tr><td align=right valign=top><b>Title</td>\n".         
      "<td valign=top>$$row[1]</td></tr>\n".

      "<tr><td align=right valign=top><b>Authors</td>\n".         
      "<td valign=top>$c</td></tr>\n".    

      "<tr><td align=right valign=top><b>Journal</td>\n".         
      "<td valign=top><a href=\"RefList?journal=%22$row3%22&page=1\"> ".
      "$$row[3]</a></td></tr>\n".

      "<tr><td align=right valign=top><b>Volume</td>\n".         
      "<td valign=top>$$row[4]</td></tr>\n".

      "<tr><td align=right valign=top><b>Year</td>\n".         
      "<td valign=top>$$row[5]</td></tr>\n";

    unshift @temp, "<table width=500 cellspacing=3 cellpadding=3 border=0>\n";
    push @temp, "</table>\n<p><p>\n";
    push @temp, "<table cellspacing=15><tr>\n";
    if ($$row[6] > HIGHEST_PID_ERROR_CODE) {
      push @temp,"<td><a href=javascript:spawn(\"" .
        "http://www.ncbi.nlm.nih.gov:80/entrez/query.fcgi?".
        "cmd=Retrieve&db=PubMed&list_uids=$$row[6]&dopt=Abstract\")>".
	"<font color=\"#003366\"><b>PubMed</font></a></td>\n";
    }
    if ($count1) {
      push @temp, "<td><a href=\"CytList?refno=$$row[0]&page=1\">\n".
        "<font color=\"#003366\"><b>All Cases</font></a></td>\n";
    }
    if ($count2) {
      push @temp, "<td><a href=\"MCList?op=M&refno=$$row[0]&page=1\">\n".
        "<font color=\"#003366\"><b>MolBiol</font></a></td>\n";
    }
    if ($count3) {
      push @temp, "<td><a href=\"MCList?op=C&refno=$$row[0]&page=1\">\n".
        "<font color=\"#003366\"><b>ClinAssoc</font></a></td>\n";
    }
    push @temp, "</tr></table>\n";
    for(my $i=0; $i<@temp; $i++) {
      $temp[$i] = convert_special_chr_to_html_code($temp[$i]);

    }
    return \@temp;
}


######################################################################
sub GetMitelmanTotal_1 {
  my ($what) = @_;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database. \n";
    return "";
  }

  my $sql = "select $what from $CGAP_SCHEMA.MITELMAN_UPDATE_INFO";
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if (!$stm->execute()) {
    print "execute failed\n";
    $db->disconnect();
    return;
  }
 
  if( $what eq "UPDATE_DATE,TOTAL" ) {
    while ( my ($update_date, $total) = $stm->fetchrow_array()) {
      my $int_with_comma = AddCommatoInteger($total);
      if( !$db->ping ) {
        $db->disconnect();
      }
      return "$update_date<BR> Total number of cases = " .
             "<font color=\"#ab0534\"><b>$int_with_comma</b></font><BR>";
    }
  }
  elsif( $what eq "YEAR" ) {
    while ( my ($year) = $stm->fetchrow_array()) {
      if( !$db->ping ) {
        $db->disconnect();
      }
      return $year;
    }
  }
  $db->disconnect();
}

######################################################################
sub GetSelectMenu_1 {
  my ($table_name) = @_;
  ## print "8888: $table_name<br>";
  my $output = "";
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database. \n";
    return "";
  }

  my $sql = "select LINE from $CGAP_SCHEMA.$table_name";
  my $stm = $db->prepare($sql);
  if (not $stm) {
    
    print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>$sql</b>!</center>";
    $db->disconnect();
    return "";
  }
  if (!$stm->execute()) {
    print "execute failed\n";
    $db->disconnect();
    return;
  }
 
  while ( my ($line) = $stm->fetchrow_array()) {
    if( $table_name =~ /MORPH$/ ) {
      $line = FixSpecChar($line);
    } 
    $output = $output . $line . "\n";
  }
  $db->disconnect();
  ## $output = "<select name=country id=\"country\" size=5 multiple>" . "\n" . $output  . "</select>";
  return $output;
}

######################################################################
sub GetSelectMenu_2 {
  my ($table_name, $select) = @_;
  ## print "8888: $table_name<br>";
  my $output = "";
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database. \n";
    return "";
  }
 
  my $sql = "select LINE from $CGAP_SCHEMA.$table_name";
  my $stm = $db->prepare($sql);
  if (not $stm) {
 
    print "<br><b><center>Error in input</b>!</center>";
    ## print "<br><b><center>$sql</b>!</center>";
    $db->disconnect();
    return "";
  }
  if (!$stm->execute()) {
    print "execute failed\n";
    $db->disconnect();
    return;
  }
 
  if( $select eq "" ) {
    while ( my ($line) = $stm->fetchrow_array()) {
      if( $table_name =~ /MORPH$/ ) {
        $line = FixSpecChar($line);
      }
      $output = $output . $line . "\n";
    }
    $db->disconnect();
    ## $output = "<select name=country id=\"country\" size=5 multiple>" . "\n" . $output  . "</select>";
    return $output;
  }
  else {
    my @values = split ",", $select;
    while ( my ($line) = $stm->fetchrow_array()) {
      if( $table_name =~ /MORPH$/ ) {
        $line = FixSpecChar($line);
      }
      for (my $i=0; $i<@values; $i++) {
        if( $line =~ $values[$i] ) {
          $line =~ s/$values[$i]/$values[$i] selected/;
        } 
      }
      $output = $output . $line . "\n";
    }
    $db->disconnect();
    ## $output = "<select name=country id=\"country\" size=5 multiple>" . "\n" . $output  . "</select>";
    return $output;
  } 
}


######################################################################
sub CytRefInfo_1 {
  my ($refno) = @_;

  my $sql = "select r.RefNo, r.TitleShort, r.AuthorsShort, ".
    "r.Journal, r.Volume, r.Year, r.PubMed, ". 
    "r.AuthorsLength, r.AuthorsLong ".
    "from $CGAP_SCHEMA.Reference r ".
    "where r.RefNo = $refno";

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database. \n";
    return "";
  }

  my (@row, @rows);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>"; 
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (@row = $stm->fetchrow_array()) {
        push @rows, [ @row ];
      }
      if (@rows == 0) {
        ## SetStatus(S_NO_DATA);
      } elsif (@rows > 1) {
        print "mulitple references found";
        $db->disconnect();
        return "Reference not found";
      }
    } else {
      $db->disconnect();
      return "Reference not found";
    }
  }
  $db->disconnect();
  if (@rows) {
    ## return "<!-- $sql -->\n" .
    return (join "", @{ RefFormatRows($rows[0]) });
  } else {
    ## return "<!-- $sql -->\n" .
    return "No data matching the query<br><br>\n";
  }

}

######################################################################
sub CaseFormatRows {
  my ($aref) = @_;

  my (@temp,$Kary,$i);

  my (
      $refno,           # [0]
      $caseno,
      $karyshort,
      $sex,
      $age,
      $race,            # [5]
      $country,
      $series,
      $herdis,
      $topo,
      $immunology,      # [10]
      $morph,
      $tissue,
      $prevtopo,
      $prevmorph,
      $prevtreat,       # [15]
      $authorsshort,
      $journal,
      $year,
      $invno,
      $karylength,      # [20]
      $karylong,
      $specmorph,
      $specherdis,
      $specobs,
      $abbreviation     # [25]
    ) = @{ $$aref[0] };

    my $morph_name     = $morph_codes{$morph};
    my $topo_name      = $topo_codes{$topo};
    my $prevmorph_name = $morph_codes{$prevmorph};
    my $prevtopo_name  = $topo_codes{$prevtopo};
    my $country_name   = $country_codes{$country};
    my $tissue_name    = $tissue_codes{$tissue};
    my $herdis_name    = $herdis_codes{$herdis};

    $specmorph    = FixSpecChar($specmorph);
    $specherdis   = FixSpecChar($specherdis);
    $specobs      = FixSpecChar($specobs);
    $abbreviation = FixSpecChar($abbreviation);
    $morph_name   = FixSpecChar($morph_name);

      ##
      ## CytogenInv.RefNo
      ## CytogenInv.CaseNo
      ## CytogenInv.KaryShort
      ## Cytogen.Sex
      ## Cytogen.Age
      ## Cytogen.Race
      ## Cytogen.Country
      ## Cytogen.Series
      ## Cytogen.HerDis
      ## Cytogen.Topo
      ## Cytogen.Immunology
      ## Cytogen.Morph
      ## CytogenInv.Tissue
      ## Cytogen.PrevTopo
      ## Cytogen.PrevMorph
      ## Cytogen.PrevTreat
      ## Reference.AuthorsShort
      ## Reference.Journal
      ## Reference.Year
      ## CytogenInv.InvNo
      ## CytogenInv.KaryLength
      ## CytogenInv.KaryLong
      ## Cytogen.SpecMorph
      ## Cytogen.SpecHerDis 
      ## Cytogen.SpecObs
      ## Reference.Abbreviation
      ##

     
      if ($sex eq 'M') {$sex = 'Male'}
      elsif ($sex eq 'F') {$sex = 'Female'}

      if ($race eq 'A') {$race = 'Asian'}
      elsif ($race eq 'B') {$race = 'Black'}
      elsif ($race eq 'W') {$race = 'White'}
      elsif ($race eq 'O') {$race = 'Other'}

      if ($series eq 'S') {$series = 'Selected'}
      elsif ($series eq 'U') {$series = 'Unselected'}
      if ($immunology eq 'B') {$immunology = 'B Lineage'}
      elsif ($immunology eq 'T') {$immunology = 'T Lineage'}
      elsif ($immunology eq 'N') {$immunology = ''}

      $prevtreat =~ s/R/ Radiotherapy/g;
      $prevtreat =~ s/C/ Chemotherapy/g;      
      $prevtreat =~ s/S/ Surgery/g;      

      if ($specmorph) {
	$morph_name = "$morph_name" . "</a>; $specmorph";
      }

      if ($specherdis) {
        $herdis = "$herdis". "; $specherdis";
      }  

   push @temp,
     "<table width=500 cellspacing=0".
     " cellpadding=0 border=0><tr><td bgcolor=\"FFFFFF\">".
     "<a href=\"CytRefInfo?REF=$refno\">" .
     "<hr noshade color=\"003366\">".
     "<font color=\"003366\"><b>$abbreviation, $journal" .
     "</font><hr noshade color=\"003366\"></a></td>\n" .
     "</tr><tr>".
     "<td><font color=\"003366\"><b>Case Number $caseno</font>".
     "</td></tr></table>\n";

    push @temp, "<table width=500 cellspacing=3 cellpadding=3>\n".
      "<tr><td colspan=2 bgcolor=\"#38639d\">\n".
      "<font color=\"white\"><b>Karyotype</b></font></td></tr>\n";

    for (my $i = 0; $i < @{ $aref }; $i++)  {     
      if ($karylength>256) {
        my $karylong_local = @{ $$aref[$i] }[21];
        $Kary=FormatKary($karylong_local);
      } else {
        my $karyshort_local = @{ $$aref[$i] }[2];
        $Kary=FormatKary($karyshort_local);
      } 
      push @temp,"<tr>".
        "<td valign=top colspan=2>$Kary</td></tr>\n";
    }
      
    push @temp, "<tr><td colspan=2 bgcolor=\"#38639d\">\n".
      "<font color=\"white\"><b>Patient Characteristics".
      "</b></font></td></tr>\n".
      
      "<tr><td align=right width=\"12%\"><b>Sex</td>\n".         
      "<td>$sex</td></tr>\n".

      "<tr><td align=right><b>Age</td>\n".         
      "<td>$age</td></tr>\n".    

      "<tr><td align=right><b>Race</td>\n".         
      "<td>$race</td></tr>\n".

      "<tr><td align=right><b>Country</td>\n<td>".         
      "$country_name</td></tr>\n".

      "<tr><td align=right><b>Series</td>\n".         
      "<td>$series</td></tr>\n".

      "<tr><td align=right><b>Hereditary Disorder</td>\n".         
      "<td>$herdis</td></tr>\n".

      "<tr><td colspan=2 bgcolor=\"#38639d\">\n".
      "<font color=\"white\"><b>Present Tumor".
      "</b></font></td></tr>\n".
      
      "<tr><td align=right><b>Topography</td>\n".         
      "<td><a href=\"CytList?top=$topo&page=1\">".
      "$topo_name</a></td></tr>\n".

      "<tr><td align=right><b>Immunophenotype</td>\n".         
      "<td>$immunology</td></tr>\n".    

      "<tr><td align=right><b>Morphology</td>\n".         
      "<td><a href=\"CytList?morph=$morph&page=1\">".
      "$morph_name</td></tr>\n".

      "<tr><td align=right><b>Tissue</td>\n".         
      "<td>$tissue_name</td></tr>\n".

      "<tr><td colspan=2 bgcolor=\"#38639d\">\n".
      "<font color=\"white\"><b>Previous Tumor".
      "</b></font></td></tr>\n".
      
      "<tr><td align=right><b>Topography</td>\n".         
      "<td><a href=\"CytList?prevtop=$prevtopo&page=1\">".
      "$prevtopo_name</a></td></tr>\n".

      "<tr><td align=right><b>Morphology</td>\n".         
      "<td><a href=\"CytList?prevmorph=$prevmorph&page=1\">".
      "$prevmorph_name</a></td></tr>\n".    

      "<tr><td align=right><b>Treatment</td>\n".         
      "<td>$prevtreat</td></tr>\n";
 
    push @temp, "</table>\n";
    for(my $i=0; $i<@temp; $i++) {
      $temp[$i] = convert_special_chr_to_html_code($temp[$i]);

    }
    return \@temp;
}

######################################################################
sub CytCaseInfo_1 {
  my ($refno, $caseno) = @_;

  InitializeDatabase();

  my $sql = 
      "select c.RefNo, c.CaseNo, c.KaryShort, ".
      "y.Sex, y.Age, y.Race, y.Country, y.Series, y.HerDis, ".
      "y.Topo, y.Immunology, y.Morph, c.Tissue, y.PrevTopo, ".
      "y.PrevMorph, y.PrevTreat, r.AuthorsShort, ". 
      "r.Journal, r.Year, c.InvNo, c.KaryLength, c.KaryLong, y.SpecMorph, ".
      "y.SpecHerDis, y.SpecObs, r.Abbreviation from $CGAP_SCHEMA.CytogenInv c, ".
      "$CGAP_SCHEMA.Cytogen y, $CGAP_SCHEMA.Reference r ".
      "where c.RefNo = r.RefNo and c.RefNo = $refno and c.CaseNo = '$caseno'".
      "  and c.CaseNo = y.CaseNo and c.RefNo = y.RefNo";

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  my (@row, @rows);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (@row = $stm->fetchrow_array()) {
        push @rows, [ @row ];
      }
      ## if (@rows == 0) {
      ##   SetStatus(S_NO_DATA);
      ## }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "<br>case not found";
    }
  }
  $db->disconnect();
  return (join "", @{ CaseFormatRows(\@rows) });

}

######################################################################
sub BuildMCQuery {
  my (
    $page,
    $abnorm_op,
    $abnormality,
    $author,
    $break_op,
    $breakpoint,
    $gene_op,
    $gene,
    $immuno,
    $invno,
    $journal,
    $morph,
    $op,
    $refno,
    $top,
    $year
  ) = @_;

  InitQuery(
      "select distinct r.Abbreviation, r.journal, " .
      "c.Refno, c.InvNo, c.Morph, c.Top, c.KaryShort, " .
      "c.Geneshort, c.immunology from $CGAP_SCHEMA.MolBiolClinAssoc c, " .
      "$CGAP_SCHEMA.Reference r" .
      ($gene               ? ", $CGAP_SCHEMA.MolClinGene k"         : "") .
      ($abnormality        ? ", $CGAP_SCHEMA.MolClinAbnorm a"       : "") .
      ($breakpoint         ? ", $CGAP_SCHEMA.MolClinBreak br"       : "") .
      ($author             ? ", $CGAP_SCHEMA.AuthorReference ar"    : "") 
  );

  Add("c.Refno = r.Refno");
  Add("c.MolClin = '$op'");
## NOTE: we now have "c.Refno = r.Refno" specified potentially 
## more than once
  
  if ($author and ($year or $journal)) {
    Add("r.RefNo = ar.RefNo and c.RefNo = r.RefNo");
  } else {
    if ($author) {
      Add("c.RefNo = ar.RefNo");
    }
    if ($year or $journal) {
      Add("c.RefNo = r.RefNo");
    }
  }

  if ($year) {
    Add(DoRange("r.year", $year, 1));
  }
  
  if ($abnormality) {
    Add("c.RefNo = a.RefNo and c.InvNo = a.InvNo");
    Add("a.molclin = '$op'");
  }
  
  if ($breakpoint) {
    Add("c.RefNo = br.RefNo and c.InvNo = br.InvNo");
    Add("br.molclin = '$op'");
  }
  
  if ($gene) {
    Add("c.RefNo = k.RefNo and c.InvNo = k.InvNo");
    Add("k.molclin = '$op'");
  }

  if ($refno) {
    Add(DoRange("c.RefNo", $refno, 1));
  }
  
  if ($invno) {
    Add(DoRange("c.InvNo", $invno, 1));;
  }
  
  if ($immuno) {
    Add(DoOpList("c.Immunology", "=", $immuno, 0));
  }

  if ($morph) {
    Add(DoWildCardable("c.Morph", $morph));
  }
  
  if ($top) {
    Add(DoWildCardable("c.Top", $top));
  }

  if ($author) {
    my @authors = FixAuthorInput($author);
    Add(
        "( " .
        DoAndOrPile("AuthorReference", "ar", "Name", "c", @authors) .
        " )"
    );
  }

  if ($journal) {
    $journal =~ tr/A-Z/a-z/;
    $journal =~ tr/*/%/;
    my @journals = split(",", $journal);
    Add(
        "( " .
        DoAndOrPile("Reference", "r", "Journal", "c", @journals) .
        " )"
    );
  }
  
  if ($abnormality) {
    $abnormality =~ tr/A-Z/a-z/;
    $abnormality =~ tr/*/%/;
                                        # inside (), separator should be ;
#   while ($abnormality =~ /(\([^,]+,[^\)]+\))/gc) {
#     $abnormality =~ s/,/;/;
#   }
    my @parts = split(",", $abnormality);
    Add(
        "( " .
        DoAndOrPile("MolClinAbnorm", "a", "Abnormality", $abnorm_op, @parts) .
        " )"
    );
  }

  if ($gene) {
    $gene =~ tr/A-Z/a-z/;
    $gene =~ tr/*/%/;
    my @parts = split(",", $gene);
    Add(
        "( " .
        DoGenePile("MolClinGene", "k", "Gene", $gene_op, @parts) .
        " )"
    );
  }

  if ($breakpoint) {
    $breakpoint =~ tr/A-Z/a-z/;
    $breakpoint =~ tr/*/%/;
    my @parts = split(",", $breakpoint);
    Add(
        "( " .
        DoAndOrPile("MolClinBreak", "br", "Breakpoint", $break_op, @parts) .
        " )"
    );
  }

  $query = "$query order by r.Abbreviation, c.Refno, c.Invno";
  return $query;

}
######################################################################
sub MCSearch_1 {
  my (
    $base,
    $page,
    $abnorm_op,
    $abnormality,
    $author,
    $break_op,
    $breakpoint,
    $gene_op,
    $gene,
    $immuno,
    $invno,
    $journal,
    $morph,
    $op,
    $refno,
    $top,
    $year
  ) = @_;

   InitializeDatabase();

  &debug_print( " in MCSearch:
     $base,
    $page,
    $abnorm_op,  
    $abnormality,
    $author,  
    $break_op,
    $breakpoint,
    $gene_op, 
    $gene,  
    $immuno,
    $invno,
    $journal,
    $morph, 
    $op,  
    $refno,
    $top, 
    $year
    ");
  $BASE = $base;

  my $sql = BuildMCQuery (
    $page,
    $abnorm_op,
    $abnormality,
    $author,
    $break_op,
    $breakpoint,
    $gene_op,
    $gene,
    $immuno,
    $invno,
    $journal,
    $morph,
    $op,
    $refno,
    $top,
    $year
  );

  &debug_print( "sql in MCSearch : $sql " );

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }

  my (@row, @rows);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (@row = $stm->fetchrow_array()) {
        push @rows, [ @row ];
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

  my $cmd = 
      ($op ? "op=$op&" : "") .
      ($abnorm_op ? "abnorm_op=$abnorm_op&" : "") .
      ($abnormality ? "abnormality=$abnormality&" : "") .
      ($break_op ? "breakpoint=$breakpoint&" : "") .
      ($breakpoint ?"breakpoint=$breakpoint&" : "") .
      ($gene_op ? "gene_op=$gene_op&" : "") .
      ($gene ? "gene=$gene&" : "") .
      ($top ? "top=$top&" : "") .
      ($immuno ? "immuno=$immuno&" : "") .
      ($morph ? "morph=$morph&" : "") .    
      ($author ? "author=$author&" : "") .    
      ($journal ? "journal=$journal&" : "") .
      ($year ? "year=$year&" : "") .
      ($refno ? "refno=$refno&" : "") .
      ($invno ? "invno=$invno&" : "");

  my $cmd1 = "MCList?" . $cmd;

  $cmd =~ s/ /+/g;
  $cmd =~ s/\(/%28/g;
  $cmd =~ s/\)/%29/g;
  $cmd =~ s/;/%3B/g;
  $cmd =~ s/, /%2C/g;
  $cmd =~ s/\?/%3F/g;
  $cmd =~ s/,/%2C/g;
  $cmd =~ s/\"/%22/g;

  $cmd = "MCList?" . $cmd;

  if (@rows) {
    return (join "", @{ MCFormatRows(\@rows, $page, $cmd, $cmd1) });
  } else {
    return "No data matching the query<br><br>\n";
  }
}
######################################################################
sub MCFormatRows {
  my ($aref, $p, $href, $href1) = @_;
  my ($i, @temp, $start, $stop, $num_pages,$cas,$ref,$inv,$Kary,$tempkary);
  my (@sgene, @aref7, $loc, $cid, $x, $xgene, $asep);
  my ($db, $sql, $stm);

  if ($p==0) {
    push @temp,
        "Author, Year\t" .
        "Journal\t" .
        "Reference Number\t" .
        "Investigation Number\t" .
        "Morphology\t" .
        "Topography\t" .
        "Short Karyotype\t" .
        "Gene\n";
    for (my $i = 0; $i < @{ $aref }; $i++)  {    
      $$aref[$i][4] = FixTextChar($morph_codes{$$aref[$i][4]});
      $$aref[$i][5] = $topo_codes{$$aref[$i][5]}; 
      $$aref[$i][0] = FixTextChar($$aref[$i][0]);
      push @temp, (join "\t", @{$$aref[$i]}) . "\n"; 
    }
  } else {

    ($num_pages,$start,$stop) =
        PagingHeader('MC',scalar(@{$aref}),$href,$href1,\@temp,$p);

    my $ref = 1;
    my $inv = 1;
    for (my $i = 1; $i < @{ $aref }; $i++)  {
      if ($$aref[$i][2] ne $$aref[$i-1][2]) {$ref++;}
      $inv++
    }
    push @temp, "<tr><td colspan=3>".
      "<b>Displaying Investigations $start to $stop of $inv found".
      "<br>From $ref References</b><br></td>\n".
      "</tr></table>\n".
      "<table width=600 border=0>\n";  
    unshift @{ $aref }, ['-','-','-','-','-','-','-'];

    $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
    if (not $db or $db->err()) {
      ##print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
      print "Cannot connect to database\n";
      return;
    }

    for (my $i = $start; $i <= $stop; $i++)  {
        ##
        ## Reference.Abbreviation
        ## Reference.Journal
        ## MolBiolClinAssoc.RefNo
        ## MolBiolCLinAssoc.InvNo
        ## MolBiolCLinAssoc.Morph (morphology)
        ## MolBiolCLinAssoc.Top (topography)
        ## MolBiolCLinAssoc.KaryShort
        ## MolBiolCLinAssoc.Gene
        ##
        $$aref[$i][4] = $morph_codes{$$aref[$i][4]};
        $$aref[$i][5] = $topo_codes{$$aref[$i][5]};
        $$aref[$i][0] = FixSpecChar($$aref[$i][0]);
        $$aref[$i][4] = FixSpecChar($$aref[$i][4]);
        $$aref[$i][8] =~ s/B/B-Lineage/g;
        $$aref[$i][8] =~ s/T/T-Lineage/g;
        $$aref[$i][8] =~ s/N//g;          

        my $sgene = $$aref[$i][7];
        if( $sgene =~ /\// and $sgene =~ /,/ ) {
          my @tmp_a = split ",", $sgene;
          for (my $i=0; $i<@tmp_a; $i++) {
            if ( $tmp_a[$i] =~ /\// ) {
              my @sub_tmp = split "\/", $tmp_a[$i];
              push @aref7, $sub_tmp[0] . "/";
              push @aref7, $sub_tmp[1];
            }
            else {
              push @aref7, $tmp_a[$i];
            }
          }
        }
        else {
          @aref7 = split "\/", $sgene;
        }
        if ($sgene =~ /,/) {
          $asep = ',';
        } else {
          $asep = '/';
        }
        $sgene =~ s/\+//g;
        $sgene =~ s/-//g;
        $sgene =~ s/\//,/g;
        $sgene =~ s/,/&#037;,/g;
        $sgene = $sgene . "&#037;";
        @sgene = split ",", $sgene;

      ## check for new reference
      if ($$aref[$i][2] ne $$aref[$i-1][2] or $i==$start) {
        push @temp, BuildRefLine($$aref[$i][0],$$aref[$i][1],$$aref[$i][2],'1');
      }  

      push @temp,"<tr>".
        "<td width=100 align=left>\n".
##        "<font color=\"#003366\"><b>Inv. No. $$aref[$i][3]</font></td>\n".
        "<font color=\"#003366\">&nbsp;</font></td>\n".
	"<td width=320><font color=\"#993333\"><b>$$aref[$i][4]</font></td>\n".
	"<td width=220><font color=\"#993333\"><b>$$aref[$i][5]</font></td></tr>\n";

      if ($$aref[$i][7]) {
        push @temp, "<tr><td></td>".
          "<td colspan=2>";
        for ($x = 0; $x <= $#sgene; $x++) {
          $xgene = $sgene[$x];
          $xgene =~ s/&#037;/%/;
          $sql = "select distinct locuslink, cluster_number " .
                 "from $CGAP_SCHEMA.mitelman_genes " .
                 "where symbol like '$xgene'";

          $stm = $db->prepare($sql);
          if (not $stm) {
            print "<br><b><center>Error in input</b>!</center>";
            $db->disconnect();
            return "";
          } 
          if (!$stm->execute()) {
            print "execute failed\n";
            $db->disconnect();
            return;
          }

          $stm->bind_columns(\$loc, \$cid);

          if ($stm->fetch) {
            if ($cid) {
              push @temp, 
              "<a href=\"$BASE/Genes/GeneInfo?ORG=Hs&CID=$cid\">";
            } elsif ($loc) {
              push @temp, 
              "<a href=javascript:spawn(" .
              "\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?" .
              "db=gene&cmd=Retrieve&dopt=full_report&" .
              "list_uids=$loc\")>";
            }
            push @temp, 
            "<font color=\"#003366\"><b>$aref7[$x]</b>".
            "</font></a>" .
            (($x < $#sgene) ? "$asep" : "");
            $stm->finish;
          } else {
            push @temp, 
            "<font color=\"#003366\"><b>$aref7[$x]</b>".
            (($x < $#sgene) ? "$asep" : "");
          }
        }
        push @temp, "</td></tr>\n";
      }

      if ($$aref[$i][6]) {
        push @temp, "<tr><td></td>".
	  "<td colspan=2>$$aref[$i][6]</td></tr>\n";
      }

      if ($$aref[$i][8]) {
        push @temp, "<tr><td></td>".
          "<td colspan=2>$$aref[$i][8]</td></tr>\n";
      }
    }    

    for( my $i=0; $i<@temp; $i++ ) {
      $temp[$i] =~ s/\/<\/b><\/font><\/a>,/<\/b><\/font><\/a>\//;
    }

    push @temp, "</table>\n";

    $db->disconnect();

    if ($num_pages > 1) {
      push @temp, "<br>\n" .
        "<table width=500><tr><td align=center>\n";
      if ($p != 1) { 
        push @temp, "<a href=\"$href" . "page=" . ($p-1) . "\">".
          "<img src=\"". IMG_DIR ."/PrevPage.gif\" border=0 alt=\"PrevPage\"></a>\n";
      }
      if ($p != $num_pages) {           
        push @temp, "<a href=\"$href" . "page=" . ($p+1) . "\">".
          "<img src=\"". IMG_DIR ."/NextPage.gif\" border=0 alt=\"NextPage\"></a>\n";
      }   
      push @temp, "</td></tr></table>";
    }

  }
  return \@temp;
} 
  

#####################################################################
sub CountByRefNo {
  my ($refno) = @_;
  my $count1 = 0;
  my $count2 = 0;
  my $count3 = 0;

  my $sql1 = "select count(invno) from $CGAP_SCHEMA.CytogenInv ".
    "where refno = $refno";

  my $sql2 = "select count(invno) from $CGAP_SCHEMA.MolBiolClinAssoc ".
    "where refno = $refno and molclin = 'M'";

  my $sql3 = "select count(invno) from $CGAP_SCHEMA.MolBiolClinAssoc ".
    "where refno = $refno and molclin='C'";
  
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return ;
  }

  my (@row);
  my $stm = $db->prepare($sql1);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      @row = $stm->fetchrow_array();
      $count1=$row[0];
      $stm->finish;
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  my $stm = $db->prepare($sql2);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      @row = $stm->fetchrow_array();
      $count2=$row[0];
      $stm->finish;
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  my $stm = $db->prepare($sql3);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      @row = $stm->fetchrow_array();
      $count3=$row[0];
      $stm->finish;
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "";
    }
  }

  $db->disconnect();

  return ($count1,$count2,$count3);
}

######################################################################
sub BuildRefQuery {
  my (
    $page,
    $author,
    $journal,
    $op,
    $refno,
    $year,
    $check_flag
  ) = @_;

  InitQuery(
      "select distinct r.Abbreviation, r.Journal, r.refno " .
      ($check_flag             ? ", r.AUTHORSSHORT " : "") . 
      "from $CGAP_SCHEMA.reference r".
      ($author             ? ", $CGAP_SCHEMA.AuthorReference ar" : "")
  );

  if ($op) {
      my @temp;
    if (index($op, 'C')>=0) {
      push @temp, "(exists (select c.refno from $CGAP_SCHEMA.cytogeninv c where c.refno=r.refno))";
    }  
    if (index($op, 'M')>=0) {
      push @temp, "(exists (select m.refno from $CGAP_SCHEMA.molbiolclinassoc m where m.molclin='M' and m.refno=r.refno))";
    }
    if (index($op, 'A')>=0) {
      push @temp, "(exists (select a.refno from $CGAP_SCHEMA.molbiolclinassoc a where a.molclin='C' and a.refno=r.refno))";
    } 
    Add("(" . (join(" or ", @temp)) . ")"); 
  } else {
     Add ("((exists (select c.refno from $CGAP_SCHEMA.cytogeninv c where c.refno=r.refno)) or " .
      "(exists (select m.refno from $CGAP_SCHEMA.molbiolclinassoc m where m.molclin='M' and m.refno=r.refno)) or " .
      "(exists (select a.refno from $CGAP_SCHEMA.molbiolclinassoc a where a.molclin='A' and a.refno=r.refno)))");
  }

  if ($author and ($year or $journal)) {
    Add("r.RefNo = ar.RefNo");
  } else {
    if ($author) {
      Add("r.RefNo = ar.RefNo");
    }
  }

  if ($year) {
    Add(DoRange("r.year", $year, 1));
  }
  
  if ($refno) {
    Add(DoRange("r.RefNo", $refno, 1));
  }
  
  if ($author) {
    my @authors = FixAuthorInput($author);
    Add(
        "( " .
        DoAndOrPile("AuthorReference", "ar", "Name", "d", @authors) .
        " )"
    );
  }

  if ($journal) {
    $journal =~ tr/A-Z/a-z/;
    $journal =~ tr/*/%/;
    my @journals = split(",", $journal);
    Add(
        "( " .
        DoAndOrPile("Reference", "r", "Journal", "d", @journals) .
        " )"
    );
  }
  
  $query = "$query order by r.Abbreviation, r.Refno";
  return $query;

}

#####################################################################
sub RefSearch_1 {
  my (
    $page,
    $author,
    $journal,
    $op,
    $refno,
    $year
  ) = @_;

  my $check_flag = 0;
  my $author_input = $author;
  if( $author =~ /\_\d+\_/ ) {
    $check_flag = 1;
    $author =~ s/\_\d+\_/\_/g; 
  }
  
  my $sql = BuildRefQuery($page,$author,$journal,$op,$refno,$year, $check_flag);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }

  ## print "8888: $sql <br>";
  my (@row, @rows);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (my @tmp_row = $stm->fetchrow_array()) {
        if( $check_flag == 1 ) {
          if ( FixSearchChar($tmp_row[3]) =~ /$author_input/ ) {
            my @row;
            for( my $i=0; $i<3; $i++ ) {
              push @row, $tmp_row[$i];
            }
            push @rows, [ @row ];
          }
        }
        else {
          push @rows, [ @tmp_row ];
        }
      }
      ## if (@rows == 0) {
      ##   SetStatus(S_NO_DATA);
      ## } 
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "Reference not found";
    }
  }
  $db->disconnect();

  my $cmd = 
    ($author ? "author=$author&" : "") .    
    ($journal ? "journal=$journal&" : "") .
    ($year ? "year=$year&" : "") .
    ($refno ? "refno=$refno&" : "");

  my $cmd1 = "RefList?" . $cmd;

  $cmd =~ s/ /+/g;
  $cmd =~ s/\(/%28/g;
  $cmd =~ s/\)/%29/g;
  $cmd =~ s/;/%3B/g;
  $cmd =~ s/, /%2C/g;
  $cmd =~ s/\?/%3F/g;
  $cmd =~ s/,/%2C/g;
  $cmd =~ s/\"/%22/g;

  $cmd = "RefList?" . $cmd;

  if (@rows) {
    return (join "", @{ RefList(\@rows, $page, $cmd, $cmd1) });
  } else {
    return "No data matching the query<br><br>\n";
  }
}

#####################################################################
sub RefList {
  my ($aref, $p, $href, $href1) = @_;

  my ($i, @temp, $start, $stop, $num_pages,$cas,$ref,$inv,$Kary,$tempkary);

  if ($p==0) {
    push @temp,
        "Author, Year\t" .
        "Journal\t" .
        "Reference Number\n";
    for (my $i = 0; $i < @{ $aref }; $i++)  {     
      $$aref[$i][0] = FixTextChar($$aref[$i][0]);
      push @temp, (join "\t", @{$$aref[$i]}) . "\n";
    }
  } else {

    ($num_pages,$start,$stop) =
        PagingHeader('Ref',scalar(@{$aref}),$href,$href1,\@temp,$p);

    my $ref = 1;
    for (my $i = 1; $i < @{ $aref }; $i++)  {
      $ref++;
    }
    push @temp, "<tr><td colspan=3>".
      "<b>Displaying References $start to $stop of $ref found".
      "</td>\n".
      "</tr></table><br>" .
      "<hr noshade color=\"#003366\" width=500 align=left><br>\n".
      "<table width=500 border=0>\n";  
    unshift @{ $aref }, ['-','-','-','-','-','-','-'];

    for (my $i = $start; $i <= $stop; $i++)  {
        ##
        ## Reference.Abbreviation
        ## Reference.Journal
        ## Cytogen.RefNo
        ##
        $$aref[$i][0] = FixSpecChar($$aref[$i][0]);

      push @temp, BuildRefLine($$aref[$i][0],$$aref[$i][1],$$aref[$i][2],'2');
    }
    push @temp, "</table>\n";

    if ($num_pages > 1) {
      push @temp, "<br>\n" . "<table width=500><tr><td align=center>\n";
      if ($p != 1) { 
        push @temp, "<a href=\"$href" . "page=" . ($p-1) . "\">".
          "<img src=\"". IMG_DIR ."/PrevPage.gif\" border=0 alt=\"PrevPage\"></a>\n";
      }
      if ($p != $num_pages) {           
        push @temp, "<a href=\"$href" . "page=" . ($p+1) . "\">".
          "<img src=\"". IMG_DIR ."/NextPage.gif\" border=0 alt=\"NextPage\"></a>\n";
      }   
      push @temp, "</td></tr></table>";
    }

  }
  for(my $i=0; $i<@temp; $i++) {
    $temp[$i] = convert_special_chr_to_html_code($temp[$i]);
  }

  return \@temp;
}
  


#####################################################################
sub HelpLists_1 {
  my ($field, $table) = @_;
  my $temp;

  my $sql = "select distinct $field from $CGAP_SCHEMA.$table order by $field ";

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }

  my (@row, @rows);
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  } else {
    if ($stm->execute()) {
      while (@row = $stm->fetchrow_array()) {
        push @rows, FixSpecChar($row[0]);
      }
      ## if (@rows == 0) {
      ##   SetStatus(S_NO_DATA);
      ## }
    } else {
      print "execute failed\n";
      $db->disconnect();
      return "$sql<br>case not found";
    }
  }
  $db->disconnect();
  return (join "<br>\n", @rows);

}

######################################################################
sub GetBacByChromosome_1
{
  my ($bac_chromosome) = @_;
   
     &debug_print( "bac_chromosome: $bac_chromosome \n");

  my @items;

  my $i;

  my ($map_coordinate, $sts_id_value, $bac_end, $insert_sequence, $bac_id, $nt_contig);

  my $graph;

  my @output;

     ## Look for bac given chromosome

  my $cids = &GetAllFromCCAP_BAC($bac_chromosome);

  &debug_print( "after process bac_chromosome: $bac_chromosome \n");

  ## if(GetStatus() == S_OK) {
  @items = split "\t", $cids;
  ## }
    
  $graph = "chr/chr" . $bac_chromosome . ".gif";

  push @output,"<p>
    <b>Chromosome $bac_chromosome</b><br>
    <hr width=\"100%\" noshade>
    <TABLE  BORDER=\"0\" CELLSPACING=\"1\" CELLPADDING=\"4\">
    <tr>
    <td valign=\"top\">
    <img src=\"" . IMG_DIR . "/$graph\" alt=\"Chromosome $bac_chromosome\" >
    </td>
    <td>
    <TABLE WIDTH=\"700\" BORDER=\"1\" CELLSPACING=\"1\" CELLPADDING=\"4\">
      <TR BGCOLOR=\"#38639d\">  
        <TD WIDTH=\"140\"><font color=\"white\">
          <B>Map Coordinate</B></font>
        </TD>
        <TD WIDTH=\"100\"><font color=\"white\">
          <B>BAC id</B></font>
        </TD>
        <TD WIDTH=\"90\"><font color=\"white\">
          <B>Placement on genome</font><a href=\"BAC_Clone_Map?CHR=$bac_chromosome\#LEGEND\"><font color=\"white\"><sup>1</sup></font></a></B>
        </TD>
        <TD WIDTH=\"80\"><font color=\"white\">
          <B>Placement summary</font><a href=\"BAC_Clone_Map?CHR=$bac_chromosome\#LEGEND\"><font color=\"white\"><sup>3</sup></font></a></B>
        </TD>
        <TD WIDTH=\"110\"><font color=\"white\">
          <B>BAC End</font><a href=\"BAC_Clone_Map?CHR=$bac_chromosome\#LEGEND\"><font color=\"white\"><sup>2</sup></font></a></B>
        </TD>
        <TD WIDTH=\"90\"><font color=\"white\">
          <B>Insert Sequence</font><a href=\"BAC_Clone_Map?CHR=$bac_chromosome\#LEGEND\"><font color=\"white\"><sup>2</sup></font></a></B>
        </TD>
        <TD WIDTH=\"90\"><font color=\"white\">
          <B>STS id</font><a href=\"BAC_Clone_Map?CHR=$bac_chromosome\#LEGEND\"><font color=\"white\"><sup>2</sup></sup></font></B>
        </TD>
      </TR>";

  for( $i=0; $i<=$#items; $i++ ) {
    my ($map_coordinate, $bac_id, $position, $graph, $end_sequence, 
              $insert_sequence, $sts_id_value) = split ("\032", $items[$i]);
    push @output,
      "<tr>" .
      $map_coordinate .
      $bac_id .
      $position .
      $graph .
      $end_sequence .
      $insert_sequence .
      $sts_id_value .
      "</tr>" .

      &debug_print("$items[$i]");
  }

  push @output, "</table>";
  push @output, "<A NAME=LEGEND></A><p><sup>1</sup> FISH-mapped clone was placed on the sequenced "; 
  push @output, "genome based on BAC-ends, insert sequences and STSs.<br>"; 
  push @output, "<p><sup>2</sup> Sequences that are associated with the clone "; 
  push @output, "and used for clone placement. <br>&nbsp;&nbsp ";
  push @output, "<sup>*</sup> indicates "; 
  push @output, "sequences that disagree with data in 'Placement on genome' column.<br>&nbsp;&nbsp "; 
  push @output, "<sup>+</sup> indicates sequences that didn't align to the "; 
  push @output, "genome or were not used for annotation.";
  push @output, "<p><sup><b>3</b></sup>	Placement summary indicates sequences ";
  push @output, "used for clone placement.<br>&nbsp;&nbsp; " .
                "<IMG src=\"" . IMG_DIR . "/L_3.gif\" alt=\"BAC-end sequence aligned in the plus orientation\"> " .
                " BAC-end sequence aligned in the plus orientation " .
                " <br>&nbsp;&nbsp; " .
                "<IMG src=\"" . IMG_DIR . "/L_2.gif\" alt=\"BAC-end sequence aligned in the minus orientation\"> " .
                " BAC-end sequence aligned in the minus orientation " .
                " <br>&nbsp;&nbsp; " .
                "<IMG src=\"" . IMG_DIR . "/M_0.gif\" alt=\"no insert sequence and no STS aligned\"> " .
                " no insert sequence and no STS aligned<br>&nbsp;&nbsp; " .
                "<IMG src=\"" . IMG_DIR . "/M_1.gif\" alt=\"STS aligned\"> " .
                " STS aligned<br>&nbsp;&nbsp; " .
                "<IMG src=\"" . IMG_DIR . "/M_2.gif\" alt=\"insert sequence\"> " .
                " insert sequence<br>&nbsp;&nbsp; " .
                "<IMG src=\"" . IMG_DIR . "/M_3.gif\" alt=\"insert sequence and STS aligned\"> " .
                " insert sequence and STS aligned<br>&nbsp;&nbsp; " .
                "<IMG src=\"" . IMG_DIR . "/LL_1.gif\" alt=\"insert sequence has clone end information\"> " .
                "insert sequence has clone end information.<br> ";
  push @output, "</td></tr>";
  push @output, "</table>";
  return join "\n", @output;
}


######################################################################
sub GetAllFromCCAP_BAC
{

  my ($bac_chromosome_value) = @_;

  my $Url_1 = "http://www.ncbi.nlm.nih.gov/CCAP";
  my $Url_2 = "http://www.ncbi.nlm.nih.gov/genome/sts";
  my $Url_3 = "http://www.ncbi.nlm.nih.gov/genome/clone";
  my $Url_5 = "http://www.ncbi.nlm.nih.gov/entrez";
  ## my $Url_6 = "http://www.ncbi.nlm.nih.gov/cgi-bin/Entrez";
  my $Url_6 = "http://www.ncbi.nlm.nih.gov/mapview";

  my ($CHROMOSOME, $FISH_DATA, $CLONE_NAME, $STS_NAME, $STS_FLAG, 
      $INSERT_SEQUENCE, $INSERT_FLAG, $END_SEQUENCE, $END_FLAG,
      $POSITION, $BOUNDARY_CATEGORY);
  my ($band, $arm);

  my ($map_coordinate, $sts_id_value, $bac_id, $insert_sequence, 
      $end_sequence, $position);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }
 
  ##
  ## By CHROMOSOME:
  ##

  my $sql = "select CHROMOSOME, FISH_DATA, CLONE_NAME, 
               STS_NAME, INSERT_SEQUENCE, 
               END_SEQUENCE, POSITION, BOUNDARY_CATEGORY
               from $CGAP_SCHEMA.CCAP_BAC 
                 where CHROMOSOME = '$bac_chromosome_value'
                   order by BEGIN_POSITION, END_POSITION";

  my $stm = $db->prepare($sql);

  if (not $stm) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }

  my $cid;
  my @cids;

  if (not $stm->execute()) {
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  $stm->bind_columns(\$CHROMOSOME, \$FISH_DATA, 
                     \$CLONE_NAME, \$STS_NAME,
                     \$INSERT_SEQUENCE,
                     \$END_SEQUENCE, \$POSITION, \$BOUNDARY_CATEGORY);

  while( $stm->fetch)
  {

    my $temp_return = &get_chromosome($FISH_DATA);

    $map_coordinate = "<TR VALIGN=TOP><TD WIDTH=\"120\" BGCOLOR=\"#FFFFFF\">
       <A HREF=\"Mitel_Search?structural=on&numerical=&breakpoint=$temp_return&neopl=&tissue=&type=&page=1\#MARK\">
       $FISH_DATA</A></TD>";

    my @temp_sts = split( /;/, $STS_NAME );

    my (@temp_sts_id, @temp_external_clone_id, @flag);

    my ($i, $start); 

    my %temp_sts_one;
    my @temp_url;
    for( $i=0; $i<=$#temp_sts; $i++ ) {
 
      my ($temp_sts_id, $temp_external_clone_id, $flag) = 
            split( /\s+/, $temp_sts[$i] );
      push @{$temp_sts_one{$temp_sts_id}}, 
             join "\t", $temp_external_clone_id, $flag;
    }

    for my $sts_id (sort keys %temp_sts_one ) {
      for (my $i=0; $i<@{$temp_sts_one{$sts_id}}; $i++) { 
        my ($url_id, $flag) = split "\t", $temp_sts_one{$sts_id}[$i];
        push @temp_url, 
               getUrlWithColoredValueForSTS($url_id, $sts_id, $flag, $Url_2);
      }
    }

    my $length = @temp_url; 
    if( $length > 0 ) {
      my $temp_sts_id_value = join ",<br>", @temp_url;
      $sts_id_value =  "<TD NOWRAP valign=top WIDTH=\"90\" BGCOLOR=\"#FFFFFF\"> $temp_sts_id_value </TD></TR>";
    }
    else {
      $sts_id_value =  "<TD NOSRAP valign=top WIDTH=\"90\" BGCOLOR=\"#FFFFFF\">&nbsp;</TD>";
    }

    my $index;
    if( $INSERT_SEQUENCE eq "" ) {
      $insert_sequence = "<TD WIDTH=\"90\" BGCOLOR=\"#FFFFFF\">&nbsp;</TD>" ;
    }
    else {
      my @temp_ins_sqs = split( /;/, $INSERT_SEQUENCE );
      my @temp_url_5;
      for( $index=0; $index<@temp_ins_sqs; $index++ ) {  
        my ($value, $flag) = split /\s+/, $temp_ins_sqs[$index];
        $value =~ s/\.\d+//;
        push @temp_url_5, 
          getUrlWithColoredValueForINS_SQS($value, $flag, $Url_5);
      }
      my $temp_ins_sqs_join = join ",<br>", @temp_url_5;
      $insert_sequence =  "<TD NOWRAP valign=top WIDTH=\"90\" BGCOLOR=\"#FFFFFF\">$temp_ins_sqs_join</TD>";
    }

    if( $END_SEQUENCE eq "" ) {
      $end_sequence = "<TD WIDTH=\"90\" BGCOLOR=\"#FFFFFF\">&nbsp;</TD>" ;
    } 
    else {
      my @temp_end_sqs = split( /;/, $END_SEQUENCE );
      my @temp_end_url;
      my $temp_value;
      for( $index=0; $index<@temp_end_sqs; $index++ ) {
        $temp_value = $temp_end_sqs[$index];
        my @temp_values = split /\s+/, $temp_value;
        my $value = $temp_values[0];
        $value =~ s/\.\d+//;
        my $show_value;
        if ( $temp_values[1] eq "na" ) {
          $show_value = $value;
        }
        else { 
          $show_value = $value . " " . $temp_values[1];
        }
        push @temp_end_url,
          getUrlWithColoredValueForEND_SQS($value, $show_value, 
                                           $temp_values[2], $Url_5);
      }
      my $temp_end_sqs_join = join ",<br>", @temp_end_url;
      $end_sequence =  "<TD NOWRAP valign=top WIDTH=\"110\" BGCOLOR=\"#FFFFFF\"> $temp_end_sqs_join </TD>";
    }

    if( $CLONE_NAME eq "" ) {
      $bac_id = "<TD WIDTH=\"100\" BGCOLOR=\"#FFFFFF\">&nbsp;</TD>" ;
    }
    else {
      $bac_id = "<TD NOWRAP WIDTH=\"100\" BGCOLOR=\"#FFFFFF\">
         <A HREF=javascript:spawn(\"$Url_3/clname.cgi?stype=Name&list=$CLONE_NAME\")>
         $CLONE_NAME</A></TD>" ;
    }

    if( $POSITION eq "" ) {
      $position = "<TD WIDTH=\"90\" BGCOLOR=\"#FFFFFF\">&nbsp;</TD>";
    }
    else {

      my $position_url;
      my @tmp = split /\s+/, $POSITION;
      my $tmp_position = $tmp[1];
      $tmp_position =~ /(\d+)\w+/;
      my $BEG = $1 - 2;
      my $END = $1 + 2;
      $BEG = $BEG . "M";  
      $END = $END . "M";  
      $position_url = 
          "<A HREF=javascript:spawn(\"$Url_6/maps.cgi?taxid=9606&MAPS=cntg-r,comp,sts,loc,clone&CHR=$CHROMOSOME&query=$CLONE_NAME&BEG=$BEG&END=$END\")>
              $POSITION</A>";

      $position =  "<TD NOWRAP valign=top WIDTH=\"90\" BGCOLOR=\"#FFFFFF\">
                   $position_url </TD>";

    }

    my $graph;
    ## use image width and height like this:
    ## "<img src=\"<dtml-var IMG_DIR>/LL_0.gif\" width=3 height=25 >" . 
    ## "<img src=\"<dtml-var IMG_DIR>/L_0.gif\" width=14 height=25 >" . 
    ## "<img src="<dtml-var IMG_DIR>/M_1.gif\" width=16 height=25 >" . 
    ## "<img src="<dtml-var IMG_DIR>/R_0.gif" width=14 height=25 >" . 
    ## "<img src="<dtml-var IMG_DIR>/RR_0.gif" width=3 height=25 ></TD>";

    if( $BOUNDARY_CATEGORY ne "" ) {
      my @tmp = split ";", $BOUNDARY_CATEGORY;
      $graph = "<TD NOWRAP valign=top WIDTH=\"80\" BGCOLOR=\"#FFFFFF\">"; 
      for ( my $i=0; $i<@tmp; $i++ ) {
        if( $tmp[$i] =~ /^LL_/ or $tmp[$i] =~ /^RR_/ ) {
          $graph = $graph . 
              "<img src=\"" .  IMG_DIR . "/$tmp[$i]\" width=3 height=25 alt=\"insert sequence has clone end information\">";
        } 
        elsif( $tmp[$i] =~ /^L_/ ) {
          $graph = $graph . 
              "<img src=\"" .  IMG_DIR . "/$tmp[$i]\" width=14 height=25 alt=\"BAC-end sequence aligned in the plus orientation\">";
        }
        elsif( $tmp[$i] =~ /^R_/ ) {
          $graph = $graph . 
              "<img src=\"" .  IMG_DIR . "/$tmp[$i]\" width=14 height=25 alt=\"BAC-end sequence aligned in the minus orientation\">";
        }
        elsif( $tmp[$i] =~ /^M_1/ ) {
          $graph = $graph . 
              "<img src=\"" .  IMG_DIR . "/$tmp[$i]\" width=16 height=25 alt=\"STS aligned\">";
        }
        elsif( $tmp[$i] =~ /^M_2/ ) {
          $graph = $graph . 
              "<img src=\"" .  IMG_DIR . "/$tmp[$i]\" width=16 height=25 alt=\"insert sequence\">";
        }
        elsif( $tmp[$i] =~ /^M_0/ ) {
          $graph = $graph . 
              "<img src=\"" .  IMG_DIR . "/$tmp[$i]\" width=16 height=25 alt=\"no insert sequence and no STS aligned\">";
        }
        elsif( $tmp[$i] =~ /^M_3/ ) {
          $graph = $graph . 
              "<img src=\"" .  IMG_DIR . "/$tmp[$i]\" width=16 height=25 alt=\"insert sequence and STS aligned\">";
        }
      }
      $graph = $graph . "</TD>"; 
    }
    else {
      $graph =  
         "<TD NOSRAP valign=top WIDTH=\"90\" BGCOLOR=\"#FFFFFF\">&nbsp;</TD>";
    }


    $cid = join "\032", $map_coordinate, $bac_id, $position, $graph,
                        $end_sequence, $insert_sequence, $sts_id_value;

    push @cids, $cid;
  }

  $db->disconnect();

  if (@cids < 1) {
    ## SetStatus(S_NO_DATA);
    return "";
  }
  else {
    return join "\t", @cids;
  }

}

######################################################################
sub SearchAbnorm_1
{
  my ($base, $breakpoint_in, $type_in, $tissue_in,
      $neopl_in, $gene_in, $structural_in, $numerical_in, 
      $chromosome_in, $num_type_in, $page) = @_;

  $chromosome_in =~ s/x/X/;
  $chromosome_in =~ s/y/Y/;
  &debug_print( "breakpoint_in: $breakpoint_in, 
        type_in: $type_in, tissue: $tissue_in, neopl_in: $neopl_in, 
        gene_in: $gene_in,
        structural_in: $structural_in,
        numerical_in: $numerical_in,
        chromosome_in: $chromosome_in,
        num_type_in: $num_type_in
          \n");

  my ($chr_in, $arm_in, $band_in);

  my $temp_breakpoint = $breakpoint_in;
  ##$temp_breakpoint =~ s/^[ \t]+//;
  ##$temp_breakpoint =~ s/[ \t]+$//;
  ##$temp_breakpoint =~ s/[\r\n]+//;
   
  $BASE = $base;

  $type_in = substr $type_in, 0, 10;
 

  my $BALANCE_AMOUNT = 0;
  my $UNBALANCE_AMOUNT = 0;

  if( $structural_in ne "on" && $numerical_in ne "on" ) {
      return "<strong>
            Please check at least one box for Structural aberrations 
            or Numerical aberrations 
            </strong>";
  } 
  elsif ( ( ($structural_in eq "on") &&
            ($temp_breakpoint eq "") && 
            ($neopl_in eq "All morphologies"   || $neopl_in eq "") &&
            ($tissue_in  eq "All topographies" || $tissue_in eq "") &&
            ($gene_in eq "All genes"           || $gene_in eq "") ) ||
          ( ($numerical_in eq "on") &&
            ($chromosome_in eq "") &&
            ($neopl_in eq "All morphologies"   || $neopl_in eq "") &&
            ($tissue_in  eq "All topographies" || $tissue_in eq "") ) ) {

    return "<strong>
            If you checked Structural aberrations, 
            Please enter a breakpoint or select at least one of
            the following: topography, morphology, or gene <br>
            If you checked Numerical aberrations, 
            Please enter a chromosome or select at least one of
            the following: topography, morphology
            </strong>";

  }
  elsif( $structural_in eq "on" && 
         $type_in eq "Unbalanced" &&
         $gene_in ne "All genes" ) {
    return "<strong>
              There are no unbalanced abnormalities associated with a gene
            </strong>";
  }
  elsif( $structural_in ne "on" && $numerical_in eq "on" &&
         $gene_in ne "All genes" ) {
    return "<strong>
              There are no  numerical aberrations associated with a gene
            </strong>";
  }

  if( $temp_breakpoint =~ /^[a-wzA-WZ]/ ) {
    return "<strong>
              \"$temp_breakpoint\" is not a legal breakpoint
            </strong>";
  }


  ($chr_in, $arm_in, $band_in) = split "\002", 
                                 split_breakpoint($temp_breakpoint);

  my (@items_total, @items_1, @items_2, @num_items_1, @num_items_2);

  my ($BandBal, $AbnormalityBal, $NeoplasmBal,
      $SiteBal, $TotalCasesBal, $GenesBal);

  my ($BandUnBal, $AbnormalityUnBal, $NeoplasmUnBal,
      $SiteUnBal, $TotalCasesUnBal, $GenesUnBal);


  my @output;

  my $i;
 
  if( $type_in eq "" ) {
    $type_in = "Both";
  }

  if( $num_type_in eq "" ) {
    $type_in = "Both";
  }


  my $cids = &GetInfoFrRecurrentDataTable($chr_in, $arm_in, $band_in, $neopl_in,
                                      $tissue_in, $type_in, $gene_in, 
                                      $structural_in, $numerical_in,
                                      $chromosome_in, $num_type_in, $page);

  &debug_print( "$cids \n");

  if( $cids eq "" ) {
    push @output,
         "<strong>
          There are no abnormalities matching the query
         </strong>";
    return join "\n", @output;
  }
  else {

    @items_total = split "!", $cids;
    if( $items_total[0] ne "" ) {
       @items_1 = split "\t", $items_total[0];
    }
    if( $items_total[1] ne "" ) {
       @items_2 = split "\t", $items_total[1];
    }
    if( $items_total[2] ne "" ) {
       @num_items_1 = split "\t", $items_total[2];
    }
    if( $items_total[3] ne "" ) {
       @num_items_2 = split "\t", $items_total[3];
    }
  }

  my $cmd =
     "breakpoint=$breakpoint_in&" .
     "tissue=$tissue_in&" .
     "neopl=$neopl_in&" .
     "type=$type_in&" .
     "gene=$gene_in&" .
     "structural=$structural_in&" .
     "numerical=$numerical_in&" .
     "chromosome=$chromosome_in&" .
     "num_type=$num_type_in&";

  $cmd =~ s/\(/%28/g;
  $cmd =~ s/\)/%29/g;
  $cmd =~ s/;/%3B/g;
  $cmd =~ s/, */%2C/g;
  $cmd =~ s/\?/%3F/g;
  $cmd =~ s/\"/%22/g;
  $cmd =~ s/\+/%2B/g;
  $cmd =~ s/ /+/g;
 
  $cmd = "Mitel_Search?" . $cmd;

  ## my $href = $base . $cmd;
  my $href = $cmd;

  if( $page == 0 ) {
    push @output, "Band" . "\t" . "Abnormality" . "\t" . "Morphology" . "\t" .
                  "Topography" . "\t" . "Cases" . "\t" . "Genes" . "\t";
  }
  else {
    push @output, "<br>";
    push @output, "<a href=\"$href" . "page=0\"><b>[Full Text]</b></a>\n  ";
    push @output, "<br>";
  }

  if( @items_1 > 0 ) {

    if( $page == 0 ) {
      for( $i=0; $i<=$#items_1; $i++ ) {
        ($BandBal, $AbnormalityBal, $NeoplasmBal,
         $SiteBal, $TotalCasesBal, $GenesBal) = split ("\032", $items_1[$i]);
        push @output,
          $BandBal . "\t" .
          $AbnormalityBal . "\t" .
          $NeoplasmBal . "\t" .
          $SiteBal . "\t" .
          $TotalCasesBal . "\t" .
          $GenesBal; 
      }
    }
    else {
      push @output, "<br>";
      push @output, $bal_header;
      push @output, "<br>";

      for( $i=0; $i<=$#items_1; $i++ ) {
        ($BandBal, $AbnormalityBal, $NeoplasmBal,
         $SiteBal, $TotalCasesBal, $GenesBal) = split ("\032", $items_1[$i]);

        if( $i > 0 && $i % $ROWS_PER_SUBTABLE == 0 && $i<$#items_1 ) {
          push @output, "</table><br>$temp_header";
        }

        push @output,
          "<tr>" .
          $BandBal .
          $AbnormalityBal .
          $NeoplasmBal .
          $SiteBal .
          $TotalCasesBal .
          $GenesBal .
          "</tr>";

        ## &debug_print("$items_1[$i]");

      }

      push @output, "</TABLE>";
    }
  }

  if( @items_2 > 0  ) {

    if( $page == 0 ) {
      for( $i=0; $i<=$#items_2; $i++ ) {
        ($BandUnBal, $AbnormalityUnBal, $NeoplasmUnBal,
         $SiteUnBal, $TotalCasesUnBal, $GenesUnBal) = split ("\032", $items_2[$i]);
        push @output,
          $BandUnBal . "\t" .
          $AbnormalityUnBal . "\t" .
          $NeoplasmUnBal . "\t" .
          $SiteUnBal . "\t" .
          $TotalCasesUnBal . "\t" .
          $GenesUnBal; 
      }
    }
    else {
      push @output, "<br>";
      push @output, $unbal_header;
      push @output, "<br>";
  
      for( $i=0; $i<=$#items_2; $i++ ) {
        ($BandUnBal, $AbnormalityUnBal, $NeoplasmUnBal,
         $SiteUnBal, $TotalCasesUnBal, $GenesUnBal) = split ("\032", $items_2[$i]);
  
        if( $i > 0 && $i % $ROWS_PER_SUBTABLE == 0 && $i<$#items_2 ) {
          push @output, "</table><br>$temp_header";
        }
  
        push @output,
          "<tr>" .
          $BandUnBal .
          $AbnormalityUnBal .
          $NeoplasmUnBal .
          $SiteUnBal .
          $TotalCasesUnBal .
          $GenesUnBal .
          "</tr>";
  
        ## &debug_print("$items_2[$i]");
  
      }
  
      push @output, "</TABLE>";
    }

  }


  if( @num_items_1 > 0 ) {
 
    if( $page == 0 ) {
      for( $i=0; $i<=$#num_items_1; $i++ ) {
        ($BandBal, $AbnormalityBal, $NeoplasmBal,
         $SiteBal, $TotalCasesBal, $GenesBal) = split ("\032", $num_items_1[$i]);
        push @output,
          $BandBal . "\t" .
          $AbnormalityBal . "\t" .
          $NeoplasmBal . "\t" .
          $SiteBal . "\t" .
          $TotalCasesBal . "\t" .
          $GenesBal; 
      }
    }
    else {
      push @output, "<br>";
      push @output, $trisomy_header;
      push @output, "<br>";
   
      for( $i=0; $i<=$#num_items_1; $i++ ) {
        ($BandBal, $AbnormalityBal, $NeoplasmBal,
         $SiteBal, $TotalCasesBal, $GenesBal) = split ("\032", $num_items_1[$i]);
   
        if( $i > 0 && $i % $ROWS_PER_SUBTABLE == 0 && $i<$#num_items_1 ) {
          push @output, "</table><br>$num_temp_header";
        }
   
        push @output,
          "<tr>" .
          $AbnormalityBal .
          $NeoplasmBal .
          $SiteBal .
          $TotalCasesBal .
          $GenesBal .
          "</tr>";
   
        ## &debug_print("$num_items_1[$i]");
   
      }
   
      push @output, "</TABLE>";
    }
  }
    
  if( @num_items_2 > 0  ) {
 
    if( $page == 0 ) {
      for( $i=0; $i<=$#num_items_2; $i++ ) {
        ($BandUnBal, $AbnormalityUnBal, $NeoplasmUnBal,
          $SiteUnBal, $TotalCasesUnBal, $GenesUnBal) = split ("\032", $num_items_2[$i]);
        push @output,
          $BandUnBal . "\t" .
          $AbnormalityUnBal . "\t" .
          $NeoplasmUnBal . "\t" .
          $SiteUnBal . "\t" .
          $TotalCasesUnBal . "\t" .
          $GenesUnBal; 
      }
    }
    else {
      push @output, "<br>";
      push @output, $monosomy_header;
      push @output, "<br>";
   
      for( $i=0; $i<=$#num_items_2; $i++ ) {
        ($BandUnBal, $AbnormalityUnBal, $NeoplasmUnBal,
          $SiteUnBal, $TotalCasesUnBal, $GenesUnBal) = split ("\032", $num_items_2[$i]);
   
        if( $i > 0 && $i % $ROWS_PER_SUBTABLE == 0 && $i<$#num_items_2 ) {
          push @output, "</table><br>$num_temp_header";
        }
   
        push @output,
          "<tr>" .
          $AbnormalityUnBal .
          $NeoplasmUnBal .
          $SiteUnBal .
          $TotalCasesUnBal .
          $GenesUnBal .
          "</tr>";
   
        ## &debug_print("$num_items_2[$i]");
   
      }
   
      push @output, "</TABLE>";
    }
 
  }

  if( @items_1 == 0 and 
      @items_2 == 0 and 
      @num_items_1 == 0 and 
      @num_items_2 == 0 ) {
    return "<B>No data matching the query</B>";
  }

  return (join "\n", @output) . "\n";

}


######################################################################
sub GetInfoFrRecurrentDataTable
{
  my ($chr_key, $arm_key, $band_key, $neopl_key, $tissue_key, 
      $type_key, $gene_key, $structural_key, $numerical_key,
      $chromosome_key, $num_type_key, $page) = @_;

  &debug_print( "$chr_key, $arm_key, $band_key, $neopl_key, $tissue_key, 
      $type_key, $gene_key \n" );

  my $sql;

  my $type_default = 0;

  my ($CHROMOSOME, $ARM, $BAND,
      $ABERRATION, $DISEASE, $ORGAN,
      $TOTAL_CASES, $GENE, $CODE, $TYPE);
  my $ABNORMALITY;

  my $temp;
  my $fixed_disease;

  my ( @bal_results, @unbal_results );
  my ( @plus_results, @minus_results );

  my $joined_1;
  my $joined_2;
  my $num_joined_1;
  my $num_joined_2;


  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }


  if( $structural_key eq "on" ) { 
    $sql = &prepare_sql($chr_key, $arm_key, $band_key, $neopl_key, 
                                  $tissue_key, $gene_key, $type_key);

    &debug_print( "sql: $sql \n" );

    my $stm = $db->prepare($sql);

    if (not $stm) {
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }

    if (not $stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      return undef;
    }

    $stm->bind_columns(\$CHROMOSOME, \$ARM, \$BAND,
       \$ABERRATION, \$DISEASE, \$ORGAN,
       \$TOTAL_CASES, \$GENE, \$CODE, \$TYPE);

    while( $stm->fetch)
    {
      if( $page == 0 ) {
        $fixed_disease = FixTextChar($DISEASE);
        if( $TYPE eq "B" ) {
          push @bal_results, &convrtToLine( "S", $CHROMOSOME, $ARM, $BAND,
            $ABERRATION, $fixed_disease, $ORGAN,
            $TOTAL_CASES, $GENE, , $CODE, $db);
        }
        elsif ( $TYPE eq "U" ) {
          push @unbal_results, &convrtToLine( "S", $CHROMOSOME, $ARM, $BAND,
            $ABERRATION, $fixed_disease, $ORGAN,
            $TOTAL_CASES, $GENE, , $CODE, $db);
        } 
      }
      else {
        $fixed_disease = FixSpecChar($DISEASE);
        if( $TYPE eq "B" ) {
          push @bal_results, &convrtToHREF( "S", $CHROMOSOME, $ARM, $BAND,
            $ABERRATION, $fixed_disease, $ORGAN,
            $TOTAL_CASES, $GENE, , $CODE, $db);
        }
        elsif ( $TYPE eq "U" ) {
          push @unbal_results, &convrtToHREF( "S", $CHROMOSOME, $ARM, $BAND,
            $ABERRATION, $fixed_disease, $ORGAN,
            $TOTAL_CASES, $GENE, , $CODE, $db);
        } 
      }

    }
  } 

  if( $numerical_key eq "on" ) {
    $sql = &prepare_num_sql($chromosome_key, $neopl_key,
                                $tissue_key, $num_type_key);
 
    &debug_print( "sql: $sql \n" );
 
    my $stm = $db->prepare($sql);
 
    if (not $stm) {
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
 
    $stm->bind_columns(\$CHROMOSOME, \$ABNORMALITY, \$DISEASE, \$ORGAN,
                       \$TOTAL_CASES, \$CODE);
 
    while( $stm->fetch)
    {
      $ARM = "";
      $BAND = "";
      $GENE = ""; 
      if( $page == 0 ) {
        $fixed_disease = FixTextChar($DISEASE);
        if( $ABNORMALITY =~ /^\+/ ) {
          push @plus_results, &convrtToLine( "N", $CHROMOSOME, $ARM, $BAND,
                                           $ABNORMALITY, $fixed_disease, $ORGAN,
                                           $TOTAL_CASES, $GENE, $CODE, $db );
        }
        elsif ( $ABNORMALITY =~ /^\-/ ) {
          push @minus_results, &convrtToLine( "N", $CHROMOSOME, $ARM, $BAND,
                                           $ABNORMALITY, $fixed_disease, $ORGAN,
                                           $TOTAL_CASES, $GENE, $CODE, $db );
        }
      }
      else { 
        $fixed_disease = FixSpecChar($DISEASE);
        if( $ABNORMALITY =~ /^\+/ ) {
          push @plus_results, &convrtToHREF( "N", $CHROMOSOME, $ARM, $BAND,
                                           $ABNORMALITY, $fixed_disease, $ORGAN,
                                           $TOTAL_CASES, $GENE, $CODE, $db );
        }
        elsif ( $ABNORMALITY =~ /^\-/ ) {
          push @minus_results, &convrtToHREF( "N", $CHROMOSOME, $ARM, $BAND,
                                           $ABNORMALITY, $fixed_disease, $ORGAN,
                                           $TOTAL_CASES, $GENE, $CODE, $db );
        }
      }
 
    }

  }


  if (@bal_results < 1)
  {
      $joined_1 = "";
  }
  else {
      $joined_1 = join "\t", @bal_results;
  }

  if (@unbal_results < 1)
  {
      $joined_2 = "";
  }
  else {
      $joined_2 = join "\t", @unbal_results;
  }

  if (@plus_results < 1)
  {
      $num_joined_1 = "";
      debug_print( "NO PLUS!!!!!!!!!!!!!\n" );
  }      
  else {
      $num_joined_1 = join "\t", @plus_results;
      debug_print( "PLUS!!!!!!!!!!!!!\n" );
  }      
 
  if (@minus_results < 1)
  {
      $num_joined_2 = "";
      debug_print( "NO MINUS!!!!!!!!!!!!!\n" );
  }      
  else {
      $num_joined_2 = join "\t", @minus_results;
      debug_print( "MINUS!!!!!!!!!!!!!\n" );
  }      


  return join "!", $joined_1, $joined_2, $num_joined_1, $num_joined_2;
}

######################################################################
sub convrtToHREF {


  my ($TYPE, $CHROMOSOME, $ARM, $BAND, $ABERRATION, $DISEASE, $ORGAN, 
      $TOTAL_CASES, $GENE, $CODE, $db) = @_;

  my ($Band, $Abnormality, $Neoplasm,
      $Site, $TotalCases, $Genes);


  my $Url_1 = "http://www.ncbi.nlm.nih.gov/Omim";
  my $Url_2 = "$BASE/Genes";

  my @result;

  my $temp;

  $temp = "";
  if( $TYPE eq "S" ) {
    $temp = $CHROMOSOME . $ARM . $BAND;
    $Band = "<TD WIDTH=\"30\" VALIGN=\"top\" BGCOLOR=\"#ffffff\">
          <A HREF=javascript:spawn(\"$Url_1/getmap.cgi?chromosome=$temp\")>$temp</A>
            </TD>";
  }
  elsif ( $TYPE eq "N" ) {
    $Band = "<TD> $CHROMOSOME </TD>";
  }
  push @result, $Band;

  $Abnormality = "<TD WIDTH=\"100\" VALIGN=\"top\" BGCOLOR=\"#ffffff\">$ABERRATION</TD>";
  push @result, $Abnormality;

  $Neoplasm = "<TD WIDTH=\"105\" VALIGN=\"top\" BGCOLOR=\"#ffffff\">
                 <A HREF=\"Mitel_Search?structural=on&numerical=on&breakpoint=&neopl=$CODE&tissue=&type=&page=1#MARK\">$DISEASE</A>
                </TD>";
  push @result, $Neoplasm;

  if( $ORGAN eq "" ) {
    $Site = "<TD WIDTH=\"100\" VALIGN=\"top\" BGCOLOR=\"#ffffff\">
                 &nbsp;
             </TD>";
  }
  else { 
 
    my $full_name = &mapToFullName($ORGAN, "TOP", $db);

    $Site = "<TD WIDTH=\"100\" VALIGN=\"top\" BGCOLOR=\"#ffffff\">
                 <A HREF=\"Mitel_Search?structural=on&numerical=on&breakpoint=&neopl=&tissue=$ORGAN&type=&page=1#MARK\">$full_name</A>
             </TD>";
  }

  push @result, $Site;

  my $operation;
  if( $TYPE eq "S" ) {
    $operation = "a";
  }
  elsif( $TYPE eq "N" ) {
    $operation = "n";
  }
  
  my $cmd =
      "page=1&" .
      "abnorm_op=$operation&" .
      ($ABERRATION ? "abnormality=$ABERRATION&" : "") .
      "soleabnorm=0&" .
      "age=&" .
      "author=&" .
      "break_op=a&" .
      "breakpoint=&" .
      "caseno=&" .
      "country=&" .
      "herdis=&" .
      "immuno=&" .
      "invno=&" .
      "journal=&" .
      ($CODE ? "morph=$CODE&" : "") .
      "nochrom=&" .
      "noclones=&" .
      "prevmorph=&" .
      "prevneo=&" .
      "prevtop=&" .
      "race=&" .
      "refno=&" .
      "series=&" .
      "sex=&" .
      "specherdis=&" .
      "specmorph=&" .
      "tissue=&" .
      ($ORGAN ? "top=$ORGAN&" : "") .
      "treat=&" .
      "year=&" .
      "totalcases=Y";

  $cmd =~ s/\(/%28/g;
  $cmd =~ s/\)/%29/g;
  $cmd =~ s/;/%3B/g;
  $cmd =~ s/, */%2C/g;
  $cmd =~ s/\?/%3F/g;
  $cmd =~ s/\"/%22/g;
  $cmd =~ s/\+/%2B/g;
  $cmd =~ s/ /+/g;

  $cmd = "CytList?" . $cmd;


  my $tempTotal = "<TD WIDTH=\"100\" VALIGN=\"top\" BGCOLOR=\"#ffffff\">
                        <A HREF=\"$cmd\">$TOTAL_CASES&nbsp;</A>
                     </TD>";


  push @result, $tempTotal;

  $Genes = "<TD WIDTH=\"40\" VALIGN=\"top\" BGCOLOR=\"#ffffff\">";
  if( $GENE eq "" ) {
    $Genes .= "&nbsp;";
  } else {
    my (@sgene, @xgene, $sgene, $xgene, $ssep, $xsep, $s, $x);
    my (@tempArray, $t);
    my ($sql, $stm, $loc, $cid);

    $sgene = $GENE;
    @tempArray = split "[\/,]", $sgene;
    $t = 0;

    $sgene =~ s/\+//g;
    $sgene =~ s/-//g;
    $sgene =~ s/\//&#037;\//g;
    $sgene =~ s/,/&#037;,/g;
    $sgene = $sgene . "&#037;";

    $ssep  = ",";
    @sgene = split ",", $sgene;

    for ($s = 0; $s <= $#sgene; $s++) {
      $xgene = $sgene[$s];
      $xsep  = "/";
      @xgene = split "/", $xgene;
      for ($x = 0; $x <= $#xgene; $x++) {
        $xgene[$x] =~ s/&#037;/%/;
        $sql = "select distinct locuslink, cluster_number " .
               "from $CGAP_SCHEMA.mitelman_genes " .
               "where symbol like '$xgene[$x]'";

        $stm = $db->prepare($sql);
        if (not $stm) {
          print "<br><b><center>Error in input</b>!</center>";
          $db->disconnect();
          return "";
        } 
        if (!$stm->execute()) {
          $db->disconnect();
          return;
        }

        $stm->bind_columns(\$loc, \$cid);

        if ($stm->fetch) {
          if ($cid) {
            $Genes .=
              "<a href=\"$Url_2/GeneInfo?ORG=Hs&CID=$cid\">";
          } elsif ($loc) {
            $Genes .=
              "<a href=javascript:spawn(" .
              "\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?" .
              "db=gene&cmd=Retrieve&dopt=full_report&" .
              "list_uids=$loc\")>";
          }
          $Genes .=
            "$tempArray[$t]" .
            "</a>" .
            (($x < $#xgene) ? "$xsep" : "");
          $stm->finish;
        } else {
          $Genes .=
            "$tempArray[$t]".
            (($x < $#xgene) ? "$xsep" : "");
        }
        $t++;
      }
      $Genes .=
         "</a>" .
         (($s < $#sgene) ? "$ssep" : "");
    }
  }
  $Genes .= "</TD>";

  push @result, $Genes;

  return join "\032", @result;

}

######################################################################
sub convrtToLine {


  my ($TYPE, $CHROMOSOME, $ARM, $BAND, $ABERRATION, $DISEASE, $ORGAN, 
      $TOTAL_CASES, $GENE, $CODE, $db) = @_;

  my ($Band, $Abnormality, $Neoplasm,
      $Site, $TotalCases, $Genes);


  my @result;

  my $temp;

  $temp = "";
  if( $TYPE eq "S" ) {
    $Band = $CHROMOSOME . $ARM . $BAND;
  }
  elsif ( $TYPE eq "N" ) {
    $Band = $CHROMOSOME;
  }
  push @result, $Band;

  push @result, $ABERRATION;

  push @result, $DISEASE;

  my $full_name;
  if( $ORGAN ne "" ) {
    $full_name = &mapToFullName($ORGAN, "TOP", $db);
  }
  push @result, $full_name;

  push @result, $TOTAL_CASES;

  push @result, $GENE;

  return join "\032", @result;

}

######################################################################

sub prepare_sql {

  my ($chr_key, $arm_key, $band_key, $neopl_key, $tissue_key, 
      $gene_key, $type_key ) = @_;

  &debug_print("!!!!!!!!!!!!!!!!!!!!!!!!!\n");
  &debug_print( "$chr_key, $arm_key, $band_key, $neopl_key, $tissue_key, 
                 $type_key, $gene_key \n" );
  &debug_print("!!!!!!!!!!!!!!!!!!!!!!!!!\n");


  my $chr_default = 0;
  my $arm_default = 0;
  my $band_default = 0;
  my $neopl_default = 0;
  my $tissue_default = 0;
  my $type_default = 0;
  my $gene_default = 0;

  my ($chr_sql, $arm_sql, $band_sql, $neopl_sql, $tissue_sql, 
      $gene_sql, $type_sql);

  my $sql_stm;

  if( $chr_key eq "All" || $chr_key eq "" ) {
    $chr_default = 1;
  }
  else
  {
    $chr_sql = "a.CHROMOSOME='$chr_key'";
  }

  if( $arm_key eq "Both" || $arm_key eq "" ) {
    $arm_default = 1;
  }
  else
  {
    $arm_sql = "a.ARM='$arm_key'";
  }

  if( $band_key eq "All" || $band_key eq "" ) {
    $band_default = 1;
  }
  else
  {
    $band_sql = "a.BAND=$band_key";
  }

  if( $neopl_key eq "All morphologies" || $neopl_key eq "" ) {
    $neopl_default = 1;
  }
  else
  {
    $neopl_sql = "a.CODE like '$neopl_key' ";
  }

  if( $tissue_key eq "All topographies" || $tissue_key eq "" ) {
    $tissue_default = 1;
  }
  else
  {
    $tissue_sql = "a.ORGAN like '$tissue_key' ";
  }

  if( $gene_key eq "All genes" || $gene_key eq "" ) {
    $gene_default = 1;
  }
  else
  {
    $gene_sql =  "( a.GENE='$gene_key'          or 
                    a.GENE like '$gene_key/%'   or 
                    a.GENE like '%,$gene_key/%' or 
                    a.GENE like '%/$gene_key'   or 
                    a.GENE like '%/$gene_key,%' ) ";
  }

  if( $type_key eq "Both" || $type_key eq "" ) {
    $type_default = 1;
  }
  else
  {
    if( $type_key eq "Balanced" ) {
      $type_sql = "a.TYPE = 'B' ";
    }
    elsif( $type_key eq "Unbalanced" ) { 
      $type_sql = "a.TYPE = 'U' ";
    } 
  }

  $sql_stm = "select a.CHROMOSOME, a.ARM, a.BAND, a.ABERRATION,
                   b.BENAMNING, a.ORGAN, a.TOTAL_CASES,
                   a.GENE, a.CODE, a.TYPE from $CGAP_SCHEMA.RECURRENT_DATA a,
                   $CGAP_SCHEMA.Koder b where a.CODE = b.KOD 
                   and b.KODTYP = 'MORPH' ";

  if( !$chr_default ) {
    $sql_stm = $sql_stm . " and " . $chr_sql;
  }
  if( !$arm_default ) {
    $sql_stm = $sql_stm . " and " . $arm_sql;
  }
  if( !$band_default ) {
    $sql_stm = $sql_stm . " and " . $band_sql;
  }
  if( !$neopl_default ) {
    $sql_stm = $sql_stm . " and " . $neopl_sql;
  }
  if( !$tissue_default ) {
    $sql_stm = $sql_stm . " and " . $tissue_sql;
  }
  if( !$gene_default ) {
    $sql_stm = $sql_stm . " and " . $gene_sql;
  }
  if( !$type_default ) {
    $sql_stm = $sql_stm . " and " . $type_sql;
  }

  $sql_stm = $sql_stm . " order by a.CHR_ORDER, a.ARM, a.BAND, a.ABERRATION,
                                   b.BENAMNING";

  &debug_print("!!!!!!!!!!!!!!!!!\n");
  &debug_print("sql_stm: $sql_stm\n");
  &debug_print("!!!!!!!!!!!!!!!!!\n");

  return $sql_stm;

}


######################################################################

sub prepare_num_sql {

  my ( $chr_key, $neopl_key, $tissue_key, $type_key ) = @_;


  debug_print ("chr_key: $chr_key \n");
  debug_print ("neopl_key: $neopl_key \n");
  debug_print ("tissue_key: $tissue_key \n");
  debug_print ("type_key: $type_key \n");
  my $chr_default = 0;
  my $neopl_default = 0;
  my $tissue_default = 0;
  my $type_default = 0;

  my ($chr_sql, $neopl_sql, $tissue_sql, 
      $gene_sql, $type_sql);

  my $sql_stm;

  if( $chr_key eq "" ) {
    $chr_default = 1;
  }
  else
  {
    $chr_sql = "a.CHROMOSOME='$chr_key'";
  }

  if( $neopl_key eq "All morphologies" || $neopl_key eq "" ) {
    $neopl_default = 1;
  }
  else
  {
    $neopl_sql = "a.CODE like '$neopl_key' ";
  }

  if( $tissue_key eq "All topographies" || $tissue_key eq "" ) {
    $tissue_default = 1;
  }
  else
  {
    $tissue_sql = "a.ORGAN like '$tissue_key' ";
  }

  if( $type_key eq "Both" || $type_key eq "" ) {
    $type_default = 1;
  }
  else
  {
    if( $type_key =~ /Trisomy/ ) {
      $type_sql = "a.ABNORMALITY like '+%' ";
    }
    elsif( $type_key =~ /Monosomy/ ) { 
      $type_sql = "a.ABNORMALITY like '-%' ";
    } 
  }

  debug_print( " 1: $chr_default, 2: $neopl_default, 3: $tissue_default, 
                 4: $type_default ");

  $sql_stm = "select a.CHROMOSOME, a.ABNORMALITY,
                   b.BENAMNING, a.ORGAN, a.TOTAL_CASES,
                   a.CODE from $CGAP_SCHEMA.RECURRENT_NUM_DATA a,
                   $CGAP_SCHEMA.Koder b where a.CODE = b.KOD 
                   and b.KODTYP = 'MORPH' ";

  if( !$chr_default ) {
    $sql_stm = $sql_stm . " and " . $chr_sql;
  }
  if( !$neopl_default ) {
    $sql_stm = $sql_stm . " and " . $neopl_sql;
  }
  if( !$tissue_default ) {
    $sql_stm = $sql_stm . " and " . $tissue_sql;
  }
  if( !$type_default ) {
    $sql_stm = $sql_stm . " and " . $type_sql;
  }

  $sql_stm = $sql_stm . " order by a.CHR_ORDER, a.ABNORMALITY,
                                   b.BENAMNING";

  &debug_print("!!!!!!!!!!!!!!!!!\n");
  &debug_print("sql_stm: $sql_stm\n");
  &debug_print("!!!!!!!!!!!!!!!!!\n");

  return $sql_stm;

}






######################################################################
sub mapToFullName {

  my ($in_code, $type, $db) = @_;

  my ($full_name, $name);

  my $sql_map = "select BENAMNING from $CGAP_SCHEMA.Koder
                 where KOD = '$in_code' and KODTYP = '$type'";

  &debug_print( "sql_map: $sql_map \n");

  my $stm_map = $db->prepare($sql_map);

  if (not $stm_map) {
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }

  if (not $stm_map->execute()) {
    ## print STDERR "$sql_map\n";
    print "execute call failed\n";
    $db->disconnect();
    return undef;
  }

  $full_name = "";
  $stm_map->bind_columns( \$full_name );

  while( $stm_map->fetch) {
    $name = FixSpecChar($full_name); 
  }

  &debug_print( "name: $name \n");

  return $name;
}

 
######################################################################

# convert some special characters for web URL

######################################################################

sub convrt {
  my ($temp) = @_;

  $temp =~ s/ /+/g;
  $temp =~ s/-/%2D/g;
  $temp =~ s/'/%27/g;

  return $temp
}

######################################################################
sub convrtSlash {
  my ($temp) = @_;

  $temp =~ s/\//,/g;
  $temp =~ s/\+//g;

  return $temp
}

######################################################################

# convert ' to '' for sql

######################################################################
sub convrtSingleToDoubleQuote {
  my ($temp) = @_;

  $temp =~ s/'/''/g;

  return $temp
}

######################################################################
sub convertSiteAbbreviationToFullName {

  my ($full_name) = @_;
  if( $full_name eq "Nas cav" ) {
      $full_name = "Nasal cavity";
  }
  elsif( $full_name eq "Nasoph" ) {
      $full_name = "Nasopharynx";
  }
  elsif( $full_name eq "Intrathor" ) {
      $full_name = "Intrathoracal";
  }
  elsif( $full_name eq "Oral" ) {
      $full_name = "Oral cavity";
  }
  elsif( $full_name eq "Sal gl" ) {
      $full_name = "Salivary gland";
  }
  elsif( $full_name eq "Oroph" ) {
      $full_name = "Oropharynx";
  }
  elsif( $full_name eq "Oesoph" ) {
      $full_name = "Oesophagus";
  }
  elsif( $full_name eq "Panc" ) {
      $full_name = "Pancreas";
  }
  elsif( $full_name eq "Gall" ) {
      $full_name = "Gallbladder";
  }
  elsif( $full_name eq "S intest" ) {
      $full_name = "Small intestine";
  }
  elsif( $full_name eq "L intest" ) {
      $full_name = "Large intestine";
  }
  elsif( $full_name eq "Periton" ) {
      $full_name = "Peritoneum";
  }
  elsif( $full_name eq "Periton" ) {
      $full_name = "Peritoneum";
  }
  elsif( $full_name eq "Intraabdom" ) {
      $full_name = "Intraabdominal";
  }
  elsif( $full_name eq "Fallop" ) {
      $full_name = "Fallopian tube";
  }
  elsif( $full_name eq "Uterus" ) {
      $full_name = "Uterus, corpus";
  }
  elsif( $full_name eq "Cervix" ) {
      $full_name = "Uterus, cervix";
  }
  elsif( $full_name eq "Pituit" ) {
      $full_name = "Pituitary";
  }
  elsif( $full_name eq "Parath" ) {
      $full_name = "Parathyroid";
  }
  elsif( $full_name eq "Hypothal" ) {
      $full_name = "Hypothalamus";
  }
  elsif( $full_name eq "Pineal" ) {
      $full_name = "Pineal body";
  }
  elsif( $full_name eq "Cereb" ) {
      $full_name = "Cerebellum";
  }
  elsif( $full_name eq "Brain st" ) {
      $full_name = "Brain stem";
  }
  elsif( $full_name eq "Spinal" ) {
      $full_name = "Spinal cord";
  }
  elsif( $full_name eq "Bl vessel" ) {
      $full_name = "Blood vessel";
  }
  elsif( $full_name eq "Lymph" ) {
      $full_name = "Lymph node";
  }
  elsif( $full_name eq "Unknown" ) {
      $full_name = "Unknown site";
  }

  return $full_name;
}

######################################################################
sub split_breakpoint {

  my ($temp_breakpoint) = @_;
  my ($chr_in, $arm_in, $band_in);
  
  if( $temp_breakpoint =~ /p/ ) {
 
    ( $chr_in, $band_in ) = split "p", $temp_breakpoint;
    $arm_in = "p";
    if( $chr_in eq "" ) {
       $chr_in = "All";
    }
    if(( $band_in eq "" ) || ( $band_in !~ /^\d+$/ )) {
       $band_in = "All";
    }
  }
  elsif( $temp_breakpoint =~ /P/ ) {
 
    ( $chr_in, $band_in ) = split "P", $temp_breakpoint;
    $arm_in = "p";
    if( $chr_in eq "" ) {
       $chr_in = "All"; 
    }
    if(( $band_in eq "" ) || ( $band_in !~ /^\d+$/ )) {
       $band_in = "All";
    }
  }
  elsif( $temp_breakpoint =~ /q/ ) {
 
    ( $chr_in, $band_in ) = split "q", $temp_breakpoint;
    $arm_in = "q";
    if( $chr_in eq "" ) {
       $chr_in = "All"; 
    }
    if(( $band_in eq "" ) || ( $band_in !~ /^\d+$/ )) {
       $band_in = "All";
    }
  }
  elsif( $temp_breakpoint =~ /Q/ ) {

    ( $chr_in, $band_in ) = split "Q", $temp_breakpoint;
    $arm_in = "q";
    if( $chr_in eq "" ) {
       $chr_in = "All"; 
    }
    if(( $band_in eq "" ) || ( $band_in !~ /^\d+$/ )) {
       $band_in = "All";
    }
  }
  elsif( $temp_breakpoint =~ /\d+/ ) {
    $chr_in = $temp_breakpoint;
    $arm_in = "Both";
    $band_in = "All";
  }
  elsif( $temp_breakpoint =~ /X/   or
         $temp_breakpoint =~ /x/ ) {
    $chr_in = "X";
    $arm_in = "Both";
    $band_in = "All";
  }
  elsif( $temp_breakpoint =~ /Y/   or
         $temp_breakpoint =~ /y/ ) {
    $chr_in = "Y";
    $arm_in = "Both";
    $band_in = "All";
  }
  elsif( $temp_breakpoint eq "" ) {
    $chr_in = "All";
    $arm_in = "Both";
    $band_in = "All";
  }

  return join "\002", $chr_in, $arm_in, $band_in; 
}

######################################################################
sub getUrlWithColoredValueForSTS {

  my ($url_id, $value, $flag, $Url_2) = @_;
  if ($flag =~ /UN/) {
    return "<A HREF=javascript:spawn(\"$Url_2/sts.cgi?uid=$url_id\")>
                <font color=\"#FF0000\">$value</font></A><sup>+</sup>";
  }
  if ( $flag =~ /DI/ ) {
    return "<A HREF=javascript:spawn(\"$Url_2/sts.cgi?uid=$url_id\")>
                <font color=\"#FF0000\">$value</font></A><sup>*</sup>";
  }

  return 
    "<A HREF=javascript:spawn(\"$Url_2/sts.cgi?uid=$url_id\")>$value</A>";
} 

######################################################################
sub getUrlWithColoredValueForINS_SQS {

  my ($value, $flag, $Url_5) = @_;
  if ($flag =~ /UN/) {
    return 
      "<A HREF=javascript:spawn(\"$Url_5/viewer.fcgi?view=gb&val=$value\")>
                <font color=\"#FF0000\">$value</font></A><sup>+</sup>";
  }
  if ( $flag =~ /DI/ ) {
    return 
      "<A HREF=javascript:spawn(\"$Url_5/viewer.fcgi?view=gb&val=$value\")>
                <font color=\"#FF0000\">$value</font></A><sup>*</sup>";
  }

  return 
    "<A HREF=javascript:spawn(\"$Url_5/viewer.fcgi?view=gb&val=$value\")>
              $value</A>";
} 

######################################################################
sub getUrlWithColoredValueForEND_SQS {

  my ($url_value, $value, $flag, $Url_5) = @_;
  if ($flag =~ /UN/) {
    return 
      "<A HREF=javascript:spawn(\"$Url_5/viewer.fcgi?view=gb&val=$url_value\")>
                <font color=\"#FF0000\">$value</font></A><sup>+</sup>";
  }
  if ( $flag =~ /DI/ ) {
    return 
      "<A HREF=javascript:spawn(\"$Url_5/viewer.fcgi?view=gb&val=$url_value\")>
                <font color=\"#FF0000\">$value</font></A><sup>*</sup>";
  }

  return 
    "<A HREF=javascript:spawn(\"$Url_5/viewer.fcgi?view=gb&val=$url_value\")>
              $value</A>";
} 

######################################################################
sub get_chromosome {

  my ($temp) = @_;
  debug_print ("input in get_arm_band: $temp \n");
  if( $temp =~ /\-/ ) {
     my @array = split "-", $temp;  
     $temp = $array[0];
  }

  if ( index($temp, ".") == -1 ) {
     $temp =~ s/[a-zA-Z]+$//;
     return $temp;
  }
  else {
     my $temp1 = substr( $temp, 0, index($temp, ".")); 
     $temp1 =~ s/[a-zA-Z]+$//;
     return $temp1;
  }
}

######################################################################
sub  AddCommatoInteger {
  my ($int) = @_;
 
  my $leng = length ($int);
  my $int_out = "";
 
  my $count = 0;
  for ( my $i=$leng-1; $i>=0 ; $i-- ) {
    $count++;
    my $a = substr($int, $i, 1);
    if( $count == 4 || $count == 7 || $count == 10 || $count == 13 ) {
      $int_out = $a . "," . $int_out;
    }
    else {
      $int_out = $a . $int_out;
    }
  }
 
  return $int_out;
 
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
sub convert_special_chr_to_html_code {
  my ($str) = @_;
  my @new_str;
  my @tmp = split "", $str;
  for (my $i=0; $i<@tmp; $i++) {
    my $value = ord($tmp[$i]);
    if( $value <= 127 and $value != 64 ) {
      push @new_str, $tmp[$i];
    }
    else {
      $value = "&#" . $value;
      push @new_str, $value;
    }
  }
  return join("",@new_str);
}

######################################################################

1;
