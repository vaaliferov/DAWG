# distutils: language = c++

import sys

cimport iostream

cimport _dawg
cimport _guide_builder
cimport _dictionary_builder

from _dawg cimport Dawg
from _guide cimport Guide
from _completer cimport Completer
from _dictionary cimport Dictionary
from _dawg_builder cimport DawgBuilder

from iostream cimport istream
from iostream cimport ostream
from iostream cimport ifstream
# from iostream cimport ofstream
from iostream cimport stringstream

from _base_types cimport BaseType
from _base_types cimport CharType
from _base_types cimport SizeType

from libcpp.string cimport string


cdef class DAWG:


    cdef Dawg dawg
    cdef Guide guide
    cdef Dictionary dct
    cdef Completer* completer
    
    cdef unicode sep
    cdef CharType c_sep
    
    
    def _size(self):
        return self.dct.size()

    def _total_size(self):
        return self.dct.total_size()

    def _file_size(self):
        return self.dct.file_size()
    
    
    def save(self, path):
        
        cdef stringstream stream
        self.dct.Write(<ostream*>&stream)
        self.guide.Write(<ostream*>&stream)
        
        with open(path, 'wb') as f:
           f.write(stream.str())
    
    
    def load(self, path):
    
        cdef ifstream stream
        
        path = path.encode(sys.getfilesystemencoding())
        stream.open(path, iostream.binary)
            
        if stream.fail():
            raise IOError("It's not possible to read file stream")
            
        try:
            res = self.dct.Read(<istream*> &stream)
            if not res:
                self.dct.Clear()
                raise IOError("Invalid data format: can't load _dawg.Dictionary")

            res = self.guide.Read(<istream*> &stream)
            if not res:
                self.dct.Clear()
                self.guide.Clear()
                raise IOError("Invalid data format: can't load _dawg.Guide")

        finally:
            stream.close()


    def build(self, keys):
    
        keys.sort()
    
        cdef DawgBuilder builder
        
        for key in keys:
            b_key = key.encode()
            builder.Insert(b_key, len(b_key), 0)
        
        builder.Finish(&self.dawg)
        
        _dictionary_builder.Build(self.dawg, &self.dct)
        _guide_builder.Build(self.dawg, self.dct, &self.guide)
        

    def __init__(self, path=None, keys=None, sep=' '):
    
        if keys: self.build(keys)
        elif path: self.load(path)
        
        self.completer = new Completer(self.dct, self.guide)
        self.sep, self.c_sep = sep, <unsigned int>ord(sep.encode())


    def __dealloc__(self):
        self.dct.Clear()
        self.dawg.Clear()
        self.guide.Clear()


    @staticmethod
    def compile_replaces(replaces):
        
        return dict(
            (
                k.encode(), 
                [(c.encode(), unicode(c)) for c in v]
            )
            for k, v in replaces.items()
        )


    cdef list _similar_keys(self, unicode current_prefix, unicode key, BaseType cur_index, dict replaces):
        
        cdef BaseType next_index, index = cur_index
        cdef unicode prefix, u_replace_char, found_key
        cdef bytes b_step, b_replace_char
        cdef list res = []
        cdef list extra_keys
        
        cdef list values = []

        cdef int start_pos = len(current_prefix)
        cdef int end_pos = len(key)
        cdef int word_pos = start_pos

        while word_pos < end_pos:
            
            b_step = <bytes>(key[word_pos].encode('utf8'))

            if b_step in replaces:
                
                for (b_replace_char, u_replace_char) in replaces[b_step]:
                    
                    next_index = index
                    
                    if self.dct.Follow(b_replace_char, &next_index):
                        prefix = current_prefix + key[start_pos:word_pos] + u_replace_char
                        extra_keys = self._similar_keys(prefix, key, next_index, replaces)
                        res.extend(extra_keys)

            if not self.dct.Follow(b_step, &index): return res
            
            word_pos += 1

        if self.dct.Follow(self.c_sep, &index):
            
            self.completer.Start(index)
            
            while self.completer.Next():
                values.append(string(self.completer.key()).decode('utf8'))
            
            found_key = current_prefix + key[start_pos:]
            res.extend([found_key + self.sep + v for v in values])

        return res


    cpdef list similar_keys(self, unicode key, dict replaces):
        return self._similar_keys("", key, self.dct.root(), replaces)



# https://stackoverflow.com/questions/30984078/cython-working-with-c-streams
