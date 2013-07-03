#!/usr/local/bin/perl

use strict;
use DBI;
use GetPvalueForT;
use CGI;
use Scan;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

if (-d "/app/oracle/product/dbhome/current") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/dbhome/current";
} elsif (-d "/app/oracle/product/8.1.7") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.7";
} elsif (-d "/app/oracle/product/8.1.6") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/8.1.6";
} elsif (-d "/app/oracle/product/10gClient") {
  $ENV{'ORACLE_HOME'} = "/app/oracle/product/10gClient"
}

my $query   = new CGI;
my $listf  = $query->param("LISTF");
my $tag     = $query->param("TAG");

print "Content-type: text/plain\n\n";
#print "Content-type: application/excel\n\n";

Scan($listf, $tag);

#my (
#  $listf,
#  $tag
#) = @ARGV;

use constant ORACLE_LIST_LIMIT  => 500;
use constant MAX_LONG_LEN       => 16384;
use constant MAX_ROWS_PER_FETCH => 1000;

my (
  $db_inst,
  $db_user,
  $db_pass,
  $schema
) = ("cgprod", "web", "readonly", "cgap2");

my (@order, %order, %order2bioassay_id, %bioassay_id2order,
    %bioassay_id2name, %tag2gene);
my (%data);
my ($rval, $nvals) = (0.80, 10);
my (@pos_accs, @pos_r, @pos_p, @pos_vecs,
    @neg_accs, @neg_r, @neg_p, @neg_vecs);

my $db = DBI->connect("DBI:Oracle:" . $db_inst, $db_user, $db_pass);
if (not $db or $db->err()) {
  print STDERR "Cannot connect to " . $db_user . "@" . $db_inst . "\n";
  exit();
}

if (! $tag) {
  print STDERR "no tag specified\n";
  exit;
}

if ($listf) {
  ReadList($listf);
} else {
  my $n;
  my @col = $query->param();
  for my $x (@col) {
    if ($x =~ /^C_(\d+)$/) {
      push @order, $1;
      $order{$1} = $n++;
    }
  }
}

if (@order == 0) {
  print STDERR "no columns specified\n";
  exit;
}

GetBioAssayNames($db);
FetchValues($db);

#Dump();

FindNeighbors(
    $tag, $rval, $nvals,
    \@pos_accs, \@pos_r, \@pos_p, \@pos_vecs,
    \@neg_accs, \@neg_r, \@neg_p, \@neg_vecs);

GetGenes($db, [$tag, @pos_accs, @neg_accs]);

$db->disconnect();

Results(
    \@pos_accs, \@pos_r, \@pos_p, \@pos_vecs,
    \@neg_accs, \@neg_r, \@neg_p, \@neg_vecs);

######################################################################
sub GetGenes {
  my ($db, $probes) = @_;

  my ($sql, $stm);
  my ($tag, $cid, $gene);
  my ($i, $list);

  for ($i = 0; $i < @{$probes}; $i += ORACLE_LIST_LIMIT) {
 
    if(($i + ORACLE_LIST_LIMIT - 1) < @{$probes}) {
      $list = join("','", @{$probes}[$i..$i+ORACLE_LIST_LIMIT-1]);
    }
    else {
      $list = join("','", @{$probes}[$i..@{$probes}-1]);
    }
 
    $sql = "select b.tag, h.cluster_number, h.gene " .
        "from $schema.hs_cluster h, $schema.sagebest_tag2clu b " .
        "where b.cluster_number = h.cluster_number " .
        "and b.protocol = 'A' " .
        "and b.tag in ('$list')";

    my $stm = $db->prepare($sql);
    if (not $stm) {
      print STDERR "prepare call failed\n";
      $db->disconnect();
      exit;
    }
    if (! $stm->execute()) {
      print STDERR "execute call failed\n";
      $db->disconnect();
      exit;
    }

    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($tag, $cid, $gene) = @{ $row };
        if (! $gene) {
          $gene = "Hs.$cid";
        }
        $tag2gene{$tag}{$gene} = 1;
      }
    }
  }

}

######################################################################
sub Results {
  my ($pos_accs, $pos_r, $pos_p, $pos_vecs,
      $neg_accs, $neg_r, $neg_p, $neg_vecs) = @_;

  print join("\t", "", "", "", "");
  for my $i (@order) {
    print "\t" . $bioassay_id2name{$order2bioassay_id{$i}};
  }
  print  "\n";

  print join("\t",
      $tag, join(",", sort keys %{ $tag2gene{$tag} }),
      "1.00", "0.00",
      join("\t", @{ $data{$tag} })) . "\n";
  print "\n";

  for (my $i = 0; $i < @{ $pos_accs }; $i++) {
    print join("\t", $$pos_accs[$i],
      join(",", sort keys %{ $tag2gene{$$pos_accs[$i]} }),
      $$pos_r[$i], $$pos_p[$i],
      join("\t", @{ $$pos_vecs[$i] })) . "\n";
  }  

  print "\n";
  for (my $i = 0; $i < @{ $neg_accs }; $i++) {
    print join("\t", $$neg_accs[$i],
      join(",", sort keys %{ $tag2gene{$$neg_accs[$i]} }),
      $$neg_r[$i], $$neg_p[$i],
      join("\t", @{ $$neg_vecs[$i] })) . "\n";
  }  
}

######################################################################
sub Dump {
  print "Probe";
  for my $x (@order) {
    print "\t" . $bioassay_id2name{$order2bioassay_id{$x}};
  }
  print "\n";
  for my $probe (keys %data) {
    print join("\t", $probe, @{ $data{$probe} }) . "\n";
  }
}

######################################################################
sub FetchValues {
  my ($db) = @_;

  my ($sql, $stm);
  my ($probe, $replica, $bioassay_id, $raw_value);

  $sql = "select p.probe, p.replica, p.bioassay_id, p.raw_value " .
      "from $schema.cgap_2d_probe p, $schema.cgap_2d_experiment e " .
      "where e.organism = 'Hs' " .
      "and e.experiment_type = 'SAGE' " .
      "and e.experiment_id = p.experiment_id " .
      "and p.bioassay_id in (" . join(",", keys %bioassay_id2name ) . ") " .
      "order by p.probe, p.replica, p.bioassay_id";

  $db->{LongReadLen} = MAX_LONG_LEN;
  
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print STDERR "prepare call failed\n";
    $db->disconnect();
    exit;
  }
  if (! $stm->execute()) {
    print STDERR "execute call failed\n";
    $db->disconnect();
    exit;
  }

  my ($row, $rowcache);
  while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
    for $row (@{ $rowcache }) {
        ($probe, $replica, $bioassay_id, $raw_value) = @{ $row };
#      print join("\t", $probe, $replica, $bioassay_id, $raw_value) . "\n";
      if (! defined $data{$probe}) {
        $data{$probe} = [];
      }
      $data{$probe}[$order{$bioassay_id2order{$bioassay_id}}] = $raw_value
    }
  }
}

######################################################################
sub GetBioAssayNames {
  my ($db) = @_;

  my ($sql, $stm);
  my ($id, $name, $column);

  $sql = "select b.bioassay_id, b.bioassay_name, b.col_order " .
      "from $schema.cgap_2d_bioassay b, $schema.cgap_2d_experiment e " .
      "where e.organism = 'Hs' " .
      "and e.experiment_type = 'SAGE' " .
      "and e.experiment_id = b.bioassay_experiment_id " .
      "and b.col_order in (" . join(",", @order) . ")";

  $db->{LongReadLen} = MAX_LONG_LEN;
  
  my $stm = $db->prepare($sql);
  if (not $stm) {
    print STDERR "prepare call failed\n";
    $db->disconnect();
    exit;
  }
  if (! $stm->execute()) {
    print STDERR "execute call failed\n";
    $db->disconnect();
    exit;
  }

  my ($row, $rowcache);
  while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
    for $row (@{ $rowcache }) {
      ($id, $name, $column) = @{ $row };
      $bioassay_id2name{$id} = $name;
      $bioassay_id2order{$id} = $column;
      $order2bioassay_id{$column} = $id;
#      print "$id, $name, $column\n";
    }
  }

}


######################################################################
sub ReadList {
  my ($f) = @_;

  my (%tmp, $n);

#  open(INF, $f) or die "cannot open $f";
#  while (<INF>) {
  while (<$f>) {
    s/\s+//g;
    if (/^$/) {
      next;
    }
    if (/^\d+$/) {
      my $id = $_;
      if (defined $tmp{$id}) {
        print STDERR "ignoring duplicate id: $id\n";
        next;
      } else {
        $tmp{$id} = 1;
        push @order, $id;
        $order{$id} = $n++;
      }
    } else {
      print STDERR "ignoring input line (not an id): $_\n";
      next;
    }
  }
#  close INF;
}

######################################################################
######################################################################
sub PreCompute {
  my ($index, $ny, $meany, $sumsqy, $stdy, $array) = @_;

  for my $probe (keys %data) {
    push @{ $index }, $probe;
    push @{ $array }, $data{$probe};
    my ($n, $mean, $sum, $sumsq, $std, $diff);
    for my $y (@{ $data{$probe} }) {
      if ($y ne "") {
        $n++;
        $sum = $sum + $y;
      }
    }
    if ($n > 0) {
      $mean = $sum / $n;
      for my $y (@{ $data{$probe} }) {
        $diff = $y - $mean;
        $sumsq = $sumsq + ($diff * $diff)
      }
      push @{ $ny }, $n;
      push @{ $meany }, $mean;
      push @{ $sumsqy }, $sumsq;
      if ($n > 1) {
        $std = sqrt($sumsq / ($n - 1));
      }
      push @{ $sumsqy }, $std;
    } else {
      push @{ $ny }, 0;
      push @{ $meany }, undef;
      push @{ $sumsqy }, undef;
      push @{ $sumsq }, undef;
    }
  }
}

######################################################################
sub FindNeighbors {
  my ($accession, $rval, $nvals,
      $pos_accs, $pos_r, $pos_p, $pos_vecs,
      $neg_accs, $neg_r, $neg_p, $neg_vecs) = @_;

  my (@empty);
  my ($meanx, $sumsqx);
  my (@index, %order, @ny, @meany, @sumsqy, @stdy, @array);
  my ($i, $probe_i, $probe_vec);
  my ($gene, %r_vals, $r, $p, %pvals, $n_neighbors);
  my $pos_rval = $rval;
  my $neg_rval = -1 * $pos_rval;


  ## Get accessions whose expression pattern correlates (positively
  ## or negatively) with the probe accession.
  ## Get at least the $nvals accessions that have the highest positive
  ## correlation and the $nvals accesions that have the lowest
  ## negative correlation.
  ## In any case, get all accessions whose correlation is higher
  ## than $rval or lower than -$rval

  PreCompute(\@index, \@ny, \@meany, \@sumsqy, \@stdy, \@array);

  if (@index == 0) {
    return 0;
  }

  for ($i = 0; $i < @index; $i++) {
    if ($accession eq $index[$i]) {
      $meanx = $meany[$i];
      $sumsqx = $sumsqy[$i];
      $probe_i = $i;
      $probe_vec = \@{ $array[$i] };
    }
    $order{$index[$i]} = $i;
  }

  for ($i = 0; $i < @index; $i++) {
    if ($probe_i != $i) {
      $gene = $index[$i];
      ($r, $p) = R($probe_vec, $meanx, $sumsqx,
          \@{ $array[$i] }, $meany[$i], $sumsqy[$i]);
      push @{ $r_vals{$r} }, $gene;
      $pvals{$gene} = $p;
    }
  }

  my @temp = sort numerically keys %r_vals;

  $n_neighbors = 0;
  for (my $i = $#temp; $i >= 0; $i--) {
    $r = $temp[$i];
    if ($n_neighbors >= $nvals and $r < $pos_rval) {
      last;
    }
    for $gene (@{ $r_vals{$r} }) {
      push @{ $pos_accs }, $gene;
      push @{ $pos_r }, sprintf("%.2f", $r);
      push @{ $pos_p }, sprintf("%.2e", $pvals{$gene});
      push @{ $pos_vecs }, $array[$order{$gene}];
      $n_neighbors++;
    }
  }

  $n_neighbors = 0;
  for $r (@temp) {
    if ($n_neighbors >= $nvals && $r > $neg_rval) {
      last;
    }
    for $gene (@{ $r_vals{$r} }) {
      push @{ $neg_accs }, $gene;
      push @{ $neg_r }, sprintf("%.2f", $r);
      push @{ $neg_p }, sprintf("%.2e", $pvals{$gene});
      push @{ $neg_vecs }, $array[$order{$gene}];
      $n_neighbors++;
    }
  }

  return 1;
}

######################################################################
sub   numerically { $a <=> $b; }
sub r_numerically { $b <=> $a; }

######################################################################
sub TValue {
  my ($r, $n) = @_;
  my $t = $r * sqrt( ($n - 2)/(1 - $r * $r ) );
  return $t;
}

######################################################################
sub R {
  my ($x, $mean_x, $sum_x_sq, $y, $mean_y, $sum_y_sq) = @_;

  ## The formula for r is from (20) on page 298 of Schaum's outline of
  ## THEORY AND PROBLEMS of STATISTICS 
  ## Second Edition
  ## by MURRAY R. SPIEGEL   
  ## 5th printing, 1992   

  my @X = @{$x};
  my @Y = @{$y};
  my $Xtotal=0;
  my $Ytotal=0;
  my $Xsquaretotal=0;
  my $Ysquaretotal=0;
  my $XYtotal;
  my $total = @X;
  my $count = 0;
  my $numerator; 
  my $denominator; 
  ## my $nonzerocount = 0;

  for (my $i=0; $i<$total; $i++) {
    my $x = $X[$i];
    my $y = $Y[$i];
    if( ($x ne "") and ($y ne "") ) {
      $Xtotal = $Xtotal + $x;
      $Ytotal = $Ytotal + $y;
      $Xsquaretotal = $Xsquaretotal + $x * $x;
      $Ysquaretotal = $Ysquaretotal + $y * $y;
      $XYtotal      = $XYtotal + $x * $y;
      $count++;
    }
  }

  ## for (my $i=0; $i<$total; $i++) {
  ##   my $x = $X[$i];
  ##   my $y = $Y[$i];
  ##   if( ($x != 0) and ($y != 0) ) {
  ##     $nonzerocount++;
  ##   }
  ## }

  $denominator = 
        ( $count * $Xsquaretotal - $Xtotal * $Xtotal ) *
        ( $count * $Ysquaretotal - $Ytotal * $Ytotal ); 

  my $r;

  if( ($count < 2) || ($denominator <= 0)) {
    return (0, 1);
  }
  ## elsif( $nonzerocount < 2 ) {
  ##   return (0, 1);
  ## }
  else {
    $numerator = $count * $XYtotal - $Xtotal * $Ytotal;
    $r = $numerator/sqrt( $denominator );
  }

  if( $r >= 1 ) {
    $r = 0.99999999;
  }
  elsif ( $r <= -1 ) {
    $r = -0.99999999;
  }
  if ($count < 3) {
    return ($r, 1);
  } else {
    my $t = TValue(abs($r), $count);
    my $p = GetPvalueForT::GetPvalueForT($t, $count-2);
    return ($r, $p);
  }
}

