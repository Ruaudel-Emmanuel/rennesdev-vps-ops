#!/bin/bash
# credential helper git : PAT lu depuis /etc/vps-github.env (jamais affiché en session)
# ordre 13/11 19:16 — utilisé par git push (tourné en root, le fichier env est 600 root:root)
test "$1" = "get" || exit 0
. /etc/vps-github.env
[ -n "${GH_PAT:-}" ] && echo "username=ruaudel-dev" && echo "password=$GH_PAT"
