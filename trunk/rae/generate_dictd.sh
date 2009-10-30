#!/bin/bash
set -e

remove_html_tags() { sed "s/<[^>]*>//g"; }
remove_leading_blank_lines() { sed '/./,$!d'; } 

generate_input() {
  local DIRECTORY=$1
  
  find "$DIRECTORY" -type f -name '*.html' | while read HTMLFILE; do
    WORD=$(basename "$HTMLFILE" ".html")
    DEFINITION=$(cat "$HTMLFILE" | remove_html_tags | remove_leading_blank_lines)
    echo ":$WORD:$DEFINITION"
  done
}

generate_dict() {
  local DIRECTORY=$1
  local NAME=$2  
  
  generate_input "$DIRECTORY" | 
    dictfmt -j --locale "es_ES.utf8" --without-headword -s "$NAME" "$NAME"
  dictzip $NAME.dict
  echo "$NAME.index"
  echo "$NAME.dict.dz"
}

generate_dict "drae2.2" "drae"