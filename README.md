# Pure Music

<p align="center">
  <img src="app_icon.png" width="80" height="80" alt="Pure Music Logo">
</p>

<p align="center">面向 Windows 的本地音乐播放器</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Windows-0078D4?style=flat-square" alt="Platform">
  <a href="https://github.com/qingyueyin/Pure-music/releases/latest"><img src="https://img.shields.io/github/v/release/qingyueyin/Pure-music?style=flat-square&color=0969da" alt="Version"></a>
  <a href="https://github.com/qingyueyin/Pure-music/releases/latest"><img src="https://img.shields.io/github/downloads/qingyueyin/Pure-music/total?style=flat-square&color=2ea44f" alt="Downloads"></a>
  <a href="#license"><img src="https://img.shields.io/badge/License-GPL--3.0-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://qingyueyin.github.io/Pure-music/"><img src="https://img.shields.io/badge/网站-使用指南-28a745?style=flat-square" alt="Website"></a>
  <a href="https://gitee.com/qingyueyin/Pure-music"><img src="https://img.shields.io/badge/Gitee-镜像-C71D23?style=flat-square" alt="Gitee"></a>
  <a href="https://t.me/+NsZamWiEKh5lOWNl"><img src="https://img.shields.io/badge/Telegram-群组-2AABEE?style=flat-square" alt="Telegram"></a>
  <a href="https://linux.do"><img src="https://img.shields.io/badge/LINUX_DO-社区-ff7800?style=flat-square" alt="LINUX DO"></a>
</p>

<p align="center">
  <a href="https://trendshift.io/repositories/110656?utm_source=repository-badge&amp;utm_medium=badge&amp;utm_campaign=badge-repository-110656"><img src="https://trendshift.io/api/badge/repositories/110656" alt="Trendshift" width="250" height="55"></a>
</p>

---

## 界面预览

**深色**

<p align="center">
  <img src="screenshot/深色主页.png" width="48%" alt="深色主页">
  <img src="screenshot/深色播放页.png" width="48%" alt="深色播放页">
</p>
<p align="center">
  <img src="screenshot/深色专辑页.png" width="48%" alt="深色专辑页">
  <img src="screenshot/深色沉浸模式.png" width="48%" alt="深色沉浸模式">
</p>
<p align="center">
  <img src="screenshot/深色竖屏.png" width="240" height="420" alt="深色竖屏">
  <img src="screenshot/深色竖屏歌词.png" width="240" height="420" alt="深色竖屏歌词">
  <img src="screenshot/深色竖屏沉浸模式.png" width="240" height="420" alt="深色竖屏沉浸模式">
</p>

**浅色**

<p align="center">
  <img src="screenshot/浅色主页.png" width="48%" alt="浅色主页">
  <img src="screenshot/浅色播放页.png" width="48%" alt="浅色播放页">
</p>
<p align="center">
  <img src="screenshot/浅色网格播放页.png" width="48%" alt="浅色网格播放页">
  <img src="screenshot/浅色专辑页.png" width="48%" alt="浅色专辑页">
</p>
<p align="center">
  <img src="screenshot/浅色沉浸模式.png" width="48%" alt="浅色沉浸模式">
</p>
<p align="center">
  <img src="screenshot/浅色竖屏.png" width="240" height="420" alt="浅色竖屏">
  <img src="screenshot/浅色竖屏歌词.png" width="240" height="420" alt="浅色竖屏歌词">
  <img src="screenshot/浅色竖屏沉浸模式.png" width="240" height="420" alt="浅色竖屏沉浸模式">
</p>

**列表视图**

<p align="center">
  <img src="screenshot/浅色列表.png" width="48%" alt="浅色列表">
  <img src="screenshot/深色列表.png" width="48%" alt="深色列表">
</p>

**曲库**

<p align="center">
  <img src="screenshot/歌单页.png" width="32%" alt="歌单页">
  <img src="screenshot/文件夹页.png" width="32%" alt="文件夹页">
  <img src="screenshot/统计页.png" width="32%" alt="统计页">
</p>
<p align="center">
  <img src="screenshot/专辑详情.png" width="80%" alt="专辑详情">
</p>

**演出模式**

<p align="center">
  <img src="screenshot/演出模式.png" width="80%" alt="演出模式">
</p>

**歌曲详情**

<p align="center">
  <img src="screenshot/歌曲详情.png" width="48%" alt="歌曲详情">
  <img src="screenshot/内嵌歌词.png" width="48%" alt="内嵌歌词">
</p>

**桌面歌词**

<p align="center">
  <img src="screenshot/左对齐主题色歌词.png" width="720" height="198" alt="左对齐主题色歌词">
</p>
<p align="center">
  <img src="screenshot/居中主题色歌词信息歌词.png" width="720" height="198" alt="居中主题色歌词">
</p>
<p align="center">
  <img src="screenshot/右对齐主题色歌词.png" width="720" height="198" alt="右对齐主题色歌词">
</p>

**其他**

<p align="center">
  <img src="screenshot/SMTC.png" width="55%" alt="SMTC">
</p>
<p align="center">
  <img src="screenshot/内嵌数据编辑.png" width="80%" alt="内嵌数据编辑">
</p>

---

## 从源码构建

<details>
<summary>构建命令</summary>

```bash
flutter pub get
flutter run

# 构建 Release
flutter build windows --release

# 修改 Rust 后重新生成 FRB 绑定
# 需先安装: cargo install flutter_rust_bridge_codegen
flutter_rust_bridge_codegen generate
```

</details>

---

## 致谢

| | |
|------|------|
| 图标 | [Silicon7921](https://ray.so/icon) |
| 字体 | [Pretendard Variable](https://github.com/orioncactus/pretendard) |
| 音频 | [BASS](https://www.un4seen.com/) |
| 标签 | [lofty](https://github.com/Serial-ATA/lofty-rs) |
| FFI | [flutter_rust_bridge](https://github.com/fzyzcjy/flutter_rust_bridge) |
| 起源 | [coriander_player](https://github.com/Ferry-200/coriander_player) |
| 参考 | [ZeroBit-Player](https://github.com/Empty-57/ZeroBit-Player) · [Lyrico](https://github.com/Replica0110/Lyrico) · [original-sound-hq-player](https://github.com/Johnwikix/original-sound-hq-player) · [SPlayer](https://github.com/imsyy/SPlayer) · [Unilyric](https://github.com/apoint123/Unilyric) |

---

## 贡献者

[![contrib.rocks](https://contrib.rocks/image?repo=qingyueyin/Pure-music&max=1000&v=2)](https://github.com/qingyueyin/Pure-music/graphs/contributors)

---

## Star History

<a href="https://www.star-history.com/?repos=qingyueyin%2FPure-music&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=qingyueyin/Pure-music&type=date&theme=dark&legend=top-left&sealed_token=3xg2arWalPfLMWP-v8tF6oiUigXHChZGv3G5byMARkfFx4mAH_bKPZWuYsOGt0OXyQAacmwE94DO-yNQKFu3d1xE7KqjHBRQ1PXDBRrIb9-lsK6IVQyzdA" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=qingyueyin/Pure-music&type=date&theme=light&legend=top-left&sealed_token=3xg2arWalPfLMWP-v8tF6oiUigXHChZGv3G5byMARkfFx4mAH_bKPZWuYsOGt0OXyQAacmwE94DO-yNQKFu3d1xE7KqjHBRQ1PXDBRrIb9-lsK6IVQyzdA" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=qingyueyin/Pure-music&type=date&theme=light&legend=top-left&sealed_token=3xg2arWalPfLMWP-v8tF6oiUigXHChZGv3G5byMARkfFx4mAH_bKPZWuYsOGt0OXyQAacmwE94DO-yNQKFu3d1xE7KqjHBRQ1PXDBRrIb9-lsK6IVQyzdA" />
 </picture>
</a>

---

## License

代码遵循 [GPL-3.0](LICENSE)。

请尊重（非法律条款）：仅限非商业用途；使用或修改时注明出处，并附上本仓库链接。

---

## 免责声明

软件不包含音乐、歌词等版权内容，播放的是你本地已有的文件。在线歌词来自第三方平台，版权归原平台及权利人所有。使用本软件产生的版权、法律问题由使用者自行承担。

---

<div align="center">Made with ❤️ by qingyueyin</div>
