#!/bin/bash
input=$(cat)
MODEL=$(echo "$input" | jq -r '.model.display_name')
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
RESETS_AT=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

if [ -n "$FIVE_H" ]; then
  PCT=$(printf '%.0f' "$FIVE_H")
  if [ "$PCT" -ge 85 ]; then
    COLOR="\033[31m"
  elif [ "$PCT" -ge 60 ]; then
    COLOR="\033[33m"
  else
    COLOR=""
  fi
  RESET="\033[0m"

  RESETS_LABEL=""
  if [ -n "$RESETS_AT" ]; then
    CLOCK=$(date -r "$RESETS_AT" "+%H:%M")
    RESETS_LABEL=" · $CLOCK"
  fi

  printf "[%s] ${COLOR}5h: %s%%${RESET}%s\n" "$MODEL" "$PCT" "$RESETS_LABEL"
else
  echo "[$MODEL]"
fi
