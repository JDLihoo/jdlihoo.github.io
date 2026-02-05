---
title: gala-gopher
author: JDLihoo
date: 2026-01-21
category: Jekyll
layout: post
published: false
---
## 问题描述
当nginx实际链接数达到20时，gala-gopher采集到的链接数只有3

## 问题复现
两个节点：Linux虚拟机和本机windows
在Linux虚拟机上安装nginx，通过源码安装，因为需要ebpf需要挂ngx_stream_proxy_init_upstream
```
cd /usr/local/src
wget http://nginx.org/download/nginx-1.24.0.tar.gz
tar -zxf nginx-1.24.0.tar.gz
cd nginx-1.24.0

./configure --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib64/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/run/nginx.pid \
    --lock-path=/run/lock/subsys/nginx \
    --user=nginx \
    --group=nginx \
    --with-pcre \
    --with-pcre-jit \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-cc-opt='-O2 -g -pipe -Wall -fstack-protector-strong' \
    --with-ld-opt='-Wl,-E'

make -j4
# 在覆盖旧版本前先停止服务
systemctl stop nginx
make install

# 验证安装结果
nm /usr/sbin/nginx | grep ngx_stream_proxy_init_upstream
```

写nginx.service
$ vim /usr/lib/systemd/system/nginx.service
```
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
# Nginx 会按照你在 configure 时定义的路径启动
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=mixed
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```
写配置
$ vim /etc/nginx/nginx.conf
```
# 在http的{}内加上
include /etc/nginx/conf.d/*.conf;
```

启动nginx
```
$ systemctl start nginx
# 开启500端口
$ vim /etc/nginx/conf.d/test.conf

server {
    listen 500; # 确保监听 500 端口
    server_name localhost;

    location / {
        # 开启 Keepalive 以保持长连接不被立即关闭
        keepalive_timeout 60s; 
        return 200 "OK";
    }
}

$ systemctl restart nginx
```

先测试本机windows能否与linux 虚拟机500端口建立链接(需要在power shell窗口，不能是cmd窗口)：
```
Test-NetConnection -ComputerName 192.168.140.132 -Port 500
```

本机windows与linux虚拟机建立20个链接：
```
$target_ip = "192.168.140.132"  # 替换为你的虚拟机IP
$port = "500"
$total_connections = 20

for ($i=1; $i -le $total_connections; $i++) {
    Start-Job -ScriptBlock {
        param($ip, $p)
        # 使用 WebRequest 并保持连接
        $req = [System.Net.HttpWebRequest]::Create("http://$ip`:$p")
        $req.KeepAlive = $true
        $req.Timeout = 600000 # 保持10分钟
        $response = $req.GetResponse()
        Start-Sleep -Seconds 600 # 保持进程不退出，从而维持连接
    } -ArgumentList $target_ip, $port
}

Write-Host "已发起 20 个连接请求，请在虚拟机执行 netstat 检查。"
```
如果第二台机子是linux服务器，则通过iperf3打流
```
yum install iperf3

# 服务端运行（记得firewall打开5201端口）
iperf3 -s
# 客户端运行（内网需要自己用socat映射端口，5201端口映射到51端口，虚拟机51端口对应物理机22051端口）
iperf3 -c 192.168.140.132 -p 5201 -i 1 -t 100 -P 10

# 要在/etc/nginx/conf.d/test.conf添加5201端口

stream {
    upstream iperf3_backend {
        server 127.0.0.1:5201; # 转发给本地真正的 iperf3 服务端
    }

    server {
        listen 192.168.140.132:500; # 监听你要求的 500 端口
        proxy_pass iperf3_backend;
        proxy_timeout 10m;
        proxy_connect_timeout 1s;
    }
}

# 同时要调整/etc/nginx/nginx.conf里include的层级关系（放到http{}外面）

events {
    worker_connections  1024;
}

include /etc/nginx/conf.d/*.conf;

http {
    include       mime.types;
    default_type  application/octet-stream;

$ systemctl restart nginx

# 在客户端就可以直接对500端口进行打流
iperf3 -c 192.168.140.132 -p 500 -i 1 -t 100 -P 10
```

在linux虚拟机查看建立链接数：
```
netstat -aptnu | grep 192.168.140.132:500 | wc -l
```

## 开启gopher探针
```
curl -X PUT http://localhost:9999/nginx -d json='
{
    "cmd": {
        "probe": [
        ]
    },
    "snoopers": {},
    "params":{
        "report_period": 10,
        "res_lower_thr": 20,
        "res_upper_thr": 40,
        "report_event": 1,
        "metrics_type": [
            "raw",
            "telemetry"
        ],
        "env": "node",
        "elf_path": "/usr/sbin/nginx"
    },
    "state":"running"
}'
```