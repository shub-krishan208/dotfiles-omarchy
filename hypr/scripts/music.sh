

song_info=$(playerctl metadata --format '▶  {{title}} - {{artist}}')

if [[ "$(playerctl metadata --format {{artist}})" = "sane1090x" ]]; then
  song_info="❌No Music Player"
fi

echo "$song_info"
