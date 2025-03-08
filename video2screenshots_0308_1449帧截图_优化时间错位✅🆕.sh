#!/bin/bash

# ----------------------------------------------
# 用法:
#   ./video2screenshots.sh <视频文件或目录> [<视频文件或目录> ...]
# 例如:
#   ./video2screenshots.sh ~/Movies/myvideo.mp4 ~/Movies/
# ----------------------------------------------

# 设定可能的环境路径
export PATH="/opt/homebrew/bin:/bin:/usr/bin:/usr/local/bin:$PATH"

# 获取脚本路径、创建log文件夹与log文件
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR="${SCRIPT_DIR}/video2screenshots_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/video2screenshots_$(date '+%Y-%m-%d').log"

# 构建log函数
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "脚本启动，所在目录: ${SCRIPT_DIR}"

# 创建锁文件，如果已有锁文件且处于锁定状态则说明已有该脚本实例在运行，退出当前实例
LOCKFILE="$(dirname "$0")/video2screenshots.lock"
exec 200>"$LOCKFILE"
lockf -t 0 200 || { log "脚本已在运行，退出"; exit 1; }

# 构建视频处理函数
process_video() {
    # 获取视频路径、目录路径、视频文件名
    local VIDEO_PATH="$1"
    VIDEO_PATH="$(realpath "$VIDEO_PATH")"
    VIDEO_DIR="$(dirname "$VIDEO_PATH")"
    BASENAME=$(basename "$VIDEO_PATH")
    PREFIX="${BASENAME%.*}"

    log "开始处理视频: ${VIDEO_PATH}"

    ESCAPED_PREFIX=$(echo "$PREFIX" | sed -e 's/\[/\\[/g' -e 's/\]/\\]/g')

    # 创建临时截图目录
    SCREENSHOT_DIR="${SCRIPT_DIR}/${PREFIX}_screenshots"
    mkdir -p "$SCREENSHOT_DIR"
    log "创建临时截图目录: ${SCREENSHOT_DIR}"

    # 获取总时长
    duration=$(ffprobe -i "$VIDEO_PATH" -show_entries format=duration -v quiet -of csv="p=0")

    # 获取总帧数 (NB: 一些视频封装格式可能需改用 -count_packets 等)
    # 如果 nb_frames 获取不到，可以考虑换一下命令，比如： -count_frames -show_entries stream=nb_read_frames
    nb_frames=$(ffprobe -v error -select_streams v:0 -show_entries stream=nb_frames -of csv=p=0 "$VIDEO_PATH" 2>/dev/null)
    # 如果某些视频 nb_frames 获取不到，会返回空，这里给个兜底处理
    if [ -z "$nb_frames" ] || [ "$nb_frames" = "N/A" ]; then
        nb_frames=$(ffprobe -v error -select_streams v:0 -count_packets \
                    -show_entries stream=nb_read_packets -of csv=p=0 "$VIDEO_PATH" 2>/dev/null)
        if [ -z "$nb_frames" ] || [ "$nb_frames" = "N/A" ]; then
            log "无法获取视频总帧数，跳过处理。"
            return
        fi
    fi
    log "视频总时长 $duration 秒， 总帧数: $nb_frames"

    # 获取分辨率来判断横竖屏
    video_resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$VIDEO_PATH")
    width=$(echo "$video_resolution" | cut -d',' -f1)
    height=$(echo "$video_resolution" | cut -d',' -f2)
    if [ "$width" -ge "$height" ]; then
        orientation="landscape"
    else
        orientation="portrait"
    fi
    log "视频分辨率: ${width}x${height}，视频方向: ${orientation}"

    # 设定前跳过时间
    pre_skip_seconds=0.2
    # 计算有效时长
    effective_duration=$(echo "$duration - $pre_skip_seconds" | bc -l)
    log "跳过前 $pre_skip_seconds 秒，视频有效时长 $effective_duration 秒。"

    # 根据总帧数和时长计算平均帧率，再估算有效帧数
    fps=$(echo "scale=5; $nb_frames / $duration" | bc -l)
    effective_nb_frames=$(echo "$fps * $effective_duration" | bc -l)
    effective_nb_frames=$(printf "%.0f" "$effective_nb_frames")
    log "视频平均帧率 $effective_nb_frames ，有效帧数 $effective_nb_frames . "

    # 根据有效时长计算所需截图数量
    if [ $(echo "$effective_duration < 8" | bc -l) -eq 1 ]; then
        interval=1
        desired_count=$(echo "($effective_duration / $interval) + 1" | bc -l)
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
                interval=60
                desired_count=$(echo "($effective_duration / $interval) + 1" | bc -l)
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
                interval=60
                desired_count=$(echo "($effective_duration / $interval) + 1" | bc -l)
                desired_count=$(printf "%.0f" "$desired_count")
            fi
        fi
    fi



    # 计算帧间隔(整数)
    # 为了让想让首尾截图都包含，需要用 desired_count-1 做分母，如果 desired_count=10，那么间隔=总帧数/(10-1)
    if [ "$desired_count" -le 1 ]; then
        frame_interval=1
    else
        frame_interval=$(echo "$effective_nb_frames" | bc) # 暂时去掉了 - 1 - 1
        frame_interval=$(echo "$frame_interval / ($desired_count - 1)" | bc)
    fi
    if [ "$frame_interval" -lt 1 ]; then
        frame_interval=1
    fi
    log "期望生成 ${desired_count} 张截图；计算出的帧间隔: ${frame_interval}"

    # 检测是否含字幕流
    subtitle_stream=$(ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 "$VIDEO_PATH")
    if [ -z "$subtitle_stream" ]; then
        subtitle_filter=""
        log "未检测到字幕流。"
    else
        subtitle_filter="subtitles='${VIDEO_PATH}',"
        log "检测到字幕流，将进行字幕处理。"
    fi

    # 将原来的 fps=1/$interval 改为 select='not(mod(n,frame_interval))'
    # 其余如 scale、drawtext 均可保持原有逻辑
    # 注意这里 -vsync vfr 表示按过滤器抽出来的帧来输出
    filter="${subtitle_filter}select='not(mod(n,$frame_interval))',scale='if(gt(min(iw,ih),360),if(gt(iw,ih),-2,360),iw)':'if(gt(min(iw,ih),360),if(gt(iw,ih),360,-2),ih)',drawtext=text='%{pts\\:hms}  ':x=w-tw-12:y=h-th-12:fontsize=22:fontcolor=white:box=1:boxcolor=black@0.5:boxborderw=4"

    log "开始提取截图 (基于帧间隔)，使用过滤器: ${filter}"

    nice -n 19 ffmpeg \
        -ss "$pre_skip_seconds" \
        -i "$VIDEO_PATH" \
        -vf "[0:v]setpts=PTS-STARTPTS+${pre_skip_seconds}/TB,$filter" \
        -vsync vfr \
        -qscale:v 1 \
        -frames:v ${desired_count} \
        "${SCREENSHOT_DIR}/${PREFIX}_%04d.jpg"

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

    montage -quality 75 -tile "$tile" -geometry +1+1 \
        "${SCREENSHOT_DIR}/${ESCAPED_PREFIX}_*.jpg" \
        "${VIDEO_DIR}/${PREFIX}_screenshot.jpg"

    if [ $? -eq 0 ]; then
        log "拼图完成，输出文件: ${VIDEO_DIR}/${PREFIX}_screenshot.jpg"
    else
        log "错误: 拼图过程失败。"
    fi

    rm -rf "$SCREENSHOT_DIR"
    log "删除临时截图目录: ${SCREENSHOT_DIR}"
}

# 无传入参数则退出当前实例
if [ $# -lt 1 ]; then
    log "错误: 参数不足。用法: $0 <视频文件或目录> [<视频文件或目录> ...]"
    exit 1
fi

# 记录开始时间
START_TIME=$(date +%s)
log "开始处理传入参数，共计 $# 个参数。"

VIDEO_EXTENSIONS=("mp4" "mov" "mkv" "avi" "flv" "wmv" "rm" "mpg")
IGNORE_KEYWORDS=("ignore" "tmp" "@eaDir")
PREVIEW_SUFFIX="_screenshot.jpg"
TIMEOUT_LIMIT=13800  # 3小时50分钟

# 处理视频文件函数
process_video_file() {
    local video="$1"
    local video_dir
    local base
    local prefix
    local screenshot_file

    video_dir=$(dirname "$video")
    base=$(basename "$video")
    prefix="${base%.*}"
    screenshot_file="${video_dir}/${prefix}${PREVIEW_SUFFIX}"

    if [ -f "$screenshot_file" ]; then
        log "视频文件 ${video} 已存在预览截图 ${screenshot_file}，跳过。"
    else
        process_video "$video"
    fi
}

# 处理目录函数
process_directory() {
    local input_path="$1"
    log "检测到目录: $input_path ，开始递归处理目录下的视频文件..."

    local PRUNE_CONDITION=""
    for keyword in "${IGNORE_KEYWORDS[@]}"; do
        PRUNE_CONDITION+=" -path \"*/${keyword}/*\" -o"
    done
    PRUNE_CONDITION=${PRUNE_CONDITION% -o}

    local videos=()
    # 使用find直接查找视频文件，并通过 -print0 保证特殊字符被正确处理
    while IFS= read -r -d '' video; do
        videos+=("$video")
    done < <(find "$input_path" \( $PRUNE_CONDITION \) -prune -o -type f \( \
        -iname "*.${VIDEO_EXTENSIONS[0]}" -o \
        -iname "*.${VIDEO_EXTENSIONS[1]}" -o \
        -iname "*.${VIDEO_EXTENSIONS[2]}" -o \
        -iname "*.${VIDEO_EXTENSIONS[3]}" -o \
        -iname "*.${VIDEO_EXTENSIONS[4]}" -o \
        -iname "*.${VIDEO_EXTENSIONS[5]}" -o \
        -iname "*.${VIDEO_EXTENSIONS[6]}" -o \
        -iname "*.${VIDEO_EXTENSIONS[7]}" \) -print0)

    # 处理视频时检查超时
    for video in "${videos[@]}"; do
        current_time=$(date +%s)
        elapsed=$(( current_time - START_TIME ))
        if [ $elapsed -ge $TIMEOUT_LIMIT ]; then
            log "运行时间已达到3小时50分 ，停止处理未处理的视频文件。"
            break 2
        fi
        process_video_file "$video"
    done
}

# 处理文件函数
process_file() {
    local input_path="$1"
    local base
    local ext
    local ext_lower

    base=$(basename "$input_path")
    ext="${base##*.}"
    ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

    case "$ext_lower" in
        mp4|mov|mkv|avi|flv|wmv|rm|mpg)
            process_video_file "$input_path"
            ;;
        *)
            log "错误: 参数 $input_path 不是视频文件"
            ;;
    esac
}

# 主程序
for INPUT_PATH in "$@"; do
    if [ -d "$INPUT_PATH" ]; then
        process_directory "$INPUT_PATH"
    elif [ -f "$INPUT_PATH" ]; then
        process_file "$INPUT_PATH"
    else
        log "错误: 参数 $INPUT_PATH 既不是文件也不是目录"
    fi
done



END_TIME=$(date +%s)
duration_total=$(( END_TIME - START_TIME ))
log "所有任务完成，总耗时 ${duration_total} 秒。"