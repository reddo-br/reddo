#!/bin/sh

cd `dirname "$0"`
SCRIPT_DIR=$(cd "$CDIR"; pwd)

java -Dfile.encoding=utf-8 -splash:splash.png "$SCRIPT_DIR"/reddo.jar
