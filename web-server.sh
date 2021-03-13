#!/usr/bin/env bash

WEB_SERVER_PID=/tmp/remote_service_web_server.pid

check_before_start(){
    if [ -f $WEB_SERVER_PID ]; then
        pid_that_running=`cat $WEB_SERVER_PID`
        if kill -0 $pid_that_running > /dev/null 2>&1; then
            echo "Server already running with pid $pid_that_running"
            exit 1
        fi
    fi
}

check_that_database_created(){
    ./scripts/CreateDB.rb ./config/settings.yml
}

usage="Usage: kekeke"

if [ $# -le 0 ]; then
    echo $usage
    exit 1
fi

startStop=$1
shift

case $startStop in

(start)
    #todo logs to file
    check_before_start
    check_that_database_created
    nohup rackup -p 8147 &
    pid=$!
    echo $pid > ${WEB_SERVER_PID}
    ;;

(stop)
    if [ -f $WEB_SERVER_PID ]; then
        pid_to_kill=`cat $WEB_SERVER_PID`
        if kill -0 $pid_to_kill > /dev/null 2>&1; then
            kill $pid_to_kill > /dev/null 2>&1
            echo "Server stoped (pid=$pid_to_kill)"
        else
            echo "Server cannot stop, becase server (pid=${pid_to_kill}) not running"
        fi
    else
        echo "Server cannot stop, becase pid file ($WEB_SERVER_PID) does not exist"
    fi
    ;;

(*)
    echo $usage
    exit 1
    ;;
esac