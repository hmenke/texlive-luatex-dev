#!/bin/sh

set -e

if [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
    echo "INFO: This is a PR.";
    echo "INFO: Not deploying repo.";
    exit 0;
fi;


if [ -z "${GH_TOKEN}" ]; then
    echo "INFO: The GitHub access token is not set.";
    echo "INFO: Not deploying repo.";
    exit 0;
fi;


if [ -z "$(git ls-remote --heads https://github.com/${TRAVIS_REPO_SLUG} gh-pages)" ]; then
    echo "INFO: The branch gh-pages does not exist.";
    echo "INFO: Not deploying repo.";
    exit 0;
fi;


export LUATEX_DIR=`mktemp -d`

git clone --single-branch --depth 1 -b experimental https://github.com/tex-live/luatex ${LUATEX_DIR}

# Fix timestamping issues
find ${LUATEX_DIR} -name \*.info -exec touch '{}' \;
touch ${LUATEX_DIR}/source/texk/web2c/web2c/web2c-lexer.c
touch ${LUATEX_DIR}/source/texk/web2c/web2c/web2c-parser.c
touch ${LUATEX_DIR}/source/texk/web2c/web2c/web2c-parser.h

export LUATEX_VERSION=`grep luatex_version_string ${LUATEX_DIR}/source/texk/web2c/luatexdir/luatex.c | cut -d '"' -f 2`
export LUATEX_SVN_REVISION=`grep -Eo "[0-9]+" ${LUATEX_DIR}/source/texk/web2c/luatexdir/luatex_svnversion.h`

echo "Building LuaTeX ${LUATEX_VERSION} ${LUATEX_SVN_REVISION}"

sudo docker run \
    -e JOBS_IF_PARALLEL=`nproc` \
    -v ${LUATEX_DIR}:/luatex -w /luatex \
    -it debian:jessie sh -c \
    "apt-get update; apt-get install -y --no-install-recommends bash gcc g++ make; ./build.sh --parallel --jit --debugopt"

cp ${LUATEX_DIR}/build/texk/web2c/luatex bin/x86_64-linux/luatex
cp ${LUATEX_DIR}/build/texk/web2c/luajittex bin/x86_64-linux/luajittex

git add bin/x86_64-linux/luatex bin/x86_64-linux/luajittex
git commit --no-gpg-sign --quiet --allow-empty -m "Update LuaTeX"

# Prepare tlpkg
mkdir -p tlpkg/tlpsrc
rsync -avzP --delete --exclude=.svn tug.org::tldevsrc/Master/tlpkg/tlpsrc/00texlive.autopatterns.tlpsrc \
                                           ::tldevsrc/Master/tlpkg/tlpsrc/00texlive.config.tlpsrc \
                                           ::tldevsrc/Master/tlpkg/tlpsrc/00texlive.installation.tlpsrc \
                                           ::tldevsrc/Master/tlpkg/tlpsrc/luatex.tlpsrc \
                                           tlpkg/tlpsrc/
rsync -avzP --delete --exclude=.svn tug.org::tldevsrc/Master/tlpkg/bin \
                                           ::tldevsrc/Master/tlpkg/installer \
                                           ::tldevsrc/Master/tlpkg/TeXLive \
                                           tlpkg/

# Prepare target directory
rm -rf tlnet/
mkdir -p tlnet/

# Build
perl tlpkg/bin/tl-update-tlpdb -from-git -master "${PWD}" -save-anyway
sed -z -i "s/revision/@/g; s/\(name luatex[^@]*@ \)[0-9]*/\1${LUATEX_SVN_REVISION}/g; s/@/revision/g" tlpkg/texlive.tlpdb
perl tlpkg/bin/tl-update-containers -master "${PWD}" -location "${PWD}/tlnet" -all -recreate -no-sign

# Deploy the tree
cd tlnet/
touch .nojekyll
git init
git checkout -b gh-pages
git add .
git commit --no-gpg-sign --quiet -m "Deploy LuaTeX ${LUATEX_VERSION}-svn${LUATEX_SVN_REVISION}"
git remote add origin https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}
git push -f origin gh-pages
