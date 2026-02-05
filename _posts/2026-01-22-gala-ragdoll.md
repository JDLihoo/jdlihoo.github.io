---
title: gala-ragdoll
author: JDLihoo
date: 2026-01-22
category: Jekyll
layout: post
published: false
---
# 安装gala-ragdoll
```
yum install gala-ragdoll
yum install python3-gala-ragdoll

yum install gala-spider
yum install python3-gala-spider

dnf install redis
systemctl start redis
systemctl status redis
systemctl restart gala-ragdoll
systemctl status gala-ragdoll

yum install zookeeper -y
systemctl start zookeeper

yum install kafka -y
```

##  配置gala-ragdoll
/etc/aops/conf.d/ragdoll.yml  
修改git信息，包括git仓的目录和用户信息  
创建/home/confTrace目录，在gitee上新建个confTrace仓库  
```
git:
  git_dir: "/home/confTrace"
  user_name: "JDLihoo"
  user_email: "2634544932@qq.com"
uwsgi:
  daemonize: "/var/log/aops/uwsgi/ragdoll.log"
  http-timeout: 600
  harakiri: 600
  processes: 1
  gevent: 100
  port: 11114
  buffer_size: 32768
serial:
  serial_count: 10
log:
  log_level: "INFO"
  log_dir: "/var/log/aops"
  max_bytes: 31457280
  backup_count: 40
```

## 查看日志
gala-ragdoll日志
```
less /var/log/aops/uwsgi/ragdoll.log 
journalctl -f -xeu gala-ragdoll.service
```
nginx日志
```
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

# 部署AOps
机器A 192.168.19.129    部署mysql、redis
机器B 192.168.19.132    部署mysql、aops-zeus、aops-hermes、
机器C 192.168.19.130	部署gala-ragdoll、

```
# 关闭防火墙

systemctl stop firewalld
systemctl disable firewalld
systemctl status firewalld
setenforce 0

#禁用SELinux

# 修改/etc/selinux/config文件中SELINUX状态为disabled

vi /etc/selinux/config
SELINUX=disabled

# 更改之后，按下ESC键，键盘中输入 :wq 保存修改的内容
注：此SELINUX状态配置在系统重启后生效。
```

先都安装aops-vulcanus：A-Ops工具库，除aops-ceres与aops-hermes模块外，其余模块须与此模块共同安装使用
```
yum -y install aops-vulcanus
```

各自自己安装各自的包
## 注意事项
### mysqld
```
vim /etc/my.cnf
# 注意将bind-address设置为0.0.0.0
```
## 机器A

## 机器B
```
yum install aops-zeus -y
# 这个配置好像没用上
vim /etc/aops/zeus.ini

# 启动aops-zeus，gala-ragdoll之类的service也是通过这种方式启停的
aops-cli service --name zeus
# 用的config在/etc/aops/aops-config.yml，附加上uwsgi配置

uwsgi:
  wsgi-file: manage.py
  daemonize: "/var/log/aops/uwsgi/zeus.log"
  http-timeout: 600
  harakiri: 600
  processes: 2
  gevent: 100

# 自动生成配置文件/opt/aops/uwsgi/zeus.ini
# 发现module=zeus.manage，其中不存在zeus.manage,在该配置文件中修改不行，会被覆盖
# 配置内容在代码中写死：/usr/lib/python3.11/site-packages/zeus/cli/service.py: 85
# 改成module = _service + ".distribute_service.manage"
pip install celery
yum install zookeeper -y
systemctl start zookeeper


# 报错日志在：ls /var/log/aops/uwsgi/zeus.log
```
代码中原始配置：
```
[uwsgi]
http=:{config.port}
chdir={chdir}
module={module}
pidfile={pidfile}
callable=app
http-timeout={config.http_timeout}
processes={config.processes}
daemonize={config.daemonize}
buffer-size={config.buffer_size}
vacuum=true
need-app=true
"""
        if config.gevent:
            uwsgi_file += f"""
gevent={config.gevent}
gevent-monkey-patch=true
"""
        else:
            uwsgi_file += f"""
threads={config.threads}           
"""
```

前端界面是aops-hermes 
```
# /etc/nginx/nginx.conf； 把/etc/nginx/aops-nginx.conf进来
    server {
        listen       90;          # 或者你想要的端口
        server_name  localhost;    # 或者你的域名/IP

        # 在这里引入你的业务配置
        include /etc/nginx/aops-nginx.conf;
    }
```

/etc/nginx/aops-nginx.conf,其中proxy_pass是生效的
```
# 保证前端路由变动时nginx仍以index.html作为入口
location / {
    try_files $uri $uri/ /index.html;
    if (!-e $request_filename){
        rewrite ^(.*)$ /index.html last;
    }
}
# 此处修改为aops-zeus部署机器真实IP
location /api/ {
    proxy_pass http://192.168.19.132:11111/;
}
# 此处IP对应gala-ragdoll的IP地址,涉及到端口为11114的IP地址都需要进行调整
location /api/domain {
    proxy_pass http://192.168.19.130:11114/;
    rewrite ^/api/(.*) /$1 break;
}
# 此处IP对应aops-apollo的IP地址
location /api/vulnerability {
    proxy_pass http://192.168.19.130:11116/;
    rewrite ^/api/(.*) /$1 break;
}

```
## 机器C
gala-ragdoll的配置：
/opt/aops/uwsgi/ragdoll.ini
/etc/aops/conf.d/ragdoll.yml


# 参考链接
> https://docs.openeuler.org/zh/docs/23.09/docs/A-Ops/%E9%85%8D%E7%BD%AE%E6%BA%AF%E6%BA%90%E6%9C%8D%E5%8A%A1%E4%BD%BF%E7%94%A8%E6%89%8B%E5%86%8C.html