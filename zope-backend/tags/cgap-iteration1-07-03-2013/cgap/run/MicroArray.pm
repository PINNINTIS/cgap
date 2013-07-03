#####################################################################
# MicroArray.pm
######################################################################

######################################################################
# Microarray data file format:
#   Input:
#     L libraries
#     G genes
#     tab-separated columns
#     line 1: empty column followed by library ids (one per column)
#     lines 2 thru G+1: gene id column folowed by L values (one per column)
#   Output:
#     L libraries
#     G genes
#     tab-separated columns
#     line 1: 5 empty columns followed by library ids (one per column)
#     lines 2 thru G+1:
#       gene id column
#       number of non-null values column
#       mean of non-null values in row column
#       variance of non-null values in row column
#       standard deviation of non-null values in row column
#       folowed by L values (one per column)
#
######################################################################

package MicroArray;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
  NumAccessions,
  NumLibraries,
  FindNeighbors,
  OrderSet,
  Pivot,
  LookForAccessions,
  LookForCIDs,
  LookupByCID,
  ColorTheVector,
  ColorTheSpot,
  IsSAGE,
  IsUBCSAGE,
  IsLONGSAGE,
  IsNCI60_NOVARTIS,
  IsNCI60_U133,
  IsNCI60_U95
);

use DBI;
use CGAPConfig;
use strict;
use GetPvalueForT;
use cor;

use constant ORACLE_LIST_LIMIT  => 500;
#use constant MAX_LONG_LEN       => 16384;
use constant MAX_LONG_LEN       => 40000;
use constant MAX_ROWS_PER_FETCH => 1000;

## use constant LENGTH_OF_ARRARY  => 300;
use constant LENGTH_OF_ARRARY  => 500;

use constant BLACK => "000000";

my $TOTAL_COLUMNS = -1;

######################################################################
sub new {
  my ($class, $db, $schema, $experiment) = @_;

  my $x = {};
  $x->{db}         = $db;
  $x->{schema}     = $schema;

  $db->{LongReadLen} = MAX_LONG_LEN;
  
  my ($sql, $stm);

  my ($experiment_id, $experiment_name, $experiment_type,
      $organism, $num_bioassays, $num_probes);
  my ($bioassay_name, $col_order, $panel_name);

  $sql = qq!
select
  experiment_id,
  experiment_name,
  experiment_type,
  organism,
  num_bioassays,
  num_probes
from
  $schema.cgap_2d_experiment
where
  experiment_name = '$experiment'
  !;

  $stm = $db->prepare($sql);
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
    return undef;
  }
  if(!$stm->execute()) {
     print STDERR "$sql\n";
     print STDERR "$DBI::errstr\n";
     print STDERR "execute call failed\n";
     die "Error: execute call $sql failed with message $DBI::errstr";
     return undef;
  }
  $stm->bind_columns(
    \$experiment_id,
    \$experiment_name,
    \$experiment_type,
    \$organism,
    \$num_bioassays,
    \$num_probes
  );
  $stm->fetch();
  $stm->finish();
  $x->{experiment_id}   = $experiment_id;
  $x->{experiment_name} = $experiment_name;
  $x->{experiment_type} = $experiment_type;
  $x->{organism}        = $organism;
  $x->{num_bioassays}   = $num_bioassays;
  $x->{num_probeS}      = $num_probes;

  ## print STDERR "8888: $experiment_id, $experiment_name, $experiment_type, $organism, $num_bioassays, $num_probes \n";
  if (defined $experiment_id) {
    $sql = qq!
select
  bioassay_name,
  col_order,
  panel_name
from
  $schema.cgap_2d_bioassay
where
  bioassay_experiment_id = $experiment_id
  !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      die "Error: prepare call $sql failed with message $DBI::errstr";
      return undef;
    }
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      die "Error: execute call $sql failed with message $DBI::errstr";
      return undef;
    }

    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($bioassay_name, $col_order, $panel_name) = @{ $row };
        $x->{cell2panel}{$bioassay_name} = $panel_name;
        $x->{num2cell}{$col_order} = $bioassay_name;
      }
    }
    $x->{num_columns} = scalar(keys %{ $x->{num2cell} });
    if ($experiment_id == 1) {  ## Store SAGE_SUMMARY as well
      $sql = qq!
select
  bioassay_name,
  col_order,
  panel_name
from
  $schema.cgap_2d_bioassay
where
  bioassay_experiment_id = 2
  !;

      $stm = $db->prepare($sql);
      if(not $stm) {
        print STDERR "$sql\n";
        print STDERR "$DBI::errstr\n";
        print STDERR "prepare call failed\n";
        die "Error: prepare call $sql failed with message $DBI::errstr";
        return undef;
      }
      if(!$stm->execute()) {
        print STDERR "$sql\n";
        print STDERR "$DBI::errstr\n";
        print STDERR "execute call failed\n";
        die "Error: execute call $sql failed with message $DBI::errstr";
        return undef;
      }

      my ($row, $rowcache);
      while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
        for $row (@{ $rowcache }) {
          ($bioassay_name, $col_order, $panel_name) = @{ $row };
          $x->{num2group}{$col_order} = $bioassay_name;
        }
      }
    }
    if ($experiment_id == 6) {  ## Store LONG_SAGE_SUMMARY as well
      $sql = qq!
select
  bioassay_name,
  col_order,
  panel_name
from
  $schema.cgap_2d_bioassay
where
  bioassay_experiment_id =8 
  !;
 
      $stm = $db->prepare($sql);
      if(not $stm) {
        print STDERR "$sql\n";
        print STDERR "$DBI::errstr\n";
        print STDERR "prepare call failed\n";
        die "Error: prepare call $sql failed with message $DBI::errstr";
        return undef;
      }
      if(!$stm->execute()) {
        print STDERR "$sql\n";
        print STDERR "$DBI::errstr\n";
        print STDERR "execute call failed\n";
        die "Error: execute call $sql failed with message $DBI::errstr";
        return undef;
      }
 
      my ($row, $rowcache);
      while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
        for $row (@{ $rowcache }) {
          ($bioassay_name, $col_order, $panel_name) = @{ $row };
          $x->{num2group}{$col_order} = $bioassay_name;
        }
      }
    }



    return bless $x;
  } else {
    print STDERR "no experiment named $experiment\n";
    die "Error: no experiment named $experiment";
    return undef;
  }
}

######################################################################
sub IsSAGE {
  my ($self) = @_;
  return $self->{experiment_type} eq "SAGE";
}

######################################################################
sub IsUBCSAGE {
  my ($self) = @_;
  return $self->{experiment_type} eq "UBC_SAGE";
}

######################################################################
sub IsLONGSAGE {
  my ($self) = @_;
  return $self->{experiment_type} eq "LONG_SAGE";
}

######################################################################
sub IsNCI60_NOVARTIS {
  my ($self) = @_;
  return $self->{experiment_type} eq "SPOTTED ARRAY";
}
 
######################################################################
sub IsNCI60_U133 {
  my ($self) = @_;
  return $self->{experiment_type} eq "AFFYMETRIX U133 ARRAY";
}

######################################################################
sub IsNCI60_U95 {
  my ($self) = @_;
  return $self->{experiment_type} eq "AFFYMETRIX U95 ARRAY";
}
 
######################################################################
sub NumAccessions {
  my ($self) = @_;
  return $self->{num_probes};
}

######################################################################
sub NumLibraries {
  my ($self) = @_;
  return $self->{num_bioassays};
}

######################################################################
sub Cell2Panel {
  my ($self, $cell) = @_;
  return $self->{cell2panel}{$cell};
}

######################################################################
sub Num2Cell {
  my ($self, $num) = @_;
  return $self->{num2cell}{$num};
}

######################################################################
sub NumCols {
  my ($self) = @_;
  return $self->{num_columns};
}

######################################################################
sub Num2Group {
  my ($self, $num) = @_;
  return $self->{num2group}{$num};
}

######################################################################
sub MatrixMove {
  my ($i, $m, $visited, $non_value, $ordf) = @_;

  ## It's a square matrix

  if ($$visited[$i]) {
    return $non_value;
  } else {
    $$visited[$i] = 1;
  }

  my ($j, $save_j);
  my $n = @{ $m };
  my $val = $non_value;

  for ($j = 0; $j < $n; $j++) {
    if (not $$visited[$j]) {
      if (&{ $ordf }($$m[$i][$j], $val)) {
        $val = $$m[$i][$j];
        $save_j = $j
      }
    }
  }
  if ($val != $non_value) {
    return $save_j;
  } else {
    return $non_value;
  }
  
}

######################################################################
sub ArrayR {
  my ($array, $meanx, $sumsqx, $r_array, $high_i) = @_;

  my ($i, $j, $r, $p, $val);
  my $NON_VALUE = -2;

  $val    = $NON_VALUE;
  $$high_i = $NON_VALUE;

  my $nrows = @{ $array };

  ## my $len = LENGTH_OF_ARRARY;
  my $len = scalar($$array[0]) + 2;
  my $ia = cor::double_array($len);
  my $ib = cor::double_array($len);

  my @ttmp = @{ $array };

  for ($i = 0; $i < $nrows; $i++) {
    for ($j = $i+1; $j < $nrows; $j++) {

      ($r, $p) = R($$array[$i], $$meanx[$i], $$sumsqx[$i],
             $$array[$j], $$meanx[$j], $$sumsqx[$j], $ia, $ib);
      $$r_array[$i][$j] = $r;
      $$r_array[$j][$i] = $r;
      if ($r > $val) {
        $val = $r;
        $$high_i = $i;        ## save off a highest correlating row
      }
    }
  }

  cor::double_destroy($ia);
  cor::double_destroy($ib);
}

######################################################################
sub Pivot {
  my ($self, $accs, $column, $rval, $nvals,
      $pos_cols, $pos_r, $pos_p,
      $neg_cols, $neg_r, $neg_p, $array) = @_;

  ## Range of column is 1..N (NOT 0..N-1)
  my $the_col = $column - 1;

  my (@t_array);
  my (@nx, @meanx, @sumsqx, @stdx);
  my ($meanx, $sumsqx);
  my (@ny, @meany, @sumsqy, @stdy);
  my (@index);
  my ($i, $trows, $tcols, $r, $p, $n_neighbors, $col, @temp);
  my (%p_vals, %r_vals);
  my $pos_rval = $rval;
  my $neg_rval = -1 * $pos_rval;

  $self->FetchArray($accs, \@index, \@nx, \@meanx, \@sumsqx, \@stdx, $array);
  TransposeArray($array, \@t_array, \@ny, \@meany, \@sumsqy);

  if ($ny[$the_col] < 2) {
    return 0;
  }

  $trows = @t_array;
  $tcols = @{ $t_array[0] };
  $meanx = $meany[$the_col];
  $sumsqx = $sumsqy[$the_col];;

  ## my $len = LENGTH_OF_ARRARY;
  my $len = scalar($t_array[$the_col]) + 2;
  my $ia = cor::double_array($len);
  my $ib = cor::double_array($len);

  for ($i = 0; $i < $trows; $i++) {
    if ($i != $the_col) {
      ($r, $p) = R($t_array[$the_col], $meanx, $sumsqx,
           $t_array[$i], $meany[$i], $sumsqy[$i], $ia, $ib);
      if ($p < 1) {
        $p_vals{$i} = $p;
        push @{ $r_vals{$r} }, $i;
      }
    }
  }

  cor::double_destroy($ia);
  cor::double_destroy($ib);

  @temp = sort numerically keys %r_vals;

  $n_neighbors = 0;
  for ($i = $#temp; $i >= 0; $i--) {
    $r = $temp[$i];
    if ($n_neighbors >= $nvals and $r < $pos_rval) {
      last;
    }
    for $col (@{ $r_vals{$r} }) {
      if( $r <= 0 ) {
        next;
      }
      push @{ $pos_cols }, $col;
      push @{ $pos_r }, sprintf("%.2f", $r);
      push @{ $pos_p }, sprintf("%.2e", $p_vals{$col});
      $n_neighbors++;
    }
  }

  $n_neighbors = 0;
  for $r (@temp) {
    if ($n_neighbors >= $nvals && $r > $neg_rval) {
      last;
    }
    for $col (@{ $r_vals{$r} }) {
      if( $r >= 0 ) {
        next;
      }
      push @{ $neg_cols }, $col;
      push @{ $neg_r }, sprintf("%.2f", $r);
      push @{ $neg_p }, sprintf("%.2e", $p_vals{$col});
      $n_neighbors++;
    }
  }

  return 1;

}


######################################################################
sub OrderSet {
  my ($self, $acclist, $ordering, $vecs) = @_;

  my (@index, @nx, @meanx, @sumsqx, @stdx, @array);
  my (@r_array, $nrows);
  my ($i, $j, $r, $p, $save_i, $non_value, $val);

  my $non_value = -2;

##  $val    = $non_value;
##  $save_i = $non_value;

  $self->FetchArray($acclist, \@index, \@nx, \@meanx, \@sumsqx, \@stdx, \@array);

  ## If 0 or 1 accessions were found, get out now
  if (@index < 2) {
    if (@index == 1) {
      push @{ $ordering }, $index[0];
      push @{ $vecs }, $array[0];
    }
    return;
  }

  ArrayR(\@array, \@meanx, \@sumsqx, \@r_array, \$save_i);

  ## not pretty: we are using $non_value ( == -2) to mean both an
  ## impossible correlation value and a non-existent array index

  my @visited;
  while ($save_i != $non_value) {
    push @{ $ordering }, $index[$save_i];
    push @{ $vecs },     $array[$save_i];
    $save_i = MatrixMove($save_i, \@r_array, \@visited, $non_value, \&IsGreaterThan);
  }
  
}

######################################################################
sub IsGreaterThan {
  my ($x, $y) = @_;
  if ($x > $y) {
    return 1;
  } else {
    return 0;
  }
}

######################################################################
sub TransposeArray {
  my ($array, $tarray, $ny, $meany, $sumsqy) = @_;

  my ($nrows, $ncols);
  my ($i, $j, $x, $n, $diff);

  $nrows = @{ $array };
  if ($nrows < 1) {
    return;
  }
  $ncols = @{ $$array[0] };

  for ($i = 0; $i < $nrows; $i++) {
    $n = 0;
    for ($j = 0; $j < $ncols; $j++) {
      $x = $$array[$i][$j];
      $$tarray[$j][$i] = $x;
      if ($x ne "") {
        $$ny[$j]++;
        $$meany[$j] += $x;
      }
    }
  }
  for ($i = 0; $i < $ncols; $i++) {
    if ($$ny[$i] ne "") {
      $$meany[$i] = $$meany[$i] / $$ny[$i];
    }
  }
  for ($i = 0; $i < $ncols; $i++) {
    if ($$meany[$i] ne "") {
      for ($j = 0; $j < $nrows; $j++) {
        $diff = $$tarray[$i][$j] - $$meany[$i];
        $$sumsqy[$i] += ($diff * $diff);
      }
    }
  }
}

######################################################################
sub FetchArray {
  my ($self, $acclist, $index, $nx, $meanx, $sumsqx, $stdx, $array) = @_;

  ##
  ## $acclist, if specified, my include probes
  ## that ARE or ARE NOT qualified by replica
  ## e.g. BF33994 or BF33994_0, or BF33994_1
  ##

  my $db            = $self->{db};
  my $schema        = $self->{schema};
  my $experiment_id = $self->{experiment_id};

  my ($sql, $stm);
  my ($probe, $replica, $n_values, $mean, $sum_sq, $stdev, $data);

  ## If @acclist is null, take everything; otherwise
  ## take only specified rows

  my ($probes_specified, %probes_specified);
  for my $acc (@{ $acclist }) {
    if ($acc =~ /^(.+)(_)(\d+)$/) {
      ($probe, $replica) = ($1, $3);
    } else {
      ($probe, $replica) = ($acc, 0);
    }
    $probes_specified{$probe}{$replica} = 1;
  }
  $probes_specified = scalar(keys %probes_specified);

  my $list_clause = "";
  if ($probes_specified && $probes_specified < 500) {
    $list_clause = " and probe in " .
        "('" . join("','", keys %probes_specified) . "')";
  }

  $sql = qq!
select
  probe,
  replica,
  n_values,
  mean,
  sum_sq,
  stdev,
  data
from
  $schema.cgap_2d_raw
where
  experiment_id = $experiment_id
  $list_clause
  !;

  $stm = $db->prepare($sql);
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
    return undef;
  }
  if(!$stm->execute()) {
     print STDERR "$sql\n";
     print STDERR "$DBI::errstr\n";
     print STDERR "execute call failed\n";
     die "Error: execute call $sql failed with message $DBI::errstr";
     return undef;
  }

  my ($row, $rowcache);
  my $i=0;
  while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
    for $row (@{ $rowcache }) {
      ($probe, $replica, $n_values, $mean, $sum_sq, $stdev, $data) =
          @{ $row };
      if (! $replica) {
        $replica = 0;
      }
      if ($probes_specified) {
        if (! defined $probes_specified{$probe}{$replica} &&
            ! defined $probes_specified{$probe}{"0"}) {
          next;
        }
      }
      push @{ $index  }, $probe . "_" . $replica;
      push @{ $nx     }, $n_values;
      push @{ $meanx  }, $mean;
      push @{ $sumsqx }, $sum_sq;
      push @{ $stdx   }, $stdev;
      push @{ $array  }, [ split("\t", $data, $TOTAL_COLUMNS) ];  
      $i++;
    }
  }

}

######################################################################
sub ReadView {
  my ($self, $probes) = @_;
  ##
  ## probes are expected to be already qualified with
  ## replica: e.g. BF33994_1, GTATCCTGAC_0
  ##

  my $db            = $self->{db};
  my $schema        = $self->{schema};
  my $experiment_id = $self->{experiment_id};

  my ($sql, $stm);
  my ($probe, $replica, $data);
  my ($i, %probeset, $list);

  for my $p (@{ $probes }) {
    if ($p =~ /(.+)(_)(\d+)$/) {
      ($probe, $replica) = ($1, $3);
    } else {
      ($probe, $replica) = ($p, 0);
    }
    $probeset{$probe}{$replica} = 1;
  }
  my @probeset = (keys %probeset);

  if (@probeset == 0) {
    return;
  }

  for($i = 0; $i < @probeset; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @probeset) {
      $list = join("','", @probeset[$i..$i+ORACLE_LIST_LIMIT-1]);
    } else {
      $list = join("','", @probeset[$i..@probeset-1]);
    }
    $list = "'" . $list ."'";
    $sql = qq!
select
    probe,
    replica,
    data
from
    $schema.cgap_2d_color
where
      experiment_id = $experiment_id
  and probe in ($list)
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      die "Error: prepare call $sql failed with message $DBI::errstr";
      return undef;
    }
    if(!$stm->execute()) {
       print STDERR "$sql\n";
       print STDERR "$DBI::errstr\n";
       print STDERR "execute call failed\n";
       die "Error: execute call $sql failed with message $DBI::errstr";
       return undef;
    }
    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($probe, $replica, $data) = @{ $row };
        if (! $replica) {
          $replica = 0;
        }
        if (defined $probeset{$probe}{$replica}) {
          $self->{view}{$probe ."_" . $replica} = [ split("\t", $data, $TOTAL_COLUMNS) ];
        }
      }
    }

  }

}

######################################################################
sub LookForAccessions {
  my ($self, $accs) = @_;

  my (%temp);
  for my $a (@{ $accs }) {
    if (defined $self->{acc2cid_set}{$a}) {
      $temp{$a};
    }
  }
  return join(",", keys %temp);

}

######################################################################
sub LookForCIDs {
  my ($self, $accs, $acc2cid) = @_;

  my (%seen, $a);

  for $a (@{ $accs }) {
    if ((not $seen{$a}) && defined $self->{acc2cid_set}{$a}) {
      $seen{$a} = 1;
      for (@{ $self->{acc2cid_set}{$a} }) {
        push @{ $$acc2cid{$a} }, $_;
      }
    }
  }

}

######################################################################
sub LookupByCID {
  my ($self, $cids, $cid2acc_set) = @_;

  ##
  ## returns probe names qualified by replica:
  ## e.g. BF33994_1, GTATCCTGAC_0
  ##

  my $db            = $self->{db};
  my $schema        = $self->{schema};
  my $experiment_id = $self->{experiment_id};
  my $organism      = $self->{organism};

  my ($probe, $replica, $cluster_number);
  my ($sql, $stm);
  my ($i, $list);

  for($i = 0; $i < @{ $cids }; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @{ $cids }) {
      $list = join(",", @{ $cids }[$i..$i+ORACLE_LIST_LIMIT-1]);
    } else {
      $list = join(",", @{ $cids }[$i..@{ $cids }-1]);
    }
    if ($self->IsSAGE()) {
      $sql = qq^
select
  d.probe,
  d.replica,
  s.cluster_number
from
  $schema.sagebest_cluster s,
  $schema.sageprotocol p,
  $schema.cgap_2d_color d
where
      s.cluster_number in ($list)
  and s.protocol = p.code
  and p.organism = '$organism'
  and p.protocol in ('SS10', 'LS10')
  and s.tag = d.probe
  and d.experiment_id = $experiment_id
      ^;
    } 
    elsif ($self->IsLONGSAGE()) {
      $sql = qq+
select
  d.probe,
  d.replica,
  s.cluster_number
from
  $schema.sagebest_cluster s,
  $schema.sageprotocol p,
  $schema.cgap_2d_color d
where
      s.cluster_number in ($list)
  and s.protocol = p.code
  and p.organism = '$organism'
  and p.protocol in ('LS17')
  and s.tag = d.probe
  and d.experiment_id = $experiment_id
      +;
    } 
    elsif ($self->IsUBCSAGE()) {
      $sql = qq+
select
  d.probe,
  d.replica,
  s.cluster_number
from
  $schema.sagebest_cluster s,
  $schema.sageprotocol p,
  $schema.cgap_2d_color d
where
      s.cluster_number in ($list)
  and s.protocol = p.code
  and p.organism = '$organism'
  and p.protocol in ('LS17')
  and s.tag = d.probe
  and d.experiment_id = $experiment_id
      +;
    }  
    elsif ($self->IsNCI60_U133() or $self->IsNCI60_U95() or $self->IsNCI60_NOVARTIS()) {
      $sql = qq!
select
  d.probe,
  d.replica,
  c.cluster_number
from
  $schema.NCI60_AFFYMETRIX c,
  $schema.cgap_2d_color d
where
      c.cluster_number in ($list)
  and c.probe_set = d.probe
  and d.experiment_id = $experiment_id
      !;
      ## print STDERR "8888: $sql\n";
    }
    else {
      my $table;
      if ($organism eq "Hs") {
        $table = "hs_ug_sequence";
      } else {
        $table = "mm_ug_sequence";
      }
      $sql = qq!
select
  d.probe,
  d.replica,
  c.cluster_number
from
  $schema.$table c,
  $schema.cgap_2d_color d
where
      c.cluster_number in ($list)
  and c.accession = d.probe
  and d.experiment_id = $experiment_id
      !;
    }

    ## print STDERR "8888: $sql\n";
    $stm = $db->prepare($sql);
    if(not $stm) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "prepare call failed\n";
      die "Error: prepare call $sql failed with message $DBI::errstr";
      return undef;
    }
    if(!$stm->execute()) {
      print STDERR "$sql\n";
      print STDERR "$DBI::errstr\n";
      print STDERR "execute call failed\n";
      die "Error: execute call $sql failed with message $DBI::errstr";
      return undef;
    }

    my ($row, $rowcache);
    while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
      for $row (@{ $rowcache }) {
        ($probe, $replica, $cluster_number) = @{ $row };
        if (! $replica) {
          $replica = 0;
        }
        push @{ $$cid2acc_set{$cluster_number} }, $probe . "_" . $replica;
      }
    }
  }
}

######################################################################
sub ColorTheVector {
  my ($self, $acc, $colorscale, $temp) = @_;

  if (not defined $self->{view}) {
    return 0;
  }
  $acc .= '_0' if ($acc !~ /_\d+$/);
  if (not defined $self->{view}{$acc}) {
    return 0;
  }
  if( $self->IsUBCSAGE ) {
    my $total = $self->{num_bioassays}; ## in the end of the line are blank
                                        ## to fill thiese blank
    my $num = 0;
    for my $x (@{ $self->{view}{$acc} }) {
      $num++;
      if ($x eq "") {
        push @{ $temp }, BLACK;
      } else {
        for (my $i = 0; $i < @{ $colorscale }; $i++) {
          if ($x-1 <= $i) {
            push @{ $temp }, $$colorscale[$i];
            last;
          }
        }
      }
    }
    my $diff = $total - $num;
    for( my $i=1; $i<=$diff; $i++ ) {
      push @{ $temp }, BLACK;
    } 
  }
  else {
    for my $x (@{ $self->{view}{$acc} }) {
      if ($x eq "") {
        push @{ $temp }, BLACK;
      } else {
        for (my $i = 0; $i < @{ $colorscale }; $i++) {
          if ($x-1 <= $i) {
            push @{ $temp }, $$colorscale[$i];
            last;
          }
        }
      }
    }
  }
  return 1;
}

######################################################################
sub FindNeighbors {
  my ($self, $accession, $rval, $nvals, $probe_vec,
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

  FetchArray($self, \@empty, \@index, \@ny, \@meany, \@sumsqy, \@stdy, \@array);
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

  if (! defined $probe_vec) {
    return 0;
  }

  ## my $len = LENGTH_OF_ARRARY;
  my $len = scalar($probe_vec) + 2;
  my $ia = cor::double_array($len);
  my $ib = cor::double_array($len);

  for ($i = 0; $i < @index; $i++) {
    if ($probe_i != $i) {
      $gene = $index[$i];
      ($r, $p) = R($probe_vec, $meanx, $sumsqx,
          \@{ $array[$i] }, $meany[$i], $sumsqy[$i], $ia, $ib);
      push @{ $r_vals{$r} }, $gene;
      $pvals{$gene} = $p;
    }
  }

  cor::double_destroy($ia);
  cor::double_destroy($ib);

  my @temp = sort numerically keys %r_vals;

  $n_neighbors = 0;
  for (my $i = $#temp; $i >= 0; $i--) {
    $r = $temp[$i];
    if ($n_neighbors >= $nvals and $r < $pos_rval) {
      last;
    }
    for $gene (@{ $r_vals{$r} }) {
      if( $n_neighbors >= $nvals ) {
        last 
      }
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
      if( $n_neighbors >= $nvals ) {
        last 
      }
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
  my ($x, $mean_x, $sum_x_sq, $y, $mean_y, $sum_y_sq, $ia, $ib) = @_;
 
  my @X = @{$x};
  my @Y = @{$y};
  my $count = 0;
 
  my $total = @X;
 
  my (@x_v, @y_v);
  for (my $i=0; $i<$total; $i++) {
    my $x = $X[$i];
    my $y = $Y[$i];
    cor::double_set($ia,$count,$x); 
    cor::double_set($ib,$count,$y); 
    $count++;
  }
 
  if( $count < 2 ) {
    return (0, 1);
  }

  my $r = cor::cor( $count, $ia, $ib );
 
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
    my $p = GetPvalueForT::GetPvalueForT($t, $count);
    return ($r, $p);
  }
}

######################################################################
sub ByStats {
  my ($self, $nrows, $mean_or_var, $hi_or_lo,
      $cols, $accs, $vals, $vecs) = @_;

  my (%gene2vector, %val2gene, @cols, $col, @vector, @vec2);
  my ($gene, $nx, $meanx, $sumsqx, $stdx);
  my ($nr, $val, @temp);

  my $db            = $self->{db};
  my $schema        = $self->{schema};
  my $experiment_id = $self->{experiment_id};

  my ($sql, $stm);
  my ($probe, $replica, $n_values, $mean, $sum_sq, $stdev, $data);

  $sql = qq!
select
  probe,
  replica,
  n_values,
  mean,
  sum_sq,
  stdev,
  data
from
  $schema.cgap_2d_raw
where
  experiment_id = $experiment_id
  !;

  $stm = $db->prepare($sql);
  if(not $stm) {
    print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print STDERR "prepare call failed\n";
    die "Error: prepare call $sql failed with message $DBI::errstr";
    return undef;
  }
  if(!$stm->execute()) {
     print STDERR "$sql\n";
     print STDERR "$DBI::errstr\n";
     print STDERR "execute call failed\n";
     die "Error: execute call $sql failed with message $DBI::errstr";
     return undef;
  }

  my ($row, $rowcache);
  while ($rowcache = $stm->fetchall_arrayref(undef, MAX_ROWS_PER_FETCH)) {
    for $row (@{ $rowcache }) {
      ($probe, $replica, $n_values, $mean, $sum_sq, $stdev, $data) =
          @{ $row };
      if (! $replica) {
        $replica = 0;
      }
      $gene = $probe . "_" . $replica;
      @vector = split("\t", $data, $TOTAL_COLUMNS);
      $gene2vector{$gene} =  [ \@vector ];  
      if (@{ $cols } == 0) {
        if ($mean_or_var eq "mean") {
          push @{ $val2gene{$mean} }, $gene;
        } else {     ## get std
          push @{ $val2gene{$stdev} }, $gene;
        }
      } else {
        undef @vec2;
        SubSetVector($cols, \@vector, \@vec2);
        if ($mean_or_var eq "mean") {
          $meanx = Mean(\@vec2);
          if (defined $meanx) {
            push @{ $val2gene{$mean} }, $gene;
          }
        } else {     ## get std
          $stdx = StandardDeviation(\@vec2);
          if (defined $stdx) {
	    push @{ $val2gene{$stdev} }, $gene;
          }
        }
      }
    }
  }

  if ($hi_or_lo eq "lo") {
    @temp = sort numerically keys %val2gene;
  } else {
    @temp = sort r_numerically keys %val2gene;
  }
  $nr = 0;
  for $val (@temp) {
    for $gene (@{ $val2gene{$val} }){
      $nr++;
      push @{ $accs }, $gene;
      push @{ $vecs }, $gene2vector{$gene};
      push @{ $vals }, sprintf("%.4f", $val);
    }
    if ($nr > $nrows) {
      last;
    }
  }

}

######################################################################
sub Mean {
  my ($vector) = @_;

  my $n = 0;
  my $total = 0;
  my ($x, $mean);

  for $x (@{ $vector }) {
    if ($x ne "") {
      $n++;
      $total += $x;
    }
  }

  if ($n == 0) {
    return undef;
  } else {
    return $total / $n;
  }

}

######################################################################
sub SubSetVector {
  my ($cols, $invec, $outvec) = @_;

  ## ASSUME: outvec is null on entry
  ## ASSUME: cols is a set, not a bag

  for my $col (@{ $cols }) {
    push @{ $outvec }, $$invec[$col-1];
  }

  return $outvec;
}

######################################################################
sub StandardDeviation {
  my ($vector) = @_;

  my $mean = Mean($vector);
  if (defined $mean) {
    my $n = 0;
    my $sum_squares = 0;
    for my $x (@{ $vector }) {
      if ($x ne "") {
        $sum_squares += ($x - $mean) * ($x - $mean);
        $n++;
      }
    }
    if ($n < 2) {
      return 0;
    } else {
      return sqrt($sum_squares / ($n - 1));
    }
  } else {
    return undef;
  }

}

######################################################################
1;


