#!/usr/bin/env bash

if [ ! "$BASH_VERSION" ] ; then
    echo "Please do not use sh to run this script ($0), just execute it directly" 1>&2
    exit 1
fi

set -o noclobber

# functions
parse_json () {
  value=$(echo "$1" | grep -Po '(?<="'"$2"'":)(\d*?|.*?[^\\])(?=,|})')
  value=${value//"\""/""}
  echo $value
}

parse_json_array () {
  values=$(echo "$1" | grep -Po '(?<="'"$2"'":\[)(\d*?|.*?[^\\])(?=])')
  values=${values//"\""/""}
  values=${values//,/" "}
  echo $values
}

main () {
  while true
  do
    echo -n "Enter search term: "
    read -r input_search_term
    if [[ -n $input_search_term ]]; then
      break
    fi
  done


  url="https://graphql.anilist.co"

  echo "Searching AniList API ($url) for \"$input_search_term\"..."

  result=$(curl --silent \
    --request POST \
    --url $url \
    --header 'accept: application/json' \
    --header 'content-type: application/json' \
    --data '{
    "query": "query ($search: String) { Page { media(search: $search) { id format title { english romaji } } } }",
    "variables": {
      "search": "'"$input_search_term"'"
    }
    }'
  )

  result=${result//" "/"^"}

  formats=($(parse_json $result "format"))
  english_titles=($(parse_json $result "english"))
  romaji_titles=($(parse_json $result "romaji"))

  echo "--Results--"
  number=0
  for line in ${formats[@]}
  do
    echo "($((number+1))): [${formats[$number]}] ${english_titles[$number]//"^"/" "} (${romaji_titles[$number]//"^"/" "})"
    ((number=number+1))
  done
  echo "-----------"

  while true
  do
    echo -n "Enter line number of desired work: "
    read -r input_number
    if [[ $input_number =~ [0-9]+ ]] && [[ $input_number -gt 0 ]] && [[ $input_number -le $((number)) ]]; then
      break
    fi
  done


  formatted_result="$(parse_json $result "id")"

  number=1
  for line in $formatted_result
  do
    if [ $number = $input_number ]; then
      target_line=$line
      break
    else
      ((number=number+1))
    fi
  done


  echo "Querying AniList API ($url) for media data with ID \"$target_line\"..."

  result=$(curl --silent \
    --request POST \
    --url $url \
    --header 'accept: application/json' \
    --header 'content-type: application/json' \
    --data '{
    "query": "query ($id: Int) { Media(id: $id) { format title { english romaji } status genres tags { name rank category} coverImage { extraLarge } } }",
    "variables": {
      "id": "'"$target_line"'"
    }
    }'
  )

  result=${result//" "/"^"}

  format=($(parse_json $result "format"))
  format=${format,,}
  format=${format^}

  if [ $format = 'Tv' ]; then
    format="Anime"
  fi

  english=($(parse_json $result "english"))
  english=${english//^/" "}

  romaji=($(parse_json $result "romaji"))
  romaji=${romaji//^/" "}

  status=($(parse_json $result "status"))
  status=${status,,}
  status=${status^}

  genres=($(parse_json_array $result "genres"))
  echo $genres

  tags=($(parse_json $result "name"))
  tags=${tags//^/" "}

  tag_ranks=($(parse_json $result "rank"))
  tag_ranks=${tag_ranks//^/" "}

  tag_categories=($(parse_json $result "category"))
  tag_categories=${tag_categories//^/" "}

  cover_image_url=($(parse_json $result "extraLarge"))
  cover_image_url=${cover_image_url//"\\"/""}
  cover_image_name="${english//" "/"_"}_cover.jpg"

  echo "Downloading cover image from $cover_image_url & saving as $cover_image_name..."
  wget -O $cover_image_name $cover_image_url

  number=0
  final_genres=""

  for genre in ${genres[@]}
  do
    final_genres+=$'\n  - '"${genre//"^"/" "}" # TODO fix separator?
  done

  number=0
  for tag in ${tags[@]}
  do
    if [ ${tag_ranks[$number]} -lt $RANK_THRESHOLD ]; then
      break
    else
      if [[ ${tag_categories[$number]} == "Theme-"* ]]; then
        final_genres+=$'\n  - '"${tag//"^"/" "}"' ' # TODO fix separator?
      fi
      ((number=number+1))
    fi
  done

  template="---
Medium: {0}
Original Title: {1}
Status:
Publishing Status: {2}
Genre:{3}
Cover: \"{4}\"
tags:
---
!{4}

### Thoughts:
-

"

  template=${template//"{0}"/$format}
  template=${template//"{1}"/\"$romaji\"}
  template=${template//"{2}"/$status}
  template=${template//"{3}"/$final_genres}
  template=${template//"{4}"/"[[$cover_image_name]]"}

  if [[ $english == "null" ]]; then
    title=$romaji
  else
    title=$english
  fi

  echo "Writing to file $title.md..."
  echo "$template" > "$title.md"
  echo "...done."
}

# constants
RANK_THRESHOLD=80


# main code
echo "- AniList parser for Obsidian -"

while true
do
  main
done
