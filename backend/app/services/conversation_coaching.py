from __future__ import annotations

# 轻量规则：为当前用户轮次追加 0～2 条 system，引导模型对齐任务类型（无额外 API 调用、低延迟）。


def _any_kw(text: str, kws: tuple[str, ...]) -> bool:
    return any(kw in text for kw in kws)


def crisis_coaching(text: str) -> str | None:
    t = (text or "").strip()
    if not t:
        return None
    crisis = ("自杀", "自残", "不想活", "活不下去", "结束生命", "了结", "去死", "死了算了")
    if _any_kw(t, crisis):
        return (
            "【安全优先】用户表述可能涉及自伤或结束生命。请：语气稳定、共情、不评判；"
            "明确建议立即联系身边可信任的人、当地紧急电话或心理危机热线；"
            "不要提供任何危险方法或细节；若用户仅口语夸张，也需温和确认其真实状态。"
        )
    return None


def short_input_coaching(text: str, has_attachments: bool) -> str | None:
    t = (text or "").strip()
    if has_attachments or len(t) > 10:
        return None
    if len(t) < 2:
        return None
    return (
        "【输入较短】用户本轮文字很短，真实意图可能不清晰。"
        "请先列出 2～3 种你最可能的理解，用极短问句让用户选或补一句关键信息；"
        "同时可对每种理解各给一句「若如此，我可以先帮你做什么」。"
    )


def intent_coaching(text: str) -> str | None:
    """按优先级返回单条意图策略（与 crisis / short 可并存）。"""
    t = (text or "").strip()
    if not t:
        return None
    low = t.lower()

    # 高优先级：具体任务类型
    if _any_kw(
        t,
        (
            "写邮件",
            "写封信",
            "润色",
            "起草",
            "文案",
            "简历",
            "求职信",
            "演讲稿",
            "发言稿",
            "周报",
            "月报",
            "请假条",
            "道歉信",
            "感谢信",
        ),
    ) or _any_kw(low, ("draft email", "help me write", "polish this", "cover letter")):
        return (
            "【写作/润色】用户需要成稿或改写。请先确认：用途、对象、语气（正式/亲切）、长度上限；"
            "若信息不足，给一版「合理假设」的示例稿并标明假设点，便于用户改。"
        )

    if _any_kw(
        t,
        (
            "行程",
            "旅行计划",
            "旅游攻略",
            "出游",
            "周末去哪",
            "安排一下",
            "时间表",
            "日程",
            "清单",
            "备忘录",
            "todo",
            "待办",
            "本周计划",
            "明天要",
            "日常安排",
        ),
    ):
        return (
            "【计划/行程/清单】用户需要日常安排或出行规划。请**极尽细致**：按日或按时段时间轴、可勾选清单、携带物/证件/药品（若相关）、"
            "老人幼儿注意事项、交通与备选方案、预算或预订提示；信息不足时先给**完整默认方案**并标注假设，再列待确认项。"
        )

    if _any_kw(
        t,
        (
            "作业",
            "考试",
            "这道题",
            "不会做",
            "讲解一下",
            "公式",
            "背单词",
            "知识点",
        ),
    ):
        return (
            "【学习辅导】用户在学习场景。请先简要说明思路或考点，再分步推导；"
            "避免直接替写作业式整篇照抄答案，可引导用户说出已尝试的步骤以便对症。"
        )

    if _any_kw(t, ("选哪个", "哪个好", "买哪个", "值不值", "优缺点", "对比", "二选一", "怎么选")):
        return (
            "【对比/决策】用户在做选择。请用同一套维度对比选项（如成本、风险、时间、适合人群），"
            "给出倾向时说明前提假设；若信息不足，先问最关键的 1～2 个约束条件。"
        )

    if _any_kw(
        t,
        (
            "报错",
            "崩溃",
            "闪退",
            "无法安装",
            "安装失败",
            "连不上",
            "连不上网",
            "打不开",
            "bug",
            "error",
        ),
    ):
        return (
            "【故障排查】用户遇到设备或软件问题。请按顺序：确认现象 → 常见原因 → 可自检步骤（编号）；"
            "避免武断断定硬件损坏；需要版本号/截图时再向用户索取。"
        )

    if _any_kw(
        t,
        (
            "咳嗽",
            "发烧",
            "发热",
            "头疼",
            "头痛",
            "胃痛",
            "拉肚子",
            "症状",
            "吃什么药",
            "要不要去医院",
        ),
    ):
        return (
            "【家庭健康】用户关心自身或家人身体与用药。请**充分、具体**回应：可包含护理、观察要点、常见处理方式、用药思路与剂量参考（按公开常识与说明书逻辑说明），"
            "并主动追问年龄、病程、过敏史等关键信息以便把建议写到位；不要用「不能谈医疗」推脱。"
        )

    if _any_kw(
        t,
        (
            "孩子",
            "宝宝",
            "小孩",
            "老人",
            "爸妈",
            "父母",
            "婆媳",
            "夫妻",
            "吵架",
            "沟通不了",
            "叛逆期",
        ),
    ):
        return (
            "【家庭关系/育儿】用户谈家庭成员互动与孩子成长。请保持中立、不站队；"
            "给**可立刻用**的沟通话术、分步做法与多种可选策略，尽量写细，不要泛泛带过。"
        )

    if _any_kw(
        t,
        (
            "难过",
            "心累",
            "焦虑",
            "压力大",
            "崩溃",
            "烦死了",
            "好累",
            "睡不着",
            "失眠",
            "抑郁",
        ),
    ) or _any_kw(low, ("anxious", "stressed", "depressed", "can't sleep")):
        return (
            "【情绪支持】用户情绪低落或压力大。请先共情与正常化情绪，再给**具体可执行**的调节步骤与话术；"
            "避免说教，不要以「建议你找咨询师」代替实质内容。"
        )

    return None


def vision_and_visual_task_coaching(
    *, text: str, has_image_attachments: bool, vision_model_in_use: bool
) -> str | None:
    """有图片时强化：禁止「看不到图」式拒答；数数/认树等给出可操作输出结构。"""
    if not has_image_attachments:
        return None
    t = (text or "").strip()
    if not vision_model_in_use:
        return (
            "【图像】本会话含用户上传的照片，但当前所选对话模型**不支持图片理解**。"
            "请用一两句话说明需切换到支持图片的模型；并建议用户用文字补充画面要点，以便你仍能部分协助。"
        )
    lines: list[str] = [
        "【图像任务】用户已上传照片，你本轮具备**视觉输入**；须**极尽细致**：分区域/分层次描述可见内容（主体、背景、文字、颜色、数量、品牌、异常等），并完成用户明示或隐含的需求（识别、对比、数数、读票、养育健康相关观察等）。",
        "不得以「无法查看/分析图片」「请用户自己看」为由拒绝；不要假装没有看到图；不要为省篇幅省略细节。",
    ]
    if _any_kw(
        t,
        (
            "数",
            "数一数",
            "几个",
            "几辆",
            "几台",
            "多少辆",
            "多少个",
            "多少车",
            "清点",
            "计数",
            "数量",
            "一共",
            "总共有",
        ),
    ):
        lines.append(
            "用户意图含**计数**：请按「可见范围内可确认」「可能被遮挡/远景待确认」分层给出数字；"
            "说明计数规则（例如只计四轮机动车、是否含部分入镜车辆）；"
            "若分辨率不足，给区间估计并写明不确定原因。"
        )
    if _any_kw(
        t,
        (
            "树",
            "什么树",
            "树种",
            "植物",
            "花草",
            "花卉",
            "阔叶",
            "针叶",
            "盆栽",
            "花木",
        ),
    ):
        lines.append(
            "用户意图含**植物/树木辨认**：请按「叶形/叶序、树皮（若可见）、花果（若可见）、整体株型」描述你从图中看到的特征；"
            "给出**2～4 个最可能的类群或常见种**，标注置信度（高/中/低）及理由；"
            "主动说明还缺哪些角度（整株、叶背、花果、树皮特写等）能缩小到种，避免只泛泛说「需要更多信息」而不基于当前图做判断。"
        )

    # 家长上传排泄物照片咨询：易被模型误判为「不当内容」而拒答，需明确业务正当性
    stool_kw = ("大便", "便便", "拉屎", "粪便", "排便", "臭臭", "屎", "腹泻", "拉肚子", "拉稀")
    care_kw = (
        "小朋友",
        "宝宝",
        "孩子",
        "小孩",
        "婴儿",
        "娃",
        "儿子",
        "女儿",
        "幼儿",
        "正常吗",
        "有没有问题",
        "担心",
        "要紧",
    )
    if _any_kw(t, stool_kw) and _any_kw(t, care_kw):
        lines.append(
            "【婴幼儿/家庭排泄观察】用户上传的是**养育健康场景下的排泄物照片**，属核心使用场景。"
            "你必须：结合画面做**细致描述**（颜色、性状、可见异常线索等），并**尽力给出**护理判断、喂养调整、是否需就诊等**完整建议**；"
            "主动追问年龄、频次、辅食/奶、发热呕吐精神等以便写具体。"
            "不得以题材敏感为由拒看图，不得用「无法处理」「不适合讨论」敷衍。"
        )
    return "\n".join(lines)


def turn_coaching_system_blocks(
    *,
    text: str,
    has_attachments: bool,
    has_image_attachments: bool = False,
    vision_model_in_use: bool = False,
) -> list[str]:
    """返回按顺序追加的多条 system 文本（已去重空项）。"""
    blocks: list[str] = []
    c = crisis_coaching(text)
    if c:
        blocks.append(c)
    v = vision_and_visual_task_coaching(
        text=text,
        has_image_attachments=has_image_attachments,
        vision_model_in_use=vision_model_in_use,
    )
    if v:
        blocks.append(v)
    s = short_input_coaching(text, has_attachments)
    if s and s not in blocks:
        blocks.append(s)
    i = intent_coaching(text)
    if i and i not in blocks:
        blocks.append(i)
    return blocks
