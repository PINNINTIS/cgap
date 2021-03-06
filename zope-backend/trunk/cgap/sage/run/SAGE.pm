#!/usr/local/bin/perl
#####################################################################
# SAGE.pm
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# NOTE: Code removed to prevent confusion.
# All SDGED code for ComputeSDGED is
# now in GXSServer.pl.
# If standalone ComputeSDGED is revived, reinsert code from GXSServer.pl.
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
######################################################################

use strict;
use DBI;
use CGAPConfig;
## use Bayesian;
use Cache;
use Paging;
use CGI::Carp qw(fatalsToBrowser);

use constant GOOD_LIB_QUALITY => 1;
use constant MIN_LIB_SIZE     => 20000;

use constant GOOD_SIZE => 1;
use constant GOOD_QUAL => 1;
use constant ANY_SIZE  => 0;
use constant ANY_QUAL  => 0;

use constant ORACLE_LIST_LIMIT => 500;

my $IMPOSSIBLY_LARGE_RANK = 1000000;
###my $MAGIC_RANK = 18;
my $MITO_ACC = "X93334";
my $DENOM = 200000;
my $BASE;

my %MAGIC_RANK;

## my $UCSC_DB = "hg18";
my $UCSC_DB = "";

my $genomics_cache = new Cache(CACHE_ROOT, GENOMICS_CACHE_PREFIX);
my $gxs_cache = new Cache(CACHE_ROOT, GXS_CACHE_PREFIX);

my $CACHE_FAIL = 0;

my %nice_histology_name = (
    "normal"         => "normal",
    "preneoplasia"   => "pre-cancer",
    "neoplasia"      => "cancer",
    "benign hyperplasia" => "benign hyperplasia",
    "uncharacterized histology" => "uncharacterized histology",
    "multiple histology"        => "multiple histology",
    "other"          => "other"
);     

my %org_method_2_protocol;
$org_method_2_protocol{"Hs"} = {
  "SS10"  =>  "A",
  "LS10"  =>  "B",
  "LS17"  =>  "C",
  "LS21"  =>  "D"
};     
$org_method_2_protocol{"Mm"} = {
  "SS10"  =>  "K",
  "LS10"  =>  "L",
  "LS17"  =>  "M",
  "LS21"  =>  "N"
};     

my $LIBRARY_LIST_TABLE_HEADER = "<table border=1 cellspacing=1 cellpadding=4>" .
        "<tr bgcolor=\"#38639d\">" .
        "<td><font color=\"white\"><b>Title</b></font></td>" .
        "<td><font color=\"white\"><b>Tissue</b></font></td>" .
        "<td><font color=\"white\"><b>Histology</b></font></td>" .
        "<td><font color=\"white\"><b>Preparation</b></font></td>" .
        "<td><font color=\"white\"><b>Keywords</b></font></td>" .
        "</tr>";

my $TRANSFRAG_LIST_TABLE_HEADER = "<table border=1 cellspacing=1 cellpadding=4>" .
        "<tr bgcolor=\"#38639d\">" .
        "<td><font color=\"white\"><b>Tag</b></font></td>" .
        "<td><font color=\"white\"><b>Chromosome</b></font></td>" .
        "<td><font color=\"white\"><b>Tag Start</b></font></td>" .
        "<td><font color=\"white\"><b>Tag Strand</b></font></td>" .
        "<td><font color=\"white\"><b>Frequency</b></font></td>" .
        "</tr>";

my @anatomic_viewer_histologies = (
    'neoplasia',
    'normal'
);

#my %anatomic_aggregate = (
#    "cerebellum"  => "brain"
#);

my @anatomic_query_tissues = (
#    'bone',          ## gone for now
    'bone marrow',
    'brain',
    'mammary gland',
    'cartilage',
##     'cervix',      ## not yet
    'colon',
    'heart',
    'kidney',
    'liver',
    'lung',
    'lymph node',
    'muscle',
    'ovary',
    'pancreas',
    'peritoneum',
    'placenta',
    'prostate',
    'retina',
    'skin',
    'spinal cord',     ## also part of brain
    'stomach',
#    'testis',       ## not yet
    'thyroid',
    'white blood cells',
    'embryonic stem cell',
    'vascular'
);

## map for names of image files:

my %anatomic_viewer_tissues = (
##     'bone'         => 'bone',
    'bone marrow'  => 'bonemarrow',
    'brain'        => 'brain',
    'mammary gland'       => 'breast',
    'cartilage'    => 'cartilage',
##    'cervix'       => 'cervix',    ## not yet
    'colon'        => 'colon',
    'heart'        => 'heart',
    'kidney'       => 'kidney',
    'liver'        => 'liver',
    'lymph node'   => 'lymphnode',
    'lung'         => 'lung',
    'muscle'       => 'muscle_bone',
    'ovary'        => 'ovary',
    'pancreas'     => 'pancreas',
    'peritoneum'   => 'peritoneum',
    'placenta'     => 'placenta',
    'prostate'     => 'prostate',
    'retina'       => 'retina',
    'skin'         => 'skin',
    'spinal cord'  => 'spine',      ## also part of brain
    'stomach'      => 'stomach',
##    'testis'       => 'testis',    ## not yet
    'thyroid'      => 'thyroid',
    'white blood cells' => 'wbc',
    'embryonic stem cell' => 'cellline',
    'vascular'     => 'vascular'
);

my @anatomic_viewer_order = (
    "brain",
    "retina",
    "thyroid",
    "lung",
    "heart",
    "mammary gland",
    "stomach",
    "pancreas",
    "liver",
    "kidney",
    "colon",
    "peritoneum",
    "spinal cord",      ## also part of brain
    "ovary",
    "placenta",
##    "cervix",    ## not yet
    "prostate",
##    "testis",         ## not yet
    "bone marrow",
##    "bone",
    "cartilage",
    "muscle",
    "skin",
    "lymph node",
    "white blood cells",
    "embryonic stem cell",
    "vascular"
);

my %anatomic_viewer_params = (
    "cartilage"   => "Cartilage,33,63",
    "bone marrow" => "Bone Marrow,45,67",
    "bone"        => "Bone,90,32",
    "brain"       => "Brain,54,51",
    "retina"      => "Retina,37,26",
    "lung"        => "Lung,51,56",
    "heart"       => "Heart,25,38",
    "mammary gland"      => "Breast,27,51",
    "stomach"     => "Stomach,43,38",
    "pancreas"    => "Pancreas,50,16",
    "liver"       => "Liver,42,24",
    "lymph node"  => "Lymph Node,71,53",
    "kidney"      => "Kidney,48,38",
    "colon"       => "Colon,54,54",
    "peritoneum"  => "Peritoneum,51,57",
    "spinal cord"       => "Spinal Cord,24,71",    ## also part of brain
    "ovary"       => "Ovary,67,37",
    "prostate"    => "Prostate,22,32",
##    "testis"      => "Testis,36,55",    ## not yet
    "white blood cells"         => "White Blood Cells,45,50",
    "muscle"      => "Muscle,82,25",
##    "cervix"      => "Cervix,67,49",    ## not yet
    "placenta"    => "Placenta,60,51",
    "skin"        => "Skin,54,54",
    "thyroid"     => "Thyroid,41,45",
    "embryonic stem cell" => "Embryonic Stem Cell,84,45",
    "vascular"    => "Vascular,72,63"
);

my %repetitives;
my %datasets;             ## rank -> (id, percent, position, has_sig, has_tail)

my @color_scale = (
  "0000FF",
  "3399FF",
  "66CCFF",
  "99CCFF",
  "CCCCFF",
  "FFCCFF",
  "FF99FF", 
  "FF66CC", 
  "FF6666",
  "FF0000"
);

my @color_breaks = (
  2, 4, 8, 16, 32, 64, 128, 256, 512, $DENOM
);

my @dpc = (
 0, 0.5, 2.5, 3.5, 5.5, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5,
 10.5, 11.5, 12.5, 13.5, 14.5, 15.5, 16.5, 17.5, 18.5, 20,
 21, 27, 40, 41, 47, 55, 56, 62, 80, 83, 90, 92, 104, 129
);

## my @theiler = (
##  "1", "3", "5", "7", "8", "10", "11", "12", "13", "14", "15",
##  "17", "19", "20", "21", "22", "23", "24", "25", "26", "27",
##  "1d", "7d", "14d", "20d", "21d", "27d", "35d", "42d", "12w"
## );
my @theiler = (
 "cell", "1", "3", "5", "7", "9", "10", "11", "12", "13", "14", "15",
 "17", "19", "20", "21", "22", "23", "24", "25", "26", "27",
 "1d", "7d", "20d", "21d", "27d", "35d", "36d", "42d", "60d", "63d", "70d", "72d", "12w", "109d"
);

my $mouse_matrix_columns = 36;

my @mouse_matrix_tissues = (
"early embryo",
"embryo",
"embryo anterior half",
"embryo embryonic",
"embryo extraembryonic",
"embryo posterior",
"embryo whole",
"ectoplacental cone",
"adrenal gland",
"bladder",
"bone",
"brain",
"brain amygdala",
## "amygdala basolateral complex",
## "amygdala central nucleus",
"brain basal nucleus of meynert",
"brain ca1",
"brain cerebellum",
"brain cerebellum white matter",
## "cerebellum Purkinje layer",
"brain dentate gyrus",
"diencephalon",
"brain dorsal thalamus",
"epithalamus",
"brain ependymal and subependymal layers",
"future brain",
"future forebrain",
## "hippocampus",
"hypothalamus",
"brain locus coeruleus",
"brain medial thalamus",
"brain preplate",
"prestriatum",
"brain primary motor cortex",
"brain rahpe nuclei",
"brain striatum",
"brain substantia nigra",
"telencephalon",
"telencephalon dorsal",
"telencephalon dorsal svz",
"telencephalon ventral",
"telencephalon ventral svz",
## "thalamus dorsal",
## "thalamus medial",
## "thalamus ventral",
"brain ventral thalamus",
"visual cortex",
"brain visual cortex layers ii",
"brain vz",
"brain whole",
"brain whole head",
"embryonic stem cells",
"embryonic tissue",
"branchial arch",
## "definitive endoderm",
"foregut endoderm",
"hindgut endoderm",
"female urogenital sinus",
## "female urogenital sinus epithelium",
## "female urogenital sinus mesenchyme",
"male urogenital sinus",
"male urogenital sinus epithelium",
"male urogenital sinus mesenchyme",
"endoderm definitive",
"esophagus",
"eye, optic cup",
"limb forelimb",
## "forelimb",
"forelimb paddle",
"heart",
"heart whole",
"atrioventricular canal",
"atrium",
"bulbous cordis",
"ventricle",
"kidney",
"kidney epithelium",
"kidney mesenchyme",
"kidney whole",
"large intestine",
"large intestine epithelium",
"large intestine mesenchyme",
"large intestine whole",
"liver",
"liver liver bud and septum transversum",
"liver right lobe",
"liver whole",
"lung",
"lung epithelium",
"lung mesenchyme",
"lung whole",
"lymph nodes",
"lymph nodes lumbar",
"lymph nodes mesenteric",
"mammary gland",
"involuting",
"lactation",
"pregnant",
"puberty",
## "virgin",
"muscle",
"skeletal",
## "smooth",
"neural tube",
"neural tube anterior neuropore",
"neural tube posterior neuropore",
"neural tube whole",
"ovary",
"pancreas",
"pancreas pancreatic duct",
"pancreas regenerating duct",
"pancreas islets",
"pancreas regenerating islets",
"pancreas whole",
## "NGN3/GFP+",
## "PDX1/GFP+",
## "NGN3/GFP",
"pituitary gland",
"placenta",
"prostate",
"prostate dorsal",
"prostate dorsal lobe",
"prostate whole",
"skin",
"small intestine",
"small intestine epithelium",
"small intestine mesenchyme",
"small intestine whole",
"spleen",
"stomach",
"testis",
"thymus",
"uterus"
);

my %mouse_matrix_tissues = (
"early embryo" => "Early embryo",
"embryo" => "Embryo",
"embryo anterior half" => "  Anterior  half",
"embryo embryonic" => "  Embryonic",
"embryo extraembryonic" => "  Extraembryonic",
"embryo posterior" => "  Posterior",
"embryo whole" => "  Whole",
"ectoplacental cone" => "Ectoplacental cone",
"adrenal gland" => "Adrenal gland",
"bladder" => "Bladder",
"bone" => "Bone",
"brain" => "Brain",
"brain amygdala" => "  Amygdala",
## "amygdala basolateral complex" => "  Amygdala  basolateral  cortex",
## "amygdala central nucleus" => "  Amygdala  central nucleus",
"brain basal nucleus of meynert" => "  Basal nucleus  of Meynert",
"brain ca1" => "  Ca1",
"brain cerebellum" => "  Cerebellum",
"brain cerebellum white matter" => "  Cerebellum  White Matter",
## "cerebellum Purkinje layer" => "  Cerebellum  Purkinje layer",
"brain dentate gyrus" => "  Dentate gyrus",
"diencephalon" => "  Diencephalon",
"brain dorsal thalamus" => "  Dorsal  Thalamus",
"epithalamus" => "  Epithalamus",
"brain ependymal and subependymal layers" => "  Ependdymal  layers",
"future brain" => "  Future brain",
"future forebrain" => "  Future  forebrain",
## "hippocampus" => "  Hippocampus",
"hypothalamus" => "  Hypothalamus",
"brain locus coeruleus" => "  Locus  coeruleus",
"brain medial thalamus" => "  Medial  Thalamus",
"brain preplate" => "  Preplate",
"prestriatum" => "  Prestriatum",
"brain primary motor cortex" => "  Primary  motor cortex",
"brain rahpe nuclei" => "  Rahpe nuclei",
"brain striatum" => "  Striatum",
"brain substantia nigra" => "  Substantia  nigra",
"telencephalon" => "  Telencephalon",
"telencephalon dorsal" => "  Telencephalon  dorsal",
"telencephalon dorsal svz" => "  Telencephalon  dorsal svz",
"telencephalon ventral" => "  Telencephalon  ventral",
"telencephalon ventral svz" => "  Telencephalon  ventral svz",
## "thalamus dorsal" => "  Thalamus  dorsal",
## "thalamus medial" => "  Thalamus  medial",
## "thalamus ventral" => "  Thalamus  ventral",
"brain ventral thalamus" => "  Ventral  Thalamus",
"visual cortex" => "  Visual cortex",
"brain visual cortex layers ii" => "  Visual cortex  Layers II",
"brain vz" => "  VZ",
"brain whole" => "  Whole",
"brain whole head" => "  Whole Head",
"embryonic stem cells" => "Embryonic  stem cell",
"embryonic tissue" => "Embryonic tissue",
"branchial arch" => "  Branchial  arch",
## "definitive endoderm" => "  Definitive  endoderm",
"foregut endoderm" => "  Foregut  endoderm",
"hindgut endoderm" => "  Hindgut  endoderm",
"female urogenital sinus" => "  Urogenital  sinus (F)",
## "female urogenital sinus mesenchyme" => "  Urogenital  sinus (F)  mesenchyme",
## "female urogenital sinus epithelium" => "  Urogenital  sinus (F)  epithelium",
"male urogenital sinus" => "  Urogenital  sinus (M)",
"male urogenital sinus mesenchyme" => "  Urogenital  sinus (M)  mesenchyme",
"male urogenital sinus epithelium" => "  Urogenital  sinus (M)  epithelium",
"endoderm definitive" => "Endoderm definitive",
"esophagus" => "Esophagus",
"eye, optic cup" => "Eye, optic cup",
"limb forelimb" => "Forelimb",
## "forelimb" => "Forelimb",
"forelimb paddle" => "Forelimb paddle",
"heart" => "Heart",
"atrioventricular canal" => "  Atrioventricular  canal",
"atrium" => "  Atrium",
"bulbous cordis" => "  Bulbous cordis",
"ventricle" => "  Ventricle",
"heart whole" => "  Whole",
"kidney" => "Kidney",
"kidney epithelium" => "  Epithelium",
"kidney mesenchyme" => "  Mesenchyme",
"kidney whole" => "  Whole",
"large intestine" => "Large intestine",
"large intestine epithelium" => "  Epithelium",
"large intestine mesenchyme" => "  Mesenchyme",
"large intestine whole"  => "  Whole",
"liver" => "Liver",
"liver liver bud and septum transversum" => "  Liver bud",
"liver right lobe" => "  Right lobe",
"liver whole" => "  Whole",
"lung" => "Lung",
"lung epithelium" => "  Epithelium",
"lung mesenchyme" => "  Mesenchyme",
"lung whole" => "  Whole",
"lymph nodes" => "Lymph nodes",
"lymph nodes lumbar" => "  Lumbar",
"lymph nodes mesenteric" => "  Mesenteric",
"mammary gland" => "Mammary gland",
"involuting" => "  Involuting",
"lactation" => "  Lactation",
"pregnant" => "  Pregnant",
"puberty" => "  Puberty",
## "virgin" => "  Virgin",
"muscle" => "Muscle",
"skeletal" => "  Skeletal",
## "smooth" => "  Smooth",
"neural tube" => "Neural tube",
"neural tube anterior neuropore" => "  Anterior  Neuropore",
"neural tube posterior neuropore" => "  Posterior  Neuropore",
"neural tube whole" => "  Whole",
"ovary" => "Ovary",
"pancreas" => "Pancreas",
"pancreas pancreatic duct" => "  Pancretic  duct",
"pancreas regenerating duct" => "  Regenerating  duct",
"pancreas islets" => "  Islet",
"pancreas regenerating islets" => "  Regenerating  islet",
"pancreas whole" => "  Whole",
## "NGN3/GFP+" => "  NGN3/GFP+",
## "PDX1/GFP+" => "  PDX1/GFP+",
## "NGN3/GFP" => "  NGN3/GFP",
"pituitary gland" => "Pituitary",
"placenta" => "Placenta",
"prostate" => "Prostate",
"prostate dorsal" => "  Dorsal",
"prostate dorsal lobe" => "  Dorsal lobe",
"prostate whole"  => "  Whole",
"skin" => "Skin",
"small intestine" => "Small intestine",
"small intestine epithelium" => "  Epithelium",
"small intestine mesenchyme" => "  Mesenchyme",
"small intestine whole"  => "  Whole",
"spleen" => "Spleen",
"stomach" => "Stomach",
"testis" => "Testis",
"thymus" => "Thymus",
"uterus" => "Uterus"
);

my %mouse_matrix_subunits = (
"brain"                  => 32,
"embryo"                 => 5,
"embryonic tissue"       => 7,
"heart"                  => 5,
"kidney"                 => 3,
"large intestine"        => 3,
"liver"                  => 3,
"lung"                   => 3,
"lymph nodes"            => 2,
"mammary gland"          => 5,
"muscle"                 => 2,
"neural tube"            => 3,
"pancreas"               => 5,
"prostate"               => 3,
"small intestine"        => 3
);


my @breast_cell_order = (
"Progenitor-like (CD44<sup>+</sup>)",
"Progenitor-like (PROCR<sup>+</sup>)",
"Endothelium (P1H12<sup>+</sup>)",
"Leukocytes (CD45<sup>+</sup>)",
"Luminal epithelial cell (CD24<sup>+</sup>)",
"Luminal epithelial cell (MUC1<sup>+</sup>)",
"Luminal epithelial cell (BerEP4<sup>+</sup>)",
"SSEA4<sup>+</sup> epithelial cells",
"Myoepithelial cell (CD10<sup>+</sup>)",
"Myofibroblast (CD10<sup>+</sup>)",
"Stroma, enriched fibroblasts"
);

my @breast_cell_tissues = (
"Progenitor-like (CD44+)",
"Progenitor-like (PROCR+)",
"endothelium (P1H12<sup>+</sup>",
"leukocytes (CD45<sup>+</sup>)",
"Luminal epithelial cell (CD24+)",
"Luminal epithelial cell (MUC1+)",
"luminal epithelial cell (BerEP4+)",
"SSEA4+ epithelial cells",
"Myoepithelial cell (CD10+)",
"Myofibroblast (CD10+)",
"stroma, enriched fibroblasts"
);

my %breast_cell_tissues = (
"Progenitor-like (CD44<sup>+</sup>)" => "progenitor-like (CD44+)",
"Progenitor-like (PROCR<sup>+</sup>)" => "progenitor-like (PROCR+)",
"Endothelium (P1H12<sup>+</sup>)" => "endothelium",
"Leukocytes (CD45<sup>+</sup>)"  => "leukocytes",
"Luminal epithelial cell (CD24<sup>+</sup>)" => "luminal epithelial cell (CD24+)",
"Luminal epithelial cell (MUC1<sup>+</sup>)" => "luminal epithelial cell (MUC1+)",
"Luminal epithelial cell (BerEP4<sup>+</sup>)" => "luminal epithelial cell (BerEP4+)",
"SSEA4<sup>+</sup> epithelial cells" => "SSEA4+ epithelial cells",
"Myoepithelial cell (CD10<sup>+</sup>)" => "myoepithelial cell (CD10+)",
"Myofibroblast (CD10<sup>+</sup>)" => "myofibroblast (CD10+)",
"Stroma, enriched fibroblasts" => "stroma, enriched fibroblasts"
);

my @breast_cell_stages = (
"normal",
"dcis",
"idc",
"metastatic"
## "metastases"
);

my %breast_cell_libraries;


sub numerically { $a <=> $b };
sub r_numerically { $b <=> $a };

######################################################################
use constant TAG_LEGEND3 => qq(
<p>
<small><b>Legend</b></small>
<table border=1 cellspacing=1 cellpadding=2>

<tr>
<td align=center><small><b>&#185;</b></td>
<td colspan=3><small>Position of virtual tag relative to 
     the longest reliable sequence in database</small></td>
</tr>

<tr>
<td align=center><small><b>&#178;</b></td>
<td><small><img src="images/bodyicon.gif" alt=\"Tissues only\" border=0><BR>Tissues only</small></td>
<td><small><img src="images/cellicon.gif" alt=\"Cell lines only\" border=0><br>Cell lines only</small></td>
<td><small><img src="images/bodycell.gif" alt=\"Tissues + Cell lines\" border=0><br>Tissues + Cell lines</small></td>
</tr>

<tr>
<td align=center><small><b>*</b></small></td>
<td colspan=3><small>Tag maps to other gene(s)</td>
</tr>

<tr>
<td align=center><small><b>#</b></small></td>
<td colspan=3><small>Highly repetitive tag</small></td>
</tr>
</table>
);

######################################################################
sub GENE_INFO_URL {
  my ($cid, $org) = @_;
  return "<a href=\"" . $BASE . "/Genes/GeneInfo?" .
      "ORG=$org&CID=$cid\">Gene Info</a>";
}

######################################################################
sub LTV_URL {
  my ($acc, $org, $method) = @_;

  return "<a href=LTViewer?ACC=$acc&ORG=$org&METHOD=$method>LTV</a>";

##  return "<a href=\"http://www.ludwig.org.br/cgi-tviewer/drawgene.pl?" .
##      "gene=$acc\">LTV</a>";
}

######################################################################
sub GB_URL {
  my ($acc, $org) = @_;
  if( $acc =~ /^ATF\d+\_\d+\_\d+/ ) {
    ## my ($chr_for_url, $start_pos, $end_pos) = split "_", $acc;
    ## return "<a href=javascript:spawn(\"" .
    ##     "http://genome.ucsc.edu/cgi-bin/hgTracks?clade=vertebrate" .
    ##     "&org=$org&db=$UCSC_DB&position=$chr_for_url:$start_pos-$end_pos" .
    ##     "&pix=620\")>$acc</a>";
    return "<a href=ATF_Info?ACC=$acc&ORG=$org>$acc</a>";
  }
  else {
    return "<a href=javascript:spawn(\"http://www.ncbi.nlm.nih.gov/" .
        "entrez/query.fcgi?db=Nucleotide&CMD=Search&term=$acc\")>$acc</a>";
  }
}

######################################################################
sub DividerBar {
  my ($text) = @_;

  return "<table width=100% cellpadding=4>" .
      "<tr bgcolor=\"#38639d\"><td><font color=\"white\"><b>" .
      $text .
      "</b></font></td></tr></table>";
}

######################################################################
sub GetMagicRank {
  my ($db, $org, $method) = @_;

  my ($sql, $stm);
  my ($rank1, $org1, $method1);
  if (!defined $MAGIC_RANK{$org}{$method}) {
    $sql = qq!
select
  max(o.rank),
  p.organism,
  p.protocol
from 
  $CGAP_SCHEMA.sageorder o,
  $CGAP_SCHEMA.sageprotocol p
where
      p.code = o.protocol
  and o.percent > 66
group by
  p.organism,
  p.protocol
    !;
    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    while(($rank1, $org1, $method1) = $stm->fetchrow_array()) {
      $MAGIC_RANK{$org1}{$method1} = $rank1;
    }
    for $org1 ("Hs", "Mm") {
      $MAGIC_RANK{$org1}{"SS10,LS10"} = $MAGIC_RANK{$org1}{"SS10"};
      $MAGIC_RANK{$org1}{"LS10,SS10"} = $MAGIC_RANK{$org1}{"SS10"};
    }
  }
  if (!defined $MAGIC_RANK{$org}{$method}) {
    if( $method eq "LS21" ) {
      $MAGIC_RANK{$org}{$method} = 10;
    }
    else {
      print STDERR "no magic rank for $org, $method\n";
      exit;
    }
  } else {
    return $MAGIC_RANK{$org}{$method};
  }

}

######################################################################
sub GetRepetitiveTagList_1 {
  my ($org, $method, $format) = @_;

  my ($db, %repeats, %by_freq, $freq, $tag, $tag_cell, @lines);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  GetRepetitives($db, \%repetitives, $org, $method);

  $db->disconnect();

  while (($tag, $freq) = each %repetitives) {
    push @{ $by_freq{$freq} }, $tag;
  }

  push @lines,
      "<p>" .
      "<table border=1 cellspacing=1 cellpadding=4>";
  push @lines, "<tr><td><b># Occurrances</b></td><td><b>Tag</b></td></tr>";

  for $freq (sort numerically keys %by_freq) {
    for $tag (@{ $by_freq{$freq} }) {
      $tag_cell = "<a href=\"GeneByTag?ORG=$org&METHOD=$method&FORMAT=html&" .
          "TAG=$tag\">$tag#</a>";
      push @lines, "<tr><td>$freq</td><td>$tag_cell</td></tr>";
    }
  }

  push @lines, "</table>";

  return join("\n", @lines);
}

######################################################################
sub GetRepetitives {
  my ($db, $repeats, $org, $method) = @_;

  my ($sql, $stm);
  my ($tag, $nrepeats);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select a.tag, a.nrepeats from $CGAP_SCHEMA.sagerepeats a, " .
      "$CGAP_SCHEMA.sageprotocol b " .
      "where b.ORGANISM = '$org' " .
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and a.PROTOCOL  = b.CODE "; 

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while(($tag, $nrepeats) = $stm->fetchrow_array()) {
    $$repeats{$tag} = $nrepeats;
  }

}

######################################################################
sub CharacterizeDataset {
  my ($rank) = @_;

  my ($id);

  if ($datasets{$rank}{position} > 1) {
    return "internal tag";
  } else {
    $id = $datasets{$rank}{id};
    if ($id =~ /_ip$/) {
      return "internally primed site";
    } elsif ($id =~ /_apa$/) {
      return "shorter alternative transcript";
    } elsif ($datasets{$rank}{has_signal} eq "Yes" || $datasets{$rank}{has_tail} eq "Yes") {
      return "reliable 3' end";
    } elsif ($id eq "mito") {
      return "mitochondrial";
    } elsif ($datasets{$rank}{has_signal} eq "No" && $datasets{$rank}{has_tail} eq "No") {
      return "undefined 3' end";
    } else {
      return "UNDEFINED TYPE";
    }
  }
}

######################################################################
sub GetConfidenceLevels {
  my ($db, $datasets, $org, $method) = @_;

  my ($sql, $stm);
  my ($rank, $position, $percent, $id, $name, $sig, $tail, $total_cdna);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select o.rank, o.position, o.percent, o.id, " .
      "s.name, s.polyA_signal, s.polyA_tail, o.total_cdna " .
      "from $CGAP_SCHEMA.sageorder o, " .
      "$CGAP_SCHEMA.sagesets s, " .
      "$CGAP_SCHEMA.sageprotocol b " .
      "where o.id = s.id " .
      "and b.ORGANISM = '$org' " .
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and s.PROTOCOL  = b.CODE " .
      "and o.PROTOCOL  = b.CODE "; 

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while(($rank, $position, $percent, $id, $name, $sig, $tail, $total_cdna) =
      $stm->fetchrow_array()) {
    $$datasets{$rank}{id}         = $id;
    $$datasets{$rank}{percent}    = $percent;
    $$datasets{$rank}{position}   = $position;
    $$datasets{$rank}{has_signal} = $sig;
    $$datasets{$rank}{has_tail}   = $tail;
    $$datasets{$rank}{name}       = $name;
    $$datasets{$rank}{total_cdna} = $total_cdna;
  }

}

######################################################################
sub ATF_Info_1 {
  my ($base, $acc, $org) = @_;
 
  my ($db, $sql, $stm);
  my ($tag, @tags);
  my $output;
  my $def_line;
  my $seq_lines;
  my %tags;
  my $tag_line;
 
  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  $sql = 
     "select TAG,ACCESSION,CELL_LINE_NAME,SEQ_START,SEQ_END,SEQ " .
     "from $CGAP_SCHEMA.TRANSFRAG_SEQ " .
     "where ACCESSION = '$acc' order by TAG"; 
 
  $db->{LongReadLen} = 512 * 1024;
  $db->{LongTruncOk} = 1; 
  ## $stm->{LongReadLen} = 512 * 1024;
  ## $stm->{LongTruncOk} = 1; 
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  my ($TAG, $ACCESSION, $CELL_LINE_NAME, $START_POSITION, $END_POSITION, $SEQ);
  $stm->bind_columns(\$TAG, \$ACCESSION, \$CELL_LINE_NAME, \$START_POSITION, \$END_POSITION, \$SEQ);
  while($stm->fetch()) {
    $tags{$TAG} = 1;
    $tag_line = $tag_line . "$TAG; "
  }
 
  my @tmp = split "_", $ACCESSION;
  my $chr = substr($tmp[2], 0, 2);
  if( $chr eq "23" ) {
    $chr = "X";
  }
  elsif( $chr eq "24" ) {
    $chr = "Y";
  }
  else {
    $chr =~ s/^0//; 
  }

  $chr = "chr" . $chr;

  my $acc_link =
    "<a href=javascript:spawn(\"" .
    "http://genome.ucsc.edu/cgi-bin/hgTracks?clade=vertebrate" .
    "&org=$org&db=$UCSC_DB&position=$chr:$START_POSITION-$END_POSITION" .
    "&pix=620\")>$chr:$START_POSITION-$END_POSITION</a>";

  my $page_header = "<table>
      <tr valign=top>" .
      "<td><b>Transfrag accession</b>:</td>" .
      "<td>$ACCESSION</td></tr>" .
      "<tr valign=top>
      <td><b>Cell Line</b>:</td>" .
      "<td>$CELL_LINE_NAME</td></tr>" .
      "<tr valign=top>
      <td><b>Genome</b>:</td>" .
      "<td>$acc_link</td></tr>" .
      "<tr valign=top>
      <td><b>SAGE Tag</b>:</td>" .
      "<td>$tag_line</td></tr></table>";
  ## $def_line = ">$acc_link|  The cell line is $CELL_LINE_NAME<br>";

  my @li_tags; 
  for my $tag (sort keys %tags) {
    my $lc_tag = lc($tag);
    if( $SEQ =~ $lc_tag ) {
      $SEQ =~ s/$lc_tag/$tag/;
    }
    else {
      my @tmp = split "", $tag;
      my $max = @tmp - 1;
      my $REVERSE_TAG; 
      for (my $i=$max; $i>=0; $i--) {
        $REVERSE_TAG = $REVERSE_TAG . $tmp[$i];
      } 
      my $REVERSE_COMPLEMENTARY_TAG = Complementary($REVERSE_TAG);
      my $lc_rev_com_tag = lc($REVERSE_COMPLEMENTARY_TAG);
      $SEQ =~ s/$lc_rev_com_tag/$REVERSE_COMPLEMENTARY_TAG/;
    }
  }
  ## $seq_lines = "<BR><b>Sequence:</b>:<BR>";
  my $leng = length($SEQ);
  for (my $i=0; $i<$leng; $i=$i + 50) {
    my $line = substr($SEQ, $i, 50);
    ## $line =~ s/C/<font color=\"#FF0000\" face="text">c<\/font>/g;
    ## $line =~ s/A/<font color=\"#FF0000\" face="text">a<\/font>/g;
    ## $line =~ s/T/<font color=\"#FF0000\" face="text">t<\/font>/g;
    ## $line =~ s/G/<font color=\"#FF0000\" face="text">g<\/font>/g;
    $seq_lines = $seq_lines . $line . "<br>";
  }
  my $all_seq_lines = "<pre>" . $seq_lines . "<\/pre>";
  $all_seq_lines =~ s/C/<font color=\"#FF0000\" face="text">c<\/font>/g;
  $all_seq_lines =~ s/A/<font color=\"#FF0000\" face="text">a<\/font>/g;
  $all_seq_lines =~ s/T/<font color=\"#FF0000\" face="text">t<\/font>/g;
  $all_seq_lines =~ s/G/<font color=\"#FF0000\" face="text">g<\/font>/g;
  return "$page_header " . "<BR><b>Sequence:</b>" . $all_seq_lines;
  $db->disconnect();
}


 
######################################################################
sub GetTransfrag_1 {
  my ($base, $page, $org, $chr, $start_pos, $end_pos) = @_;
 
  my ($db, $sql, $stm);
  my (@rows);
  my $output;
  my $def_line;
  my $seq_lines;
  my %tag2info;
  my @tags;
 
  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }
 
  my $page_header = "<table>\n" .
      "<tr align=top><td><b>Transfrag Finder Query:</b></td><td>" . 
      "Chromosome: $chr, Start: $start_pos, End: $end_pos<br>" . 
      "</td></tr>\n" .
      "<tr align=top><td><b>Order By:</b></td><td>TAG</td></td>\n" .
      "</table>\n";

  $sql =
     "select a.TAG,a.CHROMOSOME,a.TAG_START,a.TAG_STRAND,SUM(b.FREQUENCY) " .
     "from $CGAP_SCHEMA.TRANSFRAG_TAG a, $CGAP_SCHEMA.SAGEFREQ b " .
     "where CHROMOSOME = '$chr' and a.TAG = b.TAG and b.PROTOCOL = 'C' ";

  if( $start_pos ne "" ) {
    $sql = $sql . " and a.TAG_START >= $start_pos "; 
  }
 
  if( $end_pos ne "" ) {
    $sql = $sql . " and a.TAG_START <= $end_pos "; 
  }

  ## $sql = $sql . " order by TAG "; 
  $sql = $sql . " group by a.TAG,a.CHROMOSOME,a.TAG_START,a.TAG_STRAND "; 
  $sql = $sql . " order by a.TAG "; 

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  my ($TAG, $CHROMOSOME, $TAG_START, $TAG_STRAND, $FREQUENCY);
  $stm->bind_columns(\$TAG,\$CHROMOSOME,\$TAG_START, \$TAG_STRAND,\$FREQUENCY);
  while($stm->fetch()) {
    ## print "<br>$TAG, $ACCESSION, $CHR, $START_POSITION, $END_POSITION</br>";
    push @rows,join("\t",$TAG,$CHROMOSOME,$TAG_START,$TAG_STRAND,$FREQUENCY);
    ## print "8888: $TAG,$CHROMOSOME,$TAG_STRAND,$TAG_START<br>";
    ## $tag2info{$TAG} = join("\t",$TAG,$CHROMOSOME,$TAG_STRAND,$TAG_START);
    ## push @tags, $TAG;
  }

  $db->disconnect();

  my $cmd = "GetTransfrag?" .
        "ORG=$org&" .
        "CHR=$chr&" .
        "CHR_START=$start_pos&" .
        "CHR_END=$end_pos";
 
  return FormatTransfrags($page, $org, $cmd, $page_header, \@rows);
}

 
######################################################################
sub FormatOneTransfrag {
  my ($what, $org, $info) = @_;
  my ($TAG, $CHROMOSOME, $TAG_START, $TAG_STRAND, $FREQUENCY) = 
                                                       split("\t", $info);
  my $s;
  if ($what eq "HTML") {
    my $tag_cell = "<a href=\"GeneByTag?ORG=$org&METHOD=LS17&FORMAT=html&" .
       "TAG=$TAG\">$TAG" .
        (defined $repetitives{$TAG} ? "#" : "") .
        "</a>";
    $s = "<tr valign=top>".
        "<td>" . $tag_cell        . "</td>" .
        "<td align=center>" . $CHROMOSOME      . "</td>" .
        "<td align=right>" . $TAG_START       . "</td>" .
        "<td align=center>" . $TAG_STRAND      . "</td>" .
        "<td align=center>" . $FREQUENCY       . "</td>" .
        "</tr>";
  } else {
    $s = "$TAG\t$CHROMOSOME\t$TAG_START\t$TAG_STRAND\t$FREQUENCY";
  }
  return $s;
}
 
######################################################################
sub FormatTransfrags {
  my ($page, $org, $cmd, $page_header, $items_ref) = @_;
 
  if (scalar(@{ $items_ref }) == 0) {
    return "<h4>$page_header</h4><br><br>" .
        "There are no transfrags matching the query<br><br>";
  }
  if ($page < 1) {
    my $i;
    my $s;
    for ($i = 0; $i < scalar(@{ $items_ref }); $i++) {
      $s = $s . FormatOneTransfrag("TEXT", $org, $$items_ref[$i]) . "\n";
    }
    return $s;
  } else {
    return PageResults($page, $org, $cmd, $page_header,
      $TRANSFRAG_LIST_TABLE_HEADER, \&FormatOneTransfrag, $items_ref);
  }
}
 
######################################################################
sub PickBestTagForGene {
  my ($db, $cluster_number, $accession, $org, $method) = @_;

  my ($sql, $stm);
  my ($tag, @tags);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  if ($cluster_number) {
    $sql = "select a.tag " .
      "from $CGAP_SCHEMA.sagebest_cluster a,  $CGAP_SCHEMA.sageprotocol b " .
      "where a.cluster_number = $cluster_number " .
      "and b.ORGANISM = '$org' " .
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and a.PROTOCOL  = b.CODE "; 
  } else {
    $sql = "select a.tag " .
      "from $CGAP_SCHEMA.sagebest_accession a, $CGAP_SCHEMA.sageprotocol b " .
      "where a.accession = '$accession' " .
      "and b.ORGANISM = '$org' " .
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and a.PROTOCOL  = b.CODE "; 
  }

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while(($tag) = $stm->fetchrow_array()) {
    push @tags, $tag;
  }

  return $tags[0];
}

######################################################################
sub GetGeneList_1 {
  my ($format, $rank_limit, $what, $card, $org, $method) = @_;

  my ($db, $sql, $stm);
  my ($count, $cid_or_acc);
  my (@rows, @cid_or_accs, );

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  if ($what eq "c") {
    $sql = "select a.cluster_number, count (unique a.tag) " .
        "from $CGAP_SCHEMA.sagemap a, $CGAP_SCHEMA.sageprotocol b " .
        "where a.rank <= $rank_limit " .
        "and a.cluster_number != 0 " .
        "and b.ORGANISM = '$org' " .
        "and b.PROTOCOL in ( '$method_list' ) " .
        "and a.PROTOCOL  = b.CODE " .
        "group by a.cluster_number";
  } else {
    $sql = "select a.accession, count (unique a.tag) " .
        "from $CGAP_SCHEMA.sagemap a, $CGAP_SCHEMA.sageprotocol b " .
        "where a.rank <= $rank_limit " .
        "and a.cluster_number = 0 " .
        "and a.accession != '_' " .
        "and b.ORGANISM = '$org' " .
        "and b.PROTOCOL in ( '$method_list' ) " .
        "and a.PROTOCOL  = b.CODE " .
        "group by a.accession";
  }

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while(($cid_or_acc, $count) = $stm->fetchrow_array()) {
    if ($count == $card) {
      push @cid_or_accs, $cid_or_acc;
    }
  }

  $db->disconnect();

  push @rows,
      "<p>" .
      "<table border=1 cellspacing=1 cellpadding=4>";
  if ($what eq "c") {
    push @rows, "<tr><td><b>Cluster</b></td></tr>";
  } else {
    push @rows, "<tr><td><b>Unclustered Accession</b></td></tr>";
  }
  for $cid_or_acc (sort @cid_or_accs) {
    if ($what eq "a") {
      push @rows,
          "<tr><td><a href=\"/SAGE/TagByAcc?FORMAT=html&" .
          "ACC=$cid_or_acc&ORG=$org&METHOD=$method\">$cid_or_acc</td></tr>";
    } else {
      push @rows,
          "<tr><td><a href=\"/SAGE/TagByCID?FORMAT=html&" .
          "CID=$org.$cid_or_acc&ORG=$org&METHOD=$method\">$org.$cid_or_acc</td></tr>";
    }
  }
  push @rows, "</table>";
  return join("\n", @rows);
}


######################################################################
sub GetTagList_1 {
  my ($org, $method, $format, $rank_limit, $what, $card) = @_;

  my ($db, $sql, $stm);
  my ($tag, $count);
  my (@rows, @tags);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  GetRepetitives($db, \%repetitives, $org, $method);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  if ($what eq "c") {
    $sql = "select a.tag, count (unique a.cluster_number) " .
        "from $CGAP_SCHEMA.sagemap a, $CGAP_SCHEMA.sageprotocol b " .
        "where a.rank <= $rank_limit " .
        "and a.cluster_number != 0 " .
        "and b.ORGANISM = '$org' " .
        "and b.PROTOCOL in ( '$method_list' ) " .
        "and a.PROTOCOL  = b.CODE " .
        "group by a.tag";
  } else {
    $sql = "select tag, count (unique accession) " .
        "from $CGAP_SCHEMA.sagemap a, $CGAP_SCHEMA.sageprotocol b " .
        "where a.rank <= $rank_limit " .
        "and a.cluster_number = 0 " .
        "and a.accession != '_' " .
        "and b.ORGANISM = '$org' " .
        "and b.PROTOCOL in ( '$method_list' ) " .
        "and a.PROTOCOL  = b.CODE " .
        "group by a.tag";
  }

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while(($tag, $count) = $stm->fetchrow_array()) {
    if ($count == $card) {
      push @tags, $tag;
    }
  }

  $db->disconnect();

  push @rows,
      "<p>" .
      "<table border=1 cellspacing=1 cellpadding=4>";
  push @rows, "<tr><td><b>Tag</b></td></tr>";
  for $tag (sort @tags) {
    push @rows,
        "<tr><td><a href=\"/SAGE/GeneByTag?ORG=$org&METHOD=$method&" .
        "FORMAT=html&" .
        "TAG=$tag\">$tag" .
        (defined $repetitives{$tag} ? "#" : "") .
        "</td></tr>";
  }
  push @rows, "</table>";
  return join("\n", @rows);
}

######################################################################
sub GetStats_1 {
  my ($format, $what, $rank_limit, $org, $method) = @_;

  my ($db);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  if ($what eq "t2g") {
    return GetStats_1_Tag2Gene($db, $format, $rank_limit, $org, $method);
  } elsif ($what eq "g2t") {
    return GetStats_1_Gene2Tag($db, $format, $rank_limit, $org, $method);
  }

  $db->disconnect();

}

######################################################################
sub GetStats_1_Gene2Tag {
  my ($db, $format, $rank_limit, $org, $method) = @_;

  my ($sql, $stm);
  my ($cluster_number, $count, $accession);
  my (%accum_c, %accum_a, @rows);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select a.cluster_number, count (unique a.tag) " .
      "from $CGAP_SCHEMA.sagemap a, $CGAP_SCHEMA.sageprotocol b " .
      "where a.rank <= $rank_limit " .
      "and a.cluster_number != 0 " .
      "and b.ORGANISM = '$org' " .
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and a.PROTOCOL  = b.CODE " .
      "group by a.cluster_number";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($cluster_number, $count) = $stm->fetchrow_array()) {
    $accum_c{$count}++;
  }

  $sql = "select a.accession, count (unique a.tag) " .
      "from $CGAP_SCHEMA.sagemap a, $CGAP_SCHEMA.sageprotocol b " .
      "where a.rank <= $rank_limit " .
      "and a.cluster_number = 0 " .
      "and a.accession != '_' " .
      "and b.ORGANISM = '$org' " .
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and a.PROTOCOL  = b.CODE " .
      "group by a.accession";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($accession, $count) = $stm->fetchrow_array()) {
    $accum_a{$count}++;
  }

  push @rows, "<a href=\"#Clusters\"" .
      ">Cluster</a> density table<br><br>";
  push @rows, "<a href=\"#Accessions\"" .
      ">Unclustered accession </a> density table<br><br><br>";

  push @rows, "<a name=Clusters><b>Cluster Density Table</b></a>" .
      "<br><br>";
  push @rows,
      "<p>" .
      "<table border=1 cellspacing=1 cellpadding=4>";
  push @rows, "<tr><td><b># of distinct tags</b></td>" .
      "<td><b># of clusters</b></td></tr>";
  for (sort r_numerically keys %accum_c) {
    $count = $accum_c{$_};
    push @rows, "<tr><td>$_</td><td>" .
        ( $count < 501 ?
          ("<a href=\"/SAGE/GeneList?" .
          "FORMAT=html&RANK=$rank_limit&WHAT=c&MAPCARD=$_\">$count</a>") :
          $count
        ) .
        "</td></tr>";
  }
  push @rows, "</table>";

  push @rows, "<br><br>";

  push @rows, "<a name=Accessions><b>Unclustered Accession " .
      "Density Table</b></a>" .
      "<br><br>";
  push @rows,
      "<p>" .
      "<table border=1 cellspacing=1 cellpadding=4>";
  push @rows, "<tr><td><b># of distinct tags</b></td>" .
      "<td><b># of unclustered accessions</b></td></tr>";
  for (sort r_numerically keys %accum_a) {
    $count = $accum_a{$_};
    push @rows, "<tr><td>$_</td><td>" .
        ( $count < 501 ?
          ("<a href=\"/SAGE/GeneList?" .
          "FORMAT=html&RANK=$rank_limit&WHAT=a&MAPCARD=$_\">$count</a>") :
          $count
        ) .
        "</td></tr>";
  }
  push @rows, "</table>";

  return join("\n", @rows);
}

######################################################################
sub GetStats_1_Tag2Gene {
  my ($db, $format, $rank_limit, $org, $method) = @_;

  my ($sql, $stm);
  my ($tag, $count, $accession);
  my (%accum_c, %accum_a, @rows);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select a.tag, count (unique a.cluster_number) " .
      "from $CGAP_SCHEMA.sagemap a,  $CGAP_SCHEMA.sageprotocol b " .
      "where a.rank <= $rank_limit " .
      "and a.cluster_number != 0 " .
      "and b.ORGANISM = '$org' " .
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and a.PROTOCOL  = b.CODE " .
      "group by a.tag";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($tag, $count) = $stm->fetchrow_array()) {
    $accum_c{$count}++;
  }

  $sql = "select a.tag, count (unique a.accession) " .
      "from $CGAP_SCHEMA.sagemap a, $CGAP_SCHEMA.sageprotocol b " .
      "where a.rank <= $rank_limit " .
      "and a.cluster_number = 0 " .
      "and a.accession != '_' " .
      "and b.ORGANISM = '$org' " .
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and a.PROTOCOL  = b.CODE " .
      "group by a.tag";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($accession, $count) = $stm->fetchrow_array()) {
    $accum_a{$count}++;
  }

  push @rows, "<a href=\"#Clusters\"" .
      ">Cluster</a> density table<br><br>";
  push @rows, "<a href=\"#Accessions\"" .
      ">Unclustered accession </a> density table<br><br><br>";

  push @rows, "<a name=Clusters><b>Cluster Density Table</b></a>" .
      "<br><br>";
  push @rows,
      "<p>" .
      "<table border=1 cellspacing=1 cellpadding=4>";
  push @rows, "<tr><td><b># of distinct clusters</b></td>" .
      "<td><b># of tags</b></td></tr>";
  for (sort r_numerically keys %accum_c) {
    $count = $accum_c{$_};
    push @rows, "<tr><td>$_</td><td>" .
        ( $count < 501 ?
          ("<a href=\"/SAGE/TagList?" .
          "FORMAT=html&RANK=$rank_limit&WHAT=c&MAPCARD=$_\">$count</a>") :
          $count
        ) .
        "</td></tr>";
  }
  push @rows, "</table>";

  push @rows, "<br><br>";

  push @rows, "<a name=Accessions><b>Unclustered Accession " .
      "Density Table</b></a>" .
      "<br><br>";
  push @rows,
      "<p>" .
      "<table border=1 cellspacing=1 cellpadding=4>";
  push @rows, "<tr><td><b># of distinct unclustered accessions</b></td>" .
      "<td><b># of tags</b></td></tr>";
  for (sort r_numerically keys %accum_a) {
    $count = $accum_a{$_};
    push @rows, "<tr><td>$_</td><td>" .
        ( $count < 501 ?
          ("<a href=\"/SAGE/TagList?" .
          "FORMAT=html&RANK=$rank_limit&WHAT=a&MAPCARD=$_\">$count</a>") :
          $count
        ) .
        "</td></tr>";
  }
  push @rows, "</table>";

  return join("\n", @rows);
}

######################################################################
sub GetGenesForTag_1 {
  my ($base, $org, $method, $format, $tag, $show_details) = @_;

  $BASE = $base;
  $method =~ s/\s//g;

## !!! For now, always show details on tag
  $show_details = 1;
## !!! For now, always show details on tag

  my ($accession, $cluster_number, $gene, $rank, $title);
  my ($db, $sql, $stm);
  my (%already_seen, $lowest_rank, $frequency, %tags_hit, %tag2freq);
  my ($best_tag);

  my $HEADER_ROW =
    "<tr>" .
    "<td><b>Gene<br>Symbol</b></td>" .
    "<td><b>Name</b></td>" .
    "<td><b>Database</b></td>" .
    "<td><b>Rank</b></td>" .
    "<td><b>Virtual Tag Classification&#185;</b></td>" .
    "<td><b>Accession</b></td>" .
    "<td align=center><b>LT<br>Viewer</b></td>" .
    "<td><b>Gene Info</b></td>" .
    (($org eq 'Mm') ? "<td><b>SAGE Expression Matrix</b></td>" : "") .
    "</tr>";


  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  my $MAGIC_RANK = GetMagicRank($db, $org, $method);
  GetRepetitives($db, \%repetitives, $org, $method);
  GetConfidenceLevels($db, \%datasets, $org, $method);

  $tag =~ s/\s+//g;
  $tag =~ tr/a-z/A-Z/;

  $tags_hit{$tag} = 1;
  GetFreqsOfTags($db, $org, \%tags_hit, \%tag2freq, $method);

  if (defined $tag2freq{$tag}) {
    $frequency = $tag2freq{$tag};
  } else {
    $frequency = 0;
  }

  my @rows;

  push @rows,
    "<p><b>Search query:</b>" .
    "<blockquote>" .
    "<table border=1 cellspacing=1 cellpadding=4>" .
    "<tr>" .
    "<td><b>Tag</b></td>" .
    "<td align=center><b>Freq.</b></td>" .
    "<td align=center><b>Digital Northern</b></td>" .
    ($org eq "Hs" ? "<td colspan=3><b>SAGE Anatomic Viewer&#178;</b></td>" : "") .
    ($org eq "Mm" ? "<td colspan=3><b>SAGE Expression Matrix</b></td>" : "") .
    "</tr>";

  push @rows, NewFormatMapRow($org, $method, "DATASET_LESS",
      $frequency,
      (defined $repetitives{$tag} ? "$tag#" : $tag),
      $accession, $gene,
      $cluster_number, $rank, $title, $best_tag, $show_details);

  push @rows, "</table></blockquote>";

  push @rows, DividerBar("Best Gene for Tag");

  push @rows,
      "<p>" .
      "<table border=1 cellspacing=1 cellpadding=4>";
  push @rows, $HEADER_ROW;

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  my $cluster_table =
    ($org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster" : "$CGAP_SCHEMA.mm_cluster");

  $sql = "select m.accession, m.cluster_number, c.gene, m.rank, c.description " .
      "from $CGAP_SCHEMA.sagemap m, $cluster_table c, " .
      "$CGAP_SCHEMA.sageprotocol b  " .
      "where m.cluster_number = c.cluster_number (+) " .
      "and m.tag = '$tag' " .
      "and b.ORGANISM = '$org' " .
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and m.PROTOCOL  = b.CODE " .
      "order by m.rank, m.accession, m.cluster_number" ;

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  my $count = 0;
  ## use bind_columns: want vars to have values outside loop
  $stm->bind_columns(\$accession, \$cluster_number, \$gene, \$rank, \$title);
  while($stm->fetch()) {
    if (not defined $lowest_rank) {
      $lowest_rank = $rank;
    }

    if ($cluster_number && (not $already_seen{$cluster_number})) {
      $already_seen{$cluster_number} = 1;
      if ($lowest_rank > $MAGIC_RANK || $rank <= $MAGIC_RANK) {
        if ($show_details || $rank == $lowest_rank) {

          $count++;
          if ($count == 2) {
            push @rows, "<p>";
            push @rows, DividerBar("Other Gene(s) for Tag");
            push @rows,
                "<p>" .
                "<table border=1 cellspacing=1 cellpadding=4>";
            push @rows, $HEADER_ROW;
          }
          push @rows, NewFormatMapRow($org, $method, "TAG_LESS",
              $frequency, $tag, $accession, $gene,
              $cluster_number, $rank, $title, $best_tag, $show_details);
          if ($count == 1) {
            push @rows, "</table>";
            push @rows,
              "<blockquote><font color=\"#339999\"><b>View " .
              "<a href=\"" . ($cluster_number ? "TagByCID" : "TagByAcc") .
              "?FORMAT=$format&DETAILS=1&" .
              "TERM=$gene&ACC=$accession&CID=$org\." .
              "$cluster_number&ORG=$org&METHOD=$method\">" .
              "all tags</a> for gene</b></font></blockquote>";
          }

        }
      }
    } elsif ((not $cluster_number) && (not $already_seen{$accession})) {
      $already_seen{$accession} = 1;
      if ($lowest_rank > $MAGIC_RANK || $rank <= $MAGIC_RANK) {
        if ($show_details || $rank == $lowest_rank) {

          $count++;
          if ($count == 2) {
            push @rows, "<p>";
            push @rows, DividerBar("Other Gene(s) for Tag");
            push @rows,
                "<p>" .
                "<table border=1 cellspacing=1 cellpadding=4>";
            push @rows, $HEADER_ROW;
          }
          push @rows, NewFormatMapRow($org, $method, "TAG_LESS",
              $frequency, $tag, $accession, $gene,
              $cluster_number, $rank, $title, $best_tag, $show_details);
          if ($count == 1) {
            push @rows, "</table>";
            push @rows,
              "<blockquote><font color=\"#339999\"><b>View " .
              "<a href=\"" . ($cluster_number ? "TagByCID" : "TagByAcc") .
              "?FORMAT=$format&DETAILS=1&" .
              "TERM=$gene&ACC=$accession&CID=$org\." .
              "$cluster_number&ORG=$org&METHOD=$method\">" .
              "all tags</a> for gene</b></font></blockquote>";
          }

        }
      }
    }

  }

  if ($count > 1) {
    push @rows, "</table>";
  }

  my @no_gene_msg;

  if (not defined $lowest_rank) {
    $sql = "select unique s.gene_fl, s.type " .
      "from $CGAP_SCHEMA.ltv_snp s, $CGAP_SCHEMA.sageprotocol b, " .
      "$CGAP_SCHEMA.ltv_sage_tag t " .
      "where s.newtag = '$tag' " .
      "and t.gene_fl = s.gene_fl " . ## don't want to retrieve accs
                                     ## that are not already in the main
                                     ## ltv table
      "and s.protocol = b.code " .
      "and b.protocol in ('$method_list') " .
      "and b.organism = '$org'";

    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    my ($accession, $type);
    $stm->bind_columns(\$accession, \$type);
    while($stm->fetch()) {
      if ($type eq "in") {
      push @no_gene_msg,
        "new tag created by a SNP within the 3'-most tag sequence " .
        "in accession $accession: " .
        LTV_URL($accession, $org, $method);
      } elsif ($type eq "mk") {
      push @no_gene_msg,
        "new tag resulting from a SNP's creating a new 3'-most NlaIII site " .
        "in accession $accession: " .
        LTV_URL($accession, $org, $method);
      }
    }
  }

  $db->disconnect();

  if (not defined $lowest_rank) {
    if (@no_gene_msg) {
      return join("<br>\n", @no_gene_msg) . "\n";
    } else {
      return "No genes found for this tag<br>\n";
    }
  }

  return join("\n", @rows);

}

######################################################################
sub GetFreqsOfTags {
  my ($db, $org, $tags_hit, $tag2freq, $method) = @_;

  if( $method eq "LS21" ) {
    for my $tag ( keys %{ $tags_hit }){
      $$tag2freq{$tag} = 0;
    }
    return;
  }
  my ($sql, $stm);
  my ($tag, $freq);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  my $list;
  my @taglist = keys %{ $tags_hit };
  for(my $i = 0; $i < @taglist; $i += ORACLE_LIST_LIMIT) {
 
    if(($i + ORACLE_LIST_LIMIT - 1) < @taglist) {
      $list = "'" . join("','", @taglist[$i..$i+ORACLE_LIST_LIMIT-1]) . "'";
    }
    else {      $list = "'" . join("','", @taglist[$i..@taglist-1]) . "'";
    }
    $sql = "select f.tag, sum(f.frequency) " . 
      "from $CGAP_SCHEMA.sagefreq f, $CGAP_SCHEMA.sagelibinfo i " .
      "where tag in ($list) " .
      "and i.sage_library_id = f.sage_library_id " .
      "and i.organism = '$org' " .
      "and i.quality = " . GOOD_LIB_QUALITY . " " .
      "and i.tags >= " . MIN_LIB_SIZE . " " .
      "and i.method in ('$method_list') " .
      "group by tag";

    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    while (($tag, $freq) = $stm->fetchrow_array()) {
      $$tag2freq{$tag} = $freq;
    }
  }
}

######################################################################
sub GetTissueList_1 {
  my ($org, $method) = @_;

  my ($tissue, $protocol, $tissue_text);
  my ($db, $sql, $stm);
  my (@rows);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  if ($org eq 'Hs') {
    if ($method eq 'LS17') {
      $protocol = "'C'";
    } else {
      $protocol = "'A', 'B'";
    }
  } elsif ($org eq 'Mm') {
    if ($method eq 'LS17') {
      $protocol = "'M'";
    } else {
      $protocol = "'K', 'L'";
    }
  }

  $sql = "select unique tissue from $CGAP_SCHEMA.sagelibinfo " .
      "where protocol in ($protocol) " .
      "and tags > 0 " ;

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while (($tissue) = $stm->fetchrow_array()) {
    next if (($tissue eq 'other') || ($tissue eq 'uncharacterized tissue'));
    if ($tissue eq 'breast') {
      $tissue_text = 'Breast/Mammary Gland';
    } elsif ($tissue eq 'mammary gland') {
      $tissue_text = 'Mammary Gland/Breast';
    } else {
      $tissue_text = ucfirst $tissue;
    }
    push @rows, "<option value=\"$tissue\">$tissue_text</option>";
  }

  $db->disconnect();

  return join("\n", @rows);
}

######################################################################
sub NewFormatMapRow {
  my ($org, $method, $style, $freq, $tag, $acc, $gene, $cid, 
    $rank, $title, $best_tag, $show_details) = @_;

  my ($freq_cell, $dn_cell, $tag_cell, $acc_cell, $sym_cell, $mem_cell,
      $title_cell, $rank_cell, $dataset_cell, $dataset_type_cell,
      $gene_info_cell, $ltv_cell, $av_cell0, $av_cell1, $av_cell2);

  my $tag1 = $tag;
  $tag1 =~ s/\*//;     ## the '*' diacritic

  if ($freq) {
    $freq_cell = $freq;
    $dn_cell  = "<a href=\"FreqsOfTag?ORG=$org&METHOD=$method&FORMAT=html&TAG=$tag1\">DN</a>";
    $av_cell0 = "<a href=\"Viewer?TAG=$tag1&CELL=0&ORG=$org&METHOD=$method\">" .
##        "no cl</a>";
        "<img src=\"images/bodyicon.gif\" alt=\"Tissues only\" border=0&ORG=$org&METHOD=$method></a>";
    $av_cell1 = "<a href=\"Viewer?TAG=$tag1&CELL=1&ORG=$org&METHOD=$method\">" .
##        "only cl</a>";
        "<img src=\"images/cellicon.gif\" alt=\"Cell lines only\" border=0></a>";
    $av_cell2 = "<a href=\"Viewer?TAG=$tag1&CELL=2&ORG=$org&METHOD=$method\">" .
##        "both</a>";
        "<img src=\"images/bodycell.gif\" alt=\"Tissues + Cell lines\" border=0></a>";
    $mem_cell = "<a href=\"MEMatrix?ORG=$org&METHOD=$method&FORMAT=html&TAG=$tag1&STATE=\">mSEM</a>";
  } else {
    $freq_cell = "0";
    $dn_cell  = "&nbsp;";
    $av_cell0 = "&nbsp;";
    $av_cell1 = "&nbsp;";
    $av_cell2 = "&nbsp;";
    $mem_cell = "&nbsp;";
  }

  if ($style eq "DATASET_LESS") {
    $tag_cell = $tag;
  } else {
    $tag_cell = "<a href=\"GeneByTag?ORG=$org&METHOD=$method&FORMAT=html&" .
        "TAG=$tag1\">$tag" . 
        (defined $repetitives{$tag1} ? "#" : "") .
        "</a>";
  }

  if ($title) {
    $title_cell = $title;
  } else {
    $title_cell = "\&nbsp;";
  }

  if ($acc eq "" or $acc eq "_") {
    $acc_cell = "\&nbsp;";
    $ltv_cell = "\&nbsp;";
  } else {
    $acc_cell = GB_URL($acc, $org);
    if ($datasets{$rank}{id} =~ /^nu_/) {
      $ltv_cell = "\&nbsp;";
    }elsif ($datasets{$rank}{id} =~ /^transfrag/) {
      $ltv_cell = "\&nbsp;";
    } else {
      $ltv_cell = LTV_URL($acc, $org, $method);
    }
  }

  if ($gene) {
    $sym_cell = $gene;
    $gene_info_cell = GENE_INFO_URL($cid, $org);
  } elsif ($acc eq $MITO_ACC) {
    $sym_cell = "<font color=red>mitochondria</font>";
    $gene_info_cell = "&nbsp;";
  } elsif ($cid) {
    if( $org eq "Hs" ) {
      $sym_cell = "Hs.$cid";
    }
    elsif($org eq "Mm" ) {
      $sym_cell = "Mm.$cid";
    }
    $gene_info_cell = GENE_INFO_URL($cid, $org);
  } else {
    $sym_cell = "&nbsp;";
    $gene_info_cell = "&nbsp;";
  }
  $gene_info_cell or $gene_info_cell = "\&nbsp;";

  $rank_cell = sprintf("%.1f\%", $datasets{$rank}{percent});

  $dataset_cell = "<a href=\"DataSets?RANK=$rank&ORG=$org&METHOD=$method\">" .
      "$datasets{$rank}{id}</a>";

  $dataset_type_cell = CharacterizeDataset($rank);

## salmon = ffccff
## green = 99ff99

##  if ($best_tag && $show_details && ($tag1 eq $best_tag)) {
  if ($best_tag && ($tag1 eq $best_tag)) {
    $tag_cell = "<td bgcolor=\"#ffccff\">$tag_cell</td>";
  } else {
    $tag_cell = "<td>$tag_cell</td>";
  }
  $freq_cell    = "<td>$freq_cell</td>";
  $dn_cell      = "<td align=center>$dn_cell</td>";
  $dataset_cell = "<td>$dataset_cell</td>";
  $rank_cell    = "<td>$rank_cell</td>";
  $dataset_type_cell = "<td>$dataset_type_cell</td>";
  $acc_cell     = "<td>$acc_cell</td>";
  $ltv_cell     = "<td align=center>$ltv_cell</td>";
  $sym_cell     = "<td>$sym_cell</td>";
  $gene_info_cell   = "<td>$gene_info_cell</td>";
  $title_cell   = "<td>$title_cell</td>";
  $av_cell0     = "<td>$av_cell0</td>";
  $av_cell1     = "<td>$av_cell1</td>";
  $av_cell2     = "<td>$av_cell2</td>";
  $mem_cell     = "<td align=center>$mem_cell</td>";

  if ($org eq 'Hs') {
    if ($style eq "GENE_LESS") {
      return join("\n",
        "<tr>",
        $tag_cell,
        $freq_cell,
        $dataset_cell,
        $rank_cell,
        $dataset_type_cell,
        $acc_cell,
        $ltv_cell,
        $dn_cell,
        $av_cell0,
        $av_cell1,
        $av_cell2,
        "</tr>"
      );
    } elsif ($style eq "AV_LESS") {
      return join("\n",
        "<tr>",
        $tag_cell,
        $freq_cell,
        $dataset_cell,
        $rank_cell,
        $dataset_type_cell,
        $acc_cell,
        $ltv_cell,
        $sym_cell,
        $title_cell,
        $gene_info_cell,
        "</tr>"
      );
    } elsif ($style eq "TAG_LESS") {
      return join("\n",
        "<tr>",
        $sym_cell,
        $title_cell,
        $dataset_cell,
        $rank_cell,
        $dataset_type_cell,
        $acc_cell,
        $ltv_cell,
        $gene_info_cell,
        "</tr>"
      );
    } elsif ($style eq "DATASET_LESS") {
      return join("\n",
        "<tr>",
        $tag_cell,
        $freq_cell,
        $dn_cell,
        $av_cell0,
        $av_cell1,
        $av_cell2,
        "</tr>"
      );
    } else {
      print STDERR "unrecognized style: $style\n";
    }
  } elsif ($org eq 'Mm') {
    if ($style eq "GENE_LESS") {
      return join("\n",
        "<tr>",
        $tag_cell,
        $freq_cell,
        $dataset_cell,
        $rank_cell,
        $dataset_type_cell,
        $acc_cell,
        $ltv_cell,
        $dn_cell,
        $mem_cell,
        "</tr>"
      );
    } elsif ($style eq "AV_LESS") {
      return join("\n",
        "<tr>",
        $tag_cell,
        $freq_cell,
        $dataset_cell,
        $rank_cell,
        $dataset_type_cell,
        $acc_cell,
        $ltv_cell,
        $sym_cell,
        $title_cell,
        $gene_info_cell,
        $mem_cell,
        "</tr>"
      );
    } elsif ($style eq "TAG_LESS") {
      return join("\n",
        "<tr>",
        $sym_cell,
        $title_cell,
        $dataset_cell,
        $rank_cell,
        $dataset_type_cell,
        $acc_cell,
        $ltv_cell,
        $gene_info_cell,
        $mem_cell,
        "</tr>"
      );
    } elsif ($style eq "DATASET_LESS") {
      return join("\n",
        "<tr>",
        $tag_cell,
        $freq_cell,
        $dn_cell,
        $mem_cell,
        "</tr>"
      );
    } else {
      print STDERR "unrecognized style: $style\n";
    }
  }
}

######################################################################
sub GetHomonymsOfTags {
  my ($db, $magic_rank, $taglist, $disregard_accs, $homonyms, 
                                  $cids_hit, $org, $method) = @_;

  my ($sql, $stm);
  my ($tag, $accession, $cluster_number, $rank);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  my $list;
  for(my $i = 0; $i < @{ $taglist }; $i += ORACLE_LIST_LIMIT) {
 
    if(($i + ORACLE_LIST_LIMIT - 1) < @{ $taglist }) {
      $list = "'" . join("','", @{ $taglist }[$i..$i+ORACLE_LIST_LIMIT-1]) . "'";
    }
    else {
      $list = "'" . join("','", @{ $taglist }[$i..@{ $taglist }-1]) . "'";
    }

    $sql = "select a.tag, a.accession, a.cluster_number, a.rank " .
      "from $CGAP_SCHEMA.sagemap a, $CGAP_SCHEMA.sageprotocol b " .
      "where a.tag in ($list)" .
      ## (@{ $disregard_accs } > 0 ?      
      ##     ("and a.accession not in ('" .
      ##      join("','", @{ $disregard_accs }) . "') ")
      ##     : ""
      ## ) .
      (keys %{ $cids_hit } > 0 ?      
          ("and a.cluster_number not in (" .
           join(",", keys %{ $cids_hit }) . ") ")
          : ""
      ) .     
      "and a.rank <= $magic_rank " .
      "and b.ORGANISM = '$org' " .
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and a.PROTOCOL  = b.CODE " .
      "order by a.rank, a.tag, a.accession";

    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
  
    while(($tag, $accession, $cluster_number, $rank) =
        $stm->fetchrow_array()) {
      if( not defined $$disregard_accs{$accession} ) {
        push @{ $$homonyms{$tag} },
          "$tag\t$accession\t$cluster_number\t$rank";
        if ($cluster_number) {
    	  $$cids_hit{$cluster_number}= 1;
        }
      }
    }
  }
}

######################################################################
sub GetTagsByCID {
  my ($db, $cidlist, $by_rank, $tags_hit, $accs_hit,
      $cids_hit, $org, $method) = @_;

  my ($sql, $stm);
  my ($tag, $accession, $cluster_number, $rank);
  my ($lowest_rank);

  $method =~ s/\s//g;
  my $method_list = $method;
  $method_list =~ s/,/','/g;

  my $MAGIC_RANK = GetMagicRank($db, $org, $method);

  $sql = "select a.tag, a.accession, a.cluster_number, a.rank " .
      "from $CGAP_SCHEMA.sagemap a, $CGAP_SCHEMA.sageprotocol b " .
      "where a.cluster_number in (" . join(",", @{ $cidlist }) . ") " .
      "and b.ORGANISM = '$org' " .
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and a.PROTOCOL  = b.CODE " .
      "order by a.rank, a.tag, a.accession";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($tag, $accession, $cluster_number, $rank) =
      $stm->fetchrow_array()) {
    if (not defined $lowest_rank) {
      $lowest_rank = $rank;
    } elsif ($lowest_rank <= $MAGIC_RANK && $rank > $MAGIC_RANK) {
      next;
    }
    $$tags_hit{$tag} = 1;
    if ($accession && $accession ne "_") {
      $$accs_hit{$accession} = 1;
    }
    if ($cluster_number) {
      $$cids_hit{$cluster_number} = 1;
    }
    push @{ $$by_rank{$rank} }, "$tag\t$accession\t$cluster_number";
  }
}

######################################################################
sub GetTagsForAccession_1 {
  my ($base, $org, $method, $format, $acc) = @_;

  my ($db, $sql, $stm);
  my ($tag, $cluster_number, $rank);
  my (%tags, %rank2tag, %tag2freq);
  my (@rows, $tag_diacritic);
  my ($undef_gene, $undef_cluster, $undef_best_tag, $undef_title);
  my $no_show_details = 0;

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  GetRepetitives($db, \%repetitives, $org, $method);
  GetConfidenceLevels($db, \%datasets, $org, $method);

  $acc =~ s/\s+//g;
  $acc = uc($acc);

  $method =~ s/\s//g;
  my $method_list = $method;
  $method_list =~ s/,/','/g;

  my $MAGIC_RANK = GetMagicRank($db, $org, $method);

  $sql =
      "select " .
      "a.tag, a.cluster_number, a.rank " .
      "from $CGAP_SCHEMA.sagemap  a, $CGAP_SCHEMA.sageprotocol b " .
      "where a.accession = '$acc' " .
      "and b.ORGANISM = '$org' " .
      "and b.PROTOCOL in ( '$method_list' ) " .
      "and a.PROTOCOL  = b.CODE " .
      "order by a.rank, a.tag";
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while (($tag, $cluster_number, $rank) = $stm->fetchrow_array()) {
    if (not defined $tags{$tag} || $rank < $tags{$tag}) {
      $tags{$tag} = $rank;
    }
  }

  if (scalar (keys %tags) == 0) {
    my $msg;
    if (AccHasNoAnchor($db, $acc)) {
      $msg = "$acc has no NlaIII site<br>\n";
    } else {
      $msg = "No tags found for $acc<br>\n";
    }
    $db->disconnect();
    return $msg;
  }

  push @rows,
    "<p>" .
    "<table border=1 cellspacing=1 cellpadding=4 width=100%>";
  push @rows, "<tr>" .
      "<td><b>Tag</b></td>" .
      "<td align=center><b>Freq.</b></td>" .
      "<td><b>Database</b></td>" .
      "<td><b>Rank</b></td>" .
      "<td><b>Virtual Tag Classification&#185;</b></td>" .
      "<td><b>Accession</b></td>" .
      "<td align=center><b>LT<br>Viewer</b></td>".
      "<td align=center><b>Digital Northern</b></td>" .
      (($org eq 'Hs') ? "<td colspan=3><b>SAGE Anatomic Viewer&#178;</b></td>" : "") .
      (($org eq 'Mm') ? "<td colspan=3><b>SAGE Expression Matrix</b></td>" : "") .
      "</tr>";

  for $tag (keys %tags) {
    ## only one tag for this accession at this rank
    $rank2tag{$tags{$tag}} = $tag;
  }

  GetFreqsOfTags($db, $org, \%tags, \%tag2freq, $method);

  $db->disconnect();

  for $rank (sort numerically keys %rank2tag) {
    $tag = $rank2tag{$rank};
    $tag_diacritic = $tag . (defined $repetitives{$tag} ? "#" : "");
    push @rows, NewFormatMapRow($org, $method, "GENE_LESS",
        $tag2freq{$tag}, $tag_diacritic, $acc, $undef_gene,
        $undef_cluster, $rank, $undef_title, $undef_best_tag, $no_show_details);
  }

  push @rows, "</table>";
  return join("\n", @rows) . "\n";
}

######################################################################
sub GetTagsByAcc {
  my ($db, $term, $by_rank, $tags_hit, $accs_hit,
      $cids_hit, $org, $method) = @_;

  my ($sql, $stm);
  my ($the_cluster, %accum);
  my $lowest_rank = $IMPOSSIBLY_LARGE_RANK;
  my ($tag, $accession, $cluster_number, $rank);

  $method =~ s/\s//g;
  my $method_list = $method;
  $method_list =~ s/,/','/g;

  my $MAGIC_RANK = GetMagicRank($db, $org, $method);

  ##
  ## Now try for the cluster containing the accession
  ##
  my $ug_sequence_table =
    ($org eq "Hs"?"$CGAP_SCHEMA.hs_ug_sequence":"$CGAP_SCHEMA.mm_ug_sequence ");

  $sql =
      "select cluster_number " .
      "from $ug_sequence_table " .
      "where accession = '$term'";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  $cluster_number = 0;
  while (($cluster_number) = $stm->fetchrow_array()) {
    $the_cluster = $cluster_number;
  }
  if ((not $the_cluster) && $term =~ /^NM_\d\d\d\d/) {
    ## Sometimes the NM_ accessions are not in UniGene (sigh)

    my $cluster_table =
      ($org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster" : "$CGAP_SCHEMA.mm_cluster");

    $sql =
        "select cluster_number " .
        "from $cluster_table " .
        "where sequences like '%$term%'";
    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    while (($cluster_number) = $stm->fetchrow_array()) {
      $the_cluster = $cluster_number;
    }
  }

  ##
  ## Now have a look in the map for the cluster
  ##
  if ($the_cluster) {
    $sql =
        "select " .
        "a.tag, a.accession, a.cluster_number, a.rank " .
        "from $CGAP_SCHEMA.sagemap a, $CGAP_SCHEMA.sageprotocol b " .
        "where a.cluster_number = $the_cluster " .
        "and b.ORGANISM = '$org' " .
        "and b.PROTOCOL in ( '$method_list' ) " .
        "and a.PROTOCOL = b.CODE";
    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    while (($tag, $accession, $cluster_number, $rank) =
        $stm->fetchrow_array()) {
      $accum{"$tag\t$accession\t$cluster_number\t$rank"} = 1;
      if ($rank < $lowest_rank) {
        $lowest_rank = $rank;
      }
    }
  }

  for (keys %accum) {
    ($tag, $accession, $cluster_number, $rank) = split /\t/;
    if ( ($lowest_rank > $MAGIC_RANK) || ($rank <= $MAGIC_RANK) ||
        ($accession eq $term) ) {      ## keep all hits on original acc
      $$tags_hit{$tag} = 1;
      if ($accession && $accession ne "_") {
        $$accs_hit{$accession} = 1;
      }
      if ($cluster_number) {
        $$cids_hit{$cluster_number} = 1;
      }
      push @{ $$by_rank{$rank} }, "$tag\t$accession\t$cluster_number";
    }
  }
}

######################################################################
sub GetSymsOfCIDs {
  my ($db, $cids_hit, $cid2sym, $cid2title, $org) = @_;

  my ($sql, $stm);
  my ($cluster_number, $gene, $title);
  my ($i, $list);
  my @cids = keys %{ $cids_hit };

  if (@cids == 0) {
    return;
  }

  my $cluster_table = 
      ($org eq "Hs" ? "$CGAP_SCHEMA.hs_cluster" : "$CGAP_SCHEMA.mm_cluster");

  for($i = 0; $i < @cids; $i += ORACLE_LIST_LIMIT) {
 
    if(($i + ORACLE_LIST_LIMIT - 1) < @cids) {
      $list = join(",", @cids[$i..$i+ORACLE_LIST_LIMIT-1]);
    }
    else {
      $list = join(",", @cids[$i..@cids-1]);
    }

    $sql = "select cluster_number, gene, description " . 
        "from $cluster_table " .
        "where cluster_number in ($list)";

    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    while (($cluster_number, $gene, $title) = $stm->fetchrow_array()) {
      if ($gene) {
        $$cid2sym{$cluster_number} = $gene;
      }
      if ($title) {
        $$cid2title{$cluster_number} = $title;
      }
    }
  }
}

######################################################################
sub AccHasNoAnchor {
  my ($db, $acc) = @_;

  my ($sql, $stm);
  my ($accession);
  my $found = 0;

  $sql = "select accession from $CGAP_SCHEMA.sage_no_anchor " .
      "where accession = '$acc'";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while (($accession) = $stm->fetchrow_array()) {
    $found = 1;
  }
  return $found;
}


######################################################################
sub GetTagsForGene_1 {
  my ($base, $org, $method, $format, $cid, $acc, 
                                     $term, $show_details) = @_;

  $BASE = $base;

  my ($sym);
  my (%by_rank, %by_cid, %by_acc, @acc_list, @cid_list);
  my (%accs_hit, %tags_hit, %cids_hit, %cid2sym, %tag2freq, %homonyms,
      %cid2title);
  my (@hit_tag_list, @hit_acc_list, @hit_cid_list);
  my ($tag, $accession, $cluster_number, $rank);
  my ($gene, $frequency, $title);
  my ($best_tag, $tag_star);
  my (@ranks, $homonym_rank);
  my (%already_seen, %cluster_seen, %tag_seen, @rows);

  my ($db);
  $method =~ s/\s//g;

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  GetRepetitives($db, \%repetitives, $org, $method);
  GetConfidenceLevels($db, \%datasets, $org, $method);

  $cid =~ s/\s+/ /g;
  $cid =~ s/^ //;
  $cid =~ s/ $//;
  $cid =~ tr/a-z/A-Z/;

  $cid =~ s/HS\.//;
  $cid =~ s/MM\.//;

  $acc =~ s/\s+/ /g;
  $acc =~ s/^ //;
  $acc =~ s/ $//;
  $acc =~ tr/a-z/A-Z/;

  $term =~ s/\s+/ /g;
  $term =~ s/^ //;
  $term =~ s/ $//;
  $term =~ tr/a-z/A-Z/;

  $term =~ tr/*/%/;
  $term =~ s/%{2,}/%/g;

  if ($acc) {
    push @acc_list, $acc;
  }

  if ($cid) {
    push @cid_list, $cid;
    GetTagsByCID($db, \@cid_list, \%by_rank, \%tags_hit,
        \%accs_hit, \%cids_hit, $org, $method);
  } else {
    GetTagsByAcc($db, $acc, \%by_rank, \%tags_hit,
        \%accs_hit, \%cids_hit, $org, $method);
  }

  @hit_cid_list = keys %cids_hit;  ## at this point, should be max 1
  if (@hit_cid_list > 0) {
    $cid = $hit_cid_list[0];
  } else { 
    $cid = "";
    return "No genes found<br>\n";
  } 

  @hit_tag_list = keys %tags_hit;
  @hit_acc_list = keys %accs_hit;

  if (@hit_tag_list == 0) {
    $db->disconnect();
    return "No tags found for gene<br>\n";;
  }

  @ranks = sort numerically keys %by_rank;
  my $MAGIC_RANK = GetMagicRank($db, $org, $method);
  $homonym_rank =
      ($ranks[0] <= $MAGIC_RANK) ? $MAGIC_RANK : $IMPOSSIBLY_LARGE_RANK;

  GetHomonymsOfTags($db, $homonym_rank, \@hit_tag_list, \%accs_hit,
      \%homonyms, \%cids_hit, $org, $method);

  GetSymsOfCIDs($db, \%cids_hit, \%cid2sym, \%cid2title, $org);

  if ($cid && defined $cid2sym{$cid}) {
    $sym = $cid2sym{$cid};
  } else {
    $sym = "";
  }
  if ($cid && defined $cid2title{$cid}) {
    $title = $cid2title{$cid};
  } else {
    $title = "";
  }

  GetFreqsOfTags($db, $org, \%tags_hit, \%tag2freq, $method);

  $best_tag = PickBestTagForGene($db, $cid, "", $org, $method);

  $db->disconnect();

  push @rows, "<p><b>Search query:</b> $sym ($title), " .
    GENE_INFO_URL($cid, $org) . "<br><br>";

  if ($show_details) {
    push @rows, DividerBar("List of Tags for Gene");
  } else {
    push @rows, DividerBar("Best Tag for Gene");
  }
  push @rows,
    "<p>" .
    "<table border=1 cellspacing=1 cellpadding=4 width=100%>";
  push @rows, "<tr>" .
      "<td><b>Tag</b></td>" .
      "<td align=center><b>Freq.</b></td>" .
      "<td><b>Database</b></td>" .
      "<td><b>Rank</b></td>" .
      "<td><b>Virtual Tag Classification&#185;</b></td>" .
      "<td><b>Accession</b></td>" .
      "<td align=center><b>LT<br>Viewer</b></td>" .
      "<td align=center><b>Digital Northern</b></td>" .
      (($org eq 'Hs') ? "<td colspan=3><b>SAGE Anatomic Viewer&#178;</b></td>" : "") .
      (($org eq 'Mm') ? "<td colspan=3><b>SAGE Expression Matrix</b></td>" : "") .
      "</tr>";

  for my $r (sort numerically keys %by_rank) {
    for my $p (@{ $by_rank{$r} }) {
      if (not $already_seen{$p}) {
        $already_seen{$p} = 1;
        ($tag, $accession, $cluster_number) = split(/\t/, $p);
        if (defined $cid2sym{$cluster_number}) {
          $gene = $cid2sym{$cluster_number};
        } else {
          $gene = "";
        }
        if (defined $cid2title{$cluster_number}) {
          $title = $cid2title{$cluster_number};
        } else {
          $title = "";
        }

        if (defined $tag2freq{$tag}) {
          $frequency = $tag2freq{$tag};
        } else {
          $frequency = 0;
        }
        if (defined $homonyms{$tag}) {
          $tag_star = "$tag*";
        } else {
          $tag_star = $tag;
        }

        if ($show_details || $tag eq $best_tag) {

          push @rows, NewFormatMapRow($org, $method, "GENE_LESS",
              $frequency, $tag_star, $accession, $gene,
              $cluster_number, $r, $title, $best_tag, $show_details);

        }

      }
    }
  }

  push @rows, "</table>";

  if (not $show_details) {
    push @rows,
        "<blockquote><font color=\"#339999\"><b>View " .
        "<a href=\"" . ($cid ? "TagByCID" : "TagByAcc") .
        "?FORMAT=$format&DETAILS=1&" .
        "TERM=$term&ACC=$acc&CID=$org\." .
        "$cid&ORG=$org&METHOD=$method\">" .
        "all tags</a> for gene</b></font></blockquote>";
  }

  if (keys %homonyms) {
    if ($show_details || (defined $homonyms{$best_tag}) ) {
      push @rows, "<p>";
      push @rows, DividerBar("Other Gene(s) Mapping to Above Tag(s)");
      push @rows,
          "<p>" .
          "<table border=1 cellspacing=1 cellpadding=4 width=100%>";
      push @rows, "<tr>" .
          "<td><b>Tag</b></td>" .
          "<td align=center><b>Freq.</b></td>" .
          "<td><b>Database</b></td>" .
          "<td><b>Rank</b></td>" .
          "<td><b>Virtual Tag Classification&#185;</b></td>" .
          "<td><b>Accession</b></td>" .
          "<td align=center><b>LT<br>Viewer</b></td>" .
          "<td><b>Gene<br>Symbol</b></td>" .
          "<td><b>Name</b></td>" .
          "<td><b>Gene Info</b></td>" .
          (($org eq 'Mm') ? "<td><b>SAGE Expression Matrix</b></td>" : "") .
          "</tr>";
    }
    for my $h (sort keys %homonyms) {
      undef %already_seen;
      for my $x (@{ $homonyms{$h} }) {
        ($tag, $accession, $cluster_number, $rank) = split /\t/, $x;
        if (defined $cid2sym{$cluster_number}) {
          $gene = $cid2sym{$cluster_number};
        } else {
          $gene = "";
        }
        if (defined $cid2title{$cluster_number}) {
          $title = $cid2title{$cluster_number};
        } else {
          $title = "";
        }
        if (defined $tag2freq{$tag}) {
          $frequency = $tag2freq{$tag};
        } else {
          $frequency = 0;
        }
        if ($show_details) {
          if ($cluster_number && (not $already_seen{$cluster_number})) {
            $already_seen{$cluster_number} = 1;

            push @rows, NewFormatMapRow($org, $method, "AV_LESS",
                $frequency, $tag, $accession, $gene,
                $cluster_number, $rank, $title, $best_tag, $show_details);

          } elsif ((not $cluster_number) && not ($already_seen{$accession})) {
            $already_seen{$accession} = 1;


            push @rows, NewFormatMapRow($org, $method, "AV_LESS",
                $frequency, $tag, $accession, $gene,
                $cluster_number, $rank, $title, $best_tag, $show_details);

          }
        } elsif (($tag eq $best_tag) && (not $cluster_seen{$cluster_number})) {
          $cluster_seen{$cluster_number} = 1;

            push @rows, NewFormatMapRow($org, $method, "AV_LESS",
                $frequency, $tag, $accession, $gene,
                $cluster_number, $rank, $title, $best_tag, $show_details);

        }
      }
    }

    if ($show_details || (defined $homonyms{$best_tag}) ) {
      push @rows, "</table>";
    }

  }

  return join("\n", @rows)
}

######################################################################
sub FormatFreqRow {
  my ($format, $name, $sage_library_id, $real_freq,
      $frequency, $total_tags, $org) = @_;

  my ($name_cell, $freq_cell, $color_cell, $total_cell, $real_freq_cell);
  my ($color);

  if( ($real_freq eq "") or $real_freq =~ /^\s+$/ ) {
    $real_freq = 0;
  }
  if ($format eq "text") {
    return "$name\t$sage_library_id\t$frequency\t$total_tags";
  } else {
    $name_cell = "<a href=\"SAGELibInfo?" .
        "LID=$sage_library_id&ORG=$org\">$name</a>";
    for (my $c = 0; $c <= @color_breaks; $c++) {
      if ($frequency < $color_breaks[$c]) {
        $color = $color_scale[$c];
        last;
      }
    }
    $color_cell = "&nbsp;&nbsp;&nbsp;";
    $real_freq_cell = "$real_freq";
    $freq_cell = "$frequency";
    $total_cell = $total_tags;
    return "<tr>" .
        "<td>$name_cell</td>" .
        "<td>$total_cell</td>" .
        "<td>$real_freq_cell</td>" .
        "<td>$freq_cell</td>" .
        "<td bgcolor=\"#$color\">$color_cell</td>" .
        "</tr>";
  }
}

######################################################################
sub GetFreqsOfTag_1 {
  my ($org, $method, $format, $tag, $scope, $tiss, $hist, $knockout) = @_;

  my ($db, $sql, $stm);
  my ($name, $sage_library_id, $frequency, $total_tags);
  my ($tiss_list, $hist_list, $knockout_list);
  my (@rows, %freqs, %by_freq, $density);

  $tag =~ s/\s+//g;
  $tag =~ tr/a-z/A-Z/;

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql =
    "select f.sage_library_id, f.frequency " .
    "from $CGAP_SCHEMA.sagefreq f, $CGAP_SCHEMA.sageprotocol b " .
    "where f.tag = '$tag' " .
    "and b.ORGANISM = '$org' " .
    "and b.PROTOCOL in ( '$method_list' ) " .
    "and f.PROTOCOL  = b.CODE "; 
  
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while(($sage_library_id, $frequency) = $stm->fetchrow_array()) {
    $freqs{$sage_library_id} = $frequency;
  }

  if ($knockout) {
    $knockout_list = "'" . join("','", split(",", $knockout)) . "'";
  }
  if ($tiss eq "") {
    $tiss = "all";
  }
  if ($hist eq "") {
    $hist = "all";
  }
  if ($scope eq "") {
    $scope = "2";
  }

  if ($tiss ne "all") {
    $tiss_list = "'" . join("','", split(",", $tiss)) . "'";
  }
  if ($hist ne "all") {
    $hist_list = "'" . join("','", split(",", $hist)) . "'";
  }

  $sql =
      "select n.name, l.sage_library_id, l.tags " .
      "from $CGAP_SCHEMA.sagelibinfo l, $CGAP_SCHEMA.sagelibnames n " .
      "where l.organism = '$org' " .
      "and l.method in ('$method_list') " .
      "and l.sage_library_id = n.sage_library_id " .
      "and l.tags >= " . MIN_LIB_SIZE . " " .
      "and l.quality = " . GOOD_LIB_QUALITY . " " .
      "and n.nametype='DUKE' " .
      ($tiss_list ?
          "and exists (select k1.sage_library_id from " .
          "$CGAP_SCHEMA.sagekeywords k1 " .
          "where k1.sage_library_id = l.sage_library_id " .
          "and k1.keyword in ($tiss_list) ) "
        : ""
      ) .
      ($hist_list ?
          "and exists (select k2.sage_library_id from " .
          "$CGAP_SCHEMA.sagekeywords k2 " .
          "where k2.sage_library_id = l.sage_library_id " .
          "and k2.keyword in ($hist_list) ) "
        : ""
      ) .
      ($knockout_list ?
          "and not exists (select k0.sage_library_id from " .
          "$CGAP_SCHEMA.sagekeywords k0 " .
          "where k0.sage_library_id = l.sage_library_id " .
          "and k0.keyword in ($knockout_list) ) "
        : ""
      ) .
      ($scope == 0 ?
        "and not exists (select k3.sage_library_id " .
            "from $CGAP_SCHEMA.sagekeywords k3 " .
        "where k3.sage_library_id = l.sage_library_id " .
            "and k3.keyword = 'cell line') "
        : ""
      ) .
      ($scope == 1 ?
        "and     exists (select k3.sage_library_id " .
            "from $CGAP_SCHEMA.sagekeywords k3 " .
        "where k3.sage_library_id = l.sage_library_id " .
            "and k3.keyword = 'cell line') "
        : "") . " " .
      "order by n.name";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while(($name, $sage_library_id, $total_tags) =
      $stm->fetchrow_array()) {
#   $density = sprintf("%d", 0.5 + (($freqs{$sage_library_id}*$DENOM)/$total_tags));
    $density = sprintf("%d",  (($freqs{$sage_library_id}*$DENOM)/$total_tags));
    ## if ($tiss ne "all" || $hist ne "all" || $density > 0) {
    if ($tiss ne "all" || $hist ne "all" || $freqs{$sage_library_id} > 0) {
      push @{ $by_freq{$density} }, [$format, $name, $sage_library_id,
          $freqs{$sage_library_id}, $density, $total_tags, $org];
    }
  }

  $db->disconnect();

  if (scalar(keys %by_freq) == 0) {
    return "<b>Tag count = 0</b><br>\n";
  }

 my ($org, $method, $format, $tag, $scope, $tiss, $hist, $knockout) = @_;
  if ($format eq "html") {
    push @rows,
         "<P><B>Search query</B>: $tag";
    if( $tiss ne "" ) {
      push @rows,
         ", $tiss";
    }
    if( $hist ne "" ) {
      push @rows,
         ", $hist";
    }
    if( $scope ne "" ) {
      if( $scope eq "0" ) {
        push @rows,
          ", Tissues only";
      }
      elsif( $scope eq "1" ) {
        push @rows,
          ", Cell lines only";
      }
      elsif( $scope eq "2" ) {
        push @rows,
          ", Tissues and cell lines";
      }
    }
    push @rows,
      "<table border=1 cellspacing=1 cellpadding=4>" .
      "<tr>" .
      "<td><b>Color Code</b></td>" .
      "<td bgcolor=\"\#0000FF\">&nbsp;&nbsp;</td>" .
      "<td bgcolor=\"\#3399FF\">&nbsp;&nbsp;</td>" .
      "<td bgcolor=\"\#66CCFF\">&nbsp;&nbsp;</td>" .
      "<td bgcolor=\"\#99CCFF\">&nbsp;&nbsp;</td>" .
      "<td bgcolor=\"\#CCCCFF\">&nbsp;&nbsp;</td>" .
      "<td bgcolor=\"\#FFCCFF\">&nbsp;&nbsp;</td>" .
      "<td bgcolor=\"\#FF99FF\">&nbsp;&nbsp;</td>" .
      "<td bgcolor=\"\#FF66CC\">&nbsp;&nbsp;</td>" .
      "<td bgcolor=\"\#FF6666\">&nbsp;&nbsp;</td>" .
      "<td bgcolor=\"\#FF0000\">&nbsp;&nbsp;</td>" .
      "</tr>" .
      "<tr>" .
      "<td><b>Tags per 200,000</b></td>" .
      "<td>&lt;2</td>" .
      "<td>&lt;4</td>" .
      "<td>&lt;8</td>" .
      "<td>&lt;16</td>" .
      "<td>&lt;32</td>" .
      "<td>&lt;64</td>" .
      "<td>&lt;128</td>" .
      "<td>&lt;256</td>" .
      "<td>&lt;512</td>" .
      "<td>&gt;512</td>" .
      "</tr>" .
      "</table>"; 
    push @rows,
        "<p>" .
        "<table border=1 cellspacing=1 cellpadding=4>";
    push @rows, "<tr>" .
        "<td><b>Library</b></td>" .
        "<td><b>Total Tags<br>in Library</b></td>" .
        "<td><b>Tag Counts</b></td>" .
        "<td><b>Tags per<br>200,000</b></td>" .
        "<td><b>Color<br>Code</b></td>" .
        "</tr>";
  }

  for my $f (sort r_numerically keys %by_freq) {
    for my $r (@{ $by_freq{$f} }) {
      push @rows, FormatFreqRow(@{ $r });
    }
  }

  if ($format eq "html") {
    push @rows, "</table>";
  }

  return join("\n", @rows);

}

######################################################################
sub GetTagsForSym_1 {
  my ($base, $format, $term, $details, $org, $method) = @_;

  my ($db, $sql, $stm);
  my ($cluster_number, $gene, $description);
  my ($gene_alias, $cluster);
  my (@rows, @temp, %rows, $cids, $type);
  my (%official, %preferred, %alias, $wild);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  $term =~ s/\s+/ /g;
  $term =~ s/^ //;
  $term =~ s/ $//;
  $term =~ tr/a-z/A-Z/;
  $term =~ tr/*/%/;
  $term =~ s/%{2,}/%/g;
  $wild = 1 if ($term =~ /\%/);

  my $orig_term = $term;
  $orig_term =~ s/%/*/g;
  if ($org eq 'Hs') {
    $gene_alias = 'hs_gene_alias';
    $cluster = 'hs_cluster';
  } else {
    $gene_alias = 'mm_gene_alias';
    $cluster = 'mm_cluster';
  }

  $sql = "select unique c.cluster_number, a.gene_uc, c.description, a.type " .
      "from $CGAP_SCHEMA.$gene_alias a, $CGAP_SCHEMA.$cluster c " .
      "where a.gene_uc like '$term' " .
      "and c.cluster_number = a.cluster_number " .
      "order by a.gene_uc";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while (($cluster_number,$gene,$description,$type) = $stm->fetchrow_array()) {
    $rows{$gene}{$cluster_number} = "$cluster_number\t$gene\t$description";

    if ($type eq 'OF') {
      $official{$gene}{$cluster_number} = 1;
    } elsif ($type eq 'PF') {
      $preferred{$gene}{$cluster_number} = 1;
    } elsif ($type eq 'AL') {
      $alias{$gene}{$cluster_number} = 1;
    }
  }

  while (($gene, $cids) = each(%official)) {
    while ($cluster_number = each(%$cids)) {
      push @rows, "$rows{$gene}{$cluster_number}";
      delete $preferred{$gene};
      delete $alias{$gene};
    }
  }

  if (! $wild) {
    while (($gene, $cids) = each(%preferred)) {
      while ($cluster_number = each(%$cids)) {
        push @rows, "$rows{$gene}{$cluster_number}";
        delete $alias{$gene};
      }
    }
    while (($gene, $cids) = each(%alias)) {
      while ($cluster_number = each(%$cids)) {
        push @rows, "$rows{$gene}{$cluster_number}";
      }
    }
  }
  undef %official;
  undef %preferred;
  undef %alias;

  $db->disconnect();

  if (@rows == 0) {
      return "<h3>Best Tag for Gene</h3>\n" .
          "<p><b>Search query:</b> $orig_term<br><br>\n" .
          "No genes match the query<br>";
  } elsif (@rows == 1) {
    my $tag_legend3 = ($org eq 'Hs') ? TAG_LEGEND3 : "";
    ($cluster_number, $gene) = split /\t/, $rows[0];
    return "<h3>Best Tag for Gene</h3>\n" .
        GetTagsForGene_1($base, $org, $method, $format,
                "$org.$cluster_number") . "\n" . $tag_legend3;
  } else {
    push @temp, "<h3>Gene List</h3>\n";
    push @temp, "<p><b>Search query:</b> $orig_term\n";
    push @temp, "<blockquote>Click on a gene to select it.</blockquote>";
    push @temp, "<blockquote><table border=1 cellspacing=1 cellpadding=4>";
    push @temp, "<tr><td><b>Gene</b></td><td><b>Name</b></td></tr>";
    for my $r (@rows) {
      ($cluster_number, $gene, $description) = split /\t/, $r;
      $gene or $gene = "$org.$cluster_number";
      push @temp, "<tr>" .
          "<td><a href=\"TagByCID?FORMAT=html&" .
          "DETAILS=0&TERM=$gene&" .
          "CID=$org.$cluster_number&ORG=$org&METHOD=$method\">" .
          "$gene</a></td>" .
          "<td>$description</td></tr>";
    }
    push @temp, "</table></blockquote>";
    return join("\n", @temp);
  }
}

######################################################################
sub GetTagsForKey_1 {
  my ($base, $format, $keyword, $details, $org, $method) = @_;

  my ($db, $sql, $stm);
  my ($cluster_number, $gene, $description);
  my ($gene_keyword, $cluster);
  my ($term, $orig_term);
  my (@rows, @temp);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  $term = $keyword;
  $term =~ s/\s+/ /g;
  $term =~ s/^ //;
  $term =~ s/ $//;
  $orig_term = $term;
  $term =~ tr/A-Z/a-z/;
  $term =~ tr/*/%/;
  $term =~ s/%{2,}/%/g;

  if ($org eq 'Hs') {
    $gene_keyword = 'hs_gene_keyword';
    $cluster = 'hs_cluster';
  } else {
    $gene_keyword = 'mm_gene_keyword';
    $cluster = 'mm_cluster';
  }

  $sql = "select unique c.cluster_number, c.gene, c.description " .
      "from $CGAP_SCHEMA.$gene_keyword a, $CGAP_SCHEMA.$cluster c " .
      "where a.keyword like '$term' " .
      "and c.cluster_number = a.cluster_number " .
      "order by c.gene";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while (($cluster_number,$gene,$description) = $stm->fetchrow_array()) {
    push @rows, "$cluster_number\t$gene\t$description";
  }

  $db->disconnect();

  if (@rows == 0) {
      return "<h3>Best Tag for Gene</h3>\n" .
          "<p><b>Search query:</b> $orig_term<br><br>\n" .
          "No genes match the query<br>";
  } elsif (@rows == 1) {
    my $tag_legend3 = ($org eq 'Hs') ? TAG_LEGEND3 : "";
    ($cluster_number, $gene) = split /\t/, $rows[0];
    return "<h3>Best Tag for Gene</h3>\n" .
        GetTagsForGene_1($base, $org, $method, $format,
                "$org.$cluster_number") . "\n" . $tag_legend3;
  } else {
    push @temp, "<h3>Gene List</h3>\n";
    push @temp, "<p><b>Search query:</b> $orig_term\n";
    push @temp, "<blockquote>Click on a gene to select it.</blockquote>";
    push @temp, "<blockquote><table border=1 cellspacing=1 cellpadding=4>";
    push @temp, "<tr><td><b>Gene</b></td><td><b>Name</b></td></tr>";
    for my $r (@rows) {
      ($cluster_number, $gene, $description) = split /\t/, $r;
      $gene or $gene = "$org.$cluster_number";
      push @temp, "<tr>" .
          "<td><a href=\"TagByCID?FORMAT=html&" .
          "DETAILS=0&TERM=$gene&" .
          "CID=$org.$cluster_number&ORG=$org&METHOD=$method\">" .
          "$gene</a></td>" .
          "<td>$description</td></tr>";
    }
    push @temp, "</table></blockquote>";
    return join("\n", @temp);
   }
}

######################################################################
sub GetDataSetInfo_1 {
    my ($qrank, $org, $method) = @_;

  my ($db, $sql, $stm);
  my ($rank, $id, $name, $polyA_signal, $polyA_tail, $position, $percent,
      $total_cdna);
  my (@rows);

  push @rows,
    "<p>" .
    "<table border=1 cellspacing=1 cellpadding=4 width=100%>" .
    "<tr>" .
    "<td><b>Rank</b></td>" .
    "<td><b>Database ID</b></td>" .
    "<td><b>Database Name</b></td>" .
    "<td><b>cDNAs in Database</b></td>" .
    "<td><b>Transcript Has PolyA Signal</b></td>" .
    "<td><b>Transcript Has PolyA Tail</b></td>" .
    "<td><b>Virtual Tag Position</b></td>" .
    "<td><b>Virtual Tag Classification</b></td>" .
    "<td><b>%Virtual Tags in Confident Tag List</b></td>" .
    "</tr>";

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  GetConfidenceLevels($db, \%datasets, $org, $method);

  for $rank (sort numerically keys %datasets) { 
    if ($qrank == $rank || $qrank == 0) {
      push @rows,
        "<tr>" .
        "<td>$rank</td>" .
        "<td>$datasets{$rank}{id}</td>" .
        "<td>$datasets{$rank}{name}</td>" .
        "<td>$datasets{$rank}{total_cdna}</td>" .
        "<td>$datasets{$rank}{has_signal}</td>" .
        "<td>$datasets{$rank}{has_tail}</td>" .
        "<td>$datasets{$rank}{position}</td>" .
        "<td>" . CharacterizeDataset($rank). "</td>" .
        "<td>" . sprintf("%.1f%", $datasets{$rank}{percent}) . "</td>" .
        "</tr>";
    }
  }

  $db->disconnect();
  push @rows, "</table>";

  if ($qrank > 0) {
    push @rows, "<p>";
    push @rows, "View complete <a href=\"DataSets?RANK=0&ORG=$org&METHOD=$method\">list</a> " .
        "of databases";
  }

  return join("\n", @rows);

}

######################################################################
sub DevStageLibList_1 {
  my ($base) = @_;

  $BASE = $base;

  my $org = "Mm";
  my ($db);
  my (@rows);
  my $SALL = ($org eq 'Hs') ? "SALL" : "mSALL";

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  push @rows,
    "<p>" .
    "<a name='LongTags'><a href='$SALL?ORG=$org#ShortTags'>View Short Tag Libraries</a></a>" .
    "<br>";

  push @rows,
    "<table border=0 cellspacing=1 cellpadding=4 width=100%>" .
    "<tr bgcolor=\"#38639d\">" .
    "<td><b><font color=\"#ffffff\">Stage</font></b></td>" .
    "<td><b><font color=\"#ffffff\">Library Name - Long Tags</font></b></td>" .
    "<td><b><font color=\"#ffffff\">Total Tags</font></b></td>" .
    "</tr>";

  my $method = 'LS17';
  my $protocol_list = $method;

  DevStageLibListInnards($db, $org, $method, $protocol_list, \@rows);

  push @rows,
    "</table>" .
    "<p>" .
    "<a name='ShortTags'><a href='$SALL?ORG=$org#LongTags'>View Long Tag Libraries</a></a>" .
    "<br>";

  push @rows,
    "<table border=0 cellspacing=1 cellpadding=4 width=100%>" .
    "<tr bgcolor=\"#38639d\">" .
    "<td><b><font color=\"#ffffff\">Stage</font></b></td>" .
    "<td><b><font color=\"#ffffff\">Library Name - Short Tags</font></b></td>" .
    "<td><b><font color=\"#ffffff\">Total Tags</font></b></td>" .
    "</tr>";

  my $method = 'SS10,LS10';
  my $protocol_list = $method;
  $protocol_list =~ s/,/','/g; 

  DevStageLibListInnards($db, $org, $method, $protocol_list, \@rows);

  $db->disconnect();

  push @rows, "</table>";
  push @rows,
    "<p>" .
    "<a href='$SALL?ORG=$org#ShortTags'>Back to Short Tag Libraries</a> " .
    "<a href='$SALL?ORG=$org#LongTags'>Back to Long Tag Libraries</a>" ;

  return join("\n", @rows);

}

######################################################################
sub LibList_1 {
  my ($org) = @_;

  my ($db);
  my (@rows);
  my $SALL = ($org eq 'Hs') ? "SALL" : "mSALL";

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  if ($org eq 'Hs') {    ## List Short before Long

  push @rows,
    "<p>" .
    "<a name='ShortTags'><a href='$SALL?ORG=$org#LongTags'>View Long Tag Libraries</a></a>" .
    "<br>";

  push @rows,
    "<table border=0 cellspacing=1 cellpadding=4 width=100%>" .
    "<tr bgcolor=\"#38639d\">" .
    "<td><b><font color=\"#ffffff\">Tissue</font></b></td>" .
    "<td><b><font color=\"#ffffff\">Library Name - Short Tags</font></b></td>" .
    "<td><b><font color=\"#ffffff\">Total Tags</font></b></td>" .
    "</tr>";

  my $method = 'SS10,LS10';
  my $protocol_list = $method;
  $protocol_list =~ s/,/','/g; 

  LibListInnards($db, $org, $method, $protocol_list, \@rows);

  push @rows,
    "</table>" .
    "<p>" .
    "<a name='LongTags'><a href='$SALL?ORG=$org#ShortTags'>View Short Tag Libraries</a></a>" .
    "<br>";

  push @rows,
    "<table border=0 cellspacing=1 cellpadding=4 width=100%>" .
    "<tr bgcolor=\"#38639d\">" .
    "<td><b><font color=\"#ffffff\">Tissue</font></b></td>" .
    "<td><b><font color=\"#ffffff\">Library Name - Long Tags</font></b></td>" .
    "<td><b><font color=\"#ffffff\">Total Tags</font></b></td>" .
    "</tr>";

  my $method = 'LS17';
  my $protocol_list = $method;

  LibListInnards($db, $org, $method, $protocol_list, \@rows);

  } elsif ($org eq 'Mm') {    ## List Long before Short

  push @rows,
    "<p>" .
    "<a name='LongTags'><a href='$SALL?ORG=$org#ShortTags'>View Short Tag Libraries</a></a>" .
    "<br>";

  push @rows,
    "<table border=0 cellspacing=1 cellpadding=4 width=100%>" .
    "<tr bgcolor=\"#38639d\">" .
    "<td><b><font color=\"#ffffff\">Tissue</font></b></td>" .
    "<td><b><font color=\"#ffffff\">Library Name - Long Tags</font></b></td>" .
    "<td><b><font color=\"#ffffff\">Total Tags</font></b></td>" .
    "</tr>";

  my $method = 'LS17';
  my $protocol_list = $method;

  LibListInnards($db, $org, $method, $protocol_list, \@rows);

  push @rows,
    "</table>" .
    "<p>" .
    "<a name='ShortTags'><a href='$SALL?ORG=$org#LongTags'>View Long Tag Libraries</a></a>" .
    "<br>";

  push @rows,
    "<table border=0 cellspacing=1 cellpadding=4 width=100%>" .
    "<tr bgcolor=\"#38639d\">" .
    "<td><b><font color=\"#ffffff\">Tissue</font></b></td>" .
    "<td><b><font color=\"#ffffff\">Library Name - Short Tags</font></b></td>" .
    "<td><b><font color=\"#ffffff\">Total Tags</font></b></td>" .
    "</tr>";

  my $method = 'SS10,LS10';
  my $protocol_list = $method;
  $protocol_list =~ s/,/','/g; 

  LibListInnards($db, $org, $method, $protocol_list, \@rows);

  }

  $db->disconnect();

  push @rows, "</table>";
  push @rows,
    "<p>" .
    "<a href='$SALL?ORG=$org#ShortTags'>Back to Short Tag Libraries</a> " .
    "<a href='$SALL?ORG=$org#LongTags'>Back to Long Tag Libraries</a>" ;

  return join("\n", @rows);

}

######################################################################
sub LibListInnards {
  my ($db, $org, $method, $protocol_list, $rows_ref) = @_;

  my ($sql, $stm);
  my ($old_tissue, $tissue, $name, $sage_library_id, $total_tags);

  $sql = "select unique " .
      "n.name, n.sage_library_id, l.tags, t.tissue_standard " .
      "from $CGAP_SCHEMA.sagelibinfo l, $CGAP_SCHEMA.sagelibnames n, " .
      "$CGAP_SCHEMA.sageprotocol p, " .
      "$CGAP_SCHEMA.sagetissues t " .
      "where n.sage_library_id = l.sage_library_id " .
      "and n.nametype='DUKE' " .
      "and l.tags >= " . MIN_LIB_SIZE . " " .
      "and l.quality = " . GOOD_LIB_QUALITY . " " .
      "and l.tissue = t.tissue_keyword " .
      "and l.organism = '$org' " .
      "and p.protocol in ('$protocol_list') " .
      "and p.code = l.protocol " .
      "order by t.tissue_standard, n.name";
  
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  
  while(($name, $sage_library_id, $total_tags, $tissue) =
      $stm->fetchrow_array()) {
    push @{ $rows_ref }, "<tr>";
    if ($tissue eq $old_tissue) {
      $tissue = "&nbsp;";
    } else {
      $old_tissue = $tissue;
    }
    push @{ $rows_ref }, 
      "<td><b>$tissue</b></td>" .
        "<td><a href=\"SAGELibInfo?LID=$sage_library_id&ORG=$org\">$name</a></td>" .
        "<td><a href=\"TagDistOfLib?LID=$sage_library_id&" .
        "ORG=$org&METHOD=$method\">" .
        "$total_tags</a></td>" .
        "</tr>";
  }

}

######################################################################
sub DevStageLibListInnards {
  my ($db, $org, $method, $protocol_list, $rows_ref) = @_;

  my ($sql, $stm);
  my ($name, $sage_library_id, $total_tags, $stage);
  my %dev_stage = (
    "ts1"  => "TS1",
    "ts3"  => "TS3",
    "ts4"  => "TS4",
    "ts11" => "TS11",
    "ts15" => "TS15",
    "ts17" => "TS17",
    "ts19" => "TS19",
    "ts20" => "TS20",
    "ts22" => "TS22",
    "ts23" => "TS23",
    "ts24" => "TS24",
    "ts25" => "TS25",
    "ts26" => "TS26",
    "ts27" => "TS27",
    "1 day post natal"   => "Day 1",
    "20 days post natal" => "Day 20",
    "21 days post natal" => "Day 21",
    "27 days post natal" => "Day 27",
    "adult"              => "Adult"
  );
  my @dev_stage_order = (
    "ts1",
    "ts3",
    "ts4",
    "ts11",
    "ts15",
    "ts17",
    "ts19",
    "ts20",
    "ts22",
    "ts23",
    "ts24",
    "ts25",
    "ts26",
    "ts27",
    "1 day post natal",
    "20 days post natal",
    "21 days post natal",
    "27 days post natal",
    "adult"
  );
  my  %tmp;

  $sql = "select unique " .
      "n.name, n.sage_library_id, l.tags, k.keyword " .
      "from $CGAP_SCHEMA.sagelibinfo l, $CGAP_SCHEMA.sagelibnames n, " .
      "$CGAP_SCHEMA.sageprotocol p, " .
      "$CGAP_SCHEMA.sagekeywords k " .
      "where n.sage_library_id = l.sage_library_id " .
      "and l.sage_library_id = k.sage_library_id " .
      "and n.nametype='DUKE' " .
      "and l.tags >= " . MIN_LIB_SIZE . " " .
      "and l.quality = " . GOOD_LIB_QUALITY . " " .
      "and k.keyword in ('" . join("','", keys %dev_stage) . "') " .
      "and l.organism = '$org' " .
      "and p.protocol in ('$protocol_list') " .
      "and p.code = l.protocol " .
      "order by n.name";
  
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  
  while(($name, $sage_library_id, $total_tags, $stage) =
      $stm->fetchrow_array()) {
    push @{ $tmp{$stage} },
      join("\t", $name, $sage_library_id, $total_tags);
  }
  for $stage (@dev_stage_order) {
    my $first = 1;
    my $s = $dev_stage{$stage};
    for my $i (@{ $tmp{$stage} }) {
      ($name, $sage_library_id, $total_tags) = split("\t", $i);
      push @{ $rows_ref }, "<tr>";
      push @{ $rows_ref }, 
          "<td><b>$s</b></td>" .
          "<td><a href=\"SAGELibInfo?LID=$sage_library_id&ORG=$org\">$name</a></td>" .
          "<td><a href=\"TagDistOfLib?LID=$sage_library_id&" .
          "ORG=$org&METHOD=$method\">" .
          "$total_tags</a></td>" .
          "</tr>";
      $s = "\&nbsp;";
    }
  }

}

######################################################################
sub DevStageLibPartitionQuery {
  my ($db, $org, $tissue_array,
      $stage_array, $knockout_array,
      $pooledtags, $lid2stage, $lid2tiss, $method) = @_;

  my ($sql, $stm);
  my ($sage_library_id, $tissue, $stage, $ntags);

  my ($knockouts, $tissues, $stages);
  if ($knockout_array && scalar(@{ $knockout_array })) {
    $knockouts = "'" . join("','", @{ $knockout_array }) . "'";
  }
  $tissues = "'%" . join("%' or e.group_name like '%", @{ $tissue_array }) . "%'";
  $stages  = "'" . join("','", @{ $stage_array }) . "'";

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = 
      "select unique i.sage_library_id, e.group_name, e.stage_name, i.tags " .
      "from $CGAP_SCHEMA.sagelibinfo i, " .
      "$CGAP_SCHEMA.SAGE_Experiment e " .
      "where i.quality = " . GOOD_LIB_QUALITY . " " .
      "and i.tags >= " . MIN_LIB_SIZE . " " .
      "and i.organism = '$org' " .
      "and i.method in ('$method_list') " .
      "and i.sage_library_id = e.sage_library_id " .
      "and e.exp_acronym = 'SEM' " .
      "and e.parent_group_name = 'tissue' " .
      "and (e.group_name like $tissues) " .
      "and e.stage_name in ($stages) " ;

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($sage_library_id, $tissue, $stage, $ntags) =
      $stm->fetchrow_array()) {
    if (not defined $$lid2tiss{$sage_library_id}) {
      $$lid2tiss{$sage_library_id} = $tissue;
    } else {
      $$lid2tiss{$sage_library_id} .= ';' . $tissue;
    }
    $$lid2stage{$sage_library_id} = $stage;
    $$pooledtags{"$tissue,$stage"} += $ntags;
    ## if( $tissue =~ /embryo/ ) {
    ##   print "8888 pooledtags: $tissue,$stage <br>";
    ## }
  }
}

######################################################################
sub DevStagePartitionedFreqsOfTag {
  my ($db, $tag, $lid2hist, $lid2tiss, $tagfreqs, $org, $method) = @_;

  my ($sql, $stm);
  my ($sage_library_id, $freq);
  my ($tiss, $hist);
  my ($tissue, @tissues);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select f.sage_library_id, f.frequency " .
      "from $CGAP_SCHEMA.sagefreq f, $CGAP_SCHEMA.sagelibinfo i " .
      "where f.tag = '$tag' " .
      "and f.sage_library_id = i.sage_library_id " .
      "and i.quality = " . GOOD_LIB_QUALITY . " " .
      "and i.organism = '$org' " .
      "and i.method in ( '$method_list' ) " .
      "and i.tags >= " . MIN_LIB_SIZE ;
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($sage_library_id, $freq) = $stm->fetchrow_array()) {
    if (defined $$lid2hist{$sage_library_id} &&
        defined $$lid2tiss{$sage_library_id}) {
      $tiss = $$lid2tiss{$sage_library_id};
      $hist = $$lid2hist{$sage_library_id};
      @tissues = split ';', $tiss;
      for $tissue (@tissues) {
        $$tagfreqs{"$tissue,$hist"} += $freq;
      }
    }
  }
}

######################################################################
sub StemCellLibPartitionQuery {
  my ($db, $org, $tissue_keyword_array,
      $histology_keyword_array, $knockout_keyword_array,
      $pooledtags, $lid2name, $method) = @_;

  my ($sql, $stm);
  my ($sage_library_id, $name, $ntags);

  my ($k0_keys, $k1_keys, $k2_keys);
  if ($knockout_keyword_array && scalar(@{ $knockout_keyword_array })) {
    $k0_keys = "'" . join("','", @{ $knockout_keyword_array }) . "'";
  }
  my $k1_keys = "'" . join("','", @{ $tissue_keyword_array }) . "'";
  my $k2_keys = "'" . join("','", @{ $histology_keyword_array }) . "'";

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select unique i.sage_library_id, n.name, i.tags " .
      "from $CGAP_SCHEMA.sagelibinfo i, " .
      "$CGAP_SCHEMA.sagelibnames n, " .
      "$CGAP_SCHEMA.sagekeywords k1, " .
      "$CGAP_SCHEMA.sagekeywords k2 " .
      "where i.quality = " . GOOD_LIB_QUALITY . " " .
      "and i.tags >= " . MIN_LIB_SIZE . " " .
      "and i.organism = '$org' " .
      "and i.method in ('$method_list') " .
      "and n.sage_library_id = i.sage_library_id " .
      "and k1.sage_library_id = i.sage_library_id " .
      "and k1.keyword in ($k1_keys) " .
      "and k2.sage_library_id = i.sage_library_id " .
      "and k2.keyword in ($k2_keys) " .
      ($k0_keys ?
        "and not exists (select k0.sage_library_id " .
        "from $CGAP_SCHEMA.sagekeywords k0 " .
        "where k0.sage_library_id = i.sage_library_id and " .
        "k0.keyword in ($k0_keys) ) " 
        : ""
      ) ;

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while (($sage_library_id, $name, $ntags) = $stm->fetchrow_array()) {
    $$lid2name{$sage_library_id} = $name;
    $$pooledtags{$sage_library_id} += $ntags;
  }
}

######################################################################
sub StemCellPartitionedFreqsOfTag {
  my ($db, $tag, $tagfreqs, $org, $method) = @_;

  my ($sql, $stm);
  my ($sage_library_id, $freq);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select f.sage_library_id, f.frequency " .
      "from $CGAP_SCHEMA.sagefreq f, $CGAP_SCHEMA.sagelibinfo i " .
      "where f.tag = '$tag' " .
      "and f.sage_library_id = i.sage_library_id " .
      "and i.quality = " . GOOD_LIB_QUALITY . " " .
      "and i.organism = '$org' " .
      "and i.method in ( '$method_list' ) " .
      "and i.tags >= " . MIN_LIB_SIZE ;
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($sage_library_id, $freq) = $stm->fetchrow_array()) {
    $$tagfreqs{$sage_library_id} += $freq;
  }
}

######################################################################
sub MATLIB_URL {
  my ($base, $tag, $tiss, $stage, $org, $method, $format) = @_;

  return "<a href=\"" . url_encode("$base/SAGE/FreqsOfTagMatrix?" .
        "TAG=$tag&TISS=$tiss&STAGE=$stage&" .
        "ORG=$org&METHOD=$method&FORMAT=$format\"") . ">";
}

######################################################################
sub GetFreqsOfTagMatrix_1 {
  my ($tag, $tiss, $stage, $org, $method, $format) = @_;

  my ($db, $sql, $stm);
  my ($name, $sage_library_id, $frequency, $total_tags);
  my (@libs, $lib_list, $lib_sql);
  my (@rows, %freqs, %by_freq, $density, $zeros);

  $tag =~ s/\s+//g;
  $tag =~ tr/a-z/A-Z/;

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $lib_sql =
    "select sage_library_id " .
    "from $CGAP_SCHEMA.sage_experiment " .
    "where group_name = '$tiss' " .
    "and stage_name = '$stage' " .
    "and organism = '$org' " .
    "and method in ( '$method_list' ) " ;

  $sql =
    "select f.sage_library_id, f.frequency " .
    "from $CGAP_SCHEMA.sagefreq f " .
    "where f.tag = '$tag' " .
    "and f.sage_library_id in ( $lib_sql ) " ;

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while(($sage_library_id, $frequency) = $stm->fetchrow_array()) {
    $freqs{$sage_library_id} = $frequency;
  }

  $sql =
      "select n.name, l.sage_library_id, l.tags " .
      "from $CGAP_SCHEMA.sagelibinfo l, $CGAP_SCHEMA.sagelibnames n " .
      "where l.organism = '$org' " .
      "and l.method in ('$method_list') " .
      "and l.sage_library_id = n.sage_library_id " .
      "and l.tags >= " . MIN_LIB_SIZE . " " .
      "and l.quality = " . GOOD_LIB_QUALITY . " " .
      "and n.nametype = 'DUKE' " .
      "and l.sage_library_id in ( $lib_sql ) " .
      "order by n.name";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  $zeros = 1;
  while(($name, $sage_library_id, $total_tags) =
      $stm->fetchrow_array()) {
    if( not defined $freqs{$sage_library_id} ) {
      $freqs{$sage_library_id} = 0;
    }
#   $density = sprintf("%d", 0.5 + (($freqs{$sage_library_id}*$DENOM)/$total_tags));
    $density = sprintf("%d",  (($freqs{$sage_library_id}*$DENOM)/$total_tags));
    if ($density > 0) {
      push @{ $by_freq{$density} }, [$format, $name, $sage_library_id,
                   $freqs{$sage_library_id}, $density, $total_tags, $org];
    } else {
      push @{ $by_freq{$density.$zeros} }, [$format, $name, $sage_library_id,
          $freqs{$sage_library_id}, $density, $total_tags, $org];
      $zeros++;
    }
  }

  $db->disconnect();

  if (scalar(keys %by_freq) == 0) {
    return "<b>Tag count = 0</b><br>\n";
  }

  if ($format eq "html") {
    push @rows,
        "<p>" .
        "<table border=1 cellspacing=1 cellpadding=4>";
    push @rows, "<tr>" .
        "<td><b>Library</b></td>" .
        "<td><b>Total Tags<br>in Library</b></td>" .
        "<td><b>Tag Counts</b></td>" .
        "<td><b>Tags per<br>200,000</b></td>" .
        "<td><b>Color<br>Code</b></td>" .
        "</tr>";
  }

  for my $f (sort r_numerically keys %by_freq) {
    for my $r (@{ $by_freq{$f} }) {
      push @rows, FormatFreqRow(@{ $r });
    }
  }

  if ($format eq "html") {
    push @rows, "</table>";
  }

  return join("\n", @rows);

}

######################################################################
sub BreastCellLibraries {
  my ($db, $org, $method, $lib_ids) = @_;

  my ($sql, $stm);
  my ($group_name, $stage_name, $sage_library_id);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select group_name, stage_name, sage_library_id " .
         "from $CGAP_SCHEMA.SAGE_Experiment " .
         "where exp_acronym = 'SAV' " .
         "and parent_group_name = 'breast_cell' " .
         "and organism = '$org' " .
         "and method in ( '$method_list' ) " ;

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($group_name, $stage_name, $sage_library_id) =
      $stm->fetchrow_array()) {
    next if (! $sage_library_id);
    ## print "8888: $group_name, $stage_name, $sage_library_id<br>";
    if (not defined $$lib_ids{"$group_name,$stage_name"}) {
      $$lib_ids{"$group_name,$stage_name"} = "$sage_library_id";
    } else {
      $$lib_ids{"$group_name,$stage_name"} .= ",$sage_library_id";
    }
  }
}

######################################################################
sub BreastCellLibPartitionQuery {
  my ($db, $org, $lib_ids, $pooledtags, $method) = @_;

  my ($sql, $stm);
  my ($lib, $libs, $sage_library_id, $ntags);

  for $lib (values %{$lib_ids}) {
    $libs .= $lib . ',' if ($lib ne 'NA');
  }
  $libs =~ s/,$//;

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select unique i.sage_library_id, i.tags " .
      "from $CGAP_SCHEMA.sagelibinfo i " .
      "where i.quality = " . GOOD_LIB_QUALITY . " " .
      "and i.tags >= " . MIN_LIB_SIZE . " " .
      "and i.organism = '$org' " .
      "and i.method in ('$method_list') " .
#     "and i.tissue = 'mammary gland' " .
      "and i.sage_library_id in ($libs)" ;

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($sage_library_id, $ntags) =
      $stm->fetchrow_array()) {
    $$pooledtags{$sage_library_id} += $ntags;
  }
}

######################################################################
sub BreastCellPartitionedFreqsOfTag {
  my ($db, $tag, $tagfreqs, $org, $method) = @_;

  my ($sql, $stm);
  my ($sage_library_id, $freq);
  my ($tiss, $hist);
  my ($tissue, @tissues);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select f.sage_library_id, f.frequency " .
      "from $CGAP_SCHEMA.sagefreq f, $CGAP_SCHEMA.sagelibinfo i " .
      "where f.tag = '$tag' " .
      "and f.sage_library_id = i.sage_library_id " .
      "and i.quality = " . GOOD_LIB_QUALITY . " " .
      "and i.organism = '$org' " .
      "and i.method in ( '$method_list' ) " .
      "and i.tags >= " . MIN_LIB_SIZE ;

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($sage_library_id, $freq) = $stm->fetchrow_array()) {
    $$tagfreqs{$sage_library_id} += $freq;
  }
}

######################################################################
sub LibNameAndTotal {
  my ($db, $sage_library_id) = @_;

  my ($sql, $stm);
  my ($dummy, $freq);
  my ($total_tags, $name);

  $sql = "select n.name, i.tags " .
      "from $CGAP_SCHEMA.sagelibnames n, $CGAP_SCHEMA.sagelibinfo i " .
      "where i.sage_library_id = $sage_library_id " .
      "and n.sage_library_id = $sage_library_id " .
      "and i.tags >= " . MIN_LIB_SIZE . " " .
      "and n.nametype = 'DUKE'";
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while(($dummy, $freq) = $stm->fetchrow_array()) {
    $total_tags = $freq;
    $name = $dummy;
  }

  return ($name, $total_tags);
}

######################################################################
sub LibHeader {
  my ($sage_library_id, $name, $total_tags, $org) = @_;

  return join("\n",
      "<table border=0 cellspacing=1 cellpadding=4>",
      "<tr><td><b>Library Name:</b></td><td><a href=\"SAGELibInfo?",
      "LID=$sage_library_id&ORG=$org\">$name</a></td></tr>",
      "<tr><td><b>Total Tags:</b></td><td>$total_tags</td></tr></table>"
    );
}

######################################################################
sub ALLHeader {
  my ($sage_library_id, $name, $total_tags, $min, $max, $org) = @_;

  my ($interval, $bottom, $top);

  if ($max == $total_tags) {
    $interval = "&gt; 512 tags per 200,000";
  } else {
    $bottom = int($min * $DENOM/$total_tags + 0.5);
    $top    = int($max * $DENOM/$total_tags + 0.5);
    $interval = "&gt;= $bottom and &lt; $top per 200,000";
  }

  return join("\n",
      "<table border=0 cellspacing=1 cellpadding=4>",
      "<tr><td><b>Library Name:</b></td><td><a href=\"SAGELibInfo?",
      "LID=$sage_library_id&ORG=$org\">$name</a></td></tr>",
      "<tr><td><b>Total Tags:</b></td><td>$total_tags</td></tr>",
      "<tr><td><b>List tags expressed at:</b></td>",
      "<td>$interval</td></tr>",
      "</table>"
    );

}

######################################################################
sub GetTagDistOfLib_1 {
  my ($sage_library_id, $org, $method) = @_;

  my ($db, $sql, $stm);
  my ($tag, $freq, %tag_counts);
  my (@lib_specific_scale, @rows);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  my ($name, $total_tags) = LibNameAndTotal($db, $sage_library_id);

  for (@color_breaks) {
    push @lib_specific_scale, sprintf("%.2f", $_*$total_tags/$DENOM);
##    print "normal $_ = lib specific " . sprintf("%.2f", $_*$total_tags/$DENOM) . "<br>\n";
  }

  $sql = "select tag, frequency from $CGAP_SCHEMA.sagefreq " .
      "where sage_library_id = $sage_library_id";
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while(($tag, $freq) = $stm->fetchrow_array()) {
    for (@lib_specific_scale) {
      if ($freq < $_) {
        $tag_counts{$_}++;
        last;
      }
    }
  }

  $db->disconnect();

  push @rows, LibHeader($sage_library_id, $name, $total_tags, $org);

  push @rows, "<br><br>";
  push @rows,
      "<p>" .
      "<table border=1 cellspacing=1 cellpadding=4 align=center>";

  push @rows, "<tr>";
  push @rows, "<td><b>Color</b></td>";
  for (my $i; $i < @color_breaks; $i++) {
    push @rows, "<td bgcolor=\"#$color_scale[$i]\">\&nbsp;</td>";
  }
  push @rows, "</tr>";

  push @rows, "<tr>";
  push @rows, "<td><b>Tags Per 200,000</b></td>";
  for (my $i; $i < @color_breaks; $i++) {
    push @rows, "<td>" . ($i < @color_breaks-1 ? "<$color_breaks[$i]" :
        ">$color_breaks[$i-1]") . "</td>";
  }
  push @rows, "</tr>";

  my ($min, $max);
  my ($total_distinct, $this_interval_distinct);
  push @rows, "<tr>";
  push @rows, "<td><b>Distribution of Unique Tags</b></td>";
  for (my $i = 0; $i < @color_breaks; $i++) {
    $max = $lib_specific_scale[$i];
    $this_interval_distinct = $tag_counts{$max};
    $total_distinct += $this_interval_distinct;
    if ($this_interval_distinct) {
      if ($i > 0) {
        $min = $lib_specific_scale[$i-1];
      } else {
        $min = 0;
      }
      push @rows, "<td align=center>";
      if ($this_interval_distinct) {
        push @rows, "<a href=\"AbsLL?" .
          "FORMAT=" . ($this_interval_distinct > 1000 ?
              "text" : "html") . "\&" .
          "LID=$sage_library_id&" .
          "MIN=$min&MAX=$max&" .
          "ORG=$org&METHOD=$method\">$this_interval_distinct</a>";
      } else {
        push @rows, "0";
      }
      push @rows, "</td>";
    } else {
      push @rows, "<td align=center>0</td>";
    }
  }
  push @rows, "</tr>";

  push @rows, "<tr><td><b>Total # Unique Tags</b></td>";
  push @rows, "<td colspan=10 align=center><a href=\"AbsLL?FORMAT=text" .
      "&LID=$sage_library_id&MIN=0&MAX=0&" .
      "ORG=$org&METHOD=$method\"><b>$total_distinct</b></a></td>";
  push @rows, "</tr>";

  push @rows, "</table>";

##  push @rows, "<br><br>";
##  push @rows, "<center>";
##  push @rows, "Download <a href=\"AbsLL?FORMAT=text" .
##      "&LID=$sage_library_id&MIN=0&MAX=0&" .
        "ORG=$org&METHOD=$method\">complete list</a> of " .
##      "distinct tags";
##  push @rows, "</center>";

  return join("\n", @rows);
}


######################################################################
sub GetAccMapsOfTags {
  my ($db, $tags, $tag2acc, $org, $method) = @_;

  my ($tag, $accession);
  my ($sql, $stm);
  my ($i, $list);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  for($i = 0; $i < @{ $tags }; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @{ $tags }) {
      $list = join("','", @{ $tags }[$i..$i+ORACLE_LIST_LIMIT-1]);
    }
    else {
      $list = join("','", @{ $tags }[$i..@{ $tags }-1]);
    }

    $sql = "select a.tag, a.accession " .
        "from $CGAP_SCHEMA.sagebest_tag2acc a, " .
        "$CGAP_SCHEMA.sageprotocol b " .
        "where a.tag in ('" . $list . "') " .
        "and b.ORGANISM = '$org' " .
        "and b.PROTOCOL in ( '$method_list' ) " .
        "and a.PROTOCOL  = b.CODE "; 

    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    while (($tag, $accession) = $stm->fetchrow_array()) {
      $$tag2acc{$tag} = $accession;
    }
  }
}

######################################################################
sub GetBestMapsOfTags {
  my ($db, $tags, $tag2cid, $tag2acc, $cid2sym, $org, $method) = @_;

  my ($sql, $stm);
  my ($i, $list, $tag, $cluster_number, %tags_seen, @missing_cids, %cids_hit,
      %cid2loc);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  for($i = 0; $i < @{ $tags }; $i += ORACLE_LIST_LIMIT) {
    if(($i + ORACLE_LIST_LIMIT - 1) < @{ $tags }) {
      $list = join("','", @{ $tags }[$i..$i+ORACLE_LIST_LIMIT-1]);
    }
    else {
      $list = join("','", @{ $tags }[$i..@{ $tags }-1]);
    }

    $sql = "select a.tag, a.cluster_number " .
        "from $CGAP_SCHEMA.sagebest_tag2clu a, " .
        "$CGAP_SCHEMA.sageprotocol b " .
        "where tag in ('$list') " .
        "and b.ORGANISM = '$org' " .
        "and b.PROTOCOL in ( '$method_list' ) " .
        "and a.PROTOCOL  = b.CODE "; 

    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }

    while(($tag, $cluster_number) = $stm->fetchrow_array()) {
      $tags_seen{$tag} = 1;
      $$tag2cid{$tag} = $cluster_number;
      $cids_hit{$cluster_number} = 1;
    }
  }

  GetSymsOfCIDs($db, \%cids_hit, $cid2sym, \%cid2loc, $org);

  for $tag (@{ $tags }) {
    if (not defined $tags_seen{$tag}) {
      push @missing_cids, $tag;
    }
  }

  if (@missing_cids > 0) {
    GetAccMapsOfTags($db, \@missing_cids, $tag2acc, $org, $method);
  }

}

######################################################################
sub LibPartitionQuery {
  my ($db, $org, $scope, $the_tiss, $the_hist, $tissue_keyword_array,
      $histology_keyword_array, $knockout_keyword_array,
      $pooledtags, $lid2hist, $lid2tiss, $method) = @_;

  my ($sql, $stm);
  my ($sage_library_id, $tissue, $histology, $ntags);

  my ($k0_keys, $k1_keys, $k2_keys);
  if ($knockout_keyword_array && scalar(@{ $knockout_keyword_array })) {
    $k0_keys = "'" . join("','", @{ $knockout_keyword_array }) . "'";
  }
  my $k1_keys = "'" . join("','", @{ $tissue_keyword_array }) . "'";
  my $k2_keys = "'" . join("','", @{ $histology_keyword_array }) . "'";

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select unique i.sage_library_id, k1.keyword, k2.keyword, i.tags " .
      "from $CGAP_SCHEMA.sagelibinfo i, " .
      "$CGAP_SCHEMA.sagekeywords k1, " .
      "$CGAP_SCHEMA.sagekeywords k2 " .
      "where i.quality = " . GOOD_LIB_QUALITY . " " .
      "and i.tags >= " . MIN_LIB_SIZE . " " .
      "and i.organism = '$org' " .
      "and i.method in ('$method_list') " .
      ($the_tiss ? "and i.the_tiss = '$the_tiss' " : "") .
      ($the_hist ? "and i.the_hist = '$the_hist' " : "") .
      "and k1.sage_library_id = i.sage_library_id " .
      "and k1.keyword in ($k1_keys) " .
      "and k2.sage_library_id = i.sage_library_id " .
      "and k2.keyword in ($k2_keys) " .
      ($k0_keys ?
        "and not exists (select k0.sage_library_id " .
        "from $CGAP_SCHEMA.sagekeywords k0 " .
        "where k0.sage_library_id = i.sage_library_id and " .
        "k0.keyword in ($k0_keys) ) " 
        : ""
      ) .
      ($scope == 0 ?
        "and not exists (select k3.sage_library_id from $CGAP_SCHEMA.sagekeywords k3 " .
        "where k3.sage_library_id = i.sage_library_id and k3.keyword = 'cell line') "
        : ""
      ) .
      ($scope == 1 ?
        "and     exists (select k3.sage_library_id from $CGAP_SCHEMA.sagekeywords k3 " .
        "where k3.sage_library_id = i.sage_library_id and k3.keyword = 'cell line') "
        : "");

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($sage_library_id, $tissue, $histology, $ntags) =
      $stm->fetchrow_array()) {
    $$lid2hist{$sage_library_id} = $histology;
    $$lid2tiss{$sage_library_id} = $tissue;
    $$pooledtags{"$tissue,$histology"} += $ntags;
  }
}

######################################################################
sub PartitionedFreqsOfTag {
  my ($db, $tag, $lid2hist, $lid2tiss, $tagfreqs, $org, $method) = @_;

  my ($sql, $stm);
  my ($sage_library_id, $freq);
  my ($tiss, $hist);

  my $method_list = $method;
  $method_list =~ s/,/','/g;

  $sql = "select f.sage_library_id, f.frequency " .
      "from $CGAP_SCHEMA.sagefreq f, $CGAP_SCHEMA.sagelibinfo i " .
      "where f.tag = '$tag' " .
      "and f.sage_library_id = i.sage_library_id " .
      "and i.quality = " . GOOD_LIB_QUALITY . " " .
      "and i.organism = '$org' " .
      "and i.method in ( '$method_list' ) " .
      "and i.tags >= " . MIN_LIB_SIZE ;
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($sage_library_id, $freq) = $stm->fetchrow_array()) {
    if (defined $$lid2hist{$sage_library_id} &&
        defined $$lid2tiss{$sage_library_id}) {
      $tiss = $$lid2tiss{$sage_library_id};
      $hist = $$lid2hist{$sage_library_id};
      $$tagfreqs{"$tiss,$hist"} += $freq;
    }
  }
}

######################################################################
sub GetAnatomicInterval {
  my ($hits, $pool_total) = @_;

  my ($x);
  my $scaled_value = $hits * $DENOM / $pool_total;

  for (@color_breaks) {
    if ($_ > $scaled_value) {
      return $_;
    }
  }
  return $color_breaks[$#color_breaks];
}

######################################################################
sub url_encode {
  my ($x) = @_;
  $x =~ s/\+/%2B/g;
  $x =~ s/ /+/g;
  return $x 
}

######################################################################
sub AnatomicHTML {
  my ($tag, $scope, $pooledtags, $tagfreqs, $org, $method) = @_;

  my ($tiss, $tiss_en, $hist, $n_interval, $n_image, $c_interval,
      $c_image, $title, $width, $height, $text_cell, $protocol);
  my ($db, $sql, $stm);
  my (@rows, %anatomic_viewer_order);

  my $no_data = "<b><font color=\"#cccccc\">No Data</font></b>";
  my $not_applicable = "<b><font color=\"#cccccc\">Not Applicable</font></b>";

  push @rows, qq(
<TABLE align=center BORDER=0 CELLPADDING=0 CELLSPACING=0 WIDTH=488>
<tr><td align="left"><img src="images/normal.gif" width=173 height=24 border=0 alt="Normal"></td><td align="right"><img src="images/cancer.gif" width=173 height=24 border=0 alt="Cancer"></td></tr></table>
<TABLE align=center BORDER=2 bordercolor="#999999" CELLPADDING=0 CELLSPACING=0 WIDTH=488>
  <TR>
    <TD valign="top" align="center" BORDER=3 bordercolor="#999999" width=88>
    <img src="images/body-n.gif" alt=\"normal body\" width=52 height=166 border=0 alt=""></TD>
    <TD width="100" valign="top">
    <table width="300" cellspacing="0" cellpadding="4" border="3" bordercolor="#999999" >
  );

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  if ($org eq 'Hs') {
    if ($method eq 'LS17') {
      $protocol = 'C';
    } else {
      $protocol = 'A';
    }
  } elsif ($org eq 'Mm') {
    if ($method eq 'LS17') {
      $protocol = 'K';
    } else {
      $protocol = 'M';
    }
  }

#  $sql = "select unique tissue from $CGAP_SCHEMA.sagelibinfo " .
#      "where protocol = '$protocol' " .
#      "and tags > 0 " ;

  ## try using keyword instead of tissue; tissue = 'stem cell'
  ## while Anatomic viewer wants 'embryonic stem cell'

  $sql = "select unique keyword from $CGAP_SCHEMA.sagelibinfo i, " .
      "$CGAP_SCHEMA.sagekeywords k " .
      "where protocol = '$protocol' " .
      "and i.sage_library_id = k.sage_library_id " .
      "and tags > 0 " ;

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while (($tiss) = $stm->fetchrow_array()) {
    $anatomic_viewer_order{$tiss} = 1;
  }

  for $tiss (@anatomic_viewer_order) {
    next if (! $anatomic_viewer_order{$tiss});
    $tiss_en = url_encode($tiss);
    ($title, $width, $height) = split(",",
        $anatomic_viewer_params{$tiss});
    next if (!$title);
    $hist = "normal";
    if (defined $$pooledtags{"$tiss,$hist"}) {
      $n_interval = GetAnatomicInterval($$tagfreqs{"$tiss,$hist"},
          $$pooledtags{"$tiss,$hist"});
      if ($n_interval > 512) {
        $n_interval = "512plus";
      }
      $n_image = LIBLIST_URL($BASE, $tag, $tiss, $hist, $scope, "fetus", $org, $method) .
          "<img src=\"images/$anatomic_viewer_tissues{$tiss}$n_interval.gif\"" .
          " width=$width height=$height border=0 alt=\"$title\"></a>";
#      $n_image = "<a href=FreqsOfTag?" .
#          "FORMAT=html&TAG=$tag&CELL=$scope&TISS=$tiss_en&HIST=$hist" .
#          "&NOT=fetus>" .
#          "<img src=\"images/$anatomic_viewer_tissues{$tiss}$n_interval.gif\"" .
#          " width=$width height=$height border=0 alt=\"$title\"></a>";
    } else {
      $n_interval = 0;
      $n_image = $no_data;
    }
    $hist = "neoplasia";
    if (defined $$pooledtags{"$tiss,$hist"}) {
      $c_interval = GetAnatomicInterval($$tagfreqs{"$tiss,$hist"},
          $$pooledtags{"$tiss,$hist"});
      if ($c_interval > 512) {
        $c_interval = "512plus";
      }
      $c_image = LIBLIST_URL($BASE, $tag, $tiss, $hist, $scope, "fetus", $org, $method) .
          "<img src=\"images/$anatomic_viewer_tissues{$tiss}$c_interval.gif\"" .
          " width=$width height=$height border=0 alt=\"$title\"></a>";
#      $c_image = "<a href=FreqsOfTag?" .
#          "FORMAT=html&TAG=$tag&CELL=$scope&TISS=$tiss_en&HIST=$hist" .
#          "&NOT=fetus>" .
#          "<img src=\"images/$anatomic_viewer_tissues{$tiss}$c_interval.gif\"" .
#          " width=$width height=$height border=0 alt=\"$title\"></a>";
    } else {
      $c_interval = 0;
      $c_image = (($tiss eq 'heart') || ($tiss eq 'placenta')) ? $not_applicable
                                                               : $no_data;
    }
    next if (($n_interval == 0) && ($c_interval == 0));

    if ($tiss eq "brain") {
      $text_cell = "<a href=BrainViewer?TAG=$tag&CELL=$scope&ORG=$org&METHOD=$method>$title</a>";
    } elsif ($tiss eq "mammary gland") {
      $text_cell = "$title";
      if ($scope != 1) {
        $text_cell .= "<br><a href=BreastCellViewer?TAG=$tag&ORG=$org&METHOD=$method>Breast cell subtypes</a>";
      }
    } elsif ($tiss eq "embryonic stem cell") {
      $text_cell = "<a href=StemCellViewer?TAG=$tag&ORG=$org&METHOD=$method>$title</a>";
    } else {
      $text_cell = $title;
    }

    push @rows, qq(
<tr>
    <td width="100" align="center">$n_image</td>
    <td width="100" align="center">$text_cell</td>
    <td width="100" align="center">$c_image</td>
</tr>
     );
  }

  push @rows, qq(
</table>
</TD>
    <TD valign="top" align="center" BORDER=4 bordercolor="#999999" >
    <img src="images/body-c.gif" alt=\"cancer body\" width=50 height=165 border=0 alt=""><P>
	<img src="images/scale.gif" alt=\"Tags per 200,000 Scale\" width=80 height=282 border=0 alt=""></TD>
  </TR>
</TABLE>
);

  return join("\n", @rows);
}

######################################################################
sub AnatomicFreqs_1 {
  my ($base, $tag, $scope, $org, $method) = @_;

  my $TAG = $tag;
  ## scope == 0 => no   cell line data
  ## scope == 1 => only cell line data
  ## scope == 2 => all            data

  my ($db, $sql, $stm);
  my ($tiss, $hist);

  my (%pooledtags, %lid2hist, %lid2tiss, %tagfreqs);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  LibPartitionQuery($db, $org, $scope, "", "neoplasia",
      \@anatomic_query_tissues,
      ["neoplasia"], ["fetus"], \%pooledtags, \%lid2hist, \%lid2tiss, $method);
  LibPartitionQuery($db, $org, $scope, "", "normal",
      \@anatomic_query_tissues,
      ["normal"],    ["fetus"], \%pooledtags, \%lid2hist, \%lid2tiss, $method);

  ## Bad fix for problem with keywords:
  ## when SageEdit updates the keyword table it doesn't include
  ## ancestor keywords.
#  for my $lib (keys %lid2tiss) {
#    my $temp_tiss = $lid2tiss{$lib};
#    my $temp_hist = $lid2hist{$lib};
#    my $agg_tiss  = $temp_tiss;
#    my $agg_hist  = $temp_hist;
#    if (defined $anatomic_aggregate{$temp_tiss}) {
#      my $agg_tiss = $anatomic_aggregate{$temp_tiss};
#    }
#    if (defined $anatomic_aggregate{$temp_hist}) {
#      my $agg_hist = $anatomic_aggregate{$temp_hist};
#    }
#    if ($agg_tiss ne $temp_tiss || $agg_hist ne $temp_hist) {
#      $lid2tiss{$lib} =  $agg_tiss;
#      $lid2hist{$lib} =  $agg_hist;
#      $pooledtags{"$agg_tiss,$agg_hist"} +=
#        $pooledtags{"$temp_tiss,$temp_hist"};
#      delete $pooledtags{"$temp_tiss,$temp_hist"};
#    }
#  }

  PartitionedFreqsOfTag($db, $tag, \%lid2hist, \%lid2tiss, \%tagfreqs,
                                                           $org, $method);

  $db->disconnect();

  ## return AnatomicHTML($tag, $scope, \%pooledtags, \%tagfreqs, $org, $method);
  my $table =
    "<center>" .
    "<table width=\"15%\" style=\"border: 1 solid #999999\" BORDERCOLOR=\"#999999\" border=1>" .
    "<tr><td align=center>";
  if( $scope == 0 ) {
    $table = $table . "<a href=\"Viewer?TAG=$TAG&CELL=1&ORG=$org&METHOD=$method\"><img src=\"images/cellicon.gif\" alt=\"Cell Lines only\" border=0><\/a>" .
    "</td><td align=center>" .
    "<a href=\"Viewer?TAG=$TAG&CELL=2&ORG=$org&METHOD=$method\"><img src=\"images/bodycell.gif\" alt=\"Tissues + Cell Lines\" border=0><\/a>";
  }
  elsif ( $scope == 1 ) {
    $table = $table . "<a href=\"Viewer?TAG=$TAG&CELL=0&ORG=$org&METHOD=$method\"><img src=\"images/bodyicon.gif\" alt=\"Tissues only\" border=0><\/a>" .
    "</td><td align=center>" .
    "<a href=\"Viewer?TAG=$TAG&CELL=2&ORG=$org&METHOD=$method\"><img src=\"images/bodycell.gif\" alt=\"Tissues + Cell Lines\" border=0><\/a>";
  }
  elsif ( $scope == 2 ) {
    $table = $table . "<a href=\"Viewer?TAG=$TAG&CELL=0&ORG=$org&METHOD=$method\"><img src=\"images/bodyicon.gif\" alt=\"Tissues only\" border=0><\/a>" .
    "</td><td align=center>" .
      "<a href=\"Viewer?TAG=$TAG&CELL=1&ORG=$org&METHOD=$method\"><img src=\"images/cellicon.gif\" alt=\"Cell Lines only\" border=0><\/a>";
  }
 
  $table = $table . "</td></tr></table></center>";
 
  my $header = "<p><b>Search query:</b>$TAG,";
   if( $scope == 0 ) {
    $header = $header . "  Tissues only";
  }
  elsif( $scope == 1 ) {    
    $header = $header . "  Cell lines only";
  }
  elsif( $scope == 2 ) {    
    $header = $header . "  Tissues and cell lines";
  }
  $header = $header .
    "<p>" .    
    "<UL>" .    
    "<LI>Each colored organ image is hyperlinked to a Digital Northern displaying " .    
    "the tag expression in each individual library." .    
    "<LI>The \"Brain\" label is hyperlinked to an expanded anatomic view of the brain. " .    
    "<LI>The \"Embryonic Cell\" label is hyperlinked to a page showing tag expression " .
    "in each individual embryonic cell library." .
    "</UL>" .
    "" .
    "<br>" .
    "" .
    "<p>";
 
  my $before = $header .        
    "<center>Return to <a href=\"AnatomicViewer\">SAV</A> home page</A></center><br>" . $table;  
  my $after = "<br>" . $table . "<br><center>Return to <a href=\"AnatomicViewer\">SAV</A> home page</A></center>";
  return $before . AnatomicHTML($tag, $scope, \%pooledtags, \%tagfreqs, $org, $method) . $after;


}

######################################################################
sub StemCellViewer_1 {
  my ($base, $tag, $org, $method) = @_;

  my $count = 0;

  my (%pooledtags, %lid2name, %tagfreqs);
  my ($lid, $name, $nickname, $numerator, $denominator, $interval);
  my (@rows);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  StemCellLibPartitionQuery($db, $org,
      ["embryonic stem cell"],
      ["normal"], ["fetus"],
      \%pooledtags, \%lid2name, $method);
  StemCellPartitionedFreqsOfTag($db, $tag, \%tagfreqs, $org, $method);

  $db->disconnect();

  push @rows, "<TABLE cellpadding=16>";
  push @rows, "<TR>";

  while (($lid, $name) = each (%lid2name)) {
    if (defined $pooledtags{$lid}) {
      $denominator = $pooledtags{$lid};
      if (defined $tagfreqs{$lid}) {
        $numerator = $tagfreqs{$lid};
      } else {
        $numerator = 0;
      }
      $interval = GetAnatomicInterval($numerator, $denominator);
      if ($interval > 512) {
        $interval = "512plus";
      }
    } else {
      $interval = 0;
    }
    if ($interval > 0) {
      $nickname = $name;
      $nickname =~ s/^L?SAGE_Embryonic_stem_cells?_//i;
      $nickname =~ s/_CL_/<BR>_CL_/;
      push @rows, "<TD align=center valign=middle><img src='SAGE/images/hES$interval.gif' alt=\"hES$interval\"><BR><A href=\"SAGELibInfo?LID=$lid&ORG=$org\">$nickname</A></TD>" ;
      if ($count++ == 2) {
        push @rows, "</TR><TR>";
        $count = 0;
      }
    } else {
      push @rows, "<TD> &nbsp; </TD>" ;
    }
  }

  push @rows, "</TR>";
  push @rows, "</TABLE>";

  return join("\n", @rows);
}

######################################################################
sub BreastCellViewer_1 {
  my ($base, $tag, $org, $method) = @_;

  my ($db, $sql, $stm);
  my (@rows);
  my (%pooledtags, %tagfreqs);
  my ($stage, $tissue, $lib, $libs, @libs, $tiss, $tisstage);
  my ($numerator, $denominator, $interval);

  my $no_data = "<b><font color=\"#cccccc\">No Data</font></b>";

  $tag =~ s/\s+//g;
  $tag =~ tr/a-z/A-Z/;

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  BreastCellLibraries($db, $org, $method, \%breast_cell_libraries);
  BreastCellLibPartitionQuery($db, $org, 
      \%breast_cell_libraries,
      \%pooledtags, $method);
  BreastCellPartitionedFreqsOfTag($db, $tag, \%tagfreqs, $org, $method);

  $db->disconnect();

  if (scalar(keys %tagfreqs) == 0) {
    return "<b>Tag count = 0</b><br>\n";
  }

  push @rows,
    "<TABLE border=1 cellpadding=3>" .
    "<TR>" .
    "<TD width=175><B>Cell Type</B></TD>" .
    "<TD width=160 align=center><B>NB</B></TD>" .
    "<TD width=160 align=center><B>DCIS</B></TD>" .
    "<TD width=160 align=center><B>IDC</B></TD>" .
    "<TD width=160 align=center><B>METASTASES</B></TD>" .
    "</TR>" ;

  for $tissue (@breast_cell_order) {
    $tiss = $breast_cell_tissues{$tissue};
    push @rows,
      "<TR>" .
      "<TD>$tissue</font></TD>" ;
    for $stage (@breast_cell_stages) {
      $libs = $breast_cell_libraries{"$tiss,$stage"};
      @libs = split ",", $libs;
      $numerator = 0; $denominator = 0;
      for $lib (@libs) {
        if (defined $pooledtags{$lib}) {
          $denominator = $pooledtags{$lib};
          if (defined $tagfreqs{$lib}) {
            $numerator = $tagfreqs{$lib};
          } else {
            $numerator = 0;
          }
        }
      }
      if ($numerator || $denominator) {
        $interval = GetAnatomicInterval($numerator, $denominator);
        if ($interval > 512) {
          $interval = "512plus";
        }
      } else {
        $interval = 0;
      }
      if ($interval > 0) {
        my $A = MATLIB_URL($base, $tag, "$tiss", $stage, 
                                  $org, $method, 'html');
        if( $interval =~ /plus/ ) {
          push @rows, "<TD align=center valign=middle>$A<img src='SAGE/images/dot$interval.gif' alt=\"dot$interval\" border=0></A></TD>" ;
        }
        else {
          push @rows, "<TD align=center valign=middle>$A<img src='SAGE/images/dot$interval.gif' alt=\"dot$interval" . "minus\" border=0></A></TD>" ;
        }
      } else {
#       push @rows, "<TD> &nbsp; </TD>" ;
        push @rows, "<TD align=center>$no_data</TD>" ;
      }
    }

    push @rows, "</TR>" ;
  }

  push @rows, "</TABLE>";

  return join("\n", @rows);

}

######################################################################
sub AbsoluteLevelLister_1 {
  my ($format, $sage_library_id, $min, $max, $org, $method) = @_;

  my ($db, $sql, $stm);

  my ($tag, $frequency, $cluster_number, $gene, $accession);
  my ($name, $total_tags);
  my (%tags_seen, %cids_hit, %cid2loc);
  my (@missing_cids, %missing_cids);
  my (%freq2tag_set, %tag2cid_set, %cid2sym);
  my (@rows);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    ## print "Cannot connect to database \n";
    print "Cannot connect to database \n";
    exit();
  }

  if ($format eq "html") {
    push @rows, "<center>";
    ($name, $total_tags) = LibNameAndTotal($db, $sage_library_id);
    push @rows, ALLHeader($sage_library_id, $name, $total_tags,
        $min, $max, $org);
    push @rows, "<p>";
    push @rows,
        "<table border=1 cellspacing=1 cellpadding=4>" .
        "<tr>" .
        "<td><b>Tag</b></td>" .
        "<td><b>Frequency</b></td>" .
        "<td><b>Gene or Accession</b></td>" .
        "</tr>";
  } else {
    push @rows, "Tag\tFrequency\tUniGene Cluster\tGene Symbol (or Accession)";
  }


  GetRepetitives($db, \%repetitives, $org, $method);

  my $method_list = $method;
  $method_list =~ s/,/','/g;
  my $code;
  my @codes;
  my $code_list;

  $sql = "select code " .
      "from $CGAP_SCHEMA.sageprotocol " .
      "where ORGANISM = '$org' " .
      "and PROTOCOL in ( '$method_list' ) "; 
 
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
 
  while($code = $stm->fetchrow_array()) {
    push @codes, $code;
  }

  $code_list = "'" . join("','", @codes) . "'"; 

  $sql = "select f.tag, f.frequency, b.cluster_number " .
      "from $CGAP_SCHEMA.sagefreq f, $CGAP_SCHEMA.sagebest_tag2clu b " .
      "where f.sage_library_id = $sage_library_id " .
      "and f.PROTOCOL in( $code_list )" .
      "and b.PROTOCOL in( $code_list )" .
      "and f.tag = b.tag (+) " .
      ($max ? "and f.frequency >= $min and f.frequency < $max" : "");

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  while(($tag, $frequency, $cluster_number) =
      $stm->fetchrow_array()) {
    if (not defined $tags_seen{$tag}) {
      $tags_seen{$tag} = 1;
      push @{ $freq2tag_set{$frequency} }, $tag;
    }
    if ($cluster_number) {
      push @{ $tag2cid_set{$tag} }, $cluster_number;
      $cids_hit{$cluster_number} = 1;
    } else {
      push @missing_cids, $tag;
    }
  }

  GetSymsOfCIDs($db, \%cids_hit, \%cid2sym, \%cid2loc, $org);

  ##
  ## Now get accessions for tags that don't map to clusters
  ##
  GetAccMapsOfTags($db, \@missing_cids, \%missing_cids, $org, $method);

  $db->disconnect();

  my ($tag1);

  for $frequency (sort r_numerically keys %freq2tag_set) {
    for $tag (sort @{ $freq2tag_set{$frequency} }) {
      $tag1 = $tag;
      if (defined $repetitives{$tag}) {
        $tag1 = "$tag#";
      }
      if (defined $tag2cid_set{$tag}) {
        for $cluster_number (@{ $tag2cid_set{$tag} }) {
          $gene = "";
          if (defined $cid2sym{$cluster_number}) {
            $gene = $cid2sym{$cluster_number};
          } elsif ($format eq "html") {
            $gene = "$org.$cluster_number";
          }
          if ($format eq "html") {
            push @rows, "<tr>" .
                "<td><a href=\"GeneByTag?ORG=$org&METHOD=$method&" . 
                    "FORMAT=html&" .
                    "TAG=$tag&DETAILS=0\">$tag1</a></td>" .
                "<td>$frequency</td>" .
                ## "<td><a href=\"http://cgap.nci.nih.gov/Genes/GeneInfo?" .
                "<td><a href=\"/Genes/GeneInfo?" .
                    "ORG=$org&CID=$cluster_number\">$gene</a></td>" .
                "</tr>";
          } else {
            push @rows, "$tag\t$frequency\t$org.$cluster_number\t$gene";
          }
        }
      } else {
        $accession = $missing_cids{$tag};
        if ($format eq "html") {
          $accession or $accession = "\&nbsp;";
          push @rows, "<tr>" .
              "<td><a href=\"GeneByTag?ORG=$org&METHOD=$method&" .
                  "FORMAT=html&" .
                  "TAG=$tag&DETAILS=0\">$tag1</a></td>" .
              "<td>$frequency</td>" .
              "<td>$accession</td>" .
              "</tr>";
        } else {
          push @rows, "$tag\t$frequency\t\t$accession\t";
        }
      }

    }
  }

  if ($format eq "html") {
    push @rows, "</table>";
    push @rows, "</center>";
  } else {
    push @rows, "";
  }

  return join("\n", @rows);
}

######################################################################
sub Thousands {
  my ($x) = @_;

  my ($rem, $str);
  while ($x > 0) {
    $rem = sprintf("%3.3d", $x % 1000);
    $str = $str ? "$rem,$str" : "$rem";
    $x = int($x / 1000);
  }
  $str =~ s/^0+//;
  return $str;
}

######################################################################
sub MEMatrix_1 {
  my ($org, $method, $format, $tag, $state) = @_;

  my ($db, $sql, $stm);
  my (@rows);
  my (%pooledtags, %lid2stage, %lid2tiss, %tagfreqs);
  my ($brain, $embryo, $embryonic_tissue, $heart, $kidney, $large_intestine);
  my ($liver, $lung, $lymph_nodes, $mammary, $muscle, $neural_tube, 
      $pancreas, $prostate, $small_intestine);
  my ($stage, $tissue, $tiss, $tisstage, $show_tissue);
  my ($numerator, $denominator, $interval, $skip_rows);

  $tag =~ s/\s+//g;
  $tag =~ tr/a-z/A-Z/;

  if ($state) {
    ($brain,$embryo,$embryonic_tissue,$heart,$kidney,$large_intestine,
     $liver,$lung,$lymph_nodes,$mammary,$muscle,$neural_tube,$pancreas,
     $prostate, $small_intestine) = 
       split ",", $state;
  }

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  DevStageLibPartitionQuery($db, $org, 
      \@mouse_matrix_tissues,
      \@theiler, [""],
      \%pooledtags, \%lid2stage, \%lid2tiss, $method);
  DevStagePartitionedFreqsOfTag($db, $tag, \%lid2stage, \%lid2tiss, \%tagfreqs,
                                     $org, $method);

  $db->disconnect();

  if (scalar(keys %tagfreqs) == 0) {
    return "<b>Tag count = 0</b><br>\n";
  }

  if ($format eq "html") {
    if ($state eq "1,1,1,1,1,1,1,1,1,1,1,1,1,1,1") {
      push @rows,
      "<P>" .
      "<a href=\"MEMatrix?ORG=$org&METHOD=$method&FORMAT=$format&TAG=$tag&" .
      "STATE=" .  "\">Collapse</a> all tissues" .
      "<P>" ;
    } else {
      push @rows,
      "<P>" .
      "<a href=\"MEMatrix?ORG=$org&METHOD=$method&FORMAT=$format&TAG=$tag&" .
      "STATE=1,1,1,1,1,1,1,1,1,1,1,1,1,1,1" .  "\">Expand</a> all tissues" .
      "<P>" ;
    }
    push @rows,
      "<TABLE border=1 cellpadding=1 width=800>" .
      "<TR bgcolor=ffffcc>" .
      "<TD bgcolor=ffffcc rowspan=4 align=center><img src=\"images/mouse_yb.gif\" alt=\"mouse\"></TD>" .
#     "<TD bgcolor=ffffff rowspan=4> &nbsp;</TD>" .
      "<TD colspan=$mouse_matrix_columns><font size=1><B>DEVELOPMENT: dpc</B> </font> </TD>" .
      "</TR>" .

      "<TR bgcolor=ffffcc>" ;

    for $stage (@dpc) {
      push @rows, "<TD width=3%><font size=1>$stage</font></TD>";
    }

    push @rows,
      "</TR>" .

      "<TR bgcolor=ffffcc>" .
      "<TD colspan=$mouse_matrix_columns><B><font size=1>DEVELOPMENT: Theiler Stage & days post natal</font></B></TD>" .
      "</TR>" .

      "<TR bgcolor=ffffcc>" ;
 
    for $stage (@theiler) {
      push @rows, "<TD><font size=1>$stage</font></TD>";
    }

    push @rows,
#     "</TR>" .

#     "<TR>" .
#     "<TD bgcolor=ffffcc><B><font size=1>TISSUE</font></B></TD>" .
#     "<TD valign=top colspan=$mouse_matrix_columns> &nbsp;</TD>" .
      "</TR>" ;

    for $tissue (@mouse_matrix_tissues) {
      if ($skip_rows) {
        $skip_rows--;
        next;
      }
      my $obrain = $brain;
      my $oembryo = $embryo;
      my $oembryonic = $embryonic_tissue;
      my $oheart = $heart;
      my $okidney = $kidney;
      my $olarge = $large_intestine;
      my $oliver = $liver;
      my $olung = $lung;
      my $olymph_nodes = $lymph_nodes;
      my $omammary = $mammary;
      my $omuscle = $muscle;
      my $oneural_tube = $neural_tube;
      my $opancreas = $pancreas;
      my $oprostate = $prostate;
      my $osmall = $small_intestine;
      $show_tissue = $mouse_matrix_tissues{$tissue};
      if ($show_tissue =~ /^  /) {
        $show_tissue =~ s/^  /&nbsp;&nbsp;/g;
        $show_tissue =~ s/  /<BR>&nbsp;&nbsp;/g;
      }
      $tiss = $tissue;
      if ($mouse_matrix_subunits{$tiss}) {
        my $open = 0;
        if ($tiss =~ /brain/) {
          $obrain = not $brain;
          $open = $brain;
        } elsif ($tiss =~ /embryo/) {
          $oembryo = not $embryo;
          $open = $embryo;
        } elsif ($tiss =~ /embryonic_tissue/) {
          $oembryonic = not $embryonic_tissue;
          $open = $embryonic_tissue;
        } elsif ($tiss =~ /heart/) {
          $oheart = not $heart;
          $open = $heart;
        } elsif ($tiss =~ /kidney/) {
          $okidney = not $kidney;
          $open = $kidney;
        } elsif ($tiss =~ /large intestine/) {
          $olarge = not $large_intestine;
          $open = $large_intestine;
        } elsif ($tiss =~ /liver/) {
          $oliver = not $liver;
          $open = $liver;
        } elsif ($tiss =~ /lung/) {
          $olung = not $lung;
          $open = $lung;
        } elsif ($tiss =~ /lymph nodes/) {
          $olymph_nodes = not $lymph_nodes;
          $open = $lymph_nodes;
        } elsif ($tiss =~ /mammary/) {
          $omammary = not $mammary;
          $open = $mammary;
        } elsif ($tiss =~ /muscle/) {
          $omuscle = not $muscle;
          $open = $muscle;
        } elsif ($tiss =~ /neural tube/) {
          $oneural_tube = not $neural_tube;
          $open = $neural_tube;
        } elsif ($tiss =~ /pancreas/) {
          $opancreas = not $pancreas;
          $open = $pancreas;
        } elsif ($tiss =~ /prostate/) {
          $oprostate = not $prostate;
          $open = $prostate;
        } elsif ($tiss =~ /small intestine/) {
          $osmall = not $small_intestine;
          $open = $small_intestine;
        }
        $skip_rows = $mouse_matrix_subunits{$tiss} if (not $open);
        ## print "8888: tiss: $tiss, open: $open, skip_rows: $skip_rows <br>";
        push @rows,
          "<TR bgcolor=ffffff>" .
          "<TD bgcolor=ffffcc valign=top><font size=1>" .
          "<a href=\"MEMatrix?ORG=$org&METHOD=$method&FORMAT=$format&TAG=$tag&".
          "STATE=$obrain,$oembryo,$oembryonic,$oheart,$okidney,$olarge,$oliver,$olung,$olymph_nodes,$omammary,$omuscle,$oneural_tube,$opancreas,$oprostate,$osmall" .
          "\">$show_tissue</a></font></TD>" ;
      } else {
        push @rows,
          "<TR bgcolor=ffffff>" .
          "<TD bgcolor=ffffcc valign=top><font size=1>$show_tissue</font></TD>" ;
      }
      for $stage (@theiler) {
        $tisstage = "$tiss,$stage";
        if (defined $pooledtags{$tisstage}) {
          $denominator = $pooledtags{$tisstage};
          if (defined $tagfreqs{$tisstage}) {
            $numerator = $tagfreqs{$tisstage};
          } else {
            $numerator = 0;
          }
          $interval = GetAnatomicInterval($numerator, $denominator);
          if ($interval > 512) {
            $interval = "512plus";
          }
        } else {
          $interval = 0;
        }
        if ($interval > 0) {
          my $A = MATLIB_URL($BASE, $tag, "$tiss", $stage, 
                             $org, $method, $format);
          push @rows, "<TD align=center valign=middle>$A<img src='SAGE/images/dot$interval.gif' alt=\"dot$interval" . "minus\" border=0></A></TD>" ;
        } else {
          push @rows, "<TD> &nbsp; </TD>" ;
        }
      }

      push @rows, "</TR>" ;
    }

    push @rows,
      "<TR bgcolor=ffffcc>" .
      "<TD bgcolor=ffffcc rowspan=4> &nbsp;</TD>" .
      "<TD colspan=$mouse_matrix_columns><font size=1><B>DEVELOPMENT: Theiler Stage & days post natal</B> </font> </TD>" .
      "</TR>" .

      "<TR bgcolor=ffffcc>" ;

    for $stage (@theiler) {
      push @rows, "<TD><font size=1>$stage</font></TD>";
    }

    push @rows,
      "</TR>" .

      "<TR bgcolor=ffffcc>" .
      "<TD colspan=$mouse_matrix_columns><B><font size=1>DEVELOPMENT: dpc</font></B></TD>" .
      "</TR>" .

      "<TR bgcolor=ffffcc>" ;
 
    for $stage (@dpc) {
      push @rows, "<TD><font size=1>$stage</font></TD>";
    }

    push @rows,
      "</TR>" ;

  }

  if ($format eq "html") {
    push @rows, "</TABLE>";
  }

#push @rows, "<TABLE><TR><TD><B>LID 2 TISS</B></TD></TR>";
#my ($key, $val);
#while (($key, $val) = each(%lid2tiss)) {
#  push @rows, "<TR><TD>$key => $val</TD></TR>";
#}
#push @rows, "</TABLE>";

  return join("\n", @rows);

}

######################################################################
sub SAGELibPage_1 {
  my ($base, $lid, $org) = @_;

  my $BASE = $base;

  my ($DUKE_name, $NCBI_name, $keywords);
  my $organism = ($org eq 'Hs') ? "Homo sapiens" : "Mus musculus";
  my ($tags_plus, $tags, $utags);
  my ($tissue, $histology, $preparation, $mutations,
      $patient_age, $patient_sex, $other_info);
  my ($tag_enzyme, $anchor_enzyme, $supplier, $producer,
      $laboratory, $references);

  my ($db, $sql, $stm);
  my ($name, $nametype);
  my ($reference, $pubmed_id);
  my (@ref_array);

  my %nice_enzyme_html = (
    "BsmF I"  => "<i>Bsm</i><font face=\"Times New Roman\">FI</font>",
    "Nla III" => "<i>Nla</i><font face=\"Times New Roman\">III</font>",
    "Mme I"   => "<i>Mme</i><font face=\"Times New Roman\">I</font>"
  );

  my (@rows);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  $sql = "select name, nametype " .
      "from $CGAP_SCHEMA.sagelibnames " .
      "where sage_library_id = $lid";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while(($name, $nametype) = $stm->fetchrow_array()) {
    if ($nametype eq "NCBI") {
      $NCBI_name = $name;
    } elsif ($nametype eq "DUKE") {
      $DUKE_name = $name;
    }
  }

  $sql = "select " .
      "keywords, " .
      "tags_plus, tags, utags, " .
      "tissue, histology, preparation, mutations, " .
      "patient_age, patient_sex, other_info, " .
      "tag_enzyme, anchor_enzyme, supplier, producer, " .
      "laboratory " .
      "from $CGAP_SCHEMA.sagelibinfo " .
      "where sage_library_id = $lid";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }

  ($keywords,
      $tags_plus, $tags, $utags,
      $tissue, $histology, $preparation, $mutations,
      $patient_age, $patient_sex, $other_info,
      $tag_enzyme, $anchor_enzyme, $supplier, $producer,
      $laboratory)
       = $stm->fetchrow_array();
  $stm->finish();

  $tags_plus = Thousands($tags_plus);
  $tags      = Thousands($tags);
  $utags     = Thousands($utags);
  if (defined $nice_enzyme_html{$tag_enzyme}) {
    $tag_enzyme    = $nice_enzyme_html{$tag_enzyme};
  }
  if (defined $nice_enzyme_html{$anchor_enzyme}) {
    $anchor_enzyme = $nice_enzyme_html{$anchor_enzyme};
  }
  if ($tissue eq "mammary gland" && $org eq "Hs") {
    $tissue = "breast";
  }

  $sql = "select a.reference, a.pubmed_id " .
      "from $CGAP_SCHEMA.sagerefs a, $CGAP_SCHEMA.sagelibreference b " .
      "where b.sage_library_id = $lid and a.reference_id = b.reference_id ";

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while(($reference, $pubmed_id) = $stm->fetchrow_array()) {
    if ($pubmed_id) {
      push @ref_array,
        "<a href=" .
        "\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?" .
        "cmd=Retrieve&db=PubMed&list_uids=$pubmed_id&dopt=Abstract\"" .
        ">$reference</a>";
    } else {
      push @ref_array, $reference
    }
  }

  $references = join("<br>", @ref_array);

  $db->disconnect();

  push @rows, DividerBar("Library ID");
  push @rows,
      "<BR>" .
      "<table width=95% cellpadding=1>";
  push @rows,
      "<tr><td valign=top width=35%><b>New SAGE Library Name:</b></td>" .
      "<td>$DUKE_name</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Old SAGE Library Name:</b></td>" .
      "<td>$NCBI_name</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Organism:</b></td><td>$organism</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Library Keywords:</b></td>" .
      "<td>$keywords</td></tr>";
  push @rows,
      "</table><br>";

  push @rows, DividerBar("Tag Info");
  push @rows,
      "<BR>" .
      "<table width=95% cellpadding=1>";
  push @rows,
      "<tr><td valign=top width=35%><b>#Total tags:</b></td>" .
      "<td>$tags_plus</td></tr>";
  push @rows,
      "<tr><td valign=top><b>#Tags excluding linkers:</b></td>" .
      "<td><a href=\"$BASE/sagecgi/SimpleTagList.pl?" .
      "BASE=$BASE" . "\&LID=$lid\">$tags</a></td></tr>";
  push @rows,
      "<tr><td valign=top><b>#Unique tags:</b></td>" .
      "<td>$utags</td></tr>";
  push @rows,
      "</table><br>";

  push @rows, DividerBar("Tissue Info");
  push @rows,
      "<BR>" .
      "<table width=95% cellpadding=1>";
  push @rows,
      "<tr><td valign=top width=35%><b>Tissue:</b></td>" .
      "<td>$tissue</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Cell/Histology type:</b></td>" .
      "<td>$histology</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Tissue preparation:</b></td>" .
      "<td>$preparation</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Mutations:</b></td>" .
      "<td>$mutations</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Patient age:</b></td>" .
      "<td>$patient_age</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Sex:</b></td>" .
      "<td>$patient_sex</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Other info:</b></td>" .
      "<td>$other_info</td></tr>";
  push @rows,
      "</table><br>";

  push @rows, DividerBar("Library Preparation Info");
  push @rows,
      "<BR>" .
      "<table width=95% cellpadding=1>";
  push @rows,
      "<tr><td valign=top width=35%><b>Tagging enzyme:</b></td>" .
      "<td>$tag_enzyme</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Anchoring enzyme:</b></td>" .
      "<td>$anchor_enzyme</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Tissue or cell line supplier:</b></td>" .
      "<td>$supplier</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Library preparer:</b></td>" .
      "<td>$producer</td></tr>";
  push @rows,
      "<tr><td valign=top><b>Prepared in lab of:</b></td>" .
      "<td>$laboratory</td></tr>";
  push @rows,
      "<tr><td valign=top><b>References:</b></td>" .
      "<td>$references</td></tr>";
  push @rows,
      "</table><br>";


  return join("\n", @rows);
}

######################################################################
sub SimpleTagList_1 {
  my ($base, $lid) = @_;

  $BASE = $base;
  my ($tag, $freq, @rows);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  my $sql = qq!
select
  f.tag,
  f.frequency
from
  $CGAP_SCHEMA.sagefreq f
where
  f.sage_library_id = $lid
order by
  f.tag
  !;

  my $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  push @rows, "Tag\tFrequency";  
  while(($tag, $freq) = $stm->fetchrow_array()) {
    push @rows, "$tag\t$freq";
  }
  $db->disconnect();
  return join("\n", @rows) . "\n";
}

######################################################################
sub SDGEDLibrarySelect_1 {
  my (
      $min_seqs,
      $sort,
      $title_a,
      $tissue_a,
      $hist_a,
      $comp_a,
      $no_cell_a,
      $lib_a,
      $stage_a,
      $comp_stage_a,
      $user_file_a,
      $user_data_a,
      $title_b,
      $tissue_b,
      $hist_b,
      $comp_b,
      $no_cell_b,
      $lib_b,
      $stage_b,
      $comp_stage_b,
      $user_file_b,
      $user_data_b,
      $org,
      $method
  ) = @_;

  my ($db, $sql, $stm);
  my (@set_a, @info_a);
  my (@set_b, @info_b);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  if ($lib_a =~ '_') {    ## mSEV
    my @libs = split '_', $lib_a;
    for my $lib (@libs) {
      SAGESelectLibrarySet($db, \@set_a, \@info_a, $sort, $title_a, $tissue_a, 
        $hist_a, $comp_a, $no_cell_a, $lib, $stage_a, $comp_stage_a,
        GOOD_SIZE, GOOD_QUAL, $org, $method);
    }
  } elsif ($user_file_b) {    ## SDGED
    if (! $user_file_a) {
      SAGESelectLibrarySet($db, \@set_a, \@info_a, $sort, $title_a, $tissue_a, 
        $hist_a, $comp_a, $no_cell_a, $lib_a, $stage_a, $comp_stage_a,
        GOOD_SIZE, GOOD_QUAL, $org, $method);
    }
  } else {
    SAGESelectLibrarySet($db, \@set_a, \@info_a, $sort, $title_a, $tissue_a, 
      $hist_a, $comp_a, $no_cell_a, $lib_a, $stage_a, $comp_stage_a,
      GOOD_SIZE, GOOD_QUAL, $org, $method);
    SAGESelectLibrarySet($db, \@set_b, \@info_b, $sort, $title_b, $tissue_b, 
      $hist_b, $comp_b, $no_cell_b, $lib_b, $stage_b, $comp_stage_b,
      GOOD_SIZE, GOOD_QUAL, $org, $method);
  }

  $db->disconnect();

  ##
  ## must return UniGene library ids
  ## also need a global (across a, b) ordering
  ## also need to check for duplicate entries, so put in a hash
  ##
  ## UNLESS coming from mSEV and have multiple libraries
  ## that Susan wants ordered specially.
  ##

  my (%set_a, %set_b, %both_info);
  my (@rows, $info);
  my ($lid, $title, $keys, $seqs, $the_tiss, $the_hist);
  my ($idx, $i, $j, $A, $B);
  my (@data, $data, $tag, $freq);
  my ($sdged_cache, $tags_a, $tags_b, $freqs_a, $freqs_b);

  if ($lib_a =~ '_') {    ## mSEV - no checks
    for $info (@info_a) {
      $A = ""; $B = "";
      ($lid, $title, $keys, $seqs, $the_tiss, $the_hist) =
          split("\t", $info);
      push @rows, join("\002", $lid,$A,$B,$title,$seqs,$keys);
    }
    ## return join("\001", @rows);
    return join("\001", @rows) . "\003";
  }

  for ($i = 0; $i < @set_a; $i++) {
    ($lid, $title, $keys, $seqs, $the_tiss, $the_hist) =
        split("\t", $info_a[$i]);
    if ((not $min_seqs) or ($min_seqs <= $seqs)) {
      $set_a{$set_a[$i]} = 1;
      if ($sort eq "title") {
        $idx = $title;
      } elsif ($sort eq "tissue") {
        $idx = $the_tiss;
      } elsif ($sort eq "histology") {
        $idx = $the_hist;
      } elsif ($sort eq "stage") {
        if ($keys =~ /, (ts\d+)/) {
          $idx = $1;
        } elsif ($keys =~ /, (adult)/) {
          $idx = $1;
        } elsif ($keys =~ /, ([\d\.]+ days? post natal)/) {
          $idx = $1;
        } elsif ($keys =~ /, (unknown development stage)/) {
          $idx = $1;
        }
      }
      $both_info{$idx}{$lid} = $info_a[$i];
    }
  }

  if (!$user_file_b) {    ## SDGED
    for ($i = 0; $i < @set_b; $i++) {
      ($lid, $title, $keys, $seqs, $the_tiss, $the_hist) =
          split("\t", $info_b[$i]);
      if ((not $min_seqs) or ($min_seqs <= $seqs)) {
        $set_b{$set_b[$i]} = 1;
        if ($sort eq "title") {
          $idx = $title;
        } elsif ($sort eq "tissue") {
          $idx = $the_tiss;
        } elsif ($sort eq "histology") {
          $idx = $the_hist;
        } elsif ($sort eq "stage") {
          if ($keys =~ /, (ts\d+)/) {
            $idx = $1;
          } elsif ($keys =~ /, (adult)/) {
            $idx = $1;
          } elsif ($keys =~ /, ([\d\.]+ days? post natal)/) {
            $idx = $1;
          } elsif ($keys =~ /, (unknown development stage)/) {
            $idx = $1;
          }
        }
        $both_info{$idx}{$lid} = $info_b[$i];
      }
    }
  }

  if ($user_file_b) {    ## SDGED
    my $user_data;
    $user_data_b =~ s/^'//;
    $user_data_b =~ s/'$//;
    $user_data = $user_data_b;
    if ($user_data_a) {
      $user_data_a =~ s/^'//;
      $user_data_a =~ s/'$//;
      $user_data .= "\n#################\n" . $user_data_a;
    }
    $sdged_cache = WriteSDGEDToCache($user_data);
  }

  if ((keys %both_info == 0) && (! $sdged_cache)) {
    ## return "\003";
    return "";
  }

  for $j (sort keys %both_info) {
    while (($i, $info) = each %{ $both_info{$j} }) {
      $A = defined $set_a{$i} ? "A" : "";
      $B = defined $set_b{$i} ? "B" : "";
      ($lid, $title, $keys, $seqs, $the_tiss, $the_hist) =
          split("\t", $info);
      push @rows, join("\002", $lid,$A,$B,$title,$seqs,$keys);
    }
  }

  if ($sdged_cache) {    ## SDGED
    $lid  = "";
    $keys = "";

    if ($user_file_a) {
      $A = "A";
      $B = "";
      @data = split "\n", $user_data_a;
      for $data (@data) {
        ($tag, $freq) = split "\t", $data;
        $tags_a++;
        $freqs_a += $freq;
      }
      push @rows, join("\002", $lid,$A,$B,$user_file_a,$freqs_a,$keys);
    }
    if ($user_file_b) {
      $A = "";
      $B = "B";
      @data = split "\n", $user_data_b;
      for $data (@data) {
        ($tag, $freq) = split "\t", $data;
        $tags_b++;
        $freqs_b += $freq;
      }
      push @rows, join("\002", $lid,$A,$B,$user_file_b,$freqs_b,$keys);
    }

    ## foreach(keys(%ENV)) {
    ##   $host_name = $host_name . $_ . $ENV{$_};
    ## }
    my $host_name = $ENV{HOSTNAME};

    $sdged_cache = $sdged_cache . "HOSTNAME" . $host_name;
    return join("\001", @rows) . "\003$sdged_cache";
  } else {
    return join("\001", @rows) . "\003";
  }
}

######################################################################
sub WriteSDGEDToCache {
  my ($data) = @_;

  my $cache_sdged = new Cache(CACHE_ROOT, SDGED_CACHE_PREFIX);
  my ($sdged_cache_id, $filename) = $cache_sdged->MakeCacheFile();
  if ($sdged_cache_id != $CACHE_FAIL) {
    if (open(SOUT, ">$filename")) {
      print SOUT $data;
      close SOUT;
      chmod 0666, $filename;
    } else {
      $sdged_cache_id = 0;
    }
  }
  return $sdged_cache_id;
}

######################################################################
sub SAGESelectLibrarySet {
  ## This does a "liberal" selection. That is, if tissue=liver
  ## is specified, it will select any library that has a keyword
  ## k such that IsKindOf($k, 'liver'), even if the library is also
  ## keyworded for tissues that are not 'liver').

  my ($db, $items_ref, $info_ref, $sort, $title,
      $tissue, $hist, $complement_tissue, $no_cell, $lib, $stage, $comp_stage,
      $good_size, $good_qual, $org, $method) = @_;

  my ($choices);
  my ($sql, $stm);

  my @tmp = split ",", $method;
  my $methods = "'" . join ("', '", @tmp) . "'";

  $sql =
      "select distinct s.sage_library_id, s.name, i.keywords, " .
##      "i.tags, i.tissue, i.histology " .
      "i.tags, i.the_tiss, i.the_hist " .
      "from $CGAP_SCHEMA.sagelibnames s, " .
      "$CGAP_SCHEMA.sagelibinfo i " .
      "where s.sage_library_id = i.sage_library_id " .
      ($good_size ? "and i.tags >= " . MIN_LIB_SIZE . " " : "") .
      ($good_qual ? "and i.quality = " . GOOD_LIB_QUALITY . " " : "") .
      "and s.nametype='DUKE' and i.ORGANISM = '$org' " .
      "and i.METHOD in ( $methods ) " .
      ($lib ? "and s.sage_library_id = $lib " : "") ;

  if ($title) {
    my $lc_title = $title;
    $lc_title =~ tr/A-Z/a-z/;
    $lc_title =~ s/\*/%/g;
    $sql .= " and lower(s.name) like '%$lc_title%'";
  }

  if ($tissue) {
    $choices = "('" . join("', '", split(",", $tissue)). "')";
    $sql .= " and " . ($complement_tissue ? "not " : "") .
            "exists (select k1.sage_library_id " .
        "from $CGAP_SCHEMA.sagekeywords k1 " .
        "where k1.sage_library_id = s.sage_library_id and " .
        "k1.keyword in $choices)"
  }

  if ($no_cell) {
    $sql .= " and not exists (select k2.sage_library_id " .
        "from $CGAP_SCHEMA.sagekeywords k2 " .
        "where k2.sage_library_id = s.sage_library_id and " .
        "k2.keyword = 'cell line')"
  }

  if ($hist) {
    $choices = "('" . join("', '", split(",", $hist)). "')";
    $sql .= " and exists (select k4.sage_library_id " .
        "from $CGAP_SCHEMA.sagekeywords k4 " .
        "where k4.sage_library_id = s.sage_library_id and " .
        "k4.keyword in $choices)"
  }

  if ($stage) {
    $stage =~ s/d1/1 day post natal/g;
    $stage =~ s/d20/20 days post natal/g;
    $stage =~ s/d27/27 days post natal/g;
    $choices = "('" . join("', '", split(",", $stage)). "')";
    $sql .= " and " . ($comp_stage ? "not " : "") .
        "exists (select k5.sage_library_id " .
        "from $CGAP_SCHEMA.sagekeywords k5 " .
        "where k5.sage_library_id = s.sage_library_id and " .
        "k5.keyword in $choices)"
  }

##  if ($sort eq "title") {
##    $sql .= " order by a.lib_name"; 
##  } elsif ($sort eq "tissue") {
##    $sql .= " order by a.the_tiss"; 
##  } elsif ($sort eq "histology") {
##    $sql .= " order by a.the_hist"; 
##  }

  my ($lid, $name, $keys, $seqs, $the_tiss, $the_hist);

  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while (($lid, $name, $keys, $seqs, $the_tiss, $the_hist) =
      $stm->fetchrow_array()) {
    push @{ $items_ref }, $lid;
    push @{ $info_ref }, join("\t", $lid, $name, $keys, $seqs,
        $the_tiss, $the_hist);
  }      

}

######################################################################
## SAGE Library Finder
##

######################################################################
sub GetSageLibrary_1 {
  my ($base, $page, $title, $type, $tissue, $hist, 
                            $keys, $sort, $org, $method, $stage) = @_;

  $BASE = $base;

  my (@items, @info);

  my $params = join "; ",
              ($type, $tissue, $hist, $title, $keys, $org, $method, $stage); 

  while ($params =~ /; ;/) {
    $params =~ s/; ;/;/g;
  }
  $params =~ s/^ ?; ?//;
  $params =~ s/; $//;
  $params =~ s/SS10/Short SAGE/;
  $params =~ s/LS10/Extracted Short SAGE/;
  $params =~ s/LS17/Long SAGE/;

  my $page_header = "<table>\n" .
      "<tr align=top><td><b>Library Finder Query:</b></td><td>$params</td></tr>\n" .
      "<tr align=top><td><b>Order By:</b></td><td>$sort</td></td>\n" .
      "</table>\n";


  LibraryFinderLibrarySet(\@items, \@info, $org, $title, $type,
      $tissue, $hist, $keys, $sort, $method, $stage);

  if (scalar(@items) == 0) {
    return $page_header . "<br><br>" .
        "There are no libraries matching the query<br><br>";
  } else {

    my ($idx, $i, $j, $info, %lib_info, @rows);
    my ($lid, $name, $the_keys, $the_tiss, $the_hist, $the_prep);

    for ($i = 0; $i < @items; $i++) {
      ($lid, $name, $the_keys, $the_tiss, $the_hist, $the_prep) =
        split("\t", $info[$i]);

      if ($sort eq "title") {
        $idx = $name;
      } elsif ($sort eq "tissue") {
        $idx = $the_tiss;
      } elsif ($sort eq "preparation") {
        $idx = $the_prep;
      } elsif ($sort eq "histology") {
        $idx = $the_hist;
      } elsif ($sort eq "stage") {
        if ($the_keys =~ /, (ts\d+)/) {
          $idx = $1;
        } elsif ($the_keys =~ /, (adult)/) {
          $idx = $1;
        } elsif ($the_keys =~ /, ([\d\.]+ days? post natal)/) {
          $idx = $1;
        } elsif ($the_keys =~ /, (unknown development stage)/) {
          $idx = $1;
        }
      }
      $lib_info{$idx}{$lid} = $info[$i];
    }

    for $j (sort keys %lib_info) {
      while (($i, $info) = each %{ $lib_info{$j} }) {
        push @rows, $info;
      }
    }

  ##
  ## Set up for paging results
  ##
    my $cmd = "SAGELibraryQuery?" .
        "TITLE=$title&" .
        "TYPE=$type&" .
        "TISSUE=$tissue&" .
        "HIST=$hist&" .
        "KEYS=$keys&" .
        "STAGE=$stage&" .
        "SORT=$sort&" .
        "ORG=$org&" .
        "METHOD=$method";

    return FormatLibs($page, $org, $cmd, $page_header, \@rows);
  }
}

######################################################################
sub LibraryFinderLibrarySet {
  ## This does a "liberal" selection. That is, if tissue=liver
  ## is specified, it will select any library that has a keyword
  ## k such that IsKindOf($k, 'liver'), even if the library is also
  ## keyworded for tissues that are not 'liver').

  my ($items_ref, $info_ref, $org, $title, $type,
      $tissue, $hist, $keys, $sort, $method, $stage) = @_;

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }

  my $protocol_list = $method;
  $protocol_list =~ s/,/','/g; 

  my $sql =
      "select distinct n.sage_library_id, n.name, l.keywords, " .
      "l.the_tiss, l.the_hist, l.preparation " .
      "from $CGAP_SCHEMA.sagelibinfo l, $CGAP_SCHEMA.sagelibnames n ";
  if ($keys) {
     $sql = $sql .
        "     , $CGAP_SCHEMA.SAGEKEYWORDS k ";
  }
  $sql = $sql .
      "where l.sage_library_id = n.sage_library_id " .
      "and n.nametype = 'DUKE' and l.organism = '$org'" .
      (($protocol_list) ? "and l.METHOD in ('$protocol_list') " : "") ;

  if ($title) {
    my $lc_title = $title;
    $lc_title =~ tr/A-Z/a-z/;
    $lc_title =~ s/\*/%/g;
    $sql .= " and lower(n.name) like '%$lc_title%'";
  }

  if ($tissue) {
    $sql .= " and exists (select k1.sage_library_id " .
        "from $CGAP_SCHEMA.sagekeywords k1 " .
        "where k1.sage_library_id = l.sage_library_id and " .
        "k1.keyword ='$tissue')"
  }

#  if ($tissue) {
#    $sql .= " and l.the_tiss like '$tissue'";
#  }

  if ($type) {
    $sql .= " and l.preparation like '$type'";
    if ($type =~ /short term/) {
      $sql =~ s/ and l.preparation / and \(l.preparation /;
      my $type2 = "short term cell line";
      $sql .= " or l.preparation like '$type2'\)";
    }
  }

  if ($hist) {
    $sql .= " and l.the_hist like '$hist'";
  }

  if ($keys) {
    my $lc_keys = $keys;
    $lc_keys =~ tr/A-Z/a-z/;
    $lc_keys =~ s/\*/%/g;
    ## $sql .= " and lower(l.keywords) like '%$lc_keys%'";
    $sql .= " and lower(k.keyword) = '$lc_keys' " .
            " and  l.sage_library_id = k.sage_library_id ";
  }

  if ($stage) {
    $stage =~ s/d1/1 day post natal/g;
    $stage =~ s/d20/20 days post natal/g;
    $stage =~ s/d27/27 days post natal/g;
    $sql .= " and lower(l.keywords) like '%$stage%'";
  }

# if ($sort eq "title") {
#   $sql .= " order by n.name"; 
# } elsif ($sort eq "tissue") {
#   $sql .= " order by l.the_tiss"; 
# } elsif ($sort eq "histology") {
#   $sql .= " order by l.the_hist"; 
# } elsif ($sort eq "preparation") {
#   $sql .= " order by l.preparation"; 
# }

  my ($lid, $name, $keys, $the_tiss, $the_hist, $the_prep);

#return "$sql";
  my $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while (
      ($lid, $name, $keys, $the_tiss,
          $the_hist, $the_prep) = $stm->fetchrow_array()) {
    push @{ $items_ref }, $lid;
#   $keys =~ s/SAGE[^,]*,?//g;
    $keys =~ s/, *$//;
    $the_prep =~ s/short term cell line/short term culture/;
    push @{ $info_ref }, join("\t",
      $lid, $name, $keys, $the_tiss, $the_hist, $the_prep);
  }      
  $stm->finish;

  $db->disconnect();
}

######################################################################
sub FormatOneLib {
  my ($what, $org, $info) = @_;
  my ($lid, $title, $keys, 
      $the_tiss, $the_hist, $the_prep) = split("\t", $info);

  $the_hist = $nice_histology_name{$the_hist};
  if ($the_tiss eq "mammary gland" && $org eq "Hs") {
    $the_tiss = "breast";
  }

  $the_tiss or $the_tiss = '-';
  $the_hist or $the_hist = '-';
  $the_prep or $the_prep = '-';
  $keys or $keys = '&nbsp;';

  my $s;
  if ($what eq "HTML") {
    $s = "<tr valign=top>".
        "<td>" .
            "<a href=\"" . $BASE .
            "/SAGE/SAGELibInfo?LID=$lid&ORG=$org\">$title</a>" .
        "</td>" . 
        "<td>" . $the_tiss  . "</td>" .
        "<td>" . $the_hist  . "</td>" .
        "<td>" . $the_prep  . "</td>" .
        "<td>" . $keys      . "</td>" .
        "</tr>";
  } else {
    $s = "$title\t$the_tiss\t$the_hist\t$the_prep\t$keys";
  }
  return $s;
}

######################################################################
sub FormatLibs {
  my ($page, $org, $cmd, $page_header, $items_ref) = @_;

  if (scalar(@{ $items_ref }) == 0) {
    return "<h4>$page_header</h4><br><br>" .
        "There are no libraries matching the query<br><br>";
  }
  if ($page < 1) {
    my $i;
    my $s;
    for ($i = 0; $i < scalar(@{ $items_ref }); $i++) {
      $s = $s . FormatOneLib("TEXT", $org, $$items_ref[$i]) . "\n";
    }
    return $s;
  } else {
    return PageResults($page, $org, $cmd, $page_header,
      $LIBRARY_LIST_TABLE_HEADER, \&FormatOneLib, $items_ref);
  }
}

######################################################################
sub SelectionPullDowns_1 {
  my ($base, $org, $what) = @_;

  my ($db, $stm, $sql);
  my ($tissue_keyword, $tissue_standard);
  my ($histology_keyword, $histology_standard);
  my %hist2std = (
    "benign hyperplasia" => "Benign Hyperplasia",
    "preneoplasia" => "Pre-cancer",
    "neoplasia" => "Cancer",
    "normal" => "Normal",
    "tumor associated" => "Tumor associated",
    "uncharacterized histology" => "Uncharacterized"
  );
  my (@rows);

  $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  if ($what eq "tissue") {

    $sql = qq!
select unique
  s.tissue_keyword,
  s.tissue_standard
from
  $CGAP_SCHEMA.sagelibinfo i,
  $CGAP_SCHEMA.sagetissues s
where
      i.tissue = s.tissue_keyword
  and i.organism = '$org'
order by s.tissue_standard
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    while(($tissue_keyword, $tissue_standard) = $stm->fetchrow_array()) {
      if ($org eq "Mm" && $tissue_standard eq "Breast") {
        $tissue_standard = "Mammary gland";
      }
      push @rows,
          "<option value=\"$tissue_keyword\">$tissue_standard</option>";
    }
  } elsif ($what eq "histology") {
    $sql = qq!
select unique
  i.the_hist
from
  $CGAP_SCHEMA.sagelibinfo i
where
  i.organism = '$org'
order by i.the_hist
    !;

    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    while(($histology_keyword) = $stm->fetchrow_array()) {
      if (defined $hist2std{$histology_keyword}) {
        $histology_standard = $hist2std{$histology_keyword};
      } else {
        $histology_standard = $histology_keyword;
      }
      push @rows,
          "<option value=\"$histology_keyword\">$histology_standard</option>";
    }
  }

  $db->disconnect();

  return join("\n", @rows) . "\n";

}

######################################################################
## GXS
######################################################################

## removed

######################################################################
# BlowUpBrain stuff
######################################################################

######################################################################
sub LIBLIST_URL {
  my ($base, $tag, $tiss, $hist, $scope, $knockout, $org, $method) = @_;

  return "<a href=\"" . url_encode("$base/SAGE/FreqsOfTag?" .
        "ORG=$org&METHOD=$method&FORMAT=html&" .
        "TAG=$tag&TISS=$tiss&HIST=$hist&CELL=$scope&" .
        "NOT=$knockout\"") . ">";
}

######################################################################
sub BrainAnatomicFreqs_1 {
  my ($base, $tag, $scope, $org, $method) = @_;

  my @normal_tissue_keywords = (
    "cortex",
    "thalamus",
    "substantia nigra",
    "cerebellum",
    "spinal cord"
  );

  my @cancer_histology_keywords = (
    "glioblastoma multiforme",
    "oligodendroglioma",
    "astrocytoma grade i",
    "astrocytoma grade ii",
    "astrocytoma grade iii",
    "medulloblastoma",
    "ependymoma",
    "ependymoblastoma"
  );

  my %brain_cancer_pix = (
    "glioblastoma multiforme"      => "c6",
    "astrocytoma grade iii"   => "c7",
    "astrocytoma grade ii"    => "c8",
    "oligodendroglioma" => "c9",
    "astrocytoma grade i"     => "c18",
    "ependymoblastoma"  => "c21",
    "ependymoma"        => "c23",
    "medulloblastoma"   => "c24"
##  "spinal cord"       => "c28,c29,c30"
  );

  my %brain_normal_pix = (
    "cortex"           => "n1,n2,n4,n7,n9,n10,n11",
    "thalamus"         => "n3",
    "substantia nigra" => "n5",
    "spinal cord"      => "n12,n15",
    "cerebellum"       => "n6,n8,n13,n14"
  );

  my (%pooledtags, %lid2hist, %lid2tiss, %tagfreqs);
  my ($tissue, $histology, $tisshist, $numerator, $denominator, $interval);
  my (
    %U,     ## Map to url
    %W      ## Map to level
  );

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    exit();
  }

  ##
  ## Don't use the_tiss in the LibPartitionQuery: it's too restrictive
  ## for present purposes
  ##
  LibPartitionQuery($db, $org, $scope, "", "normal",
      \@normal_tissue_keywords,
      ["normal"], ["fetus"], \%pooledtags, \%lid2hist, \%lid2tiss, $method);
  LibPartitionQuery($db, $org, $scope, "", "neoplasia",
      ["brain"],
      \@cancer_histology_keywords, ["fetus"],
      \%pooledtags, \%lid2hist, \%lid2tiss, $method);
  PartitionedFreqsOfTag($db, $tag, \%lid2hist, \%lid2tiss, \%tagfreqs,
                                                           $org, $method);

  $db->disconnect();


  for $tissue (@normal_tissue_keywords) {
    $tisshist = "$tissue,normal";
    if (defined $pooledtags{$tisshist}) {
      $denominator = $pooledtags{$tisshist};
      if (defined $tagfreqs{$tisshist}) {
        $numerator = $tagfreqs{$tisshist};
      } else {
        $numerator = 0;
      }
      $interval = GetAnatomicInterval($numerator, $denominator);
      if ($interval > 512) {
        $interval = "512plus";
      }
    } else {
      $interval = 0;
    }
    for (split(",", $brain_normal_pix{$tissue})) {
      $W{$_} = $interval;
      if ($interval ne "0") {
        $U{$_} = LIBLIST_URL($base, $tag, $tissue, "normal", $scope, "fetus",
                                                              $org, $method);
        $U{$_ . "_"} = "</a>";
      }
    }
  }

  for $histology (@cancer_histology_keywords) {
    $tisshist = "brain,$histology";
    if (defined $pooledtags{$tisshist}) {
      $denominator = $pooledtags{$tisshist};
      if (defined $tagfreqs{$tisshist}) {
        $numerator = $tagfreqs{$tisshist};
      } else {
        $numerator = 0;
      }
      $interval = GetAnatomicInterval($numerator, $denominator);
      if ($interval > 512) {
        $interval = "512plus";
      }
    } else {
      $interval = 0;
    }
    for (split(",", $brain_cancer_pix{$histology})) {
      $W{$_} = $interval;
      if ($interval ne "0") {
        $U{$_} = LIBLIST_URL($base, $tag, "brain", $histology, $scope, "fetus",
                                                                 $org, $method);
        $U{$_ . "_"} = "</a>";
      }
    }
  }

  return DrawBrain_1(\%U, \%W);
}

######################################################################
sub DrawBrain_1 {
  my (
    $U,     ## url hash
    $W      ## interval hash
  ) = @_;

return qq!

<table cellspacing="0" cellpadding="0" border="0">
<tr>
<td width="417">

<table cellspacing="0" cellpadding="0" border="0" width="417">
<tr>
    <td rowspan="7">$$U{n1}<img src="images/brain/n1_$$W{n1}.gif" width=143 height=327 border=0 alt="Cortex">$$U{n1_}</td>
    <td colspan="6">$$U{n2}<img src="images/brain/n2_$$W{n2}.gif" width=274 height=114 border=0 alt="Cortex">$$U{n2_}</td>
</tr>
<tr>
    <td>$$U{n3}<img src="images/brain/n3_$$W{n3}.gif" width=65 height=30 border=0 alt="Thalamus">$$U{n3_}</td>
    <td colspan="5">$$U{n4}<img src="images/brain/n4_$$W{n4}.gif" width=208 height=30 border=0 alt="Cortex">$$U{n4_}</td>
</tr>
<tr>
    <td rowspan="2">$$U{n5}<img src="images/brain/n5_$$W{n5}.gif" width=65 height=34 border=0 alt="Substantia Nigra">$$U{n5_}</td>
    <td rowspan="2">$$U{n6}<img src="images/brain/n6_$$W{n6}.gif" width=36 height=34 border=0 alt="Cerebellum">$$U{n6_}</td>
    <td colspan="3">$$U{n7}<img src="images/brain/n7_$$W{n7}.gif" width=41 height=6 border=0 alt="Cortex">$$U{n7_}</td>
    <td rowspan="3">$$U{n11}<img src="images/brain/n11_$$W{n11}.gif" width=131 height=47 border=0 alt="Cortex">$$U{n11_}</td>
</tr>
<tr>
    <td>$$U{n8}<img src="images/brain/n8_$$W{n8}.gif" width=19 height=28 border=0 alt="Cerebellum">$$U{n8_}</td>
    <td>$$U{n9}<img src="images/brain/n9_$$W{n9}.gif" width=5 height=28 border=0 alt="Cortex">$$U{n9_}</td>
    <td>$$U{n10}<img src="images/brain/n10_$$W{n10}.gif" width=17 height=28 border=0 alt="Cortex">$$U{n10_}</td>
</tr>
<tr>
    <td rowspan="3">$$U{n12}<img src="images/brain/n12_$$W{n12}.gif" width=65 height=149 border=0 alt="Spinal Cord">$$U{n12_}</td>
    <td colspan="4">$$U{n13}<img src="images/brain/n13_$$W{n13}.gif" width=77 height=13 border=0 alt="Cerebellum">$$U{n13_}</td>
</tr>
<tr>
    <td colspan="5">$$U{n14}<img src="images/brain/n14_$$W{n14}.gif" width=207 height=82 border=0 alt="Cerebellum">$$U{n14_}</td>
</tr>
<tr>
    <td colspan="5">$$U{n15}<img src="images/brain/n15_$$W{n15}.gif" width=208 height=54 border=0 alt="Spinal Cord">$$U{n15_}</td>
</tr>
</table></td>
<td width="72"><img src="images/brain/scale.gif" width=72 height=248 border=0 alt="SCALE"></td>

<td width="420">
<table cellspacing="0" cellpadding="0" border="0" width="420">
<tr>
    <td><img src="images/brain/c1.gif" width=97 height=30 border=0 alt=""></td>
    <td><img src="images/brain/c2.gif" width=56 height=30 border=0 alt="Glioblastoma"></td>
    <td colspan="2"><img src="images/brain/c3.gif" width=88 height=30 border=0 alt="Grade III Astrocytoma"></td>
    <td colspan="2"><img src="images/brain/c4.gif" width=179 height=30 border=0 alt=""></td>
</tr>
<tr>
    <td><img src="images/brain/c5.gif" width=97 height=89 border=0 alt="Oligodendroglioma"></td>
    <td>$$U{c6}<img src="images/brain/c6_$$W{c6}.gif" width=56 height=89 border=0 alt="Glioblastoma">$$U{c6_}</td>
    <td colspan="2">$$U{c7}<img src="images/brain/c7_$$W{c7}.gif" width=88 height=89 border=0 alt="Grade III Astrocytoma">$$U{c7_}</td>
    <td rowspan="2" colspan="2">$$U{c8}<img src="images/brain/c8_$$W{c8}.gif" width=179 height=114 border=0 alt="Grade II Astrocytoma">$$U{c8_}</td>
</tr>
<tr>
    <td rowspan="2">$$U{c9}<img src="images/brain/c9_$$W{c9}.gif" width=97 height=55 border=0 alt="Oligodendroglioma">$$U{c9_}</td>
    <td rowspan="2"><img src="images/brain/c10.gif" width=56 height=55 border=0 alt=""></td>
    <td colspan="2"><img src="images/brain/c11.gif" width=88 height=25 border=0 alt=""></td>
</tr>
<tr>
    <td><img src="images/brain/c12.gif" width=55 height=30 border=0 alt="Thalamus"></td>
    <td><img src="images/brain/c13.gif" width=33 height=30 border=0 alt=""></td>
    <td colspan="2"><img src="images/brain/c14.gif" width=179 height=30 border=0 alt=""></td>
</tr>
<tr>
    <td colspan="2"><img src="images/brain/c15.gif" width=153 height=32 border=0 alt=""></td>
    <td><img src="images/brain/c16.gif" width=55 height=32 border=0 alt="Substantia Nigra"></td>
    <td><img src="images/brain/c17.gif" width=33 height=32 border=0 alt=""></td>
    <td rowspan="2">$$U{c18}<img src="images/brain/c18_$$W{c18}.gif" width=48 height=48 border=0 alt="Grade I Astrocytoma">$$U{c18_}</td>
    <td rowspan="2"><img src="images/brain/c19.gif" width=131 height=48 border=0 alt=""></td>
</tr>
<tr>
    <td colspan="3"><img src="images/brain/c20.gif" width=208 height=16 border=0 alt=""></td>
    <td>$$U{c21}<img src="images/brain/c21_$$W{c21}.gif" width=33 height=16 border=0 alt="Ependymoblastoma">$$U{c21_}</td>
</tr>
<tr>
    <td rowspan="2" colspan="3"><img src="images/brain/c22.gif" width=208 height=69 border=0 alt="Ependymoblastoma, Ependymoma"></td>
    <td>$$U{c23}<img src="images/brain/c23_$$W{c23}.gif" width=33 height=34 border=0 alt="Ependymoma">$$U{c23_}</td>
    <td>$$U{c24}<img src="images/brain/c24_$$W{c24}.gif" width=48 height=34 border=0 alt="Medulloblastoma">$$U{c24_}</td>
    <td rowspan="2"><img src="images/brain/c25.gif" width=131 height=69 border=0 alt="Grade I Astrocytoma, Medulloblastoma"></td>
</tr>
<tr>
    <td><img src="images/brain/c26.gif" width=33 height=35 border=0 alt=""></td>
    <td><img src="images/brain/c27.gif" width=48 height=35 border=0 alt=""></td>
</tr>
<tr>
    <td colspan="3"><img src="images/brain/c28.gif" width=208 height=66 border=0 alt=""></td>
    <td><img src="images/brain/c29.gif" width=33 height=66 border=0 alt="Spinal Cord"></td>
    <td><img src="images/brain/c30.gif" width=48 height=66 border=0 alt=""></td>
    <td><img src="images/brain/c31.gif" width=131 height=66 border=0 alt=""></td>
</tr>
</table>

</td>
</tr>
<tr>
<td align="center" valign="top"><br> <p><img src="images/brain/normal.gif" width=157 height=21 border=0 alt="NORMAL"></p>
</td>
<td>&nbsp;</td>
<td align="center" valign="top"><br> <p><img src="images/brain/cancer.gif" width=157 height=21 border=0 alt="CANCER"></p>
</td></tr>
</table>

!;

}

######################################################################
sub GetGenomicsByTags_1 {
  my ($base, $page, $org, $tags, $method) = @_;
 
  my @results;
  my @lines;
  my @no_result_lines;
 
  $BASE = $base;
 
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }
 
  my ($sql);
  my ($stm);
  my (%tag_info);
  my ($protocol);
 
  my @all_tags = split ",", $tags;
  for( my $i=0; $i<@all_tags; $i++ ) {
    $all_tags[$i] =~ s/\s+//g;
  }
  my $list = "'" . join("', '", @all_tags) . "'";

  my $genomics_table;
  my $genomicsdup_table;

 
  $sql =
    "select CODE from $CGAP_SCHEMA.SAGEPROTOCOL " .
    "where ORGANISM = '$org' and PROTOCOL = '$method' ";
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }  
  $stm->bind_columns(\$protocol);
  while($stm->fetch()) {
  }

  if( $protocol eq "" ) {
    return "";
  }
  $sql =
    "select unique a.TAG, a.CHROMOSOME, a.START_POSITION, a.STRAND, " .
    "a.FREQUENCY, b.CHROMOSOME, b.START_POSITION, b.STRAND " .
    "from $CGAP_SCHEMA.SAGEGENOMICS a, $CGAP_SCHEMA.SAGEGENOMICSDUP b " .
    "where a.TAG in ( $list ) and a.TAG = b.TAG(+) " .
    "and a.protocol = '$protocol' and a.protocol = b.protocol(+) "; 
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    ## print "$sql\n";
    ## print "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
  while (my ($TAG, $CHROMOSOME, $START_POSITION, $STRAND, $FREQUENCY, 
             $CHROMOSOME_DUP, $START_POSITION_DUP, $STRAND_DUP ) = 
                                               $stm->fetchrow_array()) {
    if( $FREQUENCY == 1 ) {
      if( $CHROMOSOME eq "X" ) {
        $tag_info{$TAG}{23}{$START_POSITION}{$STRAND} =1;
      }
      elsif( $CHROMOSOME eq "Y" ) {
        $tag_info{$TAG}{24}{$START_POSITION}{$STRAND} =1;
      }
      elsif( $CHROMOSOME eq "MT" ) {
        $tag_info{$TAG}{25}{$START_POSITION}{$STRAND} =1;
      }
      else {
        $tag_info{$TAG}{$CHROMOSOME}{$START_POSITION}{$STRAND} = 1;
      }
    }
    elsif ( $FREQUENCY > 1 ) {
      if( $CHROMOSOME_DUP eq "X" ) {
        $tag_info{$TAG}{23}{$START_POSITION_DUP}{$STRAND_DUP} =1;
      }
      elsif( $CHROMOSOME_DUP eq "Y" ) {
        $tag_info{$TAG}{24}{$START_POSITION_DUP}{$STRAND_DUP} =1;
      }
      elsif( $CHROMOSOME_DUP eq "MT" ) {
        $tag_info{$TAG}{25}{$START_POSITION_DUP}{$STRAND_DUP} =1;
      }
      else {
        $tag_info{$TAG}{$CHROMOSOME_DUP}{$START_POSITION_DUP}{$STRAND_DUP}= 1;
      }
    } 
  }
 
  $db->disconnect();
 
  for ( my $i=0; $i<@all_tags; $i++ ) {
    my $tag = $all_tags[$i];
    if( defined $tag_info{$tag} ) {
      for my $chr ( sort numerically keys %{$tag_info{$tag}} ) {
        for my $pos ( sort numerically keys %{$tag_info{$tag}{$chr}} ) {
          for my $strand ( sort numerically keys %{$tag_info{$tag}{$chr}{$pos}}) {
            if( $chr eq "23" ) {
              $chr = "X";
            }
            elsif( $chr eq "24" ) {
              $chr = "Y";
            }
            elsif( $chr eq "25" ) {
              $chr = "MT";
            }
   
            push @lines, (join "\t", $tag, $chr, $pos, $strand) . "\n";
          }
        }
      }
    }
    else {
      push @no_result_lines, $all_tags[$i] . "\n";
    }
  }



  if( @lines > 0 ) {
    my $header_1 = "#TAG	CHR	START	STRAND\n";
    push @results, $header_1; 
    push @results, (join "", @lines);
    ## push @results, (join "", @lines) . "//\n" ;
  }
  push @results, "//\n" ;

  if( @no_result_lines > 0 ) {
    my $header_2 = "#TAG\n";
    push @results, $header_2;
    push @results, (join "", @no_result_lines);
  }
  push @results, "//\n" ;

  return (join "", @results);
}
 
######################################################################
sub GetBatchGenomics_1 {
  my ($base, $page, $org, $filedata, $order, $method, $email) = @_;
 
  $BASE = $base;

  my (%tag2allinfo, %chr_position2allinfo);
  my (@all_lines, @good_lines, @dup_lines, @no_result_lines);
 
  my ($list);
  my ($sql, $stm);
  my %goodInput;
  my %tags;
  my $lines;
  my $count = 0;
  my (%dup_tags);
 
  my @tempArray;
  if( $filedata =~ /\r/ ) {
    @tempArray = split "\r", $filedata;
  }
  else {
    @tempArray = split "\n", $filedata;
  }
  
  for (my $t = 0; $t < @tempArray; $t++ ) {
    $tempArray[$t] =~  s/\s//g;
    if ($tempArray[$t] eq "") {
      next;
    }
    else {
      push @all_lines, $tempArray[$t]; 
      $tags{$tempArray[$t]} = 1;
    }
  } 

  $count = @all_lines;
  if ( $count > 200000 ) {
    if( $email ne "" ) {
      my $id = write_upload_file(\@all_lines, $email, $order, $org);
      if( $id eq "" ) {
        return "There is a error in the process.";
      }
      else {
        return "Your file has been uploaded and you will receive " .
               "an email ($email) within five days for your result. " .
               "Otherwise please contace us, your upload file id is $id";
      }
    }
    else {
      return "Your file has more than 200000 tags, Please fill email address.";
    }
  }

  GetDataFromOracle($org, $order, \@all_lines, \%tag2allinfo,
        \%chr_position2allinfo, \%dup_tags, $method);
  
  ## ordering
  if( $order eq "Original" ) {
    for( my $i=0; $i<@all_lines; $i++ ) {
      if( defined $tag2allinfo{$all_lines[$i]} ) {
        push @good_lines, $tag2allinfo{$all_lines[$i]} . "\n";
      }
      elsif(defined $dup_tags{$all_lines[$i]} and $dup_tags{$all_lines[$i]}>1){
        push @dup_lines, $all_lines[$i] . "\t" . $dup_tags{$all_lines[$i]} . "\n";
      }
      else {
        push @no_result_lines, $all_lines[$i] . "\n";
      }
    }
  }
  else {
    my %tmp;
    for my $tag ( keys %chr_position2allinfo ) {
      for my $chr ( keys %{$chr_position2allinfo{$tag}} ) {
        for my $pos ( keys %{$chr_position2allinfo{$tag}{$chr}}) {
          for my $strand ( keys %{$chr_position2allinfo{$tag}{$chr}{$pos}}) {
            $tmp{$chr}{$pos}{$strand} = $tag;
          }
        }
      }
    }
    for my $chr (sort numerically keys %tmp) {
      for my $pos (sort numerically keys %{$tmp{$chr}}) {
        for my $strand (sort keys %{$tmp{$chr}{$pos}}) {
          my $tmp_chr = $chr;
          if( $chr eq "23" ) {
            $chr = "X";
          }
          elsif( $chr eq "24" ) {
            $chr = "Y";
          }
          elsif( $chr eq "25" ) {
            $chr = "MT";
          }

          push @good_lines, 
              (join "\t", $tmp{$tmp_chr}{$pos}{$strand},$chr,$pos,$strand) . "\n";
        }
      }
    }
    for( my $i=0; $i<@all_lines; $i++ ) {
      if( defined $chr_position2allinfo{$all_lines[$i]} ) {
        next;
      }
      elsif( defined $dup_tags{$all_lines[$i]} and $dup_tags{$all_lines[$i]} > 1 ) {
        push @dup_lines, 
          $all_lines[$i] . "\t" . $dup_tags{$all_lines[$i]} . "\n";
      }
      else {
        push @no_result_lines, $all_lines[$i] . "\n";
      }
    }
  }

  my $header_1 = "#TAG	CHR	START	STRAND\n";
  my $header_2 = "#TAG	FREQUENCY\n";
  my $header_3 = "#TAG\n";
  my $lines; 
  if ( @good_lines > 0 ) {
    $lines = $header_1 . (join "", @good_lines); 
  }
  $lines = $lines . "//\n"; 
  if ( @dup_lines > 0 ) {
    $lines = $lines . $header_2 . (join "", @dup_lines); 
  }
  $lines = $lines . "//\n"; 
  if ( @no_result_lines > 0 ) {
    $lines = $lines . $header_3 . (join "", @no_result_lines); 
  }
  $lines = $lines . "//\n"; 
 
  return $lines;
}

######################################################################
sub GetDataFromOracle {
  my ($org, $order, $all_lines_ref, $tag2allinfo_ref, 
      $chr_position2allinfo_ref, $dup_tags_ref, $method) = @_;

  my @all_lines = @{$all_lines_ref};
  my ($sql, $stm, $list);
  my ($protocol);

  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }
 
  my $genomics_table;
  $sql =
    "select CODE from $CGAP_SCHEMA.SAGEPROTOCOL " .
    "where ORGANISM = '$org' and PROTOCOL = '$method' ";
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  } 

  $stm->bind_columns(\$protocol);

  while($stm->fetch()) {
  }
 
  if( $protocol eq "" ) {
    return "";
  }

 
  for(my $i = 0; $i < @all_lines; $i += ORACLE_LIST_LIMIT) {
 
    if(($i + ORACLE_LIST_LIMIT - 1) < @all_lines) {
      $list = "'" . join("', '", @all_lines[$i..$i+ORACLE_LIST_LIMIT-1]) . "'";
    }
    else {
      $list = "'" . join("', '", @all_lines[$i..@all_lines-1]) . "'";
    }
 
    $sql =
        "select unique TAG, CHROMOSOME, START_POSITION, STRAND, FREQUENCY " .
        "from $CGAP_SCHEMA.SAGEGENOMICS " .
        "where tag in ( $list ) and protocol = '$protocol' ";

    $stm = $db->prepare($sql);
    if(not $stm) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "<br><b><center>Error in input</b>!</center>";
      $db->disconnect();
      return "";
    }
    if(!$stm->execute()) {
      ## print STDERR "$sql\n";
      ## print STDERR "$DBI::errstr\n";
      print "execute call failed\n";
      $db->disconnect();
      return "";
    }
    while (my ($TAG, $CHROMOSOME, $START_POSITION, $STRAND, $FREQUENCY ) = 
                                                   $stm->fetchrow_array()) {
      if( $order eq "Original" ) {
        if( $FREQUENCY == 1 ) {
          $$tag2allinfo_ref{$TAG}=join "\t",$TAG,$CHROMOSOME,$START_POSITION,$STRAND;
        }
        else {
          $$dup_tags_ref{$TAG} = $FREQUENCY;
        }
      }
      else {
        if( $FREQUENCY == 1 ) {
          if( $CHROMOSOME eq "X" ) {
            $$chr_position2allinfo_ref{$TAG}{23}{$START_POSITION}{$STRAND} =1;
          }
          elsif( $CHROMOSOME eq "Y" ) {
            $$chr_position2allinfo_ref{$TAG}{24}{$START_POSITION}{$STRAND} =1;
          }
          elsif( $CHROMOSOME eq "MT" ) {
            $$chr_position2allinfo_ref{$TAG}{25}{$START_POSITION}{$STRAND} =1;
          }
          else {
            $$chr_position2allinfo_ref{$TAG}{$CHROMOSOME}{$START_POSITION}{$STRAND} = 1;
          }
        }
        else {
          $$dup_tags_ref{$TAG} = $FREQUENCY;
        }
      }
    }
  }
 
  $db->disconnect();
 
}

######################################################################
sub write_upload_file {
  my ($all_lines_ref, $email, $order, $org) = @_;
  my ($sql, $stm);
  my $FILE_ID;
  my $db = DBI->connect("DBI:Oracle:" . $DB_INSTANCE,$DB_USER,$DB_PASS);
  if (not $db or $db->err()) {
    ## print STDERR "Cannot connect to " .$DB_USER . "@" . $DB_INSTANCE . "\n";
    print "Cannot connect to database \n";
    return "";
  }

  $sql = "select $CGAP_SCHEMA.SAGE_UPLOAD_FILE_ID.nextval from DUAL";
  $stm = $db->prepare($sql);
  if(not $stm) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "<br><b><center>Error in input</b>!</center>";
    $db->disconnect();
    return "";
  }
  if(!$stm->execute()) {
    ## print STDERR "$sql\n";
    ## print STDERR "$DBI::errstr\n";
    print "execute call failed\n";
    $db->disconnect();
    return "";
  }
 
  $db->disconnect();

  my $file = INIT_SAGE_DATA_HOME . "sage_upload/$FILE_ID" . ".txt";
  my $tmp_file = INIT_SAGE_DATA_HOME . "sage_upload/temp/$FILE_ID" . 
                                       ".txt";
  open (OUT, ">$tmp_file") or die "Can not open $file\n";
  print OUT $org . "\n";
  print OUT $order . "\n";
  print OUT $email . "\n";
  print OUT ( join "\n", @{$all_lines_ref} ) . "\n";
  close OUT;
  my $cmd_1 = "chmod 0666 $tmp_file";
  system ($cmd_1);
  my $cmd_2 = "mv $tmp_file $file";
  system ($cmd_2);
  return $FILE_ID;
 
}

######################################################################
sub GetGenimicsCache_1 {
  my ($base, $cache_id) = @_;
 
  $BASE = $base;
 
  return ReadGenomicsFromCache($cache_id);
}
 
######################################################################
sub ReadGenomicsFromCache {
  my ($cache_id) = @_;
 
  my ($s, @data);
 
  if ($genomics_cache->FindCacheFile($cache_id) eq $CACHE_FAIL) {
    return "Cache expired";
  }
  my $filename = $genomics_cache->FindCacheFile($cache_id);
  open(IN, "$filename") or die "Can't open $filename.";
  while (read IN, $s, 16384) {
    push @data, $s;
  }
  close (IN);
  return join("", @data);
 
}

######################################################################
sub GetUserResults_1 {
  my ($base, $cache_id, $time, $email) = @_;
 
  $BASE = $base;
 
  return ReadUserResultsFromCache($cache_id, $time, $email);
}
 
######################################################################
sub ReadUserResultsFromCache {
  my ($cache_id, $time, $email) = @_;
 
  my ($s, @data);
 
  if ($gxs_cache->FindCacheFile($cache_id) eq $CACHE_FAIL) {
    return "The cache expired";
  }
  my $filename = $gxs_cache->FindCacheFile($cache_id);
  my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
          $atime, $mtime, $ctime, $blksize, $blocks) 
                 = stat ($filename);
  if( $size <= 10 ) {
    my $current_time = time();
    my $t_d = $current_time - $time;
    if( $t_d < 1200000 ) {
       my @month_abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
       my @week_abbr = qw( Sun Mon Tues Wed Thurs Fri Sat );
       my ($sec_r,$min_r,$hour_r,$mday,$mon,$year,$wday,$yday,$isdst) =
                   localtime($time);
       $sec_r = sprintf("%02d", $sec_r);
       $min_r = sprintf("%02d", $min_r);
       $hour_r = sprintf("%02d", $hour_r);
       my $y_r = $year + 1900;
       my $time_r = "$week_abbr[$wday] $month_abbr[$mon] $mday $hour_r:$min_r:$sec_r $y_r";
       my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                   localtime($current_time);
       my $y = $year + 1900;
       $sec = sprintf("%02d", $sec);
       $min = sprintf("%02d", $min);
       $hour = sprintf("%02d", $hour);
       my $time_now = "$week_abbr[$wday] $month_abbr[$mon] $mday $hour:$min:$sec $y";
       my $flag_s = 0;
       my $flag_m = 0;
       my ($sec_d, $min_d, $hour_d);
       if ( $sec < $sec_r ) {
         $sec_d = 60 + $sec - $sec_r;
         $flag_s = 1;
       }
       else {
         $sec_d = $sec - $sec_r;
       }
       $sec_d = sprintf("%02d", $sec_d);
       if( $flag_s == 1 ) {
         if ( $min < $min_r ) {
           $min_d = 60 + $min - $min_r -1;
           $flag_m = 1;
         }
         else {
           $min_d = $min - $min_r -1;
         }
       }
       else {
         if ( $min < $min_r ) {
           $min_d = 60 + $min - $min_r;
           $flag_m = 1;
         }
         else {
           $min_d = $min - $min_r;
         }
       }
       $min_d = sprintf("%02d", $min_d);
       if( $flag_m == 1 ) {
         $hour_d = $hour - $hour_r -1;
       }
       else {
         $hour_d = $hour - $hour_r;
       }
       $hour_d = sprintf("%02d", $hour_d);
       my $time_e = "$hour_d:$min_d:$sec_d";

       my $output =
        "<html>" .
        "<head>" .
        "<script>" .
        "function trylink() {" .
        "window.location=\"/SAGE/GetUserResult?CACHE=$cache_id&TIME=$time&EMAIL=$email\";".
        "}" .
        "function delay() {" .
        "setTimeout(\"trylink()\", 30000);" .
        "}" .
        "</script>" .
        "</head>" .
        "<body onLoad=\"delay()\">" .
        "<center><table>" .
        "<tr><td>Request ID</td><td>$cache_id</td><tr>" .
        "<tr><td>Submitted at</td><td>$time_r</td></tr>" .
        ## "<tr><td>Current time</td><td>$time_now</td></tr>" .
        ## "<tr><td>Time since submission&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td>$time_e</td></tr>" .
        "</table></center>" .
        "<BR><BR>" .
        ## "<BR><BR><center><a href=/SAGE/GetUserResult?CACHE=$cache_id&TIME=$time>Please wait several more minutes and then click the hyper link here</a></center><br><br>" .        
        ## " <center>This window will be automatically updated when the results of your query are ready.</center>" .
        ## " <br><br><center>This page will be automatically updated in 30 seconds.</center>" .
        "<center>When the results are ready, they will appear in this window.</center>" .
        "<center>Or you can close this window; the link for the results will be emailed to $email.</center>" .
        "</body>";
      ## return "<BR><BR><center><a href=http://cgap-stage.nci.nih.gov/SAGE/GetUserResult?CACHE=$cache_id&TIME=$time>Please wait 5 more minutes and then click the hyper link here</a></center>";
      return $output;
    }
    else {
      return "The query failed, Please contact the help desk.";
    }
  }
  else {
    open(IN, "$filename") or die "Can't open $filename.";
    while (read IN, $s, 16384) {
      push @data, $s;
    }
    close (IN);
    return join("", @data);
  }
 
}


###################################################################
sub Complementary {
  my ($str) = @_;
  my @t_arrary = split "", $str;
  for (my $i=0; $i<@t_arrary; $i++ ) {
    if( $t_arrary[$i] eq "C" ) {
      $t_arrary[$i] = "G";
    }
    elsif( $t_arrary[$i] eq "G" ) {
      $t_arrary[$i] = "C";
    }
    elsif( $t_arrary[$i] eq "A" ) {
      $t_arrary[$i] = "T";
    }
    elsif( $t_arrary[$i] eq "T" ) {
      $t_arrary[$i] = "A";
    }
  }
 
  return join "", @t_arrary;
}
 
######################################################################
1;
