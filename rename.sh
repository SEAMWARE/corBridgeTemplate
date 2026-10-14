#!/usr/bin/env bash
#
# rename.sh <name> - make this template the bridge <name>
#
#   ./rename.sh opcua    ->  corOpcuaBridge: opcua.so, alias "opcua", src/opcuaRegister.c, opcuaInit(), ...
#
# <name> is the bridge's alias - what --bridges and the --bridgeConfig file call it - so lowercase
# letters and digits, starting with a letter. Every tmpl / Tmpl / TMPL in the repo becomes
# <name> / <Name> / <NAME>, corBridgeTemplate becomes cor<Name>Bridge, files named tmpl* are renamed,
# the README loses its "from this template" section, and this script removes itself.
#
# Run it in a fresh copy of the template; the repo's own git history (if any) is left alone.
#
# Copyright 2026 Seamware
# SPDX-License-Identifier: Apache-2.0
#
set -euo pipefail

name=${1:-}
if ! [[ "$name" =~ ^[a-z][a-z0-9]*$ ]]; then
  echo "usage: $0 <name> - lowercase letters and digits, starting with a letter (e.g. opcua, ckan, hue)" >&2
  exit 1
fi

if [ "$name" = tmpl ]; then
  echo "$0: 'tmpl' is the template's own name" >&2
  exit 1
fi

cd "$(dirname "$0")"
self=$(basename "$0")

[ -f src/tmplRegister.c ] || { echo "$0: no src/tmplRegister.c - renamed already?" >&2; exit 1; }

#
# A copy of the template's checkout carries its .git: the template's history, and an origin that pushes
# to corBridgeTemplate
#
if origin=$(git config --get remote.origin.url 2>/dev/null) && [[ "$origin" == *corBridgeTemplate* ]]; then
  echo "$0: warning: this checkout's origin is the template ($origin) - a push goes there." >&2
  echo "  start from an export instead: git -C corBridgeTemplate archive HEAD | tar -x -C <new dir>; git init" >&2
fi

Name="$(tr '[:lower:]' '[:upper:]' <<< "${name:0:1}")${name:1}"
NAME=$(tr '[:lower:]' '[:upper:]' <<< "$name")
repo="cor${Name}Bridge"

make -s clean > /dev/null 2>&1 || true

#
# The README: the section about using the template goes
#
sed -i '/<!-- template:start -->/,/<!-- template:end -->/d' README.md

#
# Contents: every text file but this script, the licence and .git
#
grep -rlI --exclude-dir=.git --exclude="$self" --exclude=LICENSE -e tmpl -e Tmpl -e TMPL -e corBridgeTemplate -e CORBRIDGETEMPLATE . \
  | while read -r file; do
      sed -i -e "s/corBridgeTemplate/$repo/g" \
             -e "s/CORBRIDGETEMPLATE/COR${NAME}BRIDGE/g" \
             -e "s/tmpl/$name/g" \
             -e "s/Tmpl/$Name/g" \
             -e "s/TMPL/$NAME/g" "$file"
    done

#
# File names
#
find . -path ./.git -prune -o -name '*tmpl*' -print | sort -r | while read -r path; do
  dir=$(dirname "$path")
  base=$(basename "$path")
  mv "$path" "$dir/${base//tmpl/$name}"
done

rm -f "$self"

echo "$repo: renamed from the template - $name.so, alias '$name'"
echo
echo "  make            build it"
echo "  make test       a broker loads it and moves a value both ways"
echo "  grep -rn TODO   where your protocol goes"
