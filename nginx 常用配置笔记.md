### 匹配所有js和css文件重写到指定目录且只保留文件名
```nginx
location ~ .*\.(js|css)?$
{
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
