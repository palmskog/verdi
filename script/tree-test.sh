#!/usr/bin/env bash
./configure
time make -k -j 3 tree-test
