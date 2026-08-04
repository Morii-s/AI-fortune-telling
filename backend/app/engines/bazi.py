"""
八字排盘引擎
基于 lunar-python 实现四柱八字、十神、五行、纳音分析
"""
from datetime import datetime
from lunar_python import Solar

# 天干五行
GAN_WUXING = {"甲":"木","乙":"木","丙":"火","丁":"火","戊":"土","己":"土","庚":"金","辛":"金","壬":"水","癸":"水"}
# 地支五行
ZHI_WUXING = {"子":"水","丑":"土","寅":"木","卯":"木","辰":"土","巳":"火","午":"火","未":"土","申":"金","酉":"金","戌":"土","亥":"水"}

GAN_LIST = ["甲","乙","丙","丁","戊","己","庚","辛","壬","癸"]

TEN_GOD_MAP = [
    ["比肩","劫财","食神","伤官","偏财","正财","七杀","正官","偏印","正印"],
    ["劫财","比肩","伤官","食神","正财","偏财","正官","七杀","正印","偏印"],
    ["偏印","正印","比肩","劫财","食神","伤官","偏财","正财","七杀","正官"],
    ["正印","偏印","劫财","比肩","伤官","食神","正财","偏财","正官","七杀"],
    ["七杀","正官","偏印","正印","比肩","劫财","食神","伤官","偏财","正财"],
    ["正官","七杀","正印","偏印","劫财","比肩","伤官","食神","正财","偏财"],
    ["偏财","正财","七杀","正官","偏印","正印","比肩","劫财","食神","伤官"],
    ["正财","偏财","正官","七杀","正印","偏印","劫财","比肩","伤官","食神"],
    ["食神","伤官","偏财","正财","七杀","正官","偏印","正印","比肩","劫财"],
    ["伤官","食神","正财","偏财","正官","七杀","正印","偏印","劫财","比肩"],
]


def _gan_index(g):
    return GAN_LIST.index(g) if g in GAN_LIST else 0


def get_bazi(birth_year, birth_month, birth_day, birth_hour=0, gender="male"):
    solar = Solar.fromYmdHms(birth_year, birth_month, birth_day, birth_hour, 0, 0)
    lunar = solar.getLunar()
    ec = lunar.getEightChar()

    yg, yz = ec.getYearGan(), ec.getYearZhi()
    mg, mz = ec.getMonthGan(), ec.getMonthZhi()
    dg, dz = ec.getDayGan(), ec.getDayZhi()
    tg, tz = ec.getTimeGan(), ec.getTimeZhi()

    dm = ec.getDayGan()
    dm_wx = GAN_WUXING.get(dm, "")

    # 十神：优先用 lunar-python，回退手动计算
    ten_gods = {}
    try:
        ten_gods = {"year": ec.getYearShiShenGan(), "month": ec.getMonthShiShenGan(),
                     "day": "日主", "time": ec.getTimeShiShenGan()}
    except Exception:
        ri = _gan_index(dm)
        ten_gods = {"year": TEN_GOD_MAP[ri][_gan_index(yg)], "month": TEN_GOD_MAP[ri][_gan_index(mg)],
                     "day": "日主", "time": TEN_GOD_MAP[ri][_gan_index(tg)]}

    # 纳音
    nayin = {}
    try:
        nayin = {"year": ec.getYearNaYin(), "month": ec.getMonthNaYin(), "day": ec.getDayNaYin(), "time": ec.getTimeNaYin()}
    except Exception:
        nayin = {"year":"","month":"","day":"","time":""}

    # 藏干
    cang = {}
    try:
        cang = {"year": ec.getYearHideGan(), "month": ec.getMonthHideGan(), "day": ec.getDayHideGan(), "time": ec.getTimeHideGan()}
    except Exception:
        cang = {"year":"","month":"","day":"","time":""}

    today = Solar.fromYmdHms(datetime.now().year, datetime.now().month, datetime.now().day, 0, 0, 0)
    today_gz = today.getLunar().getEightChar().getDay()

    return {
        "year": f"{yg}{yz}", "month": f"{mg}{mz}", "day": f"{dg}{dz}", "time": f"{tg}{tz}",
        "year_gan": yg, "year_zhi": yz, "month_gan": mg, "month_zhi": mz,
        "day_gan": dg, "day_zhi": dz, "time_gan": tg, "time_zhi": tz,
        "day_master": dm, "day_master_wuxing": dm_wx,
        "ten_gods": ten_gods,
        "wuxing": {
            "year": GAN_WUXING.get(yg,"") + ZHI_WUXING.get(yz,"") or GAN_WUXING.get(yg,"") + ZHI_WUXING.get(yz,""),
            "month": GAN_WUXING.get(mg,"") + ZHI_WUXING.get(mz,""),
            "day": GAN_WUXING.get(dg,"") + ZHI_WUXING.get(dz,""),
            "time": GAN_WUXING.get(tg,"") + ZHI_WUXING.get(tz,""),
        },
        "nayin": nayin,
        "cang_gan": cang,
        "shengxiao": lunar.getYearShengXiao(),
        "today_ganzhi": today_gz,
    }
