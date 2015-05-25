#!/bin/bash

pipefile="out.pipe"
nc_args="-l 1234"

function utils {
    bash ./utils/$@
}

while test $# -gt 0; do
    case $1 in
        * )
            nc_args=$@
            break    
        ;;
    esac
    shift
done

echo "running netcat-httpd server : $nc_args"

rm -f $pipefile
mkfifo $pipefile
trap "rm -f out" EXIT
while true
do
  cat $pipefile | nc $nc_args > >( # parse the netcat output, to build the answer redirected to the pipe "out".
    export REQUEST=
    while read line
    do
      line=$(echo "$line" | tr -d '[\r\n]')

      if echo "$line" | grep -qE '^GET /' # if line starts with "GET /"
      then
        REQUEST=$(echo "$line" | cut -d ' ' -f2) # extract the request
      elif [ "x$line" = x ] # empty line / end of request
      then
        # call a script here
        # Note: REQUEST is exported, so the script can parse it (to answer 200/403/404 status code + content)
        utils route $REQUEST > $pipefile
      fi
    done
  )
done
