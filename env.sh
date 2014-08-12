#!/bin/sh
export PATH=/home/isu-user/local/perl-5.20/bin:$PATH
export PATH=/home/isu-user/local/ruby-2.1.2/bin:$PATH
export PATH=/home/isu-user/local/node-v0.10/bin:$PATH
export PATH=/home/isu-user/local/python-3.4.1/bin:$PATH
export PATH=/home/isu-user/local/go/bin:$PATH
export GOPATH=/home/isu-user/local/go/bin
export GOROOT=/home/isu-user/local/go
exec "$@"
