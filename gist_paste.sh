# GIT_GIST_TOKEN

file_name="$1"
desc="create by script at $(date)"
content="$(jq -R -s < "$1")"

p1='{"description":"'
p3='","public":false,"files":{"'
p5='":{"content":'
p7='}}}'
data="${p1}${desc}${p3}${file_name}${p5}${content}${p7}"

ans=$(curl --silent -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GIT_GIST_TOKEN"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/gists \
  -d "$data")

url=$(echo "$ans" | jq -r ".html_url" -)

echo "$url"
echo "$url" | xclip -sel clip - 
