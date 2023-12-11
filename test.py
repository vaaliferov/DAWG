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
dwg.save('words.dawg')

params = {
    'sep': ',',
    'path': 'words.dawg',
    'replaces': {'е':'ё'}
}

dwg = dawg.DAWG(**params)
print(dwg.similar_items('ежик'))
