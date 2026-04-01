## 阶段 8：联调修复结果（MVP）

### 已跑通的关键链路（模拟器联调通过）
- 管理后台登录：`/admin/login`
- 管理员创建账号 → iOS App 登录成功
- 会话：新建会话、发送消息、多轮对话、复制回复
- 模型切换：ChatGPT / DeepSeek
- 联网搜索开关：默认关闭；未授权账号在前端置灰（服务端强制门控）
- 附件：上传（单次 1 个、<=10MB、单会话<=5 个）、附件列表、删除、基于附件文本问答
- 历史：会话列表、进入继续聊、删除会话
- 权限：管理员可禁用账号（服务端强校验）
- 安全：模型 API Key 仅后端环境变量（客户端不包含 Key）

### 本次联调修复点
- **Docker CLI 缺失/credential helper 缺失**：已通过软链到 `/usr/local/bin` 解决（本机开发）
- **后端启动失败（bcrypt/passlib）**：锁定 `bcrypt==3.2.2` 修复 passlib 兼容问题
- **iOS pods 卡住（GitHub 依赖超时）**：移除 `file_picker`，改用 `file_selector`，避免 pods 拉取 GitHub 源
- **Python 3.9 兼容问题**：将 `| None` 注解改为 `Optional[...]`，确保本机 Python 3.9 正常运行

### 已知限制（第一版明确边界）
- DeepSeek 第一版不支持图片附件问答：会返回错误提示用户切换到 ChatGPT
- 联网搜索第一版仅在 ChatGPT 路线上生效；DeepSeek 强制关闭

