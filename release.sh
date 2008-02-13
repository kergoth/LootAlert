#!/bin/sh
project=$1
shift
version=$1
shift
repo=$1
if [ -z "$repo" ]; then
    repo="origin"
fi
shift

#alias git="echo git"

#if [ -e "${project}.toc" ]; then
#    sed -i -e"s,^## Version: .*$,## Version: ${version}," ${project}.toc
#    git commit -a -m"Prepare for the ${version} release."
#fi

echo "Tagging version ${version} of ${project}.."
git tag $@ -a -m "Tag version ${version}." v${version}
echo "Archiving to ${project}-${version}.zip.."
git archive --format=zip --prefix=${project}/ v${version} > ${project}-${version}.zip
sha1=$(git hash-object -w ${project}-${version}.zip)
git update-ref refs/archives/${project}-${version}.zip $sha1
rm -f ${project}-${version}.zip
echo "Pushing archive ref and tag to $repo.."
git push $repo +refs/archives/${project}-${version}.zip
git push --tags $repo
