"""

A CSL lexer for Pygments

How to install (in developer mode): sudo python setup.py develop

"""
from setuptools import setup

setup(
	name = 'CoralLexers',
    version = '0.8',
    description = __doc__,
    author = "Thiago Bastos",
    install_requires=['pygments'],
    packages = ['CoralLexers'],
    entry_points = '''
	[pygments.lexers]
	CSLLexer = CoralLexers:CSLLexer
    TerminalLexer = CoralLexers:TerminalLexer
	'''
) 
