#!/usr/local/bin/perl

use strict;
use DBI;

use constant MAX_LONG_LEN => 16384;

my ($org, $cid) = @ARGV;

my ($inst, $user, $pass, $schema) =
    ("cgprod", "web", "readonly", "cgap2");

my $db = DBI->connect("DBI:Oracle:$inst", "$user", "$pass");
if (not $db or $db->err()) {
  print STDERR "Cannot connect to $user\@$inst\n";
  exit;
}

$db->{LongReadLen} = MAX_LONG_LEN;

## get mrna,protein pairs for this Gene id
  
my $sql = qq!
select distinct
  l1.ll_id,
  m.mrna_accession,
  m.protein_accession
from
  $schema.ll2acc l1,
  $schema.ll2acc l2,
  $schema.mrna2prot m,
  $schema.gene2unigene g
where
      g.cluster_number = $cid
  and g.organism = '$org'
  and l1.ll_id = g.gene_id
  and l2.ll_id = g.gene_id
  and l1.accession = m.mrna_accession
  and l2.accession = m.protein_accession
!;

my ($ll_id, $mrna, $prot);
my ($sp);
my (%prot2mrna, %prot2sp);

my $stm = $db->prepare($sql);
if (not $stm) {
  print STDERR "prepare call failed\n";
} else {
  if ($stm->execute()) {
    while (($ll_id, $mrna, $prot)
        = $stm->fetchrow_array()) {
      $prot2mrna{$prot}{$mrna} = 1;
    }
  } else {
    print STDERR "Execute failed\n";
  }
}

## get SP ids

my $list = "'" . join("','", keys %prot2mrna) . "'";
print "8888: $list \n";
$sql = qq!
  select
    s.other_accession,
    p.sp_primary
  from
    $schema.sp2other s,
    $schema.sp_primary p,
    $schema.sp_info i
  where
         s.other_accession in ($list)
     and p.sp_id_or_secondary = s.sp_accession
     and p.id_or_accession = 'a'
     and i.sp_primary = p.sp_id_or_secondary
     and i.organism = '$org'
!;

$stm = $db->prepare($sql);
if (not $stm) {
  print STDERR "prepare call failed\n";
} else {
  if ($stm->execute()) {
    while (($prot, $sp)
        = $stm->fetchrow_array()) {
      $prot2sp{$prot}{$sp} = 1;
    }
  } else {
    print STDERR "Execute failed\n";
  }
}

if (! defined %prot2mrna) {
  $db->disconnect();
  exit;
}

## get motif info

my (%motif2name, %motif2type, %prot2motif);
my ($motif_id, $motif_name, $motif_type);

my $list = "'" . join("','", keys %prot2mrna) . "'";
$sql = qq!
  select distinct
    m.protein_accession,
    m.motif_id,
    m.motif_type,
    m.motif_name
  from
    $schema.motif_info m
  where
        m.protein_accession in ($list)
    and m.score >= 20
!;

$stm = $db->prepare($sql);
if (not $stm) {
  print STDERR "prepare call failed\n";
} else {
  if ($stm->execute()) {
    while (($prot, $motif_id, $motif_type, $motif_name)
        = $stm->fetchrow_array()) {
      $motif2type{$motif_id} = $motif_type;
      $motif2name{$motif_id} = $motif_name;
      $prot2motif{$prot}{$motif_id} = 1;
    }
  } else {
    print STDERR "Execute failed\n";
  }
}

$db->disconnect();

my (@temp, @lines, @np_lines, @other_lines);

for $prot (sort keys %prot2mrna) {
  undef @temp;
  my @mrna_array = map
      { "<a href=\"" . GB_URL($_) . "\" target=_blank>$_</a>" }
      keys %{ $prot2mrna{$prot} };
  my @sp_array = map
      { "<a href=\"" . SP_URL($_) . "\" target=_blank>$_</a>" }
      keys %{ $prot2sp{$prot} };
  my ($mrnas, $sps, $motifs);
  if (@mrna_array) {
    $mrnas = join("<br>", @mrna_array);
  } else {
    $mrnas = "\&nbsp;";
  }
  if (@sp_array) {
    $sps = join("<br>", @sp_array);
  } else {
    $sps = "\&nbsp;";
  }
  if (defined $prot2motif{$prot}) {
    my @motif_array;
    for $motif_id (sort keys %{ $prot2motif{$prot} }) {
      push @motif_array, "<a href=\"" .
          MOTIF_URL($motif_id, $motif2type{$motif_id}) .
          "\" target=_blank>$motif2name{$motif_id}</a>";
    }
    $motifs = join("<br>", @motif_array);
  } else {
    $motifs = "\&nbsp;";
  }
  push @temp, "<tr>";
  push @temp, "<td>";
  push @temp, $mrnas;
  push @temp, "</td>";
  push @temp, "<td>";
  push @temp, "<a href=\"" . GP_URL($prot) . "\" target=_blank>$prot</a>";
  push @temp, "</td>";
  push @temp, "<td>";
  push @temp, $sps;
  push @temp, "</td>";
  if ($prot =~ /^NP_/) {
    push @temp, "<td>";
    push @temp, $motifs;
    push @temp, "</td>";
  }
  push @temp, "</tr>";
  if ($prot =~ /^NP_/) {
    push @np_lines, @temp;
  } else {
    push @other_lines, @temp;
  }
}

if (@np_lines) {
  push @lines, "<h4>RefSeq</h4>";
  push @lines, "<table border=1>";
  push @lines, "<tr>" .
               "<td>mRNA</td>" .
               "<td>Protein</td>" .
               "<td>SwissProt</td>" .
               "<td>Pfam Motifs</td>" .
               "</tr>";
  push @lines, @np_lines;
  push @lines, "</table>";
}

if (@other_lines) {
  push @lines, "<h4>Related Sequences</h4>";
  push @lines, "<table border=1>";
  push @lines, "<tr>" .
               "<td>mRNA</td>" .
               "<td>GenPept</td>" .
               "<td>SwissProt</td>" .
               "</tr>";
  push @lines, @other_lines;
  push @lines, "</table>";
}
print "<html>\n";
print join("\n", @lines) . "\n";

######################################################################
sub MOTIF_URL {
  my ($id, $type) = @_;
  if ($type eq "PFAM") {
    return "http://pfam.wustl.edu/cgi-bin/getdesc?acc=$id";
  } else {
    return "";
  }
}

######################################################################
sub SP_URL {
  my ($acc) = @_;
  return "http://us.expasy.org/cgi-bin/niceprot.pl?$acc";
}

######################################################################
sub GB_URL {
  my ($acc) = @_;
  return "http://www.ncbi.nih.gov/entrez/query.fcgi?db=nucleotide" .
      "&cmd=search&term=$acc";
}

######################################################################
sub GP_URL {
  my ($acc) = @_;
  return "http://www.ncbi.nih.gov/entrez/query.fcgi?db=protein" .
      "&cmd=search&term=$acc";
}
