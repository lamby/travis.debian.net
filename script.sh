#!/bin/sh

#  _                   _          _      _     _                          _
# | |_ _ __ __ ___   _(_)___   __| | ___| |__ (_) __ _ _ __    _ __   ___| |_
# | __| '__/ _` \ \ / / / __| / _` |/ _ \ '_ \| |/ _` | '_ \  | '_ \ / _ \ __|
# | |_| | | (_| |\ V /| \__ \| (_| |  __/ |_) | | (_| | | | |_| | | |  __/ |_
#  \__|_|  \__,_| \_/ |_|___(_)__,_|\___|_.__/|_|\__,_|_| |_(_)_| |_|\___|\__|
#
#
#               Documentation: <http://travis.debian.net>


## Copyright ##################################################################
#
# Copyright © 2015, 2016, 2017 Chris Lamb <lamby@debian.org>
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

## Functions ##################################################################

set -eu

Info () {
	echo "I: ${*}" >&2
}

Error () {
	echo "E: ${*}" >&2
}

## Configuration ##############################################################

SOURCE="$(dpkg-parsechangelog | awk '/^Source:/ { print $2 }')"
VERSION="$(dpkg-parsechangelog | awk '/^Version:/ { print $2 }')"

if [ "${SOURCE}" = "" ] || [ "${VERSION}" = "" ]
then
	Error "Could not determine source and version from debian/changelog"
	exit 2
fi

Info "Starting build of ${SOURCE} using travis.debian.net"

TRAVIS_DEBIAN_MIRROR="${TRAVIS_DEBIAN_MIRROR:-http://deb.debian.org/debian}"
TRAVIS_DEBIAN_BUILD_DIR="${TRAVIS_DEBIAN_BUILD_DIR:-/build}"
TRAVIS_DEBIAN_TARGET_DIR="${TRAVIS_DEBIAN_TARGET_DIR:-../}"
TRAVIS_DEBIAN_NETWORK_ENABLED="${TRAVIS_DEBIAN_NETWORK_ENABLED:-false}"
TRAVIS_DEBIAN_INCREMENT_VERSION_NUMBER="${TRAVIS_DEBIAN_INCREMENT_VERSION_NUMBER:-false}"

#### Distribution #############################################################

TRAVIS_DEBIAN_BACKPORTS="${TRAVIS_DEBIAN_BACKPORTS:-false}"
TRAVIS_DEBIAN_EXPERIMENTAL="${TRAVIS_DEBIAN_EXPERIMENTAL:-false}"

if [ "${TRAVIS_DEBIAN_DISTRIBUTION:-}" = "" ]
then
	Info "Automatically detecting distribution"

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
			TRAVIS_DEBIAN_DISTRIBUTION="${TRAVIS_DEBIAN_DISTRIBUTION%%-backports}"
			;;
		backports/*)
			TRAVIS_DEBIAN_BACKPORTS="true"
			TRAVIS_DEBIAN_DISTRIBUTION="${TRAVIS_DEBIAN_DISTRIBUTION##backports/}"
			;;
		*_bpo7+*|*_bpo70+*)
			TRAVIS_DEBIAN_BACKPORTS="true"
			TRAVIS_DEBIAN_DISTRIBUTION="wheezy"
			;;
		*_bpo8+*)
			TRAVIS_DEBIAN_BACKPORTS="true"
			TRAVIS_DEBIAN_DISTRIBUTION="jessie"
			;;
		*_bpo9+*)
			TRAVIS_DEBIAN_BACKPORTS="true"
			TRAVIS_DEBIAN_DISTRIBUTION="stretch"
			;;
		*_bpo10+*)
			TRAVIS_DEBIAN_BACKPORTS="true"
			TRAVIS_DEBIAN_DISTRIBUTION="buster"
			;;
	esac
fi

# Detect codenames
case "${TRAVIS_DEBIAN_DISTRIBUTION}" in
	oldoldstable)
		TRAVIS_DEBIAN_DISTRIBUTION="wheezy"
		;;
	oldstable)
		TRAVIS_DEBIAN_DISTRIBUTION="jessie"
		;;
	stable)
		TRAVIS_DEBIAN_DISTRIBUTION="stretch"
		;;
	testing)
		TRAVIS_DEBIAN_DISTRIBUTION="buster"
		;;
	unstable|master)
		TRAVIS_DEBIAN_DISTRIBUTION="sid"
		;;
	experimental)
		TRAVIS_DEBIAN_DISTRIBUTION="sid"
		TRAVIS_DEBIAN_EXPERIMENTAL="true"
		;;
esac

case "${TRAVIS_DEBIAN_DISTRIBUTION}" in
	wheezy)
		TRAVIS_DEBIAN_GIT_BUILDPACKAGE="${TRAVIS_DEBIAN_GIT_BUILDPACKAGE:-git-buildpackage}"
		TRAVIS_DEBIAN_GIT_BUILDPACKAGE_OPTIONS="${TRAVIS_DEBIAN_GIT_BUILDPACKAGE_OPTIONS:-}"
		;;
	*)
		TRAVIS_DEBIAN_GIT_BUILDPACKAGE="${TRAVIS_DEBIAN_GIT_BUILDPACKAGE:-gbp buildpackage}"
		TRAVIS_DEBIAN_GIT_BUILDPACKAGE_OPTIONS="${TRAVIS_DEBIAN_GIT_BUILDPACKAGE_OPTIONS:---git-submodules}"
		;;
esac

case "${TRAVIS_DEBIAN_DISTRIBUTION}" in
	wheezy|jessie)
		TRAVIS_DEBIAN_AUTOPKGTEST_RUN="${TRAVIS_DEBIAN_AUTOPKGTEST_RUN:-adt-run}"
		TRAVIS_DEBIAN_AUTOPKGTEST_SEPARATOR="${TRAVIS_DEBIAN_AUTOPKGTEST_SEPARATOR:----}"
		;;
	*)
		TRAVIS_DEBIAN_AUTOPKGTEST_RUN="${TRAVIS_DEBIAN_AUTOPKGTEST_RUN:-autopkgtest}"
		TRAVIS_DEBIAN_AUTOPKGTEST_SEPARATOR="${TRAVIS_DEBIAN_AUTOPKGTEST_SEPARATOR:---}"
		;;
esac

case "${TRAVIS_DEBIAN_DISTRIBUTION}" in
	sid)
		TRAVIS_DEBIAN_SECURITY_UPDATES="${TRAVIS_DEBIAN_SECURITY_UPDATES:-false}"
		;;
	*)
		TRAVIS_DEBIAN_SECURITY_UPDATES="${TRAVIS_DEBIAN_SECURITY_UPDATES:-true}"
		;;
esac

## Detect autopkgtest tests ###################################################

if [ -e "debian/tests/control" ] || grep -E '^(XS-)?Testsuite: autopkgtest' debian/control
then
	TRAVIS_DEBIAN_AUTOPKGTEST="${TRAVIS_DEBIAN_AUTOPKGTEST:-true}"
else
	TRAVIS_DEBIAN_AUTOPKGTEST="${TRAVIS_DEBIAN_AUTOPKGTEST:-false}"
fi

## Print configuration ########################################################

Info "Using distribution: ${TRAVIS_DEBIAN_DISTRIBUTION}"
Info "Backports enabled: ${TRAVIS_DEBIAN_BACKPORTS}"
Info "Experimental enabled: ${TRAVIS_DEBIAN_EXPERIMENTAL}"
Info "Security updates enabled: ${TRAVIS_DEBIAN_SECURITY_UPDATES}"
Info "Will use extra repository: ${TRAVIS_DEBIAN_EXTRA_REPOSITORY:-<not set>}"
Info "Extra repository's key URL: ${TRAVIS_DEBIAN_EXTRA_REPOSITORY_GPG_URL:-<not set>}"
Info "Will build under: ${TRAVIS_DEBIAN_BUILD_DIR}"
Info "Will store results under: ${TRAVIS_DEBIAN_TARGET_DIR}"
Info "Using mirror: ${TRAVIS_DEBIAN_MIRROR}"
Info "Network enabled during build: ${TRAVIS_DEBIAN_NETWORK_ENABLED}"
Info "Builder command: ${TRAVIS_DEBIAN_GIT_BUILDPACKAGE}"
Info "Builder command options: ${TRAVIS_DEBIAN_GIT_BUILDPACKAGE_OPTIONS}"
Info "Increment version number: ${TRAVIS_DEBIAN_INCREMENT_VERSION_NUMBER}"
Info "Run autopkgtests after build: ${TRAVIS_DEBIAN_AUTOPKGTEST}"
Info "DEB_BUILD_OPTIONS: ${DEB_BUILD_OPTIONS:-<not set>}"

## Increment version number ###################################################

if [ "${TRAVIS_DEBIAN_INCREMENT_VERSION_NUMBER}" = true ]
then
	cat >debian/changelog.new <<EOF
${SOURCE} (${VERSION}+travis${TRAVIS_BUILD_NUMBER}) UNRELEASED; urgency=medium

  * Automatic build.

 -- travis.debian.net <nobody@nobody>  $(date --utc -R)

EOF
	cat <debian/changelog >>debian/changelog.new
	mv debian/changelog.new debian/changelog
	git add debian/changelog
	git commit -m "Incrementing version number."
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
RUN echo "deb ${TRAVIS_DEBIAN_MIRROR} ${TRAVIS_DEBIAN_DISTRIBUTION}-backports main" >> /etc/apt/sources.list
RUN echo "deb-src ${TRAVIS_DEBIAN_MIRROR} ${TRAVIS_DEBIAN_DISTRIBUTION}-backports main" >> /etc/apt/sources.list
EOF
fi

if [ "${TRAVIS_DEBIAN_SECURITY_UPDATES}" = true ]
then
	cat >>Dockerfile <<EOF
RUN echo "deb http://security.debian.org/ ${TRAVIS_DEBIAN_DISTRIBUTION}/updates main" >> /etc/apt/sources.list
RUN echo "deb-src http://security.debian.org/ ${TRAVIS_DEBIAN_DISTRIBUTION}/updates main" >> /etc/apt/sources.list
EOF
fi

if [ "${TRAVIS_DEBIAN_EXPERIMENTAL}" = true ]
then
	cat >>Dockerfile <<EOF
RUN echo "deb ${TRAVIS_DEBIAN_MIRROR} experimental main" >> /etc/apt/sources.list
RUN echo "deb-src ${TRAVIS_DEBIAN_MIRROR} experimental main" >> /etc/apt/sources.list
EOF
fi

TRAVIS_DEBIAN_EXTRA_PACKAGES=""

case "${TRAVIS_DEBIAN_EXTRA_REPOSITORY:-}" in
	https:*)
		TRAVIS_DEBIAN_EXTRA_PACKAGES="${TRAVIS_DEBIAN_EXTRA_PACKAGES} apt-transport-https"
		;;
esac

if [ "${TRAVIS_DEBIAN_EXTRA_REPOSITORY_GPG_URL:-}" != "" ]
then
	TRAVIS_DEBIAN_EXTRA_PACKAGES="${TRAVIS_DEBIAN_EXTRA_PACKAGES} wget gnupg"
fi

if [ "${TRAVIS_DEBIAN_BACKPORTS}" = "true" ]
then
        cat >>Dockerfile <<EOF
RUN echo "Package: *" >> /etc/apt/preferences.d/travis_debian_net
RUN echo "Pin: release a=${TRAVIS_DEBIAN_DISTRIBUTION}-backports" >> /etc/apt/preferences.d/travis_debian_net
RUN echo "Pin-Priority: 500" >> /etc/apt/preferences.d/travis_debian_net
EOF
fi

cat >>Dockerfile <<EOF
RUN apt-get update && apt-get dist-upgrade --yes
RUN apt-get install --yes --no-install-recommends build-essential equivs devscripts git-buildpackage ca-certificates pristine-tar lintian ${TRAVIS_DEBIAN_EXTRA_PACKAGES}

WORKDIR $(pwd)
COPY . .
EOF

if [ "${TRAVIS_DEBIAN_EXTRA_REPOSITORY_GPG_URL:-}" != "" ]
then
	cat >>Dockerfile <<EOF
RUN wget -O- "${TRAVIS_DEBIAN_EXTRA_REPOSITORY_GPG_URL}" | apt-key add -
EOF
fi

# We're adding the extra repository only after the essential tools have been
# installed, so that we have apt-transport-https if the repository needs it.
if [ "${TRAVIS_DEBIAN_EXTRA_REPOSITORY:-}" != "" ]
then
	cat >>Dockerfile <<EOF
RUN echo "deb ${TRAVIS_DEBIAN_EXTRA_REPOSITORY}" >> /etc/apt/sources.list
RUN echo "deb-src ${TRAVIS_DEBIAN_EXTRA_REPOSITORY}" >> /etc/apt/sources.list
RUN apt-get update
EOF
fi

cat >>Dockerfile <<EOF
RUN env DEBIAN_FRONTEND=noninteractive mk-build-deps --install --remove --tool 'apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes' debian/control

RUN rm -f Dockerfile
RUN git checkout .travis.yml || true
RUN mkdir -p ${TRAVIS_DEBIAN_BUILD_DIR}

RUN git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
RUN git fetch
RUN for X in \$(git branch -r | grep -v HEAD); do git branch --track \$(echo "\${X}" | sed -e 's@.*/@@g') \${X} || true; done

CMD ${TRAVIS_DEBIAN_GIT_BUILDPACKAGE} ${TRAVIS_DEBIAN_GIT_BUILDPACKAGE_OPTIONS} --git-ignore-branch --git-export-dir=${TRAVIS_DEBIAN_BUILD_DIR} -uc -us -sa
EOF

Info "Using Dockerfile:"
sed -e 's@^@  @g' Dockerfile

TAG="travis.debian.net/${SOURCE}"

Info "Building Docker image ${TAG}"
docker build --tag="${TAG}" .

Info "Removing Dockerfile"
rm -f Dockerfile

CIDFILE="$(mktemp --dry-run)"
ARGS="--cidfile=${CIDFILE}"

if [ "${TRAVIS_DEBIAN_NETWORK_ENABLED}" != "true" ]
then
	ARGS="${ARGS} --net=none"
fi

Info "Running build"
# shellcheck disable=SC2086
docker run --env=DEB_BUILD_OPTIONS="${DEB_BUILD_OPTIONS:-}" ${ARGS} "${TAG}"

Info "Copying build artefacts to ${TRAVIS_DEBIAN_TARGET_DIR}"
mkdir -p "${TRAVIS_DEBIAN_TARGET_DIR}"
docker cp "$(cat "${CIDFILE}")":"${TRAVIS_DEBIAN_BUILD_DIR}"/ - \
	| tar xf - -C "${TRAVIS_DEBIAN_TARGET_DIR}" --strip-components=1

if [ "${TRAVIS_DEBIAN_AUTOPKGTEST}" = "true" ]
then
	Info "Running autopkgtests"

	docker run --env TRAVIS=true --volume "$(readlink -f "${TRAVIS_DEBIAN_TARGET_DIR}"):${TRAVIS_DEBIAN_BUILD_DIR}" --interactive "${TAG}" /bin/sh - <<EOF
set -eu

cat <<EOS >/usr/sbin/policy-rc.d
#!/bin/sh
exit 0
EOS
chmod a+x /usr/sbin/policy-rc.d
apt-get install --yes --no-install-recommends autopkgtest autodep8

TEST_RET="0"
${TRAVIS_DEBIAN_AUTOPKGTEST_RUN} ${TRAVIS_DEBIAN_BUILD_DIR}/*.changes ${TRAVIS_DEBIAN_AUTOPKGTEST_SEPARATOR} null || TEST_RET="\${?}"
echo "I: ${TRAVIS_DEBIAN_AUTOPKGTEST_RUN} exited with status code \${TEST_RET}" >&2
if [ "\${TEST_RET}" != "0" ] && [ "\${TEST_RET}" != "2" ]
then
	exit \${TEST_RET}
fi
EOF
fi

Info "Removing container"
docker rm "$(cat "${CIDFILE}")" >/dev/null
rm -f "${CIDFILE}"

Info "Build successful"
sed -e 's@^@  @g' "${TRAVIS_DEBIAN_TARGET_DIR}"/*.changes

#  _                   _          _      _     _                          _
# | |_ _ __ __ ___   _(_)___   __| | ___| |__ (_) __ _ _ __    _ __   ___| |_
# | __| '__/ _` \ \ / / / __| / _` |/ _ \ '_ \| |/ _` | '_ \  | '_ \ / _ \ __|
# | |_| | | (_| |\ V /| \__ \| (_| |  __/ |_) | | (_| | | | |_| | | |  __/ |_
#  \__|_|  \__,_| \_/ |_|___(_)__,_|\___|_.__/|_|\__,_|_| |_(_)_| |_|\___|\__|
#
