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

min ()
{
  if (( "$1" > "$2" )); then 
    echo "$2"
  else
    echo "$1"
  fi
}

max ()
{
  if (( "$1" > "$2" )); then
    echo "$1"
  else
    echo "$2"
  fi
}

MAX_JOBS=10
IFS=$'\n'

number="$1"
book="\/book\/\d+/\d+\/ready_new"

if [[ "$1" =~ ^-h$ || "$1" =~ ^--help$ ]]; then
  show_help
  exit
fi

if ! [[ "$1" =~ ^\d+$ ]]; then
  echo "book number is NaN. "
  exit 1;
fi

if [ -z "$number" ]; then
  echo "book number didn't recive. " >&2
  exit 1;
fi

main_page=$(curl --silent "https://tl.rulate.ru/book/$number")
chapters=$(echo "$main_page" | rg -P -o "href='$book'\>[^\<]+")
rulate_count=$(echo "$main_page" | rg -A5 "Размер перевода:" | head -n 3 | tail -n 1 | rg -P -o "\d(\d| )+" | sed "s/ //g")
load_count=$(echo "$chapters" | wc -l)

if [ "$rulate_count" -ne "$load_count" ]; then 
  echo "failed parse count. Try edit regex." >&2
  exit 1
fi

echo "Chapter count: $load_count"
echo "Select [0 and $(("$load_count" - 1))]"

ans="n"

while [ "$ans" != "y" ]; do

  echo -n "from chapter: "
  read -r from

  if (( "$from" >= "$load_count" )); then
    echo "from index is more or equal chapter count." >&2
    exit 1
  fi

  if (( "$from" < 0 )); then 
    echo "from index less than zero." >&2
    exit 1
  fi
  
  off=$(min 3 $(("$load_count" - "$from")) )
  off=$(max "$off" 0)
  echo -n "* "
  get_name "$chapters" | head -n $(("$from" + "$off")) | tail -n "$off"

  echo -n "Ok? y/n: "
  read -r ans
  printf "\n"

done

ans="n"

while [ "$ans" != "y" ]; do

  echo -n "to chapter: "
  read -r to

  if (( "$to" < 0 )); then
    echo "to less than 0." >&2
    exit 1
  fi
  
  selected=$(echo "$chapters" | head -n $(("$to" + 1)) | tail -n 3)
  get_name "$selected" | head -n $(($(echo "$selected" | wc -l) - 1))
  echo -n "* "
  get_name "$selected" | tail -n 1

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
  if (( "$counter" > "$to" )); then break; fi
  if (( "$counter" < "$from" )); then
    counter=$(("$counter" + 1))
    continue; 
  fi

  if (( "$(jobs | rg "Running" | wc -l)" >= "$MAX_JOBS" )); then
    sleep 1;
  fi

  chapter_link=$(get_link "$i")
  chapter_name=$(get_name "$i")

  chapter_html=$(curl --silent "$chapter_link")
  num=$(printf %0"$len"d "$counter")
  name="${num}: ${chapter_name}.pdf"
  echo "$chapter_html" | ( wkhtmltopdf --encoding UTF-8 -q - "$name" &> /dev/null; \
    print_status_load "$(("$counter" - "$from" + 1))" "$count_to_load" "$name" ) &

  counter=$(("$counter" + 1))
done

while [ -n "$(jobs | rg -o "Running")" ]; do
  sleep 1;
done
