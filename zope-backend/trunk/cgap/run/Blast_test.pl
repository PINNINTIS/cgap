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
  'http://cgap-dev.nci.nih.gov/Genes/GeneBySeq?DB=ug&ORG=Hs&EXPECT=0.01&SHOW=200&SEQ=atgctgctct+gcacggctcg+cctggtcggc+ctgcagcttc+tcatttcctg+ctgctgggcc&Submit=Search');
  $agent->request ($req, \&callback);

}

sub heavy_test {

  my ($agent, $req);

  use LWP::UserAgent;
  use HTTP::Request;
  $agent = new LWP::UserAgent;
  $req = new HTTP::Request ('GET',
    'http://cgap-dev.nci.nih.gov/Genes/GeneBySeq?DB=ug&ORG=Hs&EXPECT=0.01&SHOW=200&SEQ=atgctgctct+gcacggctcg+cctggtcggc+ctgcagcttc+tcatttcctg+ctgctgggcc%0D%0A+++++++61+tttgcctgcc+atagcacgga+gtcttctcct+gacttcaccc+tccccggaga+ttacctcctg%0D%0A++++++121+gcaggcctgt+tccctctcca+ttctggctgt+ctgcaggtga+ggcacagacc+cgaggtgacc%0D%0A++++++181+ctgtgtgaca+ggtcttgtag+cttcaatgag+catggctacc+acctcttcca+ggctatgcgg%0D%0A++++++241+cttggggttg+aggagataaa+caactccacg+gccctgctgc+ccaacatcac+cctggggtac%0D%0A++++++301+cagctgtatg+atgtgtgttc+tgactctgcc+aatgtgtatg+ccacgctgag+agtgctctcc%0D%0A++++++361+ctgccagggc+aacaccacat+agagctccaa+ggagaccttc+tccactattc+ccctacggtg%0D%0A++++++421+ctggcagtga+ttgggcctga+cagcaccaac+cgtgctgcca+ccacagccgc+cctgctgagc%0D%0A++++++481+cctttcctgg+tgcccatgat+tagctatgcg+gccagcagcg+agacgctcag+cgtgaagcgg&Submit=Search');
  $agent->request ($req, \&callback);

}

sub volume_test {

  my ($agent, $req);

  use LWP::UserAgent;
  use HTTP::Request;
  $agent = new LWP::UserAgent;
  $req = new HTTP::Request ('GET',
    'http://cgap-dev.nci.nih.gov/Genes/GeneBySeq?DB=ug&ORG=Hs&EXPECT=0.01&SHOW=200&SEQ=atgctgctct+gcacggctcg+cctggtcggc+ctgcagcttc+tcatttcctg+ctgctgggcc%0D%0A+++++++61+tttgcctgcc+atagcacgga+gtcttctcct+gacttcaccc+tccccggaga+ttacctcctg%0D%0A++++++121+gcaggcctgt+tccctctcca+ttctggctgt+ctgcaggtga+ggcacagacc+cgaggtgacc%0D%0A++++++181+ctgtgtgaca+ggtcttgtag+cttcaatgag+catggctacc+acctcttcca+ggctatgcgg%0D%0A++++++241+cttggggttg+aggagataaa+caactccacg+gccctgctgc+ccaacatcac+cctggggtac%0D%0A++++++301+cagctgtatg+atgtgtgttc+tgactctgcc+aatgtgtatg+ccacgctgag+agtgctctcc%0D%0A++++++361+ctgccagggc+aacaccacat+agagctccaa+ggagaccttc+tccactattc+ccctacggtg%0D%0A++++++421+ctggcagtga+ttgggcctga+cagcaccaac+cgtgctgcca+ccacagccgc+cctgctgagc%0D%0A++++++481+cctttcctgg+tgcccatgat+tagctatgcg+gccagcagcg+agacgctcag+cgtgaagcgg&Submit=Search');
  for( my $i=0; $i<$COUNT; $i++ ) { 
    $agent->request ($req, \&callback);
  }

}

