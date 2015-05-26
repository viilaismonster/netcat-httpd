netcat-httpd
============

accoring to `man nc`, it's common uses include

* shell-script based HTTP clients and servers

this a httpd server based on netcat  

## FEATURE

* GET and `bash` run a shell-cgi
* GET and `cat` a static file

partially tested under `OS X 10.9.5 Mavericks`

## SYNOPSIS  

`./server.sh [--mapping path_to_mapping_file] [--debug] [- nc_args]`


## DESCRIPTION  

`--mapping path_to_mapping_file`  
the default mapping_file is `./route_map`
a typical mapping_file looks like below

```
/get          ./api/get
/post         ./api/post
/static_file  -s ./static/static_file
```

alternatively, you can use `--mapping dynamic` for dynamic mapping rule  
fyi. static files are always mapped dynamically

`--debug | -d`  
normally, netcat-httpd will log output to `current.log` file,  
enable `--debug` option will output debug information such like pipe openting state to log file

`nc_args`  
check `man nc` for more detail  
useful examples  
`-l 80` listen on port 80


## EXAMPLE  

`$ ./server.sh --mapping dynamic -l 80`  
run server with port 80 using dynamic mapping rule
