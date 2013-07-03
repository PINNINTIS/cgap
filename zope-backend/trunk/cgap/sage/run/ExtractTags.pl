
use Getopt::Long;

my %complement = (
  "a" => "t",
  "c" => "g",
  "g" => "c",
  "t" => "a",
  "A" => "T",
  "C" => "G",
  "G" => "C",
  "T" => "A"
);

my ($n, $id, $seq, @lines, %ditags, %tags);
my ($good_ditags, $long_ditags, $short_ditags, $duplicate_ditags,
    $total_linker_variations, $total_good_tags, $total_bad_tags,
    $head_tags, $tail_tags);
my %linker_variation;

my ($linker_f, $tag_length, $trim_length,
    $max_ditag_length, $min_ditag_length); 


while (<>) {
  if (/^>/) {
    ProcessSequence($id, join("", @lines));
    undef @lines;
    $n++;
    s/^>\s+/>/;
    if (/>(\w+)/) {
      $id = $1;
    } else {
      ## print "#no id for $_";
      $id = "[$n]";
    }
  } else {
    s/\r//;
    s/\n//;
    push @lines, uc($_);
  }
}
ProcessSequence($id, join("", @lines));

ProcessDitags();
PrintSummaryNumbers();
PrintTags();

######################################################################
sub PrintSummaryNumbers {

  print "#total good ditags = $good_ditags\n";
  print "#total long ditags = $long_ditags\n";
  print "#total short ditags = $short_ditags\n";
  print "#total duplicate ditags = $duplicate_ditags\n";
  print "#total linker variations = $total_linker_variations\n";
  print "#total good tags from ditags = " .
      ($total_good_tags - $head_tags - $tail_tags) . "\n";
  print "#total good tags from head = $head_tags\n";
  print "#total good tags from tail = $tail_tags\n";
  print "#total good tags = $total_good_tags\n";
  print "#total bad tags = $total_bad_tags\n";
}

######################################################################
sub ReadOptions {


  my ($linker_f, $tag_length, $trim_length, 
      $max_ditag_length, $min_ditag_length) = @_;
  GetOptions (
    "linker:s"         => \$linker_f,
    "taglength=i"      => \$tag_length,
    "trimlength=i"     => \$trim_length,
    "maxditaglength=i" => \$max_ditag_length,
    "minditaglength=i" => \$min_ditag_length
  ) or die "exiting";

  if ($linker_f) {
    ReadLinkerVariations($linker_f);
  }
  if ($trim_length) {
    $TRIM_LENGTH = $trim_length;
  }
  if ($tag_length) {
    $TAG_LENGTH = $tag_length;
  }
  if ($max_ditag_length) {
    $MAX_DITAG_LENGTH = $max_ditag_length;
  } elsif ($tag_length) {
    $MAX_DITAG_LENGTH = $tag_length * 2 + 4;     
  }
  if ($min_ditag_length) {
    $MIN_DITAG_LENGTH = $min_ditag_length;
  } elsif ($tag_length == 17) {
    $MIN_DITAG_LENGTH = $tag_length * 2 - 2;     
  }

}

######################################################################
sub ReadLinkerVariations {
  my ($f) = @_;

  open(INF, $f) or die "cannot open $f";
  while (<INF>) {
    chop;
    s/\s+//g;
    $linker_variation{$_} = 1;    
  }
  close INF;
}


######################################################################
sub PrintTags {
  for my $tag (keys %tags) {
    $total_good_tags += $tags{$tag};
    if (defined $linker_variation{$tag}) {
      ## print "#linker variation: $tag $tags{$tag}\n";
      $total_linker_variations += $tags{$tag};
    } else {
     print "$tag\t$tags{$tag}\n";
    }
  }
}

######################################################################
sub Reverse {
  my ($x) = @_;

  my (@y);
  for my $y (split("", $x)) {
    if (defined $complement{$y}) {
      unshift @y, $complement{$y};
    } else {
      unshift @y, $y;
    }
  }
  return join("", @y);
}

######################################################################
sub ProcessSequence {
  my ($id, $seq) = @_;

  if (! $seq) {
    return;
  }

  if (length($seq) > $TRIM_LENGTH) {
    ## print "#trimming [$id] to $TRIM_LENGTH, original length = " .
    ##   length($seq) . "\n";
    $seq = substr($seq, 0, $TRIM_LENGTH);
  }

  my (@forward);
  my ($i,  $j);
  my ($pi, $pj);
  my ($n, $len, $ditag);

  $i = -1;
  while (1) {
    $i = index($seq, $SEP, $i+1);
    if ($i < 0) {
      last;
    }
    push @forward, $i;
  }

  $i  = 0;
  while ($i < @forward - 1) {
    $n = $i + 1;
    $j  = $i + 1;
    $pi = $forward[$i]; $pj = $forward[$j];
    $len = $pj - $pi - $SL;;
    $ditag = substr($seq, $pi + $SL, $len);
    if ($len > $MAX_DITAG_LENGTH) {
      # ditag too long
      $long_ditags++;
      ####  print "#long ditag [$id] $n: $ditag length = $len\n";
    } elsif ($len < $MIN_DITAG_LENGTH) {
      # ditag too short
      $short_ditags++;
      ####  print "#short ditag [$id] $n: $ditag length = $len\n";
    } else {
      $good_ditags++;
      ####  print "#good ditag [$id] $n: $ditag length = $len\n";
      ##
      ## It might be a duplicate in reverse
      ##
      if (defined $ditags{Reverse($ditag)}) {
        ####  print "#reversing $ditag\n";
        $ditag = Reverse($ditag);
      }
      $ditags{$ditag}++;
    }
    $i++;
  }

}

######################################################################
sub ProcessDitags {

  my ($ditag, $freq, $left, $right);

  while (($ditag, $freq) = each %ditags) {
    ## print "8888\t$ditag\t$freq\n";
    if ($freq > 1) {
      ####  print "#duplicate ditag: $ditag $freq\n";
      $duplicate_ditags += $freq - 1;
    }
    ($left, $right) = (substr($ditag,            0, $TAG_LENGTH),
               Reverse(substr($ditag, -$TAG_LENGTH, $TAG_LENGTH)));
    if ($right !~ /^[ACTG]+$/) {
      ####  print "#bad right-hand tag: $right\n";
      $total_bad_tags++;
    } else {
      $tags{$right}++;
    }
    if ($left  !~ /^[ACTG]+$/) {
      ####  print "#bad left-hand tag: $left\n";
      $total_bad_tags++;
    } else {
      $tags{$left}++;
    }
  }
}

