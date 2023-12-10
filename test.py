import dawg

words = [
    'ёжик', 
    'ежик', 
    'ёжик@1,2,3,4', 
    'ежик@2,3,4,5', 
    'ежик@3,4,5,6'
]

words_dawg = dawg.DAWG(words, sep='@')
replaces = dawg.DAWG.compile_replaces({'е':'ё'})
print(words_dawg.similar_keys('ежик', replaces))
