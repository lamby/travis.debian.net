#!/bin/sh

set -eux

MIRROR="http://ftp.de.debian.org/debian"
USE_BACKPORTS="false"
USE_EXPERIMENTAL="false"

DIST="${TRAVIS_BRANCH##debian/}"

# Detect backports
case "${DIST}" in
	*-backports)
		DIST="${DIST%%-backports}"
		USE_BACKPORTS="true"
		;;
	backports/*)
		DIST="${DIST##backports/}"
		USE_BACKPORTS="true"
		;;
esac

# Detect codenames
case "${DIST}" in
	stable)
		DIST="jessie"
		;;
	testing)
		DIST="stretch"
		;;
	unstable|master)
		DIST="sid"
		;;
	experimental)
		DIST="sid"
		USE_EXPERIMENTAL="true"
		;;
esac

cat >Dockerfile <<EOF
FROM debian:${DIST}
RUN echo "deb ${MIRROR} ${DIST} main" > /etc/apt/sources.list
RUN echo "deb-src ${MIRROR} ${DIST} main" >> /etc/apt/sources.list
EOF

if [ "${USE_BACKPORTS}" = true ]
then
	cat >>Dockerfile <<EOF
RUN echo "deb ${MIRROR} ${DIST}-backports main" > /etc/apt/sources.list
RUN echo "deb-src ${MIRROR} ${DIST}-backports main" >> /etc/apt/sources.list
EOF
fi

if [ "${USE_EXPERIMENTAL}" = true ]
then
	cat >>Dockerfile <<EOF
RUN echo "deb ${MIRROR} experimental main" > /etc/apt/sources.list
RUN echo "deb-src ${MIRROR} experimental main" >> /etc/apt/sources.list
EOF
fi

cat >>Dockerfile <<EOF
RUN apt-get update && apt-get dist-upgrade --yes
RUN apt-get install --yes build-essential equivs devscripts git-buildpackage

WORKDIR /tmp/buildd/srcdir

COPY . .

RUN env DEBIAN_FRONTEND=noninteractive mk-build-deps --install --remove --tool 'apt-get --no-install-recommends --yes' debian/control

RUN rm -f Dockerfile
RUN git checkout .travis.yml || true

CMD gbp buildpackage --git-ignore-branch --git-ignore-new --git-builder='debuild -i -I -uc -us -b'
EOF

cat Dockerfile

docker build -t ${TRAVIS_BUILD_ID} .
docker run --net=none ${TRAVIS_BUILD_ID}

#  _                   _          _      _     _                          _
# | |_ _ __ __ ___   _(_)___   __| | ___| |__ (_) __ _ _ __    _ __   ___| |_
# | __| '__/ _` \ \ / / / __| / _` |/ _ \ '_ \| |/ _` | '_ \  | '_ \ / _ \ __|
# | |_| | | (_| |\ V /| \__ \| (_| |  __/ |_) | | (_| | | | |_| | | |  __/ |_
#  \__|_|  \__,_| \_/ |_|___(_)__,_|\___|_.__/|_|\__,_|_| |_(_)_| |_|\___|\__|
