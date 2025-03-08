#!/bin/bash

# ----------------------------------------------
# 用法:
#   ./video2screenshots.sh <视频文件或目录> [<视频文件或目录> ...]
# 例如:
#   ./video2screenshots.sh ~/Movies/myvideo.mp4 ~/Movies/
# ----------------------------------------------

export PATH="/opt/homebrew/bin:/bin:/usr/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="${SCRIPT_DIR}/video2screenshots_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/video2screenshots_$(date '+%Y-%m-%d').log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "脚本启动，所在目录: ${SCRIPT_DIR}"

LOCKFILE="$(dirname "$0")/video2screenshots.lock"
exec 200>"$LOCKFILE"
lockf -t 0 200 || { log "脚本已在运行，退出"; exit 1; }

process_video() {
    local VIDEO_PATH="$1"
    VIDEO_PATH="$(realpath "$VIDEO_PATH")"
    VIDEO_DIR="$(dirname "$VIDEO_PATH")"
    BASENAME=$(basename "$VIDEO_PATH")
    PREFIX="${BASENAME%.*}"

    log "开始处理视频: ${VIDEO_PATH}"

    ESCAPED_PREFIX=$(echo "$PREFIX" | sed -e 's/\[/\\[/g' -e 's/\]/\\]/g')

    SCREENSHOT_DIR="${SCRIPT_DIR}/${PREFIX}_screenshots"
    mkdir -p "$SCREENSHOT_DIR"
    log "创建临时截图目录: ${SCREENSHOT_DIR}"

    duration=$(ffprobe -i "$VIDEO_PATH" -show_entries format=duration -v quiet -of csv="p=0")
    duration_int=$(printf "%.0f" "$duration")

    video_resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$VIDEO_PATH")
    width=$(echo "$video_resolution" | cut -d',' -f1)
    height=$(echo "$video_resolution" | cut -d',' -f2)
    if [ "$width" -ge "$height" ]; then
        orientation="landscape"
    else
        orientation="portrait"
    fi
    log "视频分辨率: ${width}x${height}，视频方向: ${orientation}"

    # 使用浮点数计算有效时长
    pre_skip_seconds=0
    effective_duration=$(echo "$duration - $pre_skip_seconds" | bc -l)

    # 计算截图间隔和截图数量
    # 对于非常短的视频 (<8秒)，依然采用1秒间隔
    if [ $(echo "$effective_duration < 8" | bc -l) -eq 1 ]; then
        interval=1
        desired_count=$(echo "$effective_duration / 1 + 1" | bc -l)
        desired_count=$(printf "%.0f" "$desired_count")
    else
        if [ "$orientation" = "portrait" ]; then
            if [ $(echo "$effective_duration < 12" | bc -l) -eq 1 ]; then
                desired_count=8
            elif [ $(echo "$effective_duration < 15" | bc -l) -eq 1 ]; then
                desired_count=12
            elif [ $(echo "$effective_duration < 30" | bc -l) -eq 1 ]; then
                desired_count=15
            elif [ $(echo "$effective_duration < 60" | bc -l) -eq 1 ]; then
                desired_count=15
            elif [ $(echo "$effective_duration < 120" | bc -l) -eq 1 ]; then
                desired_count=18
            elif [ $(echo "$effective_duration < 240" | bc -l) -eq 1 ]; then
                desired_count=18
            elif [ $(echo "$effective_duration < 480" | bc -l) -eq 1 ]; then
                desired_count=21
            elif [ $(echo "$effective_duration < 900" | bc -l) -eq 1 ]; then
                desired_count=24
            elif [ $(echo "$effective_duration < 1800" | bc -l) -eq 1 ]; then
                desired_count=28
            else
                desired_count=$(echo "($effective_duration / 60) + 1" | bc -l)
                desired_count=$(printf "%.0f" "$desired_count")
            fi
        else
            if [ $(echo "$effective_duration < 12" | bc -l) -eq 1 ]; then
                desired_count=8
            elif [ $(echo "$effective_duration < 15" | bc -l) -eq 1 ]; then
                desired_count=12
            elif [ $(echo "$effective_duration < 30" | bc -l) -eq 1 ]; then
                desired_count=16
            elif [ $(echo "$effective_duration < 60" | bc -l) -eq 1 ]; then
                desired_count=16
            elif [ $(echo "$effective_duration < 120" | bc -l) -eq 1 ]; then
                desired_count=16
            elif [ $(echo "$effective_duration < 240" | bc -l) -eq 1 ]; then
                desired_count=20
            elif [ $(echo "$effective_duration < 480" | bc -l) -eq 1 ]; then
                desired_count=20
            elif [ $(echo "$effective_duration < 900" | bc -l) -eq 1 ]; then
                desired_count=24
            elif [ $(echo "$effective_duration < 1800" | bc -l) -eq 1 ]; then
                desired_count=28
            else
                desired_count=$(echo "($effective_duration / 60) + 1" | bc -l)
                desired_count=$(printf "%.0f" "$desired_count")
            fi
        fi
        # 计算截图间隔，确保最后一帧出现在视频末尾
        interval=$(echo "scale=4; ($effective_duration - 0.1)/($desired_count - 1)" | bc -l)
    fi

    log "视频时长：${duration_int}秒，有效时长：${effective_duration}秒，截图间隔设为：${interval}秒，每个视频预计生成截图数量: ${desired_count}"

    subtitle_stream=$(ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 "$VIDEO_PATH")
    if [ -z "$subtitle_stream" ]; then
        subtitle_filter=""
        log "未检测到字幕流。"
    else
        subtitle_filter="subtitles='${VIDEO_PATH}',"
        log "检测到字幕流，将进行字幕处理。"
    fi

    filter="${subtitle_filter}fps=1/${interval}:round=up,scale='if(gt(min(iw,ih),360),if(gt(iw,ih),-2,360),iw)':'if(gt(min(iw,ih),360),if(gt(iw,ih),360,-2),ih)',drawtext=text='%{pts\\:hms}  ':x=w-tw-12:y=h-th-12:fontsize=22:fontcolor=white:box=1:boxcolor=black@0.5:boxborderw=4"
    log "开始提取截图，使用过滤器: ${filter}"

    total_time=$(echo "$effective_duration + 1" | bc -l)
    nice -n 19 ffmpeg -ss "$pre_skip_seconds" -t "$total_time" -i "$VIDEO_PATH" -vf "$filter" -qscale:v 1 -frames:v ${desired_count} "${SCREENSHOT_DIR}/${PREFIX}_%04d.jpg"
    if [ $? -eq 0 ]; then
        log "视频截图提取成功。"
    else
        log "错误: 视频截图提取失败。"
        return
    fi

    num=$(ls "${SCREENSHOT_DIR}/${PREFIX}"_*.jpg 2>/dev/null | wc -l)
    if [ "$orientation" = "landscape" ]; then
        if [ "$num" -le 6 ]; then
            tile="2x"
        elif [ "$num" -le 12 ]; then
            tile="3x"
        elif [ "$num" -le 32 ]; then
            tile="4x"
        else
            tile="5x"
        fi
    else
        if [ "$num" -le 6 ]; then
            tile="3x"
        elif [ "$num" -le 12 ]; then
            tile="4x"
        elif [ "$num" -le 15 ]; then
            tile="5x"
        elif [ "$num" -le 18 ]; then
            tile="6x"
        elif [ "$num" -le 21 ]; then
            tile="7x"
        elif [ "$num" -le 24 ]; then
            tile="6x"
        elif [ "$num" -le 28 ]; then
            tile="7x"
        else
            tile="8x"
        fi
    fi

    log "共截取 ${num} 张图片，拼接时每行使用 ${tile%%x} 张图片"

    montage -quality 75 -tile "$tile" -geometry +1+1 "${SCREENSHOT_DIR}/${ESCAPED_PREFIX}_*.jpg" "${VIDEO_DIR}/${PREFIX}_screenshot.jpg"
    if [ $? -eq 0 ]; then
        log "拼图完成，输出文件: ${VIDEO_DIR}/${PREFIX}_screenshot.jpg"
    else
        log "错误: 拼图过程失败。"
    fi

    rm -rf "$SCREENSHOT_DIR"
    log "删除临时截图目录: ${SCREENSHOT_DIR}"
}

if [ $# -lt 1 ]; then
    log "错误: 参数不足。用法: $0 <视频文件或目录> [<视频文件或目录> ...]"
    exit 1
fi

START_TIME=$(date +%s)
log "开始处理传入参数，共计 $# 个参数。"

# 遍历所有传入的参数
for INPUT_PATH in "$@"; do
    if [ -d "$INPUT_PATH" ]; then
        log "检测到目录: $INPUT_PATH，开始递归处理目录下的视频文件..."
        videos=()
        
        # 定义需要忽略的关键词列表，可根据需要修改
        IGNORE_KEYWORDS=("ignore" "tmp" "@eaDir")
        PRUNE_CONDITION=""
        for keyword in "${IGNORE_KEYWORDS[@]}"; do
            PRUNE_CONDITION+=" -path \"*/${keyword}/*\" -o"
        done
        PRUNE_CONDITION=${PRUNE_CONDITION% -o}
        
        # 使用 eval 构造并执行 find 命令，忽略包含指定关键词的目录
        while IFS= read -r video; do
            video_dir=$(dirname "$video")
            base=$(basename "$video")
            prefix="${base%.*}"
            screenshot_file="${video_dir}/${prefix}_screenshot.jpg"
            if [ -f "$screenshot_file" ]; then
                log "视频文件 ${video} 已存在预览截图 ${screenshot_file}，跳过。"
                continue
            fi
            videos+=("$video")
        done < <(eval "find \"$INPUT_PATH\" \( $PRUNE_CONDITION \) -prune -o -type f \( -iname \"*.mp4\" -o -iname \"*.mov\" -o -iname \"*.mkv\" -o -iname \"*.avi\" -o -iname \"*.flv\" -o -iname \"*.wmv\" -o -iname \"*.rm\" -o -iname \"*.mpg\" \) -print")
        
        for video in "${videos[@]}"; do
            current_time=$(date +%s)
            elapsed=$(( current_time - START_TIME ))
            if [ $elapsed -ge 3300 ]; then
                log "运行时间已达到55分钟，停止处理未处理的视频文件。"
                break 2
            fi
            process_video "$video"
        done
    elif [ -f "$INPUT_PATH" ]; then
        base=$(basename "$INPUT_PATH")
        ext="${base##*.}"
        ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
        case "$ext_lower" in
            mp4|mov|mkv|avi|flv|wmv|rm|mpg)
                video_dir=$(dirname "$INPUT_PATH")
                prefix="${base%.*}"
                screenshot_file="${video_dir}/${prefix}_screenshot.jpg"
                if [ -f "$screenshot_file" ]; then
                    log "视频文件 $(realpath "$INPUT_PATH") 已存在预览截图 ${screenshot_file}，跳过。"
                else
                    process_video "$INPUT_PATH"
                fi
                ;;
            *)
                log "错误: 参数 $INPUT_PATH 不是视频文件"
                ;;
        esac
    else
        log "错误: 参数 $INPUT_PATH 既不是文件也不是目录"
    fi
done

END_TIME=$(date +%s)
duration_total=$(( END_TIME - START_TIME ))
log "所有任务完成，总耗时 ${duration_total} 秒。"