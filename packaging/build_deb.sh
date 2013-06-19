#!/bin/sh

set -e

DEVSCRIPTS="${HOME}/.devscripts"
. "${DEVSCRIPTS}"

DISTRIBUTION=${DISTRIBUTION:-debian}

cd "$(dirname "$0")/.."
UDEV_RULES="$PWD/rules.d"
DEBIAN_FILES="$PWD/packaging/debian"
DIST="$PWD/dist/$DISTRIBUTION"
export DIST_RELEASE=${DIST_RELEASE:-UNRELEASED}

#
# build a python sdist package
#

export TMPDIR=${TMPDIR:-/tmp}/solaar-build-$USER
/bin/mkdir --parents --mode=0700 "$TMPDIR"
BUILD_DIR="$TMPDIR/build-$DISTRIBUTION"
/bin/rm --recursive --force "$BUILD_DIR"
/bin/mkdir --parents --mode=0700 "$BUILD_DIR"
python "setup.py" sdist --dist-dir="$BUILD_DIR" --formats=gztar

cd "$BUILD_DIR"
S=$(ls -1t solaar-*.tar.gz | tail -n 1)
test -r "$S"
VERSION=${S#solaar-}
VERSION=${VERSION%.tar.gz}

LAST=$(head -n 1 "$DEBIAN_FILES/changelog" | grep -o ' ([0-9.-]*) ')
LAST=${LAST# (}
LAST=${LAST%) }
LAST_VERSION=$(echo "$LAST" | cut -d- -f 1)
LAST_BUILD=$(echo "$LAST" | cut -d- -f 2)

if test -n "$BUILD_EXTRA"; then
	BUILD_NUMBER=$LAST_BUILD
elif dpkg --compare-versions "$VERSION" gt "$LAST_VERSION"; then
	BUILD_NUMBER=1
else
	BUILD_NUMBER=$(($LAST_BUILD + 1))
fi

tar xfz "$S"
mv "$S" solaar_$VERSION.orig.tar.gz

#
# finally build the package
#

cd solaar-$VERSION
cp -a "$DEBIAN_FILES" .
test -s debian/solaar.udev || cp -a "$UDEV_RULES"/??-*.rules debian/solaar.udev
cat >debian/changelog <<_CHANGELOG
solaar ($VERSION-$BUILD_NUMBER$BUILD_EXTRA) $DIST_RELEASE; urgency=low

  * Debian packaging scripts, supports ubuntu ppa as well.

 -- $DEBFULLNAME <$DEBMAIL>  $(date -R)

_CHANGELOG
# if this is the main (Debian) build, update the changelog
test "$BUILD_EXTRA" || cp -a debian/changelog "$DEBIAN_FILES"/changelog

test "$DEBIAN_FILES_EXTRA" && cp -a $DEBIAN_FILES_EXTRA/* debian/

/usr/bin/debuild ${DEBUILD_ARGS:-$@} \
	--lintian-opts --profile $DISTRIBUTION

/bin/rm --force "$DIST"/*
/bin/mkdir --parents "$DIST"
cp -a -t "$DIST" ../solaar_$VERSION*
cp -a -t "$DIST" ../solaar-*_$VERSION* || true
cd "$DIST"
#cp -av -t ../../../packages/ * || true