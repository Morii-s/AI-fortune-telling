# Orbit Health iOS App

个人自用的 Apple Watch / HealthKit 配套 App。Apple Watch 数据由 iPhone 的 HealthKit 统一提供；App 只在用户授权后读取当日汇总值。

## 独立运行

排盘、节律评分、黄历提示和离线兜底报告都在 iPhone 应用内计算，不会连接 Mac、局域网或 Python 后端。配置 DeepSeek 后，应用会从 iPhone 直接请求 AI 生成扩展解读；无网、服务不可用或未配置 Key 时，仍会显示本地报告。

## 今日求签

命轨首页右上角的签筒按钮进入求签页。可以摇晃手机触发抽签，也可以点击“开始摇签”作为辅助入口；签筒停下后从本地完整百签库随机抽取一签，并显示签诗、文化解读和一条今日行动建议。配置 DeepSeek 且联网时，解读会再结合个人出生资料润色；离线时使用本地解签。

将 `OrbitHealth/Info.plist` 中的 `DEEPSEEK_API_KEY` 替换为自己的 Key。这个 Key 会随 App bundle 一起打包，符合当前仅个人使用的前提；不要将包含真实 Key 的构建产物分发给其他人。

## 在 Mac 上运行

1. 安装完整 Xcode，并安装 XcodeGen：`brew install xcodegen`。
2. 在本目录运行 `xcodegen generate`，打开 `OrbitHealth.xcodeproj`。
3. 在 Xcode 的 Signing & Capabilities 中选择你的 Apple ID/team，并添加 **HealthKit** capability。
4. 在 `OrbitHealth/Info.plist` 填入 `DEEPSEEK_API_KEY`，然后连接 iPhone，选择设备后 Run。免费 Apple ID 侧载通常需要约每 7 天重新签名安装。

## HealthKit 范围

首版读取步数、活动能量、睡眠、静息心率、HRV 和锻炼时长。应用不写入 HealthKit，不作医疗诊断；正式使用前应补充隐私政策与删除数据流程。

## 旧 Web 后端

仓库内的 `backend/` 和 `frontend/` 仍可用于 Web 版本开发，但 iOS App 不再依赖它们，也不需要启动 `start.sh`。
