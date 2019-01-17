#!/bin/bash

echo "================================================================="
echo " NB! Make sure you have a running Camarero app:"
echo ""
echo "      mix clean && mix run --preload-modules --no-halt"
echo "================================================================="
echo ""

# https://github.com/wg/wrk

echo " Performing 10 sec POSTs and 5 sec GETs afterwards."
echo " This will INSERT 300K key-values approx and READ 200K approx."
echo ""
echo "================================================================="
echo ""
# POSTs
wrk -t24 -c1000 -s post.lua -d10s http://127.0.0.1:4001/api/v1/crud
# GETs
wrk -t24 -c1000 -s get.lua -d5s http://127.0.0.1:4001/api/v1/crud

echo ""
echo "================================================================="
echo ""
echo " Performing 10 sec POSTs and 5 sec DELETEs afterwards."
echo " This will INSERT 300K key-values approx and DELETE 200K approx."
echo ""
echo "================================================================="
echo ""
# POSTs
wrk -t24 -c1000 -s post.lua -d10s http://127.0.0.1:4001/api/v1/crud
# DELETEs
wrk -t24 -c1000 -s delete.lua -d5s http://127.0.0.1:4001/api/v1/crud
echo ""
echo "================================================================="
echo ""

