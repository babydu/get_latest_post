#!/bin/bash

# 设置默认的Sitemap索引URL
DEFAULT_SITEMAP_INDEX_URL="https://littleprince.site/sitemap_index.xml"

# 提示用户输入Sitemap索引URL，设置超时时间为15秒
read -t 15 -p "请输入要查询的Sitemap索引URL（默认: $DEFAULT_SITEMAP_INDEX_URL）: " SITEMAP_INDEX_URL

# 如果用户没有输入任何内容，则使用默认值
if [ -z "$SITEMAP_INDEX_URL" ]; then
  SITEMAP_INDEX_URL=$DEFAULT_SITEMAP_INDEX_URL
fi

# 提取网站域名作为唯一标识符
DOMAIN=$(echo "$SITEMAP_INDEX_URL" | awk -F[/:] '{print $4}')

# 定义缓存目录
CACHE_DIR="./cache/$DOMAIN"
mkdir -p "$CACHE_DIR"

# 下载Sitemap索引文件，并忽略SSL证书验证
curl -s -k -o "$CACHE_DIR/sitemap_index.xml" "$SITEMAP_INDEX_URL"

# 检查是否成功下载Sitemap索引文件
if [ ! -f "$CACHE_DIR/sitemap_index.xml" ] || [ ! -s "$CACHE_DIR/sitemap_index.xml" ]; then
  echo "未能成功下载Sitemap索引文件"
  exit 1
fi

# 解析Sitemap索引文件，提取所有post-sitemap.xml的URL及其最后修改时间
post_sitemap_data=$(xmlstarlet sel -N x="http://www.sitemaps.org/schemas/sitemap/0.9" -t -m "//x:sitemap[x:loc[contains(., 'post-sitemap')]]" -v "concat(x:lastmod, ' ', x:loc)" -n "$CACHE_DIR/sitemap_index.xml")

# 检查是否成功获取到post-sitemap.xml的URL
if [ -z "$post_sitemap_data" ]; then
  echo "未找到任何post-sitemap.xml的URL"
  exit 1
fi

# 按最后修改时间逆序排序post-sitemap.xml文件
sorted_post_sitemap_data=$(echo "$post_sitemap_data" | sort -r -k1,1)

# 获取最新更新的post-sitemap.xml文件的信息
latest_post_sitemap_line=$(echo "$sorted_post_sitemap_data" | head -n 1)
latest_post_sitemap_lastmod=$(echo "$latest_post_sitemap_line" | awk '{print $1}')
latest_post_sitemap_url=$(echo "$latest_post_sitemap_line" | awk '{print $2}')
latest_post_sitemap_file="$CACHE_DIR/post-sitemap-$(basename "$latest_post_sitemap_url")"

# 检查文件是否已存在
if [ -f "$latest_post_sitemap_file" ]; then
  # 给出判断选项
  echo "本地已有缓存文件: $latest_post_sitemap_file"
  echo "是否使用本地缓存进行处理？ (y/n)"
  
  # 设置超时时间为10分钟
  timeout=600
  read -t $timeout -p "请输入 (y/n): " choice
  
  case $choice in
    y|Y)
      echo "使用缓存文件: $latest_post_sitemap_file"
      ;;
    n|N)
      echo "重新下载: $latest_post_sitemap_url"
      curl -s -k -o "$latest_post_sitemap_file" "$latest_post_sitemap_url"
      ;;
    *)
      echo "超时或输入无效，重新下载: $latest_post_sitemap_url"
      curl -s -k -o "$latest_post_sitemap_file" "$latest_post_sitemap_url"
      ;;
  esac
else
  echo "下载新文件: $latest_post_sitemap_url"
  curl -s -k -o "$latest_post_sitemap_file" "$latest_post_sitemap_url"
fi

# 检查是否成功下载post-sitemap.xml文件
if [ ! -f "$latest_post_sitemap_file" ] || [ ! -s "$latest_post_sitemap_file" ]; then
  echo "未能成功下载post-sitemap.xml文件: $latest_post_sitemap_url"
  exit 1
fi

# 初始化一个空数组来存储所有文章URL及其最后修改时间
all_urls=()

# 解析post-sitemap.xml文件，提取文章URL及其最后修改时间
while read -r line; do
  lastmod=$(echo "$line" | awk '{print $1}')
  loc=$(echo "$line" | awk '{print $2}')
  # 排除首页URL
  if [[ "$loc" != "https://$DOMAIN" ]]; then
    all_urls+=("$lastmod $loc")
    # echo "提取到的URL: $loc, 最后修改时间: $lastmod"  # 调试信息
  fi
done < <(xmlstarlet sel -N x="http://www.sitemaps.org/schemas/sitemap/0.9" -t -m "//x:url" -v "concat(x:lastmod, ' ', x:loc)" -n "$latest_post_sitemap_file")

# 检查是否成功获取到文章URL及其最后修改时间
if [ ${#all_urls[@]} -eq 0 ]; then
  echo "未找到任何文章URL"
  exit 1
else
  # echo "成功获取到文章URL及其最后修改时间"  # 调试信息
  :
fi

# 打印所有文章URL及其最后修改时间
# echo "所有文章URL及其最后修改时间:"
# printf "%s\n" "${all_urls[@]}"

# 将所有文章URL及其最后修改时间按日期逆序排序
sorted_urls=$(printf "%s\n" "${all_urls[@]}" | sort -r -k1,1)

# 打印排序后的文章URL及其最后修改时间
# echo "排序后的文章URL及其最后修改时间:"
# echo "$sorted_urls"

# 获取第一个结果，即最新的文章URL
newAddress=$(echo "$sorted_urls" | head -n 1 | awk '{print $2}')

# 输出最新的文章地址
echo "最新的文章地址: $newAddress"
