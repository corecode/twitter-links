twitter-links - record links posted on twitter
==============================================

twitter-links is a small tool to extract links that are being posted
on twitter.  twitter-links follows redirects so that final URLs
instead of URL shortening services are recorded.  At the moment
twitter-links explicitly ignores images and links to non-html pages.


Installation
------------

	gem install tweetstream em-http-request json


Twitter requires all applications to carry a unique OAuth
authentication token, which must be kept secure.  Clearly this is not
possible in any user-side application; therefore you will have to
register an application yourself to obtain a token.  Go to
https://dev.twitter.com/apps to do so, then enter the credentials in
`auth.conf`.  You can use `auth.conf.example` as a template.


Usage
-----

	ruby capture.rb <prefix>

twitter-links will write links to gzip'ed files, starting with
`prefix`, suffixed with the creation time of the file.  A new file is
created after 100'000 links.


Author
------

(c) Copyright 2012, 2013 Simon Schubert <2@0x2c.org>
