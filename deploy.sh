#!/bin/bash

message=$(date)
hexo clean && hexo g && hexo d && git add . && git commit -m "$message" && git push

hexoclean() {
  hexo clean > Temp/hexoclean.log
  return $?
}

hexogenerate() {
  hexo g > Temp/hexog.log
  return $?
}

gitadd() {
  git add . > Temp/gitadd.log
  return $?
}

gitcommit() {
  git commit -m "$message" > Temp/gitcommit.log
  return $?
}

gitpush() {
  git push > Temp/gitpush.log
  return $?
}

deploy() {
  if hexoclean; then
    echo "\032[32m !!success : hexo clean \033[0m"
    if hexogenerate; then
      echo "\032[32m !!success : hexo g \033[0m"
      if gitadd; then
        echo "\032[32m !!success : git add \033[0m"
        if gitcommit; then
          echo "\032[32m !!success : git commit \033[0m"
          if gitpush; then
            echo "\032[32m !!success : git push \033[0m"
          else
            echo "\033[31m !!ERROR : git push : Temp/gitpush.log\033[0m"
          fi
        else
          echo "\033[31m !!ERROR : git commit : Temp/gitcommit.log\033[0m"
        fi
      else
        echo "\033[31m !!ERROR : git add : Temp/gitadd.log\033[0m"
      fi
    else
      echo "\033[31m !!ERROR : hexo g , Log : Temp/hexog.log\033[0m"
    fi
  else
    echo "\033[31m !!ERROR : hexo clean , Log : Temp/hexoclean.log\033[0m"
  fi
} 

deploy


