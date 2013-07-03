#!/bin/csh

set THIS_SCRIPT = clean_cache.csh
set RUNDIR = /share/content/CGAP/run

set CLEANER    = $RUNDIR/CacheCleaner.pl
set CACHE_PATH = /share/content/CGAP/data/cache
set PREFIXES   = "GL,GE,GXS,RNAi,SDGED,GENOMICS,DK,CMAP,MC,LICR"

$CLEANER $CACHE_PATH $PREFIXES
