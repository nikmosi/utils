#!/bin/bash

show_help ()
{
cat <<- _EOF_
  tlrulate --help
    show this text.
  tlrulate <book number>
    start loading dialoge.
_EOF_
}

main ()
{
  local data 

  data=$2

  if (( "$1" >= "$load_count" )); then
    echo "$1 index is more or equal chapter count." >&2
    exit 1
  fi
  if (( "$1" < 0 )); then 
    echo "$1 index less than zero." >&2
    exit 1
  fi

  i=0 
  offset=2
  for c in $chapters; do
    diff=$(( i - data ))
    diff=${diff/-/}
    if (( diff > offset )); then 
      (( i++ ))
      continue;
    fi

    if (( diff == 0 )); then 
      echo -n "* "
    fi

    get_name "$c"

    (( i++ ))
  done
}

get_link () 
{
  echo "$1" | rg -P -o "'[^\>]+" | sed "s/'//g" | sed "s/^/https:\/\/tl.rulate.ru/"
}

get_name ()
{
  echo "$1" | rg -P -o "\>.*" | sed "s/>//"
}

# loaded_count / count / name
print_status_load () 
{
  printf "% ${len}d/%s | '%s'\n" "$1" "$2" "$3"
}

MAX_JOBS=10
IFS=$'\n'

number="$1"
book="\/book\/\d+/\d+\/ready_new"

if [[ "$1" =~ ^-h$ || "$1" =~ ^--help$ ]]; then
  show_help
  exit
fi

if ! [[ "$1" =~ ^[0-9]+$ ]]; then
  echo "book number is NaN. " >&2
  exit 1;
fi

if [ -z "$number" ]; then
  echo "book number didn't recive. " >&2
  exit 1;
fi

main_page=$(curl -H 'cookie: mature=c3a2ed4b199a1a15f5a5483504c7a75a7030dc4bi%3A1%3B;' --silent "https://tl.rulate.ru/book/$number")
chapters=$(echo "$main_page" | rg -P -o "href='$book'\>[^\<]+")
rulate_count=$(echo "$main_page" | rg -A5 "Размер перевода:" | head -n 3 | tail -n 1 | rg -P -o "\d(\d| )+" | sed "s/ //g")
load_count=$(echo "$chapters" | wc -l)
book_name=$(echo "$main_page" | rg -P "\<h1\>" | sed "s/<h1>\(.*\)<\/h1>/\1/")

if [ -z "$rulate_count" ] || [ -z "$load_count" ] || [ "$rulate_count" -ne "$load_count" ]; then 
  echo "failed parse count. Try edit regex." >&2
  exit 1
fi

echo "Name: $book_name"
echo "Chapter count: $load_count"
echo "Select [0 and $(("$load_count" - 1))]"

ans="n"
while [ "$ans" != "y" ]; do
  echo -n "from chapter: "
  read -r from 
  main "from" "$from"  

  echo -n "Ok? y/n: "
  read -r ans
  printf "\n"
done

ans="n"
while [ "$ans" != "y" ]; do
  echo -n "to chapter: "
  read -r to
  main "to" "$to"

  echo -n "Ok? y/n: "
  read -r ans
  printf "\n"
done

if (( "$from" > "$to" )); then 
  echo "from index is more then to index." >&2
  exit 1
fi

len=${#load_count}
count_to_load="$(("$to" - "$from" + 1))" 
counter=0
for i in $chapters; do 
  (( "$counter" > "$to" )) && break
  if (( "$counter" < "$from" )); then
    (( counter++ ))
    continue; 
  fi

  while (( "$(jobs | rg "Running" | wc -l)" >= "$MAX_JOBS" )); 
  do
    sleep 1;
  done

  chapter_link=$(get_link "$i")
  chapter_name=$(get_name "$i")

  num=$(printf %0"$len"d "$counter")
  name="${num}: ${chapter_name}.pdf"
  { curl -H 'cookie: mature=c3a2ed4b199a1a15f5a5483504c7a75a7030dc4bi%3A1%3B;' --silent "$chapter_link" | ( wkhtmltopdf --encoding UTF-8 -q - "$name" &> /dev/null; \
    print_status_load "$(("$counter" - "$from" + 1))" "$count_to_load" "$name" ) } &

  (( counter++ ))
done

while [ -n "$(jobs | rg -o "Running")" ]; do
  sleep 1;
done
