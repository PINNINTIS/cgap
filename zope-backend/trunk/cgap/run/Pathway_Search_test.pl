#!/usr/local/bin/perl
use strict;
   
my $COUNT =3;

short_test();
heavy_test();
volume_test();

sub short_test {

  my ($agent, $req);

  use LWP::UserAgent;
  use HTTP::Request;
  $agent = new LWP::UserAgent;
  $req = new HTTP::Request ('GET',
  'http://cgap-dev.nci.nih.gov/Pathways/PathwaysByKeyword?PATH_KEY=tas*');
  $agent->request ($req, \&callback);

}

sub heavy_test {

  my ($agent, $req);

  use LWP::UserAgent;
  use HTTP::Request;
  $agent = new LWP::UserAgent;
  $req = new HTTP::Request ('GET',
  'http://cgap-dev.nci.nih.gov/Pathways/PathwaysByKeyword?PATH_KEY=t*');
  $agent->request ($req, \&callback);

}

sub volume_test {

  my ($agent, $req);

  use LWP::UserAgent;
  use HTTP::Request;
  $agent = new LWP::UserAgent;
  $req = new HTTP::Request ('GET',
  'http://cgap-dev.nci.nih.gov/Pathways/PathwaysByKeyword?PATH_KEY=t*');
  for( my $i=0; $i<$COUNT; $i++ ) {
    $agent->request ($req, \&callback);
  }

}
