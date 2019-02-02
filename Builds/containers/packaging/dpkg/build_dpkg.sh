#!/usr/bin/env bash
set -ex

source update_sources.sh

# Build the dpkg

#dpkg uses - as separator, so we need to change our -bN versions to tilde
RIPPLED_DPKG_VERSION=$(echo "${RIPPLED_VERSION}" | sed 's!-!~!g')

cd rippled
if [[ -n $(git status --porcelain) ]]; then
    git status
    error "Unstaged changes in this repo - please commit first"
fi
git archive --format tar.gz --prefix rippled-${RIPPLED_DPKG_VERSION}/ -o ../rippled-${RIPPLED_DPKG_VERSION}.tar.gz HEAD
cd ..
# dpkg debmake would normally create this link, but we do it manually
ln -s ./rippled-${RIPPLED_DPKG_VERSION}.tar.gz rippled_${RIPPLED_DPKG_VERSION}.orig.tar.gz
tar xvf rippled-${RIPPLED_DPKG_VERSION}.tar.gz
cd rippled-${RIPPLED_DPKG_VERSION}
cp -pr ../debian .

# dpkg requires a changelog. We don't currently maintain
# a useable one, so let's just fake it with our current version
# TODO : not sure if the "unstable" will need to change for
# release packages (?)
NOWSTR=$(TZ=UTC date -R)
cat << CHANGELOG > ./debian/changelog
rippled (${RIPPLED_DPKG_VERSION}-1) unstable; urgency=low

  * see RELEASENOTES

 -- Ripple Labs Inc. <support@ripple.com>  ${NOWSTR}
CHANGELOG

# PATH must be preserved for our more modern cmake in /opt/local
# TODO : consider allowing lintian to run in future ?
export DH_BUILD_DDEBS=1
debuild --no-lintian --preserve-envvar PATH --preserve-env -us -uc
rc=$?; if [[ $rc != 0 ]]; then
    error "error building dpkg"
fi
cd ..
ls -latr

# copy artifacts
cp rippled-dev_${RIPPLED_DPKG_VERSION}-1_amd64.deb ${PKG_OUTDIR}
cp rippled_${RIPPLED_DPKG_VERSION}-1_amd64.deb ${PKG_OUTDIR}
cp rippled_${RIPPLED_DPKG_VERSION}-1.dsc ${PKG_OUTDIR}
# dbgsym suffix is ddeb under newer debuild, but just deb under earlier
cp rippled-dbgsym_${RIPPLED_DPKG_VERSION}-1_amd64.* ${PKG_OUTDIR}
cp rippled_${RIPPLED_DPKG_VERSION}-1_amd64.changes ${PKG_OUTDIR}
cp rippled_${RIPPLED_DPKG_VERSION}-1_amd64.build ${PKG_OUTDIR}
cp rippled_${RIPPLED_DPKG_VERSION}.orig.tar.gz ${PKG_OUTDIR}
cp rippled_${RIPPLED_DPKG_VERSION}-1.debian.tar.xz ${PKG_OUTDIR}
# buildinfo is only generated by later version of debuild
if [ -e rippled_${RIPPLED_DPKG_VERSION}-1_amd64.buildinfo ] ; then
    cp rippled_${RIPPLED_DPKG_VERSION}-1_amd64.buildinfo ${PKG_OUTDIR}
fi

cat rippled_${RIPPLED_DPKG_VERSION}-1_amd64.changes
# extract the text in the .changes file that appears between
#    Checksums-Sha256:  ...
# and
#    Files: ...
awk '/Checksums-Sha256:/{hit=1;next}/Files:/{hit=0}hit' \
    rippled_${RIPPLED_DPKG_VERSION}-1_amd64.changes | \
        sed -E 's!^[[:space:]]+!!' > shasums
DEB_SHA256=$(cat shasums | \
    grep "rippled_${RIPPLED_DPKG_VERSION}-1_amd64.deb" | cut -d " " -f 1)
DBG_SHA256=$(cat shasums | \
    grep "rippled-dbgsym_${RIPPLED_DPKG_VERSION}-1_amd64.*" | cut -d " " -f 1)
DEV_SHA256=$(cat shasums | \
    grep "rippled-dev_${RIPPLED_DPKG_VERSION}-1_amd64.deb" | cut -d " " -f 1)
SRC_SHA256=$(cat shasums | \
    grep "rippled_${RIPPLED_DPKG_VERSION}.orig.tar.gz" | cut -d " " -f 1)
echo "deb_sha256=${DEB_SHA256}" >> ${PKG_OUTDIR}/build_vars
echo "dbg_sha256=${DBG_SHA256}" >> ${PKG_OUTDIR}/build_vars
echo "dev_sha256=${DEV_SHA256}" >> ${PKG_OUTDIR}/build_vars
echo "src_sha256=${SRC_SHA256}" >> ${PKG_OUTDIR}/build_vars
echo "rippled_version=${RIPPLED_VERSION}" >> ${PKG_OUTDIR}/build_vars
echo "dpkg_version=${RIPPLED_DPKG_VERSION}" >> ${PKG_OUTDIR}/build_vars
