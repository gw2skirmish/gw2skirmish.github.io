#!/usr/bin/env sh

# variables
init_var() {
    SRC="."
    DST="."
    GW2_WORLDS_URL="https://api.guildwars2.com/v2/worlds?ids=all"
    GW2_WORLDS_FILE="$DST/worlds.json"
    GW2_MATCHES_URL="https://api.guildwars2.com/v2/wvw/matches?ids=all"
    GW2_MATCHES_FILE="$DST/matches.json"
    #worlds_json="$(jq --compact-output '.[]' "$GW2_WORLDS_FILE")"
    #matches_json="$(jq --compact-output '.[]' "$GW2_MATCHES_FILE")"
}

# functions
load_json() {
#	[ -f "$GW2_WORLDS_FILE" ] || \
	wget --quiet --output-document="$GW2_WORLDS_FILE" "$GW2_WORLDS_URL"
#	[ -f "$GW2_MATCHES_FILE" ] || \
	wget --quiet --output-document="$GW2_MATCHES_FILE" "$GW2_MATCHES_URL"
	worlds_json="$(jq --compact-output '.[]' "$GW2_WORLDS_FILE")"
	matches_json="$(jq --compact-output '.[]' "$GW2_MATCHES_FILE")"
    touch objectives.jsonl
    touch guilds.jsonl
}

delete_json() {
	rm $GW2_WORLDS_FILE
	rm $GW2_MATCHES_FILE
}

update_objectives_json() {
  objectives="$(
    for match_json in $matches_json; do
      matchid="$(echo "$match_json" | jq -r '.id')"
        echo "$match_json" \
        | jq -c '
          .maps[].objectives[]
          |select(.type|contains("Keep","Tower","Camp"))
          |select(.claimed_by!=null)
          |{"id":"matchid","owner":.owner,"guild":.claimed_by}
        ' \
        | sed "s/matchid/$matchid/g" \
        | sort \
        | uniq -c \
        | sed 's/ {"id"/,"id"/g' \
        | sed 's/^ */{"count":/g' \
        | jq -sc '
          sort_by(
            .id,
            .color,
            .count
          )
          | .[]
          | {
            "id":.id,
            "owner":.owner,
            "guild":.guild,
            "count":.count
          }
        '
    done
  )"
  for objective in $objectives; do
    id="$(echo $objective | cut -d'"' -f4)"
    owner="$(echo $objective | cut -d'"' -f8)"
    guild="$(echo $objective | cut -d'"' -f12)"
    count="$(echo $objective | cut -d'"' -f15 | tr -d ' :}{')"
    result="$(
      grep "$guild" objectives.jsonl \
      | grep "$owner" \
      | grep "\"id\":\"$id\""
    )"
    if [ -z "$result" ]; then
      echo "$objective" >> objectives.jsonl
      if [ -z "$(grep $guild guilds.jsonl)" ]; then 
        echo "New guild: https://api.guildwars2.com/v2/guild/$guild"
        guildinfo="$(curl -s "https://api.guildwars2.com/v2/guild/$guild")"
        echo "$guildinfo" | jq -c >> guilds.jsonl
        echo "$guildinfo" | jq -c [.name,.tag]
      fi
    else
      resultcount="$(echo $result | cut -d'"' -f15 | tr -d ' :}{')"
      newcount="$(( resultcount + count ))"
      newresult="$(echo "{\"id\":\"$id\",\"owner\":\"$owner\",\"guild\":\"$guild\",\"count\":$newcount}")"
      sed -i "s/$result/$newresult/g" objectives.jsonl || echo "DEBUG: $result"
    fi
  done
}

display_guild_ids() {
  echo '<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>GW2Claims</title>
<link rel="stylesheet" href="https://cdn.simplecss.org/simple.min.css">
</head>

<body>
<header>
<h1><a href="./">GW2Claims 🚩</a></h1>
<nav>
<a href="#help">Help ❓</a>
<a href="https://github.com/gw2skirmish/gw2skirmish.github.io">GitHub 🙀</a>
<a href="../">GW2Skirmish 🏅</a>
<br>
<a href="#1-1">T1 🇺🇸</a>
<a href="#1-2">T2 🇺🇸</a>
<a href="#1-3">T3 🇺🇸</a>
<a href="#1-4">T4 🇺🇸</a>
<br>
<a href="#2-1">T1 🇪🇺</a>
<a href="#2-2">T2 🇪🇺</a>
<a href="#2-3">T3 🇪🇺</a>
<a href="#2-4">T4 🇪🇺</a>
<a href="#2-5">T5 🇪🇺</a>
</nav>
</header>
<main>
<article id="help">
<h2>Help ❓</h2>
<p>Numbers on the left of the Guild name is a Claim Score. Every 5 minutes, if a guild holds one or multiple claims, the score will go up by that amount.</p>
<p>Look for your friends and foes by using your browser search: <kbd>Ctrl</kbd> + <kbd>F</kbd></p>
<p><a href="https://en-forum.guildwars2.com/topic/131928-gw2claims-and-gw2skirmish-tools-for-wvw/">Join the forums</a> if you wish to share your thoughts.</p>'
#echo '<details><summary>Beta Week 2 matches changes</summary><img src="https://cdn.discordapp.com/attachments/872791478345281588/1119252536109572156/zYoPDQJuowAAAAASUVORK5CYII.png" /></details>'
echo '</article>'
  for match_json in $matches_json; do   
    id=$(echo "$match_json" | jq -r .id);
    echo "<article><h2 id=\""$id"\">"$id"</h2>"
    for owner in Red Blue Green; do
      echo "<details open id=\"$id$owner\"><summary>"$id" "$owner"</summary><pre>"
      list="$(
        grep \"$id\" objectives.jsonl | grep "$owner" | sort | jq -sc 'sort_by(.count)|reverse|.[]'
      )"
      for line in $list; do 
        guildfilter="$(echo $line | cut -d'"' -f12)"
        count="$(echo $line | cut -d'"' -f15 | tr -d ' :}{')"
        guildname="$(grep $guildfilter guilds.jsonl \
        | cut -d'"' -f 8,12-13 \
        | sed 's/"[,}]$/]/g' \
        | sed 's/"/ [/g' \
        #| sed 's/  */ /g' \
        #| sed 's/^ *//g' \
        )"
        #name_dashed="$(echo $guildname|cut -d'[' -f1|tr ' ' '-'|sed 's/-$//g'|tr [:upper:] [:lower:])"
        #printf "<img src="https://guilds.gw2w2w.com/guilds/$name_dashed/32.svg" width=32 height=32 />"
        printf "$count\t$guildname\n"
        #printf "<br>"
      done
      echo "</pre></details>"
    done
    echo "</article>"
  done
  echo '</main>
<footer>
<p>Fin.</p>
</footer>
</body>
</html>'
}

build_html() {
  display_guild_ids > index.html.tmp
#  sed -i "s/2-1 Red/2-1 Red Moogooloo/g" index.html.tmp
#  sed -i "s/2-1 Blue/2-1 Blue Skrittsburgh/g" index.html.tmp
#  sed -i "s/2-1 Green/2-1 Green Stonefall/g" index.html.tmp
#  sed -i "s/2-2 Red/2-2 Red Grenth's Door/g" index.html.tmp
#  sed -i "s/2-2 Blue/2-2 Blue Fortune's Vale/g" index.html.tmp
#  sed -i "s/2-2 Green/2-2 Green Thornwatch/g" index.html.tmp
#  sed -i "s/2-3 Red/2-3 Red Silent Woods/g" index.html.tmp
#  sed -i "s/2-3 Blue/2-3 Blue Reaper's Corridor/g" index.html.tmp
#  sed -i "s/2-3 Green/2-3 Green Titan's Staircase/g" index.html.tmp
#  sed -i "s/2-4 Red/2-4 Red Griffonfall/g" index.html.tmp
#  sed -i "s/2-4 Blue/2-4 Blue Phoenix Dawn/g" index.html.tmp
#  sed -i "s/2-4 Green/2-4 Green Giant's Rise/g" index.html.tmp
#  sed -i "s/2-5 Red/2-5 Red Dragon's Claw/g" index.html.tmp
#  sed -i "s/2-5 Blue/2-5 Blue Seven Pines/g" index.html.tmp
#  sed -i "s/2-5 Green/2-5 Green First Haven/g" index.html.tmp
#  
#  sed -i "s/1-1 Green/1-1 Green Dragon's Claw/g" index.html.tmp
#  sed -i "s/1-1 Blue/1-1 Blue Skrittsburgh/g" index.html.tmp
#  sed -i "s/1-1 Red/1-1 Red First Haven/g" index.html.tmp
#  sed -i "s/1-2 Green/1-2 Green Phoenix Dawn/g" index.html.tmp
#  sed -i "s/1-2 Blue/1-2 Blue Stonefall/g" index.html.tmp
#  sed -i "s/1-2 Red/1-2 Red Moogooloo/g" index.html.tmp
#  sed -i "s/1-3 Green/1-3 Green Seven Pines/g" index.html.tmp
#  sed -i "s/1-3 Blue/1-3 Blue Titan's Staircase/g" index.html.tmp
#  sed -i "s/1-3 Red/1-3 Red Giant's Rise/g" index.html.tmp
#  sed -i "s/1-4 Green/1-4 Green Reaper's Corridor/g" index.html.tmp
#  sed -i "s/1-4 Blue/1-4 Blue Thornwatch/g" index.html.tmp
#  sed -i "s/1-4 Red/1-4 Red Griffonfall/g" index.html.tmp
  mv index.html.tmp index.html
}

# commands
init_var
echo "Loading Matches..."
load_json
echo "Updating Objectives..."
update_objectives_json
echo "Building HTML..."
build_html
echo "Done"

timerloop() {
  sec=300
  $1
  while [ $sec -gt 0 ]; do 
    sec=$((sec-1))
    echo $sec
    sleep 1
    if [ $sec -eq 0 ]; then 
      sec=300
      $1
    fi
  done
}

repeatafterfivemin() {
  while [ 1 ]; do
    time $1
    date -d5min +"Next update @ %T"
    echo "Sleeping for 5 minutes"
    sleep 300
  done
}
#repeatafterfivemin ./gw2claims.sh
