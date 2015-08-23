#!/bin/sh

export CLASSPATH=./lib/java:$CLASSPATH
GEM_HOME=./gem jruby -rubygems -Isrc -J-Dfile.encoding=utf-8 "$@"
