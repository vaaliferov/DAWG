import pickle

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