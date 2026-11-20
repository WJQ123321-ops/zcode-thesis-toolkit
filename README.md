# ZCode 论文开题工具包

适用于 Windows 上的 ZCode Agent。一个 PowerShell 脚本安装五个技能，配置知网 MCP，并准备它所需的 Python 环境和 Chromium 浏览器。首次使用知网时，请用自己的账号或学校入口在浏览器中完成认证。

## 安装

1. 完全退出 ZCode。在 Windows 终端打开 **PowerShell 7.4 或更新版本**。在 PowerShell 里运行 `$PSVersionTable.PSVersion` 可以查看当前版本。
2. 如果还没有 `uv`，运行下面的命令，然后重新打开终端。已经能运行 `uv --version` 的话可以跳过。

   ```powershell
   winget install --id astral-sh.uv -e
   ```

3. 将下面代码整段复制到 PowerShell。可以先在 GitHub 查看 [安装脚本](install.ps1)。脚本从 GitHub 下载固定版本的上游文件，需要能访问 GitHub、Python 包源和 Playwright 的浏览器下载服务。

   ```powershell
   $installer = Join-Path $env:TEMP 'zcode-thesis-toolkit-install.ps1'
   Invoke-WebRequest 'https://raw.githubusercontent.com/WJQ123321-ops/zcode-thesis-toolkit/main/install.ps1' -OutFile $installer -ErrorAction Stop
   pwsh -NoProfile -ExecutionPolicy Bypass -File $installer -Login
   ```

   `Bypass` 只用于这次启动的 PowerShell 进程。装好后会打开知网登录窗口。按页面提示完成认证，再等终端返回。如果暂时只想用写作技能，删掉最后的 `-Login`。日后登录时，运行安装终端输出的 `init --profile default` 完整命令。

4. 重新打开 ZCode，开一个 **ZCode Agent** 对话。进「设置 → 技能」确认下表中的五个英文名称，再进「设置 → MCP 服务器」确认 `cnki` 已启用。

## 怎么用

可以在输入框输入 `/` 找对应技能，也可以在消息里直接点名。先用下面的知网例子试一次，确认能拿到实际题录。

| 技能 | 可以直接发给 ZCode 的话 |
| --- | --- |
| `cnki-search` 知网检索 | 用知网 MCP 查 3 篇关于直播电商食品消费与消费者信任的中文论文，列出题名、作者、年份和来源。无法核实的字段标明待核实。 |
| `using-research-writing` 科研写作助手 | 我在准备一份问卷调查类本科论文开题报告。先帮我梳理研究问题、变量和章节安排。 |
| `writing-humanities` 人文社科写作 | 根据我的研究问题和问卷，修改开题报告的研究方法。把样本来源和分析方法写清楚，保留原有研究设计。 |
| `literature-review` 文献检索与综述 | 根据我提供的文献，把主播信任和产品信任分开归纳，标出每条结论对应的文献，以及哪些只核对了摘要。 |
| `zh-humanizer` 中文润色 | 润色这段开题报告，让中文更自然。保留术语、数据、引用编号和原有结论。 |

知网 MCP 用于检索和核对题录、摘要等信息。需要全文时，按自己的学校或机构权限去知网或期刊官网获取。

文献综述技能附带检索和 PDF 提取脚本。若 ZCode 提示找不到 `python`，让它使用安装结束时显示的 Python 完整路径，并从 `$env:USERPROFILE\.zcode\skills\literature-review` 运行脚本。首次需要运行 PDF 提取脚本时，给这个 Python 环境安装 PyMuPDF：

```powershell
uv pip install --python '这里填安装结束时显示的 Python 完整路径' 'PyMuPDF<2'
```

## 常见问题

- **脚本提示找不到 uv**：先完成第 2 步，重开 PowerShell 后再运行安装命令。
- **已存在同名知网 MCP**：脚本会暂停。可以继续使用已有知网配置，或者在 ZCode 的 MCP 设置里将原有服务改名，再运行安装脚本。
- **技能列表没刷新**：完全退出 ZCode 再打开，确认新对话使用的是 ZCode Agent。遇到已有同名技能时，脚本会保留已有版本。
- **知网登录已过期**：先退出 ZCode，再运行安装结束时给出的登录命令，认证后重开 ZCode。知网浏览器会话保存在本机的 `$env:USERPROFILE\.cnki-mcp`。
- **想停用**：在 ZCode 设置里关闭相应技能或 `cnki` 服务。脚本修改全局 MCP 配置前会在同目录生成 `config.json.before-thesis-*.bak`。

## 来源

- 知网 MCP 和 `cnki-search` 来自 [SepineTam/cnki-mcp](https://github.com/SepineTam/cnki-mcp)，上游许可证为 GPL-3.0。
- 三个科研写作技能来自 [Norman-bury/research-writing-skill](https://github.com/Norman-bury/research-writing-skill)，上游许可证为 MIT。
- 中文润色技能来自 [yzongy/zh-humanizer](https://github.com/yzongy/zh-humanizer)。安装时从作者仓库获取。
- ZCode 官方说明见 [MCP 服务器](https://zcode.z.ai/cn/docs/mcp-services) 和 [技能](https://zcode.z.ai/cn/docs/skill)。

本仓库提供安装脚本和教程。第三方项目的代码和技能文件在安装时从各自的 GitHub 仓库下载。
