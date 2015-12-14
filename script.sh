#!/bin/sh
#
# Copyright (C) 2015 Chris Lamb <lamby@debian.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -eu

## Functions ##################################################################

log () {
	echo "I: ${*}" >&2
}

## Configuration ##############################################################

SOURCE="$(dpkg-parsechangelog --show-field Source)"
VERSION="$(dpkg-parsechangelog --show-field Version)"

log "Starting build of ${SOURCE} ${VERSION} using travis.debian.net"

TRAVIS_DEBIAN_MIRROR="${TRAVIS_DEBIAN_MIRROR:-http://httpredir.debian.org/debian}"
TRAVIS_DEBIAN_BUILD_DIR="${TRAVIS_DEBIAN_BUILD_DIR:-/tmp/buildd}"
TRAVIS_DEBIAN_TARGET_DIR="${TRAVIS_DEBIAN_TARGET_DIR:-./debian/buildd}"
TRAVIS_DEBIAN_NETWORK_ENABLED="${TRAVIS_DEBIAN_NETWORK_ENABLED:-false}"

#### Distribution #############################################################

TRAVIS_DEBIAN_BACKPORTS="${TRAVIS_DEBIAN_BACKPORTS:-false}"
TRAVIS_DEBIAN_EXPERIMENTAL="${TRAVIS_DEBIAN_EXPERIMENTAL:-false}"

if [ "${TRAVIS_DEBIAN_DISTRIBUTION:-}" = "" ]
then
	log "Automatically detecting distribution"

	TRAVIS_DEBIAN_DISTRIBUTION="${TRAVIS_BRANCH:-}"

	if [ "${TRAVIS_DEBIAN_DISTRIBUTION:-}" = "" ]
	then
		TRAVIS_DEBIAN_DISTRIBUTION="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo master)"
	fi

	TRAVIS_DEBIAN_DISTRIBUTION="${TRAVIS_DEBIAN_DISTRIBUTION##debian/}"

	# Detect backports
	case "${TRAVIS_DEBIAN_DISTRIBUTION}" in
		*-backports)
			TRAVIS_DEBIAN_BACKPORTS="true"
			TRAVIS_DEBIAN_DISTRIBUTION="${DIST%%-backports}"
			;;
		backports/*)
			TRAVIS_DEBIAN_BACKPORTS="true"
			TRAVIS_DEBIAN_DISTRIBUTION="${DIST##backports/}"
			;;
	esac

	# Detect codenames
	case "${TRAVIS_DEBIAN_DISTRIBUTION}" in
		stable)
			TRAVIS_DEBIAN_DISTRIBUTION="jessie"
			;;
		testing)
			TRAVIS_DEBIAN_DISTRIBUTION="stretch"
			;;
		unstable|master)
			TRAVIS_DEBIAN_DISTRIBUTION="sid"
			;;
		experimental)
			TRAVIS_DEBIAN_DISTRIBUTION="sid"
			TRAVIS_DEBIAN_EXPERIMENTAL="true"
			;;
	esac
fi

log "Using distribution: ${TRAVIS_DEBIAN_DISTRIBUTION}"
log "Backports enabled: ${TRAVIS_DEBIAN_EXPERIMENTAL}"
log "Experimental enabled: ${TRAVIS_DEBIAN_EXPERIMENTAL}"
log "Will build under ${TRAVIS_DEBIAN_BUILD_DIR}"
log "Will store results under ${TRAVIS_DEBIAN_TARGET_DIR}"
log "Using mirror ${TRAVIS_DEBIAN_MIRROR}"
log "Network enabled during build: ${TRAVIS_DEBIAN_NETWORK_ENABLED}"

## Build ######################################################################

cat >Dockerfile <<EOF
FROM debian:${TRAVIS_DEBIAN_DISTRIBUTION}
RUN echo "deb ${TRAVIS_DEBIAN_MIRROR} ${TRAVIS_DEBIAN_DISTRIBUTION} main" > /etc/apt/sources.list
RUN echo "deb-src ${TRAVIS_DEBIAN_MIRROR} ${TRAVIS_DEBIAN_DISTRIBUTION} main" >> /etc/apt/sources.list
EOF

if [ "${TRAVIS_DEBIAN_BACKPORTS}" = true ]
then
	cat >>Dockerfile <<EOF
RUN echo "deb ${TRAVIS_DEBIAN_MIRROR} ${TRAVIS_DEBIAN_DISTRIBUTION}-backports main" > /etc/apt/sources.list
RUN echo "deb-src ${TRAVIS_DEBIAN_MIRROR} ${TRAVIS_DEBIAN_DISTRIBUTION}-backports main" >> /etc/apt/sources.list
EOF
fi

if [ "${TRAVIS_DEBIAN_EXPERIMENTAL}" = true ]
then
	cat >>Dockerfile <<EOF
RUN echo "deb ${TRAVIS_DEBIAN_MIRROR} experimental main" > /etc/apt/sources.list
RUN echo "deb-src ${TRAVIS_DEBIAN_MIRROR} experimental main" >> /etc/apt/sources.list
EOF
fi

cat >>Dockerfile <<EOF
RUN apt-get update && apt-get dist-upgrade --yes
RUN apt-get install --yes --no-install-recommends build-essential equivs devscripts git-buildpackage

WORKDIR $(pwd)
COPY . .

RUN env DEBIAN_FRONTEND=noninteractive mk-build-deps --install --remove --tool 'apt-get --no-install-recommends --yes' debian/control

RUN rm -f Dockerfile
RUN git checkout .travis.yml || true
RUN mkdir -p ${TRAVIS_DEBIAN_BUILD_DIR}

CMD gbp buildpackage --git-ignore-branch --git-export-dir=${TRAVIS_DEBIAN_BUILD_DIR} --git-ignore-new --git-builder='debuild -i -I -uc -us -sa'
EOF

log "Using Dockerfile:"
sed -e 's@^@  @g' Dockerfile

log "Clearing ${TRAVIS_DEBIAN_TARGET_DIR}"
rm -rf "${TRAVIS_DEBIAN_TARGET_DIR}"

TAG="travis.debian.net/${SOURCE}:${VERSION}"

log "Building Docker image ${TAG}"
docker build --tag=${TAG} .

log "Removing Dockerfile"
rm -f Dockerfile

CIDFILE="$(mktemp)"
ARGS="--cidfile=${CIDFILE}"
rm -f ${CIDFILE} # Cannot exist

if [ "${TRAVIS_DEBIAN_NETWORK_ENABLED}" != "true" ]
then
	ARGS="${ARGS} --net=none"
fi

log "Running build"
docker run ${ARGS} ${TAG}

log "Copying build artefacts to ${TRAVIS_DEBIAN_TARGET_DIR}"
docker cp "$(cat ${CIDFILE}):${TRAVIS_DEBIAN_BUILD_DIR}" "${TRAVIS_DEBIAN_TARGET_DIR}"

log "Removing container"
docker rm "$(cat ${CIDFILE})" >/dev/null
rm -f "${CIDFILE}"

log "Build successful"
sed -e 's@^@  @g' "${TRAVIS_DEBIAN_TARGET_DIR}"/*.changes

#  _                   _          _      _     _                          _
# | |_ _ __ __ ___   _(_)___   __| | ___| |__ (_) __ _ _ __    _ __   ___| |_
# | __| '__/ _` \ \ / / / __| / _` |/ _ \ '_ \| |/ _` | '_ \  | '_ \ / _ \ __|
# | |_| | | (_| |\ V /| \__ \| (_| |  __/ |_) | | (_| | | | |_| | | |  __/ |_
#  \__|_|  \__,_| \_/ |_|___(_)__,_|\___|_.__/|_|\__,_|_| |_(_)_| |_|\___|\__|
#
