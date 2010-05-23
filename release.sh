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
    if [ -z "$tagexists" ]; then
        git rev-list $tagprefix$version.. | \
            git diff-tree --pretty='format:%s%n' --stdin -s | grep -iv "Update relnotes" | \
                grep -iv "update release notes" >>$msgfile
        if [ $? -ne 0 ]; then
            rm "$msgfile"
            die "Unable to generate message for tag"
        fi
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

tagexists=""
project=`basename "$PWD"`
tagprefix=release/
version=`git for-each-ref --sort=-taggerdate --count=1 --format='%(refname)' refs/tags/$tagprefix | sed -e "s,^refs/tags/$tagprefix,,"`
baseversion=`echo $version | sed -e "s,^\(.*\)\..*$,\1,"`
origref="`git rev-parse HEAD`"

msgfile=`mktemp --tmpdir release.$project.XXXXXX` || die "Unable to create msgfile"
newversion="$1"
if [ -z "$newversion" ]; then
    if [ -z "`git rev-list $tagprefix$version..`" ]; then
        echo "No changes to include in the release"
        exit 3
    fi
    newversion=`expr $baseversion + 1`
elif git rev-parse -q --verify refs/tags/$tagprefix$newversion >/dev/null 2>&1; then
    tagexists="1"
    git for-each-ref --format='%(subject)
%(body)' refs/tags/$tagprefix$newversion >>$msgfile
    if [ $? -ne 0 ]; then
        rm "$msgfile"
        die "Unable to retrieve tag message"
    fi
fi

msgfile=`mktemp --tmpdir release.$project.XXXXXX` || die "Unable to create msgfile"
newversion="$1"
if [ -z "$newversion" ]; then
    newversion=`expr $baseversion + 1`
else
    tagexists="1"
    git for-each-ref --format='%(subject)
%(body)' $tagprefix$newversion >> $msgfile
    if [ $? -ne 0 ]; then
        rm "$msgfile"
        die "Unable to retrieve message for tag"
    fi
fi

if [ -e "$project.toc" ]; then
    sed -i -e "s,^## Version:.*,## Version: $newversion," "$project.toc"
    if [ -n "`git ls-files -m $project.toc`" ]; then
        git add $project.toc
        git commit -s -m"Update .toc Version to $newversion"
    fi
fi
tag
relnotes "$project Release Notes" | unix2dos >RelNotes.txt || die "Unable to generate release notes"
if [ -n "`git ls-files -m RelNotes.txt`" ]; then
    git add RelNotes.txt
    msg="Update Release Notes for version $newversion"
    if [ "`git show --pretty=%s -s`" = "$msg" ]; then
        git commit --amend -m "$msg"
    else
        git commit -s -m "$msg"
    fi

    echo Re-tagging version $newversion of $project to include release notes changes
    msgfile=`mktemp --tmpdir release.$project.XXXXXX` || die "Unable to create msgfile"
    tag
fi
git archive --format=zip --prefix $project/ -o $project-$newversion.zip $tagprefix$newversion
