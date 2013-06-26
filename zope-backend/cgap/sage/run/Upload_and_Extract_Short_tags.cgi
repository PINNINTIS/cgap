#!/usr/local/bin/perl

######################################################################
# Upload_and_Extract_Short_tags.cgi
#

use strict;
use CGI;
use CGAPConfig;
use Cache;
## use Archive::Extract;
use Getopt::Long;


print "Content-type: text/plain\n\n";
my $query       = new CGI;
my $filepath    = $query->param("filenameFILE");
my $filedata    = $query->upload("filenameFILE");

Extract_short_tags($filedata);

#######################################################################
sub Extract_short_tags {
  my ($filedata) = @_;
  my %tag2freq;

  while ( <$filedata> ) {
    chop;
    my ($tag, $freq) = split "\t", $_;
    my $short_tag = substr($tag, 0, 10);
    if( not defined $tag2freq{$short_tag} ) {
        $tag2freq{$short_tag} = $freq ;
    }
    else {
      $tag2freq{$short_tag} = $tag2freq{$short_tag} + $freq ;
    }
  }
  close ($filedata);

  my $unique_count = 0;
  my $freq_count = 0;
  for my $tag (sort keys %tag2freq) {
    $unique_count++;
    $freq_count = $freq_count + $tag2freq{$tag};
    print join ("\t", $tag, $tag2freq{$tag}) . "\n";
  }
 
  print "Total unique tags = $unique_count \n";
  print "Total tag frequences = $freq_count \n";

} 

#######################################################################
