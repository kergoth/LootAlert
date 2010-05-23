#!/bin/sh
set -e

relnotes () {
    unset COMMAND_MODE

    fmt='
    stripsig="/^Signed-[oO]ff-[bB]y:/d"
    type=%(objecttype)
    ref=%(refname)
    tag="${ref#refs/tags/}"
    tag="$(basename $tag)"

    if [ "$type" = "tag" ]; then
        body=%(body)
        body="$(echo "$body" | sed -e "$stripsig")"
        echo "$tag:"
        subject=%(subject)
        if [ -n "$subject" ]; then
            echo "    - $subject"
        fi
        if [ -n "$body" ]; then
            git for-each-ref --format="%%(body)" $ref | sed -e "$stripsig; /^ *$/d; s/^  */      /; s/^\([^ ]\)/    - \1/;"
        fi
    fi
    '

    echo "$@"
    echo
    eval=`git for-each-ref --shell --format="$fmt" \
    --sort=-taggerdate \
    refs/tags/$tagprefix`
    eval "$eval"
}

tag () {
    msgfile=`mktemp --tmpdir release.$project.XXXXXX` || die "Unable to create msgfile"
    git rev-list $tagprefix$version.. | \
        git diff-tree --pretty='format:%s%n' --stdin -s | grep -iv "Update relnotes" | \
            grep -iv "update release notes" >$msgfile
    if [ $? -ne 0 ]; then
        rm "$msgfile"
        die "Unable to generate message for tag"
    fi

    git tag -a -f -F $msgfile $tagprefix$newversion
    rm "$msgfile"
    if [ $? -ne 0 ]; then
        die "Unable to create tag"
    fi
}

die () {
    echo >&2 "$@"
    exit 1
}

#if ! git update-index --ignore-submodules --refresh >/dev/null; then
if [ -n "`git status --porcelain|cut -d" " -f1|grep -v '?'`" ]; then
    die "Unable to release: you have uncommitted changes"
fi

project=`basename "$PWD"`
tagprefix=release/
version=`git for-each-ref --sort=-taggerdate --count=1 --format='%(refname)' refs/tags/$tagprefix | sed -e "s,^refs/tags/$tagprefix,,"`
baseversion=`echo $version | sed -e "s,^\(.*\)\..*$,\1,"`
newversion=`expr $baseversion + 1`
origref="`git rev-parse HEAD`"

if [ -z "`git rev-list $tagprefix$version..`" ]; then
    echo "No changes to include in the release"
    exit 3
fi

if [ -e "$project.toc" ]; then
    sed -i -e "s,^## Version:.*,## Version: $newversion" "$project.toc"
    git add $project.toc
    git ci -s -m"Update .toc Version to $newversion"
fi
echo Tagging version $newversion of $project
tag
relnotes "$project Release Notes" | unix2dos >RelNotes.txt || die "Unable to generate release notes"
git add RelNotes.txt
git ci -s -m"Update Release Notes for version $newversion"
tag
git archive --format=zip --prefix $project/ -o $project-$newversion.zip $tagprefix$newversion
git tag -d $tagprefix$newversion
git reset --hard $origref
