#!/usr/local/bin/python

import re
import string
import tempfile
import commands
from CommonUtilities import *

######################################################################
def GetCategories (binpath):
  cmd = binpath + "/" + "PW_OBO_Browser.pl "
  (status, response) = commands.getstatusoutput(cmd)
  if (status / 256 == int(S_RESPONSE_FAIL)):
    return 'Internal Error'
  else:
    return response
 
######################################################################
def TrimAndType (s):

  pat2 = re.compile('^\[(PR|CM|CX|RN|EC|LL|KG|CA|UP)\](.*)$')
  p  = s
  p  = re.sub("\s+", " ", p)
  p  = re.sub("^\s+", "", p)
  p  = re.sub("\s+$", "", p)
  m2 = re.match(pat2, p)
  if m2 != None:
    p  = string.join([m2.group(1), re.sub("^\s+", "", m2.group(2))], "\t")
  return p
######################################################################
def BatchMolecules (host, port, base, request, \
      db_inst, db_user, db_pass, db_schema, file_a, file_b):

  import urllib

  graphic_type = ""

  
  if request.has_key('what'):
    what=request['what']
  else:
    return "no action specified"

  params = []
  params.append("db_user\t"     + db_user)
  params.append("db_pass\t"     + db_pass)
  params.append("db_inst\t"     + db_inst)
  params.append("db_schema\t"   + db_schema)

  pick = request['pick']

  try:
    data_a = file_a.readlines()
  except:
    pass;
  for d in data_a:
    d  = re.sub("\s+", " ", d)
    d  = re.sub("^\s+", "", d)
    d  = re.sub("\s+$", "", d)
#    params.append("value\t1\tmolecule\t" + d)
    params.append("channel\tA\t" + d)
    if pick == 'molecules':
      params.append("molecule\t" + d)

  try:
    data_b = file_b.readlines()
  except:
    pass;
  for d in data_b:
    d  = re.sub("\s+", " ", d)
    d  = re.sub("^\s+", "", d)
    d  = re.sub("\s+$", "", d)
#    params.append("value\t9\tmolecule\t" + d)
    params.append("channel\tB\t" + d)
    if pick == 'molecules':
      params.append("molecule\t" + d)

#  params.append("color\t1\t0000FF")
#  params.append("color\t9\tFF0000")

  if pick == 'pathways':
    if request.has_key('pathway'):
      p = OneParam('pathway', request['pathway'])
      if p != "":
        params.append(p)

  for name in [ \
    'source_id', \
    'evidence_code', \
    'macro_process' \
  ]:
    if request.has_key(name):
      p = OneParam(name, request[name])
      if p != "":
        params.append(p)

  if request.has_key('degree') and request['degree'] != "0":
    if request.has_key('back'):
      params.append("degree_back\t" + request['degree'])
    if request.has_key('forward'):
      params.append("degree_forward\t" + request['degree'])

  if request.has_key("sublines") and request['sublines'] == 'on':
    params.append("show\tsubtype_line")
  if request.has_key("atomids") and request['atomids'] == 'on':
    params.append("show\tatom_id")
  if request.has_key("collapse_mols") and request['collapse_mols'] == 'on':
    params.append("collapse\tmolecules")
  if request.has_key("collapse_atoms") and request['collapse_atoms'] == 'on':
    params.append("collapse\tprocesses")
  if request.has_key("complex_uses") and request['complex_uses'] == 'on':
    params.append("include\tcomplex_uses")
  if request.has_key("transcription") and request['transcription'] == 'on':
    params.append("include\ttranscription")
  if request.has_key("family_uses") and request['family_uses'] == 'on':
    params.append("include\tfamily_uses")

  if what == 'text':
    if request.has_key('lisp') and request['lisp'] != '':
      text_type = "lisp"
    elif request.has_key('xml') and request['xml'] != '':
      text_type = "xml"
    elif request.has_key('xaml') and request['xaml'] != '':
      text_type = "xaml"
    elif request.has_key('biopax') and request['biopax'] != '':
      text_type = "biopax"
    elif request.has_key('sbml') and request['sbml'] != '':
      text_type = "sbml"
    elif request.has_key('dot') and request['dot'] != '':
      text_type = "dot"
    elif request.has_key('template') and request['template'] != '':
      text_type = "template"
    elif request.has_key('cmd') and request['cmd'] != '':
      text_type = "cmd"
    else:
      return "no type specified for text output 1"

  elif what == 'graphic' or what == 'sim_graphic':
    if request.has_key('jpg') and request['jpg'] != '':
      text_type = "dot"
      graphic_type = "jpg"
    elif request.has_key('gif') and request['gif'] != '':
      text_type = "dot"
      graphic_type = "jpg"
    elif request.has_key('svg') and request['svg'] != '':
      text_type = "dot"
      graphic_type = "svg"
    elif request.has_key('xaml') and request['xaml'] != '':
      text_type = "dot"
      graphic_type = "xaml"

    else:
      return "no type specified for graphic output 1"

  elif what == 'sim_text':
    pass
  elif what == 'params':
    pass

  else:
    return "unrecognized action specified"

  if (what != 'sim_text' and what != 'sim_graphic'):
    params.append("print\t" + text_type)

#  return string.join(params, "\n") + "\n"

  x = MakeRequest(host, port, \
      "PrPath(" + \
          "'" + base         + "'," + \
          "'" + graphic_type + "'," + \
          "'" + urllib.quote(string.join(params, "\n") + "\n") + "')" )

  return PwServerResponse(request, "", "browser", x)




######################################################################
def BatchQ (host, port, base, request, \
      db_inst, db_user, db_pass, db_schema, file_a, file_b):

  import urllib

  graphic_type = ""
  
  if request.has_key('what'):
    what=request['what']
  else:
    return "no action specified"

  params = []
  params.append("db_user\t"     + db_user)
  params.append("db_pass\t"     + db_pass)
  params.append("db_inst\t"     + db_inst)
  params.append("db_schema\t"   + db_schema)

  pick = request['pick']

  try:
    data_a = file_a.readlines()
  except:
    pass;
  for d in data_a:
    d  = re.sub("\s+", " ", d)
    d  = re.sub("^\s+", "", d)
    d  = re.sub("\s+$", "", d)
#    params.append("value\t1\tmolecule\t" + d)
    params.append("channel\tA\t" + d)
    if pick == 'molecules':
      params.append("molecule\t" + d)

  try:
    data_b = file_b.readlines()
  except:
    pass;
  for d in data_b:
    d  = re.sub("\s+", " ", d)
    d  = re.sub("^\s+", "", d)
    d  = re.sub("\s+$", "", d)
#    params.append("value\t9\tmolecule\t" + d)
    params.append("channel\tB\t" + d)
    if pick == 'molecules':
      params.append("molecule\t" + d)

#  params.append("color\t1\t0000FF")
#  params.append("color\t9\tFF0000")

  if pick == 'pathways':
    if request.has_key('pathway'):
      p = OneParam('pathway', request['pathway'])
      if p != "":
        params.append(p)

  for name in [ \
    'source_id', \
    'evidence_code', \
    'macro_process' \
  ]:
    if request.has_key(name):
      p = OneParam(name, request[name])
      if p != "":
        params.append(p)

  if request.has_key('degree') and request['degree'] != "0":
    if request.has_key('back'):
      params.append("degree_back\t" + request['degree'])
    if request.has_key('forward'):
      params.append("degree_forward\t" + request['degree'])

  if request.has_key("sublines") and request['sublines'] == 'on':
    params.append("show\tsubtype_line")
  if request.has_key("atomids") and request['atomids'] == 'on':
    params.append("show\tatom_id")
  if request.has_key("collapse_mols") and request['collapse_mols'] == 'on':
    params.append("collapse\tmolecules")
  if request.has_key("collapse_atoms") and request['collapse_atoms'] == 'on':
    params.append("collapse\tprocesses")
  if request.has_key("complex_uses") and request['complex_uses'] == 'on':
    params.append("include\tcomplex_uses")
  if request.has_key("transcription") and request['transcription'] == 'on':
    params.append("include\ttranscription")
  if request.has_key("family_uses") and request['family_uses'] == 'on':
    params.append("include\tfamily_uses")

  if what == 'text':
    if request.has_key('sql') and request['sql'] != '':
      text_type = "sql"
    elif request.has_key('table') and request['table'] != '':
      text_type = "table"
    elif request.has_key('xml') and request['xml'] != '':
      text_type = "xml"
    elif request.has_key('xaml') and request['xaml'] != '':
      text_type = "xaml"
    elif request.has_key('biopax') and request['biopax'] != '':
      text_type = "biopax"
    elif request.has_key('sbml') and request['sbml'] != '':
      text_type = "sbml"
    elif request.has_key('dot') and request['dot'] != '':
      text_type = "dot"
    elif request.has_key('cmd') and request['cmd'] != '':
      text_type = "cmd"
    else:
      return "no type specified for text output 2"

  elif what == 'graphic' or what == 'sim_graphic':
    if request.has_key('jpg') and request['jpg'] != '':
      text_type = "dot"
      graphic_type = "jpg"
    elif request.has_key('gif') and request['gif'] != '':
      text_type = "dot"
      graphic_type = "jpg"
    elif request.has_key('svg') and request['svg'] != '':
      text_type = "dot"
      graphic_type = "svg"
    elif request.has_key('xaml') and request['xaml'] != '':
      text_type = "dot"
      graphic_type = "xaml"

    else:
      return "no type specified for graphic output 2"

  elif what == 'sim_text':
    pass
  elif what == 'params':
    pass

  else:
    return "unrecognized action specified"

  if (what != 'sim_text' and what != 'sim_graphic'):
    params.append("print\t" + text_type)

#  return string.join(params, "\n") + "\n"

  x = MakeRequest(host, port, \
      "PrBatch(" + \
          "'" + base         + "'," + \
          "'" + graphic_type + "'," + \
          "'" + urllib.quote(string.join(params, "\n") + "\n") + "')" )

  return x

######################################################################
def BatchQ2 (host, port, base, request, \
      db_inst, db_user, db_pass, db_schema, file_a, file_b):

  import re
  import string
  import tempfile
  import urllib
  import commands

  p = []
  path=''
  param=''
  cmd = 'PrPath'

  try:
    data_a = file_a.readlines()
  except:
    pass;
  for d in data_a:
    d  = re.sub("\s+", " ", d)
    d  = re.sub("^\s+", "", d)
    d  = re.sub("\s+$", "", d)
    p.append("channel\tA\t" + d)
    p.append("molecule\t" + d)
  try:
    data_b = file_b.readlines()
  except:
    pass;
  for d in data_b:
    d  = re.sub("\s+", " ", d)
    d  = re.sub("^\s+", "", d)
    d  = re.sub("\s+$", "", d)
    # p.append("channel\tB\t" + d)
    # p.append("molecule\t" + d)

  if host == "" and path != "":
    usesocket = 0
    if re.compile("^http:", re.I).match(path):
      usehttp = 1
      useexec = 0
    else:
      usehttp = 0
      useexec = 1
##    tmpfn = tempfile.mktemp()
##    tmpf = open(tmpfn, "w")
  elif path == "" and host != "":
    usesocket = 1
    useexec   = 0
    usehttp   = 0
  else:
    return "Error: host and path are both specified"

  if usehttp:
    other['BASE'] = base
  elif usesocket:
    p.append("'" + base + "'")
  elif useexec:
    p.append("'" + base + "'")

 
  if useexec:
    (status,response) = commands.getstatusoutput \
        (path + "/" + "PrPath" + " "  + string.join(p, " "))
##    tmpf.close()

  elif usehttp:
    httpcmd = path + "/" + cmd
    f = urllib.urlopen(httpcmd, urllib.urlencode(other))
    response = f.read()

  elif usesocket:
    response = MakeRequest(host, port, "PrPath(" + string.join(p, ", ") + ")" )

  return response

######################################################################
def OneParam (name, value):

  tmp = value
  vals = []

  pat1 = re.compile('^([^"]*)"([^"]+)"(.*)$')
  while (1):
    m1 = re.match(pat1, tmp)
    if m1 == None:
      break
    tmp = m1.group(1) + " " + m1.group(3)
    p  = m1.group(2)
    p  = TrimAndType(p)
    if p != "":
      vals.append(name + "\t" + p)
  if (re.match(".*,", tmp) != None):
    for i in re.split(" ?, ?", re.sub("\s+", " ", tmp)):
      p  = TrimAndType(i)
      if p != "":
        vals.append(name + "\t" + p)
  else:
    p = TrimAndType(tmp)
    if p != "":
      vals.append(name + "\t" + p)
  return string.join(vals, "\n")

######################################################################
def PwServerForFile (host, port, base, request, filehandle, \
      db_inst, db_user, db_pass, db_schema):

  import urllib

  try:
    params = str(filehandle.read())
  except:
    return "File does not exist or cannot be read"

  if params == "":
    return "File is empty or file does not exist"

  params = params + "\n"    ## add, just in case
  params = params + "db_user\t"     + db_user + "\n"
  params = params + "db_pass\t"     + db_pass + "\n"
  params = params + "db_inst\t"     + db_inst + "\n"
  params = params + "db_schema\t"   + db_schema + "\n"

  params = urllib.quote(params)

  if request.has_key('svg'):
    graphic_type = 'svg'
  elif request.has_key('jpg'):
    graphic_type = 'jpg'
  elif request.has_key('xaml'):
    graphic_type = 'xaml'
  else:
    graphic_type = 'text'

  x = MakeRequest(host, port, \
      "PrPath(" + \
          "'" + base         + "'," + \
          "'" + graphic_type + "'," + \
          "'" + params + "')" )

  return PwServerResponse(request, "", "browser", x)


######################################################################
def PwServerForAgent (host, port, base, request, url, graphic_type,
      params, db_inst, db_user, db_pass, db_schema):

  import urllib
  params = params + "\n"    ## add, just in case
  params = params + "db_user\t"     + db_user + "\n"
  params = params + "db_pass\t"     + db_pass + "\n"
  params = params + "db_inst\t"     + db_inst + "\n"
  params = params + "db_schema\t"   + db_schema + "\n"

  params = urllib.quote(params)

  resp = MakeRequest(host, port, \
      "PrPath(" + \
          "'" + base         + "'," + \
          "'" + graphic_type + "'," + \
          "'" + params + "')" )
  return PwServerResponse(request, url, "agent", resp)

######################################################################
def PwServerResponse (request, diagram_url, agent_or_browser, resp):

  ## agent_or_browser : {"agent", "browser"}
  ## resp         : status \001 data_type \001 data
  ## status       : {S_RESPONSE_FAIL, S_BAD_REQUEST, S_NO_DATA, S_OK}
  ## data_type    : {"text", "jpg", "svg", "xaml"}

  try:
    (status, data_type, data, interaction_ids) = re.split("\001", resp)
  except:
    return "PwServerResponse: Internal Failure in PwServerResponse"

  if status   == S_RESPONSE_FAIL:
    return "Application/database failure\n"
  elif status == S_BAD_REQUEST:
    return "Error in request:<p>\n" + data
  elif status == S_NO_DATA:
    return "There is no data matching the request<p>\n" + data
  elif status == S_OK:
    return data


######################################################################
def oldPwServerResponse (request, diagram_url, agent_or_browser, resp):

  ## agent_or_browser : {"agent", "browser"}
  ## resp         : status \001 data_type \001 data
  ## status       : {S_RESPONSE_FAIL, S_BAD_REQUEST, S_NO_DATA, S_OK}
  ## data_type    : {"text", "jpg", "svg", "xaml"}

  try:
    (status, data_type, data, interaction_ids) = re.split("\001", resp)
  except:
    return "PwServerResponse: internal failure"

  if status   == S_RESPONSE_FAIL:
    return "Application/database failure\n";
  elif status == S_BAD_REQUEST:
    return "Error in request:\n" . data
  elif status == S_NO_DATA:
    return "There is no data matching the request\n";
  elif status == S_OK:
    if data_type == "text":
      return data
    else:
      lines = []
#      if agent_or_browser == "browser":
#        lines.append("<form action=\"http://lpgws.nci.nih.gov/perl/pwot\" " + \
#            "target=_blank method=post>");
#        lines.append("<input type=hidden name=atom_id " + \
#            "value=" + interaction_ids + ">");
#        lines.append("<button type=submit>Pathway-o-tron</button><br>");
#        lines.append("</form>");
      gid_array = re.split(",", data)
      num = len(gid_array)
      n = 0
      for gid in gid_array:
        n = n + 1
        if num > 1 and agent_or_browser == "browser":
          lines.append("<p><table><tr bgcolor=yellow><td><b>Subgraph #" + str(n) + "</b></td></tr></table>")
        if data_type == "svg":
          if agent_or_browser == "browser":
            lines.append("<embed type=\"image/svg-xml\" height=800 width=1000 ")
            lines.append("src=\"PathwayGraphic?GID=" + gid + "&FORMAT=SVG\">")
          elif agent_or_browser == "agent":
            lines.append(diagram_url + "PathwayGraphic" + \
                "?GID=" + gid + "&FORMAT=SVG")
        elif data_type == 'jpg':
          if agent_or_browser == "browser":
            lines.append("<img src=\"PathwayGraphic?GID=" + gid + "&FORMAT=JPG\">")
        elif request == "agent":
            lines.append(diagram_url + "PathwayGraphic" + \
                "?GID=" + gid + "&FORMAT=JPG")
      return string.join(lines, "\n") + "\n"


######################################################################
def PwServer (host, port, base, request, \
      db_inst, db_user, db_pass, db_schema):

  import urllib
  graphic_type = ""

  if request.has_key('what'):
    what = request['what']
  else:
    return "no action specified"

  if what == 'text':
    if request.has_key('sql') and request['sql'] != '':
      text_type = "sql"
    elif request.has_key('table') and request['table'] != '':
      text_type = "table"
    elif request.has_key('xml') and request['xml'] != '':
      text_type = "xml"
    elif request.has_key('xaml') and request['xaml'] != '':
      text_type = "xaml"
    elif request.has_key('biopax') and request['biopax'] != '':
      text_type = "biopax"
    elif request.has_key('sbml') and request['sbml'] != '':
      text_type = "sbml"
    elif request.has_key('dot') and request['dot'] != '':
      text_type = "dot"
    elif request.has_key('cmd') and request['cmd'] != '':
      text_type = "cmd"
    else:
      return "no type specified for text output 3"

  elif what == 'graphic' or what == 'sim_graphic':
    if request.has_key('jpg') and request['jpg'] != '':
      text_type = "dot"
      graphic_type = "jpg"
    elif request.has_key('gif') and request['gif'] != '':
      text_type = "dot"
      graphic_type = "jpg"
    elif request.has_key('svg') and request['svg'] != '':
      text_type = "dot"
      graphic_type = "svg"
    elif request.has_key('xaml') and request['xaml'] != '':
      text_type = "dot"
      graphic_type = "xaml"
    else:
      return "no type specified for graphic output 3"

  elif what == 'sim_text':
    pass
  elif what == 'params':
    pass

  else:
    return "unrecognized action specified"

  if request.has_key('evidence_code'):
    p=request['evidence_code']
    if type(p) == type(''):
      q=p
    else:
      q=string.join(p, ",")
      request['evidence_code']=q 

  params = []
  for name in [ \
    'pathway', \
    'molecule', \
    'connect_molecule', \
    'source_id', \
    'pathway_id', \
    'pathway_ext_id', \
    'atom_id', \
    'evidence_code', \
    'prune_atom_id', \
    'macro_process', \
    'mol_name', \
    'mol_id', \
    'mol_ext_id', \
    'connect_mol_name', \
    'connect_mol_id', \
    'connect_mol_ext_id', \
    'prune_mol_name', \
    'prune_mol_id', \
    'prune_mol_ext_id' \
  ]:
 
    if request.has_key(name):
      p = OneParam(name, request[name])
      if p != "":
        params.append(p)

  if request.has_key("sublines") and request['sublines'] == 'on':
    params.append("show\tsubtype_line")
  if request.has_key("atomids") and request['atomids'] == 'on':
    params.append("show\tatom_id")
  if request.has_key("collapse_mols") and request['collapse_mols'] == 'on':
    params.append("collapse\tmolecules")
  if request.has_key("collapse_atoms") and request['collapse_atoms'] == 'on':
    params.append("collapse\tprocesses")
  if request.has_key("complex_uses") and request['complex_uses'] == 'on':
    params.append("include\tcomplex_uses")
  if request.has_key("transcription") and request['transcription'] == 'on':
    params.append("include\ttranscription")
  if request.has_key("family_uses") and request['family_uses'] == 'on':
    params.append("include\tfamily_uses")

  if request.has_key("pathway_name"):
    for p in re.split("[\n\r]", request["pathway_name"]):
      p = re.sub("\r", "", p)
      p = re.sub("\s+,\s+$", "", p)
      if re.match(re.compile("^\s*$"), p) == None:
        params.append("pathway_name\t" + p)

  if what == "sim_text" or what == "sim_graphic":

    if request.has_key('sim_cycle') and \
        request['sim_cycle'] != "0" and \
        request['sim_cycle'] != "":
      params.append("sim_cycle\t" + request['sim_cycle'])

    if request.has_key('sim_simple1') and \
        request['sim_simple1'] != "":
      params.append("sim_simple\t1")

    if request.has_key('sim_compete1') and \
        request['sim_compete1'] != "":
      params.append("sim_compete\t1")

    if request.has_key('sim_mol_id') and \
        request['sim_mol_id'] != "":
      for p in re.split(",", re.sub("\s+", "", request['sim_mol_id'])):
        p1 = re.sub("\(", "\t", p)
        p1 = re.sub("\)", "", p1)
        params.append("sim_mol_id\t" + p1)

    if request.has_key('sim_mean') and \
        request['sim_mean'] != "":
      params.append("sim_method\tmean")
    if request.has_key('sim_min') and \
        request['sim_min'] != "":
      params.append("sim_method\tmin")
    if request.has_key('sim_max') and \
        request['sim_max'] != "":
      params.append("sim_method\tmax")

  if request.has_key('degree') and request['degree'] != "0":
    if request.has_key('back'):
      params.append("degree_back\t" + request['degree'])
    if request.has_key('forward'):
      params.append("degree_forward\t" + request['degree'])

  params.append("db_user\t"   + db_user)
  params.append("db_pass\t"   + db_pass)
  params.append("db_inst\t"   + db_inst)
  params.append("db_schema\t" + db_schema)
  if (what != 'sim_text' and what != 'sim_graphic'):
    params.append("print\t" + text_type)
  elif what == 'sim_text':
    params.append("sim_output\ttext")
  elif what == 'sim_graphic':
    params.append("sim_output\t" + graphic_type)

##
## NOTE: we are encoding the parameter string (it could contain anything
## and it's gonna have to look like a Perl string literal on the server end)
##
  if what == 'text' and text_type == 'cmd':
    return MakeRequest(host, port, \
        "MakeCommandFile(" + \
            "'" + base         + "'," + \
            "'" + graphic_type + "'," + \
            "'" + urllib.quote(string.join(params, "\n") + "\n") + "')" )

  x = MakeRequest(host, port, \
      "PrPath(" + \
          "'" + base         + "'," + \
          "'" + graphic_type + "'," + \
          "'" + urllib.quote(string.join(params, "\n") + "\n") + "')" )

  return PwServerResponse(request, "", "browser", x)


######################################################################
def IsNumber (gid):
  if re.match(re.compile("^\d+$"), gid) == None :
    return 0
  else:
    return 1

######################################################################
def GetPwImage (dir, gid):
  try:
    fn = dir + "/" + "PW." + gid
    imgf = open(fn, "r")
    img = imgf.read()
    imgf.close()
#    return "Content-type: text/plain\n\n" + img
    return img
  except:
    print "Can't open " + fn
    return "Can't open " + fn

######################################################################
def PredefinedPathway (dir, pid, format):
  
  import re

  matchobj = re.search("%3C|%3E|javascript|script|vbscript|%|<|>", format)
  if matchobj:
    return "Matched Bad String"

  if format == 'svg':
    return \
        "<embed type=\"image/svg-xml\" height=800 width=1000 " + \
        "src=\"PredefinedGraphic?fn=" + pid + ".svg&format=svg\">"
  elif format == 'jpg':
    lines = []
    lines.append("<img src=\"PredefinedGraphic?fn=" + pid + ".jpg&" + \
        "format=jpg\" usemap=#map_" + pid + ">")
    lines.append("<map name=map_" + pid + ">")
    lines.append(PredefinedFile(dir, pid + ".map"))
    lines.append("</map>")
    return string.join(lines, "\n")
  elif format == 'xml':
    return PredefinedFile('/share/content/PID/data/predefined', pid + '.xml')
  elif format == 'biopax':
    return PredefinedFile('/share/content/PID/data/predefined', pid + '.bpx')
  elif format == 'xaml':
    return PredefinedFile('/share/content/PID/data/predefined', pid + '.xaml')

######################################################################
def CachePathway (dir, pid, format):

  import re

  matchobj = re.search("%3C|%3E|javascript|script|vbscript|%|<|>", format)
  if matchobj:
    return "Matched Bad String"

  if format == 'svg':
    return \
        "<embed type=\"image/svg-xml\" height=800 width=1000 " + \
        "src=\"CacheGraphic?fn=" + pid + ".svg&format=svg\">"
  elif format == 'jpg':
    lines = []
    lines.append("<img src=\"CacheGraphic?fn=" + pid + ".jpg&" + \
        "format=jpg\" usemap=#map_" + pid + ">")
    lines.append("<map name=map_" + pid + ">")
    lines.append(CacheFile(dir, pid + ".map"))
    lines.append("</map>")
    return string.join(lines, "\n")
  elif format == 'xml':
    return CacheFile('/share/content/PID/data/cache', pid + '.xml')
  elif request.has_key('xaml') and request['xaml'] != '':
      text_type = "xaml"
  elif format == 'biopax':
    return CacheFile('/share/content/PID/data/cache', pid + '.bpx')
  elif format == 'xaml':
    return CacheFile('/share/content/PID/data/predefined', pid + '.xaml')

######################################################################
def PredefinedFile (dir, fn):
  
  import re
  subdir="/nature"
  matchobj = re.search("%3C|%3E|javascript|script|vbscript|%|<|>", fn)
  if matchobj:
    return "Matched Bad String"

  pid=fn[0:1]
  if pid=='1':
    subdir="/biocarta"
  elif pid=='5':
    subdir="/reactome"
  try:
    fn = dir + subdir +  "/" + fn
    f = open(fn, "r")
    data = f.read()
    f.close()
    return data
  except:
    print "Can't open " + subdir
    return "Can't open " + fn
##################################################################
def CacheFile (dir, fn):

  import re
  matchobj = re.search("%3C|%3E|javascript|script|vbscript|%|<|>", fn)
  if matchobj:
    return "Matched Bad String"

  try:
    fn = dir + subdir +  "/" + fn
    f = open(fn, "r")
    data = f.read()
    f.close()
    return data
  except:
    print "Can't open " + subdir
    return "Can't open " + fn
###################################################################
def returnLocation(dir,fn):

  import re
  import string
  subdir="/nature"
  matchobj = re.search("%3C|%3E|javascript|script|vbscript|%|<|>", fn)
  if matchobj:
    return "Matched Bad String"

  pid=0
  if pid=='1':
    subdir="/biocarta"
  elif pid=='5':
    subdir="/reactome"
 
  data = ''
 
  try:
    fn = dir + subdir +  "/" + fn + ".xaml"
    f = open(fn, "r")
    for line in open(fn,"r").readlines():
        s = line.find('Location')
        if s==0:
          newdata = line.split('=')
          s2 = newdata[1].find('""')
          if s2 == -1:
            data2 = newdata[1].replace("\"","") 
            data2 = data2.replace("\n","") 
            data = data + ":" + data2 
    return data
  except:
    print "Can't open " + subdir
    return "Can't open " + fn
 
###################################################################
def BatchQ3 (host, port, base, request, \
      db_inst, db_user, db_pass, db_schema, file_a, file_b):

  import urllib

  graphic_type = ""

  if request.has_key('what'):
    what=request['what']
  else:
    return "no action specified"

  params = []
  params.append("db_user\t"     + db_user)
  params.append("db_pass\t"     + db_pass)
  params.append("db_inst\t"     + db_inst)
  params.append("db_schema\t"   + db_schema)

  pick = request['pick']

  try:
    data_a = file_a.readlines()
  except:
    pass;
  for d in data_a:
    d  = re.sub("\s+", " ", d)
    d  = re.sub("^\s+", "", d)
    d  = re.sub("\s+$", "", d)
#    params.append("value\t1\tmolecule\t" + d)
    params.append("channel\tA\t" + d)
    if pick == 'molecules':
      params.append("molecule\t" + d)

  try:
    data_b = file_b.readlines()
  except:
    pass;
  for d in data_b:
    d  = re.sub("\s+", " ", d)
    d  = re.sub("^\s+", "", d)
    d  = re.sub("\s+$", "", d)
#    params.append("value\t9\tmolecule\t" + d)
    params.append("channel\tB\t" + d)
    if pick == 'molecules':
      params.append("molecule\t" + d)

#  params.append("color\t1\t0000FF")
#  params.append("color\t9\tFF0000")

  if pick == 'pathways':
    if request.has_key('pathway'):
      p = OneParam('pathway', request['pathway'])
      if p != "":
        params.append(p)

  for name in [ \
    'source_id', \
    'evidence_code', \
    'macro_process' \
  ]:
    if request.has_key(name):
      p = OneParam(name, request[name])
      if p != "":
        params.append(p)

  if request.has_key('degree') and request['degree'] != "0":
    if request.has_key('back'):
      params.append("degree_back\t" + request['degree'])
    if request.has_key('forward'):
      params.append("degree_forward\t" + request['degree'])

  if request.has_key("sublines") and request['sublines'] == 'on':
    params.append("show\tsubtype_line")
  if request.has_key("atomids") and request['atomids'] == 'on':
    params.append("show\tatom_id")
  if request.has_key("collapse_mols") and request['collapse_mols'] == 'on':
    params.append("collapse\tmolecules")
  if request.has_key("collapse_atoms") and request['collapse_atoms'] == 'on':
    params.append("collapse\tprocesses")
  if request.has_key("complex_uses") and request['complex_uses'] == 'on':
    params.append("include\tcomplex_uses")
  if request.has_key("transcription") and request['transcription'] == 'on':
    params.append("include\ttranscription")
  if request.has_key("family_uses") and request['family_uses'] == 'on':
    params.append("include\tfamily_uses")

  if what == 'text':
    if request.has_key('lisp') and request['lisp'] != '':
      text_type = "lisp"
    elif request.has_key('xml') and request['xml'] != '':
      text_type = "xml"
    elif request.has_key('xaml') and request['xaml'] != '':
      text_type = "xaml"
    elif request.has_key('biopax') and request['biopax'] != '':
      text_type = "biopax"
    elif request.has_key('sbml') and request['sbml'] != '':
      text_type = "sbml"
    elif request.has_key('dot') and request['dot'] != '':
      text_type = "dot"
    elif request.has_key('template') and request['template'] != '':
      text_type = "template"
    elif request.has_key('cmd') and request['cmd'] != '':
      text_type = "cmd"
    else:
      return "no type specified for text output 4"

  elif what == 'graphic' or what == 'sim_graphic':
    if request.has_key('jpg') and request['jpg'] != '':
      text_type = "dot"
      graphic_type = "jpg"
    elif request.has_key('gif') and request['gif'] != '':
      text_type = "dot"
      graphic_type = "jpg"
    elif request.has_key('svg') and request['svg'] != '':
      text_type = "dot"
      graphic_type = "svg"
    elif request.has_key('xaml') and request['xaml'] != '':
      text_type = "dot"
      graphic_type = "xaml"

    else:
      return "no type specified for graphic output 4"

  elif what == 'sim_text':
    pass
  elif what == 'params':
    pass

  else:
    return "unrecognized action " + what + " specified"

  if (what != 'sim_text' and what != 'sim_graphic'):
    params.append("print\t" + text_type)


#  return string.join(params, "\n") + "\n"

  x = MakeRequest(host, port, \
      "PrPath(" + \
          "'" + base         + "'," + \
          "'" + graphic_type + "'," + \
          "'" + urllib.quote(string.join(params, "\n") + "\n") + "')" )

  return PwServerResponse(request, "", "browser", x)

