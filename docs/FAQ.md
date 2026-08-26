# FAQ / 常见问题

## 为什么有两个安装方式？

- **bundle 安装（推荐给新机器）**：`npx @deepseek-ai/dsh plugin --profile web add https://github.com/xtd1145/dsh-full-access-switch`
  只做一件事——把新会话的默认权限固化为 Full access（danger-full-access + never）。不需要动任何已安装文件。
- **install.ps1（完整体验）**：除了默认权限，还打两个前端 bundle 补丁，给界面加"不再询问"复选框，
  让三处 Full access 确认弹窗全部跳过。会改动 `@deepseek-ai/dsh-client-ui-*` 的已安装文件（有备份，可卸载还原）。

## 我改回默认权限后，补丁还有效吗？

补丁只负责"跳过确认弹窗"，权限本身仍是 DSH 的开关。把设置里默认权限切回 workspace-write 后，
新会话回到需要确认的状态——但勾选了"不再询问"的浏览器里，手动切换到 Full access 也不会再弹确认。

## 升级 DSH 后补丁会失效吗？

会。DSH 升级会覆盖 `node_modules` 里的 bundle，settings 里的 `defaultPreset` 一般保留。
升级后重新运行一次 `install.ps1` 即可（幂等）。

## 为什么 patches.json 里的补丁带版本号？

字符串补丁针对特定版本（`0.1.1-rc.2`）的 bundle 内容。其它版本内容可能不同，
脚本会检测"锚点找不到"并拒绝修改，避免误伤。
