import dawg

words = [
    'ёжик',
    'ежик',
    'ежик_3,4,5,6',
    'ёжик@1,2,3,4',
    'ежик@2,3,4,5',
    'ежик@3,4,5,6',
    'ежика@3,4,5,6'
]

params = {
    'sep': '@',
    'keys': words,
    'replaces': {'е':'ё'}
}

dwg = dawg.DAWG(**params)
print(dwg.similar_items('ежик'))
print(dwg.similar_items('ёжик'))

def unpack(item):
    key, value = item.split('@')
    return list(map(int, value.split(',')))

# for _ in range(400000):
    # results = dwg.similar_items('ежик')
    # [unpack(item) for item in results]

dwg.save('words.dawg')

params = {
    'sep': '@',
    'path': 'words.dawg',
    'replaces': {'е':'ё'}
}

dwg = dawg.DAWG(**params)
print(dwg.similar_items('ежик'))
print(dwg.similar_items('ёжик'))
