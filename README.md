Coral Website
=============

These are the source files for the website http://www.coral-framework.org/

It's built using [Middleman](http://middlemanapp.com/) with some custom extensions.

How to run the site locally
---------------------------

Make sure you have Ruby 2.0+ and Bundler installed, then clone this repository and run `bundle install`. Then run `middleman` to start the server at `http://localhost:4567`.


Syntax highlighting with Pygments
---------------------------------

Because we use [Pygments](http://pygments.org/) you'll also need Python and our _custom lexer_ for syntax highlighting. After installing Pygments go to `coral-website/pygments` and use `setup.py` to install our lexer. For example, in OSX run `sudo python setup.py install`.

Contributing
------------

Please help Coral improve its documentation. We'll merge in any reasonable extensions to our website docs, and give credit for your help!
]Most articles are written in [Markdown](http://en.wikipedia.org/wiki/Markdown).

Copyright
---------

Copyright (c) Thiago Bastos. [Creative Commons Attribution-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-sa/4.0/).