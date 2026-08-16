"""
融合解读引擎
将八字、黄历、星盘数据交叉分析，优先使用 DeepSeek AI 生成自然语言运势解读
AI 调用失败时自动回退为模板生成
"""
import random
from typing import Optional
from app.engines.bazi import get_bazi, _gan_index
from app.engines.huangli import get_today_huangli
from app.engines.astrology import get_astrology


# 五行 ↔ 星座元素 映射
WUXING_ELEMENT_MAP = {
    "木": "风象",
    "火": "火象",
    "土": "土象",
    "金": None,
    "水": "水象",
}

# 十神 ↔ 行星 映射
TEN_GOD_PLANET_MAP = {
    "正官": "土星", "偏官": "冥王星", "七杀": "冥王星",
    "正印": "木星", "偏印": "天王星", "枭神": "天王星",
    "正财": "金星", "偏财": "金星(逆行)",
    "食神": "月亮", "伤官": "水星",
    "比肩": "太阳", "劫财": "火星",
}

# 星座元素 ↔ 当前行运 模板
ELEMENT_DAILY_TEMPLATES = {
    "火象": {
        "good": ["你的火象能量今日格外旺盛，行动力和热情高涨", "白羊/狮子/射手今日气场强大，适合主动出击"],
        "neutral": ["火象能量平稳，适合保持节奏", "保持你的热情，但不必急于求成"],
        "bad": ["火象能量偏弱，注意控制情绪冲动", "今天火象人容易急躁，三思而后行"],
    },
    "土象": {
        "good": ["土象能量稳健，务实的态度会带来回报", "金牛/处女/摩羯今日财运和事业运都不错"],
        "neutral": ["土象能量如常，适合踏实做事", "按部就班，步步为营"],
        "bad": ["土象偏滞，注意灵活变通", "今天可能感到有些沉闷，适当地走出去"],
    },
    "风象": {
        "good": ["风象能量轻盈流动，社交运和创意运旺盛", "双子/天秤/水瓶今日人缘好，适合沟通交流"],
        "neutral": ["风象尚可，适合学习和思考", "保持头脑清醒，多与人交流"],
        "bad": ["风象能量飘散，注意集中注意力", "今天风象人容易分心，重要事情需要专注"],
    },
    "水象": {
        "good": ["水象能量丰沛，直觉和感受力敏锐", "巨蟹/天蝎/双鱼今日直觉特别准"],
        "neutral": ["水象平和，适合关注内心感受", "保持情绪的流动性，不要压抑自己"],
        "bad": ["水象能量过盛，注意情绪波动", "今天水象人容易情绪化，给自己一些独处时间"],
    },
}

LOVE_TEMPLATES = {
    "good": ["桃花运旺盛，单身者有机会遇到缘分", "感情温度升高，适合约会和表白", "已有伴侣者感情升温，适合规划未来"],
    "neutral": ["感情运势平稳，顺其自然即可", "不宜强求，感情需要耐心经营"],
    "bad": ["感情中容易出现误解，多沟通", "桃花偏弱，今天不宜表白"],
}

CAREER_TEMPLATES = {
    "good": ["事业上有贵人相助，适合推进重要项目", "工作效率高，适合处理复杂事务", "今天适合展现领导力，主动承担"],
    "neutral": ["工作平稳，适合处理日常事务", "按计划推进，不必冒进"],
    "bad": ["工作中可能有阻碍，保持耐心", "今天小心口舌是非，谨言慎行"],
}

WEALTH_TEMPLATES = {
    "good": ["正财运旺盛，可能有额外收入", "投资运不错，但也需谨慎", "财运喜人，适合收账和理财"],
    "neutral": ["财运稳定，量入为出", "没有大进大出，宜稳健理财"],
    "bad": ["今天消费欲望强烈，谨防冲动购物", "财运偏弱，不适合投资决策"],
}

HEALTH_TEMPLATES = {
    "good": ["精力充沛，适合运动锻炼", "身体状况良好，保持规律作息"],
    "neutral": ["身体状况平稳，注意饮食均衡", "保持现有节奏，不要过度"],
    "bad": ["可能感到疲劳，注意休息", "关注肠胃/睡眠问题，早睡早起"],
}


def _wuxing_interaction(day_master_wx: str, day_wx: str) -> str:
    """分析日主五行与今日五行的关系"""
    ke_cycle = {"金": "木", "木": "土", "土": "水", "水": "火", "火": "金"}
    sheng_cycle = {"木": "火", "火": "土", "土": "金", "金": "水", "水": "木"}

    if day_wx == day_master_wx:
        return "比和"
    if ke_cycle.get(day_master_wx) == day_wx:
        return "我克"  # 日主克今日五行
    if ke_cycle.get(day_wx) == day_master_wx:
        return "克我"  # 今日五行克日主
    if sheng_cycle.get(day_master_wx) == day_wx:
        return "我生"  # 日主生今日五行
    if sheng_cycle.get(day_wx) == day_master_wx:
        return "生我"  # 今日五行生日主
    return "未知"


def _score_from_interaction(interaction: str) -> int:
    """根据五行互动给出基础分"""
    scores = {"生我": 8, "比和": 7, "我生": 6, "我克": 5, "克我": 4}
    return scores.get(interaction, 5)


def _score_to_100(interaction: str, sun_element: str, day_master_wx: str, day_ganzhi: str) -> int:
    """A deterministic 100-point daily rhythm score with Bazi as its primary weight."""
    base_scores = {"生我": 82, "比和": 74, "我生": 67, "我克": 61, "克我": 54}
    element_adjustment = _element_score_adjust(sun_element, interaction) * 4
    resonance = 3 if WUXING_ELEMENT_MAP.get(day_master_wx) == sun_element else 0
    day_adjustment = sum(ord(char) for char in day_ganzhi) % 7 - 3
    return min(96, max(42, base_scores.get(interaction, 62) + element_adjustment + resonance + day_adjustment))


def _pick(items: list) -> str:
    return random.choice(items) if items else "一切随缘"


def _category_from_score(score: int) -> str:
    if score >= 7:
        return "good"
    elif score >= 5:
        return "neutral"
    return "bad"


def _element_score_adjust(element: str, gan_zhi_relation: str) -> int:
    """根据星座元素进行调整"""
    adjustments = {
        "生我": 1, "比和": 0, "我生": 0, "我克": -1, "克我": -1,
    }
    return adjustments.get(gan_zhi_relation, 0)


def _lucky_color(day_master_wx: str) -> str:
    colors = {"金": "白色、金色", "木": "绿色、青色", "水": "黑色、蓝色", "火": "红色、橙色", "土": "黄色、棕色"}
    return colors.get(day_master_wx, "白色")


def _lucky_number(day_master_wx: str) -> str:
    numbers = {"金": "4, 9", "木": "3, 8", "水": "1, 6", "火": "2, 7", "土": "5, 0"}
    return numbers.get(day_master_wx, "4, 9")


def _lucky_direction(day_master_wx: str) -> str:
    directions = {"金": "西方", "木": "东方", "水": "北方", "火": "南方", "土": "中央"}
    return directions.get(day_master_wx, "西方")


async def generate_fortune(birth_year: int, birth_month: int, birth_day: int,
                           birth_hour: int = 12, gender: str = "male",
                           birth_lat: float = 39.9,
                           health_summary: Optional[dict] = None) -> dict:
    """核心：生成中西合璧的每日运势（AI 优先，模板兜底）"""
    # 1. 八字排盘
    bazi = get_bazi(birth_year, birth_month, birth_day, birth_hour, gender)
    # 2. 今日黄历
    huangli = get_today_huangli()
    # 3. 星盘
    astrology = get_astrology(birth_year, birth_month, birth_day, birth_hour, 0, birth_lat)
    
    # 尝试 AI 生成
    from app.services.ai import generate_ai_fortune
    ai_result = await generate_ai_fortune(bazi, huangli, astrology, health_summary)
    if ai_result is not None:
        return ai_result

    # AI 失败，回退到模板生成
    return _generate_fortune_template(bazi, huangli, astrology)


def _generate_fortune_template(bazi: dict, huangli: dict, astrology: dict) -> dict:
    """模板生成每日运势（AI 失败时的回退方案）
    
    原 generate_fortune 逻辑保留于此。"""
    # 1. 八字排盘（已由调用方传入）
    # 以下代码从原 generate_fortune 的函数体移入

    day_master_wx = bazi.get("day_master_wuxing", "")
    # 黄历返回的日五行可能是天干、地支各一字（如“水水”），
    # 取首字参与五行生克，避免字符串无法匹配导致评分落入默认值。
    day_wx = huangli.get("day_wuxing", "")[:1]
    sun_element = astrology.get("element", "")
    sun_sign = astrology.get("sun_sign", "")

    # 五行生克关系
    wx_relation = _wuxing_interaction(day_master_wx, day_wx) if day_master_wx and day_wx else "比和"
    base_score = _score_from_interaction(wx_relation)

    # 星座元素调整
    elem_adjust = _element_score_adjust(sun_element, wx_relation)
    # 兼容性额外调整
    compat_adjust = 1 if WUXING_ELEMENT_MAP.get(day_master_wx) == sun_element else 0

    rating = min(10, max(1, base_score + elem_adjust + compat_adjust))
    overall_score = _score_to_100(wx_relation, sun_element, day_master_wx, huangli.get("day_ganzhi", ""))
    cat = _category_from_score(rating)

    # 各分项评分
    day_seed = sum(ord(char) for char in huangli.get("day_ganzhi", ""))
    love_score = min(96, max(42, overall_score + ((day_seed + 1) % 7 - 3)))
    career_score = min(96, max(42, overall_score + ((day_seed + 3) % 9 - 3)))
    wealth_score = min(96, max(42, overall_score + ((day_seed + 5) % 9 - 5)))
    health_score = min(96, max(42, overall_score + ((day_seed + 2) % 7 - 3)))

    # 生成解读文案
    # 综合运势
    stars = "⭐" * min(5, rating // 2)
    element_text = _pick(ELEMENT_DAILY_TEMPLATES.get(sun_element, {}).get(cat, [""]))

    overall_text = (
        f"{stars}\n"
        f"今日{huangli['day_ganzhi']}日，日主{bazi['day_master']}（{day_master_wx}）与今日五行「{wx_relation}」。\n"
        f"{element_text}。\n"
        f"太阳星座{sun_sign}（{sun_element}）与您的八字{bazi['day']}日柱相互呼应，\n"
        f"整体节奏{'上扬' if overall_score >= 70 else '平稳' if overall_score >= 58 else '需注意'}。"
    )

    # 爱��
    love_text = _pick(LOVE_TEMPLATES[_category_from_score(love_score / 10)])
    # 事业
    career_text = _pick(CAREER_TEMPLATES[_category_from_score(career_score / 10)])
    # 财运
    wealth_text = _pick(WEALTH_TEMPLATES[_category_from_score(wealth_score / 10)])
    # 健康
    health_text = _pick(HEALTH_TEMPLATES[_category_from_score(health_score / 10)])

    # 幸运提示
    lucky = {
        "color": _lucky_color(day_master_wx),
        "number": _lucky_number(day_master_wx),
        "direction": _lucky_direction(day_master_wx),
    }

    # 建议
    advice_parts = []
    if "克我" in wx_relation:
        advice_parts.append("今天五行克日主，宜低调行事，以守为主。")
    elif "生我" in wx_relation:
        advice_parts.append("今日五行生扶日主，运势顺畅，适合主动出击。")
    if huangli.get("chong_desc"):
        advice_parts.append(f"冲{huangli['chong_desc']}，属{huangli['chong_desc']}的朋友注意。")
    if huangli.get("ji") and len(huangli["ji"]) > 0:
        advice_parts.append(f"今日忌{huangli['ji'][0]}，请合理安排。")

    advice = "；".join(advice_parts) if advice_parts else "顺其自然，保持好心情就是最好的运势。"

    # 给用户可执行的下一步，避免报告只停留在抽象判断。
    guidance = []
    if wx_relation in {"生我", "比和"}:
        guidance.append("把今天最重要的一件事放在上午完成，先行动再等待反馈。")
    else:
        guidance.append("今天适合收拢节奏，给重要决定留出一晚的观察时间。")
    if career_score >= 70:
        guidance.append("事业线适合主动沟通：约一次关键对话，或把卡住的任务拆成第一步。")
    else:
        guidance.append("工作上减少多线程切换，优先完成一个可交付的小结果。")
    if wealth_score >= 70:
        guidance.append("财运有流动空间，但先确认边界和预算，再做任何支出或投资。")
    else:
        guidance.append("财务上采用‘延迟购买’原则，今天不为情绪性消费买单。")
    guidance.append("留出二十分钟不被打扰的时间，让身体和注意力重新归位。")

    return {
        "overall_score": overall_score,
        "overall_text": overall_text,
        "love": {"score": love_score, "text": love_text},
        "career": {"score": career_score, "text": career_text},
        "wealth": {"score": wealth_score, "text": wealth_text},
        "health": {"score": health_score, "text": health_text},
        "lucky": lucky,
        "advice": advice,
        "guidance": guidance,
    }


async def get_full_fortune(birth_year: int, birth_month: int, birth_day: int,
                     birth_hour: int = 12, gender: str = "male",
                     birth_place: str = "北京", birth_lat: float = 39.9,
                     health_summary: Optional[dict] = None) -> dict:
    """获取完整的运势报告（包含所有引擎数据）"""
    bazi = get_bazi(birth_year, birth_month, birth_day, birth_hour, gender)
    huangli = get_today_huangli()
    astrology = get_astrology(birth_year, birth_month, birth_day, birth_hour, 0, birth_lat)
    fortune = await generate_fortune(birth_year, birth_month, birth_day, birth_hour, gender, birth_lat, health_summary)
    analysis = _merge_bazi_analysis(
        fortune.get("analysis"),
        _build_analysis(bazi, huangli, astrology, fortune, health_summary),
    )
    if not _overall_mentions_bazi(fortune.get("overall_text", ""), bazi, huangli):
        fortune["overall_text"] = _bazi_lead(bazi, huangli) + " " + str(fortune.get("overall_text", ""))
    wellbeing_note = _build_wellbeing_note(health_summary)
    if wellbeing_note:
        fortune.setdefault("guidance", []).append(wellbeing_note)

    return {
        "bazi": bazi,
        "huangli": huangli,
        "astrology": astrology,
        "fortune": fortune,
        "analysis": analysis,
        "date": huangli["solar_date"],
        "health_summary_used": health_summary,
}


def _bazi_lead(bazi: dict, huangli: dict) -> str:
    master = bazi.get("day_master", "未知")
    master_wx = bazi.get("day_master_wuxing", "未知")
    day_ganzhi = huangli.get("day_ganzhi", "未知")
    raw_day_wx = huangli.get("day_wuxing") or ""
    day_wx = raw_day_wx[:1] or "未知"
    relation = _wuxing_interaction(master_wx, day_wx) if master_wx != "未知" and raw_day_wx else "比和"
    return f"八字主线：你的日主为{master}（{master_wx}），今日{day_ganzhi}的{day_wx}气与日主形成「{relation}」。"


def _overall_mentions_bazi(text: str, bazi: dict, huangli: dict) -> bool:
    return text.strip().startswith("八字主线：") if text else False


def _merge_bazi_analysis(ai_analysis: Optional[dict], fallback: dict) -> dict:
    """Keep deterministic bazi evidence as the report's primary spine while retaining LLM prose."""
    if not isinstance(ai_analysis, dict):
        return fallback
    merged = dict(ai_analysis)
    ai_bazi = ai_analysis.get("bazi") if isinstance(ai_analysis.get("bazi"), dict) else {}
    base_bazi = fallback["bazi"]
    evidence = list(base_bazi.get("evidence", []))
    for item in ai_bazi.get("evidence", []):
        if item not in evidence:
            evidence.append(item)
    merged["bazi"] = {
        "title": ai_bazi.get("title") or base_bazi["title"],
        "summary": f"{base_bazi['summary']} {ai_bazi.get('summary', '')}".strip(),
        "evidence": evidence,
        "guidance": ai_bazi.get("guidance") or base_bazi["guidance"],
    }
    merged["disclaimer"] = ai_analysis.get("disclaimer") or fallback["disclaimer"]
    for key in ("meihua", "fengshui", "astrology", "wellbeing"):
        if not isinstance(merged.get(key), dict):
            merged[key] = fallback[key]
    merged["actionable"] = fallback["actionable"]
    return merged


def _build_analysis(bazi: dict, huangli: dict, astrology: dict, fortune: dict, health_summary: Optional[dict] = None) -> dict:
    """Build transparent, culture-oriented reasoning sections for the detail report."""
    master = bazi.get("day_master", "")
    master_wx = bazi.get("day_master_wuxing", "")
    day_wx = (huangli.get("day_wuxing") or "")[:1]
    relation = _wuxing_interaction(master_wx, day_wx) if master_wx and day_wx else "比和"
    yi = "、".join((huangli.get("yi") or [])[:4]) or "未提供"
    ji = "、".join((huangli.get("ji") or [])[:4]) or "未提供"
    auspicious_hours = huangli.get("auspicious_hours") or []
    hour_text = "、".join(item.get("time", "") for item in auspicious_hours[:3]) or "黄历未提供吉时"
    sign = astrology.get("sun_sign", "未知")
    sign_element = astrology.get("element", "未知")
    sign_action = {
        "火象": "把关键沟通或启动动作放在精力更集中的时段，避免一时冲动承诺。",
        "土象": "优先处理可落地的事务与预算，按既定节奏推进会更舒适。",
        "风象": "适合安排沟通、学习和信息整理，重要信息先确认再回应。",
        "水象": "给情绪和关系沟通留出余地，重要回复可以先停顿片刻。",
    }.get(sign_element, "按自己的节奏完成一件可落地的小事。")
    meihua_number = (sum(ord(char) for char in str(huangli.get("solar_date", ""))) + bazi.get("birth_hour", 0)) % 64 + 1
    health = health_summary or {}
    return {
        "disclaimer": "以下内容将传统命理、梅花易数、风水与占星作为文化娱乐和自我反思工具，不构成事实预测、医疗、财务或人生决策建议。",
        "bazi": {
            "title": "八字与五行",
            "summary": f"你的日主为{master}（{master_wx}），今日五行取{day_wx or '未知'}，与日主形成「{relation}」关系。",
            "evidence": [
                f"四柱为 {bazi.get('year')} / {bazi.get('month')} / {bazi.get('day')} / {bazi.get('time')}。",
                f"今日干支为 {huangli.get('day_ganzhi', '未知')}；日主与今日五行的推演关系为「{relation}」。",
                f"日主五行对应的幸运色为 {fortune.get('lucky', {}).get('color', '未提供')}，作为穿搭或桌面小物的轻量提示。",
            ],
            "guidance": "把这层解读当作节奏提醒：关系偏顺时优先推进一件关键事；关系偏紧时为决定留出复核时间。",
        },
        "meihua": {
            "title": "梅花易数·今日取象",
            "summary": f"以日期与出生时辰起数，得到第 {meihua_number} 象。它不用于断言结果，而用于观察「时机、行动与反馈」的关系。",
            "evidence": [
                f"取数依据：今日日期 {huangli.get('solar_date', '未知')} 与出生时辰 {bazi.get('birth_hour', '未知')}。",
                "取象时看重当下环境与人的选择，因此同一象不等于同一结论。",
                "适合把犹豫的问题拆成一个小行动，再用实际反馈校正判断。",
            ],
            "guidance": "今天先完成一个小而明确的动作：发出一条关键消息、整理一个待办，或为明天留出准备时间。",
        },
        "fengshui": {
            "title": "黄历与空间提醒",
            "summary": f"黄历提示：宜 {yi}；忌 {ji}。可将其转译为整理环境与安排事务的灵感。",
            "evidence": [
                f"冲煞信息：{huangli.get('chong_sha') or '未提供'}。",
                f"喜神/福神/财神方位：{huangli.get('xi_shen') or '未提供'}、{huangli.get('fu_shen') or '未提供'}、{huangli.get('cai_shen') or '未提供'}。",
                f"彭祖百忌：{huangli.get('pengzu') or '未提供'}。",
            ],
            "guidance": "让工作台保持一处清爽、光线充足；重要沟通前先清理干扰源。方位仅作文化性布置灵感。",
        },
        "astrology": {
            "title": "星座与星盘视角",
            "summary": f"太阳星座为 {astrology.get('sun_sign', '未知')}（{astrology.get('element', '未知')}），月亮为 {astrology.get('moon_sign') or '未知'}，上升为 {astrology.get('rising_sign') or '未知'}。",
            "evidence": [
                f"守护星：{astrology.get('ruling_planet') or '未提供'}；性质：{astrology.get('quality') or '未提供'}。",
                "太阳可作为行动风格的参考，月亮可作为情绪觉察的提示，上升可作为外在沟通方式的观察框架。",
                f"中西融合点：以{master_wx or '个人'}的五行节奏，对照{astrology.get('element', '未知')}元素的行为倾向，寻找更舒适的行动方式。",
            ],
            "guidance": "沟通前先说清目标和边界；情绪起伏时，先暂停十分钟再回复重要信息。",
        },
        "wellbeing": _build_wellbeing_analysis(health),
        "actionable": {
            "title": "今日可执行提示",
            "items": [
                {"label": "适合穿", "value": fortune.get("lucky", {}).get("color", "未提供"), "icon": "tshirt.fill", "reason": f"以你的{master}日主（{master_wx}）推导；{sign}（{sign_element}）的表达风格可用这组颜色作轻量呼应。"},
                {"label": "吉时", "value": hour_text, "icon": "clock.fill", "reason": f"仅展示当天黄历标记为吉的时段；适合把{sign_element}的{sign}行动风格放在此时发挥，不做结果保证。"},
                {"label": "今天优先", "value": sign_action, "icon": "checkmark.seal.fill", "reason": f"结合{master}日主与今日{huangli.get('day_ganzhi', '干支')}的「{relation}」关系，并参考{sign}的{sign_element}元素倾向。"},
                {"label": "少做", "value": ji, "icon": "exclamationmark.triangle.fill", "reason": "根据今日黄历忌项给重要安排留出复核和缓冲。"},
                {"label": "有利方位", "value": fortune.get("lucky", {}).get("direction", "未提供"), "icon": "location.north.fill", "reason": f"以{master_wx}日主对应方位为主，再用{sign_element}元素作为工作与沟通氛围的参考；仅作空间布置灵感。"},
            ],
        },
    }


def _build_wellbeing_note(health_summary: Optional[dict]) -> Optional[str]:
    """将可选的设备汇总转为温和的生活方式提示，不作健康评估或诊断。"""
    if not health_summary:
        return None
    sleep_hours = health_summary.get("sleep_hours")
    steps = health_summary.get("steps")
    workout_minutes = health_summary.get("workout_minutes")
    if sleep_hours is not None and sleep_hours < 6:
        return "昨夜休息时间偏少，今天给重要任务留出缓冲，并尽量提前结束屏幕时间。"
    if steps is not None and steps < 3000 and (workout_minutes is None or workout_minutes < 15):
        return "今天的活动量还不多；如果状态允许，安排一次轻松步行或舒展，让节奏慢慢启动。"
    if workout_minutes is not None and workout_minutes >= 30:
        return "你今天已经完成了一段活动，接下来把注意力放在补水、进食和恢复节奏上。"
    return "根据你授权的今日活动摘要，保持适度活动与规律休息；如有不适，请咨询专业人士。"


def _build_wellbeing_analysis(health: dict) -> dict:
    """Build a separate health-informed lifestyle section, without medical claims or raw metrics."""
    if not health:
        return {
            "title": "今日节奏建议",
            "summary": "尚未同步今日健康摘要。可先按八字与黄历给出的节奏安排一件关键事，并在午后留出短暂休息。",
            "evidence": ["本节只在用户授权后使用设备生成的当日汇总，不读取或展示原始健康记录。"],
            "guidance": "今天先完成一件最重要的事，再安排十到二十分钟走动或放松；身体持续不适时请咨询专业人士。",
        }

    sleep_hours = health.get("sleep_hours")
    steps = health.get("steps")
    workout_minutes = health.get("workout_minutes")
    recovery_markers = [health.get("resting_heart_rate"), health.get("heart_rate_variability")]
    has_recovery = any(value is not None for value in recovery_markers)

    if sleep_hours is not None and sleep_hours < 6:
        summary = "睡眠汇总提示今天更适合采用留白较多的节奏，把高专注任务放在精神较稳的时段。"
        guidance = "把关键决定延后复核一次；午后安排十分钟离开屏幕的休息，今晚尽量提前结束高刺激活动。"
    elif steps is not None and steps < 3000 and (workout_minutes is None or workout_minutes < 15):
        summary = "活动汇总显示今天的身体节奏尚未完全启动，适合用低门槛的走动或舒展来进入状态。"
        guidance = "在两个工作段之间安排一次轻松步行或拉伸，不追求强度；完成后再回到需要沟通或专注的任务。"
    elif workout_minutes is not None and workout_minutes >= 30:
        summary = "今天已有一段明确活动，接下来的重点可以从消耗转向补水、进食与恢复节奏。"
        guidance = "把需要冲刺的任务控制在一个时间块内，之后留出安静收尾；晚间减少额外高强度安排。"
    else:
        summary = "已同步今日生活节奏摘要，可将它作为安排专注、活动与休息顺序的参考。"
        guidance = "上午推进一件重点任务，午后安排短暂走动；晚间为明天预留一个不被打扰的收尾时段。"

    evidence = [
        "建议由你授权的当日活动、睡眠与恢复汇总生成，仅用于日常节奏参考。",
        "它与八字、黄历的时间安排提示并列使用，不将传统文化解释为健康结论。",
    ]
    if has_recovery:
        evidence.append("恢复相关汇总已纳入建议，用于帮助你在推动事务与留出缓冲之间选择更平衡的安排。")
    return {"title": "今日节奏建议", "summary": summary, "evidence": evidence, "guidance": guidance}
