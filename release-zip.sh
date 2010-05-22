#!/bin/sh
set -e

tagprefix=release/
version=`git for-each-ref --sort=-taggerdate --count=1 --format='%(refname)' refs/tags/$tagprefix | sed -e "s,^refs/tags/$tagprefix,,"`
git archive --format=zip --prefix LootAlert/ -o LootAlert-$version.zip $tagprefix$version
