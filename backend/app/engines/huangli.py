"""
黄历引擎
基于 lunar-python 实现每日黄历宜忌、冲煞、吉神方位
"""
from datetime import datetime
from lunar_python import Solar


def get_today_huangli(date=None):
    if date is None:
        date = datetime.now()
    solar = Solar.fromYmdHms(date.year, date.month, date.day, 0, 0, 0)
    lunar = solar.getLunar()
    lunar_year = lunar.getYearInChinese()
    lunar_month = lunar.getMonthInChinese()
    lunar_day = lunar.getDayInChinese()
    eight_char = lunar.getEightChar()
    day_ganzhi = eight_char.getDay()
    day_gan = eight_char.getDayGan()
    day_zhi = eight_char.getDayZhi()
    yi, ji = [], []
    try:
        yi = list(lunar.getDayYi()) if lunar.getDayYi() else []
        ji = list(lunar.getDayJi()) if lunar.getDayJi() else []
    except: pass
    chong = ''; chong_desc = ''; chong_sha = ''
    try:
        chong = lunar.getDayChong()
        chong_desc = lunar.getDayChongShengXiao()
        chong_sha = lunar.getDayChongSha()
    except: pass
    xi_shen = fu_shen = cai_shen = ''
    try:
        xi_shen = lunar.getDayXiShen()
        fu_shen = lunar.getDayFuShen()
        cai_shen = lunar.getDayCaiShen()
    except: pass
    pengzu = ''
    try: pengzu = lunar.getDayPengZuGan() + ' ' + lunar.getDayPengZuZhi()
    except: pass
    jianchu = ''
    try: jianchu = lunar.getDayJianChu()
    except: pass
    day_wuxing = ''
    try: day_wuxing = eight_char.getDayWuXing()
    except: pass
    xingzuo = solar.getXingZuo()
    return {
        'lunar_date': f'{lunar_year}年{lunar_month}{lunar_day}',
        'lunar_year': lunar_year, 'lunar_month': lunar_month, 'lunar_day': lunar_day,
        'day_ganzhi': day_ganzhi, 'day_gan': day_gan, 'day_zhi': day_zhi,
        'day_wuxing': day_wuxing,
        'yi': yi, 'ji': ji,
        'chong': chong, 'chong_desc': chong_desc, 'chong_sha': chong_sha,
        'xi_shen': xi_shen, 'fu_shen': fu_shen, 'cai_shen': cai_shen,
        'pengzu': pengzu, 'jianchu': jianchu, 'xingzuo': xingzuo,
        'solar_date': f'{date.year}-{date.month:02d}-{date.day:02d}',
    }
