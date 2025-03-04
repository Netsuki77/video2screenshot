# video2screenshot

video2screenshot 是一个便捷的命令行工具，用于自动生成视频文件的多帧截图预览图。它能帮助你快速创建视频缩略图，方便视频内容概览、管理与归档，同时也可以轻松集成到更复杂的自动化工作流中，提升视频处理效率，适合视频库整理和媒体资源管理。

## 主要特性
* 多平台支持：兼容 macOS、Linux 等可运行ffmpeg与ImageMagick的系统。
* 依赖：借助 ffmpeg 快速提取视频帧，并利用 ImageMagick 进行图像合成。
* 自动判断截图数量：根据视频长度自动化判断所需截图的数量，用户可根据注释自行修改参数以自定义规则。

## 使用方式
1. 前置条件：安装ffmpeg与ImageMagick
  * Linux：可使用`apt`命令从系统软件仓库中安装。
  * MacOS：建议先安装“Homebrew”，借助“Homebrew”安装ffmpeg与ImageMagick。




 
