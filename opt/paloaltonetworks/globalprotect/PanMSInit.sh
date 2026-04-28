#!/bin/bash

PANGPA=/opt/paloaltonetworks/globalprotect/PanGPA

pgrep -u $USER PanGPA > /dev/null 2>&1

if [ $? -ne 0 ]; then
  if [ -f $PANGPA ]; then 
    $PANGPA start &
  fi
fi
