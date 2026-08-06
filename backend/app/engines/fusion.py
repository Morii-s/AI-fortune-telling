"""
融合解读引擎
将八字、黄历、星盘数据交叉分析，优先使用 DeepSeek AI 生成自然语言运势解读
AI 调用失败时自动回退为模板生成
"""
import random
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
                           birth_lat: float = 39.9) -> dict:
    """核心：生成中西合璧的每日运势（AI 优先，模板兜底）"""
    # 1. 八字排盘
    bazi = get_bazi(birth_year, birth_month, birth_day, birth_hour, gender)
    # 2. 今日黄历
    huangli = get_today_huangli()
    # 3. 星盘
    astrology = get_astrology(birth_year, birth_month, birth_day, birth_hour, 0, birth_lat)
    
    # 尝试 AI 生成
    from app.services.ai import generate_ai_fortune
    ai_result = await generate_ai_fortune(bazi, huangli, astrology)
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

    overall_score = min(10, max(1, base_score + elem_adjust + compat_adjust))
    cat = _category_from_score(overall_score)

    # 各分项评分
    love_score = min(10, max(1, overall_score + random.choice([-1, 0, 1])))
    career_score = min(10, max(1, overall_score + random.choice([-1, 0, 1, 2])))
    wealth_score = min(10, max(1, overall_score + random.choice([-2, -1, 0, 1])))
    health_score = min(10, max(1, overall_score + random.choice([-1, 0, 1, 1])))

    # 生成解读文案
    # 综合运势
    stars = "⭐" * min(5, overall_score // 2)
    element_text = _pick(ELEMENT_DAILY_TEMPLATES.get(sun_element, {}).get(cat, [""]))

    overall_text = (
        f"{stars}\n"
        f"今日{huangli['day_ganzhi']}日，日主{bazi['day_master']}（{day_master_wx}）与今日五行「{wx_relation}」。\n"
        f"{element_text}。\n"
        f"太阳星座{sun_sign}（{sun_element}）与您的八字{bazi['day']}日柱相互呼应，\n"
        f"整体运势{'上扬' if overall_score >= 6 else '平稳' if overall_score >= 4 else '需注意'}。"
    )

    # 爱��
    love_text = _pick(LOVE_TEMPLATES[_category_from_score(love_score)])
    # 事业
    career_text = _pick(CAREER_TEMPLATES[_category_from_score(career_score)])
    # 财运
    wealth_text = _pick(WEALTH_TEMPLATES[_category_from_score(wealth_score)])
    # 健康
    health_text = _pick(HEALTH_TEMPLATES[_category_from_score(health_score)])

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
    if career_score >= 7:
        guidance.append("事业线适合主动沟通：约一次关键对话，或把卡住的任务拆成第一步。")
    else:
        guidance.append("工作上减少多线程切换，优先完成一个可交付的小结果。")
    if wealth_score >= 7:
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
                     birth_place: str = "北京", birth_lat: float = 39.9) -> dict:
    """获取完整的运势报告（包含所有引擎数据）"""
    bazi = get_bazi(birth_year, birth_month, birth_day, birth_hour, gender)
    huangli = get_today_huangli()
    astrology = get_astrology(birth_year, birth_month, birth_day, birth_hour, 0, birth_lat)
    fortune = await generate_fortune(birth_year, birth_month, birth_day, birth_hour, gender, birth_lat)

    return {
        "bazi": bazi,
        "huangli": huangli,
        "astrology": astrology,
        "fortune": fortune,
        "date": huangli["solar_date"],
    }
