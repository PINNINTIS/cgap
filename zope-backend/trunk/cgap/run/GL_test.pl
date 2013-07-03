#!/usr/local/bin/perl
use strict;

my $COUNT = 3;
   
short_test();
heavy_test();
volume_test();

sub short_test {

  my ($agent, $req);

  use LWP::UserAgent;
  use HTTP::Request;
  $agent = new LWP::UserAgent;
  $req = new HTTP::Request ('GET',
  'http://cgap-dev.nci.nih.gov/Tissues/SummaryQuery?PAGE=1&ORG=Hs&SCOPE=cgap&TISSUE=colon&TYPE=&HIST=normal&PROT=&TITLE=&SORT=tissue');
  $agent->request ($req, \&callback);

}

sub heavy_test {

  my ($agent, $req);

  use LWP::UserAgent;
  use HTTP::Request;
  $agent = new LWP::UserAgent;
  $req = new HTTP::Request ('GET',
  'http://cgap-dev.nci.nih.gov/Tissues/SummaryQuery?PAGE=1&ORG=Hs&SCOPE=cgap&SCOPE=mgc&SCOPE=orestes&SCOPE=est&TISSUE=&TYPE=&HIST=&PROT=&TITLE=&SORT=tissue');
  $agent->request ($req, \&callback);

}

sub volume_test {

  my ($agent, $req);

  use LWP::UserAgent;
  use HTTP::Request;
  $agent = new LWP::UserAgent;
  $req = new HTTP::Request ('GET',
  'http://cgap-dev.nci.nih.gov/Tissues/SummaryQuery?PAGE=1&ORG=Hs&SCOPE=cgap&SCOPE=mgc&SCOPE=orestes&SCOPE=est&TISSUE=&TYPE=&HIST=&PROT=&TITLE=&SORT=tissue');
  for(my $i=0; $i<$COUNT; $i++ ) {
    $agent->request ($req, \&callback);
  }

}
