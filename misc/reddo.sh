#!/bin/sh

cd `dirname "$0"`
SCRIPT_DIR=$(cd "$CDIR"; pwd)

cd "$SCRIPT_DIR"
java -Dfile.encoding=utf-8 -Xmx1g -splash:splash.png -jar reddo.jar "$@"
