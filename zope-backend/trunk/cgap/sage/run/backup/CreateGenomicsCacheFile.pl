#!/usr/local/bin/perl

#####################################################################
# CreateGenomicsCacheFile.pl

use strict;
use DBI;
use CGAPConfig;
use Cache;

BEGIN {
  push @INC, "/share/content/CGAP/SAGE/run";
}


my $BASE;

my $cache = new Cache(CACHE_ROOT, GENOMICS_CACHE_PREFIX);

my $file_dir = INIT_SAGE_DATA_HOME . "sage_upload";
my $tmp_file_dir = INIT_SAGE_DATA_HOME . "tmp_upload";

GetBatchGenomics();

######################################################################
sub GetBatchGenomics {

  my (%tag2allinfo, %chr_position2allinfo);
  my (@all_lines, @good_lines, @no_result_lines);
 
  my ($list);
  my ($sql, $stm);
  my %goodInput;
  my @garbage;
  my $count;
 
  my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    return "";
  }
 
  opendir (DATADIR, $file_dir) or die "Can not open $file_dir \n";
  while( my $filename = readdir(DATADIR) ) {
    if( !($filename =~ /^\./) ) {
      if( $filename =~ /\.txt$/ ) {
        my $full_filename = $file_dir . "/" . $filename;
        my $tmp_filename = $tmp_file_dir . "/" . $filename;
        print "8888: $full_filename 8888\n";
        print "8888: $tmp_filename 8888\n";
        my $cmd = "mv $full_filename $tmp_filename";
        print "8888: $cmd 8888\n";
        system($cmd);
        process_file($tmp_filename);      
      }
    }
  }
 
}

######################################################################
sub WriteGenomicsToCache {
  my ($data) = @_;
 
  my ($genomics_cache_id, $filename) = $cache->MakeCacheFile();
  if ($genomics_cache_id != $CACHE_FAIL) {
    if (open(SOUT, ">$filename")) {
      print SOUT $data;
      close SOUT;
      chmod 0666, $filename;
    } else {
      $genomics_cache_id = 0;
    }
  }
  return $genomics_cache_id;
}

######################################################################
sub process_file {
  my ($file) = @_;
  print "8888: $file\n";
  my ($sql, $stm, $list);
  my (%tag2allinfo, %chr_position2allinfo); 
  my (@all_lines, @good_lines, @no_result_lines);
  my $FILE_ID;
  my %tags;
  my $count = 0;
  my ($org, $order, $email);
  my $db = DBI->connect("DBI:Oracle:" . $$DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    print STDERR "Cannot connect to " .$DB_USER . "@" . $$DB_INSTANCE . "\n";
    return "";
  }

  open(IN, $file) or die "Can not open file $file\n";
  while( <IN> ) {
    chop;
    if( $count > 2 ) {
      push @all_lines, $_;
    }
    if( $count == 0 ) {
      $org = $_;
    }
    elsif( $count == 1 ) {
      $order = $_;
    }
    elsif( $count == 2 ) {
      $email = $_;
    }
    $count++;
  }

  print "8888: $org, $order, $email\n";
  my $genomics_table = ($org eq "Hs" ? " $CGAP_SCHEMA.sagegenomicshs " : " $CGAP_SCHEMA.sagegenomicsmm ");
 
  for(my $i = 0; $i < @all_lines; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @all_lines) {
       $list ="'" . join("', '", @all_lines[$i..$i+ORACLE_LIST_LIMIT-1]) . "'";
    }
    else {
      $list = "'" . join("', '", @all_lines[$i..@all_lines-1]) . "'";
    }
    $list = "'" . join("', '", @all_lines[1..20]) . "'";
 
    $sql =
      "select TAG, CHROMOSOME, START_POSITION, STRAND " .
      "from $genomics_table " .
      "where tag in ( $list )";
 
    $stm = $db->prepare($sql);
    if ($stm->execute()) {
      my ($TAG, $CHROMOSOME, $START_POSITION, $STRAND );
      $stm->bind_columns(\$TAG, \$CHROMOSOME, \$START_POSITION, \$STRAND);
      while($stm->fetch()) {
        $tags{$TAG} = 1;
        if( $order eq "Original" ) {
          $tag2allinfo{$TAG}{$CHROMOSOME}{$START_POSITION}{$STRAND} =
                   join "\t", $TAG, $CHROMOSOME, $START_POSITION, $STRAND;
        }
        else {
          if( $CHROMOSOME eq "X" ) {
            $chr_position2allinfo{23}{$START_POSITION}{$STRAND} =
                  join "\t", $TAG, $CHROMOSOME, $START_POSITION, $STRAND;
          }
          elsif( $CHROMOSOME eq "Y" ) {
            $chr_position2allinfo{24}{$START_POSITION}{$STRAND} =
                  join "\t", $TAG, $CHROMOSOME, $START_POSITION, $STRAND;
          }
          else {
            $chr_position2allinfo{$CHROMOSOME}{$START_POSITION}{$STRAND} =
                  join "\t", $TAG, $CHROMOSOME, $START_POSITION, $STRAND;
          }
        }
      }
    }
    else {
      print STDERR "$sql\n";
      print STDERR "execute call failed\n";
      return "";
    }
  }
 
  $db->disconnect();

  print "8888: finish sql\n";
  if( $order eq "Original" ) {
    for( my $i=0; $i<@all_lines; $i++ ) {
      if( defined $tag2allinfo{$all_lines[$i]} ) {
        for my $chr (sort numerically keys %{$tag2allinfo{$all_lines[$i]}}) {
          for my $pos (sort numerically keys %{$tag2allinfo{$all_lines[$i]}{$chr}}) {
            for my $strand (sort keys %{$tag2allinfo{$all_lines[$i]}{$chr}{$pos}}) {
              push @good_lines, $tag2allinfo{$all_lines[$i]}{$chr}{$pos}{$strand} . "\n";
              my ($TAG, $CHROMOSOME, $START_POSITION, $STRAND) = 
                 split "\t", $tag2allinfo{$all_lines[$i]}{$chr}{$pos}{$strand}; 
              delete $tags{$TAG};  
            }
          }
        }
      }
      else {
        push @no_result_lines, "$all_lines[$i]\n";
      }
    }
  }
  else {
    for my $chr (sort numerically keys %chr_position2allinfo ) {
      for my $pos (sort numerically keys %{$chr_position2allinfo{$chr}}) {
        for my $strand (sort numerically keys %{$chr_position2allinfo{$chr}{$pos}}) {
          push @good_lines, $chr_position2allinfo{$chr}{$pos}{$strand} . "\n";
        }
      }
    }
    for my $tag ( sort keys %tags ) {
      push @no_result_lines, $tag . "\n";
    }
  }

  my $lines;
  for( my $i=0; $i<@good_lines; $i++ ) {
    $lines = $lines . $good_lines[$i] . "\n";
  }

  for( my $i=0; $i<@no_result_lines; $i++ ) {
    $lines = $lines . $no_result_lines[$i] . "\n";
  }

  my $sagegenomics_cache = WriteGenomicsToCache($lines);
  open(MAIL, "|/usr/lib/sendmail -t");
  print MAIL "To: $email\n";
  print MAIL "From: wuko\@mail.nih.gov\n";
  print MAIL "Subject: Batch Genomics\n";
  print MAIL "This is the url http://cgap-dev.nci.nih.gov/SAGE/GetGenomicsFile?CACHE=$sagegenomics_cache to get your file by click this highperlink.\n";
  close (MAIL);
 
}
######################################################################
sub numerically { $a <=> $b };
sub r_numerically { $b <=> $a };

######################################################################
