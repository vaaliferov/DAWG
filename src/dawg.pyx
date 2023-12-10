# distutils: language = c++

cimport _dawg
cimport _iostream
cimport _guide_builder
cimport _dictionary_builder

from _dawg cimport Dawg
from _guide cimport Guide
from _completer cimport Completer
from _dictionary cimport Dictionary
from _dawg_builder cimport DawgBuilder

from _iostream cimport istream, ostream
from _base_types cimport BaseType, CharType
from _iostream cimport ifstream, stringstream

from libcpp.string cimport string


cdef class DAWG:

    cdef unicode sep
    cdef dict replaces
    cdef CharType c_sep
    
    cdef Guide guide
    cdef Dictionary dct
    cdef Completer* completer


    def save(self, path):
        cdef stringstream stream
        self.dct.Write(<ostream*>&stream)
        self.guide.Write(<ostream*>&stream)
        with open(path, 'wb') as f:
           f.write(stream.str())
    
    
    def load(self, path):
        cdef ifstream stream
        path = path.encode()
        stream.open(path, _iostream.binary)
        self.dct.Read(<istream*>&stream)
        self.guide.Read(<istream*>&stream)
        stream.close()


    def build(self, keys):
    
        keys.sort()
        
        cdef Dawg dawg
        cdef DawgBuilder builder
        
        for key in keys:
            b_key = key.encode()
            builder.Insert(b_key, len(b_key), 0)
        
        builder.Finish(&dawg)
        
        _dictionary_builder.Build(dawg, &self.dct)
        _guide_builder.Build(dawg, self.dct, &self.guide)
        
        dawg.Clear()
        

    def __init__(self, sep, replaces, keys=None, path=None):
    
        if keys: self.build(keys)
        elif path: self.load(path)
        
        self.replaces = {
            k.encode(): 
            [(c.encode(), c) for c in v]
            for k, v in replaces.items()
        }
        
        self.completer = new Completer(self.dct, self.guide)
        self.sep, self.c_sep = sep, <unsigned int>ord(sep.encode())


    def __dealloc__(self):
        self.dct.Clear()
        self.guide.Clear()


    cdef list _similar_items(self, unicode cur_prefix, unicode key, BaseType cur_index):
    
        cdef list values = []
        cdef list results = []
        
        cdef bytes b_step, b_char
        cdef BaseType index = cur_index
        cdef BaseType next_index = cur_index
        cdef unicode prefix, u_char, found_key
        
        cdef int end_pos = len(key)
        cdef int word_pos = len(cur_prefix)
        cdef int start_pos = len(cur_prefix)

        while word_pos < end_pos:
            
            b_step = <bytes>(key[word_pos].encode())

            if b_step in self.replaces:
                
                for (b_char, u_char) in self.replaces[b_step]:
                    
                    next_index = index
                    
                    if self.dct.Follow(b_char, &next_index):
                        prefix = cur_prefix + key[start_pos:word_pos] + u_char
                        results.extend(self._similar_items(prefix, key, next_index))

            if not self.dct.Follow(b_step, &index): return results
            
            word_pos += 1

        if self.dct.Follow(self.c_sep, &index):
            
            self.completer.Start(index)
            
            while self.completer.Next():
                values.append(string(self.completer.key()).decode('utf8'))
            
            found_key = cur_prefix + key[start_pos:]
            results.extend([found_key + self.sep + v for v in values])

        return results


    cpdef list similar_items(self, unicode key):
        return self._similar_items('', key, self.dct.root())
