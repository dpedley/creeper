Creeper
=======

Creeper is an iPhone app to create animated gifs from video capture device. Imgur is used as the storage solution.

Compiling instructions.

1. git clone git@github.com:dpedley/creeper.git
2. cd creeper
3. git submodule init
4. git submodule update --recursive

Additional externals not hosted on github.

Giflib (version was 5.0.4 as of this writing)

1. download from http://sourceforge.net/projects/giflib/files/latest/download
2. extract to a temporary folder
3. cp giflib-5.0.4/lib/*.[ch] externals/giflib-ios/giflib-ios/giflib-ios/

PNGNQ (vwersion 1.1 as of this writing)

1. download from http://sourceforge.net/projects/pngnq/files/latest/download
2. extract to a temporary folder
3. cp pngnq-1.1/src/neuquant32.[ch] externals/giflib-ios/giflib-ios/giflib-ios/
