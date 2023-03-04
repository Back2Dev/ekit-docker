#!/bin/bash
# $Id: system-setup.sh,v 1.2 2011-08-31 00:52:38 triton Exp $
#
# Kwik script to set up all the 'system' packages necessary to support the Triton software
#
# - - - First up, some fonts...
#
aptitude install -y \
 ttf-freefont  \
 ttf-indic-fonts-core \
 ttf-mscorefonts-installer \
 ttf-punjabi-fonts         \
 ttf-ubuntu-font-family    \
 ttf-umefont               \
 ttf-unfonts-core          \
 ttf-unikurdweb            \
 ttf-kacst-one             \
 ttf-droid                 \
 ttf-dejavu  \
 ttf-dejavu-core  \
 ttf-liberation  \
 ttf-mscorefonts-installer  \
 ttf-symbol-replacement  \
 ttf-takao-pgothic  \
 ttf-thai-tlwg  \


#
# - - - Next, utilities
#
aptitude install -y \
 links \
 lynx \
 rsync \
 elinks \
 zip \
 unzip \
 ncftp2 \
 ncftp \
 telnet \
 cvs \
 subversion \
 locate \
 imagemagick \
 perlmagick \
 dh-make-perl \


