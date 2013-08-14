##
## Parameters for back-end data servers for CGAP
##

package CGAPConfig;
require Exporter;
 
@ISA     = qw(Exporter);
@EXPORT  = qw(

  $CGAP_SCHEMA
  $CGAP_SCHEMA2
  $CMAP_SCHEMA
  $RFLP_SCHEMA

  $DB_USER
  $DB_PASS
  $DB_INSTANCE

  GENE_SERVER_PORT
  CYT_SERVER_PORT
  BLAST_QUERY_SERVER_PORT
  LIBRARY_SERVER_PORT
  GL_SERVER_PORT
  PATHWAY_SERVER_PORT
  MICROARRAY_SERVER_PORT

  GXS_SERVER_PORT

  INIT_DATA_HOME

  INIT_SAGE_DATA_HOME

  KEGG_DIR

  HS_GL_DATA
  MM_GL_DATA
  CACHE_ROOT
  CACHE_ID_FILE
  HS_GXS_DATA
  MM_GXS_DATA
  HS_UG_BLAST
  MM_UG_BLAST

  NCI60_STATS
  NCI60_VIEW

  SAGE_STATS
  SAGE_VIEW

  SAGE_GROUP_RAW
  SAGE_GROUP_STATS
  SAGE_GROUP_VIEW

  SAGEFREQ

  GXS_CACHE_PREFIX
  XP_CACHE_PREFIX
  GL_CACHE_PREFIX
  MICROARRAY_CACHE_PREFIX
  LICR_CACHE_PREFIX
  RNAi_CACHE_PREFIX
  SDGED_CACHE_PREFIX

  BASE
  IMG_DIR

  SAFE_IPS
);

use DB_SCHEMAConfig;
use  Config::Simple;

$CGAP_SCHEMA = RUNNING_CGAP_SCHEMA;
$CGAP_SCHEMA2 = "";
$CMAP_SCHEMA = "cmap";
$RFLP_SCHEMA = "rflp";

$cfg = new Config::Simple('/cgap/run/data.ini');
$DB_USER = $cfg->param('username');
$DB_PASS = $cfg->param('password');
$DB_INSTANCE = $cfg->param('sid');


##use constant GENE_SERVER_PORT        => "8001";
##use constant LIBRARY_SERVER_PORT     => "8004";
use constant GXS_SERVER_PORT         => "8005";

use constant GENE_SERVER_PORT        => "0000";
use constant LIBRARY_SERVER_PORT     => "0000";
##use constant GXS_SERVER_PORT         => "0000";

use constant CYT_SERVER_PORT         => "8002";
use constant BLAST_QUERY_SERVER_PORT => "8003";
use constant GL_SERVER_PORT          => "8006";
use constant PATHWAY_SERVER_PORT     => "8007";
use constant MICROARRAY_SERVER_PORT  => "8008";

use constant INIT_DATA_HOME          => "/cgap/data/";
use constant KEGG_DATA_HOME          => "/cgap/data/";
use constant INIT_SAGE_DATA_HOME     => "/cgap/data/";

use constant HS_GL_DATA              => INIT_DATA_HOME . "Hs_gl.dat";
use constant MM_GL_DATA              => INIT_DATA_HOME . "Mm_gl.dat";
use constant CACHE_ROOT              => INIT_DATA_HOME . "cache/";
use constant CACHE_ID_FILE           => CACHE_ROOT     . "cache_id";

use constant GXS_CACHE_PREFIX        => "GXS";
use constant XP_CACHE_PREFIX         => "XP";
use constant GL_CACHE_PREFIX         => "GL";
use constant MICROARRAY_CACHE_PREFIX => "MC";
use constant LICR_CACHE_PREFIX       => "LICR";
use constant RNAi_CACHE_PREFIX       => "RNAi";
use constant SDGED_CACHE_PREFIX      => "SDGED";

use constant HS_GXS_DATA        => INIT_DATA_HOME . "Hs_gxs.dat";
use constant MM_GXS_DATA        => INIT_DATA_HOME . "Mm_gxs.dat";

use constant HS_UG_BLAST        => INIT_DATA_HOME . "Hs.seq.all";
use constant MM_UG_BLAST        => INIT_DATA_HOME . "Mm.seq.all";

use constant NCI60_RAW       => INIT_DATA_HOME . "discover.raw";
use constant NCI60_STATS     => INIT_DATA_HOME . "discover.stats";
use constant NCI60_VIEW      => INIT_DATA_HOME . "discover.view";

use constant SAGE_RAW           => INIT_DATA_HOME . "sage.raw";
use constant SAGE_STATS         => INIT_DATA_HOME . "sage.stats";
use constant SAGE_VIEW          => INIT_DATA_HOME . "sage.view";

use constant SAGE_GROUP_RAW     => INIT_DATA_HOME . "sage_group.raw";
use constant SAGE_GROUP_STATS   => INIT_DATA_HOME . "sage_group.stats";
use constant SAGE_GROUP_VIEW    => INIT_DATA_HOME . "sage_group.view";

use constant SAGEFREQ           => INIT_SAGE_DATA_HOME . "sagefreq.dat";

# Perl equivalents of Zope dtml-var's BASE and IMG_DIR
use constant BASE     => "/CGAP";
use constant IMG_DIR  => "/CGAP/images";

use constant KEGG_DIR => "http://cgap.nci.nih.gov/KEGG";

use constant SAFE_IPS =>
  "127.0.0.1," .           ## localhost
  "128.231.202.171," .     ## lpgfs
  "137.187.66.221,"  .     ## lpgfs new
  "156.40.133.243,"  .     ## cbiodev24
  "137.187.66.205,"  .     ## cbiodev104
  "137.187.66.207,"  .     ## cbioapp101
  "137.187.66.209,"  .     ## cbioapp102
  "137.187.66.195,"  .     ## cbioapp104
  "137.187.66.222,"  .     ## ncicbstarfish
  "137.187.67.76,"   .     ## ncicbstarfish
  "137.187.67.77,"   .     ## ncicbstarfish
  "137.187.67.78" ;        ## ncicbstarfish

######################################################################
1;
