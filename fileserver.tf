job "nginx-fileserver" {
  datacenters = ["dc1"]

  group "nginx" {
    count = 1

    network {
      mode = "host"
      port "http" {
          static = "8080"
      }
    }

    service {
        name = "fileserver"
        port = "http"

        check {
            name     = "HTTP Health"
            path     = "/"
            type     = "http"
            protocol = "http"
            interval = "10s"
            timeout  = "2s"
        }
    }

    task "nginx-container" {
      driver = "docker"

      config {
        network_mode = "host"
        image = "nginx:alpine"
        ports = ["http"]
        volumes = [
          "local/fileserver/nginx.conf:/etc/nginx/nginx.conf",
          "local/fileserver/default.conf:/etc/nginx/conf.d/default.conf",
          "local/fileserver/buffers.conf:/etc/nginx/conf.d/buffers.conf",
          "local/fileserver/timeouts.conf:/etc/nginx/conf.d/timeouts.conf",
          "local/fileserver/header.conf:/etc/nginx/conf.d/header.conf",
          "local/fileserver/cache.conf:/etc/nginx/conf.d/cache.conf",
          "local/fileserver/gzip.conf:/etc/nginx/conf.d/gzip.conf",
          "local/fileserver/.htpasswd:/etc/nginx/conf.d/.htpasswd",
          "local/fileserver/index.html:/usr/share/nginx/html/index.html",
          "local/fileserver/files/public/file.txt:/usr/share/nginx/html/public/file.txt",
          "local/fileserver/files/secret/secretfile.txt:/usr/share/nginx/html/secret/secretfile.txt"
        ]
      }

      template {
        data = <<EOH
user  nginx;
worker_processes  auto;
worker_rlimit_nofile  15000;
pid  /var/run/nginx.pid;
include /usr/share/nginx/modules/*.conf;


events {
    worker_connections  2048;
    multi_accept on;
    use epoll;
}


http {
    default_type   application/octet-stream;
    # error_log    /var/log/nginx/error.log;
    error_log /dev/stdout info;
    # don't display server version on error pages
    server_tokens  off;
    server_names_hash_bucket_size 64;
    include        /etc/nginx/mime.types;
    sendfile       on;
    tcp_nopush     on;
    tcp_nodelay    on;

    charset utf-8;
    source_charset utf-8;
    charset_types text/xml text/plain text/vnd.wap.wml application/javascript application/rss+xml;
    
    include /etc/nginx/conf.d/default.conf;
    include /etc/nginx/conf.d/buffers.conf;
    include /etc/nginx/conf.d/timeouts.conf;
    include /etc/nginx/conf.d/cache.conf;
    include /etc/nginx/conf.d/gzip.conf;
}
        EOH

        destination = "local/fileserver/nginx.conf"
      }

      template {
        data = <<EOH
server {
    listen 8080;
    listen [::]:8080;
    include /etc/nginx/conf.d/header.conf;

    server_name  my.domain.com;

    #access_log  /var/log/nginx/host.access.log;
    access_log /dev/stdout;

    location ~ /secret/.* {
		    auth_basic "Restricted";
        auth_basic_user_file /etc/nginx/conf.d/.htpasswd; 
        root   /usr/share/nginx/html;
    }

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
        EOH

        destination = "local/fileserver/default.conf"
      }

      template {
        data = <<EOH
client_body_buffer_size 10k;
client_header_buffer_size 1k;
client_max_body_size 8m;
large_client_header_buffers 2 1k;
# Directive needs to be increased for certain site types to prevent ERROR 400
# large_client_header_buffers 4 32k;
        EOH

        destination = "local/fileserver/buffers.conf"
      }

      template {
        data = <<EOH
add_header                Cache-Control  "public, must-revalidate, proxy-revalidate, max-age=0";
proxy_set_header          X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header          X-NginX-Proxy true;
proxy_set_header          X-Real-IP $remote_addr;
proxy_set_header          X-Forwarded-Proto http;
proxy_hide_header         X-Frame-Options;
proxy_set_header          Accept-Encoding "";
proxy_http_version        1.1;
proxy_set_header          Upgrade $http_upgrade;
proxy_set_header          Connection "upgrade";
proxy_set_header          Host $host;
proxy_cache_bypass        $http_upgrade;
proxy_max_temp_file_size  0;
proxy_redirect            off;
proxy_read_timeout        240s;
        EOH

        destination = "local/fileserver/header.conf"
      }

      template {
        data = <<EOH
open_file_cache max=1500 inactive=20s;
open_file_cache_valid 30s;
open_file_cache_min_uses 5;
open_file_cache_errors off;
        EOH

        destination = "local/fileserver/cache.conf"
      }

      template {
        data = <<EOH
client_header_timeout 3m;
client_body_timeout 3m;
keepalive_timeout 100;
keepalive_requests 1000;
send_timeout 3m;
        EOH

        destination = "local/fileserver/timeouts.conf"
      }

      template {
        data = <<EOH
gzip on;
gzip_disable "msie6";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 5;
gzip_min_length 256;
gzip_buffers 16 8k;
gzip_http_version 1.1;
gzip_types text/plain text/css application/json application/javascript
text/xml application/xml application/xml+rss text/javascript
image/svg+xml application/xhtml+xml application/atom+xml;
        EOH

        destination = "local/fileserver/gzip.conf"
      }

      template {
        data = <<EOH
<!DOCTYPE html>
<html>
<head>
    <title>File Server</title>
    <style>
    html { color-scheme: light dark; }
    body { width: 35em; margin: 0 auto;
    font-family: Tahoma, Verdana, Arial, sans-serif; }
    </style>
</head>
<body>
    <h1>My File Server</h1>
    <h2>Public Files</h2>
    <ul>
      <li><a href="/public/file.txt">file.txt</a></li>
    </ul>
    <h2>Secret Files</h2>
    <ul>
      <li><a href="/secret/secretfile.txt">secretfile.txt</a></li>
    </ul>
    <em>Use admin / password to download the secret file.</em>
</body>
</html>
        EOH

        destination = "local/fileserver/index.html"
      }

      template {
        data = <<EOH
I am a publicly available text file.
        EOH

        destination = "local/fileserver/files/public/file.txt"
      }

      template {
        data = <<EOH
I am a secret text file.
        EOH

        destination = "local/fileserver/files/secret/secretfile.txt"
      }

      template {
        data = <<EOH
admin:$apr1$OSeK5n.F$LaIPaE5V21DZmE0brRCsW/
        EOH

        destination = "local/fileserver/.htpasswd"
        # user login generated with "htpasswd -c ./.htpasswd admin"
        # admin / password
      }

    }
  }
}