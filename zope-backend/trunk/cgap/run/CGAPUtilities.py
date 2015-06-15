#! /usr/bin/python


from CommonUtilities import *
import cgi
import commands
import os

######################################################################
def SimilarityByMotif (binpath, base, page, accession, evalue, \
    score, pvalue, org):

  cmd = binpath + "/" + "SimilarityByMotif.pl " + \
    "'" + str(base)        +  "' " + \
    "'" + str(page)        +  "' " + \
    "'" + str(accession)   +  "' " + \
    "'" + str(evalue)      +  "' " + \
    "'" + str(score)       +  "' " + \
    "'" + str(pvalue)      +  "' " + \
    "'" + str(org)         +  "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def GetClones (binpath, request):
  
  flag        = GetRequestParam(request, 'FLAG')
  org         = GetRequestParam(request, 'ORG')
  cmd         = GetRequestParam(request, 'CMD')
  filehandle  = request.form['filename']

  cmd = binpath + "/" + "GetClones.pl " + \
    "'" + str(org)                   + "' " + \
    "'" + str(cmd)                   + "' " + \
    "'" + str(flag)                  + "' " + \
    "'" + str(filehandle.read())     + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def ServerOperation (binpath, request):

  operation   = GetRequestParam(request, 'OPERATION')
  program     = GetRequestParam(request, 'PROGRAM')
  port        = GetRequestParam(request, 'PORT')
  
  cmd = binpath + "/" + "ServerOP.pl  " + \
    "'" + str(operation)                   + "' " + \
    "'" + str(program)                     + "' " + \
    "'" + str(port)                        + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

  ## os.system(cmd)
  ## return 0


######################################################################
def GetBatchGenes (binpath, base, request):
  
  page        = GetRequestParam(request, 'PAGE')
  org         = GetRequestParam(request, 'ORG')
  filedata    = GetRequestParam(request, 'FILEDATA')
  filehandle  = request.form['filename']

  if (filehandle):
    cmd = binpath + "/" + "GetBatchGenes.pl " + \
      "'" + str(base)               + "' " + \
      "'" + str(page)               + "' " + \
      "'" + str(org)                + "' " + \
      "'" + str(filehandle.read())  + "'"
  else:
    cmd = binpath + "/" + "GetBatchGenes.pl " + \
      "'" + str(base)               + "' " + \
      "'" + str(page)               + "' " + \
      "'" + str(org)                + "' " + \
      "'" + str(filedata)           + "'" 

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
def FindGenePage (binpath, base, request):

  org     = GetRequestParam(request, 'ORG')
  bcid    = GetRequestParam(request, 'BCID')
  ecno    = GetRequestParam(request, 'ECNO')
  llno    = GetRequestParam(request, 'LLNO')
  cid     = GetRequestParam(request, 'CID')

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
      "'" + str(id)      +  "' "

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def SummarizedGenes (binpath, cgapcgi, gl_host, gl_port, base, request):

  page   = GetRequestParam(request, 'PAGE')
  org    = GetRequestParam(request, 'ORG')
  scope  = GetRequestParam(request, 'SCOPE')
  title  = GetRequestParam(request, 'TITLE')
  type   = GetRequestParam(request, 'TYPE')
  tissue = GetRequestParam(request, 'TISSUE')
  hist   = GetRequestParam(request, 'HIST')
  prot   = GetRequestParam(request, 'PROT')
  sort   = GetRequestParam(request, 'SORT')

  row    = GetRequestParam(request, 'ROW')
  what   = GetRequestParam(request, 'WHAT')

  cmd = binpath + "/" + "GetPartition.pl " + \
    "'" + str(org)      + "' " + \
    "'" + str(scope)    + "' " + \
    "'" + str(title)    + "' " + \
    "'" + str(type)     + "' " + \
    "'" + str(tissue)   + "' " + \
    "'" + str(hist)     + "' " + \
    "'" + str(prot)     + "' " + \
    "'" + str(sort)     + "'"

  (status, partition) = commands.getstatusoutput(cmd)

  if (status / 256 != int(S_OK)):
    return partition

  genes =  MakeRequest(gl_host, gl_port, 'ListSummarizedGenes(' + \
    "'" + str(row)      + "', " + \
    "'" + str(what)     + "', " + \
    "'" + str(org)      + "', " + \
    "'" + str(scope)    + "', " + \
    "'" + str(title)    + "', " + \
    "'" + str(type)     + "', " + \
    "'" + str(tissue)   + "', " + \
    "'" + str(hist)     + "', " + \
    "'" + str(prot)     + "', " + \
    "'" + str(sort)     + "', " + \
    "'" + str(partition) + "'"  + \
    ')')

  if (GlobalResponseStatus() != S_OK):
    return genes

  ## cmd = binpath + "/" + "FormatGeneList.pl " + \
  ##   "'" + str(base)   +  "' " + \
  ##   "'" + str(page)   +  "' " + \
  ##   "'" + str(org)    +  "' " + \
  ##   "'" + str(genes)  +  "'"

  ## (status, response) = commands.getstatusoutput(cmd)
  ## if (status / 256 == int(S_RESPONSE_FAIL)):
  ##   return 'Internal Error'
  ## else:
  ##   return response
  return BackEnd('',0,cgapcgi,base,'FormatGeneList.pl','',"'PAGE','ORG','GENES'",request,{'PAGE':page,'ORG':org,'GENES':genes})

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
def FindSummary (binpath, gl_host, gl_port, base, request):

  org    = GetRequestParam(request, 'ORG')
  scope  = GetRequestParam(request, 'SCOPE')
  title  = GetRequestParam(request, 'TITLE')
  type   = GetRequestParam(request, 'TYPE')
  tissue = GetRequestParam(request, 'TISSUE')
  hist   = GetRequestParam(request, 'HIST')
  prot   = GetRequestParam(request, 'PROT')
  sort   = GetRequestParam(request, 'SORT')

  cmd = binpath + "/" + "GetPartition.pl " + \
    "'" + str(org)      + "' " + \
    "'" + str(scope)    + "' " + \
    "'" + str(title)    + "' " + \
    "'" + str(type)     + "' " + \
    "'" + str(tissue)   + "' " + \
    "'" + str(hist)     + "' " + \
    "'" + str(prot)     + "' " + \
    "'" + str(sort)     + "'"

  (status, partition) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_NO_DATA)):
    return partition

  return MakeRequest(gl_host, gl_port, 'GetSummaryTable(' + \
    "'" + str(base)     + "', " + \
    "'" + str(org)      + "', " + \
    "'" + str(scope)    + "', " + \
    "'" + str(title)    + "', " + \
    "'" + str(type)     + "', " + \
    "'" + str(tissue)   + "', " + \
    "'" + str(hist)     + "', " + \
    "'" + str(prot)     + "', " + \
    "'" + str(sort)     + "', " + \
    "'" + str(partition) + "'"   + \
    ')')

######################################################################
def FindXProfiledGenes (binpath, cgapcgi, gl_host, gl_port, \
    base, cache, page, org, row, what, request):

  genes = MakeRequest(gl_host, gl_port, 'ListXProfiledGenes(' + \
    "'" + str(base)     + "', " + \
    "'" + str(cache)    + "', " + \
    "'" + str(page)     + "', " + \
    "'" + str(org)      + "', " + \
    "'" + str(row)      + "', " + \
    "'" + str(what)     + "'"   + \
    ')')

  if (GlobalResponseStatus() != S_OK):
    return genes

  ## cmd = binpath + "/" + "FormatGeneList.pl " + \
  ##   "'" + str(base)   +  "' " + \
  ##   "'" + str(page)   +  "' " + \
  ##   "'" + str(org)    +  "' " + \
  ##   "'" + str(genes)  +  "'"

  ## (status, gene_list) = commands.getstatusoutput(cmd)
  ## if (status / 256 == int(S_RESPONSE_FAIL)):
  ##   return 'Internal Error'
  ## else:
  ##   return gene_list
  return BackEnd('',0,cgapcgi,base,'FormatGeneList.pl','',"'PAGE','ORG','GENES'",request,{'PAGE':page,'ORG':org,'GENES':genes})

######################################################################
def FindXProfiledLibraries (binpath, \
    base, page, org, what, form):
  import string

  lib_set = []

  hiddens = ""
  hiddens = hiddens + \
      "<input type=hidden name=ORG value=" + str(org) + ">\n"
  hiddens = hiddens + \
      "<input type=hidden name=WHAT value=" + str(what) + ">\n"

  form_tag = "<form name=xpf action=\"" + base + \
      "/Genes/XProfiledThings\"" + "method=POST>"

  if (what == 'a_libs'):
    for k in form.keys():
      if (k[0:2] == 'A_'):
        lib_set.append(k[2:])
        hiddens = hiddens + \
            "<input type=hidden name=" + k + " value=" + form[k] + ">\n"
  elif (what == 'b_libs'):
    for k in form.keys():
      if (k[0:2] == 'B_'):
        lib_set.append(k[2:])
        hiddens = hiddens + \
            "<input type=hidden name=" + k + " value=" + form[k] + ">\n"
  if (lib_set == ""):
    return "No libraries selected<br>\n"

  header = ""

  xpf_cmd = "javascript:document.xpf.PAGE.value=;document.xpf.submit()"
  cmd = binpath + "/" + "FormatLibraryList.pl " + \
    "'" + str(base)     + "' " + \
    "'" + str(page)     + "' " + \
    "'" + str(org)      + "' " + \
    "'" + str(xpf_cmd)  + "' " + \
    "'" + str(header)   + "' " + \
    "'" + str(string.join(lib_set, ',')) + "'"

  (status, lib_list) = commands.getstatusoutput(cmd)
  if (status / 256 != int(S_OK)):
    return "Query failed<br><br>"
  else:
    if (page != '0'):
      return form_tag + hiddens + lib_list + "</form>"
    else:
      return lib_list

######################################################################
def FindXProfile (host, port, base, org, form):
  import string

  a_set  = []
  b_set  = []
  ab_set = []
  for k in form.keys():
    if (k[0:2] == 'A_'):
      if form.has_key('B_' + k[2:]):
        ab_set.append(k[2:])
      a_set.append(k[2:])
    elif (k[0:2] == 'B_'):
      b_set.append(k[2:])
  if (a_set == [] and b_set == []):
    return "No libraries selected<br>\n"
  elif (len(ab_set) == 1):
    return "One library is included in both A and B; any library must be " + \
        "in at most one set"
  elif (len(ab_set) > 1):
    return str(len(ab_set)) + " libraries are included in both A and B; " +\
        "any library must be in at most one set"
  else:
    return MakeRequest(host, port, 'GetXProfile(' + \
      "'" + str(base)     + "', " + \
      "'" + str(org)      + "', " + \
      "'" + str(string.join(a_set, ','))     + "', " + \
      "'" + str(string.join(b_set, ','))     + "'"   + \
      ')')

######################################################################
def GetHiddensForGXS (request):
  import string
  import re

  lines = []

  lines.append("<input type=hidden name=\"SAVE\">")
  org = request['ORG']
  lines.append("<input type=hidden name=\"ORG\" value=\"" + org  + "\">")
  lines.append("<input type=hidden name=\"PAGE\" value=1>")
  lines.append("<input type=hidden name=\"WHAT\" value='genes'>")
  lines.append(GetHiddensForGXSParam(request, 'SCOPE'))
  lines.append(GetHiddensForGXSParam(request, 'SEQS'))
  lines.append(GetHiddensForGXSParam(request, 'SORT'))
  lines.append(GetHiddensForGXSParam(request, 'TITLE_A'))
  lines.append(GetHiddensForGXSParam(request, 'TYPE_A'))
  lines.append(GetHiddensForGXSParam(request, 'PROT_A'))
  lines.append(GetHiddensForGXSParam(request, 'TISSUE_A'))
  lines.append(GetHiddensForGXSParam(request, 'HIST_A'))
  lines.append(GetHiddensForGXSParam(request, 'COMP_A'))
  lines.append(GetHiddensForGXSParam(request, 'TITLE_B'))
  lines.append(GetHiddensForGXSParam(request, 'TYPE_B'))
  lines.append(GetHiddensForGXSParam(request, 'PROT_B'))
  lines.append(GetHiddensForGXSParam(request, 'TISSUE_B'))
  lines.append(GetHiddensForGXSParam(request, 'HIST_B'))
  lines.append(GetHiddensForGXSParam(request, 'COMP_B'))

  p = request['CMD']
  lines.append("<input type=hidden name=\"CMD\" value=\"" + p + "\">")
  lines.append("<input type=hidden name=\"ASEQS\" value=0>")
  lines.append("<input type=hidden name=\"BSEQS\" value=0>")
  lines.append("<input type=hidden name=\"ALIBS\" value=0>")
  lines.append("<input type=hidden name=\"BLIBS\" value=0>")

  scope = GetRequestParam(request, 'SCOPE')
  seqs = GetRequestParam(request, 'SEQS')
  sort = GetRequestParam(request, 'SORT')
  title_a = GetRequestParam(request, 'TITLE_A')
  type_a = GetRequestParam(request, 'TYPE_A')
  prot_a = GetRequestParam(request, 'PROT_A')
  tissue_a = GetRequestParam(request, 'TISSUE_A')
  hist_a = GetRequestParam(request, 'HIST_A')
  comp_a = GetRequestParam(request, 'COMP_A')
  title_b = GetRequestParam(request, 'TITLE_B')
  type_b = GetRequestParam(request, 'TYPE_B')
  prot_b = GetRequestParam(request, 'PROT_B')
  tissue_b = GetRequestParam(request, 'TISSUE_B')
  hist_b = GetRequestParam(request, 'HIST_B')
  comp_b = GetRequestParam(request, 'COMP_B')

  lists = scope + ',' + seqs + ',' + sort + ',' + title_a + ',' + type_a + ',' + prot_a + ',' + tissue_a + ',' + hist_a + ',' + comp_a + ',' + title_b + ',' + type_b + ',' + prot_b + ',' + tissue_b + ',' + hist_b + ',' + comp_b + ',' + p + ',' + org
  scan = Scan(lists)
 
  if (scan == ""):
    return string.join(lines, "\n")
  else:
    return 'Error in input'

######################################################################
def GetHiddensForGXSParam (request, s):
  import re
  import string
  lines = []
  if request.has_key(s):
    p = request[s]
    matcher = re.compile("^[a-zA-Z0-9-\_\.\+\,]*$")
    if type(p) == type(''):
      if matcher.match(p):
         lines.append("<input type=hidden name=\"" + s + "\" value=\"" + p + "\">")
      else:
         lines.append("<input type=hidden name=\"" + s + "\" value=''>")
    else:
      for i in p:
        if matcher.match(i):
           lines.append("<input type=hidden name=\"" + s + "\" value=\"" + i + "\">")
        else:
           lines.append("<input type=hidden name=\"" + s + "\" value=''>")
  else:  
    lines.append("<input type=hidden name=\"" + s + "\" value=''>")
  return string.join(lines, "\n") 

######################################################################
def FindLibsForXProfiler (binpath, request):
  import string
  import re

  org      = GetRequestParam(request, 'ORG')
  scope    = GetRequestParam(request, 'SCOPE')
  seqs     = GetRequestParam(request, 'SEQS')
  sort     = GetRequestParam(request, 'SORT')
  title_a  = GetRequestParam(request, 'TITLE_A')
  type_a   = GetRequestParam(request, 'TYPE_A')
  prot_a   = GetRequestParam(request, 'PROT_A')
  tissue_a = GetRequestParam(request, 'TISSUE_A')
  hist_a   = GetRequestParam(request, 'HIST_A')
  comp_a   = GetRequestParam(request, 'COMP_A')
  title_b  = GetRequestParam(request, 'TITLE_B')
  type_b   = GetRequestParam(request, 'TYPE_B')
  prot_b   = GetRequestParam(request, 'PROT_B')
  tissue_b = GetRequestParam(request, 'TISSUE_B')
  hist_b   = GetRequestParam(request, 'HIST_B')
  comp_b   = GetRequestParam(request, 'COMP_B')
  what     = GetRequestParam(request, 'WHAT')
  save     = GetRequestParam(request, 'SAVE')

  a_set = []
  b_set = []
  if save == 'yes':
    for k in request.form.keys():
      if (k[0:2] == 'A_'):
        a_set.append(k)
      elif (k[0:2] == 'B_'):
        b_set.append(k)


  cmd = binpath + "/" + "GXSLibrarySelect.pl " + \
    "'" + str(org)      + "' " + \
    "'" + str(scope)    + "' " + \
    "'" + str(seqs)     + "' " + \
    "'" + str(sort)     + "' " + \
    "'" + str(title_a)  + "' " + \
    "'" + str(title_b)  + "' " + \
    "'" + str(type_a)   + "' " + \
    "'" + str(type_b)   + "' " + \
    "'" + str(tissue_a) + "' " + \
    "'" + str(tissue_b) + "' " + \
    "'" + str(hist_a)   + "' " + \
    "'" + str(hist_b)   + "' " + \
    "'" + str(prot_a)   + "' " + \
    "'" + str(prot_b)   + "' " + \
    "'" + str(comp_a)   + "' " + \
    "'" + str(comp_b)   + "'"

  (status, libs) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_NO_DATA)):
    return "There are no libraries matching the query<br><br>"

  lines = []

  table_header = \
    "<table border=1 cellspacing=1 cellpadding=4>" + \
    "<tr bgcolor=\"#666699\" valign=top>" + \
    "<td colspan=2><font color=\"white\"><b>Pool</b></font></td>" + \
    "<td rowspan=2><font color=\"white\"><b>Library Name</b></font></td>" + \
    "<td rowspan=2><font color=\"white\"><b>Sequences</b></font></td>" + \
    "<td rowspan=2><font color=\"white\"><b>Keywords</b></font></td>" + \
    "</tr>" + \
    "<tr bgcolor=\"#666699\" valign=top>" + \
    "<td><font color=\"white\"><b>A</b></font></td>" + \
    "<td><font color=\"white\"><b>B</b></font></td>" + \
    "</tr>\n"

  lines.append("<br><br>");

  lines.append(table_header)

  lib_list = re.split("\001", libs)
  row_num = 0
  for i in lib_list:
    if (row_num % 300 == 0 and row_num > 0):
      lines.append("</table>")
      lines.append(table_header)
    row_num = row_num + 1
    temp = re.split("\002", i)
    if len(temp) != 7:
      return "error: " + string.join(temp, "|")
    (ug_lid, cgap_lid, setA, setB, lib_name, num_seqs, keywords) = temp
    if save == 'yes':
      a_flag = 0
      for a_id in a_set:
        temp_a = "A_" + ug_lid
        if( temp_a == a_id ):
          a_flag = 1
      if a_flag == 1:
        setA = " checked"
      else:
        setA = ""
      b_flag = 0
      for b_id in b_set:
        temp_b = "B_" + ug_lid
        if( temp_b == b_id ):
          b_flag = 1
      if b_flag == 1:
        setB = " checked"
      else:
        setB = "" 
    else:
      if setA == "A":
        setA = " checked"
      if setB == "B":
        setB = " checked"
    lines.append( \
      "<tr>" + \
      "<td><label for=\"A_" + ug_lid + '"' + "></label><input type=checkbox name=A_" + ug_lid + setA + " id=\"A_" + ug_lid + '"' + "></td>" + \
      "<td><label for=\"B_" + ug_lid + '"' + "></label><input type=checkbox name=B_" + ug_lid + setB + " id=\"B_" + ug_lid + '"' + "></td>" + \
      "<td><a href=\"LibInfo?ORG=" + org + \
      "&LID=" + cgap_lid + "\">" + lib_name + "</a></td>" + \
      "<td>" + num_seqs + "</td>" + \
      "<td>" + keywords + "</td>" + \
      "</tr>" )
  lines.append("</table>")
  return string.join(lines, "\n")

######################################################################
def GXSLibsOfCluster (binpath, base, request):
  import string

  org       = GetRequestParam(request, 'ORG')
  cid       = GetRequestParam(request, 'CID')
  what      = GetRequestParam(request, 'WHAT')
  page      = GetRequestParam(request, 'PAGE')

  lset        = []
  hidden_libs = []
  for k in request.form.keys():
    if (what == 'libs_a' and k[0:2] == 'A_'):
      lset.append(k[2:])
      hidden_libs.append("<input type=hidden name=" + k + " value=" + \
        request.form[k] + ">\n")
    elif (what == 'libs_b' and k[0:2] == 'B_'):
      lset.append(k[2:])
      hidden_libs.append("<input type=hidden name=" + k + " value=" + \
        request.form[k] + ">\n")

  hiddens = ""
  hiddens = hiddens + \
      "<input type=hidden name=ORG value=" + str(org) + ">\n"
  hiddens = hiddens + \
      "<input type=hidden name=CID value=" + str(cid) + ">\n"
  hiddens = hiddens + \
      "<input type=hidden name=WHAT value=" + str(what) + ">\n"
  hiddens = hiddens + string.join(hidden_libs, "")

  form_tag = "<form name=xpf action=\"" + base + \
      "/Tissues/GXSResults\"" + "method=POST>"

  header = ""
  if page == "":
    page = "1"

  if (cid == '0'):
    xpf_cmd = "javascript:document.xpf.PAGE.value=;document.xpf.submit()"
    cmd = binpath + "/" + "FormatLibraryList.pl " + \
      "'" + str(base)     + "' " + \
      "'" + str(page)     + "' " + \
      "'" + str(org)      + "' " + \
      "'" + str(xpf_cmd)  + "' " + \
      "'" + str(header)   + "' " + \
      "'" + str(string.join(lset, ',')) + "'"

  else:
    cmd = binpath + "/" + "GXSLibsOfCluster.pl " + \
      "'" + str(base)                   + "' " + \
      "'" + str(org)                    + "' " + \
      "'" + str(cid)                    + "' " + \
      "'" + str(string.join(lset, ",")) + "'"

  (status, lib_list) = commands.getstatusoutput(cmd)
  if (status / 256 != int(S_OK)):
    return "Query failed<br><br>"
  else:
    if (page != '0'):
      return form_tag + hiddens + lib_list + "</form>"
    else:
      return lib_list

######################################################################
## def ComputeGXS (host, port, base, request):
def ComputeGXS (cgapcgi, base, request):

  import string
  import re
  import tempfile

  page      = GetRequestParam(request, 'PAGE')
  factor    = GetRequestParam(request, 'FACTOR')
  cache     = GetRequestParam(request, 'CACHE')
  org       = GetRequestParam(request, 'ORG')
  pvalue    = GetRequestParam(request, 'PVALUE')
  chr       = GetRequestParam(request, 'CHR')
  a_seqs    = GetRequestParam(request, 'ASEQS')
  b_seqs    = GetRequestParam(request, 'BSEQS')
  a_libs    = GetRequestParam(request, 'ALIBS')
  b_libs    = GetRequestParam(request, 'BLIBS')

  if( chr == "" ):
    chr = "All"

  GXS_ROWS_PER_PAGE = 300
  GXS_ROWS_PER_SUBTABLE = 100

  page = int(page)

  a_set = []
  b_set = []
  for k in request.form.keys():
    if (k[0:2] == 'A_'):
      a_set.append(k[2:])
    elif (k[0:2] == 'B_'):
      b_set.append(k[2:])

  tmpfn = tempfile.mktemp()
  tmpf = open(tmpfn, "w")
  tmpf.write(cache                     + "\n")
  tmpf.write(org                       + "\n")
  tmpf.write(str(page)                 + "\n")
  tmpf.write(str(factor)               + "\n")
  tmpf.write(str(pvalue)               + "\n")
  tmpf.write(str(chr)                  + "\n")
  tmpf.write(a_seqs                    + "\n")
  tmpf.write(b_seqs                    + "\n")
  tmpf.write(a_libs                    + "\n")
  tmpf.write(b_libs                    + "\n")
  tmpf.write(string.join(a_set, ",")   + "\n")
  tmpf.write(string.join(b_set, ",")   + "\n")
  tmpf.close()

  ## cmd = binpath + "/" + "ComputeGXS.pl " + tmpfn
  ## (status,response) = commands.getstatusoutput(cmd)
  response = BackEnd('',0,cgapcgi,base,'ComputeGXS.pl','',"'FILE'",request,{'FILE':tmpfn})

#   response = MakeRequest(host, port, 'ComputeGXS(' + \
#     "'" + str(cache)              + "', "   + \
#     "'" + str(org)                + "', "   + \
#     "'" + str(page)               + "', "   + \
#     "'" + str(factor)             + "', "   + \
#     "'" + str(pvalue)             + "', "   + \
#     "'" + str(chr)                + "', "   + \
#     "'" + str(a_seqs)             + "', "   + \
#     "'" + str(b_seqs)             + "', "   + \
#     "'" + str(a_libs)             + "', "   + \
#     "'" + str(b_libs)             + "', "   + \
#     "'" + string.join(a_set, ",") + "', "   + \
#     "'" + string.join(b_set, ",") + "' "   + \
#     ')')

  html_table_header = \
    "<table border=1 cellspacing=1 cellpadding=4>\n" + \
    "<tr bgcolor=\"#666699\" valign=top>\n" + \
    "<td rowspan=2><font color=\"white\"><b>Symbol</b></font></td>\n" + \
    "<td rowspan=2><font color=\"white\"><b>Gene Info</b></font></td>\n" + \
    "<td rowspan=2><font color=\"white\"><b>Accession</b></font></td>\n" + \
    "<td colspan=2 witdh=16%><font color=\"white\"><b>Libraries</b></font></td>\n" + \
    "<td colspan=2 width=16%><font color=\"white\"><b>Sequences</b></font></td>\n" + \
    "<td rowspan=2><font color=\"white\"><b>Seq Odds A:B</b></font></td>\n" + \
    "<td rowspan=2><font color=\"white\"><b>Q</b></font></td>\n" + \
    "</tr>\n" + \
    "<tr bgcolor=\"#666699\" valign=top>\n" + \
    "<td width=8%><font color=\"white\"><b>A</b></font></td>\n" + \
    "<td width=8%><font color=\"white\"><b>B</b></font></td>\n" + \
    "<td width=8%><font color=\"white\"><b>A</b></font></td>\n" + \
    "<td width=8%><font color=\"white\"><b>B</b></font></td>\n" + \
    "</tr>"

  try:
    (cache, ngenes, a_seqs, b_seqs, a_libs, b_libs, table, whole_table) = \
        re.split("\|", response)
  except:
    return "Query failed: " + response

  param_table = \
      "<blockquote><table border=0 cellspacing=1 cellpadding=4>\n" + \
      "<tr>\n" + \
        "<td><b>Total sequences in Pool A:</b></td>" + \
        "<td>" + a_seqs + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td ><b>Total sequences in Pool B:</b></td>" + \
        "<td>" + b_seqs + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>Total libraries in Pool A:</b></td>" + \
        "<td>" + a_libs + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td ><b>Total libraries in Pool B:</b></td>" + \
        "<td>" + b_libs + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>F (expression factor):</b></td>" + \
        "<td>" + factor + "X</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>Q (False discovery rate):</b></td>" + \
        "<td>" + pvalue + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>Chromosome:</b></td>" + \
        "<td>" + chr + "</td>\n" + \
      "</tr>\n" + \
      "<tr>\n" + \
        "<td><b>Enter Chromosome:</b></td>" + \
        "<td>" + "<input type=text name=\"CHR\" id=\"Chromosome\" value=\"" + chr  + "\" size=3 >" + "</td>\n" + \
        "<td>" + "<a href=\"javascript:" + \
          "document.gxs.PAGE.value=1;" + \
          "document.gxs.WHAT.value='genes';" + \
          "document.gxs.submit()\">" + \
          "<b>[Submit]</b></a> &nbsp;&nbsp;&nbsp;" + "</td>\n" + \
      "</tr>\n" + \
      "</table></blockquote\n"

  ngenes = int(ngenes)
  if ngenes == 0:
    if page != 0:
      lines = []
      lines.append("<form name=\"gxs\" action=\"GXSResults\" method=POST>")
      lines.append("<input type=hidden name=\"PAGE\">")
      lines.append("<input type=hidden name=\"WHAT\">")
      lines.append("<input type=hidden name=\"PVALUE\" value=" + pvalue + ">")
      lines.append("<input type=hidden name=\"CID\">")
      lines.append("<input type=hidden name=\"ORG\" value=" + org + ">")
      lines.append("<input type=hidden name=\"FACTOR\" value=" + factor + ">")
      lines.append("<input type=hidden name=\"CACHE\" value=" + cache + ">")
      lines.append("<input type=hidden name=\"ASEQS\" value=" + a_seqs + ">")
      lines.append("<input type=hidden name=\"BSEQS\" value=" + b_seqs + ">")
      lines.append("<input type=hidden name=\"ALIBS\" value=" + a_libs + ">")
      lines.append("<input type=hidden name=\"BLIBS\" value=" + b_libs + ">")
      for k in request.form.keys():
        if (k[0:2] == 'A_' or k[0:2] == 'B_'):
          lines.append("<input type=hidden name=\"" + k + "\" checked>")
    return  string.join(lines, "\n") + param_table + \
        "<p>No tags were found<br></form>"
  if page == 0:
    ## put org prefix so result set can be submitted to clone list generator
    table1 = []
    for i in re.split("\n", table):
      (sym, clu, accs, la, lb, sa, sb, odds, p) = re.split("\t", i)
      clu = org + "." + clu
      table1.append(string.join( \
          (sym, clu, accs, la, lb, sa, sb, odds, p), "\t") + "\n")
    return \
        "Total sequences in Pool A: " + a_seqs + "\n" + \
        "Total sequences in Pool B: " + b_seqs + "\n" + \
        "Total libraries in Pool A: " + a_libs + "\n" + \
        "Total libraries in Pool B: " + b_libs + "\n" + \
        "F (expression factor): " + factor + "X\n" + \
        "Q (False discovery rate): " + pvalue + "\n" + \
        "Symbol\tCluster\tAccession\tLibs: A\tLibs: B\t" + \
        "Seqs: A\tSeqs: B\tSeq Odds A:B\tQ\n" + string.join(table1, "")
  else:
    lines = []
    url = base + "/Genes/RunUniGeneQuery"
    lines.append("<form name=\"geneList\" action=" + url + " method=POST>")
    lines.append("<input type=hidden name=\"PAGE\" value=" + str(page) + ">")
    lines.append("<input type=hidden name=\"ORG\" value=" + org + ">")
    for i in re.split("\n", whole_table):
      (sym, clu, accs, la, lb, sa, sb, odds, p) = re.split("\t", i)
      if (clu != ''):
        if( odds == 'NaN' ):
          lines.append("<input type=hidden name=\"TERM\" value=" + str(clu) + \
                        "_A" + ">")
        elif( float(odds) > 1 ):
          lines.append("<input type=hidden name=\"TERM\" value=" + str(clu) + \
                        "_A" + ">")
        elif( float(odds) < 1 ):
          lines.append("<input type=hidden name=\"TERM\" value=" + str(clu) + \
                        "_B" + ">")
        elif( float(odds) == 1 ):
          lines.append("<input type=hidden name=\"TERM\" value=" + str(clu) + \
                        "_E" + ">")
    lines.append("<br>") 
    lines.append("Get Gene List: &nbsp;&nbsp; ")
    lines.append("<a href=\"javascript:" + \
         "document.geneList.PAGE.value=" + str(page+200000) + ";" + \
         "document.geneList.submit()\">" + \
         "<b>[ A > B ]</b></a>&nbsp;&nbsp; ") 
    lines.append("<a href=\"javascript:" + \
         "document.geneList.PAGE.value=" + str(page+300000) + ";" + \
         "document.geneList.submit()\">" + \
         "<b>[ A < B ]</b></a>&nbsp;&nbsp; ") 
    lines.append("<a href=\"javascript:" + \
         "document.geneList.PAGE.value=" + str(page+400000) + ";" + \
         "document.geneList.submit()\">" + \
         "<b>[ All ]</b></a><br><br>") 
    lines.append("</form>")

    lo = 1 + (page - 1) * GXS_ROWS_PER_PAGE
    hi = lo + GXS_ROWS_PER_PAGE - 1 
    if hi > ngenes:
      hi = ngenes
    npages = ngenes / GXS_ROWS_PER_PAGE
    if ngenes % GXS_ROWS_PER_PAGE > 0:
      npages = int(npages) + 1
    lines.append("<form name=\"gxs\" action=\"GXSResults\" method=POST>")
    lines.append("<input type=hidden name=\"PAGE\">")
    lines.append("<input type=hidden name=\"WHAT\">")
    lines.append("<input type=hidden name=\"PVALUE\" value=" + pvalue + ">")
    lines.append("<input type=hidden name=\"CID\">")
    lines.append("<input type=hidden name=\"ORG\" value=" + org + ">")
    lines.append("<input type=hidden name=\"FACTOR\" value=" + factor + ">")
    lines.append("<input type=hidden name=\"CACHE\" value=" + cache + ">")
    lines.append("<input type=hidden name=\"ASEQS\" value=" + a_seqs + ">")
    lines.append("<input type=hidden name=\"BSEQS\" value=" + b_seqs + ">")
    lines.append("<input type=hidden name=\"ALIBS\" value=" + a_libs + ">")
    lines.append("<input type=hidden name=\"BLIBS\" value=" + b_libs + ">")
    for k in request.form.keys():
      if (k[0:2] == 'A_' or k[0:2] == 'B_'):
        lines.append("<input type=hidden name=\"" + k + "\" checked>")
    lines.append("Displaying " + str(lo) + " thru " + str(hi) + " of " + \
      str(ngenes) + " genes &nbsp;&nbsp;&nbsp;");
    if page < npages:
      lines.append("<a href=\"javascript:" + \
          "document.gxs.PAGE.value=" + str(page+1) + ";" + \
          "document.gxs.WHAT.value='genes';" + \
          "document.gxs.submit()\">" + \
          "Next Page</a> &nbsp;&nbsp;&nbsp;") 
    if page > 1:
      lines.append("<a href=\"javascript:" + \
          "document.gxs.PAGE.value=" + str(page-1) + ";" + \
          "document.gxs.WHAT.value='genes';" + \
          "document.gxs.submit()\">" + \
          "Prev Page</a> &nbsp;&nbsp;&nbsp;") 
    lines.append("<a href=\"javascript:" + \
        "document.gxs.PAGE.value=0;" + \
        "document.gxs.WHAT.value='genes';" + \
        "document.gxs.submit()\">" + \
        "<b>[Full Text]</b></a>") 
    lines.append(param_table)
    lines.append("<p>");
    lines.append(html_table_header)
    j = 0
    for i in re.split("\n", table):
      j = j + 1
      if j > 1 and j % GXS_ROWS_PER_SUBTABLE == 1:
        lines.append("</table>")
        lines.append(html_table_header)
      (sym, clu, accs, la, lb, sa, sb, odds, p) = re.split("\t", i);
      lines.append("<tr>")
      lines.append("<td>" + sym + "</td>")
      lines.append("<td><a href=\"" + base + "/Genes/GeneInfo?" + \
          "ORG=" + org + "&CID=" + clu + "\">Gene Info</a></td>")
      lines.append("<td>" + accs + "</td>")
      if (int(la) > 0):
        lines.append("<td><a href=\"javascript:" + \
            "document.gxs.WHAT.value='libs_a';" + \
            "document.gxs.CID.value=" + clu + ";" + \
            "document.gxs.submit()\">" + \
            la + "</a></td>")
      else:
        lines.append("<td>" + la + "</td>")
      if (int(lb) > 0):
        lines.append("<td><a href=\"javascript:" + \
            "document.gxs.WHAT.value='libs_b';" + \
            "document.gxs.CID.value=" + clu + ";" + \
            "document.gxs.submit()\">" + \
            lb + "</a></td>")
      else:
        lines.append("<td>" + lb + "</td>")
      lines.append("<td>" + sa + "</td>")
      lines.append("<td>" + sb + "</td>")
      lines.append("<td>" + odds + "</td>")
      lines.append("<td nowrap>" + p + "</td>")
      lines.append("</tr>")
    lines.append("</table>")
    lines.append("</form>")

  return string.join(lines, "\n")

######################################################################
def SequenceVerifiedClones (page_string, org, file_home, base, img_dir):
  import re
  import string

  ROWS_PER_PAGE = 300
  if (org == "Hs"):
    fname = "Hs_svc.dat"
  else:
    fname = "Mm_svc.dat"

  page = int(page_string)
  f = open (file_home + fname, "r")
  lines = f.readlines()
  total_rows = len(lines)
  number_of_pages = total_rows/ROWS_PER_PAGE
  if (total_rows % ROWS_PER_PAGE != 0):
    number_of_pages = number_of_pages + 1

  if (page == 0):
    table_header = "IMAGE Id\tSequence ID\tUniGene Cluster\tGene Symbol\n"
  else:

    cmd = \
        "Displaying page " + page_string + " of " + \
        str(number_of_pages) + "<br>\n" + \
        "<form name=pform action=\"" + base + "/Reagents/SeqVerClones\">" + \
        "<a href=\"javascript:document.pform.submit()\">Go to page</a>&nbsp" + \
        "<input type=hidden name=ORG value=" + org + "><select name=PAGE>"
    for p in range(1, number_of_pages + 1):
      cmd = cmd + "<option value=" + str(p) + ">" + str(p) + "</option>"
    cmd = cmd + "</select>&nbsp&nbsp or &nbsp&nbsp"
    cmd = cmd + "<a href=\"" + base + "/Reagents/SeqVerClones?PAGE=0&ORG=" + org + \
        "\">Full Text Listing</a></form>"

    table_header = "<table border=1 cellspacing=1 cellpadding=4>" + \
        "<tr bgcolor=\"#666699\">" + \
        "<td><font color=\"white\"><b>IMAGE Id</b></font></td>" + \
        "<td><font color=\"white\"><b>Sequence ID</b></font></td>" + \
        "<td><font color=\"white\"><b>UniGene Cluster</b></font></td>" + \
        "<td><font color=\"white\"><b>Gene Symbol</b></font></td>" + \
        "<td><font color=\"white\"><b>CGAP Gene Info</b></font></td></tr>\n"

  rows = []
  if (page != 0):
    rows.append(cmd)
  rows.append(table_header)

  if (page == 0):
    lo = 0
    hi = total_rows
  else:
    lo = (page-1)*ROWS_PER_PAGE
    hi = lo + ROWS_PER_PAGE
    if (hi > total_rows):
      hi = total_rows
  for i in range(lo, hi):
    if (page == 0):
      rows.append(lines[i])
    else:
      fields = re.split("\t", lines[i])
      row = "<td>" + fields[0] + "</td>" + \
         "<td><a href=\"http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?" + \
              "db=Nucleotide&CMD=Search&term=" + fields[1] + "\">" + \
              fields[1] + "</a></td>" + \
          "<td>" + fields[2] + "</td>" + \
          "<td>" + fields[3][:-1] + "</td>" + \
          "<td><a href=\"" + base + "/Genes/GeneInfo?" + \
              "ORG=" + org + "&CID=" + fields[2][3:] + \
              "\">Gene Info</a></td></tr>\n"
      rows.append(row)
      if ((i + 1 < hi) and (i + 1 % 100 == 0)):
        rows.append("</table>" + table_header)
  if (page != 0):
    rows.append("</table>")
  return string.join(rows, "")

######################################################################
def FindSeq (host, port, request):

  org    = GetRequestParam(request, 'ORG')
  db     = GetRequestParam(request, 'DB')
  expect = GetRequestParam(request, 'EXPECT')
  show   = GetRequestParam(request, 'SHOW')
  seq    = GetRequestParam(request, 'SEQ')

  return MakeRequest(host, port, 'BlastQuery(' + \
      "'" + str(org)    + "', " + \
      "'" + str(db)     + "', " + \
      "'" + str(expect) + "', " + \
      "'" + str(show)   + "', " + \
      "'" + str(seq)    + "')" )

######################################################################
# Pathway stuff
######################################################################

######################################################################
def FindKeggTerms (binpath, request):

  import string
  import re
  import tempfile

  pattern  = GetRequestParam(request, 'PATTERN')

  tmpfn = tempfile.mktemp()
  tmpf = open(tmpfn, "w")
  tmpf.write(str(pattern) + "\n")
  tmpf.close()

  cmd = binpath + "/" + "GetKeggTerms.pl " + tmpfn

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def ShowKeggCompound (path_host, path_port, base, request):
  cno = GetRequestParam(request, 'CNO')

  return MakeRequest(path_host, path_port, 'GetKeggCompound(' + \
    "'" + str(base) + "', " + \
    "'" + str(cno)  + "'  " + \
    ')')

######################################################################
def ShowBioCartaGenePathways (path_host, path_port, base, request):
  gene = GetRequestParam(request, 'PATH_GENE')

  return MakeRequest(path_host, path_port, 'GetBioCartaPathways(' + \
    "'" + str(base) + "', " + \
    "'" + str(gene) + "'  " + \
    ')')

######################################################################
def ShowPathwayGenes (path_host, path_port, base, request):
  gene = GetRequestParam(request, 'PATH_GENE')

  return MakeRequest(path_host, path_port, 'GetPathwayGenes(' + \
    "'" + str(base) + "', " + \
    "'" + str(gene) + "'  " + \
    ')')

######################################################################
def ShowPathwaysByKeyword (path_host, path_port, base, request):
  key = GetRequestParam(request, 'PATH_KEY')

  return MakeRequest(path_host, path_port, 'GetPathwaysByKeyword(' + \
    "'" + str(base) + "', " + \
    "'" + str(key) + "'  " + \
    ')')

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
def ComputePathway (path_host, path_port, base, request):
  path_from  = GetRequestParam(request, 'PATH_FROM')
  path_to    = GetRequestParam(request, 'PATH_TO')
  path_with  = GetRequestParam(request, 'PATH_WITH')

  return MakeRequest(path_host, path_port, 'ComputePathway(' + \
    "'" + str(base)       + "', " + \
    "'" + str(path_from)  + "', " + \
    "'" + str(path_to)    + "', " + \
    "'" + str(path_with)  + "'  " + \
    ')')

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
def ListBioCartaPathways (binpath, base):

  cmd = binpath + "/" + "ListBioCartaPathways.pl " + \
    "'" + str(base)   + "'"

  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response

######################################################################
def Do_Scan (request):
 
  org    = GetRequestParam(request, 'ORG')
  cid    = GetRequestParam(request, 'CID')
  lists = org + ',' + cid
  return Scan(lists)


######################################################################
def Scan (input):
  import re
  for i in re.split(",", input):
    if(re.search("javascript|<script>|</script>|vbscript|background\:", input, re.I) != None):
      return 'Error 1'
    if(re.search("<a.+</a>|\=|\|\||\s+\|\s+|\-\-|\+\+|\&\&|\*\*.+\*\*|<IMG\s+SRC=|';", input, re.I) != None):
      return 'Error 2'
  return ""


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
