#!/usr/local/bin/perl
use strict;
   
sub test {

  my ($agent, $req);

  use LWP::UserAgent;
  use HTTP::Request;
  $agent = new LWP::UserAgent;
  $req = new HTTP::Request ('GET',
  'http://cgap.nci.nih.gov/SAGE/SDGEDResults?PAGE=1&FACTOR=2&CACHE=0&ORG=Hs&PVALUE=.05&CHR=1&ASEQS=0&BSEQS=0&ALIBS=0&BLIBS=0@METHOD=SS10,LS10&SDGED_CACHE=A_14=checked&B_12=checked');
  $agent->request ($req, \&callback);

}
test();
