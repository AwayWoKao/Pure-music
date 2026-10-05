---
outline: deep
description: 报告问题、提交代码或改文档。
---

# 贡献指南

代码、文档或反馈都可以。

## 报告问题

- 先看 [常见问题](/guide/faq)
- 还不确定是不是程序问题，先到 [Discussions](https://github.com/qingyueyin/Pure-music/discussions/categories/general)
- 能复现的异常，用 [Issue 模板](https://github.com/qingyueyin/Pure-music/issues/new/choose)
- 「设置 → 关于 → 报告问题」会打开 Bug 表单并复制日志快照，粘贴到「完整日志」，不要用原始 `.log` 代替。见 [Issue 提交规范](https://github.com/qingyueyin/Pure-music/blob/main/.github/ISSUE_GUIDELINES.md)

## 提交代码

1. Fork 后从 `main` 开功能分支
2. 按 [构建](/dev/build) 跑起来
3. `flutter analyze` 无错误，并跑相关测试
4. 说清改了什么、为什么改

## 约定

仓库根目录 `AGENTS.md` 为准：

- 歌词分组、音调、流光律动等稳定功能，改前先问
- 不新加状态管理库
- 封面取色走 Rust k-means
- 不手改 `lib/native/rust/` 和 `rust/src/frb_generated.rs`

## 非代码

文档、错字、FAQ、翻译、Star 都欢迎。

## 发版（维护者）

GitHub 发 Release 后，workflow 会同步更新日志、检查更新信息和文档站。以 **GitHub** 为准；[Gitee](https://gitee.com/qingyueyin/Pure-music) 是镜像，可能滞后。
