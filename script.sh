#!/bin/sh

set -eu

## Configuration ##############################################################

TRAVIS_BUILD_ID="${TRAVIS_BUILD_ID:-travis.debian.net}"
TRAVIS_DEBIAN_MIRROR="${TRAVIS_DEBIAN_MIRROR:-http://ftp.de.debian.org/debian}"

TRAVIS_DEBIAN_BACKPORTS="${TRAVIS_DEBIAN_BACKPORTS:-false}"
TRAVIS_DEBIAN_EXPERIMENTAL="${TRAVIS_DEBIAN_EXPERIMENTAL:-false}"
TRAVIS_DEBIAN_NETWORK_ENABLED="${TRAVIS_DEBIAN_NETWORK_ENABLED:-false}"

if [ "${TRAVIS_DEBIAN_WORKDIR:-}" = "" ]
then
	TRAVIS_DEBIAN_WORKDIR="/tmp/buildd/srcdir"
fi

if [ "${TRAVIS_DEBIAN_DISTRIBUTION:-}" = "" ]
then
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
RUN apt-get install --yes build-essential equivs devscripts git-buildpackage

WORKDIR ${TRAVIS_DEBIAN_WORKDIR}

COPY . .

RUN env DEBIAN_FRONTEND=noninteractive mk-build-deps --install --remove --tool 'apt-get --no-install-recommends --yes' debian/control

RUN rm -f Dockerfile
RUN git checkout .travis.yml || true

CMD gbp buildpackage --git-ignore-branch --git-ignore-new --git-builder='debuild -i -I -uc -us -b'
EOF

cat Dockerfile

CIDFILE="$(mktemp)"
rm -f ${CIDFILE} # Cannot exist

ARGS="--cidfile=${CIDFILE}"
if [ "${TRAVIS_DEBIAN_NETWORK_ENABLED}" != "true" ]
then
	ARGS="${ARGS} --net=none"
fi

docker build --tag=${TRAVIS_BUILD_ID} .
docker run ${ARGS} ${TRAVIS_BUILD_ID}
docker cp $(cat ${CIDFILE}):$(dirname "${TRAVIS_DEBIAN_WORKDIR}") debian/buildd

#  _                   _          _      _     _                          _
# | |_ _ __ __ ___   _(_)___   __| | ___| |__ (_) __ _ _ __    _ __   ___| |_
# | __| '__/ _` \ \ / / / __| / _` |/ _ \ '_ \| |/ _` | '_ \  | '_ \ / _ \ __|
# | |_| | | (_| |\ V /| \__ \| (_| |  __/ |_) | | (_| | | | |_| | | |  __/ |_
#  \__|_|  \__,_| \_/ |_|___(_)__,_|\___|_.__/|_|\__,_|_| |_(_)_| |_|\___|\__|
#
