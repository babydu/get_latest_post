#!/bin/bash

# 设置默认的Sitemap地址
DEFAULT_SITEMAP_URL="https://littleprince.site/sitemap_index.xml"

# 提示用户输入Sitemap地址，设置超时时间为15秒
read -t 15 -p "请输入Sitemap地址（默认: $DEFAULT_SITEMAP_URL）: " SITEMAP_URL

# 如果用户没有输入任何内容，则使用默认值，并提醒用户
if [ -z "$SITEMAP_URL" ]; then
  SITEMAP_URL=$DEFAULT_SITEMAP_URL
  echo "使用默认Sitemap地址: $SITEMAP_URL"
  
  # 请求用户确认是否真的使用默认Sitemap地址
  read -t 10 -p "是否确认使用默认Sitemap地址？建议使用你自己的地址噢！(y/n): " confirm

  # 如果用户超时没有输入，则终止执行
  if [ -z "$confirm" ]; then
    echo "由于没有输入确认信息，程序终止执行。"
    exit 1
  fi

  # 如果用户输入不是 'y' 或 'Y'，则请求重新输入Sitemap地址
  while [[ "$confirm" != "y" && "$confirm" != "Y" ]]; do
    read -p "请输入新的Sitemap地址: " SITEMAP_URL
    if [ -z "$SITEMAP_URL" ]; then
      echo "未输入新的Sitemap地址，程序终止执行。"
      exit 1
    fi
    confirm="y"  # 确认使用新输入的Sitemap地址
  done
fi

# 提取网站URL的中间部分作为文件夹名称
site_name=$(echo "$SITEMAP_URL" | awk -F[/:] '{print $4}')

# 定义缓存目录
CACHE_DIR="./cache/$site_name"
mkdir -p "$CACHE_DIR"

# 定义缓存文件路径
CACHE_FILE="$CACHE_DIR/sitemap.xml"

# 检查本地缓存文件是否存在且未过期
if [ -f "$CACHE_FILE" ]; then
  # 获取文件的最后修改时间
  file_mod_time=$(date -r "$CACHE_FILE" +%s)
  current_time=$(date +%s)
  time_diff=$((current_time - file_mod_time))
  days_diff=$((time_diff / 86400))  # 86400秒 = 1天

  if [ $days_diff -lt 7 ]; then
    echo "使用本地缓存文件: $CACHE_FILE"
  else
    echo "本地缓存文件已过期，重新下载Sitemap文件"
    # 下载Sitemap文件，并忽略SSL证书验证
    curl -s -k -o "$CACHE_FILE" "$SITEMAP_URL"
  fi
else
  echo "本地缓存文件不存在，下载Sitemap文件"
  # 下载Sitemap文件，并忽略SSL证书验证
  curl -s -k -o "$CACHE_FILE" "$SITEMAP_URL"
fi

# 检查是否成功下载Sitemap文件
if [ ! -f "$CACHE_FILE" ] || [ ! -s "$CACHE_FILE" ]; then
  echo "未能成功下载Sitemap文件"
  exit 1
fi

# 检查是否为Sitemap索引文件
is_index=$(xmlstarlet sel -N x="http://www.sitemaps.org/schemas/sitemap/0.9" -t -m "//x:sitemapindex" -v "." -n "$CACHE_FILE")

if [ -n "$is_index" ]; then
  # 是Sitemap索引文件，提取所有Sitemap URL
  sitemap_urls=$(xmlstarlet sel -N x="http://www.sitemaps.org/schemas/sitemap/0.9" -t -m "//x:sitemap/x:loc" -v "." -n "$CACHE_FILE")
  
  # 将Sitemap URL列表转换为数组
  sitemap_url_array=($(echo "$sitemap_urls" | tr '\n' ' '))
  
  # 计算Sitemap URL数量
  sitemap_url_count=${#sitemap_url_array[@]}
  
  # 随机选择一个Sitemap URL
  random_sitemap_index=$((RANDOM % sitemap_url_count))
  selected_sitemap_url=${sitemap_url_array[$random_sitemap_index]}
  
  # 提取选定Sitemap URL的中间部分作为文件夹名称
  selected_site_name=$(echo "$selected_sitemap_url" | awk -F[/:] '{print $4}')
  SELECTED_CACHE_DIR="./cache/$selected_site_name"
  mkdir -p "$SELECTED_CACHE_DIR"
  SELECTED_CACHE_FILE="$SELECTED_CACHE_DIR/sitemap.xml"
  curl -s -k -o "$SELECTED_CACHE_FILE" "$selected_sitemap_url"
  
  # 检查是否成功下载选定的Sitemap文件
  if [ ! -f "$SELECTED_CACHE_FILE" ] || [ ! -s "$SELECTED_CACHE_FILE" ]; then
    echo "未能成功下载选定的Sitemap文件: $selected_sitemap_url"
    exit 1
  fi
  
  # 更新缓存文件路径
  CACHE_FILE="$SELECTED_CACHE_FILE"
fi

# 解析Sitemap文件，提取所有URL
urls=$(xmlstarlet sel -N x="http://www.sitemaps.org/schemas/sitemap/0.9" -t -m "//x:url/x:loc" -v "." -n "$CACHE_FILE")

# 检查是否成功提取到URL
if [ -z "$urls" ]; then
  echo "未找到任何URL"
  exit 1
fi

# 将URL列表转换为数组
url_array=($(echo "$urls" | tr '\n' ' '))

# 计算URL数量
url_count=${#url_array[@]}

# 随机选择一个URL
random_index=$((RANDOM % url_count))
theUrl=${url_array[$random_index]}

# 输出随机选择的URL
echo "随机选择的URL: $theUrl"

# 清理临时文件
# rm "$CACHE_FILE"  # 如果需要保留缓存文件，可以注释掉这一行
