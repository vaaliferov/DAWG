from tqdm import tqdm

def get_idx(sets, id):
    for i in range(len(sets)):
        if id in sets[i]: return i

def add_link(sets, from_id, to_id, type):

    if type not in {7, 21, 23, 27}:

        to_idx = get_idx(sets, to_id)
        from_idx = get_idx(sets, from_id)

        if to_idx == from_idx == None:
            sets.append({from_id, to_id})

        elif to_idx != None and from_idx == None:
            sets[to_idx].add(from_id)

        elif from_idx != None and to_idx == None:
            sets[from_idx].add(to_id)

        elif to_idx != from_idx:
            to = sets[to_idx]
            sets[from_idx].update(to)
            del sets[to_idx]


def get_replaces(links):

    sets, replaces = list(), dict()

    for ln in tqdm(links):
        add_link(sets, ln[1], ln[2], ln[3])

    for ids in tqdm(sets):

        ids = sorted(list(ids))

        replaces.update({
            ids[i]: ids[0] 
            for i in range(1, len(ids))
        })

    return replaces