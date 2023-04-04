#!/bin/zsh
echo -e "\e[032m START ... \e[0m"

message=$(date)

checkcommit() {
  lastmessage="git status ""$1"" | tail -n 2"
  if [[ $lastmessage =~ "nothing to commit" ]]; then
    return 0
  fi
  return 1
}

check() {
  if [[ $? != 0 ]]; then
    echo -e "\e[031m ERROR : $1 , Log : Temp/deploy.log \e[0m"
    exit 1
  fi
  echo -e "\e[032m SUCESS : $1 ! \e[0m"
}

if [[ ! -d "Temp/" ]]; then
  mkdir -p Temp
  if [[ $? != 0 ]]; then
    echo -e "\e[031m mkdir Temp failed ! \e[0m"
  fi
fi

if [[ ! -f ".gitignore" ]]; then
  touch .gitignore
  check "touch .gitignore"
fi

grep Temp .gitignore > Temp/deploy.log 2>&1

if [[ $? != 0 ]]; then
  echo '\nTemp/' >> .gitignore
fi

hexo clean > Temp/deploy.log 2>&1

check "hexo clean"

hexo g > Temp/deploy.log 2>&1

check "hexo g"

if [[ $(checkcommit '.deploy_git') == 1 ]]; then
  hexo d > Temp/deploy.log 2>&1
  check "hexo d"
else
  echo -e "\e[33m SKIP : hexo d, nothing to commit\e[0m"
fi

git add . > Temp/deploy.log 2>&1

check "git add . "

if [[ $(checkcommit '.') == 1 ]]; then
  git commit -m "$message" > Temp/deploy.log 2>&1
  check "git commit"
else
  echo -e "\e[33m SKIP : git commit, nothing to commit\e[0m"
fi

git push > Temp/gitpush.log  2>&1

check "git push"
