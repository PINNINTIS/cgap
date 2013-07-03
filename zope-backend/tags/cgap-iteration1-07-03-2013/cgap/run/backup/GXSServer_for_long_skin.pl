#!/usr/local/bin/perl
use strict;

my $COUNT = 3;
   
short_test();

sub short_test {

  my ($agent, $req);

  use LWP::UserAgent;
  use HTTP::Request;
  $agent = new LWP::UserAgent;
  $req = new HTTP::Request ('GET',
  'http://cgap-dev.nci.nih.gov/SAGE/SDGEDResults?WHAT=genes&PAGE=1&FACTOR=3&CACHE=0&ORG=Hs&PVALUE=.05&CHR=All&ASEQS=0&BSEQS=0&ALIBS=2&BLIBS=2&METHOD=LS17&SDGED_CACHE=&A_2279=&B_2265=&B_2263=&A_2269=&A_2281=&B_2285=&A_2271=&A_2283&B_2313=&A_2277=&A_2273=&B_2323=&B_2325=&A_2267=');
  $agent->request ($req, \&callback);

}

sub heavy_test {

  my ($agent, $req);

  use LWP::UserAgent;
  use HTTP::Request;
  $agent = new LWP::UserAgent;
  $req = new HTTP::Request ('GET',
  'http://cgap-dev.nci.nih.gov/SAGE/SDGEDResults?WHAT=genes&PAGE=1&FACTOR=2&CACHE=0&ORG=Hs&PVALUE=.05&CHR=All&ASEQS=0&BSEQS=0&ALIBS=2&BLIBS=2&METHOD=SS10,LS10&SDGED_CACHE=&A_14=&B_12=&A_2262=&A_2258=&A_2312=&A_2260=&A_2310=&A_1367=A_1904&A_384=&A_524=A_139=A_7=&A_346=&A_358&A_526&A_144=&A_351=&A_525=&A_147&A_359&A_283&A_361&A_348&A_345=&A_145&A_151&A_148&A_140&A_343=&A_150=&A_152&A_385=&A_267=&A_347=&A_349=&A_354=&A_344=&A_352=&A_388=&A_355=&A_564=&A_149=&A_350=&A_50=&A_563=&A_138=&A_146=&A_406=&A_356=&A_137=&A_527=&A_4&A_528=&A_357=&A_43=&A_86=&A_54&B_409=&B_404=&B_523=&B_430=&B_421=&B_10=&B_53&B_133=&B_8=&B_55=&B_34&B_11=&B_12=&B_1363=&B_1623=&B_136=&B_94=&B_135=&B_99=&B_405=&B_2306=&B_2180=&B_1963=&B_182=&B_31=&B_669=&B_420=&B_2178=&B_183=&B_47=&B_132=&B_142=');
  $agent->request ($req, \&callback);

}

sub volume_test {

  my ($agent, $req);

  use LWP::UserAgent;
  use HTTP::Request;
  $agent = new LWP::UserAgent;
  $req = new HTTP::Request ('GET',
  'http://cgap-dev.nci.nih.gov/SAGE/SDGEDResults?WHAT=genes&PAGE=1&FACTOR=2&CACHE=0&ORG=Hs&PVALUE=.05&CHR=All&ASEQS=0&BSEQS=0&ALIBS=2&BLIBS=2&METHOD=SS10,LS10&SDGED_CACHE=&A_14=&B_12=&A_2262=&A_2258=&A_2312=&A_2260=&A_2310=&A_1367=A_1904&A_384=&A_524=A_139=A_7=&A_346=&A_358&A_526&A_144=&A_351=&A_525=&A_147&A_359&A_283&A_361&A_348&A_345=&A_145&A_151&A_148&A_140&A_343=&A_150=&A_152&A_385=&A_267=&A_347=&A_349=&A_354=&A_344=&A_352=&A_388=&A_355=&A_564=&A_149=&A_350=&A_50=&A_563=&A_138=&A_146=&A_406=&A_356=&A_137=&A_527=&A_4&A_528=&A_357=&A_43=&A_86=&A_54&B_409=&B_404=&B_523=&B_430=&B_421=&B_10=&B_53&B_133=&B_8=&B_55=&B_34&B_11=&B_12=&B_1363=&B_1623=&B_136=&B_94=&B_135=&B_99=&B_405=&B_2306=&B_2180=&B_1963=&B_182=&B_31=&B_669=&B_420=&B_2178=&B_183=&B_47=&B_132=&B_142=');
  for( my $i=0; $i<$COUNT; $i++ ) {
    $agent->request ($req, \&callback);
  }

}
