from lxml import etree

def parse_link(elem):
    values = elem.attrib.values()
    return tuple(map(int, values))

def parse_type(elem):
    return (elem.attrib['id'], elem.text)

def parse_grammeme(elem):
    return (elem.find('name').text, 
            elem.find('alias').text, 
            elem.attrib.get('parent'), 
            elem.find('description').text)

def parse_lemma(elem):

    forms = []
    for f in elem.getchildren():
        gs = [g.attrib['v'] for g in f.getchildren()]
        forms.append((f.attrib['t'], ','.join(gs)))
    
    id, tag = int(elem.attrib['id']), forms[0][1]
    return [(id, tag) + form for form in forms[1:]]


def parse_dict(path):

    types, links = [], []
    lemmas, grammemes = [], []
    items = etree.iterparse(path)

    for ev, elem in items:

        if elem.tag == 'lemma':
            lm = parse_lemma(elem)
            lemmas.append(lm)
            elem.clear()

        elif elem.tag == 'link':
            ln = parse_link(elem)
            links.append(ln)
            elem.clear()

        elif elem.tag == 'type':
            lt = parse_type(elem)
            types.append(lt)
            elem.clear()

        elif elem.tag == 'grammeme':
            gr = parse_grammeme(elem)
            grammemes.append(gr)
            elem.clear()

    tp_cols = ['id','type']
    ln_cols = ['id','from','to','type']
    lm_cols = ['id','tag','word','form']
    gr_cols = ['name','alias','parent','description']

    lemmas = [lemma for sub in lemmas for lemma in sub]

    cols = {'types': tp_cols, 'links': ln_cols,
            'lemmas': lm_cols, 'grammemes': gr_cols}

    data = {'types': types, 'links': links,
            'lemmas': lemmas, 'grammemes': grammemes}

    return data, cols


def parse_annot(path):

    lemma_counts = dict()
    items = etree.iterparse(path)

    for ev, elem in items:
        if elem.tag == 'l':
            lemma_id = int(elem.attrib['id'])
            if lemma_id not in lemma_counts:
                lemma_counts[lemma_id] = 0
            lemma_counts[lemma_id] += 1
            elem.clear()

    return lemma_counts