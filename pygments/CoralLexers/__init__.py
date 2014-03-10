# -*- coding: utf-8 -*-
"""
Coral Lexers for Pygments
~~~~~~~~~~~~~~~~~~~~~~~~~
"""

import re
from pygments.lexer import RegexLexer, bygroups, include, using, this
from pygments.lexers.compiled import CppLexer
from pygments.token import *

__all__ = ['CSLLexer', 'TerminalLexer']

class CSLLexer(RegexLexer):
    name = 'CSL'
    aliases = ['csl']
    filenames = ['*.csl', ]
    mimetypes = ['text/csl']

    id = r'[a-zA-Z][a-zA-Z0-9_]*'
    fullid = r'(?:' + id + r'|\.)+'

    flags = re.MULTILINE | re.DOTALL

    tokens = {
        'basics': [
            (r'\s+', Text),
            (r'//.*?\n', Comment.Single),
            (r'/\*.*?\*/', Comment.Multiline),
        ],
        'type': [
            (r'(any|bool|double|float|int8|int16|int32|string|uint8|uint16|uint32|void)\b', Keyword.Type),
            (r'(' + fullid + ')(\[\])?(\s+)(' + id + r')', bygroups(Name, Text, Operator, Name.Function)),
        ],
        'root': [
            include('basics'),
            (r'@' + fullid, Name.Decorator),
            (r'<c\+\+', Literal.String.Other, 'cppblock'),
            (r'(true|false|null)\b', Keyword.Constant),
            (r'(any|bool|double|float|int8|int16|int32|string|uint8|uint16|uint32|void)\b', Keyword.Type),
            (r'(extends|provides|readonly|receives)\b', Keyword.Declaration),
            (r'(' + id + r')(\s*)(\()', bygroups(Name.Function, Text, Punctuation), 'parameters'),
            (r'(enum)(\s+)(' + id + r')(\s*)(\{)',
              bygroups(Keyword.Declaration, Text, Name.Class, Text, Punctuation), 'enum'),
            (r'(component|exception|interface|native class|struct)(\s+)(' + id + r')',
              bygroups(Keyword.Declaration, Text, Name.Class)),
            (r'(import)(\s+)(' + fullid + r')', bygroups(Keyword.Namespace, Text, Name.Class)),
            (r'"(\\\\|\\"|[^"])*"', String),
            (r'(' + fullid + ')(\[\])?(\s+)(' + id + r')',
              bygroups(Name.Class, Text, Operator, Name.Variable)),
            (id, Name.Variable),
            (r'[\(\)\{\};,.]', Punctuation),
            (r'[~\^\*!%&\[\]<>\|+=:./?-]', Operator),
            (r'[0-9][0-9]*\.[0-9]+([eE][0-9]+)?[fd]?', Number.Float),
            (r'0x[0-9a-fA-F]+', Number.Hex),
            (r'[0-9]+L?', Number.Integer),
        ],
        'enum': [
            include('basics'),
            (r'(' + id + r')(\s*)(,?)', bygroups(Name.Constant, Text, Punctuation)),
            (r'\}', Punctuation, '#pop')
        ],
        'cppblock': [
            (r'(.+?)(c\+\+>)', bygroups(using(CppLexer), Literal.String.Other)),
        ],
        'parameters': [
            include('basics'),
            (r'(inout|in|out)(\s+)(' + fullid + r')(\[\])?(\s*)(' + id + r')(,?)',
              bygroups(Keyword.Declaration, Text, Name.Class, Operator,
                Text, Name.Label, Punctuation)),
            (r'\)', Punctuation, 'raises')
        ],
        'raises': [
            include('basics'),
            (r'(raises)\b', Keyword.Declaration),
            (r'(' + fullid + r')(\s*)(,?)', bygroups(Name.Class, Text, Punctuation)),
            (r';', Punctuation, '#pop:2')
        ],
    }

class TerminalLexer(RegexLexer):
    name = 'CoralTerminal'
    aliases = ['terminal']
    filenames = ['*.terminal']
    tokens = {
        'root': [
            (ur'^([^\n$]*)(\$)([^\n]*)$',
                bygroups(Name.Function, Name.Decorator, Text)),
            (r'^[^\n]+$', Generic.Output)
        ],
    }
