> ⚠️ 非官方补丁：本项目是用户级的社区补丁，针对 DeepSeek Harness 的已发布 bundle 做修改，
> 与 DeepSeek 官方无关，不随官方版本升级自动生效（升级后请重新运行 install.ps1）。

# DSH Full Access 一次性开关（不再每次确认）

给 DeepSeek Harness（DSH，v0.1.1-rc.2 的 web profile）加一个**一次性开关**：
打开后，**新工作区 / 新对话不再需要逐个确认 Full access（danger-full-access）**。

## 它做了什么

1. **新会话默认权限**：向 `$DSH_HOME/settings.yaml` 写入
   `permission.defaultPreset: danger-full-access`。DSH 会在每次创建新会话（新工作区、
   新对话）时自动把会话固化为 `danger-full-access + never`，全程零确认。
   （settings 文件有 chokidar 热发布，运行中的服务立即生效，**无需重启**。）

2. **GUI 风险确认门**：给两处前端 bundle 打补丁，新增一个浏览器本地持久化的
   "不再询问"开关（localStorage key `dsh.permission.skipFullAccessConfirmation`）：
   - 设置 → 权限 那一行下方新增复选框 **「不再询问 Full access 确认（记住我的选择）」**；
   - 勾选后，三处 "Enable Full access?" 弹窗全部跳过：
     - 设置页权限行的切换
     - 输入框下方的权限选择器（composer）
     - `/permission` 命令弹窗

## 两种安装方式

| 方式 | 命令 | 效果 |
| --- | --- | --- |
| **bundle 一键安装**（推荐新机器） | `npx @deepseek-ai/dsh plugin --profile web add https://github.com/xtd1145/dsh-full-access-switch` | 新会话默认 Full access，零改动已安装文件 |
| **install.ps1 完整体验** | `powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1` | 默认权限 + GUI"不再询问"开关（见下方补丁说明） |

> bundle 方式只需把本仓库当作一个可安装的 DSH 插件（`dsh.bundle` 清单 + `cordis.patch.yml`），
> 它把 `permission` 行的默认预设固化为 `danger-full-access`。装完重启 harness 即可。

## 安装


```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

脚本会自动定位 DSH 安装位置（优先 `$env:USERPROFILE\.dsh\profiles\node_modules\@deepseek-ai\`，
再找 `npm-cache\_npx\*\node_modules\@deepseek-ai\`），对每个文件：

- 已打过补丁（含 `FULL_ACCESS_SKIP_KEY`）→ 跳过，幂等；
- 未打过 → 先备份为 `<文件名>.bak-<时间戳>`，再应用字符串补丁；
- 找不到目标文件或文件内容与预期不符 → 明确报错，不破坏原文件。

然后**刷新浏览器页面**（F5）即可生效。

> 兼容性：补丁针对 `@deepseek-ai/dsh-client-ui-permission-presets` /
> `@deepseek-ai/dsh-client-ui-conversation` 的 `0.1.1-rc.2` bundle。
> 其它版本脚本会提示"内容不匹配"，不会误改。

## 卸载

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1
```

从最近的 `.bak-*` 备份恢复被补丁的文件；`settings.yaml` 中的
`permission.defaultPreset` 也会被移除（还原为 DSH 默认）。

## 收录情况

- [DSH Market](https://dsh.market/) 收录申请：[issue #67](https://github.com/2BingLing/dsh-market/issues/67)（每日 06:00 自动管道）
- [awesome-dsh-plugin](https://awesome-dsh-plugin.com/) 收录 PR：[#3386](https://github.com/awesome-dsh-plugin/awesome-dsh-plugin/pull/3386)
- [dshbase](https://dshbase.com/) 收录申请：[issue #85](https://github.com/ylwl1997/dshbase/issues/85)

## 手动修改对应关系

| 文件 | 改动 |
| --- | --- |
| `$DSH_HOME/settings.yaml` | 新增 `permission.defaultPreset: danger-full-access` |
| `.../@deepseek-ai/dsh-client-ui-permission-presets/lib/client.js` | 一次性开关 + 三处跳过逻辑 |
| `.../@deepseek-ai/dsh-client-ui-conversation/lib/client.js` | composer 权限选择器跳过确认 |

详细补丁见 `patches/*.diff`。

## 验证

- 新开一个工作区或新对话 → 权限直接是 **Full access**，不再弹确认；
- 设置 → 权限：默认已是 Full access，勾选"不再询问"后手动来回切换也不再弹窗；
- 若想临时改回，把 Settings 里默认权限切回 workspace-write 即可，不影响开关本身。
