# Issue 提交规范

先看 [常见问题](https://qingyueyin.github.io/Pure-music/guide/faq)。还不能确认是程序问题时，先到 [Discussions](https://github.com/qingyueyin/Pure-music/discussions/categories/general)。已经能复现的异常，再用对应模板提交。

## 用哪个入口

| 情况 | 入口 |
|------|------|
| 能复现的异常 | [Bug 模板](https://github.com/qingyueyin/Pure-music/issues/new?template=01-bug_report.yml) |
| 新功能 | [新功能模板](https://github.com/qingyueyin/Pure-music/issues/new?template=02-feature_request.yml) |
| 现有功能改进 | [改进模板](https://github.com/qingyueyin/Pure-music/issues/new?template=03-enhancement.yml) |
| 文档问题 | [文档模板](https://github.com/qingyueyin/Pure-music/issues/new?template=04-documentation.yml) |

应用内路径：设置 → 关于 → 报告问题。点「提交问题」会打开 Bug 表单，并把日志快照复制到剪贴板。请把快照粘贴到「完整日志」，再补全安装方式、问题分类等必填项。不要把应用生成的快照换成自己打开的 `.log` 文件。

## 日志快照怎么读

应用生成的是一份给人和 AI 看的快照，不是磁盘上的原始日志。主要段落：

| 段落 | 内容 |
|------|------|
| `APP` | 版本和构建模式 |
| `ENV` | 系统、运行时、语言 |
| `PREF` / `SETTINGS` | 播放、歌词、窗口等当前设置 |
| `NOW_PLAYING` | 当时的播放状态、进度、曲目时长、输出信息 |
| `APPLICATION_LOG` | 折叠后的时间线 |
| `CRASH_LOG` | 若有崩溃，相同异常只留最近一次 |
| `AUDIO_ECHO_LOG` | 仅在开过回声录制时出现 |

`APPLICATION_LOG` 的阅读顺序：

1. 开头的等级计数和 `modules=`：哪些模块在报 warn/error。
2. `-- problems --`：把相同警告收成一条，并标次数和首尾时间。没有问题则是 `problems=-`。
3. `-- timeline --`：按时间排列的标题。只含 info 及以上；连续重复会写成 `×N until 最后时间`。debug 默认不出现。
4. `-- detail ... --`：最近几条警告前后、同一模块的 debug，用来看警告发生时在干什么。

播放问题先找：

```
INFO playback song.changed | reason=... to=... at=... length=...
WARN playback song.advanced_early | at=... length=...
```

- `reason`：`completed` 自然结束，`user.next` / `user.previous` / `user.play` 用户操作，`gapless` 无缝，`smart` 智能切歌，`restore` 恢复进度。
- `at` / `length`：切歌决定前已经跟踪到的进度和曲目时长，不是切完之后的播放器读数。
- 只有 `reason=completed` 且明显没到结尾时才会出现 `song.advanced_early`。

快照里若出现 `TRUNCATED|omittedChars=`，表示按体积截过，已优先保留警告和较新的 info。公开前遮盖访问令牌、账号、无关私人路径，保留出错前后的上下文。

## Bug 模板字段

应用内提交一般会带上版本、Windows 版本，以及描述里能对应上的步骤/期望/实际结果。下面这些仍要在 GitHub 上补全：

- 安装方式、问题分类、最后正常版本
- 常见问题自查结果
- 与问题相关的环境信息（输出设备、文件格式、曲库规模等）
- 复现材料（原文件、对照结果、截图或录屏）
- 提交前确认

音频、标签或歌词问题请提供原文件或可复现样本，并用一个已确认正常的文件对照。日志与问题确实无关时，写明原因。

缺少日志、复现步骤、相关文件或自查结果时，Issue 可能会先关闭；补全后可以重新评估。

## 提交之后

请继续关注评论，按要求补充材料。不要用新 Issue 重复同一件事；有新日志或新样本，直接回在原贴。