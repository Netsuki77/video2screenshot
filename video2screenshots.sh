#!/bin/bash

# ----------------------------------------------
# 用法:
#   ./video2screenshots.sh <视频文件或目录>
# 例如:
#   ./video2screenshots.sh ~/Movies/myvideo.mp4
#   ./video2screenshots.sh ~/Movies/
# ----------------------------------------------

LOCKFILE="$(dirname "$0")/video2screenshots.lock"
exec 200>"$LOCKFILE"
lockf -t 0 200 || { echo "脚本已在运行，退出"; exit 1; }

# 定义处理单个视频文件的函数
process_video() {
    local VIDEO_PATH="$1"
    VIDEO_PATH="$(realpath "$VIDEO_PATH")"
    VIDEO_DIR="$(dirname "$VIDEO_PATH")"
    BASENAME=$(basename "$VIDEO_PATH")
    PREFIX="${BASENAME%.*}"

    # 检查预览截图是否已存在
    screenshot_file="${VIDEO_DIR}/${PREFIX}_screenshot.jpg"
    if [ -f "$screenshot_file" ]; then
        echo "预览截图已存在: ${screenshot_file}，跳过处理该视频。"
        return
    fi

    # 对文件名中的 [ 和 ] 进行转义，供后续 montage 使用
    ESCAPED_PREFIX=$(echo "$PREFIX" | sed -e 's/\[/\\[/g' -e 's/\]/\\]/g')

    # 在脚本所在目录创建一个用于存放截图的临时目录
    SCREENSHOT_DIR="${SCRIPT_DIR}/${PREFIX}_screenshots"
    mkdir -p "$SCREENSHOT_DIR"

    # 使用 ffprobe 获取视频总时长（秒）
    duration=$(ffprobe -i "$VIDEO_PATH" -show_entries format=duration -v quiet -of csv="p=0")
    duration_int=$(printf "%.0f" "$duration")

    # 先获取视频分辨率来判断方向（横屏/竖屏）
    video_resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$VIDEO_PATH")
    width=$(echo "$video_resolution" | cut -d',' -f1)
    height=$(echo "$video_resolution" | cut -d',' -f2)
    if [ "$width" -ge "$height" ]; then
        orientation="landscape"
    else
        orientation="portrait"
    fi
    echo "视频方向: ${orientation}"

# 忽略视频的前2秒
    pre_skip_seconds=2
# 得出用于截图的有效视频时长
    effective_duration=$(( duration_int - pre_skip_seconds ))

# 根据视频长度和视频方向设置截图间隔
    if [ "$effective_duration" -lt 30 ]; then
        # 视频长度小于30秒，每3秒生成一张截图
        interval=3
    elif [ "$orientation" = "portrait" ]; then
        # 竖图视频规则
        if [ "$effective_duration" -lt 60 ]; then
            # 视频长度小于1分钟，固定生成12张截图
            desired_count=12
            interval=$(( effective_duration / desired_count ))
        elif [ "$effective_duration" -lt 120 ]; then
            # 视频长度小于2分钟，固定生成15张截图
            desired_count=15
            interval=$(( effective_duration / desired_count ))
        elif [ "$effective_duration" -lt 240 ]; then
            # 视频长度小于4分钟，固定生成18张截图
            desired_count=18
            interval=$(( effective_duration / desired_count ))
        elif [ "$effective_duration" -lt 480 ]; then
            # 视频长度小于8分钟，固定生成21张截图
            desired_count=21
            interval=$(( effective_duration / desired_count ))
        elif [ "$effective_duration" -lt 900 ]; then
            # 视频长度小于15分钟，固定生成24张截图
            desired_count=24
            interval=$(( effective_duration / desired_count ))
        elif [ "$effective_duration" -lt 1800 ]; then
            # 视频长度小于30分钟，固定生成28张截图
            desired_count=28
            interval=$(( effective_duration / desired_count ))
        elif [ "$effective_duration" -lt 3600 ]; then
            # 视频长度小于60分钟，固定生成32张截图
            desired_count=32
            interval=$(( effective_duration / desired_count ))
        else
            # 视频长度超过60分钟，每90秒生成一张截图
            interval=90
        fi
    else
        # 横屏视频规则（沿用原有逻辑）
        if [ "$effective_duration" -lt 60 ]; then
            # 视频长度小于1分钟，固定生成12张截图
            desired_count=12
            interval=$(( effective_duration / desired_count ))
        elif [ "$effective_duration" -lt 120 ]; then
            # 视频长度小于2分钟，固定生成14张截图
            desired_count=14
            interval=$(( effective_duration / desired_count ))
        elif [ "$effective_duration" -lt 240 ]; then
            # 视频长度小于4分钟，固定生成16张截图
            desired_count=16
            interval=$(( effective_duration / desired_count ))
        elif [ "$effective_duration" -lt 480 ]; then
            # 视频长度小于8分钟，固定生成20张截图
            desired_count=20
            interval=$(( effective_duration / desired_count ))
        elif [ "$effective_duration" -lt 900 ]; then
            # 视频长度小于15分钟，固定生成24张截图
            desired_count=24
            interval=$(( effective_duration / desired_count ))
        elif [ "$effective_duration" -lt 1800 ]; then
            # 视频长度小于30分钟，固定生成28张截图
            desired_count=28
            interval=$(( effective_duration / desired_count ))
        elif [ "$effective_duration" -lt 3600 ]; then
            # 视频长度小于60分钟，固定生成32张截图
            desired_count=32
            interval=$(( effective_duration / desired_count ))
        else
            # 视频长度超过60分钟，每90秒生成一张截图
            interval=90
        fi
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

    ffmpeg -ss "$pre_skip_seconds" -i "$VIDEO_PATH" -vf "$filter" -qscale:v 1 -frames:v ${desired_count} "${SCREENSHOT_DIR}/${PREFIX}_%04d.jpg"

    # 获取视频分辨率来判断方向（横屏/竖屏）
    video_resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$VIDEO_PATH")
    width=$(echo "$video_resolution" | cut -d',' -f1)
    height=$(echo "$video_resolution" | cut -d',' -f2)
    if [ "$width" -ge "$height" ]; then
        orientation="landscape"
    else
        orientation="portrait"
    fi
    echo "视频方向: ${orientation}"

    # 根据截图数量和视频方向设置 montage 的每行图片数量
    num=$(ls "${SCREENSHOT_DIR}/${PREFIX}"_*.jpg 2>/dev/null | wc -l)
    if [ "$orientation" = "landscape" ]; then
        if [ "$num" -le 12 ]; then
            tile="3x"
        elif [ "$num" -le 32 ]; then
            tile="4x"
        else
            tile="5x"
        fi
    else
        if [ "$num" -le 12 ]; then
            tile="4x"
        elif [ "$num" -le 15 ]; then
            tile="5x"
        elif [ "$num" -le 18 ]; then
            tile="6x"
        elif [ "$num" -le 21 ]; then
            tile="7x"
        elif [ "$num" -le 24 ]; then
            tile="8x"
        elif [ "$num" -le 28 ]; then
            tile="7x"
        else
            tile="8x"
        fi
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

# 记录脚本开始运行的时间（秒）
START_TIME=$(date +%s)

# 判断输入是目录还是文件
if [ -d "$INPUT_PATH" ]; then
    echo "检测到输入是目录，将处理目录下的视频文件..."
    # 遍历目录下所有文件
    for video in "$INPUT_PATH"/*; do
        # 检查是否已运行超过50分钟（3000秒）
        current_time=$(date +%s)
        elapsed=$(( current_time - START_TIME ))
        if [ $elapsed -ge 3000 ]; then
            echo "运行时间已达到50分钟，停止处理未处理的视频文件。"
            break
        fi
        
        # 判断是否为常见视频文件（根据扩展名，忽略大小写）
        if [ -f "$video" ]; then
            ext="${video##*.}"
            ext_lower=$(echo "$ext" | tr 'A-Z' 'a-z')
            case "$ext_lower" in
                mp4|mov|mkv|avi|flv|wmv|rm|mpg)
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