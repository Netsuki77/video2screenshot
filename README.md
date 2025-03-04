# video2screenshot

video2screenshot 是一个便捷的命令行工具，用于自动生成视频文件的多帧截图预览文件。因为我在MacOS上找不到可以实现这个功能的软件所以写了这个脚本。它能帮助你快速创建视频缩略图，方便视频内容概览、管理与归档，同时也可以轻松集成到更复杂的自动化工作流中，提升视频处理效率，适合视频库整理和媒体资源管理。

生成的多帧截图预览文件示例：
\n<img src="https://github.com/NetsukiAo/video2screenshot/blob/main/SampleResults.jpg" alt="示例图片" width="600"/>

## 主要特性

* 多平台支持：兼容 macOS、Linux 等可运行ffmpeg与ImageMagick的系统。
* 依赖：借助 ffmpeg 快速提取视频帧，并利用 ImageMagick 进行图像合成。
* 自动判断截图数量：根据视频长度自动化判断所需截图的数量，用户可根据注释自行修改参数以自定义规则。

## 使用方式

1. **前置条件**  
   确保已安装以下工具：  
   - **ffmpeg**  
   - **ImageMagick**  
   - **安装方法：**  
     - **Linux：** 使用 `apt` 命令从系统软件仓库中安装。  
     - **macOS：** 推荐先安装 [Homebrew](https://brew.sh/)，然后通过 Homebrew 安装 ffmpeg 与 ImageMagick。  

2. **运行脚本**  
   下载仓库中的`video2screenshots.sh`，在任意目录下运行该脚本，需传入视频文件的绝对路径作为唯一参数。示例命令如下：  
   ```bash
   <path>/video2screenshots.sh "<path>/<videoFileName>.mkv"
   ```

3. **生成预览图**
   - 脚本会在其所在目录下创建一个以视频文件同名的文件夹，用于存储临时截图文件。
   - 运行完成后，该临时文件夹及其中所有文件会被自动删除。
   - 最终生成的多帧截图预览文件将保存在视频文件所在目录中，文件名与视频文件相同。

🌟如果觉得这个脚本不错，或者有帮助到你，可以点个星（右上角的Star）关注这个项目。今后我可能会继续优化这个脚本或者增加更多不同的版本以针对性优化不同的用例。

## 其他说明

- 默认的截图数量判断规则是：
   - 视频长度小于30秒，每3秒生成一张截图
   - 视频长度小于1分钟，固定生成12张截图
   - 视频长度小于2分钟，固定生成14张截图
   - 视频长度小于4分钟，固定生成16张截图
   - 视频长度小于8分钟，固定生成20张截图
   - 视频长度小于15分钟，固定生成24张截图
   - 视频长度小于30分钟，固定生成28张截图
   - 视频长度小于60分钟，固定生成32张截图
   - 视频长度超过60分钟，每120秒生成一张截图
- 截图时默认包含字幕，如果不需要字幕可删除脚本中的`subtitles='${VIDEO_PATH}',`。
- 默认包含每张截图的时间戳，如果不需要时间戳可删除脚本中的`,drawtext=text='%{pts\:hms}  ':x=w-tw-12:y=h-th-12:fontsize=22:fontcolor=white:box=1:boxcolor=black@0.5:boxborderw=4`。
- 默认每张截图缩小至短边不大于360，如需修改可将脚本中所有的`360`修改为所需数值。

---

# video2screenshot

video2screenshot is a convenient command-line tool that automatically generates multi-frame preview images from video files. Because I couldn't find any software on macOS that offered this functionality, I wrote this script. It helps you quickly create video thumbnails for easy content overview, management, and archiving, and can be seamlessly integrated into more complex automation workflows to boost video processing efficiency. This tool is perfect for organizing video libraries and managing media resources.

Example of generated multi-frame preview image:
<img src="https://github.com/NetsukiAo/video2screenshot/blob/main/SampleResults.jpg" alt="Sample Image" width="600"/>

## Key Features

- **Cross-Platform Support:** Compatible with systems like macOS and Linux that support ffmpeg and ImageMagick.
- **Dependencies:** Utilizes ffmpeg for fast frame extraction and ImageMagick for image composition.
- **Automatic Frame Calculation:** Determines the required number of screenshots based on the video length automatically. Users can modify parameters in the script comments to customize this behavior.

## How to Use

1. **Prerequisites**  
   Ensure that the following tools are installed:  
   - **ffmpeg**  
   - **ImageMagick**  
   - **Installation Methods:**  
     - **Linux:** Install using the `apt` command from your system's repository.  
     - **macOS:** It is recommended to install [Homebrew](https://brew.sh/) first, then install ffmpeg and ImageMagick via Homebrew.

2. **Running the Script**  
   Download the `video2screenshots.sh` from the repository, execute the script from any directory by providing the absolute path to the video file as the only parameter. For example:  
   ```bash
   <path>/video2screenshots.sh "<path>/<videoFileName>.mkv"
   ```
3.	**Generating the Preview Image**
   - The script creates a temporary folder (named after the video file) in its directory to store the screenshot files.
   - Once the process is complete, the temporary folder and all its contents are automatically deleted.
   - The final multi-frame preview image is saved in the same directory as the video file, using the video file’s name.

🌟If you find this script helpful, please give it a star (click the Star button at the top right) to follow the project. I may continue to improve this script or add different versions in the future to better optimize for various use cases.

## Additional Notes

- **Default Screenshot Count Rules:**
  - For videos shorter than 30 seconds, one screenshot is taken every 3 seconds.
  - For videos shorter than 1 minute, a fixed 12 screenshots are generated.
  - For videos shorter than 2 minutes, a fixed 14 screenshots are generated.
  - For videos shorter than 4 minutes, a fixed 16 screenshots are generated.
  - For videos shorter than 8 minutes, a fixed 20 screenshots are generated.
  - For videos shorter than 15 minutes, a fixed 24 screenshots are generated.
  - For videos shorter than 30 minutes, a fixed 28 screenshots are generated.
  - For videos shorter than 60 minutes, a fixed 32 screenshots are generated.
  - For videos longer than 60 minutes, one screenshot is taken every 120 seconds.
  
- **Subtitles:**  
  By default, the screenshots include subtitles. If you do not need the subtitles, remove the `subtitles='${VIDEO_PATH}',` part from the script.

- **Timestamps:**  
  Each screenshot includes a timestamp by default. If you do not want the timestamp, remove the `,drawtext=text='%{pts\:hms}  ':x=w-tw-12:y=h-th-12:fontsize=22:fontcolor=white:box=1:boxcolor=black@0.5:boxborderw=4` segment from the script.

- **Image Size:**  
  Each screenshot is automatically resized so that its shorter side is no greater than 360 pixels. To modify this, change all instances of `360` in the script to your desired value.
