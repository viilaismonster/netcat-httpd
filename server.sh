#!/bin/bash

function cd_to_root {
    if [ "$(dirname $0)" != "." ]; then
        echo "cd to $(dirname $0)"
        cd $(dirname $0)
        ./$(basename $0) $@
        exit
    fi
}

pidfile="current.pid"
pipefile="out.pipe"
nc_args="-l 1234"
route_args="--mapping ./route_map"
utils_dir=$(dirname $0)/utils/


function utils {
    bash $utils_dir$@
}

debug=0
init_args=$@
while test $# -gt 0; do
    case $1 in
        --mapping )
            shift
            route_args="--mapping $1"
        ;;
        --debug | -d )
            debug=1
        ;;
        - )
            shift
            nc_args=$@
            break            
        ;;
        * )
            nc_args=$@
            break    
        ;;
    esac
    shift
done

log "running netcat-httpd server pid = $$: $nc_args"
echo $$ > $pidfile


function log {
    case $1 in
        D )
            if [ $debug -eq 0 ]; then
                return
            fi
            # echo $@
        ;;
        * )
            echo $@
        ;;
    esac
    echo $@ >> current.log
}

qid=0
function listen {
  # pid check
  if [ ! -f $pidfile ] || [ "`cat $pidfile`" != "$$" ]; then
    log "exit due to pid check"
    return 999
  fi

  qid=$(($qid+1))
  _pipe=$pipefile.$(($qid%5))
  log D "qid $qid open pipe file $_pipe"
  rm -f $_pipe
  mkfifo $_pipe
  # trap "rm -f $_pipe" EXIT
  forked=$1
  args=$@
  cat $_pipe | nc $nc_args > >( # parse the netcat output, to build the answer redirected to the pipe "out".
    # export REQUEST=
    REQUEST=
    while read line
    do
      if [ $forked -eq 0 ]; then
          # echo "fork when req $line"
          forked=1
          log D "fork when first read"
          listen $args &
      fi
      line=$(echo "$line" | tr -d '[\r\n]')

      if echo "$line" | grep -qE '^GET /' # if line starts with "GET /"
      then
        REQUEST=$(echo "$line" | cut -d ' ' -f2) # extract the request
      elif [ "x$line" = x ] # empty line / end of request
      then
        # call a script here
        # Note: REQUEST is exported, so the script can parse it (to answer 200/403/404 status code + content)
        utils route $route_args $REQUEST > $_pipe 2>> current.log
      fi
    done
    # echo "after request, forked = $forked"
    if [ $forked -eq 0 ]; then
      log D "fork after io read"
      listen $args &
    fi
  )
}

case `uname` in
    "Darwin" )
        listen 0 &
    ;;
    "Linux" )
        while true; do
            listen 1
            if [ $? -eq 999 ]; then
                break
            fi
        done
    ;;
    * )
        echo "unknown os `uname`"
    ;;
esac


