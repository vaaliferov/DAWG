import dawg

words = [
    'ёжик', 
    'ежик', 
    'ёжик@1,2,3,4', 
    'ежик@2,3,4,5', 
    'ежик@3,4,5,6',
    'ежика@3,4,5,6',
    'ежик_3,4,5,6'
]

words_dawg = dawg.DAWG(keys=words, sep='@')
replaces = dawg.DAWG.compile_replaces({'е':'ё'})
print(words_dawg.similar_keys('ежик', replaces))

words_dawg.save('words.dawg')

words_dawg = dawg.DAWG(path='words.dawg', sep='@')
replaces = dawg.DAWG.compile_replaces({'е':'ё'})
print(words_dawg.similar_keys('ежик', replaces))

print(words_dawg._size())
print(words_dawg._file_size())
print(words_dawg._total_size())
