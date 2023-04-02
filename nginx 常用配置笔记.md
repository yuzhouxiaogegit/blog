### 匹配所有js和css文件重写到指定目录且只保留文件名
```nginx
location ~ .*\.(js|css)?$
{
  expires 30d; # 缓存30天
  # 重写到指定目录 break是不在发生新的请求
  rewrite ^/(/.*(js|css)$) /wp-content/cache/staticfile$1 break;
}
```

### wp-super-cache缓存插件伪静态配置
```nginx
# wp-super-cache 早期版本或者是使用http访问
set $http_url /wp-content/cache/supercache/$http_host/$request_uri/index.html;
# wp-super-cache 新版本或者是使用https时访问
set $https_url /wp-content/cache/supercache/$http_host/$request_uri/index-https.html;
location /
{
    # 如果有缓存文件则直接访问缓存目录  没有则从新生成
    try_files $https_url $http_url $uri $uri/ /index.php?$args;
}
```

### nginx常用的静态文件缓存设置
```nginx
location ~ .*\.(js|css|eot|ttf|woff|woff2|otf|ico|svg|gif|jpg|jpeg|png|bmp|swf|webp|mp4|flv|txt|bmp|doc|zip|docx|rar)?$
{
    expires 30d;  # 缓存30天
    error_log /dev/null;
    access_log off; 
}
````

### 防盗链配置
```nginx
location ~ .*\.(js|css|eot|ttf|woff|woff2|otf|ico|svg|gif|jpg|jpeg|png|bmp|swf|webp|mp4|flv|txt|bmp|doc|zip|docx|rar)?$
{
    expires 30d;  #缓存30天
    access_log off;
    # 允许链接单独访问
    #valid_referers none blocked baidu.com www.baidu.com;
    # 仅支持网站内访问
    valid_referers baidu.com www.baidu.com;
    if ($invalid_referer){
       return 404;
    }
}
```
