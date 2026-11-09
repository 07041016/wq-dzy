# 栖舍 Qishe · 智能宿舍联动实验室

> 《鸿蒙高级应用开发工程师认证》期末大作业 · 主题三「联动实验室」
> 面向智能宿舍的「当……就……」自动化规则编排 App，用 Mock 环境代替真实传感器与执行器。
>
> - 仓库：<https://github.com/07041016/wq-dzy>
> - 作者：马瑶函（20230313211）· 独立完成
> - 包名：`com.example.myhdzy`（调试签名 Profile 绑定，故未改）

## 一、这个应用做什么

宿舍里最麻烦的不是开灯关灯，而是"什么情况下该自动做什么"这条规矩。栖舍把这条规矩从人的记忆里搬到可编辑的规则里：

- **环境模拟台**：温度、湿度、光照、噪声四路滑块，代替真实传感器；
- **规则引擎**：每条规则由 1~2 个条件 + 1~3 个设备动作组成，按优先级求值、裁决、留痕；
- **冲突消解**：同一台设备的同一个属性只允许一条规则生效，被挤掉的规则写进日志的「冲突」；
- **执行日志**：按"顺序 1、顺序 2……"记录触发条件、设备变化与冲突，可翻页、可清空；
- **场景演练**：午休 / 夜读 / 离舍三组预设，一键把环境与设备拉回设定状态；
- **冷启动恢复**：关掉进程再打开，规则、设备状态、环境值、日志都还在。

## 二、功能清单

| 能力 | 说明 | 代码位置 |
| --- | --- | --- |
| 4 类 5 台设备 | 顶灯 / 床头灯（照明）、空调（温控）、风扇（通风）、窗帘（遮光） | `model/Defaults.ets` |
| 4 路环境可调 | 温度 −10~45 ℃、湿度 0~100 %、光照 0~2000 lx、噪声 0~100 dB | `pages/EnvPanelPage.ets` |
| 6 条规则（3 条双条件） | R-94 夜间自习、R-88 高温通风、R-75 晨起透光、R-60 午休助眠、R-45 闷湿排风（默认停用）、R-30 离舍断电 | `model/Defaults.ets` |
| 规则增删改查 | 名称、优先级 1~99、冷却时间、条件组、动作组 | `pages/RuleEditPage.ets` |
| 规则引擎 | 过滤 → 求值 → 排序 → 冲突消解 → 冷却判定 → 生成 seq | `engine/` |
| 冲突处理 | targetKey 占用 + priority 降序 + createdSeq 升序 | `engine/ConflictResolver.ets` |
| 执行日志 | RDB 一张表，ts 倒序索引，上限 500 行 | `store/LogRepository.ets` |
| 持久化 | Preferences 四键（rules / devices / env / scenes）+ RDB 一表 | `store/` |
| 单元测试 | Hypium 9 条：正常 3 / 边界 3 / 异常 3 | `entry/src/ohosTest/ets/test/RuleEngine.test.ets` |

## 三、开发环境

| 项 | 版本 |
| --- | --- |
| DevEco Studio | 6.0.0 Release |
| HarmonyOS SDK | 6.1.1 Release（API 24） |
| 模型 | Stage 模型，ArkTS + ArkUI 声明式 |
| 状态管理 | V1（`@State` / `@Prop` / `@StorageLink` / `@StorageProp`） |
| 测试框架 | Hypium 1.0.25 + Hamock 1.0.0 |
| 运行载体 | Phone 模拟器（API 26 镜像，向下兼容 6.1.1(24)） |

## 四、目录结构

```
entry/src/main/ets/
├── model/            Types（数据模型与量程常量）、Readers（读写与格式化）、
│                     Defaults（种子数据）、Keys（AppStorage 键与事件名）
├── engine/           ConditionEvaluator、ConflictResolver、ConditionTextBuilder、
│                     RuleValidator、RuleEngine
├── store/            Prefs（Preferences 封装）、RuleRepository（规则/设备/环境）、
│                     SceneRepository（场景）、LogRepository（RDB 日志）
├── viewmodel/        Boot（冷启动恢复与落盘）、TickRunner（一次 tick 的执行入口）、
│                     EnvStore（环境 clamp 与防抖）
├── pages/            Index（Tabs 主界面）、EnvPanelPage、RuleListPage、
│                     DevicePage、LogPage、RuleEditPage（路由页）
├── components/       EnvSliderRow、DeviceChip、ChipRow、NumberField
└── common/           Ui（Toast 与路由的统一封装）

docs/
├── 软件需求说明书.md
├── HASHES.txt                    # 源码 SHA-256 指纹清单
└── screenshots/                  # 模拟器实机截图（4 张）
```

## 五、怎么跑起来

1. DevEco Studio 打开本目录，等待 oh-package 同步完成（首次会下载 Hypium）；
2. 签名已配置（`build-profile.json5` 的 `signingConfigs`），若要换账号：
   `File → Project Structure → Project → Signing Configs → 勾选 Automatically generate signature`；
3. 选择 Phone 模拟器或真机，点 Run；
4. 首次启动会写入 6 条种子规则、5 台设备、3 组场景；
5. 拖动「环境模拟台」的温度滑块到 28 ℃ 以上，观察顶灯 / 空调 / 风扇联动，切到「日志」页看"顺序 1、2、3"。

命令行构建与安装：

```bash
hvigorw --mode module -p module=entry@default -p product=default assembleHap --no-daemon
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -a EntryAbility -b com.example.myhdzy
```

> 建议的验收路径：新建规则 → 调整 Mock 环境 → 观察联动与日志 → 碰到冲突后改优先级 → 保存场景 → 从最近任务划掉 → 重新打开确认状态还在。

## 六、跑单元测试

```bash
hvigorw --mode module -p module=entry@default test --no-daemon
```

或在 DevEco 中右键 `entry/src/ohosTest/ets/test/RuleEngine.test.ets` → Run。

9 条用例覆盖：

1. 正常：三条规则命中且按优先级排序
2. 正常：目标值与当前值相同 → 幂等跳过
3. 正常：两条规则争同一 targetKey → 记 1 条冲突
4. 边界：温度恰好等于阈值 28.0 → 命中
5. 边界：温度 27.99 → 不命中，返回空计划
6. 边界：冷却窗口内 → 跳过但留痕
7. 异常：环境值 NaN → 不抛异常、不命中
8. 异常：条件组为空 → 校验拒绝
9. 异常：schemaVersion 不符 / JSON 损坏 → 回落 6 条种子规则

## 七、持久化设计

| 存储 | 键 / 表 | 内容 | 为什么放这儿 |
| --- | --- | --- | --- |
| Preferences | `qishe.rules` | 规则（带 schemaVersion 信封） | 体量小、每次整体读写 |
| Preferences | `qishe.devices` | 5 台设备当前状态 | 同上 |
| Preferences | `qishe.env` | 四路环境值 | 同上，写入防抖 400 ms |
| Preferences | `qishe.scenes` | 3 组预设 + 自定义场景 | 同上 |
| RDB | `execution_log` | 执行记录流水 | 持续增长，需要按时间分页与裁剪 |

## 八、运行截图

模拟器实机截图存放在 `docs/screenshots/`：

| 文件 | 内容 |
| --- | --- |
| `01-env-panel.jpeg` | 环境模拟台：四路滑块、设备现状、场景演练、冲突提示 |
| `02-rule-list.jpeg` | 规则列表：6 条规则、优先级徽标、启停开关、冲突提示 |
| `03-device-panel.jpeg` | 设备面板：5 台设备、开关与属性步进 |
| `04-exec-log.jpeg` | 执行日志：顺序 1/2/3、条件文本、冲突与跳过标记 |

## 九、录屏

录屏文件（演示用，按下列分镜录制，时长控制在 2 分钟内）：

| 镜头 | 操作 | 观察点 |
| --- | --- | --- |
| 1 | 冷启动进入环境台 | 骨架屏 → 恢复上次状态（约 40 ms） |
| 2 | 拖动温度滑块到 28 ℃ 以上 | 数值实时变化，300 ms 后顶灯/空调/风扇联动 |
| 3 | 切「规则」页 | 顶部冲突提示条 + 6 条规则按优先级排列 |
| 4 | 切「日志」页 | 顺序 1/2/3、条件带实际值、R-60 标"冲突" |
| 5 | 把 R-60 优先级改到 96 再拖滑块 | 顺序变化、冲突消失 |
| 6 | 点「离舍」场景 | 环境与设备整体回放 |
| 7 | 新建规则：空条件保存 | 被校验拦下并提示 |
| 8 | 从最近任务划掉 → 重新打开 | 规则、设备值、日志全部恢复 |

模拟器录屏命令：

```bash
hdc shell screenrecord --time-limit 120 /data/local/tmp/qishe.mp4
hdc file recv /data/local/tmp/qishe.mp4 ./docs/qishe-demo.mp4
```

## 十、提交历史

按模块分组提交，每条提交对应一个可独立编译的功能点（详见 `docs/软件需求说明书.md` 第 7 节里程碑）。查看方式：

```bash
git log --oneline --author=07041016
```
