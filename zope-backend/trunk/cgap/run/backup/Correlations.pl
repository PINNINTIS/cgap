#!/usr/local/bin/perl

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use strict;
use CGAPConfig;
use DBI;
use MicroArray;
use CGI;

my $NEIGHBOR_RVAL = "0.85";
my $N_NEIGHBORS = 10;

my ($ma);

## allow for multiple experiments off the same bio source
my %data_src2bio_src = (
  "NCI60_STANFORD"  => "NCI60_STANFORD",
  "SAGE"            => "SAGE",
  "SAGE_SUMMARY"    => "SAGE_SUMMARY",
  "NCI60_NOVARTIS"  => "NCI60_NOVARTIS",
  "UBC_SAGE"        => "UBC_SAGE",
  "LONG_SAGE"       => "LONG_SAGE",
  "NCI60_U133"      => "NCI60_U133"
);

my %exp_name = (
  1 => "SAGE",
  2 => "SAGE_SUMMARY",
  3 => "NCI60_STANFORD",
  4 => "NCI60_NOVARTIS",
  5 => "UBC_SAGE",
  6 => "LONG_SAGE",
  7 => "NCI60_U133"
);

my $SAGE_SUMMARY_CODE = 2;

my %patchForWhiteBloodCells; 

$patchForWhiteBloodCells {"White Blood Cells normal"} = "Leukocytes normal";

print "Content-type: text/plain\n\n";

my ($org, $data_source, $accession,
    $n_limit, $r_limit) =
#   ("Hs", "NCI60_STANFORD", "W87861_0",
#    "20", ".85");
   ("Hs", "LONG_SAGE", "GGGAATTAAAATTTTTA",
    "20", ".85");

my $query       = new CGI;
my $org         = $query->param("ORG");
my $data_source = $query->param("SRC");
my $accession   = $query->param("ACCESSION");
my $n_limit     = $query->param("N");
my $r_limit     = $query->param("R");

if ($org ne "Hs" && $org ne "Mm") {
  print "Parameter ORG: no organism or unrecognized organism specified\n";
  exit;
}

if (! defined $data_src2bio_src{$data_source}) {
  print "Parameter SRC: No data source or unrecognized data source specified\n";
  exit;
}

if ($accession eq "") {
  print "Parameter ACCESSION: No accession specified\n";
  exit;
}

if ($n_limit == "") {
  $n_limit = $N_NEIGHBORS;
}
if ($r_limit == "") {
  $r_limit = $NEIGHBOR_RVAL;
}

if ($accession !~ /_\d+$/) {
  $accession = $accession . "_0";
}

print FindNeighbors($org, $data_source, $accession,
  $n_limit, $r_limit);


######################################################################
sub LookForCIDs {
  my ($data_source, $org, $accs, $acc2cid, $acc2sym) = @_;

  my ($sql, $stm);
  my ($acc, $cid, $sym);
  my ($sacc, @simple_accs);

  $ma->LookForCIDs($accs, $acc2cid);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
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

    if ($data_source eq "SAGE" || $data_source eq "SAGE_SUMMARY" ||
        $data_source eq "UBC_SAGE" || $data_source eq "LONG_SAGE") {
      my $sage_protocol_list = ($org eq "Hs") ? "'A','C'" : "'K','M'";
      $sql = "select s.tag, s.cluster_number, c.gene " .
          "from $CGAP_SCHEMA.sagebest_cluster s, $CGAP_SCHEMA.$c_table c " .
          "where c.cluster_number = s.cluster_number " .
          "and s.protocol in ($sage_protocol_list) " .
          "and s.tag in ('" . $list . "')";
    } else {
      my $table_name = ($org eq "Hs" ? "$CGAP_SCHEMA.hs_ug_sequence " : "$CGAP_SCHEMA.mm_ug_sequence ");
      $sql = "select s.accession, s.cluster_number, c.gene " .
          "from $table_name s, $CGAP_SCHEMA.$c_table c " .
          "where c.cluster_number = s.cluster_number " .
          "and s.accession in ('" . $list . "')";
    }

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
sub FindNeighbors {
  my ($org, $data_source, $accession, $n_limit, $r_limit) = @_;

  my (@pos_accs, @pos_r, @pos_p, @pos_vecs,
      @neg_accs, @neg_r, @neg_p, @neg_vecs,
      @probe_vec);

  my @lines;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print STDERR "$DBI::errstr\n";
    exit;
  }

  $ma = new MicroArray($db, $CGAP_SCHEMA, $data_source);

  if (not $ma->FindNeighbors($accession, $r_limit,
      $n_limit, \@probe_vec, \@pos_accs, \@pos_r, \@pos_p, \@pos_vecs,
      \@neg_accs, \@neg_r, \@neg_p, \@neg_vecs)) {
    return "No $data_source data for $accession\n";
  }

#  $ma->ReadView([$accession, @pos_accs, @neg_accs]);

  my (@pos_negs, %acc2cid, %acc2sym, @lines);

  push @pos_negs, $accession,
  push @pos_negs, @pos_accs;
  push @pos_negs, @neg_accs;

  LookForCIDs($data_source, $org, \@pos_negs, \%acc2cid, \%acc2sym);

  my ($acc, $a, $cid, $sym, $r, $p);

  $acc = $accession;
  $acc =~ s/_0$//;
  unshift @pos_accs, $acc;
  unshift @pos_r, "1.00";
  unshift @pos_p, "0.00";

  for (my $i = 0; $i < @pos_accs; $i++) {
    $acc = $pos_accs[$i];
    $a = $acc;
    $a =~ s/_0$//;
    $acc =~ s/_\d+$//;
    $cid = $acc2cid{$acc};
    if ($cid) {
      $cid = "$org.$cid";
    } else {
      $cid = "-";
    }
    if (defined $acc2sym{$acc}) {
      $sym = join(",", @{ $acc2sym{$acc} });
    } else {
      $sym = "-";
    }
    $r = $pos_r[$i];
    $p = $pos_p[$i];
    push @lines, join("\t", $sym, $cid, $a, $r, $p);
  }
  for (my $i = 0; $i < @neg_accs; $i++) {
    $acc = $neg_accs[$i];
    $a = $acc;
    $a =~ s/_0$//;
    $acc =~ s/_\d+$//;
    $cid = $acc2cid{$acc};
    if ($cid) {
      $cid = "$org.$cid";
    } else {
      $cid = "-";
    }
    if (defined $acc2sym{$acc}) {
      $sym = join(",", @{ $acc2sym{$acc} });
    } else {
      $sym = "-";
    }
    $r = $neg_r[$i];
    $p = $neg_p[$i];
    push @lines, join("\t", $sym, $cid, $a, $r, $p);
  }

  return join("\n", @lines) . "\n";
}

######################################################################
sub numerically { $a <=> $b; }


