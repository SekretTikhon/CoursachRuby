#!/usr/bin/env bash

CODE_GENERATOR_PID=/tmp/remote_service_code_generator.pid

check_before_start(){
    if [ -f $CODE_GENERATOR_PID ]; then
        pid_that_running=`cat $CODE_GENERATOR_PID`
        if kill -0 $pid_that_running > /dev/null 2>&1; then
            echo "Code generator already running with pid $pid_that_running"
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
    nohup ./scripts/CodeGenerator.rb &
    pid=$!
    echo $pid > ${CODE_GENERATOR_PID}
    ;;

(stop)
    if [ -f $CODE_GENERATOR_PID ]; then
        pid_to_kill=`cat $CODE_GENERATOR_PID`
        if kill -0 $pid_to_kill > /dev/null 2>&1; then
            kill $pid_to_kill > /dev/null 2>&1
            echo "Code generator stoped (pid=$pid_to_kill)"
        else
            echo "Code generator cannot stop, becase server (pid=${pid_to_kill}) not running"
        fi
    else
        echo "Code generator cannot stop, becase pid file ($CODE_GENERATOR_PID) does not exist"
    fi
    ;;

(*)
    echo $usage
    exit 1
    ;;
esac