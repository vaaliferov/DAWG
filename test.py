import dawg

words = [
    'ёжик',
    'ёжик,111,222,333,444',
    'ежик,222,333,444,555',
    'ежик,333,444,555,666',
    'ежика,333,444,555,666'
]

params = {
    'sep': ',',
    'keys': words,
    'replaces': {'е':'ё'}
}

dwg = dawg.DAWG(**params)
print(dwg.similar_items('ежик'))
print(dwg.similar_items('ёжик'))

def unpack(item):
    return list(map(int, item.split(',')[1:]))

import time
start_time = time.time()

for _ in range(400000):
    results = dwg.similar_items('ежик')
    results = list(map(unpack, results))
    # words[results[0][0]]

print("--- %s seconds ---" % (time.time() - start_time))

dwg.save('words.dawg')

params = {
    'sep': ',',
    'path': 'words.dawg',
    'replaces': {'е':'ё'}
}

dwg = dawg.DAWG(**params)
print(dwg.similar_items('ежик'))
print(dwg.similar_items('ёжик'))
