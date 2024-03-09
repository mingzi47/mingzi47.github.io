# clean
clean :
  hexo clean

# generate
generate : clean
  hexo generate

# deploy
deploy : generate
  git add . && git commit -m "$(date)" && git push
