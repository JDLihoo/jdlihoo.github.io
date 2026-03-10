---
title: gala-anteater
author: JDLihoo
date: 2026-03-05
category: Jekyll
layout: post
published: false
---
# issue链接
https://atomgit.com/src-openeuler/gala-anteater/issues/27

# 解决方案

# 问题复现
创建一个新的repo
```
cat << EOF | sudo tee /etc/yum.repos.d/openEuler-update-temp.repo
[update_20260226]
name=openEuler-24.03-LTS-SP3-update_20260226
baseurl=https://dailybuild.openeuler.openatom.cn/repo.openeuler.org/openEuler-24.03-LTS-SP3/update_20260226/$(arch)/
enabled=1
gpgcheck=0
EOF
```
清除并更新缓存
```
sudo yum clean all
sudo yum makecache
```
安装 gala-anteater
```
yum install -y gala-anteater --disablerepo="*" --enablerepo="update_20260226"
```
验证安装来源
```
rpm -qi gala-anteater | grep "Build Host"
# 或者查看安装源
yum list installed gala-anteater
```

# 自验证
