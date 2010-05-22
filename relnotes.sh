#!/bin/bash
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
    if [ -z "$body" ]; then
        subject=%(subject)
        if [ -n "$subject" ]; then
            echo "    - $subject"
        fi
    else
        git for-each-ref --format="%%(body)" $ref | sed -e "$stripsig; /^ *$/d; s/^  */      /; s/^\([^ ]\)/    - \1/;"
    fi
fi
'

echo "LootAlert Release Notes"
echo
eval=`git for-each-ref --shell --format="$fmt" \
--sort=-taggerdate \
refs/tags/release`
eval "$eval"
