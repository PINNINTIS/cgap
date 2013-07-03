#!/usr/local/bin/perl
use strict;
   
#!/usr/local/bin/perl
 
######################################################################
# SummarizeGOForGeneSet.pl
######################################################################
 
use strict;
use DBI;
use CGI;
 
 
BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
 
use CGAPConfig;
use GOBrowser_2;
 
  my $CIDS = "116724,25527,323342,433307,675718,448664,694070,241421,592212,702377,563491,434123,282997,654496,192492,556754,522847,461138,522846,678973,592038,193857,369380,567880,310453,654752,655734,483512,532781,461954,525198,389457,434693,466531,375030,272382,679662,248198,434196,350571,434116,2563,9730,652130,279245,501252,699946,104019,654419,88372,942,699160,23582,435967,500066,386390,158560,705378,112444,530251,632426,402752,153088,654508,153022,591086,122752,18857,369519,96103,270621,489309,131846,438838,223806,520122,653163,592248,702057,643614,552273,640299,529984,632099,517168,169330,247978,438678,158728,410889,556496,631758,291623,644420,352018,502,370937,504597,479223,498115,326,300624,534032,481860,288974,657163,124574,553548,74375,567492,533756,679407,408153,679406,272395,676011,647085,553660,669863,352241,650648,553716,688195,688197,287378,688193,679464,687025,688196,686384,675370,688194,688222,533754,533755,272391,369932,640471,705386,170568,475401,530538,34576,12956,409911,176503,655273,699204,534648,500598,3376,518611,284630,369819,631587,479403,371016,590876,124512,435044,485270,477003,353087,30619,567426,617010,677656,454716,661995,631531,105891,655470,448884,210891,475629,484678,442657,351798,480819,694161,155829,291212,31053,75064,518469,464391,498143,632108,505874,607889,94790,699315,581171,664560,647044,513267,590872,486507,528278,210862,436410,231411,173984,454480,146196,251830,645440,705451,404167,272409,374253,129895,143907,381715,198301,442530,520757,510262,629177,514146,491745,505004,446354,95243,401835,311776,194329,403462,447815,21861,389734,554594,172772,584806,621226,375035,515381,631674,631677,443465,126575,511504,437,584807,475018,78061,591583,415342,371282,644653,573153,516297,593995,699411,432416,553300,546477,410924,495985,2484,632346,510368,2012,417948,519672,605019,363137,351,119929,42034,435371,655341,696047,648100,517962,189183,584808,479226,585137,211511,694390,167165,438991,662323,584809,385870,592361,517962,189183,584808,479226,585137,694390,211511,167165,438991,662323,584809,385870,592361,583896,183671,209945,333132,387671,646351,525061,197354,656983,193842,21454,144439,655331,515534,485205,94865,479670,248162,348615,156977,181159,35052,89640,462108,127111,414648,631517,143519,271044,343334,6147,508835,132976,436182,442707,63335,301419,492203,664957,592286,525709,699324,591499,585127,667712,632581,494648,97978,121776,524039,567543,333130,390221,571446,458316,175414,516087,517864,115365,662202,672606,511476,518267,642966,519880,33102,473152,434107,567844,513305,279908,699156,156471,79353,379018,142908,274184,485360,705396,125962,162807,2979,82961,518123,20225,516578,438231,590939,544932,529618,654591,12393,170009,645227,513530,133379,592317,645734,369397,494622,82028,604277,482390,446350,373550,632264,592220,112148,676118,508950,517033,2022,438265,129719,452039,164661,593382,335068,435609,517148,639545,369592,7432,591123,632200,245798,702257,645463,435759,650237,479971,512756,350209,582050,2030,164226,371147,169875,211426,250002,9676,164070,132648,20000,353090,645274,516179,699172,592243,548868,484227,534385,75361,412304,288151,78769,1166,724,585396,610189,187861,591969,325667,553878,29742,387057,648482,120855,68533,655179,460232,468254,443081,653181,13645,516075,705495,701975,517228,586279,29344,705455,705455,78824,310640,552091,211823,58924,632121,301243,71574,169333,699848,161287,334907,118631,235750,75056,20716,30570,702365,524308,661964,499594,465784,597106,590956,705773,279915,440525,522632,633514,701968,682316,591665,127011,199368,496191,482526,12813,547611,572318,209431,537126,520145,510833,50382,515122,512619,89643,102866,303923,705716,197320,332173,444213,334507,655640,445078,659766,106513,154296,471014,610975,569438,592561,654532,621817,120551,519033,657724,174312,604542,662185,659215,660543,87968,89583,168586,249125,656790,7471,288912,596698,351316,22026,135997,135997,156652,133527,184194,513094,531624,31130,438641,652230,91586,654824,500674,654665,591605,505934,670211,352626,253489,355126,115838,632227,187377,592102,477547,6360,370410,93832,706477,406265,317593,656313,179646,13526,515139,74137,684601,75914,592682,513058,598832,632641,482873,658619,642817,200413,26403,279929,657066,144513,126221,12449,173233,514211,655662,311100,370262,364191,567647,396358,596726,513933,191616,13662,654713,705605,475392,91566,506815,444668,437195,706603,449718,488835,157527,503709,104476,533725,525063,699231,12845,518562,270753,469376,118552,524838,49599,507268,310482,44004,288761,188591,656176,406530,17558,658637,356744,351335,176227,382075,631842,9234,679002,352548,94896,273077,519557,591559,399779,632851,518900,607691,27524,374147,356108,35861,258212,105606,631629,379972,128069,369471,659535,496572,479766,302346,355606,121847,334916,503074,148970,91791,58785,154329,696326,163909,590990,501622,656657,308028,487510,162246,379754,508588,478936,647116,647090,439991,40808,655004,381134,43899,309069,99145,436203,497443,654748,592174,182626,522172,376722,513330,23119,59134,696710,688627,590943,546454,376511,645547,369632,591040,670634,487670,446664,494146,632085,591341,632365,446069,591886,459652,8036,445386,655019,587176,564188,623955,129614,87619,653131,6451,108530,659339,146180,652353,98843,110702,31082,203896,45140,26216,436068,411925,656003,25544,475502,677570,634586,594563,646859,517817,478729,658956,504301,433791,8769,476525,444569,705675,699516,523054,433668,465305,123423,22157,534521,202517,7001,189782,632471,523262,329850,19025,663950,511175,119387,414473,593722,567759,187646,521487,116240,420076,694081,436502,106650,293842,99439,629674,485606,638407,347408,288940,146928,454828,350808,177927,250905,502100,135215,569487,511138,656298,389669,631922,181444,12400,224630,30011,259432,199695,353163,501853,517155,267632,185777,371005,263928,133321,494595,659839,11355,450110,407122,132195,201877,645299,677557,125571,266308,439309,208600,161985,46720,370885,435490,465560,446574,522584,159201,655548,659140,555895,56145,496530,401954,577775,331268,647096,181391,687024,143250,241570,76090,660676,525607,591338,437322,656274,465643,432360,306343,591834,521456,655801,213467,204044,81791,355899,158341,344088,512898,2556,212680,149168,279594,256278,443577,462529,129780,434878,1314,654459,478275,333791,54673,54673,54673,525157,129708,241382,248197,181097,654445,1524,34024,543850,368551,208206,203420,518513,370267,530730,329327,132957,156369,118845,182421,320890,523403,351582,480085,631558,533613,73454,3017,513349,482497,705399,193613,537792,659864,565319,26047,623956,655057,372082,584945,592375,471381,520814,438292,42853,485104,531550,653129,474978,525091,368527,474705,153504,462379,533192,595072,517066,655909,321653,112318,227253,532675,592136,472737,528574,661092,381281,156346,475733,592115,436401,53454,589962,664395,534312,496459,693681,655655,654672,444106,584957,634856,491805,26608,460789,555910,654481,274329,440968,523968,554791,514050,50649,700624,516994,440263,137569,697294,82128,524763,131851,368433,591347,473296,351815,591999,376337,524219,660232,133892,300772,654421,705387,535581,631618,444319,467554,523454,432424,481466,406966,534458,279640,338851,20529,157401,629812,638296,405479,592982,677789,592076,421194,694819,374596,122986,377488,244580,699226,74647,74647,74647,74647,74647,74647,592213,460996,531251,522506,510528,631898,654708,147434,8375,523930,591983,643537,5148,517972,535711,152774,491988,570737,520182,30345,24379,592238,461722,523131,524078,432413,466929,13303,138701,449416,351665,654601,129712,283022,435295,117331,164797,639392,93698,434181,485392,694840,644635,182231,199814,3022,69499,444947,696139,467751,516826,274295,13543,436922,575631,606488,591789,123534,164324,121748,435711,532357,684559,501778,792,490287,528952,485041,440382,467408,504115,591992,493275,591910,26837,125300,125300,125300,125300,104223,638953,519514,579079,584851,413493,413493,50749,509439,441488,700303,343487,232026,591987,301526,287735,293660,195715,534218,370515,647053,647272,516036,85524,521092,323858,212957,368004,654633,656006,279709,454490,189823,130836,655089,523438,489254,487412,567678,661859,661254,632307,645328,705357,336810,654750,348618,276429,130031,533030,515094,632339,591633,43618";
my $base    = "";
my $org     = "Hs";
my @cids    = split ",",  $CIDS;
 
use constant ORACLE_LIST_LIMIT  => 500;
use constant MAX_ROWS_PER_FETCH => 1000;
use constant MAX_LONG_LEN       => 16384;
 
my (%go2cid, %go2name, %go2class);
my (%cids);
my (%total, %direct_total);
my ($total_annotated_genes);
 
print "Content-type: text/plain\n\n";
 
if( $cids[0] =~ /,/ ) {
  my $tmp = $cids[0];
  @cids = split ",", $tmp;
}
 
print SummarizeGOForGeneSet_1($base, $org, \@cids);
