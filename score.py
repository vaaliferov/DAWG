# VERB,PRTF,PRTS,GRND -> INFN
# ADJS,COMP,ADVB -> ADJF sing masc nomn
# NOUN -> NOUN sing masc/femn/neut nomn

def get_score(tag):

    score = 0

    scores = {
        ('NOUN','INFN','ADJF'): 10,
        ('masc','sing','nomn'):  2,
        ('Qual','femn','impf'):  1,
        ('V-ie','V-be','V-sh'): -1,
        ('Supr','Infr','Erro'): -1,
        ('Slng','Litr','Dist'): -1,
    }

    for k, v in scores.items():
        score += sum([v for t in k if t in tag])

    return score