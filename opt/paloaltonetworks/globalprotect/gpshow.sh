#!/bin/bash

FILE_TO_SHOW=$1

if [ $# -eq 0 ]; then
    exit 1
fi
printf "\n"

# if parameter number is bigger than 1, check the build option
if [ $# -gt 1 ]; then
  if [ $2 == "content" ]; then
    cat $FILE_TO_SHOW
  elif [ $2 == "location" ]; then
    echo "The information is in "$FILE_TO_SHOW
  elif [ $2 == "saml-pre-login" ]; then
    echo "Try to launch default browser for saml login..."
  fi
fi

echo $DISPLAY | grep : > /dev/null 2>&1
if [ $? -eq 0 ]; then
  xdg-open $FILE_TO_SHOW > /dev/null 2>&1
else
  echo "There is not default browser to launch."
fi

