#!/usr/local/bin/perl

######################################################################
# BlastQueryServer.pm
#
# $ARGV[0]: name of file that specifies operating parameters
#
######################################################################

use strict;
use FileHandle;
use CGAPConfig;
use DBI;
use CGI;
use Scan;
use POSIX qw(tmpnam);

use lib "/usr/local/cgap/lib/perl/";

## my $BLAST_DIR = "/usr/local/blast/bin";
my $BLAST_DIR = "/usr/local/blast";

my $query     = new CGI;
my $base      = $query->param("BASE");
my $org       = $query->param("ORG");
my $expect    = $query->param("EXPECT");
my $show      = $query->param("SHOW");
my $seq       = $query->param("SEQ");
 
print "Content-type: text/plain\n\n";
 
Scan($base, $org,$expect,$show,$seq);
print BlastQuery($org, $expect, $show, $seq);

######################################################################
sub GetGenes {
  my ($org, $exp_ref, $acc_ref, $cid_ref) = @_;

  my ($cid, $gene, $desc, %cid2gene, %cid2desc);

##  my $build_id = $BUILDS{$org};

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to databse\n";
    return "";
  }

  my $sql =
      "select distinct cluster_number, gene, description " .
          "from $CGAP_SCHEMA." .
              ($org eq "Hs" ? "hs_cluster" : "mm_cluster") . " " .
          "where cluster_number in (" . join(",", @{ $cid_ref }) . ")";
##      "from rflp.ug_cluster " .
##      "where build_id = $build_id " .
##      "and cluster_number in (" . join(",", @{ $cid_ref }) . ")";

  my $stm = $db->prepare($sql);
  if (not $stm) {
    print "prepare call failed\n";
  } else {
    if ($stm->execute()) {
      while (($cid, $gene, $desc) =
          $stm->fetchrow_array()) {
        $gene or $gene = "-";
        ## bad data from UniGene!!!
        $desc =~ s/\001//g;
        $desc or $desc = "-";
        $cid2gene{$cid} = $gene;
        $cid2desc{$cid} = $desc;
      }
    } else {
      print "execute failed\n";
    }
  }

  $db->disconnect();

  my $table_header = "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr bgcolor=\"#666699\">".
      "<td><font color=\"white\"><b>Accession</b></font></td>".
      "<td><font color=\"white\"><b>E-value</b></font></td>".
      "<td><font color=\"white\"><b>Symbol</b></font></td>".
      "<td><font color=\"white\"><b>Name</b></font></td>" .
      "<td><font color=\"white\"><b>CGAP Gene Info</b></font></td>" .
      "</tr>";

  my @rows;
  for (my $i = 0; $i < @{ $acc_ref }; $i++) {
    push @rows,
      "<tr>" .
      "<td><a href=javascript:spawn(" .
          "\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?" .
          "db=Nucleotide&" .
          "CMD=Search&term=$$acc_ref[$i]\")>$$acc_ref[$i]</a></td>" .
      "<td>$$exp_ref[$i]</td>" .
      "<td>$cid2gene{$$cid_ref[$i]}</td>" .
      "<td>$cid2desc{$$cid_ref[$i]}</td>" .
      "<td><a href=\"GeneInfo?" .
          "ORG=$org&CID=$$cid_ref[$i]\">Gene Info</a></td></tr>";
  }

  unshift @rows, $table_header;
  push @rows, "</table>";
  return join("\n", @rows);
}

######################################################################
sub DoBlast {
  my ($org, $db, $seq, $expect, $show, $cumref) = @_; 

  my ($n);

  my $id = "Query";
  my $query_file = tmpnam();
  open(QUERY_F, ">$query_file") || die;
  printf QUERY_F ">%s\n", $id;
  printf QUERY_F "%s\n", $seq;
  close QUERY_F;

  ## print STDERR "8888: $query_file \n";

  my $outfile = tmpnam();
  ## print STDERR "9999: $outfile \n";
  ## $is_temp = 1;
  my $cmd = "$BLAST_DIR/megablast -D3 -e $expect -i $query_file -d $db -m 8 -o $outfile";
  ## print STDERR "8888: $cmd \n";
  system($cmd);
  ## print STDERR "7777: $cmd \n";

  open( IN, $outfile ) or die "Can not open $outfile \n";
  my ($gb, $ug, $desc, $n, %seen);
  while(<IN>) {
    if( ! ($_ =~ /^Query/) ) {
      next;
    }
    chop;
    ## print STDERR $_;
    my ($Query_id, $Subject_id, $identity, $alignment_length, $mismatches, $gap_openings,        $q_start, $q_end, $s_start, $s_end, $e_value, $bit_score) = split "\t", $_;
    my @tmp = split /\|/, $Subject_id;
    ($gb, $ug ) = split /\#/, $tmp[1];; 
    ## No sense keeping multiple alignments
    ## print STDERR "8888: $gb, $ug\n";
    if (not $seen{$gb}) {
      $seen{$gb} = 1;
      push @{ $$cumref{$e_value} }, "$gb,$ug";
      $n++;
    }
    ##    print STDERR "8888: $gb, $ug \n";
  }
  close IN;
  
  unlink($query_file);
 
  unlink($outfile);

  return $n;
}

######################################################################
sub numerically { $a <=> $b; }

######################################################################
sub BlastQuery {
  my ($org, $expect, $show, $seq) = @_;

  ## print "8888: $expect, $show, $seq\n";
  my ($db, @exps, @accs, @cids, %cumulative_hits, $n);

  if ($org eq "Hs") {
    $db = HS_UG_BLAST;
  } else {
    $db = MM_UG_BLAST;
  }
  $n += DoBlast($org, $db, $seq, $expect, $show, \%cumulative_hits);

  if ($n == 0) {
    return "There are no matches for " .
        "expect = $expect<br><br>";
  }

  for my $e (sort numerically keys %cumulative_hits) {
    for (@{ $cumulative_hits{$e} }) {
      push @exps, $e;
      split ",", $_;
      push @accs, $_[0];
      push @cids, $_[1];
    }
    if (@accs > $show) {
      last;
    }
  }

  return GetGenes($org, \@exps, \@accs, \@cids);

}

#my $aldh3_seq = 'ccaggagccccagttaccgggagaggctgtgtcaaaggcgccatgagcaagatcagcgag';


