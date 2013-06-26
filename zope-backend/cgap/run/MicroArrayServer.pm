#!/usr/local/bin/perl

use strict;
use CGAPConfig;
use Paging;
use DBI;
use FileHandle;
use MicroArray;
use Cache;
use GD;
use SVG;
use URI::URL; 
use URI::Escape; 
use Scan;
use Scan_Server;

my %BUILDS;
my $BASE;
my $NEIGHBOR_RVAL = "0.85";
my $N_NEIGHBORS = 10;

my $IMAGE_HEIGHT = 1800;
my $IMAGE_WIDTH  = 1000;
my $SVG_IMAGE_HEIGHT = 8000;
my $SVG_IMAGE_WIDTH  = 4000;
my $SCREEN_HEIGHT = 800;
my $SCREEN_WIDTH  = 800;
my $CELL_HEIGHT = 15;
my $CELL_WIDTH = 10;
my $SMALL_CELL_WIDTH = 4;
my $LEFT1 = 8;
my $LEFT2 = 67;
my $LEFT3 = 65;
my $LEFT4 = $LEFT2+55;
my $LEFT2_SVG = 80;

my $UBC_SAGE_SVG = 60;
my $LONG_SAGE = 51;

my $cache = new Cache(CACHE_ROOT, MICROARRAY_CACHE_PREFIX);

my ($ma);

use constant BLACK => "000000";
use constant YES => "0";
use constant NO => "1";

my %cluster_table = (
  "Hs" => "hs_cluster",
  "Mm" => "mm_cluster"
);

## allow for multiple experiments off the same bio source
my %data_src2bio_src = (
  "NCI60_STANFORD"    => "NCI60_STANFORD",
  "SAGE"              => "SAGE",
  "SAGE_SUMMARY"      => "SAGE_SUMMARY",
  "NCI60_NOVARTIS"    => "NCI60_NOVARTIS", ## using NCI60_U95
  "UBC_SAGE"          => "UBC_SAGE",
  "LONG_SAGE"         => "LONG_SAGE",
  "NCI60_U133"        => "NCI60_U133",
  "LONG_SAGE_SUMMARY" => "LONG_SAGE_SUMMARY"
##   "NCI60_U95"      => "NCI60_U95"
);

my %exp_name = (
  1 => "SAGE",
  2 => "SAGE_SUMMARY",
  3 => "NCI60_STANFORD",
  4 => "NCI60_NOVARTIS",  ## using NCI60_U95
  5 => "UBC_SAGE",
  6 => "LONG_SAGE",
  7 => "NCI60_U133",
  8 => "LONG_SAGE_SUMMARY"
##  8 => "NCI60_U95"
);

my $SAGE_SUMMARY_CODE = 2;
my $UBC_SAGE_CODE = 5;
my $LONG_SAGE_CODE = 6;
my $NCI60_U133 = 7;
my $LONG_SAGE_SUMMARY_CODE = 8;
## my $NCI60_U95 = 8;

my %cell2color;
my %panel_color_breaks;

## panel_color_breaks are upper bounds
$panel_color_breaks{"NCI60_STANFORD"} =
    [8, 17, 23, 30, 36, 42, 50, 57, 59, 60];

$panel_color_breaks{"SAGE"} =
[5,6,8,12,69,76,121,146,155,178,180,190,192,193,194,195,196,197,200,204,205,208,210,212,214,215,217,223,226,228,230,231,232,234,242,246,247,256,265,272,273,285,292,293,296,297,298,299,301,307,318];

$panel_color_breaks{"SAGE_SUMMARY"} = 
[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51];

$panel_color_breaks{"NCI60_NOVARTIS"} =
    [8, 17, 23, 30, 36, 42, 50, 57, 59, 60];

$panel_color_breaks{"UBC_SAGE"} = [1,2,3,4,5,6,8,10,13,15,22,27,31,36,41,42,46,52,53,72,73,77,79,80,83,84,89,90,92,98,99,103,105,106,107,111,114,115,116,118,119,120,121,122,124,125,126,127,128,131,132,133,134,135,137,138,139,140,142,143,144,145,146,148,149,151,152,153,154,156,157,158,159,161,162,164,165,166,167,168,169,172,173,174,175,176,177,178,179,180,181,182,184,185,186,187,188,189,190,191];

$panel_color_breaks{"LONG_SAGE"} =
[5,7,8,12,14,36,55,59,60,61,62,65,66,72,75,76,77,85,91,102,105,107,110,120];

$panel_color_breaks{"LONG_SAGE_SUMMARY"} =
[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24];

$panel_color_breaks{"NCI60_U133"} =
    [8, 17, 23, 30, 36, 42, 50, 57, 59];

$panel_color_breaks{"NCI60_U95"} =
    [8, 17, 23, 30, 36, 42, 50, 57, 59, 60];

my %color2id = (
  "0000FF" => "A",
  "3399FF" => "B",
  "66CCFF" => "C",
  "99CCFF" => "D",
  "CCCCFF" => "E",
  "FFCCFF" => "F",
  "FF99FF" => "G",
  "FF66CC" => "H",
  "FF6666" => "I",
  "FF0000" => "J",
  "000000" => "K"
);

my %patchForWhiteBloodCells; 

$patchForWhiteBloodCells {"White Blood Cells normal"} = "Leukocytes normal";

my @microarray_color_scale = (
  "0000FF",
  "3399FF",
  "66CCFF",
  "99CCFF",
  "CCCCFF",
  "FFCCFF",
  "FF99FF", 
  "FF66CC", 
  "FF6666",
  "FF0000"
);

######################################################################
sub InitializeDatabase {

  SetCellLineColors();

}

######################################################################
sub ColorScaleIndex {
  my (@temp);
  push @temp, "<center><table>";
  push @temp, "<tr>";
  push @temp, "<td>Lowest</td>";
  for my $color (@microarray_color_scale) {
    push @temp, "<td bgcolor=\"#$color\">\&nbsp;\&nbsp;</td>";
  }
  push @temp, "<td>Highest</td>";
  push @temp, "</tr>";
  push @temp, "<tr>";
  push @temp, "<td>Missing Value</td>";
  push @temp, "<td bgcolor=\"#" . BLACK . "\">\&nbsp;\&nbsp;</td>";
  push @temp, "</tr>";
  push @temp, "</table></center>";
  return join "\n", @temp;
}

######################################################################
sub SetCellLineColors {

  ## my $EVEN_COLOR = "EVEN";
  ## my $ODD_COLOR  = "ODD";

  ## my $EVEN_COLOR = "238,232,170";
  ## my $ODD_COLOR  = "176,196,222";

  my $EVEN_COLOR = "FFFF99";
  my $ODD_COLOR  = "CCCCCC";

  my ($n, $bio_src, $i, $color);
  for $bio_src (values %data_src2bio_src) {
    $n = 1;
    for ($i = 0; $i <= @{ $panel_color_breaks{$bio_src} }; $i++) {
      if ($i % 2 == 0) {
        $color = $EVEN_COLOR;
      } else {
        $color = $ODD_COLOR;
      }
      for (; $n <= $panel_color_breaks{$bio_src}[$i]; $n++) {
        $cell2color{$bio_src}{$n} = $color;
      }
    }
  }

}

######################################################################
sub LookForCIDs {
  my ($data_source, $org, $accs, $acc2cid, $acc2sym) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($sql, $stm);
  my ($acc, $cid, $sym);
  my ($sacc, @simple_accs);

  $ma->LookForCIDs($accs, $acc2cid);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database\n";
    return "";
  }

  my $c_table = $org eq "Hs" ? "hs_cluster" : "mm_cluster";

  for $acc (@{ $accs }) {
    $sacc = $acc;
    $sacc =~ s/_\d+$//;
    push @simple_accs, $sacc;
  }

  my ($i, $list);
  for($i = 0; $i < @simple_accs; $i += 1000) {

    if(($i + 1000 - 1) < @simple_accs) {
      $list = join("','", @simple_accs[$i..$i+1000-1]);
    }
    else {
      $list = join("','", @simple_accs[$i..@simple_accs-1]);
    }

    if ($ma->IsSAGE()) {
      $sql = "select s.tag, s.cluster_number, c.gene " .
          "from $CGAP_SCHEMA.sagebest_cluster s, $CGAP_SCHEMA.$c_table c " .
          "where c.cluster_number = s.cluster_number " .
          "and s.tag in ('" . $list . "') " .
          "and exists (select x.cluster_number from cgap.sagebest_tag2clu x " .
          "where x.protocol = 'A' and x.tag = s.tag " .
          "and x.cluster_number = s.cluster_number) ";

##      $sql = "select s.tag, s.cluster_number, c.gene " .
##          "from $CGAP_SCHEMA.ncbisagemap s, $CGAP_SCHEMA.$c_table c " .
##          "where c.cluster_number = s.cluster_number " .
##          "and s.tag in ('" . $list . "')";
    }
    elsif ($ma->IsLONGSAGE()) {
      $sql = "select s.tag, s.cluster_number, c.gene " .
          "from $CGAP_SCHEMA.sagebest_cluster s, $CGAP_SCHEMA.$c_table c " .
          "where c.cluster_number = s.cluster_number " .
          "and s.tag in ('" . $list . "') " .
          "and exists (select x.cluster_number from cgap.sagebest_tag2clu x " .
          "where x.protocol = 'C' and x.tag = s.tag " .
          "and x.cluster_number = s.cluster_number) ";
 
##      $sql = "select s.tag, s.cluster_number, c.gene " .
##          "from $CGAP_SCHEMA.ncbisagemap s, $CGAP_SCHEMA.$c_table c " .
##          "where c.cluster_number = s.cluster_number " .
##          "and s.tag in ('" . $list . "')";
    }
    elsif ($ma->IsUBCSAGE()) {
      $sql = "select s.tag, s.cluster_number, c.gene " .
          "from $CGAP_SCHEMA.sagebest_cluster s, $CGAP_SCHEMA.$c_table c " .
          "where c.cluster_number = s.cluster_number " .
          "and s.tag in ('" . $list . "') " .
          "and exists (select x.cluster_number from cgap.sagebest_tag2clu x " .
          "where x.protocol = 'M' and x.tag = s.tag " .
          "and x.cluster_number = s.cluster_number) ";
 
##      $sql = "select s.tag, s.cluster_number, c.gene " .
##          "from $CGAP_SCHEMA.ncbisagemap s, $CGAP_SCHEMA.$c_table c " .
##          "where c.cluster_number = s.cluster_number " .
##          "and s.tag in ('" . $list . "')";
    }
    elsif ($ma->IsNCI60_U133()) {
      $sql = "select s.PROBE_SET, c.cluster_number, c.gene " .
          "from $CGAP_SCHEMA.NCI60_AFFYMETRIX s, $CGAP_SCHEMA.$c_table c " .
          "where c.LOCUSLINK = s.GENE_ID and TYPE = 'U133' " .
          "and s.PROBE_SET in ('" . $list . "')";
    } 
    elsif ($ma->IsNCI60_U95() or $ma->IsNCI60_NOVARTIS()) {
      $sql = "select s.PROBE_SET, c.cluster_number, c.gene " .
          "from $CGAP_SCHEMA.NCI60_AFFYMETRIX s, $CGAP_SCHEMA.$c_table c " .
          "where c.LOCUSLINK = s.GENE_ID and TYPE = 'U95' " .
          "and s.PROBE_SET in ('" . $list . "')";
    } else {
      my $table_name = ($org eq "Hs" ? "$CGAP_SCHEMA.hs_ug_sequence " : "$CGAP_SCHEMA.mm_ug_sequence ");
      $sql = "select s.accession, s.cluster_number, c.gene " .
          "from $table_name s, $CGAP_SCHEMA.$c_table c " .
          "where c.cluster_number = s.cluster_number " .
          "and s.accession in ('" . $list . "')";
    }

    $stm = $db->prepare($sql);

    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "prepare call failed\n";
      return "";
    }
    if(!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }
    $stm->bind_columns(\$acc, \$cid, \$sym);
    while($stm->fetch) {
      $$acc2cid{$acc} = $cid;
      if ($sym ne "") {
        push @{ $$acc2sym{$acc} }, $sym;
      } else {
        push @{ $$acc2sym{$acc} }, "$org.$cid";
      }
    }
  }

  $db->disconnect();
}

######################################################################
sub CellLineIndex {
  my ($lines, $org, $src_name, $flag, $columns, $show_index) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  push @{ $lines }, "<table><tr><td>";

  if( $src_name eq "SAGE_SUMMARY"
      and ($flag == 1 or $flag == 0 or $flag == 3) ) {
    push @{ $lines }, "<table><tr><td>";
    push @{ $lines }, "<select multiple name=\"COLUMN\" size=5>";
  
    my $count = 0;
    for my $num (sort numerically keys %{ $ma->{num2cell} }) {
      if( $count == 0 ) {
        push @{ $lines }, "<option value=$num selected>$num: " .
          $ma->Num2Cell($num) .
          "\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;</option>";
      }
      else {
        push @{ $lines }, "<option value=$num>$num: " .
          $ma->Num2Cell($num) .
          "\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;</option>";
      }
      $count++;
    }  
    
    push @{ $lines }, "</select>";
    push @{ $lines }, "</td><td>";
    if( $flag == 1 ) {
      push @{ $lines }, "</td><td valign=center>Details: \&nbsp;\&nbsp;" .
          "</td><td valign=center>" .
          "<a href=\"javascript:" .
          "document.mform.action='FNResults';" .
          "document.mform.SRC.value='SAGE';" .
          "document.mform.SHOW.value=1;" .
          "document.mform.submit()\"> " .
          "PNG</a> \&nbsp;\&nbsp;";
      push @{ $lines }, "</td><td valign=center>" .
          "<a href=\"javascript:" .
          "document.mform.action='FNResults';" .
          "document.mform.SRC.value='SAGE';" .
          "document.mform.SHOW.value=2;" .
          "document.mform.submit()\"> " .
          "SVG</a> " . 
          "</td><td valign=center><a title=\"Download Plugin Adobe SVG Viewer\" href=\"http://www.adobe.com/svg/viewer/install/main.html\" target=\"_blank\"><img src=\"/CGAP/images/tmpSVGlogo.png\" width=\"20\" height=\"20\" border=\"0\"
    alt=\"Download Plugin Adobe SVG Viewer\"\/><\/a>\&nbsp;\&nbsp;";
    }
    elsif( $flag == 0 ) {
      push @{ $lines }, "</td><td valign=center>Details: \&nbsp;\&nbsp;" .
          "</td><td valign=center>" .
          "<a href=\"javascript:" .
          "document.mform.action='GeneList';" .
          "document.mform.SRC.value='SAGE';" .
          "document.mform.SHOW.value=1;" .
          "document.mform.submit()\"> " .
          "PNG</a> \&nbsp;\&nbsp;";
      push @{ $lines }, "</td><td valign=center>" .
          "<a href=\"javascript:" .
          "document.mform.action='GeneList';" .
          "document.mform.SRC.value='SAGE';" .
          "document.mform.SHOW.value=2;" .
          "document.mform.submit()\"> " .
          "SVG</a> " .
          "</td><td valign=center><a title=\"Download Plugin Adobe SVG Viewer\" href=\"http://www.adobe.com/svg/viewer/install/main.html\" target=\"_blank\"><img src=\"/CGAP/images/tmpSVGlogo.png\" width=\"20\" height=\"20\" border=\"0\"
    alt=\"Download Plugin Adobe SVG Viewer\"\/><\/a> \&nbsp;\&nbsp;";
    }
    elsif ( $flag == 3 ) {
      push @{ $lines }, "</td><td valign=center>Details: \&nbsp;\&nbsp;" .
          "</td><td valign=center>" .
          "<a href=\"javascript:" .
          "document.mform.action='SResults';" .
          "document.mform.SRC.value='SAGE';" .
          "document.mform.SHOW.value=1;" .   
          "document.mform.COLUMNS.value='$columns';" .
          "document.mform.submit()\"> " .
          "PNG</a> \&nbsp;\&nbsp;"; 
      push @{ $lines }, "</td><td valign=center>" .
          "<a href=\"javascript:" .
          "document.mform.action='SResults';" .
          "document.mform.SRC.value='SAGE';" .
          "document.mform.SHOW.value=2;" .   
          "document.mform.COLUMNS.value='$columns';" .
          "document.mform.submit()\"> " .
          "SVG</a> " .
          "</td><td valign=center><a title=\"Download Plugin Adobe SVG Viewer\" href=\"http://www.adobe.com/svg/viewer/install/main.html\" target=\"_blank\"><img src=\"/CGAP/images/tmpSVGlogo.png\" width=\"20\" height=\"20\" border=\"0\"
    alt=\"Download Plugin Adobe SVG Viewer\"\/><\/a>\&nbsp;\&nbsp;"; 
    }
    push @{ $lines }, "<input type=hidden name=COLN>"; 
  }
  elsif( $src_name eq "LONG_SAGE_SUMMARY"
      and ($flag == 1 or $flag == 0 or $flag == 3) ) {
    push @{ $lines }, "<table><tr><td>";
    push @{ $lines }, "<select multiple name=\"COLUMN\" size=5>";
 
    my $count = 0;
    for my $num (sort numerically keys %{ $ma->{num2cell} }) {
      if( $count == 0 ) {
        push @{ $lines }, "<option value=$num selected>$num: " .
          $ma->Num2Cell($num) .
          "\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;</option>";
      }
      else {
        push @{ $lines }, "<option value=$num>$num: " .
          $ma->Num2Cell($num) .
          "\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;\&nbsp;</option>";
      }
      $count++;
    }
   
    push @{ $lines }, "</select>";
    push @{ $lines }, "</td><td>";
    if( $flag == 1 ) {
      push @{ $lines }, "</td><td valign=center>Details: \&nbsp;\&nbsp;" .
          "</td><td valign=center>" .
          "<a href=\"javascript:" .
          "document.mform.action='FNResults';" .
          "document.mform.SRC.value='LONG_SAGE';" .
          "document.mform.SHOW.value=1;" .
          "document.mform.submit()\"> " .
          "PNG</a> \&nbsp;\&nbsp;";
      push @{ $lines }, "</td><td valign=center>" .
          "<a href=\"javascript:" .
          "document.mform.action='FNResults';" .
          "document.mform.SRC.value='LONG_SAGE';" .
          "document.mform.SHOW.value=2;" .
          "document.mform.submit()\"> " .
          "SVG</a> " .
          "</td><td valign=center><a title=\"Download Plugin Adobe SVG Viewer\" href=\"http://www.adobe.com/svg/viewer/install/main.html\" target=\"_blank\"><img src=\"/CGAP/images/tmpSVGlogo.png\" width=\"20\" height=\"20\" border=\"0\"
    alt=\"Download Plugin Adobe SVG Viewer\"\/><\/a>\&nbsp;\&nbsp;";
    }
    elsif( $flag == 0 ) {
      push @{ $lines }, "</td><td valign=center>Details: \&nbsp;\&nbsp;" .
          "</td><td valign=center>" .
          "<a href=\"javascript:" .
          "document.mform.action='GeneList';" .
          "document.mform.SRC.value='LONG_SAGE';" .
          "document.mform.SHOW.value=1;" .
          "document.mform.submit()\"> " .
          "PNG</a> \&nbsp;\&nbsp;";
      push @{ $lines }, "</td><td valign=center>" .
          "<a href=\"javascript:" .
          "document.mform.action='GeneList';" .
          "document.mform.SRC.value='LONG_SAGE';" .
          "document.mform.SHOW.value=2;" .
          "document.mform.submit()\"> " .
          "SVG</a> " .
          "</td><td valign=center><a title=\"Download Plugin Adobe SVG Viewer\" href=\"http://www.adobe.com/svg/viewer/install/main.html\" target=\"_blank\"><img src=\"/CGAP/images/tmpSVGlogo.png\" width=\"20\" height=\"20\" border=\"0\"
    alt=\"Download Plugin Adobe SVG Viewer\"\/><\/a>\&nbsp;\&nbsp;";
    }
    elsif ( $flag == 3 ) {
      push @{ $lines }, "</td><td valign=center>Details: \&nbsp;\&nbsp;" .
          "</td><td valign=center>" .
          "<a href=\"javascript:" .
          "document.mform.action='SResults';" .
          "document.mform.SRC.value='LONG_SAGE';" .
          "document.mform.SHOW.value=1;" .  
          "document.mform.COLUMNS.value='$columns';" .
          "document.mform.submit()\"> " .
          "PNG</a> \&nbsp;\&nbsp;";
      push @{ $lines }, "</td><td valign=center>" .
          "<a href=\"javascript:" .
          "document.mform.action='SResults';" .
          "document.mform.SRC.value='LONG_SAGE';" .
          "document.mform.SHOW.value=2;" .  
          "document.mform.COLUMNS.value='$columns';" .
          "document.mform.submit()\"> " .
          "SVG</a> " .
          "</td><td valign=center><a title=\"Download Plugin Adobe SVG Viewer\" href=\"http://www.adobe.com/svg/viewer/install/main.html\" target=\"_blank\"><img src=\"/CGAP/images/tmpSVGlogo.png\" width=\"20\" height=\"20\" border=\"0\"
    alt=\"Download Plugin Adobe SVG Viewer\"\/><\/a>\&nbsp;\&nbsp;";
    }
    push @{ $lines }, "<input type=hidden name=COLN>";
  }
  elsif ( $src_name eq "UBC_SAGE" ) { 
    my $count = 0;
    push @{ $lines }, "<select name=COLN size=5>";
    for (my $i = 1; $i <= $ma->NumCols(); $i++) {
      if( $count == 0 ) {
        push @{ $lines }, "<option value=$i selected>$i: " .
          $ma->Num2Cell($i) . 
          "</option>";
      }
      else {
        push @{ $lines }, "<option value=$i>$i: " .
          $ma->Num2Cell($i) . 
          "</option>";
      }
      $count++;
    }
    push @{ $lines }, "</select>";  
  
    if( $src_name ne "NCI60_NOVARTIS" and $src_name ne "NCI60_U133" and $src_name ne "NCI60_U95" ) {
      if( $show_index == 2 ) {
        push @{ $lines }, "</td><td valign=center>" .
          "\&nbsp;\&nbsp;\&nbsp;<a href=\"javascript:" .
          "document.mform.action='PivotResults';" .
          "document.mform.SRC.value='$src_name';" .
          "document.mform.ORG.value='$org';" .
          "document.mform.SHOW.value=2;" .
          "document.mform.submit()\">" .
          "Pivot On Column </a>\&nbsp;\&nbsp;"; 
      }
      else {
        push @{ $lines }, "</td><td valign=center>" .
          "\&nbsp;\&nbsp;\&nbsp;<a href=\"javascript:" .
          "document.mform.action='PivotResults';" .
          "document.mform.SRC.value='$src_name';" .
          "document.mform.ORG.value='$org';" .
          "document.mform.SHOW.value=1;" .
          "document.mform.submit()\">" .
          "Pivot On Column </a>\&nbsp;\&nbsp;"; 
      }
    }
  }
  else { 
    my $count = 0;
    push @{ $lines }, "<select name=COLN size=5>";
    for (my $i = 1; $i <= $ma->NumCols(); $i++) {
      if( $count == 0 ) {
        push @{ $lines }, "<option value=$i selected>$i: " .
          $ma->Num2Cell($i) . " " .
          "\[" .
          $ma->Cell2Panel($ma->Num2Cell($i)) .
          "\]" .
          "</option>";
      }
      else {
        push @{ $lines }, "<option value=$i>$i: " .
          $ma->Num2Cell($i) . " " .
          "\[" .
          $ma->Cell2Panel($ma->Num2Cell($i)) .
          "\]" .
          "</option>";
      }
      $count++;
    }
    push @{ $lines }, "</select>";  
  
    if( $src_name ne "NCI60_NOVARTIS" and $src_name ne "NCI60_U133" and $src_name ne "NCI60_U95" ) {
      if( $show_index == 2 ) {
        push @{ $lines }, "</td><td valign=center>" .
          "\&nbsp;\&nbsp;\&nbsp;<a href=\"javascript:" .
          "document.mform.action='PivotResults';" .
          "document.mform.SRC.value='$src_name';" .
          "document.mform.ORG.value='$org';" .
          "document.mform.SHOW.value=2;" .
          "document.mform.submit()\">" .
          "Pivot On Column </a>\&nbsp;\&nbsp;"; 
      }
      else {
        push @{ $lines }, "</td><td valign=center>" .
          "\&nbsp;\&nbsp;\&nbsp;<a href=\"javascript:" .
          "document.mform.action='PivotResults';" .
          "document.mform.SRC.value='$src_name';" .
          "document.mform.ORG.value='$org';" .
          "document.mform.SHOW.value=1;" .
          "document.mform.submit()\">" .
          "Pivot On Column </a>\&nbsp;\&nbsp;"; 
      }
    }
  }

  push @{ $lines }, "</td></tr></table>";

}

######################################################################
sub CellLineHeader {
  my ($data_src, $n_leader_cols) = @_;

  my $bio_src = $data_src2bio_src{$data_src};
  my $cell_cols = $ma->NumCols();

  my (@temp);
  push @temp, "<tr>";
  for (my $i = 1; $i <= $n_leader_cols - 1; $i++) {
      push @temp, "<td>\&nbsp;</td>";
  }
  push @temp, "<td><font size=1>" . "<b>Panel</b>" . "</font></td>";
  for (my $i = 1; $i <= $cell_cols; $i++) {
    push @temp, "<td bgcolor=\"#$cell2color{$bio_src}{$i}\">" .
        "<font size=1>" . ($i < 10 ? "\&nbsp;" : "") . "$i</font></td>";
  }
  push @temp, "</tr>";
##  push @temp, "<tr><td colspan=" . ($cell_cols+3) . ">\&nbsp;</td></tr>\n";
  return join "\n", @temp;
}

######################################################################
sub DisplayPivotRow {
  my ($org, $src_name, $accession, $vector, $pivot_column,
      $pos_cols, $neg_cols, $scale,
      $lines, $acc2cid, $acc2sym) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  push @{ $lines }, "<tr>";
  if (not defined $$acc2cid{$accession}) {
    push @{ $lines }, "<td><font size=1>\&nbsp;</font></td>";
  } elsif (@{ $$acc2cid{$accession} } == 1) {
    push @{ $lines }, "<td><font size=1>" .
        "<a href=\"$BASE/Genes/GeneInfo?" .
        "ORG=$org&CID=$$acc2cid{$accession}[0]\">" .
        "$$acc2sym{$accession}[0]</a>\&nbsp;\&nbsp;</font></td>";
  } else {
    my $nice_sym = $$acc2sym{$accession}[0];
    for (@{ $$acc2sym{$accession} }) {
      if (! /^Hs\./) {
        $nice_sym = $_;
      }
    }
    push @{ $lines }, "<td><font size=1>" .
        "<a href=\"$BASE/Genes/RunUniGeneQuery?" .
        "PAGE=1&ORG=$org&TERM=" .
        "$org." . join(",$org.", @{ $$acc2cid{$accession} }) . "\">" .
        "$nice_sym...</a>\&nbsp;\&nbsp;</font></td>";
  }
  push @{ $lines }, "<td><font size=1>" .
      "<a href=\"FNResults?ORG=$org&" .
      "SRC=$src_name&ACCESSION=$accession&SHOW=1\">" .
      "$accession</a>\&nbsp;\&nbsp;</font></td>";

  my (@temp, $x);
  if ($ma->ColorTheVector($accession, $scale, \@temp)) {
    push @{ $lines }, "<td bgcolor=\"#" .
        $temp[$pivot_column] .
        "\">\&nbsp;</td>";
    push @{ $lines }, "<td>\&nbsp;</td>";
    for $x (@{ $pos_cols }) {
      push @{ $lines }, "<td bgcolor=\"#" .
          $temp[$x] .
          "\">\&nbsp;</td>";
    }
    push @{ $lines }, "<td>\&nbsp;</td>";
    for $x (@{ $neg_cols }) {
      push @{ $lines }, "<td bgcolor=\"#" .
          $temp[$x] .
          "\">\&nbsp;</td>";
    }    
  } else {
    push @{ $lines }, "<td bgcolor=\"#" .
        $ma->ColorTheSpot($$vector[$pivot_column], $scale) .
        "\">\&nbsp;</td>";
    push @{ $lines }, "<td>\&nbsp;</td>";
    for $x (@{ $pos_cols }) {
      push @{ $lines }, "<td bgcolor=\"#" .
          $ma->ColorTheSpot($$vector[$x], $scale) .
          "\">\&nbsp;</td>";
    }
    push @{ $lines }, "<td>\&nbsp;</td>";
    for $x (@{ $neg_cols }) {
      push @{ $lines }, "<td bgcolor=\"#" .
          $ma->ColorTheSpot($$vector[$x], $scale) .
          "\">\&nbsp;</td>";
    }
  }
  push @{ $lines }, "</tr>";
}

######################################################################
sub DisplayArrayRow {
  my ($org, $src_name, $accession, $nvals, $val1, $val2, $vector, $scale,
      $lines, $acc2cid, $acc2sym) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  push @{ $lines }, "<tr>";
  if (not defined $$acc2cid{$accession}) {
    push @{ $lines }, "<td><font size=1>\&nbsp;</font></td>";
  } elsif (@{ $$acc2cid{$accession} } == 1) {
    push @{ $lines }, "<td><font size=1>" .
        "<a href=\"$BASE/Genes/GeneInfo?" .
        "ORG=$org&CID=$$acc2cid{$accession}[0]\">" .
        "$$acc2sym{$accession}[0]</a>\&nbsp;\&nbsp;</font></td>";
  } else {
    my $nice_sym = $$acc2sym{$accession}[0];
    for (@{ $$acc2sym{$accession} }) {
      if (! /^Hs\./) {
        $nice_sym = $_;
      }
    }
    push @{ $lines }, "<td><font size=1>" .
        "<a href=\"$BASE/Genes/RunUniGeneQuery?" .
        "PAGE=1&ORG=$org&TERM=" .
        "$org." . join(",$org.", @{ $$acc2cid{$accession} }) . "\">" .
        "$nice_sym...</a>\&nbsp;\&nbsp;</font></td>";
  }

  push @{ $lines }, "<td><font size=1>" .
      "<a href=\"FNResults?ORG=$org&" .
      "SRC=$src_name&ACCESSION=$accession&SHOW=1\">" .
      "$accession</a>\&nbsp;\&nbsp;</font></td>";
  push @{ $lines }, "<td><font size=1>$val1</font></td>";
  if ($nvals > 1) {
    push @{ $lines }, "<td><font size=1>\&nbsp;$val2</font></td>";
  }

  my @temp;
  if ($ma->ColorTheVector($accession, $scale, \@temp)) {
    for my $x (@temp) {
      push @{ $lines }, "<td bgcolor=\"#" .
          $x .
          "\">\&nbsp;</td>";
    }
  } else {
    for my $x (@{ $vector }) {
      push @{ $lines }, "<td bgcolor=\"#" .
          $ma->ColorTheSpot($x, $scale) .
          "\">\&nbsp;</td>";
    }
  }
  push @{ $lines }, "</tr>";
}

######################################################################
sub AccessionsOfCIDs {
  my ($org, $cidlist, $accs) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my ($accession);
  my ($sql, $stm);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print "Cannot connect to database\n";
    return "";
  }

  my $table_name = ($org eq "Hs" ? "$CGAP_SCHEMA.hs_ug_sequence " : "$CGAP_SCHEMA.mm_ug_sequence ");

  $sql = "select accession from $table_name " .
         "where cluster_number in ($cidlist) ".
         "and build_id = $BUILDS{$org}";
  $stm = $db->prepare($sql);

  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "prepare call failed\n";
    return "";
  }
  else {
    if(!$stm->execute()) {
       ## print STDERR "$sql\n";
       ## print STDERR "$DBI::errstr\n";
       print "execute call failed\n";
       return "";
    }
    $stm->bind_columns(\$accession);
    while($stm->fetch) {
      push @{ $accs }, $accession;
    }
  }

  $db->disconnect();

}

######################################################################
sub LookForAccessions_1 {
  my ($base, $org, $cid) = @_;

  my $test = Scan ($base, $org, $cid);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  $BASE = $base;
  my @temp;
  my ($sql, $stm);
  my ($exp, $probe, $replica, $tag, $str1);
  my %src_acc;

  InitializeDatabase();
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print STDERR "$DBI::errstr\n";
    die "Error: Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE;
    exit;
  }

  $sql = "select unique c.experiment_id, c.probe, c.replica " .
         "from $CGAP_SCHEMA.NCI60_AFFYMETRIX s,$CGAP_SCHEMA.cgap_2d_color c " .
         "where s.probe_set = c.probe " .
         "and s.cluster_number = $cid " ;

  $stm = $db->prepare($sql);

  if (not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "prepare call failed\n";
    return "";
  }

  if (!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    return "";
  }
  $stm->bind_columns(\$exp, \$probe, \$replica);
  while ($stm->fetch) {
    if ($exp != 1) {
      push @{$src_acc{$exp_name{$exp}}}, $probe . "_" . $replica;
    }
  }

  my $c_table = $org eq "Hs" ? "hs_cluster" : "mm_cluster";
  my $table_name = ($org eq "Hs" ? "$CGAP_SCHEMA.hs_ug_sequence " : "$CGAP_SCHEMA.mm_ug_sequence ");

  $sql = "select unique c.experiment_id, c.probe, c.replica " .
         "from $table_name s, $CGAP_SCHEMA.cgap_2d_color c " .
         "where s.accession = c.probe " .
         "and s.cluster_number = $cid " ;

  $stm = $db->prepare($sql);

  if (not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "prepare call failed\n";
    return "";
  }
  if (!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    return "";
  }
  $stm->bind_columns(\$exp, \$probe, \$replica);
  while ($stm->fetch) {
    if ($exp != 1) {
      push @{$src_acc{$exp_name{$exp}}}, $probe . "_" . $replica;
    }
  }

  $sql = "select unique s.tag, EXPERIMENT_ID " .
         "from $CGAP_SCHEMA.sagebest_cluster s, " .
         "     $CGAP_SCHEMA.cgap_2d_raw b " .
         "where s.cluster_number = $cid " .
         "and s.tag = b.probe and EXPERIMENT_ID " .
         "in ( $SAGE_SUMMARY_CODE, $UBC_SAGE_CODE, $LONG_SAGE_SUMMARY_CODE ) " .
         ## "in ( $SAGE_SUMMARY_CODE, $UBC_SAGE_CODE, $LONG_SAGE_CODE, $LONG_SAGE_SUMMARY_CODE ) " .
         "and s.protocol in ( 'A', 'C', 'M' ) " .
         "and exists (select x.cluster_number from cgap.sagebest_tag2clu x " .
         "where x.protocol in ( 'A', 'C', 'M' ) and x.tag = s.tag " .
         "and x.cluster_number = s.cluster_number) ";


  $stm = $db->prepare($sql);

  if (not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "prepare call failed\n";
    return "";
  }
  if (!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    return "";
  }
  $stm->bind_columns(\$tag, \$exp);
  ## $exp = 2;
  while ($stm->fetch) {
    push @{$src_acc{$exp_name{$exp}}}, $tag . "_0";
  }

  ## push @temp, "<h3>SAGE/Microarray Data Available for $org, $cid</h3>";
  my $tmp_line; 
  for my $src (sort keys %src_acc) {
    for my $accession (@{ $src_acc{$src} }) {
      $str1 = $accession;
      $str1 =~ s/_0$//;
      if( ($org eq "Hs") and ($src eq "LONG_SAGE_SUMMARY") ) {
        $tmp_line = "Long_SAGE_Summary: " .
                "<a href=\"FNResults?" .
                "ORG=$org&" .
                "ACCESSION=$accession$_&SRC=$src&SHOW=1\">$str1</a>";
      } 
      elsif( ($org eq "Mm") and ($src eq "UBC_SAGE") ) {
        $tmp_line = "Mouse_Atlas_SAGE: " .
                "<a href=\"FNResults?" .
                "ORG=$org&" .
                "ACCESSION=$accession$_&SRC=$src&SHOW=1\">$str1</a>";
      } 
      elsif ( ($src eq "NCI60_STANFORD") or 
              ($src eq "NCI60_NOVARTIS") or
              ($src eq "NCI60_U133") or
              ($src eq "NCI60_U95") or
              ($src eq "SAGE_SUMMARY") or
              ($src eq "LONG_SAGE_SUMMARY") ) {
        push @temp,
          ($src eq "NCI60_STANFORD" ? "NCI60_Stanford: " :
           $src eq "NCI60_NOVARTIS" ? "NCI60_Novartis: " :
           $src eq "NCI60_U133" ? "NCI60_U133: " :
           $src eq "NCI60_U95" ? "NCI60_U95: " :
           ## $src eq "LONG_SAGE_SUMMARY" ? "Long_SAGE_Summary: " :
           $src eq "SAGE_SUMMARY" ? "Short_SAGE_Summary: " : "" ) . 
           "<a href=\"FNResults?" .
           "ORG=$org&" .
           "ACCESSION=$accession$_&SRC=$src&SHOW=1\">$str1</a>";
      }
    }
  }
  if( $tmp_line ne "" ) {
    push @temp, $tmp_line;
  }

  $db->disconnect;

  if (@temp < 2) {
    return "No microarray data found\n";
  } else {
    return join("<p>", @temp);
  }

}

######################################################################
sub ByStats_1 {
  my ($base, $show_index, $org, $data_src, $scope, $columns, $what, 
             $selected_detail_coln) = @_;

  my $test = Scan ($base, $show_index, $org, $data_src, $scope, $columns, 
                   $what, $selected_detail_coln);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  $BASE = $base;
  my $NROWS = 50;
  my (@cols, %cols, $col, $mean_or_var, $hi_or_lo);
  my (@accs, @vals, @vecs, %acc2cid, %acc2sym);

  my %display_col;
 
  InitializeDatabase();
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print STDERR "$DBI::errstr\n";
    die "Error: Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE;
    exit;
  }

  $ma = new MicroArray($db, $CGAP_SCHEMA, $data_src);

  ## choose col for SAGE
  my @colns = split (",", $selected_detail_coln);
  if( $data_src eq "SAGE" ) {
    for( my $i=0; $i<@colns; $i++ ) {
      ## my $name = $ma->Num2Cell($colns[$i]);
      my $name = $ma->Num2Group($colns[$i]);
      my @tmp = split (/\_/, $name);
      my $tmp_name1 = $tmp[1];
      for( my $j=2; $j<@tmp; $j++ ) {
        $tmp_name1 = $tmp_name1 . " " . $tmp[$j];
      }
      for (my $i = 1; $i <= $ma->NumCols(); $i++) {
        my $tmp_name2 = $ma->Cell2Panel($ma->Num2Cell($i));
        if( $tmp_name1 =~ /$tmp_name2/i ) {
          $display_col{$i} = 1;
        }
        elsif ( defined $patchForWhiteBloodCells{$tmp_name2} and
                $tmp_name1 =~ /$patchForWhiteBloodCells{$tmp_name2}/i ) {
          $display_col{$i} = 1;
        }
      }  
    }  
  }  

  if ($scope eq "all") {
    $columns = "";
  } elsif ($scope eq "some") {
    $columns =~ s/[^\-,0-9]+/,/g;
    $columns =~ s/,+/,/g;
    $columns =~ s/^,//;
    $columns =~ s/,$//;
    if ($columns eq "") {
      ## SetStatus(S_BAD_REQUEST);
      return "No columns specified\n";
    }
    for $col (split(",", $columns)) {
      if ($col =~ /-/) {
        my ($a, $b) = split("-", $col);
        for (my $i = $a; $i <= $b; $i++) {
          if ($i > $ma->NumCols()) {
            ## SetStatus(S_BAD_REQUEST);
            return "Bad column: $i\n";
          } else {
            $cols{$i} = 1;
          }
        }
      } else {
        if ($col > $ma->NumCols()) {
          ## SetStatus(S_BAD_REQUEST);
          return "Bad column: $col\n";
        } else {
          $cols{$col} = 1;
        }
      }
    }
    @cols = keys %cols;
  } else {
    ## SetStatus(S_BAD_REQUEST);
    return "Bad parameter value SCOPE='$scope'\n";
  }
  ## params: n, by mean, mean hi/lo, by var, var hi/lo
  if ($what eq "himean") {
    $mean_or_var = "mean";
    $hi_or_lo  = "hi";
  } elsif ($what eq "lomean") {
    $mean_or_var = "mean";
    $hi_or_lo  = "lo";
  } elsif ($what eq "hivar") {
    $mean_or_var = "var";
    $hi_or_lo  = "hi";
  } elsif ($what eq "lovar") {
    $mean_or_var = "var";
    $hi_or_lo  = "lo";
  } else {
    ## SetStatus(S_BAD_REQUEST);
    return "Bad parameter value WHAT='$what'\n";
  }

  $ma->ByStats($NROWS, $mean_or_var, $hi_or_lo,
      \@cols, \@accs, \@vals, \@vecs, $col);

  LookForCIDs($data_src, $org, \@accs, \%acc2cid, \%acc2sym);

  $ma->ReadView(\@accs);

  my @lines;

  push @lines, ColorScaleIndex();
##  push @lines, "<br><center>Accessions in array: " .
##      $ma->NumAccessions() . "</center>";

  push @lines, "<form name=mform action=SResults method=POST>";
  push @lines, "<input type=hidden name=COLUMNS>";
  ##  push @lines, "<input type=hidden name=COLUMN value=$selected_detail_coln>";
  if( $data_src eq "SAGE" ) {
    push @lines, "<input type=hidden name=COLUMN value=$selected_detail_coln>";
  }
  push @lines, "<input type=hidden name=SHOW>";
  push @lines, "<input type=hidden name=ORG value=$org>";
  push @lines, "<input type=hidden name=SRC value='$data_src'>";
  push @lines, "<input type=hidden name=WHAT value=$what>";
  push @lines, "<input type=hidden name=SCOPE value=$scope>";

  my $i;
  for my $acc (@accs) {
    if (++$i > 500) {
      last;
    }
    push @lines, "<input type=hidden name=ACCS value=$acc>";
  }

  push @lines, "<p><b>Column Index</b>";

  my $flag = 3;

  my $tmp_columns;
  if( $data_src eq "SAGE_SUMMARY" ) {
    my @tmp1 = split (/-/, $columns);
    if( $tmp1[0] == 1 ) {
      $tmp_columns = "1" . "-" . $panel_color_breaks{"SAGE"}[$tmp1[0] - 1];
    }
    else {
      $tmp_columns = ($panel_color_breaks{"SAGE"}[$tmp1[0] - 2] + 1) . "-" . $panel_color_breaks{"SAGE"}[$tmp1[0] - 1];
    }
  }
  elsif( $data_src eq "LONG_SAGE_SUMMARY" ) {
    my @tmp1 = split (/-/, $columns);
    if( $tmp1[0] == 1 ) {
      $tmp_columns = "1" . "-" . $panel_color_breaks{"LONG_SAGE"}[$tmp1[0] - 1];
    }
    else {
      $tmp_columns = ($panel_color_breaks{"LONG_SAGE"}[$tmp1[0] - 2] + 1) . "-" . $panel_color_breaks{"LONG_SAGE"}[$tmp1[0] - 1];
    }
  }

  CellLineIndex(\@lines, $org, $data_src, $flag, $tmp_columns, $show_index);

  if (@accs > 500) {
    push @lines, "List too long; returning first 500 entries<br>";
  }

##  if ($show_index) {
##    push @lines, "<p><b>Column Index</b>";
##    push @lines, "\&nbsp;\&nbsp;\&nbsp;" .
##        "<a href=\"javascript:document.mform.SHOW.value=0;" .
##        "document.mform.submit()\"><b>Hide index</b></a><br>";
##    CellLineIndex(\@lines, $org, $data_src);
##  } else {
##    push @lines,
##        "<a href=\"javascript:document.mform.SHOW.value=1;" .
##        "document.mform.submit()\"><b>Show column index</b></a><br>";
##  }

  push @lines, "<br><br>";

  if ($show_index) {
    if($show_index == 1) { 
      push @lines,
        "<center>" .
        "<a href=\"javascript:document.mform.SHOW.value=0;" .
        "document.mform.COLUMNS.value='$columns';" .
        "document.mform.SRC.value='$data_src';" .
        "document.mform.submit()\"><b>Hide index</b></a>" .
        "</center><br>";
    }
  } else {
    push @lines,
        "<center>" .
        "<a href=\"javascript:document.mform.SHOW.value=1;" .
        "document.mform.COLUMNS.value='$columns';" .
        "document.mform.SRC.value='$data_src';" .
        "document.mform.submit()\"><b>Show column index</b></a>" .
        "</center><br>";
  }

######################################################################
## SVG 
######################################################################

  if( $data_src eq "SAGE" and $show_index == 2) {

    my $image_cache_id = createByStatsSVGGraph( $org,
                                                $data_src,
                                                \@accs,
                                                $mean_or_var,
                                                \@vals,
                                                \%acc2cid,
                                                \%acc2sym,
                                                $show_index,
                                                $selected_detail_coln,
                                                \%display_col );

    if ($image_cache_id eq "CACHE_FAILED") {
      return "Cache failed";
    }

    push @lines,
      "<EMBED src=\"Get_Microarray_Image?CACHE=$image_cache_id\" " .
      "NAME=\"SVGEmbed\" " .
      "HEIGHT=\"$SCREEN_HEIGHT\" WIDTH=\"$SCREEN_WIDTH\" " .
      "TYPE=\"image/svg-xml\" " .
      "PLUGINPAGE=\"http://www.adobe.com/svg/viewer/install/\">";
    push @lines,
      "<NOEMBED>You need to install SVG tool: <A HREF=\"javascript:spawn('http://www.adobe.com/svg/viewer/install')\">Install SVG tool</a></NOEMBED>"; 
    push @lines, "</form>";

    $db->disconnect;

    return join("\n", @lines);
  }

######################################################################

  my @maps;
 
  my $image_cache_id = createByStatsGraphWithMap( $org,
                                                  $data_src,
                                                  \@accs,
                                                  $mean_or_var,
                                                  \@vals,
                                                  \%acc2cid,
                                                  \%acc2sym,
                                                  $show_index,
                                                  \@maps,
                                                  $selected_detail_coln,
                                                  \%display_col );
 
  if ($image_cache_id eq "CACHE_FAILED") {
    return "Cache failed";
  }
 
  my @image_cache_ids = split ";", $image_cache_id;
 
  for ( my $i=0; $i<@image_cache_ids; $i++ ) {
    if( $i > 0 ) {
      push @lines, "<form>";
    }
    my $map_name = "CR" . $i;
    push @lines, "<map name=\"$map_name\">\n";
    push @lines, join "", @{$maps[$i]};
    push @lines, "</map>\n";
    push @lines,
       "<image src=\"Get_Microarray_Image?CACHE=$image_cache_ids[$i]\" " .
       "border=0 width=1000 height=1800 " .
       "usemap=\"#$map_name\" alt=\"Microarray_Image\">";
    push @lines, "</form>";
  }

  $db->disconnect;

  return join("\n", @lines);

}


######################################################################
sub FindNeighbors_1 {
  my ($base, $org, $data_source, $accession, $show_index, $col) = @_;

  my $test = Scan ($base, $org, $data_source, $accession, $show_index, $col);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  $BASE = $base;

  my (@pos_accs, @pos_r, @pos_p, @pos_vecs,
      @neg_accs, @neg_r, @neg_p, @neg_vecs,
      @probe_vec);

  InitializeDatabase();
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print STDERR "$DBI::errstr\n";
    die "Error: Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE;
    exit;
  }

  $ma = new MicroArray($db, $CGAP_SCHEMA, $data_source);

  if (not $ma->FindNeighbors($accession, $NEIGHBOR_RVAL,
      $N_NEIGHBORS, \@probe_vec, \@pos_accs, \@pos_r, \@pos_p, \@pos_vecs,
      \@neg_accs, \@neg_r, \@neg_p, \@neg_vecs)) {
    return "No $data_source data for $accession";
  }
  $ma->ReadView([$accession, @pos_accs, @neg_accs]);

  my (@pos_negs, %acc2cid, %acc2sym, @lines);

  push @pos_negs, $accession,
  push @pos_negs, @pos_accs;
  push @pos_negs, @neg_accs;

  my %display_col;

  ## choose col for SAGE
  my @cols = split (",", $col);
  if( $data_source eq "SAGE" or $data_source eq "LONG_SAGE" ) {
    for( my $i=0; $i<@cols; $i++ ) {
      ## my $name = $ma->Num2Cell($cols[$i]);
      my $name = $ma->Num2Group($cols[$i]);
      my @tmp = split /\_/, $name;
      my $tmp_name1 = $tmp[1]; 
      for( my $j=2; $j<@tmp; $j++ ) {
        $tmp_name1 = $tmp_name1 . " " . $tmp[$j]; 
      }  
      for (my $i = 1; $i <= $ma->NumCols(); $i++) { 
        my $tmp_name2 = $ma->Cell2Panel($ma->Num2Cell($i));
        if( $tmp_name1 =~ /$tmp_name2/i ) {
          $display_col{$i} = 1; 
        }
        elsif ( defined $patchForWhiteBloodCells{$tmp_name2} and
                $tmp_name1 =~ /$patchForWhiteBloodCells{$tmp_name2}/i ) {
          $display_col{$i} = 1;
        }
      }  
    }  
  }  

  LookForCIDs($data_source, $org, \@pos_negs, \%acc2cid, \%acc2sym);

  my $str1 = $accession;
  $str1 =~ s/_0$//;
  push @lines, "<br>";
  if( $data_source =~ /SAGE/ ) {
    push @lines, "Tags Correlating with $str1</h3>";
  }
  else {
    push @lines, "Accessions Correlating with $str1</h3>";
  }
  push @lines, "<a href=\"MicroArrayHelp\"><font color=red><b>Help</b></font></a>";
  push @lines, "<br><p>";
  push @lines, ColorScaleIndex();

  push @lines, "<form name=mform action=FNResults method=POST>";
  push @lines, "<input type=hidden name=ACCESSION value=$accession>";
  push @lines, "<input type=hidden name=SHOW>";
  push @lines, "<input type=hidden name=SRC value=$data_source>";
  push @lines, "<input type=hidden name=ORG value=$org>";
  push @lines, "<input type=hidden name=ACCS value=$accession>";
  push @lines, "<input type=hidden name=COLUMN value=$col>";

  for my $a (@pos_accs) {
    push @lines, "<input type=hidden name=ACCS value=$a>";
  }
  for my $a (@neg_accs) {
    push @lines, "<input type=hidden name=ACCS value=$a>";
  }

  push @lines, "<p><b>Column Index</b>";
  my $flag = 1;
  my $tmp; 
  CellLineIndex(\@lines, $org, $data_source, $flag, $tmp, $show_index);

  push @lines, "<br><br>";


  if ($show_index) {
    if($show_index == 1) { 
      push @lines,
        "<center>" .
        "<a href=\"javascript:document.mform.SHOW.value=0;" .
        "document.mform.SRC.value='$data_source';" .
        "document.mform.submit()\"><b>Hide index</b></a>" .
        "</center><br>";
    } 
  } else {
    push @lines,
        "<center>" .
        "<a href=\"javascript:document.mform.SHOW.value=1;" .
        "document.mform.SRC.value='$data_source';" .
        "document.mform.submit()\"><b>Show column index</b></a>" .
        "</center><br>";
  }

######################################################################
## SVG 
######################################################################

  if( ($data_source eq "SAGE" or $data_source eq "LONG_SAGE" ) and $show_index == 2 ) {

    my $image_cache_id = createNeighborsSVGGraph($org,
                                                 $data_source,
                                                 $accession,
                                                 \@pos_accs,
                                                 \@pos_r,
                                                 \@pos_p,
                                                 \@neg_accs,
                                                 \@neg_r,
                                                 \@neg_p,
                                                 \%acc2cid,
                                                 \%acc2sym,
                                                 $show_index,
                                                 \@lines,
                                                 $col,
                                                 \%display_col,
                                                 $BASE);

    if ($image_cache_id eq "CACHE_FAILED") {
      return "Cache failed";
    }

    push @lines,
      "<EMBED src=\"Get_Microarray_Image?CACHE=$image_cache_id\" " .
      "NAME=\"SVGEmbed\" " .
      "HEIGHT=\"$SCREEN_HEIGHT\" WIDTH=\"$SCREEN_WIDTH\" " .
      "TYPE=\"image/svg-xml\" " .
      "PLUGINPAGE=\"http://www.adobe.com/svg/viewer/install/\">";
    push @lines,
      "<NOEMBED>You need to install SVG tool: <A HREF=\"javascript:spawn('http://www.adobe.com/svg/viewer/install')\">Install SVG tool</a></NOEMBED>"; 
    push @lines, "</form>";

    $db->disconnect;

    return join("\n", @lines);
  }
  elsif( $data_source eq "UBC_SAGE" ) { 
  
    my $image_cache_id = createNeighborsSVGGraph($org,
                                                 $data_source,
                                                 $accession,
                                                 \@pos_accs,
                                                 \@pos_r,
                                                 \@pos_p,
                                                 \@neg_accs,
                                                 \@neg_r,
                                                 \@neg_p,
                                                 \%acc2cid,
                                                 \%acc2sym,
                                                 $show_index,
                                                 \@lines,
                                                 $col,
                                                 \%display_col,
                                                 $BASE);
 
    if ($image_cache_id eq "CACHE_FAILED") {
      return "Cache failed";
    }
 
    push @lines,
      "<EMBED src=\"Get_Microarray_Image?CACHE=$image_cache_id\" " .
      "NAME=\"SVGEmbed\" " .
      "HEIGHT=\"$SCREEN_HEIGHT\" WIDTH=\"$SCREEN_WIDTH\" " .
      "TYPE=\"image/svg-xml\" " .
      "PLUGINPAGE=\"http://www.adobe.com/svg/viewer/install/\">";
    push @lines,
      "<NOEMBED>You need to install SVG tool: <A HREF=\"javascript:spawn('http://www.adobe.com/svg/viewer/install')\">Install SVG tool</a></NOEMBED>"; 
    push @lines, "</form>";
 
    $db->disconnect;
 
    return join("\n", @lines);
  }
 
######################################################################
  push @lines, "<map name=\"CR\">\n";

  my $image_cache_id=WriteMCToCache(createNeighborsGraphWithMap($org,
                                                                $data_source,
                                                                $accession,
                                                                \@pos_accs, 
                                                                \@pos_r, 
                                                                \@pos_p, 
                                                                \@neg_accs, 
                                                                \@neg_r, 
                                                                \@neg_p, 
                                                                \%acc2cid,
                                                                \%acc2sym,
                                                                $show_index,
                                                                \@lines,
                                                                $col,
                                                                \%display_col,
                                                                $BASE));
  push @lines, "</map>\n";

  if (! $image_cache_id) {
    return "Cache failed";
  }
 
  push @lines,
       "<image src=\"Get_Microarray_Image?CACHE=$image_cache_id\" " .
       "border=0 width=1000 height=1800 " .
       "usemap=\"#CR\" alt=\"Microarray_Image\">";
 
 
  push @lines, "</form>";
 
  $db->disconnect;

  return join("\n", @lines);
}

######################################################################
sub PivotOnColumn_1 {
  my ($base, $org, $data_source, $acclist, $column, $col, $show_index ) = @_;

  my $test = Scan ($base, $org, $data_source, $acclist, $column, $col, 
                   $show_index );
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  $BASE = $base;

  my (@accs, %acc2cid, %acc2sym);
  my (@pos_cols, @pos_r, @pos_p);
  my (@neg_cols, @neg_r, @neg_p);
  my (@vecs, @lines, $i);

  if ($acclist eq "") {
    return "No genes specified";
  }

  InitializeDatabase();

  ## Retain original order of accessions

  @accs = split (",", $acclist);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print STDERR "$DBI::errstr\n";
    die "Error: Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE;
    exit;
  }

  $ma = new MicroArray($db, $CGAP_SCHEMA, $data_source);

  $ma->Pivot(\@accs, $col,
      $NEIGHBOR_RVAL, $N_NEIGHBORS,
      \@pos_cols, \@pos_r, \@pos_p,
      \@neg_cols, \@neg_r, \@neg_p, \@vecs);

  if (@pos_cols == 0) {
    return "No correlations with column $col can be computed " .
        "(insufficient number of values).<br>\n";
  }

  $ma->ReadView(\@accs);
  
  LookForCIDs($data_source, $org, \@accs, \%acc2cid, \%acc2sym);

  push @lines, ColorScaleIndex();

  push @lines, "<form name=mform action=PivotResults method=POST>";
  for my $accession (@accs) {
    push @lines, "<input type=hidden name=ACCS value=$accession>";
  }
  push @lines, "<input type=hidden name=SHOW>";
  push @lines, "<input type=hidden name=SRC value=$data_source>";
  push @lines, "<input type=hidden name=ORG value=$org>";
  ## push @lines, "<input type=hidden name=COLN>";

  push @lines, "<p><b>Column Index</b>";
  push @lines, "<br>";

  my @cols;
  my $flag = 2; 
  my $tmp;

  CellLineIndex(\@lines, $org, $data_source, $flag, $tmp, $show_index);

  push @lines, "<BR><BR>";



######################################################################
## SVG
######################################################################
  if( ($data_source eq "SAGE" or $data_source eq "LONG_SAGE") and $show_index == 2) {

    my $image_cache_id = createPivotSVGGraph( $org,
                                              $data_source,
                                              \@accs,
                                              \@pos_cols,
                                              \@neg_cols,
                                              $col,
                                              \%acc2cid,
                                              \%acc2sym,
                                              $column );

    if ($image_cache_id eq "CACHE_FAILED") {
      return "Cache failed";
    }

    push @lines, "<form name=mform action=GeneList method=post>";
    push @lines,
      "<EMBED src=\"Get_Microarray_Image?CACHE=$image_cache_id\" " .
      "NAME=\"SVGEmbed\" " .
      "HEIGHT=\"$SCREEN_HEIGHT\" WIDTH=\"$SCREEN_WIDTH\" " .
      "TYPE=\"image/svg-xml\" " .
      "PLUGINPAGE=\"http://www.adobe.com/svg/viewer/install/\">";
    push @lines,
      "<NOEMBED>You need to install SVG tool: <A HREF=\"javascript:spawn('http://www.adobe.com/svg/viewer/install')\">Install SVG tool</a></NOEMBED>"; 
    push @lines, "</form>";

    $db->disconnect;

    return join("\n", @lines);
  }
  elsif( $data_source eq "UBC_SAGE" ) {

    my $image_cache_id = createPivotSVGGraph( $org,
                                              $data_source,
                                              \@accs,
                                              \@pos_cols,
                                              \@neg_cols,
                                              $col,
                                              \%acc2cid,
                                              \%acc2sym,
                                              $column );

    if ($image_cache_id eq "CACHE_FAILED") {
      return "Cache failed";
    }

    push @lines, "<form name=mform action=GeneList method=post>";
    push @lines,
      "<EMBED src=\"Get_Microarray_Image?CACHE=$image_cache_id\" " .
      "NAME=\"SVGEmbed\" " .
      "HEIGHT=\"$SCREEN_HEIGHT\" WIDTH=\"$SCREEN_WIDTH\" " .
      "TYPE=\"image/svg-xml\" " .
      "PLUGINPAGE=\"http://www.adobe.com/svg/viewer/install/\">";
    push @lines,
      "<NOEMBED>You need to install SVG tool: <A HREF=\"javascript:spawn('http://www.adobe.com/svg/viewer/install')\">Install SVG tool</a></NOEMBED>"; 
    push @lines, "</form>";

    $db->disconnect;

    return join("\n", @lines);
  }

        ## "HEIGHT=\"$SVG_IMAGE_HEIGHT\" WIDTH=\"$SVG_IMAGE_WIDTH\" " .
######################################################################






  my @maps;

  my $image_cache_id = createPivotGraphWithMap( $org,
                                                $data_source,
                                                \@accs,
                                                \@pos_cols,
                                                \@neg_cols,
                                                $col,
                                                \%acc2cid,
                                                \%acc2sym,
                                                \@maps,
                                                $column );

  if ($image_cache_id eq "CACHE_FAILED" ) {
    return "Cache failed";
  }

  my @image_cache_ids = split ";", $image_cache_id;

  for ( my $i=0; $i<@image_cache_ids; $i++ ) {
    if( $i > 0 ) {
      push @lines, "<form>";
    }
    my $map_name = "CR" . $i;
    push @lines, "<map name=\"$map_name\">\n";
    push @lines, join "", @{$maps[$i]};
    push @lines, "</map>\n";
    push @lines,
       "<image src=\"Get_Microarray_Image?CACHE=$image_cache_ids[$i]\" " .
       "border=0 width=1000 height=1800 " .
       "usemap=\"#$map_name\" alt=\"Microarray_Image\">";
    push @lines, "</form>";
  }

  $db->disconnect;

  return join("\n", @lines);
}

######################################################################
sub numerically { $a <=> $b; }

######################################################################
sub OrderRandomGenes_1 {
  my ($base, $org, $data_source, $cidlist, $show_index, $col) = @_;

  my $test = Scan ($base, $org, $data_source, $cidlist, $show_index, $col);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  InitializeDatabase();

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  $BASE = $base;

  my %display_col; 

  my (@accs, @ordering, @vecs, %acc2cid, %acc2sym, @lines);
  my (@cids, %cid2acc_set, $a, $cidset);
  my ($acc, $sacc, @simple_accs);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print STDERR "$DBI::errstr\n";
    die "Error: Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE;
    exit;
  }

  ## print STDERR "8888: $data_source";
  $ma = new MicroArray($db, $CGAP_SCHEMA, $data_source);

  ## print STDERR "8888: $cidlist";
  if ($cidlist ne "") {
    @cids = split (",", $cidlist);
    $ma->LookupByCID(\@cids, \%cid2acc_set);
    for my $acc_set (values %cid2acc_set) {
      for $a (@{ $acc_set }) {
        push @accs, $a;
      }
    }
  }
  $ma->ReadView(\@accs);

  ## choose col for SAGE
  my @cols = split (",", $col);
  if( $data_source eq "SAGE" or $data_source eq "LONG_SAGE") {
    for( my $i=0; $i<@cols; $i++ ) {
      my $name = $ma->Num2Group($cols[$i]);
      my @tmp = split /\_/, $name;
      my $tmp_name1 = $tmp[1]; 
      for( my $j=2; $j<@tmp; $j++ ) {   
        $tmp_name1 = $tmp_name1 . " " . $tmp[$j];
      } 
      for (my $i = 1; $i <= $ma->NumCols(); $i++) { 
        my $tmp_name2 = $ma->Cell2Panel($ma->Num2Cell($i));
        if( $tmp_name2 ) {
          if( $tmp_name1 =~ /$tmp_name2/i ) {
            $display_col{$i} = 1; 
          }
          elsif ( defined $patchForWhiteBloodCells{$tmp_name2} and 
            $tmp_name1 =~ /$patchForWhiteBloodCells{$tmp_name2}/i ) {
            $display_col{$i} = 1; 
          }
        }
      }  
    }  
  }  

  ## don't go into OrderSet with a null accession list; it
  ## will pull everything in data source
  if (@accs == 0) {
    return "No expression data found in $data_source data for specified genes\n";
  } elsif (@accs > 500) {
    return "Query would return " . scalar(@accs) . " expression rows<br>\n" .
        "Please restrict queries to fewer than 500 expression rows<br>\n";
  }

  $ma->OrderSet(\@accs, \@ordering, \@vecs);
  
  for $acc (@ordering) {
    $sacc = $acc;
    $sacc =~ s/_\d+$//;
    push @simple_accs, $sacc;
  }

  LookForCIDs($data_source, $org, \@ordering, \%acc2cid, \%acc2sym);

  push @lines, ColorScaleIndex();

  push @lines, "<form name=mform action=GeneList method=post>";

  for (split(",", $cidlist)) {
    push @lines, "<input type=hidden name=CIDS value=$_>";
  }
  push @lines, "<input type=hidden name=SHOW>";
  push @lines, "<input type=hidden name=SRC value=$data_source>";
  push @lines, "<input type=hidden name=ORG value=$org>";
  ## push @lines, "<input type=hidden name='COLN'>";
  if( $data_source eq "SAGE" or $data_source eq "UBC_SAGE" 
      or $data_source eq "LONG_SAGE" ) {
    push @lines, "<input type=hidden name=COLUMN value=$col>";
  }
  ## else {
  ##   push @lines, "<input type=hidden name=COLUMN>";
  ## }

  for $a (@ordering) {
    push @lines, "<input type=hidden name=ACCS value=$a>";
  }

  push @lines, "<p><b>Column Index</b>";
  my $flag = 0;
  my $tmp;

  if ($ma->IsUBCSAGE()) {
    $show_index = 2;
  }

  CellLineIndex(\@lines, $org, $data_source, $flag, $tmp, $show_index);

  push @lines, "<br><br>";

  if ($show_index) {
    if($show_index == 1) { 
      push @lines,
        "<center>" .
        "<a href=\"javascript:document.mform.SHOW.value=0;" .
        "document.mform.SRC.value='$data_source';" .
        "document.mform.submit()\"><b>Hide index</b></a>" .
        "</center><br>";
    }
  } else {
    push @lines,
        "<center>" .
        "<a href=\"javascript:document.mform.SHOW.value=1;" .
        "document.mform.SRC.value='$data_source';" .
        "document.mform.submit()\"><b>Show column index</b></a>" .
        "</center><br>";
  }

######################################################################
## SVG 
######################################################################
  my $accession_list = join ",", @ordering;

  if( ($data_source eq "SAGE" or $data_source eq "LONG_SAGE" ) and $show_index == 2) {
    my $image_cache_id = createSVGGraph( $org,
                                         $data_source,
                                         \@ordering,
                                         \%acc2cid,
                                         \%acc2sym,
                                         $show_index,
                                         $col,
                                         \%display_col,
                                         $accession_list );

    if ($image_cache_id eq "CACHE_FAILED") {
      return "Cache failed";
    }

    ## my @image_cache_ids = split ";", $image_cache_id;

    ## for ( my $i=0; $i<@image_cache_ids; $i++ ) {
    ##   if( $i > 0 ) {
      push @lines, "<form name=mform action=GeneList method=post>";
    ##   }
      push @lines,
        "<EMBED src=\"Get_Microarray_Image?CACHE=$image_cache_id\" " .
        "NAME=\"SVGEmbed\" " .
        "HEIGHT=\"$SCREEN_HEIGHT\" WIDTH=\"$SCREEN_WIDTH\" " .
        "TYPE=\"image/svg-xml\" " .
        "PLUGINPAGE=\"http://www.adobe.com/svg/viewer/install/\">";
    push @lines,
      "<NOEMBED>You need to install SVG tool: <A HREF=\"javascript:spawn('http://www.adobe.com/svg/viewer/install')\">Install SVG tool</a></NOEMBED>"; 
      push @lines, "</form>";
    ## }

    $db->disconnect;

    return join("\n", @lines);
  }
  elsif( $data_source eq "UBC_SAGE") {
    my $image_cache_id = createSVGGraph( $org,
                                         $data_source,
                                         \@ordering,
                                         \%acc2cid,
                                         \%acc2sym,
                                         $show_index,
                                         $col,
                                         \%display_col,
                                         $accession_list );
 
    if ($image_cache_id eq "CACHE_FAILED") {
      return "Cache failed";
    }
 
    ## my @image_cache_ids = split ";", $image_cache_id;
 
    ## for ( my $i=0; $i<@image_cache_ids; $i++ ) {
    ##   if( $i > 0 ) {
      push @lines, "<form name=mform action=GeneList method=post>";
    ##   }
      push @lines,
        "<EMBED src=\"Get_Microarray_Image?CACHE=$image_cache_id\" " .
        "NAME=\"SVGEmbed\" " .
        "HEIGHT=\"$SCREEN_HEIGHT\" WIDTH=\"$SCREEN_WIDTH\" " .
        "TYPE=\"image/svg-xml\" " .
        "PLUGINPAGE=\"http://www.adobe.com/svg/viewer/install/\">";
    push @lines,
      "<NOEMBED>You need to install SVG tool: <A HREF=\"javascript:spawn('http://www.adobe.com/svg/viewer/install')\">Install SVG tool</a></NOEMBED>"; 
      push @lines, "</form>";
    ## }
 
    $db->disconnect;
 
    return join("\n", @lines);
  }

        ## "HEIGHT=\"$SVG_IMAGE_HEIGHT\" WIDTH=\"$SVG_IMAGE_WIDTH\" " .
######################################################################
  my @maps;
  my $image_cache_id = createGraphWithMap( $org, 
                                           $data_source, 
                                           \@ordering, 
                                           \%acc2cid,
                                           \%acc2sym, 
                                           $show_index, 
                                           \@maps,
                                           $col,
                                           \%display_col );

  if ($image_cache_id eq "CACHE_FAILED") {
    return "Cache failed";
  }
  my @image_cache_ids = split ";", $image_cache_id;

  for ( my $i=0; $i<@image_cache_ids; $i++ ) {
    if( $i > 0 ) {
      push @lines, "<form>";
    }
    my $map_name = "CR" . $i;
    push @lines, "<map name=\"$map_name\">\n";
    push @lines, join "", @{$maps[$i]}; 
    push @lines, "</map>\n";
    push @lines,
       "<image src=\"Get_Microarray_Image?CACHE=$image_cache_ids[$i]\" " .
       "border=0 width=1000 height=1800 " .
       "usemap=\"#$map_name\" alt=\"Microarray_Image\">";
    push @lines, "</form>";
  }

  $db->disconnect;

  return join("\n", @lines);

}

######################################################################
sub createGraphWithMap {
  my ($org, $data_source, $accession, $acc2cid_ref,
      $acc2sym_ref, $show_index, $lines_ref, $col, $display_col) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my @image_cache_id;
 
  my (@accs, @ordering, @vecs, %acc2cid, %acc2sym, @lines);
  my (@cids, %cid2acc_set, $a, $cidset);

  @ordering = @$accession;
  %acc2cid = %$acc2cid_ref;
  %acc2sym = %$acc2sym_ref;

  ## my $maps;

  my $needMorePage = NO;

  my $start = 0;

  for ( my $nu = 0; $nu < 15; $nu++ ) {
    if( $needMorePage == YES ) {
      $needMorePage = NO;
    }

    my $maps;

    my $im = new GD::Image($IMAGE_WIDTH,$IMAGE_HEIGHT);

    my %scale2color;
    my ($white, $black, $red, $blue, $green, $yellow);
    InitializeColor(\$im, \%scale2color, \$white, \$black, 
                    \$red, \$blue, \$green, \$yellow);
    $im->filledRectangle( 0, 0, $IMAGE_WIDTH, $IMAGE_HEIGHT, $white );
    ## Panel:
    if( $show_index and $nu == 0 ) {
      my $x1 = $LEFT2+55+25+5-15-10-2;
      if( $data_source eq "LONG_SAGE" or $data_source eq "LONG_SAGE_SUMMARY" ) {
        $x1 = $x1 + $LONG_SAGE;
      }
      $maps = $maps . Panel(\$im, $data_source, $x1, $display_col, $col );
    }
    if( $nu == 0 ) {
      ## title:
      my @title;
      push @title, "Gene"; 
      push @title, (($data_source eq "SAGE" or $data_source eq "SAGE_SUMMARY" or $data_source eq "LONG_SAGE" or $data_source eq "LONG_SAGE_SUMMARY") ? "TAG" : "ACC"); ## SAGE_SUMMARY ## same as SAGE 

      my @position;
      push @position, $LEFT1;
      push @position, $LEFT2;
      drawTitle( 2, \$im, $show_index, $data_source, 
                    \@position, \@title, $black );
    }
  
    ## lines:
    my $x1; 
    my $y1;
    my $x2; 
    my $y2; 
    my $x11=$LEFT1; 
    my $x12=$LEFT2; 
    if( $nu == 0 ) {
      if( $show_index ) {
        if( $data_source eq "NCI60_STANFORD" ) {
          $y1 = 95;
        }
        elsif ( $data_source eq "SAGE_SUMMARY" or $data_source eq "LONG_SAGE_SUMMARY" ) {
          $y1 = 250;
        }
        elsif( $data_source eq "NCI60_NOVARTIS" ) {
          $y1 = 95;
        }
        elsif( $data_source eq "NCI60_U133"  or  $data_source eq "NCI60_U95") {
          $y1 = 95;
        }
        elsif ( $data_source eq "LONG_SAGE" ) {
          $y1 = 455; 
        }
        else {
          ## $y1 = 310;
          $y1 = 385;
        }
      }
      else {
        $y1 = 30;
      }
    }
    else {
      $y1 = 0;
    }
    $x1 = $LEFT2+55+25+5-15; ## graph start
    if( $data_source eq "LONG_SAGE" or $data_source eq "LONG_SAGE_SUMMARY") {
      $x1 = $x1 + $LONG_SAGE;
    }
    for (my $i = $start; $i < @ordering; $i++) {

      if( $y1 + 15 > $IMAGE_HEIGHT ) {
        $start = $i;
        $needMorePage = YES;
        last;
      }
      else {
        $maps = $maps . lineForGraphWithMap ( 1, $org, $data_source, 
                                              $ordering[$i], \%acc2cid, 
                                              \%acc2sym, $show_index, 
                                              $x1, $y1, \$im, \%scale2color, 
                                              $blue, $black, "", "", "","",
                                              $col, $display_col );
      }
 
      $y1 = $y1+15;
  
    }
  
    push @{$$lines_ref[$nu]}, $maps . "\n";
  
    my $id;
    ## my $id = WriteMCToCache( $im->jpeg(100) );
    if( GD->require_version() > 1.19 ) {
      $id = WriteMCToCache( $im->png );
    } 
    else {
      $id = WriteMCToCache( $im->gif );
    }

    if (!$id) {
      return "CACHE_FAILED";
    }
    else {
      push  @image_cache_id, $id;
    }

    if ( $needMorePage == NO ) {
      last;
    } 

  }
  return join ";", @image_cache_id;
} 

######################################################################
sub createSVGGraph {

  my ($org, $data_source, $accession, $acc2cid_ref,
      $acc2sym_ref, $show_index, $col, $display_col, $accession_list) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my @image_cache_id;
 
  my (@accs, @ordering, @vecs, %acc2cid, %acc2sym, @lines);
  my (@cids, %cid2acc_set, $a, $cidset);

  @ordering = @$accession;
  %acc2cid = %$acc2cid_ref;
  %acc2sym = %$acc2sym_ref;

  my $start = 0;

  my $svg = SVG->new(width=>$SVG_IMAGE_WIDTH,height=>$SVG_IMAGE_HEIGHT);

  my %scale2color;
  my ($white, $black, $red, $blue, $green, $yellow);

  InitializeSVGColor(\%scale2color, \$white, \$black, 
                     \$red, \$blue, \$green, \$yellow);

  ## Panel:

  my $x1 = $LEFT2_SVG+55+25+5-15-10-2;
  if( $data_source eq "UBC_SAGE" or $data_source eq "LONG_SAGE" ) {
    $x1 = $x1 + $UBC_SAGE_SVG;
  }
  Panel_SVG(\$svg, $data_source, $x1, $display_col, $col, $accession_list);

  ## title:
  my @title;
  push @title, "Gene"; 
  push @title, (($data_source eq "SAGE" or $data_source eq "UBC_SAGE" or $data_source eq "LONG_SAGE") ? "TAG" : "ACC"); ## SAGE_SUMMARY is
                                                           ## same as SAGE

  my @position;
  push @position, $LEFT1;
  push @position, $LEFT2_SVG;

  drawTitle_SVG( 2, \$svg, $show_index, $data_source, 
                    \@position, \@title, $black );

  ## lines:
  my $x1; 
  my $y1;
  my $x2; 
  my $y2; 
  my $x11=$LEFT1; 
  my $x12=$LEFT2; 
  if( $show_index ) {
    if( $data_source eq "NCI60_STANFORD" ) {
      $y1 = 95;
    }
    elsif ( $data_source eq "SAGE_SUMMARY" ) {
      $y1 = 250;
    }
    elsif( $data_source eq "NCI60_NOVARTIS" ) {
      $y1 = 95;
    }
    elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
      $y1 = 95;
    }
    elsif( $data_source eq "UBC_STAGE" ) {
      $y1 = 200;
    }
    else {
      ## $y1 = 310;
      $y1 = 385;
    }
  }
  else {
    $y1 = 30;
  }

  $x1 = $LEFT2_SVG+55+25+5-15; ## graph start
  if( $data_source eq "UBC_SAGE" or $data_source eq "LONG_SAGE" ) {
    $x1 = $x1 + $UBC_SAGE_SVG;
  }

  defineRect_SVG(\$svg, \%scale2color); 

  for (my $i = $start; $i < @ordering; $i++) {

    lineForGraph_SVG ( 1, $org, $data_source, 
                       $ordering[$i], \%acc2cid, 
                       \%acc2sym, $show_index, 
                       $x1, $y1, \$svg, \%scale2color, 
                       $blue, $black, "", "", "","",
                       $col, $display_col );
 
    $y1 = $y1+15;

  }

  my $out = $svg->xmlify;
  my $id = WriteMCToCache( $out );

  if (!$id) {
    return "CACHE_FAILED";
  }

  return $id;

} 

######################################################################
sub createPivotGraphWithMap {
  my ($org, $data_source, $accs_ref, $pos_cols_ref, $neg_cols_ref, $column,
      $acc2cid_ref, $acc2sym_ref, $lines_ref, $col) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my @image_cache_id;

  my (@accs, %acc2cid, %acc2sym);
  my (@pos_cols, @pos_r, @pos_p);
  my (@neg_cols, @neg_r, @neg_p);
  my (@vecs, @lines, $i);

  @accs = @$accs_ref;
  @pos_cols = @$pos_cols_ref;
  @neg_cols = @$neg_cols_ref;
  %acc2cid = %$acc2cid_ref;
  %acc2sym = %$acc2sym_ref;

  my $needMorePage = NO; 
 
  my $start = 0; 

  for ( my $nu = 0; $nu < 15; $nu++ ) {
    if( $needMorePage == YES ) {
      $needMorePage = NO;   
    }

    my $maps;
  
    my $im = new GD::Image($IMAGE_WIDTH,$IMAGE_HEIGHT);
  
    my %scale2color;
    my ($white, $black, $red, $blue, $green, $yellow);

    InitializeColor(\$im, \%scale2color, \$white, \$black,
                    \$red, \$blue, \$green, \$yellow);

    $im->filledRectangle( 0, 0, $IMAGE_WIDTH, $IMAGE_HEIGHT, $white );
  
    my $x1;
    my $y1;
    my $x2;
    my $y2;
  
    my $bio_src = $data_src2bio_src{$data_source};
    my $cell_cols = $ma->NumCols();
  
    ## my $pos_start = $LEFT2+55+25+5-15-2+25;
    my $pos_start = $LEFT2+95-2;
    my $neg_start = $pos_start+155;

    if( $data_source eq "LONG_SAGE" or $data_source eq "LONG_SAGE_SUMMARY" ) {
      $pos_start = $pos_start + $LONG_SAGE;
      $neg_start = $neg_start + $LONG_SAGE;
    }

    if( $nu == 0 ) {
      ## Panel:
      ## $x1 = $LEFT2+55+25+5-15-2;
      $x1 = $LEFT2+70-2;
      if( $data_source eq "NCI60_STANFORD" ) {
        $y1 = 110;
      }
      elsif ( $data_source eq "SAGE_SUMMARY" or $data_source eq "LONG_SAGE_SUMMARY" ) {
        $y1 = 265;
      }
      elsif ( $data_source eq "LONG_SAGE" ) {
        $y1 = 445;
      }
      elsif( $data_source eq "NCI60_NOVARTIS" ) {
        $y1 = 110;
      }
      elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95" ) {
        $y1 = 110;
      }
      else {
        ## $y1 = 325;
        $y1 = 400;
      }
    
      ## The Col:  
      if( $data_source eq "LONG_SAGE" or $data_source eq "LONG_SAGE_SUMMARY" ) {
        $x1 = $x1 + $LONG_SAGE;
      }
      my $tmp_str = $ma->Num2Cell($column);
      $im->stringUp(gdSmallFont, $x1, $y1, $tmp_str, $black);

      $x1 = $x1 + 10;
    
      ## pos ones:
      $x1 = $pos_start-2 ;
      for my $i (@pos_cols) {
        my $tmp_str = $ma->Num2Cell($i+1);
        $im->stringUp(gdSmallFont, $x1, $y1, $tmp_str, $black);
        $x1 = $x1 + 10;
      } 
    
      ## neg ones:
      if( @pos_cols <= 10 ) {
        ## consider the length of title Positive Correlations 
        $x1 = $neg_start-2; 
      }
      else {
        ## using previous x1 from pos
        $x1 = $x1+20-2;  
        $neg_start = $x1+2;
      }
      for my $i (@neg_cols) {
        my $tmp_str = $ma->Num2Cell($i+1);
        $im->stringUp(gdSmallFont, $x1, $y1, $tmp_str, $black);
        $x1 = $x1 + 10;
      }
    
      ## Title:
      my $str1 = "Gene";
      my $str2;
      if( $data_source eq "SAGE" or $data_source eq "SAGE_SUMMARY" ) {
        $str2 = "TAG";
      }
      elsif( $data_source eq "LONG_SAGE" or $data_source eq "LONG_SAGE_SUMMARY" ) {
        $str2 = "TAG";
      }
      else {
        $str2 = "Accession";
      }
      my $str3 = "Positive Correlations";
      my $str4 = "Negative Correlations";
      $x1 = $LEFT1;
      $y1 = 1;
      $im->string(gdMediumBoldFont, $x1, $y1, $str1, $black);
      $x1 = $LEFT2;
      $im->string(gdMediumBoldFont, $x1, $y1, $str2, $black);
      $x1 = $pos_start;
      $im->string(gdMediumBoldFont, $x1, $y1, $str3, $black);
      $x1 = $neg_start;
      $im->string(gdMediumBoldFont, $x1, $y1, $str4, $black);
    }
  
    if( $nu == 0 ) {
      if( $data_source eq "NCI60_STANFORD" ) {
        $y1 = 115;
      }
      elsif ( $data_source eq "SAGE_SUMMARY" or $data_source eq "LONG_SAGE_SUMMARY" ) {
        $y1 = 270;
      }
      elsif ( $data_source eq "LONG_SAGE" ) {
        $y1 = 450;
      }
      elsif( $data_source eq "NCI60_NOVARTIS" ) {
        $y1 = 115;
      }
      elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
        $y1 = 115;
      }
      else {
        ## $y1 = 330;
        $y1 = 405;
      }
    }
    else{
        $y1 = 1;
    }
  
    for (my $i = $start; $i < @accs; $i++) {


      if( $y1 + 15 > $IMAGE_HEIGHT ) {
        $start = $i;
        $needMorePage = YES;
        last;
      }
      else {
        my $show_index = 1;
        $maps = $maps . lineForGraphWithMap ( 4, $org, $data_source,
                                              $accs[$i], \%acc2cid,
                                              \%acc2sym, $show_index,
                                              $x1, $y1, \$im, \%scale2color,
                                              $blue, $black, "",
                                              "", "","", $col );
      }

      my @temp;
      ## $x1 = $LEFT2+55+25+5-15;
      $x1 = $LEFT2+70;
  
      my $str1 = $accs[$i];
      if ($ma->ColorTheVector($str1,
                                    \@microarray_color_scale, \@temp)) {
        
        $y2 = $y1+$CELL_HEIGHT;
  
        ## The col:
        my $x = $temp[$column-1];
        if( $data_source eq "LONG_SAGE" or $data_source eq "LONG_SAGE_SUMMARY" ) {
          $x1 = $x1 + $LONG_SAGE;
        }
        my $color = $scale2color{$x};
        $x2 = $x1+$CELL_WIDTH;
        $im->filledRectangle( $x1, $y1, $x2, $y2, $color );
     
        ## pos ones:
        $x1 = $pos_start;
        for my $x (@pos_cols) {
          my $xx = $temp[$x];
          my $color = $scale2color{$xx};
          $x2 = $x1+$CELL_WIDTH;
          $im->filledRectangle( $x1, $y1, $x2, $y2, $color );
          $x1 = $x2;
        }
   
        ## neg ones:
        $x1 = $neg_start;
        for my $x (@neg_cols) {
          my $xx = $temp[$x];
          my $color = $scale2color{$xx};
          $x2 = $x1+$CELL_WIDTH;
          $im->filledRectangle( $x1, $y1, $x2, $y2, $color );
          $x1 = $x2;
        }
      }
   
      $y1 = $y2;
   
    }
  
    ## push @$lines_ref, $maps;
    push @{$$lines_ref[$nu]}, $maps . "\n";
  
    my $id;
    ## my $id = WriteMCToCache( $im->jpeg(100) );
    if( GD->require_version() > 1.19 ) {
      $id = WriteMCToCache( $im->png );
    }
    else {
      $id = WriteMCToCache( $im->gif );
    }
  
    if (!$id) {
      return "CACHE_FAILED";
    }
    else {
      push  @image_cache_id, $id;
    }

    if ( $needMorePage == NO ) {
      last;
    }

  } 

  return join ";", @image_cache_id;
} 

######################################################################

######################################################################
sub createPivotSVGGraph {
  my ($org, $data_source, $accs_ref, $pos_cols_ref, $neg_cols_ref, $column,
      $acc2cid_ref, $acc2sym_ref, $col) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my @image_cache_id;

  my (@accs, %acc2cid, %acc2sym);
  my (@pos_cols, @pos_r, @pos_p);
  my (@neg_cols, @neg_r, @neg_p);
  my (@vecs, @lines, $i);

  @accs = @$accs_ref;
  @pos_cols = @$pos_cols_ref;
  @neg_cols = @$neg_cols_ref;
  %acc2cid = %$acc2cid_ref;
  %acc2sym = %$acc2sym_ref;

  my $start = 0; 

  my $svg = SVG->new(width=>$SVG_IMAGE_WIDTH,height=>$SVG_IMAGE_HEIGHT);

  my %scale2color;
  my ($white, $black, $red, $blue, $green, $yellow);

  InitializeSVGColor(\%scale2color, \$white, \$black,
                     \$red, \$blue, \$green, \$yellow);

  my $x1;
  my $y1;
  my $x2;
  my $y2;

  my $bio_src = $data_src2bio_src{$data_source};
  my $cell_cols = $ma->NumCols();

  ## my $pos_start = $LEFT2+55+25+5-15-2+25;
  my $pos_start = $LEFT2_SVG+95-2;
  $pos_start = $pos_start + 30;
  if( $data_source eq "UBC_SAGE" or $data_source eq "LONG_SAGE" ) {
    $pos_start = $pos_start + $UBC_SAGE_SVG;
  }
  my $neg_start = $pos_start+155;

  ## Panel:
  ## $x1 = $LEFT2+55+25+5-15-2;
  $x1 = $LEFT2_SVG+70;
  $x1 = $x1+30; ## for SVG
  if( $data_source eq "NCI60_STANFORD" ) {
    $y1 = 110;
  }
  elsif ( $data_source eq "SAGE_SUMMARY" or $data_source eq "LONG_SAGE_SUMMARY" ) {
    $y1 = 265;
  }
  elsif( $data_source eq "NCI60_NOVARTIS" ) {
    $y1 = 110;
  }
  elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
    $y1 = 110;
  }
  else {
    ## $y1 = 325;
    $y1 = 400;
  }


  ## The Col:  
  my $tmp_str = $ma->Num2Cell($column);
  ## $im->stringUp(gdSmallFont, $x1, $y1, $tmp_str, $black);
  if( $data_source eq "UBC_SAGE" or $data_source eq "LONG_SAGE" ) {
    $x1 = $x1 + $UBC_SAGE_SVG;
  }
  my $x_tr = $x1 - $y1;
  my $y_tr = $x1 + $y1;
  $svg->text(x=>$x1,y=>$y1,style=>{'font-size'=>11,'fill'=>'black'},'transform'=>"translate($x_tr, $y_tr)rotate(-90)")->cdata($tmp_str);

  $x1 = $x1 + 10;

  ## pos ones:
  ## $x1 = $pos_start-2 ;
  $x1 = $pos_start ;
  $x1 = $x1+10;
  for my $i (@pos_cols) {
    my $tmp_str = $ma->Num2Cell($i+1);
    ## $im->stringUp(gdSmallFont, $x1, $y1, $tmp_str, $black);
    my $x_tr = $x1 - $y1;
    my $y_tr = $x1 + $y1;
    $svg->text(x=>$x1,y=>$y1,style=>{'font-size'=>11,'fill'=>'black'},'transform'=>"translate($x_tr, $y_tr)rotate(-90)")->cdata($tmp_str);
    $x1 = $x1 + 10;
  } 

  ## neg ones:
  if( @pos_cols <= 10 ) {
    ## consider the length of title Positive Correlations 
    ## $x1 = $neg_start-2; 
    $x1 = $neg_start+10; 
  }
  else {
    ## using previous x1 from pos
    $x1 = $x1+40;  
    $neg_start = $x1;
    $x1 = $x1 + 10;
  }
  for my $i (@neg_cols) {
    my $tmp_str = $ma->Num2Cell($i+1);
    ## $im->stringUp(gdSmallFont, $x1, $y1, $tmp_str, $black);
    my $x_tr = $x1 - $y1;
    my $y_tr = $x1 + $y1;
    $svg->text(x=>$x1,y=>$y1,style=>{'font-size'=>11,'fill'=>'black'},'transform'=>"translate($x_tr, $y_tr)rotate(-90)")->cdata($tmp_str);
    $x1 = $x1 + 10;
  }

  ## Title:
  my $str1 = "Gene";
  my $str2;
  if( $data_source eq "SAGE" ) {
    $str2 = "TAG";
  }
  elsif( $data_source eq "UBC_SAGE" ) {
    $str2 = "TAG";
  }
  else {
    $str2 = "Accession";
  }
  my $str3 = "Positive Correlations";
  my $str4 = "Negative Correlations";
  $x1 = $LEFT1;
  $y1 = 1;
  $y1 = $y1+15; ## for SVG
  ## $im->string(gdMediumBoldFont, $x1, $y1, $str1, $black);
  $svg->text(x=>$x1,y=>$y1,style=>{'font-size'=>12, 'font-weight'=>'bold', 'fill'=>'black'},)->cdata($str1);
  $x1 = $LEFT2_SVG;
  ## $im->string(gdMediumBoldFont, $x1, $y1, $str2, $black);
  $svg->text(x=>$x1,y=>$y1,style=>{'font-size'=>12, 'font-weight'=>'bold', 'fill'=>'black'},)->cdata($str2);
  $x1 = $pos_start;
  ## $im->string(gdMediumBoldFont, $x1, $y1, $str3, $black);
  $svg->text(x=>$x1,y=>$y1,style=>{'font-size'=>12, 'font-weight'=>'bold', 'fill'=>'black'},)->cdata($str3);
  $x1 = $neg_start;
  ## $im->string(gdMediumBoldFont, $x1, $y1, $str4, $black);
  $svg->text(x=>$x1,y=>$y1,style=>{'font-size'=>12, 'font-weight'=>'bold', 'fill'=>'black'},)->cdata($str4);

  if( $data_source eq "NCI60_STANFORD" ) {
    $y1 = 115;
  }
  elsif ( $data_source eq "SAGE_SUMMARY" or $data_source eq "LONG_SAGE_SUMMARY" ) {
    $y1 = 270;
  }
  elsif( $data_source eq "NCI60_NOVARTIS" ) {
    $y1 = 115;
  }
  elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
    $y1 = 115;
  }
  else {
    ## $y1 = 330;
    $y1 = 405;
  }

  defineRect_SVG(\$svg, \%scale2color);

  for (my $i = $start; $i < @accs; $i++) {

    my $show_index = 2;
    lineForGraph_SVG ( 4, $org, $data_source,
                       $accs[$i], \%acc2cid,
                       \%acc2sym, $show_index,
                       $x1, $y1, \$svg, \%scale2color,
                       $blue, $black, "",
                       "", "","", $col );

    my @temp;
    ## $x1 = $LEFT2+55+25+5-15;
    $x1 = $LEFT2_SVG+70;
    $x1 = $x1+20;
    if( $data_source eq "UBC_SAGE" or $data_source eq "LONG_SAGE" ) {
      $x1 = $x1 + $UBC_SAGE_SVG;
    }

    my $str1 = $accs[$i];
    if ($ma->ColorTheVector($str1,
                                  \@microarray_color_scale, \@temp)) {
      
      $y2 = $y1+$CELL_HEIGHT;

      ## The col:
      my $x = $temp[$column-1];
      ## my $color = $scale2color{$x};
      $x2 = $x1+$CELL_WIDTH;
      ## $im->filledRectangle( $x1, $y1, $x2, $y2, $color );
      my $id = $color2id{$x};
      $svg->use(x=>$x1,y=>$y1, '-href'=>"#$id");

   
      ## pos ones:
      $x1 = $pos_start;
      for my $x (@pos_cols) {
        my $xx = $temp[$x];
        ## my $color = $scale2color{$xx};
        $x2 = $x1+$CELL_WIDTH;
        ## $im->filledRectangle( $x1, $y1, $x2, $y2, $color );
        my $id = $color2id{$xx};
        $svg->use(x=>$x1,y=>$y1, '-href'=>"#$id");
        $x1 = $x2;
      }
 
      ## neg ones:
      $x1 = $neg_start;
      for my $x (@neg_cols) {
        my $xx = $temp[$x];
        ## my $color = $scale2color{$xx};
        $x2 = $x1+$CELL_WIDTH;
        ## $im->filledRectangle( $x1, $y1, $x2, $y2, $color );
        my $id = $color2id{$xx};
        $svg->use(x=>$x1,y=>$y1, '-href'=>"#$id");
        $x1 = $x2;
      }
    }
 
    $y1 = $y2;
 
  }

  my $out = $svg->xmlify;
  my $id = WriteMCToCache( $out );

  if (!$id) {
    return "CACHE_FAILED";
  }

  return $id;

} 



######################################################################
sub createNeighborsSVGGraph {
  my ($org, $data_source, $accession, $pos_accs_ref, $pos_r_ref, 
            $pos_p_ref, $neg_accs_ref, $neg_r_ref, $neg_p_ref, 
            $acc2cid_ref, $acc2sym_ref, $show_index, $lines_ref, $col,
            $display_col, $BASE) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my (@pos_accs, @pos_r, @pos_p, @pos_vecs,
      @neg_accs, @neg_r, @neg_p, @neg_vecs,
      @probe_vec);

  my (@pos_negs, %acc2cid, %acc2sym, @lines);
  my (@all_accs);

  @pos_accs = @$pos_accs_ref;
  @pos_r = @$pos_r_ref;
  @pos_p = @$pos_p_ref;
  @neg_accs = @$neg_accs_ref;
  @neg_r = @$neg_r_ref;
  @neg_p = @$neg_p_ref;
  %acc2cid = %$acc2cid_ref;
  %acc2sym = %$acc2sym_ref;

  my $svg = SVG->new(width=>$SVG_IMAGE_WIDTH,height=>$SVG_IMAGE_HEIGHT);

  my %scale2color;
  my ($white, $black, $red, $blue, $green, $yellow);

  InitializeSVGColor(\%scale2color, \$white, \$black,
                     \$red, \$blue, \$green, \$yellow);


  ## hiperlink for R
  my $pos_cids;
  my $acc1 = $accession;
  $acc1 =~ s/_\d+$//;
  if (not defined $acc2cid{$acc1}) {
  } elsif ($acc2cid{$acc1}) {
    $pos_cids = $org . "." . $acc2cid{$acc1};
  } else {
     $pos_cids = "$org." . join(",$org.", @{ $acc2cid{$acc1} });
  }

  for ( my $i=0; $i<@pos_accs; $i++ ) {
    my $acc1 = $pos_accs[$i];
    $acc1 =~ s/_\d+$//;
    if (not defined $acc2cid{$acc1}) { 
    } elsif ($acc2cid{$acc1}) {
      $pos_cids = $pos_cids . "," . $org . "." . $acc2cid{$acc1};
    } else {
      $pos_cids = $pos_cids . "," . "$org." . join(",$org.", @{ $acc2cid{$acc1} }); 
    }
  }
  my $neg_cids;
  for ( my $i=0; $i<@neg_accs; $i++ ) {
    my $acc1 = $neg_accs[$i];
    $acc1 =~ s/_\d+$//;
    if (not defined $acc2cid{$acc1}) {
    } elsif ($acc2cid{$acc1}) {
      $neg_cids = $neg_cids . "," . $org . "." . $acc2cid{$acc1};
    } else {
      $neg_cids = $neg_cids . "," . "$org." . join(",$org.", @{ $acc2cid{$acc1} });
    }
  }

  drawHiperLinkForR_SVG( $BASE, \$svg, $blue, $show_index, $data_source,
                         $org, $pos_cids, $neg_cids );



  ## title:
  my @title;
  push @title, "Gene";
  push @title, ($data_source eq "SAGE" or $data_source eq "UBC_SAGE" or $data_source eq "LONG_SAGE" ? "TAG" : "ACC");
  push @title, "R";
  push @title, "P<=";

  my @position;
  my $x11;
  if( $data_source eq "SAGE" or $data_source eq "SAGE_SUMMARY") {
    $x11 = $LEFT2_SVG+90;
  }
  elsif( $data_source eq "UBC_SAGE" or $data_source eq "LONG_SAGE") {
    $x11 = $LEFT2_SVG+90+$UBC_SAGE_SVG;
  }
  elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
    $x11 = $LEFT2+80;
  }
  else {
    $x11 = $LEFT2+60;
  }
  my $x12 = $x11+35;
  push @position, $LEFT1;
  push @position, $LEFT2_SVG;
  push @position, $x11;
  push @position, $x12;

  drawTitle_SVG( 4, \$svg, $show_index, $data_source,
                    \@position, \@title, $black );

  ## lines:
  my $x1;
  my $y1;
  my $x2;
  my $y2;
  if( $show_index ) {
    if( $data_source eq "NCI60_STANFORD" ) {
      $y1 = 95;
    }
    elsif ( $data_source eq "SAGE_SUMMARY" ) {
      $y1 = 250; 
    }
    elsif( $data_source eq "NCI60_NOVARTIS" ) {
      $y1 = 95;
    }
    elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
      $y1 = 95;
    }
    else {
      ## $y1 = 310; 
      $y1 = 385; 
    }
  }  
  else { 
    $y1 = 30;
  }

  defineRect_SVG(\$svg, \%scale2color);

  ## The one:
  $x1 = $x12+50;
  lineForGraph_SVG ( 3, $org, $data_source,
                     $accession, \%acc2cid,
                     \%acc2sym, $show_index,
                     $x1, $y1, \$svg, \%scale2color,
                     $blue, $black, $x11,
                     "1", $x12, "0", $col, $display_col );

  push @all_accs, $accession; 

  ## pos ones:
  $y1 = $y1+$CELL_HEIGHT+2;
  my $pos_str = "Positive Correlations";
  ## $im->string(gdSmallFont, $x12, $y1, $pos_str, $black);
  my $y_SVG = $y1 + 10;
  $svg->text(x=>$x12,y=>$y_SVG,style=>{'font-size'=>12,'fill'=>$black})->cdata($pos_str);

  $y1 = $y1+15+2;
  for (my $i = 0; $i < @pos_accs; $i++) {
    
    lineForGraph_SVG ( 3, $org, $data_source,
                       $pos_accs[$i], \%acc2cid,
                       \%acc2sym, $show_index,
                       $x1, $y1, \$svg, \%scale2color,
                       $blue, $black, $x11,
                       $pos_r[$i], $x12, $pos_p[$i], 
                       $col, $display_col );

    $y1 = $y1+15;

    push @all_accs, $pos_accs[$i]; 
  }

  ## neg ones:
  $y1 = $y1+2;
  my $neg_str = "Negative Correlations";
  ## $im->string(gdSmallFont, $x12, $y1, $neg_str, $black);
  my $y_SVG = $y1 + 10;
  $svg->text(x=>$x12,y=>$y_SVG,style=>{'font-size'=>12,'fill'=>$black})->cdata($neg_str);
 
  $y1 = $y1+15+2;
  for (my $i = 0; $i < @neg_accs; $i++) {
 
    lineForGraph_SVG ( 3, $org, $data_source,
                       $neg_accs[$i], \%acc2cid, 
                       \%acc2sym, $show_index, 
                       $x1, $y1, \$svg, \%scale2color,
                       $blue, $black, $x11, 
                       $neg_r[$i], $x12, $neg_p[$i],
                       $col, $display_col ); 

    $y1 = $y1+15;

    push @all_accs, $neg_accs[$i]; 

  }

  if( $show_index ) {
    $x1 = $x12+50-2-10;
    my $acc_list = join ",", @all_accs;
    Panel_SVG( \$svg, $data_source, $x1, $display_col, $col, $acc_list ); 
  }

  my $out = $svg->xmlify;
  my $id = WriteMCToCache( $out );

  if (!$id) {
    return "CACHE_FAILED";
  }

  return $id;

} 


######################################################################
sub createNeighborsGraphWithMap {
  my ($org, $data_source, $accession, $pos_accs_ref, $pos_r_ref, 
            $pos_p_ref, $neg_accs_ref, $neg_r_ref, $neg_p_ref, 
            $acc2cid_ref, $acc2sym_ref, $show_index, $lines_ref, $col,
            $display_col, $BASE) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my (@pos_accs, @pos_r, @pos_p, @pos_vecs,
      @neg_accs, @neg_r, @neg_p, @neg_vecs,
      @probe_vec);

  my (@pos_negs, %acc2cid, %acc2sym, @lines);

  @pos_accs = @$pos_accs_ref;
  @pos_r = @$pos_r_ref;
  @pos_p = @$pos_p_ref;
  @neg_accs = @$neg_accs_ref;
  @neg_r = @$neg_r_ref;
  @neg_p = @$neg_p_ref;
  %acc2cid = %$acc2cid_ref;
  %acc2sym = %$acc2sym_ref;

  my $maps;

  my $im = new GD::Image($IMAGE_WIDTH,$IMAGE_HEIGHT);

  my %scale2color;
  my ($white, $black, $red, $blue, $green, $yellow);

  InitializeColor(\$im, \%scale2color, \$white, \$black,
                  \$red, \$blue, \$green, \$yellow);

  $im->filledRectangle( 0, 0, $IMAGE_WIDTH, $IMAGE_HEIGHT, $white );

  ## hiperlink for R
  my $pos_cids;
  my $acc1 = $accession;
  $acc1 =~ s/_\d+$//;
  if (not defined $acc2cid{$acc1}) {
  } elsif ($acc2cid{$acc1}) {
    $pos_cids = $org . "." . $acc2cid{$acc1};
  } else {
     $pos_cids = "$org." . join(",$org.", @{ $acc2cid{$acc1} });
  }
 
  for ( my $i=0; $i<@pos_accs; $i++ ) {
    my $acc1 = $pos_accs[$i];
    $acc1 =~ s/_\d+$//;
    if (not defined $acc2cid{$acc1}) {
    } elsif ($acc2cid{$acc1}) {
      $pos_cids = $pos_cids . "," . $org . "." . $acc2cid{$acc1};
    } else {
      $pos_cids = $pos_cids . "," . "$org." . join(",$org.", @{ $acc2cid{$acc1} });
    }
  }
  my $neg_cids;
  for ( my $i=0; $i<@neg_accs; $i++ ) {
    my $acc1 = $neg_accs[$i];
    $acc1 =~ s/_\d+$//;
    if (not defined $acc2cid{$acc1}) {
    } elsif ($acc2cid{$acc1}) {
      $neg_cids = $neg_cids . "," . $org . "." . $acc2cid{$acc1};
    } else {
      $neg_cids = $neg_cids . "," . "$org." . join(",$org.", @{ $acc2cid{$acc1} });
    }
  }
 
  $maps = $maps . drawHiperLinkForR( $BASE, \$im, $blue, $show_index, 
                                     $data_source, $org, $pos_cids, $neg_cids );

  ## title:
  my @title;
  push @title, "Gene";
  push @title, ($data_source eq "SAGE" ? "TAG" : "ACC");
  push @title, "R";
  push @title, "P<=";

  my @position;
  my $x11;
  if( $data_source eq "SAGE" or $data_source eq "SAGE_SUMMARY") {
    $x11 = $LEFT2+65;
  }
  elsif( $data_source eq "LONG_SAGE" or $data_source eq "LONG_SAGE_SUMMARY" ) {
    $x11 = $LEFT2+65+$LONG_SAGE;
  }
  elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
    $x11 = $LEFT2+80;
  }
  else {
    $x11 = $LEFT2+60;
  }
  ## if( $data_source eq "SAGE" ) {
  ##   $x11 = $LEFT2+60;
  ## }
  ## else {
  ##   $x11 = $LEFT2+65;
  ## }
  my $x12 = $x11+35;
  push @position, $LEFT1;
  push @position, $LEFT2;
  push @position, $x11;
  push @position, $x12;

  drawTitle( 4, \$im, $show_index, $data_source,
                      \@position, \@title, $black );

  ## lines:
  my $x1;
  my $y1;
  my $x2;
  my $y2;
  if( $show_index ) {
    if( $data_source eq "NCI60_STANFORD" ) {
      $y1 = 95;
    }
    elsif ( $data_source eq "SAGE_SUMMARY" or $data_source eq "LONG_SAGE_SUMMARY" ) {
      $y1 = 250; 
    }
    elsif ( $data_source eq "LONG_SAGE" ) {
      $y1 = 455; 
    }
    elsif( $data_source eq "NCI60_NOVARTIS" ) {
      $y1 = 95;
    }
    elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
      $y1 = 95;
    }
    else {
      ## $y1 = 310; 
      $y1 = 385; 
    }
  }  
  else { 
    $y1 = 30;
  }

  ## The one:
  $x1 = $x12+50;
  $maps = $maps . lineForGraphWithMap ( 3, $org, $data_source,
                                        $accession, \%acc2cid,
                                        \%acc2sym, $show_index,
                                        $x1, $y1, \$im, \%scale2color,
                                        $blue, $black, $x11,
                                        "1", $x12, "0", $col, $display_col );

  ## pos ones:
  $y1 = $y1+$CELL_HEIGHT+2;
  my $pos_str = "Positive Correlations";
  $im->string(gdSmallFont, $x12, $y1, $pos_str, $black);

  $y1 = $y1+15+2;
  for (my $i = 0; $i < @pos_accs; $i++) {
    
    $maps = $maps . lineForGraphWithMap ( 3, $org, $data_source,
                                          $pos_accs[$i], \%acc2cid,
                                          \%acc2sym, $show_index,
                                          $x1, $y1, \$im, \%scale2color,
                                          $blue, $black, $x11,
                                          $pos_r[$i], $x12, $pos_p[$i], 
                                          $col, $display_col );

    $y1 = $y1+15;

  }

  ## neg ones:
  $y1 = $y1+2;
  my $neg_str = "Negative Correlations";
  $im->string(gdSmallFont, $x12, $y1, $neg_str, $black);
 
  $y1 = $y1+15+2;
  for (my $i = 0; $i < @neg_accs; $i++) {
 
    $maps = $maps . lineForGraphWithMap ( 3, $org, $data_source,
                                          $neg_accs[$i], \%acc2cid, 
                                          \%acc2sym, $show_index, 
                                          $x1, $y1, \$im, \%scale2color,
                                          $blue, $black, $x11, 
                                          $neg_r[$i], $x12, $neg_p[$i],
                                          $col, $display_col ); 

    $y1 = $y1+15;

  }

  if( $show_index ) {
    $x1 = $x12+50-2-10;
    $maps = $maps . Panel( \$im, $data_source, $x1, $display_col, $col ); 
  }
 
  push @$lines_ref, $maps;
 
  ## return $im->gif;
  if( GD->require_version() > 1.19 ) {
    return $im->png;
  }
  else {
    return $im->gif;
  }
  ## return $im->jpeg(100);
} 

######################################################################

sub createByStatsGraphWithMap {

  my ($org, $data_source, $accession, $mean_or_var, $vals_ref, $acc2cid_ref,
      $acc2sym_ref, $show_index, $lines_ref, $col, $display_col) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my @image_cache_id;
 
  my (@accs, @ordering, @vecs, %acc2cid, %acc2sym, @lines);
  my (@cids, %cid2acc_set, $a, $cidset);

  my @vals = @$vals_ref;

  @ordering = @$accession;
  %acc2cid = %$acc2cid_ref;
  %acc2sym = %$acc2sym_ref;

  ## my $maps;

  my $needMorePage = NO;

  my $start = 0;

  for ( my $nu = 0; $nu < 15; $nu++ ) {
    if( $needMorePage == YES ) {
      $needMorePage = NO;
    }

    my $maps;

    my $im = new GD::Image($IMAGE_WIDTH,$IMAGE_HEIGHT);
  
    my %scale2color;
    my ($white, $black, $red, $blue, $green, $yellow);

    InitializeColor(\$im, \%scale2color, \$white, \$black,
                    \$red, \$blue, \$green, \$yellow);

    $im->filledRectangle( 0, 0, $IMAGE_WIDTH, $IMAGE_HEIGHT, $white );
  
    ## title:
    my $title1 =  "Gene"; 
    my $title2 =  ($data_source eq "SAGE" ? "TAG" : "ACC"); 
    my $title3 =  ($mean_or_var eq "mean" ? "Mean" : "StdDev"); 

    ## my $x_mean = $LEFT2+55+25+5-15;
    my $x_mean = $LEFT2+70;
 
    if( $nu == 0 ) {
      ## title:
      my @title;
      push @title, "Gene";
      push @title, ($data_source eq "SAGE" ? "TAG" : "ACC");
      push @title, ($mean_or_var eq "mean" ? "Mean" : "StdDev"); 

      my @position;
      push @position, $LEFT1;
      push @position, $LEFT2;
      push @position, $x_mean;

      drawTitle( 3, \$im, $show_index, $data_source,
                    \@position, \@title, $black );

    }
  
    ## Panel:
 
    if( $show_index and $nu == 0 ) {
      my $x1 = $x_mean + 60 - 2;
      $maps = $maps . Panel( \$im, $data_source, $x1, $display_col, $col );
    }
 
    ## lines:
    my $x1; 
    my $y1;
    if( $nu == 0 ) {
      if( $show_index ) {
        if( $data_source eq "NCI60_STANFORD" ) {
          $y1 = 95;
        }
        elsif ( $data_source eq "SAGE_SUMMARY" ) {
          $y1 = 250;
        }
        elsif( $data_source eq "NCI60_NOVARTIS" ) {
          $y1 = 95;
        }
        elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
          $y1 = 95;
        }
        else {
          ## $y1 = 310;
          $y1 = 385;
        }
      }
      else {
        $y1 = 30;
      }
    }
    else {
      $y1 = 0;
    }
  
    $x1 = $x_mean + 70;
    for (my $i = $start; $i < @ordering; $i++) {

      if( $y1 + 15 > $IMAGE_HEIGHT ) {
        $start = $i;
        $needMorePage = YES;
        last;
      }
      else {
        $maps = $maps . lineForGraphWithMap ( 2, $org, $data_source,
                                              $ordering[$i], \%acc2cid,
                                              \%acc2sym, $show_index,
                                              $x1, $y1, \$im, \%scale2color,
                                              $blue, $black, $x_mean, 
                                              $vals[$i], "","", $col, 
                                              $display_col );
      }
   
      $y1 = $y1 + 15;
  
    }

    push @{$$lines_ref[$nu]}, $maps . "\n";
  
    my $id;
    ## my $id = WriteMCToCache( $im->gif );
    if( GD->require_version() > 1.19 ) {
      $id = WriteMCToCache( $im->png );
    }
    else {
      $id = WriteMCToCache( $im->gif );
    }
    ## my $id = WriteMCToCache( $im->jpeg(100) );

    if (!$id) {
      return "CACHE_FAILED";
    }
    else {
      push  @image_cache_id, $id;
    }

    if ( $needMorePage == NO ) {
      last;
    } 

  }

  return join ";", @image_cache_id;
} 

######################################################################

######################################################################

sub createByStatsSVGGraph {

  my ($org, $data_source, $accession, $mean_or_var, $vals_ref, $acc2cid_ref,
      $acc2sym_ref, $show_index, $col, $display_col) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my @image_cache_id;
 
  my (@accs, @ordering, @vecs, %acc2cid, %acc2sym, @lines);
  my (@cids, %cid2acc_set, $a, $cidset);

  my @vals = @$vals_ref;

  @ordering = @$accession;
  %acc2cid = %$acc2cid_ref;
  %acc2sym = %$acc2sym_ref;

  ## my $maps;

  my $start = 0;

  my $svg = SVG->new(width=>$SVG_IMAGE_WIDTH,height=>$SVG_IMAGE_HEIGHT);

  my %scale2color;
  my ($white, $black, $red, $blue, $green, $yellow);

  InitializeSVGColor(\%scale2color, \$white, \$black,
                     \$red, \$blue, \$green, \$yellow);

  ## title:
  my $title1 =  "Gene"; 
  my $title2 =  ($data_source eq "SAGE" ? "TAG" : "ACC"); 
  my $title3 =  ($mean_or_var eq "mean" ? "Mean" : "StdDev"); 

  ## my $x_mean = $LEFT2_SVG+55+25+5-15;
  my $x_mean = $LEFT2_SVG+70;
  my $x_mean = $x_mean+15; ## for SVG
 
  ## title:
  my @title;
  push @title, "Gene";
  push @title, ($data_source eq "SAGE" ? "TAG" : "ACC");
  push @title, ($mean_or_var eq "mean" ? "Mean" : "StdDev"); 

  my @position;
  push @position, $LEFT1;
  push @position, $LEFT2_SVG;
  push @position, $x_mean;

  drawTitle_SVG( 3, \$svg, $show_index, $data_source,
                    \@position, \@title, $black );


  ## Panel:
 
  my $x1 = $x_mean + 60 - 2;
  my $acc_list = join ",", @ordering;
  Panel_SVG( \$svg, $data_source, $x1, $display_col, $col, $acc_list );
 
  ## lines:
  my $x1; 
  my $y1;

  if( $show_index ) {
    if( $data_source eq "NCI60_STANFORD" ) {
      $y1 = 95;
    }
    elsif ( $data_source eq "SAGE_SUMMARY" ) {
      $y1 = 250;
    }
    elsif( $data_source eq "NCI60_NOVARTIS" ) {
      $y1 = 95;
    }
    elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
      $y1 = 95;
    }
    else {
      ## $y1 = 310;
      $y1 = 385;
    }
  }
  else {
    $y1 = 30;
  }

  defineRect_SVG(\$svg, \%scale2color);

  $x1 = $x_mean + 70;
  for (my $i = $start; $i < @ordering; $i++) {

    lineForGraph_SVG ( 2, $org, $data_source,
                       $ordering[$i], \%acc2cid,
                       \%acc2sym, $show_index,
                       $x1, $y1, \$svg, \%scale2color,
                       $blue, $black, $x_mean, 
                       $vals[$i], "","", $col, 
                       $display_col );
 
    $y1 = $y1 + 15;

  }

  my $out = $svg->xmlify;
  my $id = WriteMCToCache( $out );

  if (!$id) {
    return "CACHE_FAILED";
  }

  return $id;
} 








######################################################################

######################################################################
sub GetMicroarrayFromCache_1 {
  my ($base, $cache_id) = @_;

  my $test = Scan ($base, $cache_id);
  if( $test =~ /Error in input/ ) {
    return $test;
  }
  return ReadMicroarrayFromCache($cache_id);
}

######################################################################
sub ReadMicroarrayFromCache {
  my ($cache_id) = @_;

  my $test = Scan ($cache_id);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

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
sub WriteMCToCache {
  my ($data) = @_;
    
  ## my $test = Scan ($data);
  ## if( $test =~ /Error in input/ ) {
  ##   return $test;
  ## }
    
  my ($ge_cache_id, $filename) = $cache->MakeCacheFile();
  if ($ge_cache_id != $CACHE_FAIL) {
    if (open(MCOUT, ">$filename")) {
      print MCOUT $data;
      close MCOUT;
      chmod 0666, $filename;
    } else {
      $ge_cache_id = 0;
    }
  }
  return $ge_cache_id;
}

######################################################################
sub drawTitle {
   my ( $count, $im, $show_index, $data_source, $position_ref, 
        $title_ref, $black ) = @_;
   my $yy;    
   if( $show_index ) {
     if( $data_source eq "NCI60_STANFORD" ) {
       $yy = 80; 
     }
     elsif ( $data_source eq "SAGE_SUMMARY" or $data_source eq "LONG_SAGE_SUMMARY" ) {
       $yy = 235; 
     }
     elsif ( $data_source eq "LONG_SAGE" ) {
       $yy = 440; 
     }
     elsif( $data_source eq "NCI60_NOVARTIS" ) {
       $yy = 80; 
     }
     elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
       $yy = 80; 
     }
     else {
       ## $yy = 295;
       $yy = 370;
     }
   }  
   else {
     $yy = 15;
   }   
 
   for( my $i=0; $i<$count; $i++ ) {
     my $x1 = $$position_ref[$i];
     my $title = $$title_ref[$i];
     $$im->string(gdLargeFont,$x1,$yy,$title,$black);
   }

}

######################################################################
sub drawTitle_SVG {
   my ( $count, $svg, $show_index, $data_source, $position_ref,
        $title_ref, $black ) = @_;
   my $yy;
   if( $show_index ) {
     if( $data_source eq "NCI60_STANFORD" ) {
       $yy = 80;
     }
     elsif ( $data_source eq "SAGE_SUMMARY" ) {
       $yy = 235;
     }
     elsif( $data_source eq "NCI60_NOVARTIS" ) {
       $yy = 80;
     }
     elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
       $yy = 80;
     }
     else {
       ## $yy = 295;
       $yy = 370;
     }
   }
   else {
     $yy = 15;
   }

   $yy = $yy + $CELL_HEIGHT -5; ## for SVG

   for( my $i=0; $i<$count; $i++ ) {
     my $x1 = $$position_ref[$i];
     my $title = $$title_ref[$i];
     $$svg->text(x=>$x1,y=>$yy,style=>{'font-size'=>15,'fill'=>$black})->cdata($title);
   }
}

######################################################################
sub drawHiperLinkForR {
   my ($BASE, $im, $blue, $show_index, $data_source, $org, $pos_cids, 
       $neg_cids) = @_;

   if( not defined $cluster_table{$org} ) {
     print "<br><b><center>Error in input</b>!</center>";
     return "";
   }
   my $yy;    
   if( $show_index ) {
     if( $data_source eq "NCI60_STANFORD" ) {
       $yy = 80; 
     }
     elsif ( $data_source eq "SAGE_SUMMARY" or $data_source eq "LONG_SAGE_SUMMARY" ) {
       $yy = 235; 
     }
     elsif ( $data_source eq "LONG_SAGE" ) {
       $yy = 430;  
     }
     elsif( $data_source eq "NCI60_NOVARTIS" ) {
       $yy = 80; 
     }
     elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
       $yy = 80; 
     }
     else {
       ## $yy = 295;
       $yy = 370;
     }
   }  
   else {
     $yy = 15;
   }   
 
   ## my $cmd = "" . $BASE . "/Genes/RunUniGeneQuery?ORG=$org&TERM=$terms";
   ## my $cmd = "/Genes/RunUniGeneQuery?ORG=$org&TERM=$terms";

   my $R_1 = "R > 0";
   my $R_2 = "R < 0";

   my $x1 = $LEFT1 + 60;
   my $x2 = $LEFT2 + 60;
   my $x3 = $LEFT3 + 60;
   my $x4 = $LEFT4 + 60;
   my $y1;
   my $genes = "Genes:";

   if( $show_index ) {
     $y1 = $yy - 25; 
     $$im->string(gdLargeFont, $LEFT1, $y1, $genes, $blue);
     $$im->string(gdLargeFont, $x1, $y1, $R_1, $blue);
     $$im->string(gdLargeFont, $x2, $y1, $R_2, $blue);
   }
   else {
     $y1 = $yy - 15; 
     $$im->string(gdLargeFont, $LEFT1, $y1, $genes, $blue);
     $$im->string(gdLargeFont, $x1, $y1, $R_1, $blue);
     $$im->string(gdLargeFont, $x2, $y1, $R_2, $blue);
   }

   my $html1 =
     " href=\"$BASE/Genes/RunUniGeneQuery?PAGE=1&ORG=$org&TERM=$pos_cids\""; 

   my $html2 =
     " href=\"$BASE/Genes/RunUniGeneQuery?PAGE=1&ORG=$org&TERM=$neg_cids\""; 

   my $cord4 = $y1 + 15;

   my $barmap1="<area shape=rect coords=\"$x1, $y1, $x3, $cord4\"" .
               $html1 . " alt=\"Go to /Genes/RunUniGeneQuery\">";
   my $barmap2="<area shape=rect coords=\"$x2, $y1, $x4, $cord4\"" .
               $html2 . " alt=\"Go to /Genes/RunUniGeneQuery\">";
   my $maps = $barmap1 . $barmap2;

   return $maps;

}

######################################################################
sub drawHiperLinkForR_SVG {
   my ($BASE, $svg, $blue, $show_index, $data_source, $org, 
       $pos_cids, $neg_cids) = @_;

   if( not defined $cluster_table{$org} ) {
     print "<br><b><center>Error in input</b>!</center>";
     return "";
   }
   my $yy;    
   if( $show_index ) {
     if( $data_source eq "NCI60_STANFORD" ) {
       $yy = 80; 
     }
     elsif ( $data_source eq "SAGE_SUMMARY" ) {
       $yy = 235; 
     }
     elsif( $data_source eq "NCI60_NOVARTIS" ) {
       $yy = 80; 
     }
     elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
       $yy = 80; 
     }
     else {
       ## $yy = 295;
       $yy = 370;
     }
   }  
   else {
     $yy = 15;
   }   
 
   ## my $cmd = "" . $BASE . "/Genes/RunUniGeneQuery?ORG=$org&TERM=$terms";
   ## my $cmd = "/Genes/RunUniGeneQuery?ORG=$org&TERM=$terms";

   my $R_1 = "R > 0";
   my $R_2 = "R < 0";

   my $y1;

   if( $show_index ) {
     $y1 = $yy - 25; 
   }
   else {
     $y1 = $yy - 15; 
   }

   my $html1 = "$BASE/Genes/RunUniGeneQuery" .
                         uri_escape("?PAGE=1&ORG=$org&TERM=$pos_cids"); 

   my $html2 = "$BASE/Genes/RunUniGeneQuery" . 
                         uri_escape("?PAGE=1&ORG=$org&TERM=$neg_cids"); 

   my $cord4 = $y1 + 15;

   my $y1_SVG = $y1 + $CELL_HEIGHT -2 -2; ## for SVG;

   my $str = "Genes:";
   $$svg->text(x=>$LEFT1,y=>$y1_SVG,style=>{'font-size'=>16,'fill'=>$blue})->cdata($str);

   my $x1 = $LEFT1 + 60;
   my $x2 = $LEFT2_SVG + 60;

   $$svg->anchor(-href=>"$html1")->text(x=>$x1,y=>$y1_SVG,style=>{'font-size'=>16,'fill'=>'blue'})->cdata($R_1);
   $$svg->anchor(-href=>"$html2")->text(x=>$x2,y=>$y1_SVG,style=>{'font-size'=>16,'fill'=>'blue'})->cdata($R_2);

}

######################################################################
sub lineForGraphWithMap {
  my ( $flag, $org, $data_source, $accession, $acc2cid, $acc2sym,
       $show_index, $graph_start, $y1, $im, $scale2color, 
       $blue, $black, $value1_start, $value1, $value2_start, 
       $value2, $col, $display_col ) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my $html1;
  my $html11;
  my $cord4 = $y1 + 13;  
  my $str;
  my $maps;
  my ($x2, $y2); 
 
  my $acc1 = $accession;
  $acc1 =~ s/_\d+$//;

  if (not defined $$acc2cid{$acc1}) {
  } elsif ($$acc2cid{$acc1}) {
      $html1 = " href=\"$BASE/Genes/GeneInfo?" .
               "ORG=$org&CID=$$acc2cid{$acc1}\"";
      $str = $$acc2sym{$acc1}[0];
  } else {
    my $nice_sym = $$acc2sym{$acc1}[0];
    for (@{ $$acc2sym{$acc1} }) {
      if (! /^Hs\./) {   
        $nice_sym = $_;
      }  
    }   
    $html1 =
      " href=\"$BASE/Genes/RunUniGeneQuery?" .
      "PAGE=1&ORG=$org&TERM=" .
      "$org." . join(",$org.", @{ $$acc2cid{$acc1} }) . "\"";
    $str = $nice_sym . "...";
  }

  if( length($str) > 9 ) {
    my $tmp = $str;
    $str = substr($tmp, 0, 9);
    $html11 = " alt=\"$tmp Go to /Genes/RunUniGeneQuery\" ";
  }
  else {
    if ($$acc2cid{$acc1}) {
      $html11 = " alt=\"$str Go to /Genes/GeneInfo\" ";
    }
    else {
      $html11 = " alt=\"$str Go to /Genes/RunUniGeneQuery\" ";
    }
  }
   
  my $html2 =
    " href=\"FNResults?ORG=$org&" .
    "SRC=$data_source&ACCESSION=$accession&SHOW=$show_index&COLUMN=$col\"";
  
  $$im->string(gdSmallFont, $LEFT1, $y1, $str, $blue);
  
  my $str1 = $accession;
  $str1 =~ s/_0$//;
  if( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
    my $str2 = $str1;
    if( length($str1) > 11 ) {
      $str2 = substr($str1, 0, 11);
    }
    $$im->string(gdSmallFont, $LEFT2, $y1, $str2, $blue);
  }
  else {
    $$im->string(gdSmallFont, $LEFT2, $y1, $str1, $blue);
  }
  
  my $barmap1="<area shape=rect coords=\"$LEFT1, $y1, $LEFT3, $cord4\"" .
               $html1 .  $html11 . ">";

  my $barmap2;
  if( $data_source eq "LONG_SAGE" or $data_source eq "LONG_SAGE_SUMMARY") {
    my $co4 = $LEFT4 + 45;
    my $tmp_acc = $accession;
    $tmp_acc =~ s/_\d+$//; 
    $barmap2="<area shape=rect coords=\"$LEFT2, $y1, $co4, $cord4\"" .
               $html2 . " alt=\"$tmp_acc Go to FNResults\">";
  }
  else {
    my $tmp_acc = $accession;
    $tmp_acc =~ s/_\d+$//; 
    $barmap2="<area shape=rect coords=\"$LEFT2, $y1, $LEFT4, $cord4\"" .
               $html2 . " alt=\"$tmp_acc Go to FNResults\">";
  }
   
  $maps = $maps . $barmap1 . $barmap2;

  if( $flag == 2 ) {
      $$im->string(gdSmallFont, $value1_start, $y1, $value1, $black);
  } 
  elsif( $flag == 3 ) {
      $$im->string(gdSmallFont, $value1_start, $y1, $value1, $black);
      $$im->string(gdSmallFont, $value2_start, $y1, $value2, $black);
  } 
  elsif( $flag == 4 ) {
    return $maps;
  } 

  my @temp;
  my $x1 = $graph_start;
  if ($ma->ColorTheVector($str1,
                                \@microarray_color_scale, \@temp)) {
    $y2 = $y1+$CELL_HEIGHT;
    my $account = 0;
    for my $x (@temp) {
      $account++;
      if( $data_source eq "SAGE" or $data_source eq "LONG_SAGE" ) {
        if( not defined $$display_col{$account} ) {
          next;
        }
      }  
      my $color = $$scale2color{$x};
 
      if( $show_index ) {
        $x2 = $x1+$CELL_WIDTH;
      }
      else {
        $x2 = $x1+$SMALL_CELL_WIDTH;
      }
 
      $$im->filledRectangle( $x1, $y1, $x2, $y2, $color );
 
      $x1 = $x2;
    }
 
  }
   
  return $maps;

}

######################################################################


######################################################################
sub lineForGraph_SVG {
  my ( $flag, $org, $data_source, $accession, $acc2cid, $acc2sym,
       $show_index, $graph_start, $y1, $svg, $scale2color, 
       $blue, $black, $value1_start, $value1, $value2_start, 
       $value2, $col, $display_col ) = @_;

  if( not defined $cluster_table{$org} ) {
    print "<br><b><center>Error in input</b>!</center>";
    return "";
  }
  my $html1;
  my $html11;
  my $cord4 = $y1 + 13;  
  my $str;
  my $maps;
  my ($x2, $y2); 

  my $y1_SVG = $y1 + $CELL_HEIGHT -2 -2; ## for SVG;

  my $acc1 = $accession;
  $acc1 =~ s/_\d+$//;
  if (not defined $$acc2cid{$acc1}) {
  } elsif ($$acc2cid{$acc1}) {
      $html1 = "$BASE/Genes/GeneInfo" . 
                       uri_escape("?ORG=$org&CID=$$acc2cid{$acc1}");
                       ## uri_escape("ORG=$org&CID=$$acc2cid{$acc1}", "&");
      $str = $$acc2sym{$acc1}[0];
  } else {
    my $nice_sym = $$acc2sym{$acc1}[0];
    for (@{ $$acc2sym{$acc1} }) {
      if (! /^Hs\./) {   
        $nice_sym = $_;
      }  
    }   
    $html1 = "$BASE/Genes/RunUniGeneQuery" .
                 uri_escape("?PAGE=1&ORG=$org&TERM=" .
                   "$org." . join(",$org.", @{ $$acc2cid{$acc1} }));
                   ## "$org." . join(",$org.", @{ $$acc2cid{$acc1} }), "&");
    $str = $nice_sym . "...";
  }

  if( length($str) > 9 ) {
    my $tmp = $str;
    $str = substr($tmp, 0, 9);
    $html11 = " alt=\"$tmp\" ";
  }
  my $html2 = "FNResults" .
         uri_escape("?ORG=$org&" .
    "SRC=$data_source&ACCESSION=$accession&SHOW=$show_index&COLUMN=$col");
    ## "SRC=$data_source&ACCESSION=$accession&SHOW=$show_index&COLUMN=$col", "&");

  ## $$im->string(gdSmallFont, $LEFT1, $y1, $str, $blue);
  $$svg->anchor(-href=>"$html1")->text(x=>$LEFT1,y=>$y1_SVG,style=>{'font-size'=>11,'fill'=>'blue'})->cdata($str);
  my $str1 = $accession;
  $str1 =~ s/_0$//;
  $$svg->anchor(-href=>"$html2")->text(x=>$LEFT2_SVG,y=>$y1_SVG,style=>{'font-size'=>11,'fill'=>'blue'})->cdata($str1);
  ## $$im->string(gdSmallFont, $LEFT2, $y1, $str1, $blue);
  
  ## my $barmap1="<area shape=rect coords=\"$LEFT1, $y1, $LEFT3, $cord4\"" .
               $html1 .  $html11 . ">";
  ## my $barmap2="<area shape=rect coords=\"$LEFT2, $y1, $LEFT4, $cord4\"" .
               $html2 . ">";
   
  ## $maps = $maps . $barmap1 . $barmap2;

  if( $flag == 2 ) {
      ## $$im->string(gdSmallFont, $value1_start, $y1, $value1, $black);
      $$svg->text(x=>$value1_start,y=>$y1_SVG,style=>{'font-size'=>11,'fill'=>$black})->cdata($value1);
  } 
  elsif( $flag == 3 ) {
      ## $$im->string(gdSmallFont, $value1_start, $y1, $value1, $black);
      ## $$im->string(gdSmallFont, $value2_start, $y1, $value2, $black);
      $$svg->text(x=>$value1_start,y=>$y1_SVG,style=>{'font-size'=>11,'fill'=>$black})->cdata($value1);
      $$svg->text(x=>$value2_start,y=>$y1_SVG,style=>{'font-size'=>11,'fill'=>$black})->cdata($value2);
  } 
  elsif( $flag == 4 ) {
    ## return $maps;
    return;
  } 

  my @temp;
  my $x1 = $graph_start;
  my $x1 = $x1 + 5 + 10; ## for SVG
  if ($ma->ColorTheVector($str1,
                          \@microarray_color_scale, \@temp)) {
    $y2 = $y1+$CELL_HEIGHT;
    my $account = 0;
    for my $x (@temp) {
      $account++;
      if( $data_source eq "SAGE" or $data_source eq "LONG_SAGE" ) {
        if( not defined $$display_col{$account} ) {
          next;
        }
      }  

      ##my $color = $$scale2color{$x};
 
      if( $show_index ) {
        $x2 = $x1+$CELL_WIDTH;
      }
      else {
        $x2 = $x1+$SMALL_CELL_WIDTH;
      }
 
      ## $$im->filledRectangle( $x1, $y1, $x2, $y2, $color );
      ## my $width = $x2 - $x1;
      ## my $height = $y2 - $y1;
      ## $$svg->rect(x=>$x1,y=>$y1,width=>$width, height=>$height,style=>{fill=>$color});

      my $id = $color2id{$x};
      $$svg->use(x=>$x1,y=>$y1, '-href'=>"#$id");
 
      $x1 = $x2;
    }
 
  }
   
}

######################################################################
sub Panel {
  my ($im, $data_source, $x1, $display_col, $col) = @_; 

  my $bio_src = $data_src2bio_src{$data_source};
  my $cell_cols = $ma->NumCols();
  my $x2;
  my $y1;
  my $y2;
  my $maps;
  for (my $i = 1; $i <= $cell_cols; $i++) {
    if( $data_source eq "SAGE" or $data_source eq "LONG_SAGE" ) {
      if( not defined $$display_col{$i} ) {
        next;
      }
    }
    my $color;
    if( $cell2color{$bio_src}{$i} eq "FFFF99" ) {
      $color = $$im->colorAllocate(000,153,102);
    }
    else {
      $color = $$im->colorAllocate(204,000,051);
    }
    my $tmp_str = $ma->Num2Cell($i);
    if( $data_source eq "NCI60_STANFORD" ) {
      $y2 = 90;
    }
    elsif ( $data_source eq "SAGE_SUMMARY" or $data_source eq "LONG_SAGE_SUMMARY" ) {
      $y2 = 245;
    }
    elsif ( $data_source eq "LONG_SAGE" ) {
      $y2 = 450;
    }
    elsif( $data_source eq "NCI60_NOVARTIS" ) {
      $y2 = 90;
    }
    elsif( $data_source eq "NCI60_U133" or $data_source eq "NCI60_U95") {
      $y2 = 90;
    }
    else {
      ## $y2 = 305;
      $y2 = 380;
    }
    $x2 = $x1+10;
    my $len = length($tmp_str);
    $y1 = $y2-$len*6;
    my $html =  " href=\"javascript:" .
      "document.mform.action='PivotResults';" .
      "document.mform.SRC.value='$data_source';" .
      ## "document.mform.COLUMN.value=$col;" .
      "document.mform.COLN.value=$i;" .
      "document.mform.SHOW.value=1;" .
      "document.mform.submit()\" ";
    my $x3 = $x1+10+2+1;
    my $x4 = $x2+10+2-1;
    ## for map
    
    if( $data_source ne "NCI60_NOVARTIS" and $data_source ne "NCI60_U133" and $data_source ne "NCI60_U95")       { ## don't hyperlink the column names
                                             ## for NCI60_NOVARTIS
      my $barmap="<area shape=rect coords=\"$x3, $y1, $x4, $y2\" " .
                  $html .  " alt=\"Go to PivotResults\">";
      $maps = $maps . $barmap;
    }
    $x1 = $x2;
    ## for graph
    $$im->stringUp(gdSmallFont, $x1, $y2, $tmp_str, $color);
  }  

  return $maps;
}

######################################################################
sub defineRect_SVG {
  my ($svg, $scale2color) = @_;

  my $color1 = $$scale2color{'0000FF'};
  my $color2 = $$scale2color{'3399FF'};
  my $color3 = $$scale2color{'66CCFF'};
  my $color4 = $$scale2color{'99CCFF'};
  my $color5 = $$scale2color{'CCCCFF'};
  my $color6 = $$scale2color{'FFCCFF'};
  my $color7 = $$scale2color{'FF99FF'};
  my $color8 = $$scale2color{'FF66CC'};
  my $color9 = $$scale2color{'FF6666'};
  my $color10 = $$scale2color{'FF0000'};
  my $color11 = $$scale2color{'000000'};

  $$svg->defs->rect(id=>'A', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color1});
  $$svg->defs->rect(id=>'B', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color2});
  $$svg->defs->rect(id=>'C', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color3});
  $$svg->defs->rect(id=>'D', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color4});
  $$svg->defs->rect(id=>'E', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color5});
  $$svg->defs->rect(id=>'F', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color6});
  $$svg->defs->rect(id=>'G', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color7});
  $$svg->defs->rect(id=>'H', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color8});
  $$svg->defs->rect(id=>'I', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color9});
  $$svg->defs->rect(id=>'J', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color10});
  $$svg->defs->rect(id=>'K', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color11});

  ## $$svg->defs->rect(id=>'0000FF', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color1});
  ## $$svg->defs->rect(id=>'3399FF', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color2});
  ## $$svg->defs->rect(id=>'66CCFF', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color3});
  ## $$svg->defs->rect(id=>'99CCFF', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color4});
  ## $$svg->defs->rect(id=>'CCCCFF', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color5});
  ## $$svg->defs->rect(id=>'FFCCFF', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color6});
  ## $$svg->defs->rect(id=>'FF99FF', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color7});
  ## $$svg->defs->rect(id=>'FF66CC', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color8});
  ## $$svg->defs->rect(id=>'FF6666', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color9});
  ## $$svg->defs->rect(id=>'FF0000', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color10});
  ## $$svg->defs->rect(id=>'000000', width=>$CELL_WIDTH, height=>$CELL_HEIGHT, style=>{fill=>$color11});
}

######################################################################
sub Panel_SVG {
  my ($svg, $data_source, $x1, $display_col, $col, $accession_list) = @_;

  my $bio_src = $data_src2bio_src{$data_source};
  my $cell_cols = $ma->NumCols();
  my $x2;
  my $y1;
  my $y2;
  my $maps;
  $x1 = $x1+25+11;  ## for SVG
  for (my $i = 1; $i <= $cell_cols; $i++) {
    if( $data_source eq "SAGE" or $data_source eq "LONG_SAGE" ) {
      if( not defined $$display_col{$i} ) {
        next;
      }
    }
    my $color;
    if( $cell2color{$bio_src}{$i} eq "FFFF99" ) {
      $color = "rgb(000,153,102)";
    }
    else {
      $color = "rgb(204,000,051)";
    }
    my $tmp_str = $ma->Num2Cell($i);

    ## if( $data_source eq "NCI60_STANFORD" ) {
    ##   $y2 = 90;
    ## }
    ## elsif ( $data_source eq "SAGE_SUMMARY" ) {
    ##   $y2 = 145;
    ## }
    ## else {

    ## $y2 = 305;
    $y2 = 380;

    ## }
    $x2 = $x1+10;
    my $len = length($tmp_str);
    $y1 = $y2-$len*6;

    my $org = "Hs";
    ## my $html = "PivotResults?" .
               "ORG=$org&SRC=$data_source&ACCS=$accession_list&COLUMN=$col&COLN=$i&SHOW=1";

    ## my $html = "javascript:" .
    ##   "document.mform.action='PivotResults';" .
    ##   "document.mform.SRC.value='$data_source';" .
    ##   "document.mform.COLN.value=$i;" .
    ##   "document.mform.SHOW.value=1;" .
    ##   "document.mform.submit()";
    ## "document.mform.ORG.value='Hs';" .
    ## my $x3 = $x1+10+2+1;
    ## my $x4 = $x2+10+2-1;

    ## "document.mform.COLUMN.value=$col;" .

    my $x_tr = $x1 - $y2;
    my $y_tr = $x1 + $y2;
    $$svg->text(x=>$x1,y=>$y2,style=>{'font-size'=>11,'fill'=>$color},'transform'=>"translate($x_tr, $y_tr)rotate(-90)")->cdata($tmp_str);


    ## $$svg->anchor(-href=>"$html")->text(x=>$x1,y=>$y2, style=>{'font-size'=>11,'fill'=>'$color'}, transform=>'translate($x_tr, $y_tr)rotate(-90)')->cdata('$tmp_str');

    $x1 = $x2;

  } 

}

######################################################################
sub InitializeColor {
  my ($im,
      $scale2color, 
      $white,
      $black,
      $red,
      $blue,
      $green,
      $yellow) = @_;

  my $test = Scan ($im,
                   $scale2color, 
                   $white,
                   $black,
                   $red,
                   $blue,
                   $green,
                   $yellow);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  $$white       = $$im->colorAllocate(255,255,255);
  $$black       = $$im->colorAllocate(0,0,0);
  $$red         = $$im->colorAllocate(255,0,0);
  $$blue        = $$im->colorAllocate(0,0,255);
  $$green       = $$im->colorAllocate(0,128,0);
  $$yellow      = $$im->colorAllocate(255,255,0);

  my $color1  = $$im->colorAllocate(0,0,255);
  my $color2  = $$im->colorAllocate(51,153,255);
  my $color3  = $$im->colorAllocate(102,204,255);
  my $color4  = $$im->colorAllocate(153,204,255);
  my $color5  = $$im->colorAllocate(204,204,255);
  my $color6  = $$im->colorAllocate(255,204,255);
  my $color7  = $$im->colorAllocate(255,153,255);
  my $color8  = $$im->colorAllocate(255,102,204);
  my $color9  = $$im->colorAllocate(255,102,102);
  my $color10 = $$im->colorAllocate(255,0,0);
  my $color11 = $$im->colorAllocate(0,0,0);
 
  $$scale2color{'0000FF'} = $color1;
  $$scale2color{'3399FF'} = $color2;
  $$scale2color{'66CCFF'} = $color3;
  $$scale2color{'99CCFF'} = $color4;
  $$scale2color{'CCCCFF'} = $color5;
  $$scale2color{'FFCCFF'} = $color6;
  $$scale2color{'FF99FF'} = $color7;
  $$scale2color{'FF66CC'} = $color8;
  $$scale2color{'FF6666'} = $color9;
  $$scale2color{'FF0000'} = $color10;
  $$scale2color{'000000'} = $color11;
}


######################################################################
sub InitializeSVGColor {
  my ($scale2color,
      $white,
      $black,
      $red,
      $blue,
      $green,
      $yellow) = @_;

  my $test = Scan ($scale2color,
                   $white,
                   $black,
                   $red,
                   $blue,
                   $green,
                   $yellow);
  if( $test =~ /Error in input/ ) {
    return $test;
  }

  $$white       = "rgb(255,255,255)";
  $$black       = "rgb(0,0,0)";
  $$red         = "rgb(255,0,0)";
  $$blue        = "rgb(0,0,255)";
  $$green       = "rgb(0,128,0)";
  $$yellow      = "rgb(255,255,0)";

  my $color1  = "rgb(0,0,255)";
  my $color2  = "rgb(51,153,255)";
  my $color3  = "rgb(102,204,255)";
  my $color4  = "rgb(153,204,255)";
  my $color5  = "rgb(204,204,255)";
  my $color6  = "rgb(255,204,255)";
  my $color7  = "rgb(255,153,255)";
  my $color8  = "rgb(255,102,204)";
  my $color9  = "rgb(255,102,102)";
  my $color10 = "rgb(255,0,0)";
  my $color11 = "rgb(0,0,0)";

  $$scale2color{'0000FF'} = $color1;
  $$scale2color{'3399FF'} = $color2;
  $$scale2color{'66CCFF'} = $color3;
  $$scale2color{'99CCFF'} = $color4;
  $$scale2color{'CCCCFF'} = $color5;
  $$scale2color{'FFCCFF'} = $color6;
  $$scale2color{'FF99FF'} = $color7;
  $$scale2color{'FF66CC'} = $color8;
  $$scale2color{'FF6666'} = $color9;
  $$scale2color{'FF0000'} = $color10;
  $$scale2color{'000000'} = $color11;
}

## SetSafe(
##     "ResetServer",
##     "ByStats",
##     "LookForAccessions",
##     "OrderRandomGenes",
##     "FindNeighbors",
##     "PivotOnColumn",
##     "GetMicroarrayFromCache"

## );

## SetForkable(
##    "ByStats",
##    "LookForAccessions",
##    "OrderRandomGenes",
##    "FindNeighbors",
##    "PivotOnColumn",
##    "GetMicroarrayFromCache"

## );


## InitializeDatabase();

######################################################################
1;
