#!/bin/sh

eval $( fixuid -q )

fixdockergid

exec "$@"