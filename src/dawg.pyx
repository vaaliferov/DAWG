# cython: profile=False
# cython: embedsignature=True

cimport _dawg
cimport _dictionary_builder
cimport _guide_builder
cimport iostream

from _base_types cimport BaseType, CharType, SizeType
from _completer cimport Completer
from _dawg_builder cimport DawgBuilder
from _dictionary cimport Dictionary
from _guide cimport Guide
from iostream cimport ifstream, istream, ostream, stringstream
from libcpp.string cimport string
from libcpp.vector cimport vector

import struct
import sys
from collections.abc import Mapping


class Error(Exception):
    pass


cdef class DAWG:
    """
    Base DAWG wrapper.
    """
    cdef Dictionary dct
    cdef _dawg.Dawg dawg

    def __init__(self, arg=None, input_is_sorted=False):
        if arg is None:
            arg = []
        if not input_is_sorted:
            arg = [
                (<unicode>key).encode('utf8') if isinstance(key, unicode) else key
                for key in arg
            ]
            arg.sort()
        self._build_from_iterable(arg)

    def __dealloc__(self):
        self.dct.Clear()
        self.dawg.Clear()

    def _build_from_iterable(self, iterable):
        cdef DawgBuilder dawg_builder
        cdef bytes b_key
        cdef int value

        for key in iterable:
            if isinstance(key, tuple) or isinstance(key, list):
                key, value = key
                if value < 0:
                    raise ValueError("Negative values are not supported")
            else:
                value = 0

            if isinstance(key, unicode):
                b_key = <bytes>(<unicode>key).encode('utf8')
            else:
                b_key = key

            if not dawg_builder.Insert(b_key, len(b_key), value):
                raise Error("Can't insert key %r (with value %r)" % (b_key, value))

        if not dawg_builder.Finish(&self.dawg):
            raise Error("dawg_builder.Finish error")

        if not _dictionary_builder.Build(self.dawg, &self.dct):
            raise Error("Can't build dictionary")

    def __contains__(self, key):
        if isinstance(key, unicode):
            return self.has_key(<unicode>key)
        return self.b_has_key(key)

    cpdef bint has_key(self, unicode key) except -1:
        return self.b_has_key(<bytes>key.encode('utf8'))

    cpdef bint b_has_key(self, bytes key) except -1:
        return self.dct.Contains(key, len(key))

    cpdef bytes tobytes(self) except +:
        """
        Return raw DAWG content as bytes.
        """
        cdef stringstream stream
        self.dct.Write(<ostream *> &stream)
        cdef bytes res = stream.str()
        return res

    cpdef frombytes(self, bytes data):
        """
        Load DAWG from bytes ``data``.

        FIXME: it seems there is a memory leak here (DAWG uses 3x memory
        when loaded using ``.frombytes`` compared to DAWG loaded
        using ``.load``).
        """
        cdef string s_data = data
        cdef stringstream* stream = new stringstream(s_data)

        try:
            res = self.dct.Read(<istream *> stream)

            if not res:
                self.dct.Clear()
                raise IOError("Invalid data format")

            return self
        finally:
            del stream

    def read(self, f):
        """
        Load DAWG from a file-like object.

        FIXME: this method should'n read the whole stream.
        """
        self.frombytes(f.read())

    def write(self, f):
        """
        Write DAWG to a file-like object.
        """
        f.write(self.tobytes())

    def load(self, path):
        """
        Load DAWG from a file.
        """
        if isinstance(path, unicode):
            path = path.encode(sys.getfilesystemencoding())

        cdef ifstream stream
        stream.open(path, iostream.binary)
        if stream.fail():
            raise IOError("It's not possible to read file stream")

        res = self.dct.Read(<istream*> &stream)

        stream.close()

        if not res:
            self.dct.Clear()
            raise IOError("Invalid data format")

        return self

    def save(self, path):
        """
        Save DAWG to a file.
        """
        with open(path, 'wb') as f:
            self.write(f)

    # pickling support
    def __reduce__(self):
        return self.__class__, tuple(), self.tobytes()

    def __setstate__(self, state):
        self.frombytes(state)

    # half-internal methods
    def _size(self):
        return self.dct.size()

    def _total_size(self):
        return self.dct.total_size()

    def _file_size(self):
        return self.dct.file_size()

    cdef bint _has_value(self, BaseType index):
        return  self.dct.has_value(index)

    cdef list _similar_keys(self, unicode current_prefix, unicode key, BaseType cur_index, dict replace_chars):
        cdef BaseType next_index, index = cur_index
        cdef unicode prefix, u_replace_char, found_key
        cdef bytes b_step, b_replace_char
        cdef list res = []
        cdef list extra_keys

        cdef int start_pos = len(current_prefix)
        cdef int end_pos = len(key)
        cdef int word_pos = start_pos

        while word_pos < end_pos:
            b_step = <bytes>(key[word_pos].encode('utf8'))

            if b_step in replace_chars:
                for (b_replace_char, u_replace_char) in replace_chars[b_step]:
                    next_index = index
                    is_followed = self.dct.Follow(b_replace_char, &next_index)
                    if is_followed:
                        prefix = current_prefix + key[start_pos:word_pos] + u_replace_char
                        extra_keys = self._similar_keys(prefix, key, next_index, replace_chars)
                        res.extend(extra_keys)

            if not self.dct.Follow(b_step, &index):
                break
            word_pos += 1

        else:
            if self._has_value(index):
                found_key = current_prefix + key[start_pos:]
                res.insert(0, found_key)

        return res

    cpdef list similar_keys(self, unicode key, dict replaces):
        """
        Return all variants of ``key`` in this DAWG according to
        ``replaces``.

        ``replaces`` is an object obtained from
        ``DAWG.compile_replaces(mapping)`` where mapping is a dict
        that maps single-char unicode strings to (one or more) single-char
        unicode strings.

        This may be useful e.g. for handling single-character umlauts.
        """
        return self._similar_keys("", key, self.dct.root(), replaces)

    cpdef list prefixes(self, unicode key):
        """
        Return a list with keys of this DAWG that are prefixes of the ``key``.
        """
        return [p.decode('utf8') for p in self.b_prefixes(<bytes>key.encode('utf8'))]

    cpdef list b_prefixes(self, bytes b_key):
        cdef list res = []
        cdef BaseType index = self.dct.root()
        cdef int pos = 1
        cdef CharType ch

        for ch in b_key:
            if not self.dct.Follow(ch, &index):
                break
            if self._has_value(index):
                res.append(b_key[:pos])
            pos += 1

        return res

    def iterprefixes(self, unicode key):
        """
        Return a generator with keys of this DAWG that are prefixes of the ``key``.
        """
        cdef BaseType index = self.dct.root()
        cdef bytes b_key = <bytes>key.encode('utf8')
        cdef int pos = 1
        cdef CharType ch

        for ch in b_key:
            if not self.dct.Follow(ch, &index):
                return
            if self._has_value(index):
                yield b_key[:pos].decode('utf8')
            pos += 1

    @classmethod
    def compile_replaces(cls, replaces):

        for k,v in replaces.items():
            if len(k) != 1:
                raise ValueError("Keys must be single-char unicode strings.")
            if (isinstance(v, str) and len(v) != 1):
                raise ValueError("Values must be single-char unicode strings or non-empty lists of such.")
            if isinstance(v, list) and (any(len(v_entry) != 1 for v_entry in v) or len(v) < 1):
                raise ValueError("Values must be single-char unicode strings or non-empty lists of such.")
        return dict(
            (
                k.encode('utf8'),
                [(v_entry.encode('utf8'), unicode(v_entry)) for v_entry in v]
            )
            for k, v in replaces.items()
        )


cdef void init_completer(Completer& completer, Dictionary& dic, Guide& guide):
    completer.set_dic(dic)
    completer.set_guide(guide)


cdef class CompletionDAWG(DAWG):
    """
    DAWG with key completion support.
    """
    cdef Guide guide

    def __init__(self, arg=None, input_is_sorted=False):
        super(CompletionDAWG, self).__init__(arg, input_is_sorted)
        if not _guide_builder.Build(self.dawg, self.dct, &self.guide):
            raise Error("Error building completion information")

    def __dealloc__(self):
        self.guide.Clear()

    cpdef list keys(self, unicode prefix=""):
        cdef bytes b_prefix = prefix.encode('utf8')
        cdef BaseType index = self.dct.root()
        cdef list res = []

        if not self.dct.Follow(b_prefix, &index):
            return res

        cdef Completer completer
        init_completer(completer, self.dct, self.guide)
        completer.Start(index, b_prefix)

        while completer.Next():
            key = (<char*>completer.key()).decode('utf8')
            res.append(key)

        return res

    def iterkeys(self, unicode prefix=""):
        cdef bytes b_prefix = prefix.encode('utf8')
        cdef BaseType index = self.dct.root()

        if not self.dct.Follow(b_prefix, &index):
            return

        cdef Completer completer
        init_completer(completer, self.dct, self.guide)
        completer.Start(index, b_prefix)

        while completer.Next():
            key = (<char*>completer.key()).decode('utf8')
            yield key

    def has_keys_with_prefix(self, unicode prefix):
        cdef bytes b_prefix = prefix.encode('utf8')
        cdef BaseType index = self.dct.root()

        if not self.dct.Follow(b_prefix, &index):
            return False

        cdef Completer completer
        init_completer(completer, self.dct, self.guide)
        completer.Start(index, b_prefix)

        return completer.Next()

    cpdef bytes tobytes(self) except +:
        """
        Return raw DAWG content as bytes.
        """
        cdef stringstream stream
        self.dct.Write(<ostream *> &stream)
        self.guide.Write(<ostream *> &stream)
        cdef bytes res = stream.str()
        return res

    cpdef frombytes(self, bytes data):
        """
        Load DAWG from bytes ``data``.

        FIXME: it seems there is memory leak here (DAWG uses 3x memory when
        loaded using frombytes vs load).
        """
        cdef char* c_data = data
        cdef stringstream stream
        stream.write(c_data, len(data))
        stream.seekg(0)

        res = self.dct.Read(<istream*> &stream)
        if not res:
            self.dct.Clear()
            raise IOError("Invalid data format: can't load _dawg.Dictionary")

        res = self.guide.Read(<istream*> &stream)
        if not res:
            self.guide.Clear()
            self.dct.Clear()
            raise IOError("Invalid data format: can't load _dawg.Guide")

        return self

    def load(self, path):
        """
        Load DAWG from a file.
        """
        if isinstance(path, unicode):
            path = path.encode(sys.getfilesystemencoding())

        cdef ifstream stream
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
                self.guide.Clear()
                self.dct.Clear()
                raise IOError("Invalid data format: can't load _dawg.Guide")

        finally:
            stream.close()

        return self

    def _transitions(self):
        transitions = set()
        cdef BaseType index, prev_index, completer_index
        cdef char* key

        cdef Completer completer
        init_completer(completer, self.dct, self.guide)
        completer.Start(self.dct.root())

        while completer.Next():
            key = <char*>completer.key()

            index = self.dct.root()

            for i in range(completer.length()):
                prev_index = index
                self.dct.Follow(&(key[i]), 1, &index)
                transitions.add(
                    (prev_index, <unsigned char>key[i], index)
                )

        return sorted(list(transitions))
