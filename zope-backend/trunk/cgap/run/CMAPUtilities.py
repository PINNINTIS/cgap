#! /usr/local/bin/python

from CommonUtilities import *
import string
import commands

######################################################################
def ComputeDotBlot (binpath, base, request):

  org           = GetRequestParam(request, 'ORG')
  context       = GetRequestParam(request, 'CONTEXT')
  cmap_id       = GetRequestParam(request, 'CMAP_ID')
  path          = GetRequestParam(request, 'PATH')
  lib_id        = GetRequestParam(request, 'LIB_ID')
  anomaly       = GetRequestParam(request, 'ANOMALY')
  text          = GetRequestParam(request, 'TEXT')

  cmd = binpath + "/" + "ComputeDotBlot.pl " + \
    "'" + str(base)         + "' " + \
    "'" + str(org)          + "' " + \
    "'" + str(context)      + "' " + \
    "'" + str(cmap_id)      + "' " + \
    "'" + str(path)         + "' " + \
    "'" + str(lib_id)       + "' " + \
    "'" + str(anomaly)      + "' " + \
    "'" + str(text)         + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def FindAgentPage (binpath, base, request):

  org        = GetRequestParam(request, 'ORG')
  agent      = GetRequestParam(request, 'AGENT')
  context    = GetRequestParam(request, 'CONTEXT')
  scope      = GetRequestParam(request, 'SCOPE')

  cmd = binpath + "/" + "BuildAgentPage.pl " + \
    "'" + str(base)        + "' " + \
    "'" + str(org)         + "' " + \
    "'" + str(agent)       + "' " + \
    "'" + str(context)     + "' " + \
    "'" + str(scope)       + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def FindAgents (binpath, base, request):

  org         = GetRequestParam(request, 'ORG')
  term        = GetRequestParam(request, 'TERM')
  context     = GetRequestParam(request, 'CONTEXT')

  if request.form.has_key('HAS_TARGET'):
    has_target = 1
  else:
    has_target = 0
    
  if request.form.has_key('HAS_CTEP'):
    has_ctep = 1
  else:
    has_ctep = 0
    
  cmd = binpath + "/" + "FindAgents.pl " + \
    "'" + str(base)        + "' " + \
    "'" + str(org)         + "' " + \
    "'" + str(has_target)  + "' " + \
    "'" + str(has_ctep)    + "' " + \
    "'" + str(term)        + "' " + \
    "'" + str(context)     + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def FindLibsOfCluster (binpath, base, page, org, id):

  cmd = binpath + "/" + "GetLibsOfCluster.pl " + \
      "'" + str(base) +  "' " + \
      "'" + str(page) +  "' " + \
      "'" + str(org)  +  "' " + \
      "'" + str(id)   +  "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def FindGenePage (binpath, base, request):
  org     = GetRequestParam(request, 'ORG')
  bcid    = GetRequestParam(request, 'BCID')
  ecno    = GetRequestParam(request, 'ECNO')
  llno    = GetRequestParam(request, 'LLNO')
  cid     = GetRequestParam(request, 'CID')
  context = GetRequestParam(request, 'CONTEXT')

  if (cid == ''):
    cmd = binpath + "/" + "GetPathInfo.pl " + \
        "'" + str(org)       + "' " + \
        "'" + str(bcid)      + "' " + \
        "'" + str(ecno)      + "' " + \
        "'" + str(llno)      + "' "

    (status, id) = commands.getstatusoutput(cmd)
    if (status / 256 != int(S_OK)):
       return "<B>No Gene Information available</B><br>\n"
  else:
    id = cid

  cmd = binpath + "/" + "BuildGenePage.pl " + \
      "'" + str(base)    +  "' " + \
      "'" + str(org)     +  "' " + \
      "'" + str(id)      +  "' " + \
      "'" + str(context) +  "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def FindLibPage (binpath, org, id):

  cmd = binpath + "/" + "BuildLibPage.pl " + \
    "'" + str(org)   + "' " + \
    "'" + str(id)    + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def FindLibrary (binpath, base, request):

  page   = GetRequestParam(request, 'PAGE')
  org    = GetRequestParam(request, 'ORG')
  scope  = GetRequestParam(request, 'SCOPE')
  title  = GetRequestParam(request, 'TITLE')
  type   = GetRequestParam(request, 'TYPE')
  tissue = GetRequestParam(request, 'TISSUE')
  hist   = GetRequestParam(request, 'HIST')
  prot   = GetRequestParam(request, 'PROT')
  sort   = GetRequestParam(request, 'SORT')

  cmd = binpath + "/" + "GetLibrary.pl " + \
    "'" + str(base)     + "' " + \
    "'" + str(page)     + "' " + \
    "'" + str(org)      + "' " + \
    "'" + str(scope)    + "' " + \
    "'" + str(title)    + "' " + \
    "'" + str(type)     + "' " + \
    "'" + str(tissue)   + "' " + \
    "'" + str(hist)     + "' " + \
    "'" + str(prot)     + "' " + \
    "'" + str(sort)     + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def FindPathInfo (binpath, org, bcid):

  cmd = binpath + "/" + "GetPathInfo.pl " + \
    "'" + str(org)       + "' " + \
    "'" + str(bcid)      + "' "

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def ListBioCartaPathways (binpath, base, context):

  cmd = binpath + "/" + "ListBioCartaPathways.pl " + \
    "'" + str(base)         + "' " + \
    "'" + str(context)      + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response


######################################################################
# CommonGene stuff
######################################################################

######################################################################
def CommonGeneQuery (binpath, base, page, request):

  org         = GetRequestParam(request, 'ORG')
  ckbox       = GetRequestParam(request, 'CKBOX')
  page_header = GetRequestParam(request, 'PAGE_HEADER')
  cids        = GetRequestParam(request, 'CIDS')

  cidarray = []
  if type(cids) == type(''):
    cidlist = cids
  else:
    for c in cids:
      cidarray.append(int(c))
    cidlist = str(string.join(cids, ","))

  cmd = binpath + "/" + "CommonGeneQuery.pl " + \
    "'" + str(base)        + "' " + \
    "'" + str(page)        + "' " + \
    "'" + str(org)         + "' " + \
    "'" + str(ckbox)       + "' " + \
    "'" + str(page_header) + "' " + \
    "'" + str(cidlist)     + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def ComputeVN (binpath, request):
  org    = GetRequestParam(request, 'ORG')
  cid    = GetRequestParam(request, 'CID')
  text   = GetRequestParam(request, 'TEXT')

  cmd = binpath + "/" + "ComputeVN.pl " + \
    "'" + str(org)       + "' " + \
    "'" + str(cid)       + "' " + \
    "'" + str(text)      + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def FindGene (binpath, \
    base, page, org, sym, title, curated, pathway, cyt, tissue):

  cmd = binpath + "/" + "GetGene.pl " + \
    "'" + str(base)     + "' " + \
    "'" + str(page)     + "' " + \
    "'" + str(org)      + "' " + \
    "'" + str(sym)      + "' " + \
    "'" + str(title)    + "' " + \
    "'" + str(curated)  + "' " + \
    "'" + str(pathway)  + "' " + \
    "'" + str(cyt)      + "' " + \
    "'" + str(tissue)   + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def UniGeneQuery (binpath, base, page, org, term):

  cmd = binpath + "/" + "GetGeneByNumber.pl " + \
      "'" + str(base)  + "' " + \
      "'" + str(page)  + "' " + \
      "'" + str(org)   + "' " + \
      "'" + str(term)  + "'" 

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def FindGOGenes (binpath, base, page, request):

  org    = GetRequestParam(request, 'ORG')
  goid   = GetRequestParam(request, 'GOID')

  cmd = binpath + "/" + "GetGOGenes.pl " + \
    "'" + str(base)      + "' " + \
    "'" + str(page)      + "' " + \
    "'" + str(org)       + "' " + \
    "'" + str(goid)      + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def FindGOTerms (binpath, request):

  pattern  = GetRequestParam(request, 'PATTERN')
  validate = GetRequestParam(request, 'VALIDATE')

  cmd = binpath + "/" + "GetGOTerms.pl " + \
     "'" + str(pattern)    + "' " + \
     "'" + str(validate)   + "' "

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def FindPathGenes (binpath, base, page, request):
  org    = GetRequestParam(request, 'ORG')
  path   = GetRequestParam(request, 'PATH')

  cmd = binpath + "/" + "GetPathGenes.pl " + \
    "'" + str(base)      + "' " + \
    "'" + str(page)      + "' " + \
    "'" + str(org)       + "' " + \
    "'" + str(path)      + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def WideDotBlot (binpath, base, request):

  org           = GetRequestParam(request, 'ORG')
  context       = GetRequestParam(request, 'CONTEXT')
  cmap_id       = GetRequestParam(request, 'CMAP_ID')
  path          = GetRequestParam(request, 'PATH')
  lib_id        = GetRequestParam(request, 'LIB_ID')
  anomaly       = GetRequestParam(request, 'ANOMALY')
  text          = GetRequestParam(request, 'TEXT')

  cmd = binpath + "/" + "WideDotBlot.pl " + \
    "'" + str(base)         + "' " + \
    "'" + str(org)          + "' " + \
    "'" + str(context)      + "' " + \
    "'" + str(cmap_id)      + "' " + \
    "'" + str(path)         + "' " + \
    "'" + str(lib_id)       + "' " + \
    "'" + str(anomaly)      + "' " + \
    "'" + str(text)         + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def WideBioCartaPathways_XML (binpath, base, context):

  cmd = binpath + "/" + "WideBioCartaPathways_XML.pl " + \
    "'" + str(base)         + "' " + \
    "'" + str(context)      + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

