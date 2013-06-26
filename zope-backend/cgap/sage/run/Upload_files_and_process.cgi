#!/usr/local/bin/perl

######################################################################
# Upload_files_and_process.cgi
#

use strict;
use CGI;
use CGAPConfig;
use Cache;
use Archive::Extract;
use Getopt::Long;

print "Content-type: text/plain\n\n";
my $upload_cache = new Cache(CACHE_ROOT, UPLOAD_CACHE_PREFIX);
my $CACHE_FAIL = 0;
my $LONG_LINKER_FILE = "/share/content/CGAP/SAGE/data/Linkers_17.txt";
my $SHORT_LINKER_FILE = "/share/content/CGAP/SAGE/data/Linkers_10.txt";
my $SEP              = "CATG";
my $R_SEP            = "GTAC";  #reverse but not complemented
my $SL               = length($SEP);

## print "Content-type: text/plain\n\n";
## print "Content-type: application/x-zip\n\n";

my $query       = new CGI;
## my $file_type   = $query->param("FILE_TYPE");
my $linkers   = $query->param("linkers");
my $filepath_1    = $query->param("filenameFILE[0]");
my $filedata_1    = $query->upload("filenameFILE[0]");
my $filepath_2;
my $filedata_2;
if ( $linkers eq "User" ) {
  $filepath_2    = $query->param("filenameFILE[1]");
  $filedata_2    = $query->upload("filenameFILE[1]");
}
my $TAG_LENGTH       = $query->param("LENGTH");
my $TRIM_LENGTH  = $query->param("TRIM_LENGTH");
my $MAX_DITAG_LENGTH = $query->param("MAX_DITAG_LENGTH");
my $MIN_DITAG_LENGTH  = $query->param("MIN_DITAG_LENGTH");
my $filename_1;
my $filename_2;

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
    $head_tags, $tail_tags, $total_seqs, $total_unique_tags);
my %linker_variation;
 
my ($linker_f, $tag_length, $trim_length,
    $max_ditag_length, $min_ditag_length);

if( $filepath_1 eq "" ) {
  print_out ("Please go to step 2  to fill file name.");
}
elsif( $linkers eq "User" and $filepath_2 eq "" ) {
  print_out ("Please go to step 3 to fill file name.");
}
elsif( $TRIM_LENGTH eq "" ) {
  print_out ("Please go to step 5 to fill trim sequence length.");
}
elsif( $MAX_DITAG_LENGTH eq "" ) {
  print_out ("Please go to step 6 to fill maximum ditag length.");
}
elsif( $MIN_DITAG_LENGTH eq "" ) {
  print_out ("Please go to step 7 to fill minimum ditag length.");
}
else {

  my ($cache_id, $cache_dir_name) = $upload_cache->MakeCacheFile();
  if ($cache_id == $CACHE_FAIL) {
    print "Failed to make Upload cache. <br>";
  }

  mkdir $cache_dir_name;
  chmod 0777, $cache_dir_name;

  if ($filepath_1 =~ /\//) { 
    my @path_elem1 = split /\//, $filepath_1;
    $filename_1 =$path_elem1[$#path_elem1];
  } 
  elsif ($filepath_1 =~ /\\/) { 
    my @path_elem2 = split /\\/, $filepath_1;
    $filename_1=$path_elem2[$#path_elem2];
  } 
  else {   
    $filename_1=$filepath_1;
  }

  if ( $linkers eq "User" ) {
    while ( <$filedata_2> ) {
      chop;
      s/\s+//g;
      s/\d+$//g;
      $linker_variation{$_} = 1;
    }
    close ($filedata_2);
  }
  elsif ( $linkers eq "Server" ) {
    if( $TAG_LENGTH == 17 ) {
      ReadLinkerVariations($LONG_LINKER_FILE);
    }
    elsif( $TAG_LENGTH == 10 ) {
      ReadLinkerVariations($SHORT_LINKER_FILE);
    }
  }

  my $up_file = $cache_dir_name . "/" . $filename_1;
  open( FOUT, ">$up_file") || die "Can not open $cache_dir_name";
  binmode FOUT;
  my $buff;
  my $byte_size;
 
  while( $byte_size = read($filedata_1, $buff, 2096) ) {
    print FOUT $buff;
  }
  close FOUT;
  chmod 0777, $up_file;

  my $ae = Archive::Extract->new( archive =>$up_file );
  my $ok = $ae->extract( to=>$cache_dir_name ) or die $ae->error;

  ProcessExtraction($cache_dir_name, $linkers);

  my $cmd = "rm -r $cache_dir_name";
  system($cmd);

  ## print_out ("$file_type: $filepath_1 and $filepath_2 ( $filename_1 and $filename_2 ) have been uploaded successfully.");

} 

#######################################################################
sub print_out {
  my ($message) = @_;
  print $message . "\n";
}
#######################################################################
sub get_today_date {
  my $time_ins=`date`;
  my @time=split(/ +/,$time_ins);

  if(length($time[2]) < 2)
  {
    $time[2] = "0" . $time[2];
  }

  chop($time[5]);
  ## my $year = substr $time[5], 2;

  my $date="$time[1]_$time[2]_$time[5]";
  return $date;
}

#######################################################################
sub ProcessExtraction {
  my ($cache_dir_name, $linkers) = @_;
  opendir (DATADIR, $cache_dir_name) or die "Can not open $cache_dir_name \n";
  while( my $filename = readdir(DATADIR) ) {
    if( !($filename =~ /^\./) ) {
      if ($filename =~ /\.gz$/ or $filename =~ /\.zip$/) {
        next;
      }
      if($filename =~ /\.seq$/) {
        my $full_filename = $cache_dir_name . "/" . $filename;
        chmod 0777, $full_filename;
        open( IN, $full_filename ) or die "Can not open file $full_filename\n";
        while (<IN>) {
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
        close (IN);
        ProcessSequence($id, join("", @lines));
      }
      else {
        my $full_dir = $cache_dir_name . "/" . $filename;
        ## print "8888: $full_dir \n";
        opendir (DIR, $full_dir) or die "Can not open $full_dir \n";
        while( my $filename = readdir(DIR) ) {
          if( !($filename =~ /^\./) ) {
            if($filename =~ /\.seq$/) {
              my $full_filename = $full_dir . "/" . $filename;
              ## print "8888: $full_filename \n";
              chmod 0777, $full_filename;
              open( IN, $full_filename ) or die "Can not open file $full_filename\n";
              while (<IN>) {
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
              close (IN);
              ProcessSequence($id, join("", @lines));
              undef @lines;
            }
          }
        }
        close (DIR);
      }
    }
  }
  ProcessDitags();
  Not_PrintTags(); ## for PrintSummaryNumbers
  PrintSummaryNumbers($linkers);
  PrintTags();
}

######################################################################
sub PrintSummaryNumbers {
  my ($linkers) =@_; 

  print "The parameters:\n";
  print "#tag length     = $TAG_LENGTH\n";
  print "#trim length     = $TRIM_LENGTH\n";
  print "#maximum ditag length     = $MAX_DITAG_LENGTH\n";
  print "#minimum ditag length     = $MIN_DITAG_LENGTH\n";
  print "\n";
  print "The results:\n";
  print "#total sequences = $total_seqs\n";
  print "#total good ditags = $good_ditags\n";
  print "#total long ditags = $long_ditags\n";
  print "#total short ditags = $short_ditags\n";
  print "#total duplicate ditags = $duplicate_ditags\n";
  print "#total good tags = $total_good_tags\n";
  if( $linkers eq "User" or $linkers eq "Server" ) {
    print "#total linker variations = $total_linker_variations\n";
    print "#total good tags excluding linkers = " .
       ($total_good_tags - $total_linker_variations) . "\n";
  }
  print "#total unique good tags = $total_unique_tags\n";
  ## print "#total good tags from ditags = " .
  ##     ($total_good_tags - $head_tags - $tail_tags) . "\n";
  ## print "#total good tags from head = $head_tags\n";
  ## print "#total good tags from tail = $tail_tags\n";
  print "#total bad tags = $total_bad_tags\n";

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
sub Not_PrintTags {
  for my $tag (keys %tags) {
    $total_good_tags += $tags{$tag};
    if (defined $linker_variation{$tag}) {
      ## print "#linker variation: $tag $tags{$tag}\n";
      $total_linker_variations += $tags{$tag};
    } 
    else {
      $total_unique_tags++;
    }
  }
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

  $total_seqs++;

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

######################################################################


