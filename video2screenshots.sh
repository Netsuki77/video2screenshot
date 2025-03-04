#!/bin/bash

# ----------------------------------------------
# 用法:
#   ./video2screenshots.sh <视频文件或目录>
# 例如:
#   ./video2screenshots.sh ~/Movies/myvideo.mp4
#   ./video2screenshots.sh ~/Movies/
# ----------------------------------------------

# 定义处理单个视频文件的函数
process_video() {
    local VIDEO_PATH="$1"
    VIDEO_PATH="$(realpath "$VIDEO_PATH")"
    VIDEO_DIR="$(dirname "$VIDEO_PATH")"
    BASENAME=$(basename "$VIDEO_PATH")
    PREFIX="${BASENAME%.*}"

    # 对文件名中的 [ 和 ] 进行转义，供后续 montage 使用
    ESCAPED_PREFIX=$(echo "$PREFIX" | sed -e 's/\[/\\[/g' -e 's/\]/\\]/g')

    # 在脚本所在目录创建一个用于存放截图的临时目录
    SCREENSHOT_DIR="${SCRIPT_DIR}/${PREFIX}_screenshots"
    mkdir -p "$SCREENSHOT_DIR"

    # 使用 ffprobe 获取视频总时长（秒）
    duration=$(ffprobe -i "$VIDEO_PATH" -show_entries format=duration -v quiet -of csv="p=0")
    duration_int=$(printf "%.0f" "$duration")

    # 根据视频长度选择截图间隔
    if [ "$duration_int" -lt 30 ]; then
        # 视频长度小于30秒，每3秒生成一张截图
        interval=3
    elif [ "$duration_int" -lt 60 ]; then
        # 视频长度小于1分钟，固定生成12张截图
        desired_count=12
        interval=$(( duration_int / desired_count ))
    elif [ "$duration_int" -lt 120 ]; then
        # 视频长度小于2分钟，固定生成14张截图
        desired_count=14
        interval=$(( duration_int / desired_count ))
    elif [ "$duration_int" -lt 240 ]; then
        # 视频长度小于4分钟，固定生成16张截图
        desired_count=16
        interval=$(( duration_int / desired_count ))
    elif [ "$duration_int" -lt 480 ]; then
        # 视频长度小于8分钟，固定生成20张截图
        desired_count=20
        interval=$(( duration_int / desired_count ))
    elif [ "$duration_int" -lt 900 ]; then
        # 视频长度小于15分钟，固定生成24张截图
        desired_count=24
        interval=$(( duration_int / desired_count ))
    elif [ "$duration_int" -lt 1800 ]; then
        # 视频长度小于30分钟，固定生成28张截图
        desired_count=28
        interval=$(( duration_int / desired_count ))
    elif [ "$duration_int" -lt 3600 ]; then
        # 视频长度小于60分钟，固定生成32张截图
        desired_count=32
        interval=$(( duration_int / desired_count ))
    else
        # 视频长度超过60分钟，每120秒生成一张截图
        interval=120
    fi

    echo "正在处理视频: ${VIDEO_PATH}"
    echo "视频时长：${duration_int}秒，截图间隔设为：${interval}秒"

    # 检查视频是否包含字幕流
    subtitle_stream=$(ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 "$VIDEO_PATH")
    if [ -z "$subtitle_stream" ]; then
        # 没有字幕流，不使用字幕过滤器
        subtitle_filter=""
    else
        # 存在字幕流，使用字幕过滤器
        subtitle_filter="subtitles='${VIDEO_PATH}',"
    fi

    # 构造完整的过滤器（先处理字幕，再处理截图和叠加时间戳）
    filter="${subtitle_filter}fps=1/${interval},scale='if(gt(min(iw,ih),360),if(gt(iw,ih),-2,360),iw)':'if(gt(min(iw,ih),360),if(gt(iw,ih),360,-2),ih)',drawtext=text='%{pts\\:hms}  ':x=w-tw-12:y=h-th-12:fontsize=22:fontcolor=white:box=1:boxcolor=black@0.5:boxborderw=4"

    ffmpeg -ss 2 -i "$VIDEO_PATH" -vf "$filter" -qscale:v 1 "${SCREENSHOT_DIR}/${PREFIX}_%04d.jpg"

    # 根据截图数量设置 montage 的每行图片数量
    num=$(ls "${SCREENSHOT_DIR}/${PREFIX}"_*.jpg 2>/dev/null | wc -l)
    if [ "$num" -le 12 ]; then
        tile="3x"
    elif [ "$num" -le 32 ]; then
        tile="4x"
    else
        tile="5x"
    fi

    echo "共截取 ${num} 张图片，拼接时每行使用 ${tile%%x} 张图片"

    # 使用 ImageMagick 的 montage 命令将截图拼接成一张长图，最终输出到视频所在目录
    montage -quality 75 -tile "$tile" -geometry +1+1 "${SCREENSHOT_DIR}/${ESCAPED_PREFIX}_*.jpg" "${VIDEO_DIR}/${PREFIX}_screenshot.jpg"

    # 如果不想保留临时截图，可以取消下面这一行的注释
    rm -rf "$SCREENSHOT_DIR"

    echo "拼图完成，输出文件: ${VIDEO_DIR}/${PREFIX}_screenshot.jpg"
}

# 检查参数是否传入
if [ $# -lt 1 ]; then
    echo "用法: $0 <视频文件或目录>"
    exit 1
fi

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

INPUT_PATH="$1"

# 判断输入是目录还是文件
if [ -d "$INPUT_PATH" ]; then
    echo "检测到输入是目录，将处理目录下的视频文件..."
    # 遍历目录下所有文件
    for video in "$INPUT_PATH"/*; do
        # 判断是否为常见视频文件（根据扩展名，忽略大小写）
        if [ -f "$video" ]; then
            ext="${video##*.}"
            ext_lower=$(echo "$ext" | tr 'A-Z' 'a-z')
            case "$ext_lower" in
                mp4|mov|mkv|avi|flv|wmv)
                    process_video "$video"
                    ;;
                *)
                    echo "跳过非视频文件: $video"
                    ;;
            esac
        fi
    done
elif [ -f "$INPUT_PATH" ]; then
    process_video "$INPUT_PATH"
else
    echo "错误: 参数既不是文件也不是目录"
    exit 1
fi