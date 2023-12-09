
import dawg

words = ['test', 'girl', 'testing', 'girls', 'ёжик', 'ежик', 'ежика']

d = dawg.CompletionDAWG(words)

print(d.prefixes('testing'))

replaces = dawg.DAWG.compile_replaces({'е': 'ё'})

print(d.similar_keys('ежик', replaces))

# print(dawg.BytesDAWG)
