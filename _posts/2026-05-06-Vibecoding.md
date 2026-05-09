---
title: Vibe coding
author: JDLihoo
date: 2026-05-06
category: Jekyll
layout: post
---
# claude code

## 安装 配置
```
yum install nodejs
node -v
npm install -g @anthropic-ai/claude-code

vim ~/.claude.json
# "hasCompletedOnboarding":true,

vim ~/.claude/settings.json

``` 

## 多项目统一处理
```
/add-dir /path/to/other/project
```

## 下载安装CC-switch
> https://github.com/farion1231/cc-switch/releases/tag/v3.14.1  
> https://docs.packyapi.com/docs/ccswitch/#cc-switch%E4%BB%8B%E7%BB%8D

```
sudo dpkg -i CC-Switch-v3.14.1-Linux-x86_64.deb
sudo apt update
sudo apt install -f
sudo dpkg -i CC-Switch-v3.14.1-Linux-x86_64.deb

# 乱码问题
sudo apt install fonts-noto-cjk
fc-cache -fv
```

`cc-switch`
