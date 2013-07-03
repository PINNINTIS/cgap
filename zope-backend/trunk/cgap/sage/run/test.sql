select unique i.sage_library_id, k1.keyword, k2.keyword, i.tags
from sagelibinfo i, sagekeywords k1, sagekeywords k2, sagekeywords k3
where i.quality = 1
and i.tags >= 20000
and i.organism = 'Mm'
and i.method in ('SS10','LS10')
and k1.sage_library_id = i.sage_library_id
and k1.keyword in ('brain')
and k2.sage_library_id = i.sage_library_id
and k2.keyword in ('ts17')
and k3.sage_library_id = i.sage_library_id
and k3.keyword in ('atlas');
