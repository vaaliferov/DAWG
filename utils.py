import pickle

def lcs(a):

    ss = ''

    if len(a) == 0: return ''
    if len(a) == 1: return a[0]
    if len(a[0]) == 0: return ''

    c = lambda s: all(s in x for x in a)

    for i in range(len(a[0])):
        for j in range(len(a[0])-i+1):
            if j > len(ss) and c(a[0][i:i+j]):
                ss = a[0][i:i+j]

    return ss

def load_lines(path):
    with open(path) as fd:
        return fd.read().splitlines()

def dump_lines(lines, path):
    with open(path, 'w') as fd:
        fd.write('\n'.join(lines)+'\n')

def load_pickle(path):
    with open(path, 'rb') as fd:
        return pickle.load(fd)

def dump_pickle(obj, path):
    with open(path, 'wb') as fd:
        proto = pickle.HIGHEST_PROTOCOL
        pickle.dump(obj, fd, protocol=proto)