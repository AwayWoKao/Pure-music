---
outline: deep
description: 下载安装版或便携版。Windows 10 / 11，无需管理员。
---

# 下载

安装版或便携版。按钮直达当前最新包。

<DownloadCard />

::: tip 下哪个文件？

- **安装版**：文件名带 `installer` 的 `.exe`
- **便携版**：文件名带 `portable` 的 `.zip`
- `Source code` 是源码，不能直接运行

历史版本见 [GitHub Releases](https://github.com/qingyueyin/Pure-music/releases)。GitHub 慢可用 [Gitee](https://gitee.com/qingyueyin/Pure-music)，镜像常滞后，请核对版本号。
:::

## 系统要求

- **Windows 10 / 11**（7 / 8 不可用）
- 建议 4GB 内存，约 100MB 磁盘空间
- 建议安装最新 Visual C++ 可再发行组件

## 安装版

1. 运行 `*_release_installer.exe`
2. 按向导安装（默认 `%LOCALAPPDATA%\Programs\Pure Music`，当前用户，无需管理员）
3. 开始菜单会创建；桌面快捷方式默认不勾
4. 本机还没有安装版数据时，可从便携版导入
5. 启动后按欢迎页添加音乐文件夹

| 用途 | 路径 |
|------|------|
| 程序 | `%LOCALAPPDATA%\Programs\Pure Music` |
| 数据 | `%LOCALAPPDATA%\pure_music` |

备份只拷数据目录即可。

## 便携版

1. 完整解压，不要在压缩包里直接运行
2. 放到有写入权限的目录
3. 运行 `pure_music.exe`，按欢迎页添加音乐文件夹

配置、曲库和缓存写在程序旁的 `data/`。迁移时保留整个程序目录。

::: warning 不要只复制 exe
同目录还需要 DLL、`dll/` 和 `desktop_lyric/`。
:::

## 更新

**安装版**：完全退出后，运行新安装程序覆盖。数据一般还在。

**便携版**：退出 → 备份旧目录 `data/` → 新版解到新目录 → 拷入 `data/` → 确认后再删旧目录。不要用旧文件覆盖新版本。

## 卸载

**安装版**：在「已安装的应用」里卸载。结束时可选是否删除用户数据（默认保留）。

**便携版**：退出后删除整个程序目录。要留配置就先备份 `data/`。

## SmartScreen 与杀软

首次运行可能弹出 SmartScreen：点「更多信息」→「仍要运行」。

杀软误报时，把程序目录加入白名单。

更多见 [更新日志](/guide/changelog)、[常见问题](/guide/faq)。
