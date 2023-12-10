#! /usr/bin/env python

import glob

from Cython.Build import cythonize
from setuptools import Extension, setup

extensions = [
    Extension(
        "dawg",
        sources=glob.glob("src/*.pyx"),
        include_dirs=["lib"],
        define_macros=[],
        language="c++",
    )
]

ext_modules = cythonize(
    extensions,
    annotate=False,
    compiler_directives={"language_level": 3},
)

setup(
    name="DAWG2",
    version="0.12.1",
    ext_modules=ext_modules,
)
