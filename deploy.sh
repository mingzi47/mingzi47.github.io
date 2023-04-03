#!/bin/bash

message=$(date)
hexo clean && hexo g && hexo d && git add . && git commit -m "$message" && git push
