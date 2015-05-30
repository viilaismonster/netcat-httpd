#!/bin/bash

arg0=$0
init_args=$@

pidfile="current.pid"
pipefile="out.pipe"
nc_args="-l 1234"
route_args="--mapping ./route_map"
utils_dir=$(dirname $0)/utils/


function utils {
    bash $utils_dir$@
}

debug=0
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
    echo "[$$] "$@ >> current.log
}

log "running netcat-httpd server pid = $$: $nc_args"
echo $$ > $pidfile

function pid_check {
  if [ ! -f $pidfile ] || [ "`cat $pidfile`" != "$$" ]; then
    log "pid changed!"
    return 1
  fi
}

qid=0
function listen {
  ! pid_check && return 999

  qid=$(($qid+1))

  log D "$qid enter listen"
  _pipe=$pipefile.$(($qid%5))
  log D "$qid open pipe file $_pipe"
  rm -f $_pipe
  mkfifo $_pipe
  # trap "rm -f $_pipe" EXIT
  forked=$1
  args=$@
  line_index=0;

  if [ $forked -eq 0 ] && [ $qid -gt 256 ]; then
    log D "$qid > 256, restart"
    (sleep 1 && $arg0 $init_args ) &
    return 1
  fi

  log D "$qid nc listening"
  cat $_pipe | nc $nc_args > >( # parse the netcat output, to build the answer redirected to the pipe "out".
    log D "$qid nc listening enter $?"
    # export REQUEST=
    REQUEST=
    RESPONSE=
    while read line
    do
      line_index=$(($line_index+1))
      log D "$qid $line_index. $line"

      if [ $forked -eq 0 ]; then
          # echo "fork when req $line"
          forked=1
          log D "$qid fork when first read"
          listen $args &
      fi
      line=$(echo "$line" | tr -d '[\r\n]')

      if echo "$line" | grep -qE '^GET /' # if line starts with "GET /"
      then
        REQUEST=$(echo "$line" | cut -d ' ' -f2) # extract the request
      elif [ "x$line" = x ] # empty line / end of request
      then
        log D "$qid pass REQUEST($REQUEST) to utils route"
        # call a script here
        # Note: REQUEST is exported, so the script can parse it (to answer 200/403/404 status code + content)
        utils route $route_args $REQUEST > $_pipe 2>> current.log
        RESPONSE=1
      fi
    done
    # echo "after request, forked = $forked"
    if [ $forked -eq 0 ]; then
      log D "$qid fork after io read"
      listen $args &
    fi
    log D "$qid nc listening exit"
    if [ "$RESPONSE" == "" ]; then
        log "$qid 500.no response"
        sleep 1
        echo "" > $_pipe
    fi
  )
  log D "$qid exit listen"
}

case `uname` in
    "Darwin" )
        listen 0 &
    ;;
    "Linux" )
        while true; do
            ! pid_check && break
            listen 1
            # ret=$?
            # log "listen return $ret"
        done
        log D "exit while"
    ;;
    * )
        echo "unknown os `uname`"
    ;;
esac


