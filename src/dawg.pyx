cimport _dawg
cimport _guide_builder
cimport _dictionary_builder

from _dawg cimport Dawg
from _guide cimport Guide
from _completer cimport Completer
from _dictionary cimport Dictionary
from _dawg_builder cimport DawgBuilder

from _base_types cimport BaseType
from _base_types cimport CharType
from _base_types cimport SizeType

from libcpp.string cimport string


cdef class DAWG:

    cdef Dawg dawg
    cdef Guide guide
    cdef Dictionary dct
    cdef Completer* completer
    
    cdef unicode _sep
    cdef CharType _c_sep

    def __init__(self, keys=[], sep=' '):
    
        cdef bytes b_key
        cdef DawgBuilder dawg_builder
        
        keys.sort()
        
        for key in keys:
            b_key = <bytes>(<unicode>key).encode('utf8')
            dawg_builder.Insert(b_key, len(b_key), <int>0)
        
        dawg_builder.Finish(&self.dawg)
        
        _dictionary_builder.Build(self.dawg, &self.dct)
        _guide_builder.Build(self.dawg, self.dct, &self.guide)
        
        self.completer = new Completer(self.dct, self.guide)
        
        # self._c_sep  = <unsigned int>ord(b'\x20') # space
        self._sep, self._c_sep = sep, <unsigned int>ord(sep.encode('utf8'))

    def __dealloc__(self):
        self.dct.Clear()
        self.dawg.Clear()
        self.guide.Clear()

    @classmethod
    def compile_replaces(cls, replaces):
        
        return dict(
            (
                k.encode('utf8'), 
                [(c.encode('utf8'), unicode(c)) for c in v]
            )
            for k, v in replaces.items()
        )

    cdef list _values_for_index(self, BaseType index):
    
        cdef list results = []

        self.completer.Start(index)

        while self.completer.Next():
            key = string(self.completer.key())
            results.append(key.decode('utf8'))

        return results


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

        if self.dct.Follow(self._c_sep, &index):
            
            self.completer.Start(index)
            
            while self.completer.Next():
                values.append(string(self.completer.key()).decode('utf8'))
            
            found_key = current_prefix + key[start_pos:]
            res.extend([found_key + self._sep + v for v in values])

        return res


    cpdef list similar_keys(self, unicode key, dict replaces):
        return self._similar_keys("", key, self.dct.root(), replaces)
