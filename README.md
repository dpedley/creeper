Creeper
=======

Creeper is an iPhone app to create animated gifs from video capture device. Imgur is used as the storage solution.

Imgur api requires a API client id. You can obtain one at http://api.imgur.com and copy the id string provided into 
the ImgurAPICredentials.h located in the Imgur group in the project.

Compiling
=========

1. git clone git@github.com:dpedley/creeper.git
2. cd creeper
3. git submodule init
4. git submodule update --recursive

Additional externals not hosted on github.

Giflib (version was 5.0.4 as of this writing)

1. download from http://sourceforge.net/projects/giflib/files/latest/download
2. extract to a temporary folder
3. cp giflib-5.0.4/lib/*.[ch] externals/giflib-ios/giflib-ios/giflib-ios/

PNGNQ (version 1.1 as of this writing)

1. download from http://sourceforge.net/projects/pngnq/files/latest/download
2. extract to a temporary folder
3. cp pngnq-1.1/src/neuquant32.[ch] externals/giflib-ios/giflib-ios/giflib-ios/

At this point the project should compile. Tested on xcode 4.6 with iOS 6.1. 

Configuring
===========

For the most part, configuring is a matter of adding various developer keys from online services. These 
configuration options are contained in a few limited source files.

!!! WARNING !!!
There are two copies of these files listed in the project. The ones in the folder "credentials" are not used by the 
application. They are only referenced there to make developers lives easier, and help avoid pushing private credential
information to github.

1. ImgurAPICredentials.h - You application ID registered with https://api.imgur.com/
2. CreeperSHKConfigurator.m - ShareKit integration keys instructions at: http://getsharekit.com/install/ 

!!! Notes on ShareKit integration !!!

(as of March 5th 2013)
Creeper is pre-configured. You only need to do step 3 in the instructions.
In step 3, the instructions call for info in SHKConfig.h this has been duplicated in CreeperSHKConfigurator.m. 

Imagery
=======

The splash screen is an illustration of Eurasian Treecreepers by Henrik Grönvold. It is dated from 1904-1905. 
Henrik passed away in 1940. This image became part of the the public domain in the European Union and non-EU 
countries in 2010 with a copyright term of 70 years. I found the image and copyright information on wikimedia
at the following url.

http://commons.wikimedia.org/wiki/File:Tree_Creeper_Gr%C3%B6nvold.jpg

The icon is a photograph found on wikimedia. The copyright holder Jon Sullivan has given this image to the public domain. 
Jon runs the site http://pdphoto.org where the wikimedia calls the original source. I found the image and copyright 
information at the following url.

http://commons.wikimedia.org/wiki/File:Vine.jpg
