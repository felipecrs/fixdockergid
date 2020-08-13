#!/bin/sh

exec fixdockergid "$(id -u)" "$(id -g)" "$@"
