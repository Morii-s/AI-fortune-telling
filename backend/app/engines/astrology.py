"""
星盘引擎
基于天文算法计算星座、行星位置、元素归属
"""
from datetime import datetime
from math import sin, cos, pi, floor

# 黄道十二宫日期范围（近似）
ZODIAC_DATES = [
    ("摩羯座",  (1, 1),   (1, 19)),  ("水瓶座",  (1, 20),  (2, 18)),
    ("双鱼座",  (2, 19),  (3, 20)),  ("白羊座",  (3, 21),  (4, 19)),
    ("金牛座",  (4, 20),  (5, 20)),  ("双子座",  (5, 21),  (6, 21)),
    ("巨蟹座",  (6, 22),  (7, 22)),  ("狮子座",  (7, 23),  (8, 22)),
    ("处女座",  (8, 23),  (9, 22)),  ("天秤座",  (9, 23),  (10, 23)),
    ("天蝎座",  (10, 24), (11, 22)), ("射手座",  (11, 23), (12, 21)),
    ("摩羯座",  (12, 22), (12, 31)),
]

ZODIAC_ELEMENTS = {
    "白羊座": "火象", "狮子座": "火象", "射手座": "火象",
    "金牛座": "土象", "处女座": "土象", "摩羯座": "土象",
    "双子座": "风象", "天秤座": "风象", "水瓶座": "风象",
    "巨蟹座": "水象", "天蝎座": "水象", "双鱼座": "水象",
}

ZODIAC_RULING_PLANETS = {
    "白羊座": "火星", "金牛座": "金星", "双子座": "水星",
    "巨蟹座": "月亮", "狮子座": "太阳", "处女座": "水星",
    "天秤座": "金星", "天蝎座": "冥王星", "射手座": "木星",
    "摩羯座": "土星", "水瓶座": "天王星", "双鱼座": "海王星",
}

ZODIAC_QUALITIES = {
    "白羊座": "开创", "金牛座": "固定", "双子座": "变动",
    "巨蟹座": "开创", "狮子座": "固定", "处女座": "变动",
    "天秤座": "开创", "天蝎座": "固定", "射手座": "变动",
    "摩羯座": "开创", "水瓶座": "固定", "双鱼座": "变动",
}


def get_zodiac_sign(month, day):
    for sign, start, end in ZODIAC_DATES:
        if (month == start[0] and day >= start[1]) or (month == end[0] and day <= end[1]):
            return sign
    return "摩羯座"


def get_zodiac_from_degrees(lon_deg):
    """从黄道经度获取星座"""
    signs = ["白羊座", "金牛座", "双子座", "巨蟹座", "狮子座", "处女座",
             "天秤座", "天蝎座", "射手座", "摩羯座", "水瓶座", "双鱼座"]
    idx = int(lon_deg // 30) % 12
    return signs[idx]


def datetime_to_julian(dt: datetime) -> float:
    """转为儒略日"""
    y, m, d = dt.year, dt.month, dt.day
    h = dt.hour + dt.minute / 60.0
    if m <= 2:
        y -= 1
        m += 12
    a = int(y / 100)
    b = 2 - a + int(a / 4)
    jd = int(365.25 * (y + 4716)) + int(30.6001 * (m + 1)) + d + h / 24.0 + b - 1524.5
    return jd


def calc_sun_position(jd: float, t: float = None):
    """计算太阳黄道经度"""
    if t is None:
        t = (jd - 2451545.0) / 36525.0
    # 太阳平均近点角
    M = 357.5291 + 35999.0503 * t - 0.0001559 * t * t
    M = M % 360
    M_rad = M * pi / 180
    # 太阳中心差
    C = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(M_rad) \
        + (0.019993 - 0.000101 * t) * sin(2 * M_rad) \
        + 0.000289 * sin(3 * M_rad)
    # 太阳真实经度
    L0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
    L0 = L0 % 360
    lon = (L0 + C) % 360
    return lon


def calc_moon_position(jd: float):
    """计算月球近似的黄道经度"""
    t = (jd - 2451545.0) / 36525.0
    # 月球平黄经
    Lp = 218.3165 + 481267.8813 * t
    Lp = Lp % 360
    # 月球平近点角
    Mp = 134.9629 + 477198.8674 * t
    Mp = Mp % 360
    # 夹角距
    D = 297.8502 + 445267.1115 * t
    D = D % 360
    # 太阳平近点角
    Ms = 357.5291 + 35999.0503 * t
    Ms = Ms % 360
    # 改为弧度
    Lp_r = Lp * pi / 180
    Mp_r = Mp * pi / 180
    D_r = D * pi / 180
    Ms_r = Ms * pi / 180
    # 经度改正项
    corr = (2.2656 * sin(2 * D_r - Mp_r - Ms_r) + 1.2740 * sin(Mp_r)
            + 0.6583 * sin(2 * D_r) + 0.2136 * sin(2 * Mp_r)
            - 0.1851 * sin(Ms_r) - 0.1143 * sin(2 * (D_r + Mp_r - Ms_r)))
    lon = (Lp + corr) % 360
    return lon


def calc_rising_sign(birth_dt: datetime, lat: float = 39.9):
    """近似计算上升星座"""
    jd = datetime_to_julian(birth_dt)
    sun_lon = calc_sun_position(jd)
    # 地方恒星时
    t = (jd - 2451545.0) / 36525.0
    gst = 280.46061837 + 360.98564736629 * (jd - 2451545.0)
    lst = (gst + birth_dt.hour * 15) % 360
    asc = (lst - 180) % 360
    # 考虑纬度修正
    asc_adj = asc + 30 * sin(lat * pi / 180)
    asc_adj = asc_adj % 360
    return get_zodiac_from_degrees(asc_adj)


def calc_planet_positions(jd: float):
    """计算各大行星近似黄道经度"""
    t = (jd - 2451545.0) / 36525.0
    planets = {}
    # 太阳
    planets["太阳"] = ("sun", calc_sun_position(jd, t))
    # 月亮
    planets["月亮"] = ("moon", calc_moon_position(jd))
    # 水星
    Ml = 252.2509 + 149472.6746 * t
    lon = Ml % 360
    planets["水星"] = ("mercury", lon)
    # 金星
    Ml = 181.9798 + 58517.8156 * t
    lon = Ml % 360
    planets["金星"] = ("venus", lon)
    # 火星
    Ml = 355.4500 + 19140.2993 * t
    lon = Ml % 360
    planets["火星"] = ("mars", lon)
    # 木星
    Ml = 34.3515 + 3034.9057 * t
    lon = Ml % 360
    planets["木星"] = ("jupiter", lon)
    # 土星
    Ml = 50.0774 + 1222.1138 * t
    lon = Ml % 360
    planets["土星"] = ("saturn", lon)
    return planets


def get_astrology(birth_year: int, birth_month: int, birth_day: int,
                  birth_hour: int = 12, birth_minute: int = 0,
                  birth_lat: float = 39.9) -> dict:
    """计算用户星盘信息"""
    birth_dt = datetime(birth_year, birth_month, birth_day, birth_hour, birth_minute)
    sun_sign = get_zodiac_sign(birth_month, birth_day)

    # 更精确的太阳星座（用天文算法）
    jd = datetime_to_julian(birth_dt)
    sun_lon = calc_sun_position(jd)
    precise_sun_sign = get_zodiac_from_degrees(sun_lon)

    # 月亮星座
    moon_lon = calc_moon_position(jd)
    moon_sign = get_zodiac_from_degrees(moon_lon)

    # 上升星座
    rising_sign = calc_rising_sign(birth_dt, birth_lat)

    # 行星位置
    planets = calc_planet_positions(jd)
    planet_signs = {}
    for pname, (pkey, plon) in planets.items():
        planet_signs[pname] = {
            "sign": get_zodiac_from_degrees(plon),
            "longitude": round(plon, 2),
        }

    return {
        "sun_sign": precise_sun_sign or sun_sign,
        "moon_sign": moon_sign,
        "rising_sign": rising_sign,
        "element": ZODIAC_ELEMENTS.get(precise_sun_sign, ""),
        "quality": ZODIAC_QUALITIES.get(precise_sun_sign, ""),
        "ruling_planet": ZODIAC_RULING_PLANETS.get(precise_sun_sign, ""),
        "planet_signs": planet_signs,
    }
