#!/usr/local/bin/perl

use strict;

## input is 8 columns:
##   tag
##   chromosome
##   bp
##   strand
##   tag ordinal
##   raw freq
##   normalized freq
##   smoothed value

my ($DEL_WIDTH,
    $DEL_THRESHHOLD) = (50, 0.1);
my ($AMP_WIDTH,
    $AMP_THRESHHOLD) = (75, 7);
##     $AMP_THRESHHOLD) = (50, 3);

my ($inp_f, $out_f);
my $in  = \*STDIN;
my $out = \*STDOUT;
my (%data, %del_detect, %amp_detect);
my %ord2bp;

ReadOptions();

my $DEL_AREA = $DEL_WIDTH * $DEL_THRESHHOLD;
my $AMP_AREA = $AMP_WIDTH * $AMP_THRESHHOLD;

if ($inp_f) {
  open(INF, $inp_f) or die "cannot open $inp_f";
  $in = \*INF;
}

ReadData($in);

if ($inp_f) {
  close $in;
}

if ($out_f) {
  open(OUT, ">$out_f") or die "cannot open $out_f";
  $out = \*OUT;
}

Analyze();

for my $chr (keys %amp_detect) {

  my ($start_amp, $last_amp) = (0, 0);

  for my $ord (@{ $amp_detect{$chr} }) {
    if (! $start_amp) {
      $start_amp = $ord;
    } elsif ($ord == $last_amp + 1) {
    } else {
      print $out "amp\t$chr\t$start_amp\t$last_amp\t$ord2bp{$start_amp}\t$ord2bp{$last_amp}\n";
      $start_amp = 0;
    }
    $last_amp = $ord;
#    print $out "amp\t$chr\t$ord\n";
  }
  if ($start_amp) {
    print $out "amp\t$chr\t$start_amp\t$last_amp\t$ord2bp{$start_amp}\t$ord2bp{$last_amp}\n";
    $start_amp = 0;
  }

}

for my $chr (keys %del_detect) {

  my ($start_del, $last_del) = (0, 0);

  for my $ord (@{ $del_detect{$chr} }) {
    if (! $start_del) {
      $start_del = $ord;
    } elsif ($ord == $last_del + 1) {
    } else {
      print $out "del\t$chr\t$start_del\t$last_del\t$ord2bp{$start_del}\t$ord2bp{$last_del}\n";
      $start_del = 0;
    }
    $last_del = $ord;
#    print $out "del\t$chr\t$ord\n";
  }
  if ($start_del) {
    print $out "del\t$chr\t$start_del\t$last_del$ord2bp{$start_del}\t$ord2bp{$last_del}\n";
    $start_del = 0;
  }

}

if ($out_f) {
  close $out;
}

######################################################################
sub AnalyzeChr {
  my ($chr, $v) = @_;

  my ($amp, $del);
  my ($x);
  my (@del_queue, @amp_queue);

  for (my $i = 1; $i < @{ $v }; $i++) {
    $x = $$v[$i];

    if ($i > $DEL_WIDTH) {
      $del -= shift @del_queue;
    }
    push @del_queue, $x;
    $del += $x;
    if ($i >= $DEL_WIDTH && $del <= $DEL_AREA) {
      push @{ $del_detect{$chr} }, $i;    ## or should it be $ord - half of ...
    }

    if ($i > $AMP_WIDTH) {
      $amp -= shift @amp_queue;
    }
    push @amp_queue, $x;
    $amp += $x;
    if ($i >= $AMP_WIDTH && $amp >= $AMP_AREA) {
      push @{ $amp_detect{$chr} }, $i;    ## or should it be $ord - half of ...
    }

  }
}

######################################################################
sub Analyze {
  for my $chr (keys %data) {
    AnalyzeChr($chr, $data{$chr});
  }
}

######################################################################
sub ReadData {
  my ($in) = @_;
  my ($tag, $chr, $bp, $strand, $ord, $raw_f, $norm_f, $smoothed_f);
  while (<$in>) {
    s/[\r\n]+//;
    ($tag, $chr, $bp, $strand, $ord, $raw_f, $norm_f, $smoothed_f) =
        split /\t/;
    if (! defined $data{$chr}) {
      $data{$chr} = [];
    }
    $data{$chr}[$ord] = $smoothed_f;
    $ord2bp{$ord} = $bp;
  }
}

######################################################################
sub ReadOptions {

  use Getopt::Long;

  my ($del_width, $amp_width, $del_threshhold, $amp_threshhold);

  GetOptions (
    "i:s"         => \$inp_f,
    "o:s"         => \$out_f,
    "dw=i"        => \$del_width,
    "aw=i"        => \$amp_width,
    "dt=f"        => \$del_threshhold,
    "at=f"        => \$amp_threshhold
  ) or die "exiting";

  if ($del_width) {
    $DEL_WIDTH = $del_width;
  }
  if ($amp_width) {
    $AMP_WIDTH = $amp_width;
  }
  if ($del_threshhold) {
    $DEL_THRESHHOLD = $del_threshhold;
  }
  if ($amp_threshhold) {
    $AMP_THRESHHOLD = $amp_threshhold;
  }


}


