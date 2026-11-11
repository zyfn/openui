# Agent 核心示例：01–08

本目录是这八组示例的唯一维护源，随 SDK 的 `main` 分支维护。
`AgentExamples.md` 是从这些源码生成的 Agent 阅读版本；CaseLab 只同步副本。
示例数据沿用用户审核过的材料，不代表当前实时价格、库存或营业信息。

Map、MapPoint、SVG使用CaseLab已有的宿主扩展；它们不是SDK默认组件。Agent必须使用实际宿主导出的LibrarySpec。
`test-library-spec.json`是该注册库的测试快照，不是另一套手工维护的协议；测试会核对标准组件签名未漂移。

## 容器的职责

容器定义排列关系和空间分配，不等同于灰色加载骨架。

| 内容关系 | 使用方式 |
| --- | --- |
| 连续阅读、章节、图文顺序 | `Stack(column)`；内容按已分配宽度换行、向下增长 |
| 按内容定宽的小字段、操作 | `Stack(row)`；`wrap`只表示能否换行，不表示等宽 |
| 需要共享宽度的内容单元 | 将 `Card` 直接放在横向容器中；`clear`保留其容器语义和内边距，并非零边距网格 |
| 图片集合、横向浏览 | 使用 `ImageGallery`、卡片组或 `Carousel` 自己的布局能力；不要重复包容器 |
| 单个完整对象 | 可用 `Card` 组合合法内容；不要为满足卡片组至少两项而虚构另一个对象 |

`Card`被额外的普通`Stack`包住后，外层看到的是Stack，伸展关系不能穿透包装。
`Carousel`的合法children由导出的组件契约决定，不把任意Card/Stack塞入它。

## 商品数据边界

标题、店铺、规格、价格、库存、优惠和跳转地址必须来自对应工具返回或可核对的原始资料；不为了凑卡片层级改写商品身份、补卖点或推定属性。原始描述缺失时允许省略，不用推荐理由填充商品描述。
Agent 的选择建议放在商品卡外，并明确为建议。价格展示可以调整位置和字号，但不能改变币种、单位、适用条件或起价/区间的含义。链接文案必须符合目标页面实际用途。
本目录沿用已保存的示例材料。Case05 本地只有整理后的示例记录，尚无原始商品工具响应可逐字段复核，因此保留其名称、店铺、图片、金额和地址，不将它们宣称为已复核的原始商品标题；已移除卡内“商品标题标注……”等推断性说明。消费方必须绑定自己的实际工具结果，不能复制示例中的商品事实作为新查询结果。

## 文字角色与对象表达

复用 SDK 系统字体与既有角色，不写客户端样式覆盖或硬编码字号。当前默认对照为：页面标题 26pt、章节 20pt、对象标题 18pt、正文 16pt、规格/来源 14pt、紧凑图注 12pt；正文 regular，标题 semibold，价格与时间使用数字角色。行距继承 SDK 的角色设置（正文 1.5、章节 1.3、对象标题 1.35、详情 1.45），不是在示例中另设参数。

- 页面/章节用 Markdown 标题；对象名称用 CardHeader 或组件自己的 title。正文介绍使用 TextContent 默认角色；small 留给日期、规格、来源与短补充，不把完整解释普遍压成小字。
- 主标题标识真实对象：景点名、酒店名、可核对商品名/型号。票种、房型、日期与入园时段放在规格区域。正文介绍对象本身；预约、退改提示和 Agent 推荐理由分开，不能替代介绍。
- 商品卡底部使用 `BoldText(number, 金额, 价格口径, text, lg)`，卡内详情入口使用 `Button(primary, normal, small)`；金额不在介绍中重复。币种、每人/每张/每间每晚、合计、含税或起价条件必须准确。
- 统一按钮层级，不强制同名。商品页“查看商品”、酒店页“查看酒店”、公示页“查看官方票价”；查询入口写“查询此路线”。不让公示页、首页或 mock 方案冒充可下单商品。
- 演示数据允许表达完整能力，但需统一标明。Case07 固定 2026/11/21–22、3 位成人、铁路二等座往返、2 间客房 1 晚。交通卡展示自洽时刻与每人价格；酒店展示真实身份与公开介绍，演示用房需求和预算独立标注，不宣称真实房型库存或酒店报价。
- Case08 的同日同条件 mock 比较与原历史灵活日期报价分组；不把跨日期价差归因于直飞/中转。当地时区、跨日日期、中转机场与衔接时间必须算得通。
- 缺失原始商品属性时不补卖点；mock 不是给真实商品编属性的授权。资料出处与 mock 字段边界见 [内容依据](CONTENT-SOURCES.md)。

## 流式编写

1. 根声明先写完整，用具名引用连接主要区域，让容器参数尽早到达。
2. 按阅读顺序展开组件定义。卡片组先声明`items`引用及`layout`，再逐张定义卡片，不把整组大段内联内容放在布局参数前。
   图库先声明图项引用，再紧接着填入对应图片记录，让已知列结构与图片加载分开；已有可信数据就近补入，不机械拖到整篇末尾。
3. 普通文字直接写进`TextContent`；无需把每句话再拆为字符串变量。短叶子可内联。具名文字组件的作用是尽早闭合外层结构，不是禁止内联。
4. 图表/表格结构和大块数据分开；状态、Query及动作按官方契约处理。`@Each`模板捕获局部变量时必须保留在模板作用域内，不能机械外提。
   组件定义按实际阅读顺序展开；例如Form虽然把buttons列为第二个参数，字段仍应先于提交按钮补入。
5. 图片URL必须来自可信材料。卡片结构就绪、文字到达、URL完整、图片下载完成是不同阶段；不要以“整组全部下载完成”作为显示门槛。
6. 缺失内容不能编造；已显示内容不能因后续声明到达而清空。停止、失败、刷新由实际状态驱动。

这些是现有协议下的编写建议，不新增参数，不承诺任意源码顺序都零位移。
布局优先与数据随后填充的依据来自固定官方的`Hoisting & Streaming`提示词规则。

## 八组覆盖

01 场景发现；02 图文实景与地点；03 原理说明与图解；04 风格选择与输入；
05 商品比较；06 非商品决策；07 跨品类旅行规划；08 交通报价。

案例的用途是学习信息组织和组件组合，不按case编号或业务词触发SDK布局。
Case08保留原生细线，采用统一的时间/价格主层级与辅助信息层级；不使用SVG交通卡或定制次日徽标。
业务字段取舍属于消费方/Skill说明，不进入SDK组件实现。

## 校验与同步

`manifest.json`固定这八条的身份和源码摘要。同步时校验摘要、组件契约、未解析引用和孤立声明。
内容与动作的对照检查区分“顺序/引用重构”与明确的布局改动。
通过普通字号的真实流回放检查卡片逐项出现、图片尺寸、前文连续性及操作；仅编译/解析成功不代表视觉通过。
此轮不要求大字号专项验收，也不删除SDK已有的无障碍能力。

Agent消费方同步本目录的生成文档与源码；SDK默认提示词保持通用，不自动塞入全部旅行案例。

<!-- Generated from the .openui sources; do not edit this copy. -->

## Case 01 · 杭州周末 · 场景发现

```openui-lang
root = Stack([cover, moods, choosing, places, closing, followUps], "column", "xl")
cover = Stack([edition, headline, heroImage, opening], "column", "s")
edition = TextContent("HANGZHOU · WEEKEND NOTES", "small")
headline = MarkDownRenderer("# 杭州周末，换一种心情")
heroImage = Image("杭州西湖远景实拍，湖面、岛屿与远处群山", "https://upload.wikimedia.org/wikipedia/commons/e/ee/Aerial_panorama_of_West_Lake_and_its_surrounding_mountains._December_2023.jpg")
opening = TextContent("想在杭州出去走走，不一定要排满景点。先从四种截然不同的氛围里挑一个：湖边的松弛、山涧的绿意、老街的烟火，或宋韵建筑的细节。")
moods = Stack([moodsTitle, moodCards, moodCaption], "column", "s")
moodsTitle = MarkDownRenderer("## 四种周末，各有自己的节奏")
moodCards = VisualCardBlock([moodCards_part1, moodCards_part2, moodCards_part3, moodCards_part4], "carousel", true)
moodCards_part1 = VisualCardItem(BoldText("text", "湖边漫步"), "lake", "https://img1.qunarzz.com/travel/d0/1508/b5/86a1839a0346a8.jpg_r_720x480x95_04ad6f0a.jpg", Tag("苏堤", null, "sm", "neutral"), "西湖苏堤沿湖步道与柳树实景")
moodCards_part2 = VisualCardItem(BoldText("text", "山涧寻绿"), "creek", "https://www.pelago.com/img/products/CN-China/half-day-hangzhou-nine-creeks-hiking-tour-with-tea-plantation-experience/862ecdad-1461-41c7-9853-78bc7f397cb4_half-day-hangzhou-nine-creeks-hiking-tour-with-tea-plantation-experience-xlarge.webp", Tag("九溪烟树", null, "sm", "neutral"), "杭州九溪烟树林荫溪流与石阶实景")
moodCards_part3 = VisualCardItem(BoldText("text", "老城烟火"), "street", "https://photo.tuchong.com/1341903/f/268355055.jpg", Tag("南宋御街", null, "sm", "neutral"), "杭州南宋御街石板路、沿街店铺与行人实景")
moodCards_part4 = VisualCardItem(BoldText("text", "宋韵建筑"), "palace", "https://p9.itc.cn/q_70/images03/20221030/ec6c914e9d9e483bb46ef2e1359a2d8b.jpeg", Tag("德寿宫", null, "sm", "neutral"), "杭州德寿宫红墙古树与游客实景")
moodCaption = TextContent("上面的照片来自不同日期的公开实景，仅用于辨认环境与氛围；不代表当前天气、人流或开放状态。", "small")
choosing = Stack([choosingTitle, choices], "column", "s")
choosingTitle = MarkDownRenderer("## 按自己的状态选，不用四处都去")
choices = ContextCardBlock([choices_part1, choices_part2], "grid", true)
choices_part1 = ContextCardItem("easy", "轻松走走，不想安排太满", "苏堤可以只走喜欢的一段；南宋御街适合边逛边吃，时间安排更灵活。", "gray")
choices_part2 = ContextCardItem("deep", "愿意留出半天，认真体验", "九溪需要为步行留出余量；德寿宫则值得分别看地上建筑与地下遗址。", "gray")
places = Stack([mapTitle, sceneMap, mapCaption], "column", "s")
mapTitle = MarkDownRenderer("## 四个地点，大致在哪儿？")
sceneMap = Map([sudiPoint, jiuxiPoint, streetPoint, deshouPoint], "wgs84")
sudiPoint = MapPoint("苏堤 · 湖边漫步", 30.242637, 120.134544, "https://img1.qunarzz.com/travel/d0/1508/b5/86a1839a0346a8.jpg_r_720x480x95_04ad6f0a.jpg", null, "西湖西侧长堤，可任选一段步行")
jiuxiPoint = MapPoint("九溪烟树 · 山涧寻绿", 30.204675, 120.108564, "https://www.pelago.com/img/products/CN-China/half-day-hangzhou-nine-creeks-hiking-tour-with-tea-plantation-experience/862ecdad-1461-41c7-9853-78bc7f397cb4_half-day-hangzhou-nine-creeks-hiking-tour-with-tea-plantation-experience-xlarge.webp", null, "西湖西南侧山谷，林荫与溪流步道")
streetPoint = MapPoint("南宋御街 · 老城烟火", 30.244830, 120.166119, "https://photo.tuchong.com/1341903/f/268355055.jpg", null, "上城区历史风貌商业街，适合闲逛")
deshouPoint = MapPoint("德寿宫 · 宋韵建筑", 30.241200, 120.168620, "https://p9.itc.cn/q_70/images03/20221030/ec6c914e9d9e483bb46ef2e1359a2d8b.jpeg", null, "上城区宫苑遗址博物馆，红墙与地下遗址")
mapCaption = TextContent("御街和德寿宫都在上城区一带；苏堤靠西湖，九溪更偏西南。地图是位置对照，不是建议一次走完四处的路线。", "small")
closing = Stack([closing_part1, closeTitle, closeText], "column", "s")
closing_part1 = Separator("horizontal")
closeTitle = MarkDownRenderer("## 先选一种喜欢的感觉")
closeText = TextContent("第一次来，想随意走走，可以从苏堤或南宋御街开始；若更喜欢山间自然，选九溪；偏爱历史建筑，就把时间留给德寿宫。选定方向后，再细化到出入口、交通与半日节奏。")
followUps = FollowUpBlock([FollowUpItem("帮我把西湖散步安排成轻松的半日行程"), FollowUpItem("我更喜欢宋韵建筑，帮我细化德寿宫周边的半日安排")])
```

## Case 02 · 杭州两日 · 实景与票务预览

```openui-lang
root = Stack([hero, intro, dayOne, dayTwo, mapSection, ticketSection, comparison, conclusion], "column", "xl")
hero = Stack([hero_part1, hero_part2, heroImage, heroCaption], "column", "s")
hero_part1 = TextContent("HANGZHOU · A VISUAL JOURNEY", "small")
hero_part2 = MarkDownRenderer("# 杭州两日 · 实景预览")
heroImage = Image("德寿宫宫墙，古树和游客沿红墙散步", "https://p9.itc.cn/q_70/images03/20221030/ec6c914e9d9e483bb46ef2e1359a2d8b.jpeg")
heroCaption = TextContent("德寿宫红墙实拍 · 古树、宫墙与行人，是杭州很有辨识度的宋韵画面。", "small")
intro = Stack([intro_part1, intro_part2, intro_part3], "column", "s")
intro_part1 = TextContent("两天，两种杭州。", "large-heavy")
intro_part2 = TextContent("喜欢南宋历史与文人文化，可以先从这两组景点认识这座城：第一天看宫苑、官窑和老城，第二天沿西湖寻找文人遗迹。")
intro_part3 = TextContent("照片来自不同时期的公开实景，供了解外观和空间氛围；不代表实时天气、人流或开放状态。", "small")
dayOne = Stack([dayOneTitle, kiln, deshou, dayOnePair], "column", "l")
dayOneTitle = Stack([dayOneTitle_part1, dayOneTitle_part2], "column", "xs")
dayOneTitle_part1 = MarkDownRenderer("## Day 01｜南宋临安")
dayOneTitle_part2 = TextContent("官窑博物馆 → 德寿宫 → 南宋遗址陈列馆 → 南宋御街", "small")
kiln = Stack([kiln_part1, kiln_part2, kiln_part3, kiln_part4], "column", "s")
kiln_part1 = Image("南宋官窑博物馆室内龙窑遗址全景", "https://www.hangchow.org/data/upload/ueditor/20230106/63b787c317c37.jpg")
kiln_part2 = CardHeader("01 · 杭州南宋官窑博物馆", "古窑址 · 青瓷 · 安静的庭院")
kiln_part3 = TextContent("这里主要看保护在室内的古窑址。长条形的土质结构，就是当年烧造瓷器的龙窑遗迹。")
kiln_part4 = MarkDownRenderer("**现场感受：** 安静、朴素，有很强的考古感，更像走进宋代工匠工作过的地方。")
deshou = Stack([deshou_part1, deshou_part2, deshou_part3, deshouGallery, deshouFeeling], "column", "s")
deshou_part1 = Image("德寿宫重华宫仿宋建筑正面实拍", "https://imagecloud.thepaper.cn/thepaper/image/225/370/576.jpg")
deshou_part2 = CardHeader("02 · 南宋德寿宫遗址博物馆", "皇家宫苑 · 红墙 · 地下遗址")
deshou_part3 = TextContent("地面是依历史资料营造的宋韵建筑群，真正的南宋遗址保留在地下。")
deshouGallery = ImageGallery([deshouGallery_image1, deshouGallery_image2])
deshouGallery_image1 = {"src":"https://hznews.hangzhou.com.cn/chengshi/content/2022-11/18/8ef4e822-a19e-4ed4-bc72-1ea847fb06bf_zsize.png","alt":"德寿宫室外红墙和院落实景","details":"室外 · 红墙"}
deshouGallery_image2 = {"src":"https://dimg04.c-ctrip.com/images/1mh0t12000al0nz2w4226_W_640_10000.jpg?proc=autoorient","alt":"德寿宫地下遗址展厅与保护展示空间","details":"室内 · 遗址展区"}
deshouFeeling = MarkDownRenderer("**现场感受：** 地上开阔、庄重；地下光线较暗，像走进一座沉浸式考古博物馆。")
dayOnePair = Stack([siteCard, streetCard], "row", "m", "start", "start", true)
siteCard = Card([siteCard_part1, siteCard_part2, siteCard_part3], "clear", "column", "xs")
siteCard_part1 = Image("南宋遗址陈列馆入口建筑实拍", "https://z.hangzhou.com.cn/2022/syjy/images/2022-12/09/d809c897-a59f-46fb-8f43-1797ddec8e68.jpg")
siteCard_part2 = CardHeader("03 · 南宋遗址陈列馆", "小型考古展馆")
siteCard_part3 = TextContent("入口低调，主要看馆内的南宋街道遗迹。")
streetCard = Card([streetCard_part1, streetCard_part2, streetCard_part3], "clear", "column", "xs")
streetCard_part1 = Image("南宋御街行人、石板路与街巷实拍", "https://photo.tuchong.com/1341903/f/268355055.jpg")
streetCard_part2 = CardHeader("04 · 南宋御街", "老城街巷 · 烟火气")
streetCard_part3 = TextContent("沿着老街慢慢走，感受店铺和市井生活。")
dayTwo = Stack([dayTwoTitle, sudi, dayTwoPair, xiling, dongpoExtra], "column", "l")
dayTwoTitle = Stack([dayTwoTitle_part1, dayTwoTitle_part2, dayTwoTitle_part3], "column", "xs")
dayTwoTitle_part1 = Separator("horizontal")
dayTwoTitle_part2 = MarkDownRenderer("## Day 02｜西湖文脉")
dayTwoTitle_part3 = TextContent("苏堤 → 岳王庙 → 孤山与林逋遗迹 → 西泠印社", "small")
sudi = Stack([sudi_part1, sudi_part2, sudi_part3, sudi_part4], "column", "s")
sudi_part1 = Image("西湖苏堤石桥、柳树和湖面实景", "https://img1.qunarzz.com/travel/d0/1508/b5/86a1839a0346a8.jpg_r_720x480x95_04ad6f0a.jpg")
sudi_part2 = TextContent("01 · 苏堤｜在湖心走一段路", "large-heavy")
sudi_part3 = TextContent("柳树、湖面与沿堤的石桥。这里的美不在某一个建筑，而在连续的行走体验。")
sudi_part4 = TextContent("现场氛围｜开阔、松弛；苏堤全长接近 3 公里。", "small")
dayTwoPair = Stack([yueCard, gushanCard], "row", "m", "start", "start", true)
yueCard = Card([yueCard_part1, yueCard_part2, yueCard_part3], "clear", "column", "xs")
yueCard_part1 = Image("岳王庙建筑实景", "https://www.pelago.com/img/products/CN-China/yue-fei-temple-ticket/df78b90c-88b1-4dcf-9345-0f32d6a6d728_yue-fei-temple-ticket.jpg")
yueCard_part2 = CardHeader("02 · 岳王庙", "传统祠庙 · 庄重肃穆")
yueCard_part3 = TextContent("红柱重檐，墓区与碑刻庄重肃穆。")
gushanCard = Card([gushanCard_part1, gushanCard_part2, gushanCard_part3], "clear", "column", "xs")
gushanCard_part1 = Image("孤山放鹤亭实景", "https://youimg1.c-ctrip.com/target/fd/tg/g1/M0B/C3/49/CghzflT_pLqAB8CTABhI6i-AH8Q373.jpg")
gushanCard_part2 = CardHeader("03 · 孤山与放鹤亭", "林逋遗迹 · 清幽园林")
gushanCard_part3 = TextContent("树荫、石阶、古亭，慢慢走更有味道。")
xiling = Stack([xiling_part1, xiling_part2, xiling_part3, xilingGallery, xilingMood], "column", "s")
xiling_part1 = Image("西泠印社华严经塔、池塘、植物构成的古典园林实景", "https://pic.hangzhou.com.cn/hzyx/images/2022-08/20/a5e06102-cac4-485d-b7a5-361a0e269225_zsize.jpg")
xiling_part2 = TextContent("04 · 西泠印社｜藏在孤山里的文人园林", "large-heavy")
xiling_part3 = TextContent("石径、亭台、摩崖题刻与篆刻文化散落在山坡上。相比西湖主游览道，更适合慢慢观察建筑和书法。")
xilingGallery = ImageGallery([xilingGallery_image1, xilingGallery_image2])
xilingGallery_image1 = {"src": "https://p1-tt.byteimg.com/origin/tos-cn-i-qvj2lq49k0/0b074d1f451d424aa9a977e2a55867ee", "alt": "西泠印社白墙月洞门建筑外观", "details": "建筑细节 · 月洞门"}
xilingGallery_image2 = {"src": "https://www.xlys.org.cn/u/cms/www/202112/13092706qj87.png", "alt": "西泠印社游客听讲解、观看石刻实拍", "details": "实际参观场景"}
xilingMood = TextContent("现场氛围｜精致、清幽，文人气息很浓。", "small")
dongpoExtra = Accordion([dongpoExtra_part1])
dongpoExtra_part1 = AccordionItem("dongpo", "补充 · 苏东坡纪念馆", [dongpoPhoto, TextContent("馆址位于苏堤南端附近。这里有绿荫中的传统风格纪念建筑，但距离岳王庙与孤山所在的北段较远。", "small")])
dongpoPhoto = Image("苏东坡纪念馆实拍，传统屋顶建筑立于绿荫之中", "https://edu.hangzhou.com.cn/2024rdzt/zdagzyjd/images/2024-08/07/482030a1-e1f3-4cf9-875e-4df9dd93dbee.jpg")
mapSection = Stack([mapSection_part1, mapSection_part2, mapSection_part3, allMap], "column", "s")
mapSection_part1 = Separator("horizontal")
mapSection_part2 = MarkDownRenderer("## 两天的地点，在地图上是什么关系？")
mapSection_part3 = TextContent("第一组主要在南宋临安城区域，第二组沿西湖和孤山展开。地图同时展示全部九个地点；苏东坡纪念馆为补充选项。", "small")
allMap = Map([pKiln, pDeshou, pSite, pStreet, pSudi, pYue, pGushan, pXiling, pDongpo], "wgs84")
pKiln = MapPoint("南宋官窑博物馆", 30.21183, 120.150447, "https://www.hangchow.org/data/upload/ueditor/20230106/63b787c317c37.jpg", null, "第一天 · 南宋临安 · 古窑址")
pDeshou = MapPoint("南宋德寿宫遗址博物馆", 30.2412, 120.16862, "https://imagecloud.thepaper.cn/thepaper/image/225/370/576.jpg", null, "第一天 · 南宋临安 · 宫苑遗址")
pSite = MapPoint("南宋遗址陈列馆", 30.23219, 120.1652, "https://z.hangzhou.com.cn/2022/syjy/images/2022-12/09/d809c897-a59f-46fb-8f43-1797ddec8e68.jpg", null, "第一天 · 南宋临安 · 街道遗迹")
pStreet = MapPoint("南宋御街", 30.24467, 120.16616, "https://photo.tuchong.com/1341903/f/268355055.jpg", null, "第一天 · 南宋临安 · 老街")
pSudi = MapPoint("苏堤中段", 30.242637, 120.134544, "https://img1.qunarzz.com/travel/d0/1508/b5/86a1839a0346a8.jpg_r_720x480x95_04ad6f0a.jpg", null, "第二天 · 西湖文脉 · 沿湖步道")
pYue = MapPoint("岳王庙", 30.25474, 120.12977, "https://www.pelago.com/img/products/CN-China/yue-fei-temple-ticket/df78b90c-88b1-4dcf-9345-0f32d6a6d728_yue-fei-temple-ticket.jpg", null, "第二天 · 西湖文脉 · 祠庙")
pGushan = MapPoint("孤山放鹤亭附近", 30.2542, 120.138013, "https://youimg1.c-ctrip.com/target/fd/tg/g1/M0B/C3/49/CghzflT_pLqAB8CTABhI6i-AH8Q373.jpg", null, "第二天 · 西湖文脉 · 林逋遗迹")
pXiling = MapPoint("西泠印社", 30.252578, 120.135202, "https://pic.hangzhou.com.cn/hzyx/images/2022-08/20/a5e06102-cac4-485d-b7a5-361a0e269225_zsize.jpg", null, "第二天 · 西湖文脉 · 金石篆刻")
pDongpo = MapPoint("苏东坡纪念馆", 30.231245, 120.13929, "https://edu.hangzhou.com.cn/2024rdzt/zdagzyjd/images/2024-08/07/482030a1-e1f3-4cf9-875e-4df9dd93dbee.jpg", null, "补充地点 · 苏堤南端")
ticketSection = Stack([ticketSection_part1, ticketSection_part2, freeAdmission, ticketCards], "column", "s")
ticketSection_part1 = Separator("horizontal")
ticketSection_part2 = MarkDownRenderer("## 门票与预约")
freeAdmission = Stack([freeAdmission_part1, freeAdmission_part2], "column", "xs")
freeAdmission_part1 = TextContent("免费参观：德寿宫、南宋官窑博物馆、南宋遗址陈列馆；苏堤、南宋御街、孤山和西泠印社的公共游览区域也无需购买门票。", "small")
freeAdmission_part2 = TextContent("德寿宫个人参观免预约；其他场馆的周末预约要求与临时展览以当期公告为准。", "small")
ticketCards = Card([ticketCards_image, ticketCards_heading, ticketCards_detail1, ticketCards_spec, ticketCards_footer], "card", "column", "s")
ticketCards_image = Image("岳王庙正殿建筑实拍", "https://www.pelago.com/img/products/CN-China/yue-fei-temple-ticket/df78b90c-88b1-4dcf-9345-0f32d6a6d728_yue-fei-temple-ticket.jpg")
ticketCards_heading = CardHeader("岳王庙")
ticketCards_detail1 = TextContent("红柱重檐的祠庙建筑与墓区、碑刻共同构成纪念岳飞的游览空间。")
ticketCards_spec = TextContent("成人票 · 单次入园 · Day 02
实际票价及优惠以所选日期为准。", "small")
ticketCards_footer = Stack([ticketCards_price, ticketCards_buttons], "row", "m", "center", "between")
ticketCards_price = BoldText("number", "¥25 起", "成人票 · 单次入园", "text", "lg")
ticketCards_buttons = Buttons([Button("查看门票", @OpenUrl("https://touch.piao.qunar.com/touch/detail.htm?id=3501705640"), "primary", "normal", "small")], "row")
comparison = Stack([comparison_part1, comparison_part2, atmosphereTable], "column", "s")
comparison_part1 = Separator("horizontal")
comparison_part2 = MarkDownRenderer("## 现场氛围，一眼对比")
atmosphereTable = Table([Col("地点", comparisonPlaces, "string"), Col("实际氛围", comparisonAtmospheres, "string"), Col("视觉看点", comparisonHighlights, "string")])
conclusion = Stack([conclusion_part1, conclusion_part2, conclusion_part3], "column", "s")
conclusion_part1 = Separator("horizontal")
conclusion_part2 = MarkDownRenderer(conclusionTitle)
conclusion_part3 = TextContent(conclusionText)
comparisonPlaces = ["德寿宫","官窑博物馆","南宋遗址陈列馆","南宋御街","苏堤","岳王庙","孤山","西泠印社"]
comparisonAtmospheres = ["宫苑感、仪式感","安静、朴素","低调、考古感","热闹、商业化","开阔、自然","庄重、肃穆","清幽、古朴","雅致、文人气息"]
comparisonHighlights = ["红墙、复原建筑、遗址","古窑址、青瓷、庭院","地下街道遗迹","老街立面、市井生活","湖水、长堤、树荫","祠庙、墓碑、殿宇","放鹤亭、石阶、林木","园林、书法、石刻"]
conclusionTitle = "## 哪些地方最值得认真停留？"
conclusionText = "想看建筑与遗址的层次，优先德寿宫；偏好文人书画和园林细节，把时间留给孤山与西泠印社；希望放慢节奏看湖，就在苏堤走一段。"
```

## Case 03 · 空调制热 · 热泵原理

```openui-lang
root = Stack([intro, overview, temperature, mechanism, modes, efficiency, conclusion, followUps], "column", "l")
intro = Stack([intro_part1, intro_part2], "column", "xs")
intro_part1 = TextContent("空调冬天能制热，其实是因为它有一种很巧妙的能力：**把室外的热量搬到室内，而不是直接制造热量。**")
intro_part2 = TextContent("它的原理叫作 **热泵（Heat Pump）**，你可以把它理解成一台能够反向工作的冰箱。")
overview = Stack([overviewTitle, overviewCards], "column", "s")
overviewTitle = Stack([overviewTitle_part1, overviewTitle_part2], "column", "xs")
overviewTitle_part1 = MarkDownRenderer("### 核心概览")
overviewTitle_part2 = TextContent("两件事就能理解空调制热", "small")
overviewCards = OverviewCardBlock([overviewSource, overviewDirection], "grid")
overviewSource = OverviewCardItem("heat-source", IconText(Icon("wind"), "info", "s", "热量从哪里来"), MetricIndicatorInline("室外空气", "低温空气中仍然有热量"))
overviewDirection = OverviewCardItem("heat-direction", IconText(Icon("arrow-right"), "warning", "s", "热量往哪里去"), MetricIndicatorInline("室外 → 室内", "压缩机驱动热量搬运"))
temperature = Stack([temperature_part1, temperature_part2, temperature_part3, temperatureCard, temperature_part5], "column", "s")
temperature_part1 = MarkDownRenderer("### 01 · 冬天室外那么冷，哪来的热量？")
temperature_part2 = TextContent("这是最容易困惑的地方。**温度低不代表没有热量。** 即使室外只有 0℃，空气中的分子仍然在运动，仍然具有热能。")
temperature_part3 = TextContent("只要空调内部的制冷剂温度比室外空气更低，就能从室外吸收热量。")
temperatureCard = Card([temperatureCard_part1, temperatureCard_part2], "sunk", "column", "xs")
temperatureCard_part1 = EntityList([{"left":"室外空气","right":"0℃"},{"left":"制冷剂","right":"-15℃"}], "small")
temperatureCard_part2 = TextContent("热量就能从 0℃ 的空气流向 -15℃ 的制冷剂。上述温度仅为原理示例，不是空调运行时的固定值。")
temperature_part5 = TextContent("然后，空调通过压缩机把制冷剂变成高温高压状态，再把热量释放到室内。")
mechanism = Stack([mechanism_part1, heatDiagram, mechanism_part3, mechanismSteps], "column", "s")
mechanism_part1 = MarkDownRenderer("### 02 · 空调是怎么搬运热量的？")
heatDiagram = SVG("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 330 150'><rect width='330' height='150' rx='10' fill='#F5F7F9'/><rect x='10' y='12' width='110' height='115' rx='9' fill='#E0EDF7'/><rect x='210' y='12' width='110' height='115' rx='9' fill='#FAE8D7'/><text x='65' y='35' text-anchor='middle' font-size='13' fill='#356B91' font-weight='600'>室外 0℃</text><text x='265' y='35' text-anchor='middle' font-size='13' fill='#9E622E' font-weight='600'>室内 22℃</text><g stroke='#6A9BC0' stroke-width='2' fill='none'><path d='M42 52q-6 9 0 18t0 18'/><path d='M56 52q-6 9 0 18t0 18'/><path d='M70 52q-6 9 0 18t0 18'/></g><g stroke='#DE9256' stroke-width='2' fill='none'><path d='M242 52q-6 9 0 18t0 18'/><path d='M256 52q-6 9 0 18t0 18'/><path d='M270 52q-6 9 0 18t0 18'/></g><text x='65' y='107' text-anchor='middle' font-size='11' fill='#356B91'>吸热</text><text x='265' y='107' text-anchor='middle' font-size='11' fill='#9E622E'>放热</text><rect x='129' y='48' width='72' height='42' rx='8' fill='#E5AA6A'/><text x='165' y='65' text-anchor='middle' font-size='11' fill='#513722'>压缩机</text><text x='165' y='80' text-anchor='middle' font-size='10' fill='#513722'>升温加压</text><path d='M118 108H209' stroke='#D88943' stroke-width='5' stroke-linecap='round'/><path d='M199 102l10 6-10 6' stroke='#D88943' stroke-width='3' fill='none' stroke-linejoin='round'/><path d='M252 125v9H78v-9' stroke='#7E9FBA' fill='none' stroke-width='1.5' stroke-dasharray='4 3'/><text x='165' y='145' text-anchor='middle' font-size='10' fill='#65788A'>制冷剂循环 · 热量向室内转移</text></svg>", null, "热泵空调冬季制热原理示意")
mechanism_part3 = TextContent("图解｜室外机吸热，压缩机升温加压，室内机释放热量。图示为简化原理，并非实际管路。", "small")
mechanismSteps = ListBlock([mechanismSteps_part1, mechanismSteps_part2, mechanismSteps_part3, mechanismSteps_part4], "number", "small")
mechanismSteps_part1 = ListItem("室外吸热", "低温制冷剂吸收室外空气中的热量，逐渐蒸发。")
mechanismSteps_part2 = ListItem("压缩升温", "压缩机对气态制冷剂做功，使其温度和压力升高。")
mechanismSteps_part3 = ListItem("室内放热", "高温制冷剂在室内机冷凝，释放热量，风扇吹出热风。")
mechanismSteps_part4 = ListItem("降压降温", "制冷剂经过节流装置降压降温，再次回到室外吸热。")
modes = Stack([modes_part1, modes_part2, modeList, modes_part4], "column", "s")
modes_part1 = MarkDownRenderer("### 03 · 空调制冷和制热有什么区别？")
modes_part2 = TextContent("本质上是同一套原理，只不过热量搬运方向相反。")
modeList = SnippetCardBlock([summer, winter], "grid")
summer = SnippetCardItem("summer", IconText(Icon("snowflake"), "info", "s", "夏天制冷", "室内热量搬到室外"), BoldText("text", "室内 → 室外", null, null, "sm"))
winter = SnippetCardItem("winter", IconText(Icon("sun"), "warning", "s", "冬天制热", "室外热量搬到室内"), BoldText("text", "室外 → 室内", null, null, "sm"))
modes_part4 = TextContent("能够制冷制热的空调，通常通过 **四通换向阀** 切换制冷剂的流动路径，从而改变室内外换热器的作用。")
efficiency = Stack([efficiency_part1, efficiency_part2, efficiencyFigure, efficiency_part4, efficiency_part5], "column", "s")
efficiency_part1 = MarkDownRenderer("### 04 · 为什么空调制热有时比电暖器省电？")
efficiency_part2 = TextContent("电暖器主要是把电能直接转化为热量，而热泵空调还从室外搬来了额外的热量。")
efficiencyFigure = Stack([efficiencyFigure_part1, efficiencyBars, efficiencyFigure_part3], "column", "xs")
efficiencyFigure_part1 = TextContent("**假设两台设备各消耗 1 度电**", "small-heavy")
efficiencyBars = SVG("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 330 139'><rect width='330' height='139' rx='10' fill='#F5F7F9'/><text x='14' y='23' font-size='12' fill='#3C4A58'>普通电暖器</text><text x='316' y='23' text-anchor='end' font-size='11' fill='#5F6B78'>约 1 度热量</text><rect x='14' y='33' width='302' height='17' rx='4' fill='#E6E9ED'/><path d='M18 33H100V50H18Q14 50 14 46V37Q14 33 18 33Z' fill='#929CA8'/><text x='14' y='78' font-size='12' fill='#3C4A58'>热泵空调</text><text x='316' y='78' text-anchor='end' font-size='11' fill='#A56633'>约 3.5 度热量</text><rect x='14' y='88' width='302' height='17' rx='4' fill='#E6E9ED'/><path d='M18 88H100V105H18Q14 105 14 101V92Q14 88 18 88Z' fill='#929CA8'/><path d='M100 88H312Q316 88 316 92V101Q316 105 312 105H100Z' fill='#E5A25F'/><rect x='14' y='119' width='9' height='9' rx='2' fill='#929CA8'/><text x='29' y='127' font-size='10' fill='#64717F'>电能投入</text><rect x='117' y='119' width='9' height='9' rx='2' fill='#E5A25F'/><text x='132' y='127' font-size='10' fill='#64717F'>额外从室外搬来的热量</text></svg>", null, "电暖器与热泵空调消耗一度电时的供热量示意比较")
efficiencyFigure_part3 = TextContent("灰色表示电能投入，橙色表示从室外搬来的热量。图中热泵按 3.5 度热量示意；实际效率取决于设备性能和运行工况。", "small")
efficiency_part4 = TextContent("热泵空调的制热性能系数（COP）可以大于 1，并不违反能量守恒，因为多出来的热量来自室外环境。")
efficiency_part5 = TextContent("不过，室外温度较低时，热泵的制热效率和能力通常会下降。室外机还可能结霜，需要定期除霜，所以空调有时会短暂停止吹热风。")
conclusion = Stack([conclusion_part1, conclusion_part2], "column", "xs")
conclusion_part1 = MarkDownRenderer("### 一句话总结")
conclusion_part2 = TextContent("空调制热的本领，不是用电直接烧出热量，而是用电驱动压缩机，把室外本来就存在的热量搬进屋里。")
followUps = FollowUpBlock([FollowUpItem("制热时温度和风速怎么设置更舒服？"), FollowUpItem("一直开空调和频繁开关，哪种更省电？")])
```

## Case 04 · 卧室氛围 · 风格探索

```openui-lang
root = Stack([intro, section1, chooser, section2, tips, advice, closing], "column", "xl")
intro = Stack([intro1, intro2], "column", "s")
intro1 = MarkDownRenderer("我建议先别急着给卧室定一个「日式」「北欧」之类的风格标签。**先找到一种你愿意每天回家后待在里面的感觉**，再考虑家具、颜色和装饰。")
intro2 = TextContent("先看看三种配色、灯光和材质不同的卧室，凭直觉选择吸引你的部分，再逐步确认自己的偏好。")
section1 = MarkDownRenderer("## 01｜找到你喜欢的卧室氛围")
chooser = Form("bedroom-style-exploration", Buttons([Button("按我的选择继续", @ToAssistant("根据我刚才选中的卧室氛围，帮我提炼共同偏好，给出租房可执行的配色、灯光和软装建议。优先不破坏房屋、可搬走的改变，不要直接推荐购物商品。"), "secondary", "normal", "medium")]), [chooser_part1])
chooser_part1 = FormControl("选最想住进去的感觉，也可以组合两种", OptionCards("卧室氛围", "multiple", [styleA, styleB, styleC], {required: true}))
styleA = OptionCard("自然松弛", "A · 自然松弛", "奶油白、浅木、棉麻；像阳光晒过的房间。", imgA)
imgA = Image("自然松弛、浅木色和暖白床品的卧室", "https://images.unsplash.com/photo-1616594039964-ae9021a400a0?w=900&q=85")
styleB = OptionCard("安静克制", "B · 安静克制", "深木、亚麻、间接暖光；安静而有秩序。", imgB)
imgB = Image("安静克制、柔和照明的卧室", "https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?w=900&q=85")
styleC = OptionCard("温暖复古", "C · 温暖复古", "胡桃木、藤编、焦糖色；温润、有生活感。", imgC)
imgC = Image("胡桃木与复古氛围的温暖卧室", "https://images.unsplash.com/photo-1615874694520-474822394e73?w=900&q=85")
section2 = MarkDownRenderer("## 02｜舒服，不一定需要重新装修")
tips = VisualCardBlock([tipA, tipB, tipC], "carousel", true)
tipA = VisualCardItem(tipTextA, "light", "https://images.unsplash.com/photo-1507473885765-e6ed057f782c?w=800&q=85")
tipTextA = BoldText("text", "灯光", "用低位暖光代替刺眼的顶灯。")
tipB = VisualCardItem(tipTextB, "fabric", "https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800&q=85")
tipTextB = BoldText("text", "织物", "用床品和窗帘增加柔软质感。")
tipC = VisualCardItem(tipTextC, "space", "https://images.unsplash.com/photo-1778145792155-708f364bd772?auto=format&fit=crop&fm=jpg&ixid=NHwxMjA3fDA%3D&ixlib=rb-4.1.0&q=60&w=3000")
tipTextC = BoldText("text", "留白", "少放零碎装饰，让空间能呼吸。")
advice = TextContent("如果是租来的卧室，建议先调整灯光、床品和窗帘，再考虑家具。优先选择可以撤回、也方便搬走的改变。")
closing = Stack([question, closingDesc], "column", "s")
question = MarkDownRenderer("**不必追求纯粹的一种风格。** 喜欢 A 的配色、B 的灯光，完全可以组合成你自己的卧室。")
closingDesc = TextContent("等确认喜欢的氛围，我们再结合房间尺寸和现有家具，把它落实成具体布置。")
```

## Case 05 · 小书桌 · 阅读台灯决策

```openui-lang
root = Stack([lead, products, fit, closing], "column", "l")
lead = Stack([headline, leadText, preferences], "column", "s")
headline = MarkDownRenderer("# 小书桌，选一盏真正好用的读书灯")
leadText = MarkDownRenderer("**小桌面先比较摆放方式，再看功能。** 折叠式方便收纳，夹式可以少占桌面；具体是否放得下，还要核对底座、夹口和灯臂尺寸。")
preferences = TextContent("小桌面 · 阅读用途 · 先比较折叠与夹式", "small")
products = Stack([productsHeader, productsCarousel, priceNote], "column", "s")
productsHeader = InlineHeader("三款台灯候选", "比较摆放方式，并核对具体规格")
productsCarousel = CompositeCardBlock([folding, rechargeable, clipLamp], "carousel", true)
folding = CompositeCardItem("taobao-971628097659", ImageTextLarge("https://img.alicdn.com/imgextra/i1/2216436773929/O1CN010S8AcDt6spH1chua_!!4611686018427384873-0-item_pic.jpg", "惠普折叠阅读台灯商品图", "惠普折叠阅读台灯", "惠普照明旗舰店", true), [], {"price":BoldText("number", "¥84.00", "示例记录价", "text", "lg"), "button":Button("查看商品", @OpenUrl("https://detail.tmall.com/item.htm?id=971628097659"), "primary", "normal", "small")})
rechargeable = CompositeCardItem("taobao-1014479690931", ImageTextLarge("https://img.alicdn.com/imgextra/i3/138006397/O1CN01GESzBaCMA9E1chua-138006397.jpg", "欧普充电折叠台灯商品图", "欧普充电折叠台灯", "欧普照明官方旗舰店", true), [], {"price":BoldText("number", "¥116.20", "示例记录价", "text", "lg"), "button":Button("查看商品", @OpenUrl("https://detail.tmall.com/item.htm?id=1014479690931"), "primary", "normal", "small")})
clipLamp = CompositeCardItem("taobao-1087331917809", ImageTextLarge("https://img.alicdn.com/imgextra/i3/2217254400585/O1CN01wHFlHoptgGH1chua_!!2217254400585-0-C2M.jpg", "充电夹式阅读台灯商品图", "充电夹式阅读台灯", "国货严选旗舰", true), [], {"price":BoldText("number", "¥49.90", "示例记录价", "text", "lg"), "button":Button("查看商品", @OpenUrl("https://detail.tmall.com/item.htm?id=1087331917809"), "primary", "normal", "small")})
priceNote = TextContent("以上商品名称、店铺、图片与价格沿用 2026-11-10 的示例记录，不代表本次实时查询结果；具体规格与结算条件以商品页为准。", "small")
fit = Stack([fitTitle, fitList], "column", "xs")
fitTitle = MarkDownRenderer("## 用法不同，选择也不同")
fitList = EntityList([{"left":"读完需要收起来","right":"先比较折叠款的尺寸"},{"left":"桌面几乎放不下灯座","right":"核对夹式灯与桌沿是否匹配"},{"left":"希望移动使用","right":"比较充电方式和续航条件"}], "small")
closing = Stack([closingTitle, closingText], "column", "xs")
closingTitle = TextContent("买前别漏了这件事", "small-heavy")
closingText = TextContent("量一下灯座能放多宽、灯头会不会挡显示器，再确认照射范围和插座位置。", "small")
```

## Case 06 · 执行用户代码 · 隔离方案决策

```openui-lang
root = Stack([intro, principle, schemes, architecture, kubernetes, recommendation, references, followUps], "column", "xl")
intro = Stack([pageTitle, lead, leadSupplement], "column", "s")
pageTitle = MarkDownRenderer("# 服务端执行用户代码：容器还是虚拟机？")
lead = TextContent("如果你要在服务端执行用户提交的任意代码，我更推荐虚拟机隔离，尤其是 MicroVM（微型虚拟机），而不是直接使用普通 Docker 容器。")
leadSupplement = TextContent("但不一定需要自己管理传统虚拟机。现在有一条更实用的路线：保留容器的使用体验，底层采用虚拟机隔离。")
principle = Stack([principleHeading, isolationDiagram, isolationCaption, containerExplanation, vmExplanation], "column", "s")
principleHeading = MarkDownRenderer("## 01 · 容器与虚拟机，核心区别是什么？")
isolationDiagram = SVG("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 340 192'><rect x='1' y='1' width='164' height='189' rx='9' fill='#EDF7F3' stroke='#BCDCD0'/><rect x='175' y='1' width='164' height='189' rx='9' fill='#EFF4FB' stroke='#BFD0E8'/><text x='83' y='22' text-anchor='middle' font-size='12' font-weight='600' fill='#276B57'>Container</text><text x='257' y='22' text-anchor='middle' font-size='12' font-weight='600' fill='#315F95'>Virtual Machine</text><rect x='10' y='36' width='70' height='42' rx='5' fill='#D1E9DD'/><rect x='85' y='36' width='70' height='42' rx='5' fill='#D1E9DD'/><text x='45' y='53' text-anchor='middle' font-size='10' fill='#28634F'>用户代码</text><text x='45' y='67' text-anchor='middle' font-size='9' fill='#477A69'>Container</text><text x='120' y='53' text-anchor='middle' font-size='10' fill='#28634F'>用户代码</text><text x='120' y='67' text-anchor='middle' font-size='9' fill='#477A69'>Container</text><rect x='10' y='85' width='145' height='43' rx='5' fill='#BCDDCE'/><text x='82' y='103' text-anchor='middle' font-size='11' font-weight='600' fill='#28634F'>共享 Host Kernel</text><text x='82' y='117' text-anchor='middle' font-size='9' fill='#477A69'>同一个宿主机内核</text><rect x='182' y='33' width='70' height='96' rx='6' fill='#DCE8F7' stroke='#A2BDDC'/><rect x='262' y='33' width='70' height='96' rx='6' fill='#DCE8F7' stroke='#A2BDDC'/><rect x='187' y='39' width='60' height='36' rx='4' fill='#BFD3EC'/><rect x='267' y='39' width='60' height='36' rx='4' fill='#BFD3EC'/><text x='217' y='54' text-anchor='middle' font-size='10' fill='#315F95'>用户代码</text><text x='217' y='67' text-anchor='middle' font-size='9' fill='#315F95'>Container</text><text x='297' y='54' text-anchor='middle' font-size='10' fill='#315F95'>用户代码</text><text x='297' y='67' text-anchor='middle' font-size='9' fill='#315F95'>Container</text><rect x='187' y='81' width='60' height='41' rx='4' fill='#ABC8E8'/><rect x='267' y='81' width='60' height='41' rx='4' fill='#ABC8E8'/><text x='217' y='98' text-anchor='middle' font-size='9' fill='#315F95'>Guest</text><text x='217' y='111' text-anchor='middle' font-size='9' fill='#315F95'>Kernel</text><text x='297' y='98' text-anchor='middle' font-size='9' fill='#315F95'>Guest</text><text x='297' y='111' text-anchor='middle' font-size='9' fill='#315F95'>Kernel</text><rect x='182' y='135' width='150' height='22' rx='4' fill='#BFD3EC'/><text x='257' y='150' text-anchor='middle' font-size='10' fill='#315F95'>Hypervisor / KVM</text><rect x='10' y='160' width='145' height='23' rx='4' fill='#BCDDCE'/><rect x='182' y='164' width='150' height='19' rx='4' fill='#BFD3EC'/><text x='82' y='176' text-anchor='middle' font-size='10' fill='#28634F'>Host 硬件</text><text x='257' y='177' text-anchor='middle' font-size='10' fill='#315F95'>Host 硬件</text></svg>", null, "容器与虚拟机隔离边界对比：容器共享宿主机内核，虚拟机使用独立客户机内核")
isolationCaption = TextContent("普通容器共享宿主机内核；虚拟机拥有独立的 Guest Kernel，通过 Hypervisor 提供硬件虚拟化隔离边界。", "small")
containerExplanation = TextContent("普通容器依靠 Namespace、cgroups、seccomp 等机制隔离进程与资源。它适合运行受信任的应用，但如果用户代码利用内核漏洞，就可能影响整个宿主机。")
vmExplanation = TextContent("虚拟机增加了独立内核和硬件虚拟化边界，通常更适合执行潜在恶意代码。")
schemes = Stack([schemesHeading, comparisonTable, relationshipNote, comparisonNote, detailHeading, detailAccordion], "column", "s")
schemesHeading = MarkDownRenderer("## 02 · 四种常见隔离技术怎么选？")
comparisonTable = Table([Col("方案", ["Docker / runc", "gVisor", "Kata Containers", "Firecracker"]), Col("隔离机制", ["共享 Host Kernel", "用户态应用内核", "Pod 级 VM 隔离", "KVM MicroVM"]), Col("典型场景", ["内部可信代码", "不可信脚本", "K8s 多租户", "高密度执行"])])
relationshipNote = TextContent("注意：这四项不处于同一抽象层。Kata Containers 是容器运行时方案，可选用 QEMU、Cloud Hypervisor、Firecracker 等 VMM；因此 Kata 和 Firecracker 并非互斥。", "small")
comparisonNote = TextContent("资源开销上，普通容器通常最轻；gVisor 引入系统调用处理开销；Kata 需要 VM 运行资源；Firecracker 针对轻量虚拟化优化，但完整冷启动仍取决于镜像、运行时和调度。")
detailHeading = MarkDownRenderer("## 展开了解技术实现")
detailAccordion = Accordion([dockerDetail, gvisorDetail, kataDetail, firecrackerDetail])
dockerDetail = AccordionItem("docker", "Docker / runc · 普通容器", [TextContent("依靠 Linux Namespace、cgroups、seccomp 等内核隔离能力，多个容器共享宿主机内核。启动和资源开销通常较低，但不建议仅依赖普通容器隔离执行完全不可信的任意代码。")])
gvisorDetail = AccordionItem("gvisor", "gVisor · 用户态内核隔离", [TextContent("在用户代码与宿主机内核之间加入用户态应用内核，拦截并实现大量 Linux 系统调用。可以集成 Docker、Kubernetes，适合常见的不可信脚本。"), TextContent("需要特别验证系统调用兼容性、I/O 性能以及目标语言运行时的行为。")])
kataDetail = AccordionItem("kata", "Kata Containers · 容器接口 + VM 隔离", [TextContent("Kata 使用轻量虚拟机承载容器。通常一个 Kata Pod 对应一个独立 VM 沙箱，容器在 VM 内运行。"), TextContent("通过 Kubernetes RuntimeClass，可以在保留现有 Pod 编排体验的同时，获得更强的隔离边界。代价是虚拟机启动、内存及基础设施开销。")])
firecrackerDetail = AccordionItem("firecracker", "Firecracker · 轻量 MicroVM", [TextContent("Firecracker 基于 KVM，通过精简虚拟设备和功能降低虚拟化开销，适合大规模、短生命周期的代码执行任务。"), TextContent("官方最小配置基准中，从启动指令到 Guest 用户态 init 可在 125ms 以内，但这个指标不包含业务镜像准备、运行时初始化和调度等完整冷启动过程。")])
architecture = Stack([architectureHeading, architectureIntro, runtimeDiagram, architectureCaption, securityHeading, securityPoints], "column", "s")
architectureHeading = MarkDownRenderer("## 03 · 服务端执行架构怎么设计？")
architectureIntro = TextContent("假设用户提交 Python、JavaScript、Shell，甚至编译型语言代码，执行环境应当默认视为不可信。")
runtimeDiagram = SVG("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 340 280'><rect x='43' y='2' width='254' height='41' rx='7' fill='#EEF0F4' stroke='#CDD3DB'/><text x='170' y='20' text-anchor='middle' font-size='12' font-weight='600' fill='#384456'>API / Agent 服务</text><text x='170' y='34' text-anchor='middle' font-size='9' fill='#667484'>提交代码 · 鉴权 · 租户配额</text><path d='M170 43V58' stroke='#9AA5B3' stroke-width='1.5'/><path d='M166 54L170 60L174 54' fill='none' stroke='#9AA5B3' stroke-width='1.5'/><rect x='43' y='62' width='254' height='42' rx='7' fill='#E5ECF6' stroke='#BDCEE3'/><text x='170' y='80' text-anchor='middle' font-size='12' font-weight='600' fill='#355F92'>Execution Scheduler</text><text x='170' y='95' text-anchor='middle' font-size='9' fill='#587598'>排队 · 分配 · 超时 · 回收</text><path d='M170 104V117M88 117H252M88 117V132M252 117V132' fill='none' stroke='#9AA5B3' stroke-width='1.5'/><rect x='6' y='132' width='157' height='101' rx='7' fill='#EFF5FC' stroke='#A9C2E0'/><rect x='177' y='132' width='157' height='101' rx='7' fill='#EFF5FC' stroke='#A9C2E0'/><text x='84' y='149' text-anchor='middle' font-size='11' font-weight='600' fill='#355F92'>Sandbox A</text><text x='255' y='149' text-anchor='middle' font-size='11' font-weight='600' fill='#355F92'>Sandbox B</text><rect x='15' y='157' width='139' height='23' rx='4' fill='#D5E5F7'/><rect x='186' y='157' width='139' height='23' rx='4' fill='#D5E5F7'/><text x='84' y='173' text-anchor='middle' font-size='10' fill='#355F92'>用户代码 · Python / JS</text><text x='255' y='173' text-anchor='middle' font-size='10' fill='#355F92'>用户代码 · Shell</text><rect x='15' y='186' width='139' height='18' rx='4' fill='#D5E5F7'/><rect x='186' y='186' width='139' height='18' rx='4' fill='#D5E5F7'/><text x='84' y='199' text-anchor='middle' font-size='9' fill='#355F92'>隔离文件系统</text><text x='255' y='199' text-anchor='middle' font-size='9' fill='#355F92'>隔离文件系统</text><rect x='15' y='210' width='139' height='16' rx='4' fill='#B9D3F0'/><rect x='186' y='210' width='139' height='16' rx='4' fill='#B9D3F0'/><text x='84' y='222' text-anchor='middle' font-size='9' fill='#355F92'>Guest Kernel · VM</text><text x='255' y='222' text-anchor='middle' font-size='9' fill='#355F92'>Guest Kernel · VM</text><path d='M170 233V247' stroke='#9AA5B3' stroke-width='1.5'/><path d='M166 243L170 249L174 243' fill='none' stroke='#9AA5B3' stroke-width='1.5'/><rect x='18' y='252' width='304' height='26' rx='6' fill='#EEF0F4' stroke='#CDD3DB'/><text x='170' y='269' text-anchor='middle' font-size='10' fill='#384456'>宿主机节点池 · 资源计量 · 网络出口控制</text></svg>", null, "API 服务通过调度器管理两个独立虚拟机沙箱，宿主机节点池统一提供资源控制")
architectureCaption = TextContent("每个沙箱具有独立的执行环境与文件系统。调度器负责生命周期，宿主机侧负责资源和网络控制。", "small")
securityHeading = MarkDownRenderer("## 三个关键设计点")
securityPoints = Stack([isolationPoint, warmPoolPoint, securityPoint], "column", "m")
isolationPoint = Stack([isolationPoint_part1, isolationPoint_part2], "column", "xs")
isolationPoint_part1 = TextContent("隔离粒度", "small-heavy")
isolationPoint_part2 = TextContent("短任务可以每次执行创建一个沙箱；有状态 Agent 可按会话分配沙箱。不同不可信租户默认使用不同的 VM 安全边界。")
warmPoolPoint = Stack([warmPoolPoint_part1, warmPoolPoint_part2], "column", "xs")
warmPoolPoint_part1 = TextContent("预热机制", "small-heavy")
warmPoolPoint_part2 = TextContent("高频代码执行可建立 Warm Pool，提前准备沙箱或基础镜像，减少重复初始化的等待时间。")
securityPoint = Stack([securityPoint_part1, securityPoint_part2], "column", "xs")
securityPoint_part1 = TextContent("安全约束", "small-heavy")
securityPoint_part2 = TextContent("默认关闭外网；按需开放出口白名单。限制 CPU、内存、PID、磁盘、执行时长与日志大小。不要暴露宿主机 Docker Socket、云凭证和 K8s ServiceAccount Token。")
kubernetes = Stack([kubernetesHeading, kubernetesIntro, kubernetesDescription, kubeCode, kubernetesNote], "column", "s")
kubernetesHeading = MarkDownRenderer("## 04 · 如果已经使用 Kubernetes")
kubernetesIntro = TextContent("我更倾向于先落地 K8s + Kata Containers，而不是直接自己管理 Firecracker。")
kubernetesDescription = TextContent("一个 Pod 可以通过 `runtimeClassName` 指定虚拟机隔离的运行时：")
kubeCode = CodeBlock("yaml", "apiVersion: v1\nkind: Pod\nmetadata:\n  name: user-code-runner\nspec:\n  runtimeClassName: kata-qemu-runtime-rs\n  automountServiceAccountToken: false\n  restartPolicy: Never\n  containers:\n    - name: runner\n      image: your-runner-image:tag\n      resources:\n        limits:\n          cpu: '1'\n          memory: 512Mi")
kubernetesNote = TextContent("示例中的 RuntimeClass 名称取决于实际安装配置，镜像名称也是占位符。这只是运行时选型示例，不是完整生产安全配置。Kata 需要支持 KVM 的宿主节点，普通云主机不一定支持嵌套虚拟化。", "small")
recommendation = Stack([recommendationHeading, primaryRecommendation, alternativeHeading, alternativeRecommendations, finalNote], "column", "m")
recommendationHeading = MarkDownRenderer("## 05 · 最终选型：结合现有条件")
primaryRecommendation = Card([primaryRecommendation_part1, primaryRecommendation_part2, primaryRecommendation_part3], "sunk", "column", "s")
primaryRecommendation_part1 = TextContent("适用前提：已有 K8s、节点支持 KVM，且运行时兼容性验证通过", "small")
primaryRecommendation_part2 = TextContent("优先评估 Kata Containers", "large-heavy")
primaryRecommendation_part3 = TextContent("保留 Pod 编排方式，同时用独立 VM 作为更强的隔离边界；仍需配合网络、凭证、存储及资源约束。")
alternativeHeading = TextContent("其他情况", "small-heavy")
alternativeRecommendations = Stack([firecrackerChoice, gvisorChoice], "column", "m")
firecrackerChoice = Stack([firecrackerChoice_part1, firecrackerChoice_part2], "column", "xs")
firecrackerChoice_part1 = TextContent("**Firecracker** · 高频短任务", "small-heavy")
firecrackerChoice_part2 = TextContent("优先评估 Firecracker + 自定义执行调度。适合追求极低冷启动、高密度执行，并愿意投入宿主机、镜像、快照、网络及调度工程的平台。")
gvisorChoice = Stack([gvisorChoice_part1, gvisorChoice_part2], "column", "xs")
gvisorChoice_part1 = TextContent("**gVisor** · 常见轻量脚本", "small-heavy")
gvisorChoice_part2 = TextContent("适合希望保留容器体验，并且目标语言和系统调用兼容性满足要求的场景。")
finalNote = TextContent("真正决定架构的，不只是容器和虚拟机本身，还包括沙箱什么时候创建、为谁独占，以及存活多久。")
references = Stack([referenceHeading, referenceLinks], "column", "xs")
referenceHeading = MarkDownRenderer("## 参考文档")
referenceLinks = TextContent("[Kubernetes RuntimeClass](https://kubernetes.io/docs/concepts/containers/runtime-class/) · [Kata Containers](https://github.com/kata-containers/kata-containers/blob/main/docs/design/virtualization.md) · [gVisor](https://gvisor.dev/docs/architecture_guide/intro/) · [Firecracker](https://github.com/firecracker-microvm/firecracker/blob/main/SPECIFICATION.md)", "small")
followUps = FollowUpBlock([FollowUpItem("如何设计沙箱的创建、复用和销毁策略？"), FollowUpItem("已有 Kubernetes 时，怎样验证 Kata 的运行时兼容性？")])
```

## Case 07 · 苏州两天｜陪父母慢慢逛

```openui-lang
root = Stack([hero, introduction, transport, stay, dayOne, dayTwo, locationMap, tickets, finish], "column", "xl")
hero = Stack([hero_part1, hero_part2, demoNotice, coverImage, hero_part4], "column", "s")
hero_part1 = TextContent("SHANGHAI → SUZHOU · 2 DAYS", "small")
hero_part2 = MarkDownRenderer("# 苏州两天｜陪父母慢慢逛")
demoNotice = TextContent("演示行程 · 2026/11/21–22 · 3 位成人。交通时刻、票价和住宿预算为 mock；景点与酒店介绍来自公开资料，未查询实时库存。", "small")
coverImage = Image("苏州平江路真实河道与游船，游客沿岸步行", "https://www.suzhou.gov.cn/szsrmzf/tpxw/202507/8d91434b0f83493aa6cf9ad9e7f9033e/images/d106b03438da47c4b48176a3b817421c.jpg")
hero_part4 = TextContent("不追求多打卡。把时间留给两座园林、两段老街，以及足够从容的吃饭和休息。")
introduction = Stack([introduction_part1, introduction_part2, introduction_part3], "column", "xs")
introduction_part1 = TextContent("两天一晚 · 每天一座园林", "large-heavy")
introduction_part2 = TextContent("建议第一天看拙政园和平江路，第二天看留园和山塘街；跨片区优先打车，古街只走父母觉得舒服的一小段。")
introduction_part3 = TextContent("住宿按 2 间客房、1 晚安排；父母同住一间，同行子女单独一间。", "small")
transport = Stack([transportTitle, transportIntro, outbound, inbound, transferNote], "column", "m")
transportTitle = MarkDownRenderer("## 往返交通")
transportIntro = TextContent("去程上午抵达，返程放在第二天下午。两程都以苏州站接驳古城，车站与酒店之间安排打车。")
outbound = Card([outboundHeading, outboundSpec, outboundJourney, outboundDetail, outboundFare], "card", "column", "s")
outboundHeading = CardHeader("上海 → 苏州")
outboundSpec = TextContent("11/21 · 高铁二等座 · 3 位成人 · 演示方案", "small")
outboundJourney = Stack([outboundDeparture, outboundMiddle, outboundArrival], "row", "s", "start", "between")
outboundDeparture = BoldText("number", "09:30", "上海站", "text", "lg")
outboundMiddle = Card([outboundMiddleContent], "clear", "column", "none")
outboundMiddleContent = Stack([outboundDurationRow, outboundLine, outboundModeRow], "column", "xs", "stretch")
outboundDurationRow = Stack([outboundDuration], "row", "none", "center", "center")
outboundDuration = Text("text", "35 分钟", null, null, "sm")
outboundLine = Separator("horizontal")
outboundModeRow = Stack([outboundMode], "row", "none", "center", "center")
outboundMode = Text("text", "直达", null, null, "sm")
outboundArrival = BoldText("number", "10:05", "苏州站", "text", "lg")
outboundDetail = TextContent("3 人单程合计 ¥180；时刻与金额为演示设定，无真实车次或余票。", "small")
outboundFare = Stack([outboundPrice, outboundActions], "row", "m", "center", "between")
outboundPrice = BoldText("number", "¥60", "每人 / 单程 · 演示价", "text", "lg")
outboundActions = Buttons([Button("查询此路线", @OpenUrl("https://www.12306.cn/index/"), "primary", "normal", "small")], "row")
inbound = Card([inboundHeading, inboundSpec, inboundJourney, inboundDetail, inboundFare], "card", "column", "s")
inboundHeading = CardHeader("苏州 → 上海")
inboundSpec = TextContent("11/22 · 高铁二等座 · 3 位成人 · 演示方案", "small")
inboundJourney = Stack([inboundDeparture, inboundMiddle, inboundArrival], "row", "s", "start", "between")
inboundDeparture = BoldText("number", "16:30", "苏州站", "text", "lg")
inboundMiddle = Card([inboundMiddleContent], "clear", "column", "none")
inboundMiddleContent = Stack([inboundDurationRow, inboundLine, inboundModeRow], "column", "xs", "stretch")
inboundDurationRow = Stack([inboundDuration], "row", "none", "center", "center")
inboundDuration = Text("text", "35 分钟", null, null, "sm")
inboundLine = Separator("horizontal")
inboundModeRow = Stack([inboundMode], "row", "none", "center", "center")
inboundMode = Text("text", "直达", null, null, "sm")
inboundArrival = BoldText("number", "17:05", "上海站", "text", "lg")
inboundDetail = TextContent("3 人单程合计 ¥180；15:00 前结束游览，先取行李再前往车站。", "small")
inboundFare = Stack([inboundPrice, inboundActions], "row", "m", "center", "between")
inboundPrice = BoldText("number", "¥60", "每人 / 单程 · 演示价", "text", "lg")
inboundActions = Buttons([Button("查询此路线", @OpenUrl("https://www.12306.cn/index/"), "primary", "normal", "small")], "row")
transferNote = TextContent("往返合计 ¥360，未含市内接驳。按钮打开 12306 查询入口；演示时刻不是可售班次。", "small")
stay = Stack([stayTitle, stayIntro, hotelCard, hotelCaution], "column", "m")
stayTitle = MarkDownRenderer("## 住一晚｜古城里的落脚点")
stayIntro = TextContent("以同一间酒店作为两天的起终点，减少带行李换住处的折腾。下面展示一个具体住宿对象和独立的预算方案。")
hotelCard = Card([hotelImage, hotelHeading, hotelIntro, hotelSpec, hotelFare], "card", "column", "s")
hotelImage = Image("AC Hotel Suzhou China 酒店入口，来源万豪官网", "https://cache.marriott.com/is/image/marriotts7prod/ar-wuxsa-entrance-25469:Wide-Hor?wid=1336&fit=constrain")
hotelHeading = CardHeader("AC Hotel Suzhou China", "姑苏区 · 人民路 1585 号")
hotelIntro = TextContent("酒店以现代玻璃、石材结合江南白墙黑瓦的建筑元素；客房配有书桌和可调节阅读灯。")
hotelSpec = TextContent("11/21 入住 · 11/22 退房 · 3 位成人
演示用房需求：双床房 1 间 + 大床房 1 间，不代表已查得的可售房型。", "small")
hotelFare = Stack([hotelPrice, hotelActions], "row", "m", "center", "between")
hotelPrice = BoldText("number", "¥1,180", "2 间 × 1 晚 · 演示总预算", "text", "lg")
hotelActions = Buttons([Button("查看酒店", @OpenUrl("https://www.marriott.com/en-us/hotels/wuxsa-ac-hotel-suzhou-china/overview/"), "primary", "normal", "small")], "row")
hotelCaution = TextContent("预算按每间每晚 ¥590 估算，并非酒店报价；早餐、退改和实际房型另查。官网另提示周边施工，预订前需确认噪声影响与父母的出入需求。", "small")
dayOne = Stack([dayOneTitle, arrivalOne, gardenVisitOne, canalVisitOne], "column", "l")
dayOneTitle = Stack([dayOneTitle_part1, dayOneTitle_part2], "column", "xs")
dayOneTitle_part1 = MarkDownRenderer("## Day 01｜园林与平江水巷")
dayOneTitle_part2 = TextContent("11 月 21 日 · 上午抵达，午后赏园，傍晚临河休息。", "small")
arrivalOne = Stack([arrivalOne_part1, arrivalOne_part2], "column", "xs")
arrivalOne_part1 = InlineHeader("上午 · 抵达苏州", "车站 → 酒店寄存行李 → 午饭休息")
arrivalOne_part2 = TextContent("到站后优先打车前往酒店，安排午饭和休息，再开始逛园林。")
gardenVisitOne = Stack([gardenVisitOne_part1, gardenOne, gardenVisitOne_part3], "column", "s")
gardenVisitOne_part1 = InlineHeader("午后 · 拙政园", "约 60–90 分钟 · 以中部水院与亭廊为主")
gardenOne = Image("拙政园中花园池水与亭台实景，来源苏州市园林局", "https://ylj.suzhou.gov.cn/szdoc/szsylj/uploadfile/bg5naimiu1e.jpg")
gardenVisitOne_part3 = TextContent("不必走遍全园。建议提前按游玩日期核对实名预约时段，遇到台阶和拥挤处放慢节奏。")
canalVisitOne = Stack([canalVisitOne_part1, canalOne, canalVisitOne_part3], "column", "s")
canalVisitOne_part1 = InlineHeader("傍晚 · 平江路", "沿河走一小段，找间茶馆坐坐")
canalOne = Image("苏州平江路傍晚河道、石桥、木船与临河街景", "https://news.2500sz.com/uploadfiles/202602/21/2026022109200146823428.jpg")
canalVisitOne_part3 = TextContent("平江路公共街区免费。照片展示的是临河街景；人多时不必走完全程，休息比打卡重要。")
dayTwo = Stack([dayTwoTitle, gardenVisitTwo, streetVisitTwo, returnTwo], "column", "l")
dayTwoTitle = Stack([dayTwoTitle_part1, dayTwoTitle_part2], "column", "xs")
dayTwoTitle_part1 = MarkDownRenderer("## Day 02｜留园与山塘旧街")
dayTwoTitle_part2 = TextContent("11 月 22 日 · 上午游园，午后短逛，15:00 前结束游览取行李。", "small")
gardenVisitTwo = Stack([gardenVisitTwo_part1, gardenTwo, gardenVisitTwo_part3], "column", "s")
gardenVisitTwo_part1 = InlineHeader("上午 · 留园", "约 60–90 分钟 · 冠云峰、窗景和回廊")
gardenTwo = Image("苏州留园冠云峰与园林庭院实景", "https://p1.itc.cn/q_70/images03/20211230/6d7f3cb169064fdf9c92c85896302271.jpeg")
gardenVisitTwo_part3 = TextContent("从酒店打车前往。把时间留给园林细节，累了就坐下休息。")
streetVisitTwo = Stack([streetVisitTwo_part1, oldStreet, streetVisitTwo_part3], "column", "s")
streetVisitTwo_part1 = InlineHeader("午后 · 山塘街", "临河短走 · 苏式点心")
oldStreet = Image("苏州山塘街白天游船、石拱桥和沿河街景实拍", "https://cdn-ak.f.st-hatena.com/images/fotolife/s/suzhoushenghuo/20240603/20240603112852.jpg")
streetVisitTwo_part3 = TextContent("公共街区免费，照片展示石桥和沿河风貌。走累了可以取消这一站，直接回酒店取行李。")
returnTwo = Stack([returnTwo_part1, returnTwo_part2], "column", "xs")
returnTwo_part1 = InlineHeader("傍晚前 · 返回上海", "取行李 → 前往车站 → 返程")
returnTwo_part2 = TextContent("演示返程为 16:30 发车；先到酒店取行李，再打车到苏州站，留足进站时间。")
locationMap = Stack([locationMap_part1, locationMap_part2, cityMap], "column", "s")
locationMap_part1 = MarkDownRenderer("## 一张地图｜看清两天为什么顺路")
locationMap_part2 = TextContent("第一天在古城东北片区，第二天转向古城西侧。景点之间建议打车或短距离步行；这张图只标位置，不虚构导航时长。", "small")
cityMap = Map([pGardenOne, pPingjiang, pGardenTwo, pShantang], "wgs84")
pGardenOne = MapPoint("拙政园", 31.32647, 120.62473, "https://ylj.suzhou.gov.cn/szdoc/szsylj/uploadfile/bg5naimiu1e.jpg", null, "Day 01 · 园林主站")
pPingjiang = MapPoint("平江路", 31.31493, 120.62969, "https://news.2500sz.com/uploadfiles/202602/21/2026022109200146823428.jpg", null, "Day 01 · 古城水巷")
pGardenTwo = MapPoint("留园", 31.31762, 120.58827, "https://p1.itc.cn/q_70/images03/20211230/6d7f3cb169064fdf9c92c85896302271.jpeg", null, "Day 02 · 园林主站")
pShantang = MapPoint("山塘街", 31.32010, 120.59745, "https://cdn-ak.f.st-hatena.com/images/fotolife/s/suzhoushenghuo/20240603/20240603112852.jpg", null, "Day 02 · 短段步行")
tickets = Stack([tickets_part1, tickets_part2, ticketCards, ticketNote], "column", "s")
tickets_part1 = MarkDownRenderer("## 门票与预约")
tickets_part2 = TextContent("平江路、山塘街公共街区免费；两座园林需单独核对门票和入园时段。")
ticketCards = Stack([ticketGardenOne, ticketGardenTwo], "column", "s")
ticketGardenOne = Card([ticketGardenOne_image, ticketGardenOne_heading, ticketGardenOne_detail1, ticketGardenOne_spec, ticketGardenOne_footer], "card", "column", "s")
ticketGardenOne_image = Image("拙政园中花园池水与亭台实景，来源苏州市园林局", "https://ylj.suzhou.gov.cn/szdoc/szsylj/uploadfile/bg5naimiu1e.jpg")
ticketGardenOne_heading = CardHeader("拙政园")
ticketGardenOne_detail1 = TextContent("池水构成中部园景的核心，亭榭与树木沿水展开，呈现疏朗自然的江南园林格局。")
ticketGardenOne_spec = TextContent("成人票 · 11/21 下午计划入园 · 未预约", "small")
ticketGardenOne_footer = Stack([ticketGardenOne_price, ticketGardenOne_buttons], "row", "m", "center", "between")
ticketGardenOne_price = BoldText("number", "¥70", "成人 / 张 · 淡季公示价", "text", "lg")
ticketGardenOne_buttons = Buttons([Button("查看官方票价", @OpenUrl("https://ylj.suzhou.gov.cn/szsylj/mpjg/wztt.shtml"), "primary", "normal", "small")], "row")
ticketGardenTwo = Card([ticketGardenTwo_image, ticketGardenTwo_heading, ticketGardenTwo_detail1, ticketGardenTwo_spec, ticketGardenTwo_footer], "card", "column", "s")
ticketGardenTwo_image = Image("留园冠云峰和园林庭院", "https://p1.itc.cn/q_70/images03/20211230/6d7f3cb169064fdf9c92c85896302271.jpeg")
ticketGardenTwo_heading = CardHeader("留园")
ticketGardenTwo_detail1 = TextContent("以厅堂庭院、曲廊和湖石见长；冠云峰与漏窗相互借景，庭院空间层层变化。")
ticketGardenTwo_spec = TextContent("成人票 · 11/22 上午计划入园 · 未预约", "small")
ticketGardenTwo_footer = Stack([ticketGardenTwo_price, ticketGardenTwo_buttons], "row", "m", "center", "between")
ticketGardenTwo_price = BoldText("number", "¥45", "成人 / 张 · 淡季公示价", "text", "lg")
ticketGardenTwo_buttons = Buttons([Button("查看官方票价", @OpenUrl("https://ylj.suzhou.gov.cn/szsylj/mpjg/wztt.shtml"), "primary", "normal", "small")], "row")
ticketNote = TextContent("11 月按淡季公示价展示；旺季（4、5、7—10 月）分别为 ¥80、¥55。父母年龄优惠与预约场次另行核对，不直接按 3 张成人票计总价。按钮打开官方价格公示，不代表可订库存。", "small")
finish = Card([finish_part1, finish_part2, finish_part3], "card", "column", "m")
finish_part1 = CardHeader("出发前，确认这三件事")
finish_part2 = Stack([departureChecklist], "column", "s")
departureChecklist = CheckBoxGroup("出行准备", [departureChecklist_part1, departureChecklist_part2, departureChecklist_part3])
departureChecklist_part1 = CheckBoxItem("确认实际出行日期与车次", "示例按 11/21–22 安排，真实出行需重新查询。", "日期", false)
departureChecklist_part2 = CheckBoxItem("同行人的房间安排", "确认人数、房间数、床型及退改条件。", "房间", false)
departureChecklist_part3 = CheckBoxItem("两座园林的预约时段", "按实际游玩日期核对拙政园和留园的可约场次。", "园林预约", false)
finish_part3 = TextContent("如果父母当天体力一般，宁可去掉一段老街，也不要把整趟旅行变成赶路。", "small")
```

## Case 08 · 北京—曼谷 · 交通报价

```openui-lang
root = Stack([intro, sameDayTitle, sameDayOptions, alternatives, sourceNote], "column", "l")
intro = Stack([intro_part1, intro_part2], "column", "s")
intro_part1 = MarkDownRenderer("# 北京飞曼谷，先按同一天比较")
intro_part2 = TextContent("同为 11 月 21 日出发、1 位成人、单程经济舱，先看直飞与同机场中转的取舍。以下两条为演示数据，并非实时航班；时间均为机场当地时间。")
sameDayTitle = MarkDownRenderer("## 同日比较 · 演示方案")
sameDayOptions = Stack([demoDirect, demoTransfer], "column", "m")
demoDirect = Card([demoDirectHeading, demoDirectSpec, demoDirectJourney, demoDirectDetail, demoDirectFare], "card", "column", "s")
demoDirectHeading = CardHeader("北京大兴 → 曼谷素万那普")
demoDirectSpec = TextContent("2026/11/21 · 1 位成人 · 单程经济舱 · 演示 A", "small")
demoDirectJourney = Stack([demoDirectDeparture, demoDirectMiddle, demoDirectArrival], "row", "s", "start", "between")
demoDirectDeparture = BoldText("number", "10:00", "北京大兴", "text", "lg")
demoDirectMiddle = Card([demoDirectMiddleContent], "clear", "column", "none")
demoDirectMiddleContent = Stack([demoDirectDurationRow, demoDirectLine, demoDirectModeRow], "column", "xs", "stretch")
demoDirectDurationRow = Stack([demoDirectDuration], "row", "none", "center", "center")
demoDirectDuration = Text("text", "5小时5分", null, null, "sm")
demoDirectLine = Separator("horizontal")
demoDirectModeRow = Stack([demoDirectMode], "row", "none", "center", "center")
demoDirectMode = Text("text", "直飞", null, null, "sm")
demoDirectArrival = BoldText("number", "14:05", "曼谷素万那普", "text", "lg")
demoDirectDetail = TextContent("当日抵达。中国 UTC+8，泰国 UTC+7；演示报价含税，无真实航班号或库存。", "small")
demoDirectFare = Stack([demoDirectPrice, demoDirectActions], "row", "m", "center", "between")
demoDirectPrice = BoldText("number", "¥950", "每人含税 · 演示价", "text", "lg")
demoDirectActions = Buttons([Button("查询此路线", @ToAssistant("请重新查询 2026-11-21 北京大兴到曼谷素万那普的直飞，1 位成人、单程经济舱；不要将示例金额当作实时价格。"), "primary", "normal", "small")], "row")
demoTransfer = Card([demoTransferHeading, demoTransferSpec, demoTransferJourney, demoTransferDetail, demoTransferFare], "card", "column", "s")
demoTransferHeading = CardHeader("北京大兴 → 曼谷素万那普")
demoTransferSpec = TextContent("2026/11/21 · 1 位成人 · 单程经济舱 · 演示 B", "small")
demoTransferJourney = Stack([demoTransferDeparture, demoTransferMiddle, demoTransferArrival], "row", "s", "start", "between")
demoTransferDeparture = BoldText("number", "09:00", "北京大兴", "text", "lg")
demoTransferMiddle = Card([demoTransferMiddleContent], "clear", "column", "none")
demoTransferMiddleContent = Stack([demoTransferDurationRow, demoTransferLine, demoTransferModeRow], "column", "xs", "stretch")
demoTransferDurationRow = Stack([demoTransferDuration], "row", "none", "center", "center")
demoTransferDuration = Text("text", "8 小时", null, null, "sm")
demoTransferLine = Separator("horizontal")
demoTransferModeRow = Stack([demoTransferMode], "row", "none", "center", "center")
demoTransferMode = Text("text", "1 次中转", null, null, "sm")
demoTransferArrival = BoldText("number", "16:00", "曼谷素万那普", "text", "lg")
demoTransferDetail = TextContent("上海浦东同机场中转：11:00 抵达、13:00 出发，衔接 2 小时；当日抵达曼谷。演示报价含税，行李直挂与退改未设定。", "small")
demoTransferFare = Stack([demoTransferPrice, demoTransferActions], "row", "m", "center", "between")
demoTransferPrice = BoldText("number", "¥820", "每人含税 · 演示价", "text", "lg")
demoTransferActions = Buttons([Button("查询此路线", @ToAssistant("请重新查询 2026-11-21 北京大兴到曼谷素万那普经上海浦东中转的方案，1 位成人、单程经济舱，并核对行李和中转条件。不要沿用 mock 价格。"), "primary", "normal", "small")], "row")

alternatives = Stack([alternatives_part1, alternativesNote, directCard, transferCard, alternativeAcard, alternativeBcard], "column", "m")
alternatives_part1 = MarkDownRenderer("## 灵活日期 · 历史报价")
alternativesNote = TextContent("以下保留原示例 11/18、11/22、11/26、11/27 的记录，不能用跨日期价差推断直飞或中转更划算。", "small")
directCard = Card([directHeader, directJourney, directConnection, directFare], "card", "column", "m")
directHeader = CardHeader(null, "2026-11-27 · 泰国越捷航空 · VZ3719 · 经济舱")
directJourney = Stack([directDeparture, directDuration, directArrival], "row", "s", "start", "between")
directDeparture = BoldText("number", "23:45", "北京大兴", "text", "lg")
directDuration = Card([directDuration_part1], "clear", "column", "none")
directDuration_part1 = Stack([directDuration_part1_part1, directDuration_part1_part2, directDuration_part1_part3], "column", "xs", "stretch")
directDuration_part1_part1 = Stack([directDuration_part1_part1_part1], "row", "none", "center", "center")
directDuration_part1_part1_part1 = Text("text", "5小时5分", null, null, "sm")
directDuration_part1_part2 = Separator("horizontal")
directDuration_part1_part3 = Stack([directDuration_part1_part3_part1], "row", "none", "center", "center")
directDuration_part1_part3_part1 = Text("text", "直飞", null, null, "sm")
directArrival = BoldText("number", "03:50", "曼谷素万那普", "text", "lg")
directConnection = TextContent("11/28 凌晨抵达；确认住宿能否衔接实际到达时间。", "small")
directFare = Stack([directFare_part1, directFare_part2], "row", "m", "center", "between")
directFare_part1 = BoldText("number", "¥729", "每人 · 单程经济舱", "text", "lg")
directFare_part2 = Buttons([directFare_part2_part1], "row")
directFare_part2_part1 = Button("查看航班", @OpenUrl(directUrl), "primary", "normal", "small")
transferCard = Card([transferHeader, transferJourney, transferConnection, transferFare], "card", "column", "m")
transferHeader = CardHeader(null, "2026-11-26 · 东航 · MU6641 · 经济舱")
transferJourney = Stack([transferDeparture, transferDuration, transferArrival], "row", "s", "start", "between")
transferDeparture = BoldText("number", "07:25", "北京大兴", "text", "lg")
transferDuration = Card([transferDuration_part1], "clear", "column", "none")
transferDuration_part1 = Stack([transferDuration_part1_part1, transferDuration_part1_part2, transferDuration_part1_part3], "column", "xs", "stretch")
transferDuration_part1_part1 = Stack([transferDuration_part1_part1_part1], "row", "none", "center", "center")
transferDuration_part1_part1_part1 = Text("text", "10小时50分", null, null, "sm")
transferDuration_part1_part2 = Separator("horizontal")
transferDuration_part1_part3 = Stack([transferDuration_part1_part3_part1], "row", "none", "center", "center")
transferDuration_part1_part3_part1 = Text("text", "1 次中转", null, null, "sm")
transferArrival = BoldText("number", "17:15", "曼谷素万那普", "text", "lg")
transferConnection = TextContent("**需换机场**：10:35 抵达成都双流，15:05 从成都天府出发；确认跨机场接驳与行李安排。", "small")
transferFare = Stack([transferFare_part1, transferFare_part2], "row", "m", "center", "between")
transferFare_part1 = BoldText("number", "¥721", "每人 · 单程经济舱", "text", "lg")
transferFare_part2 = Buttons([transferFare_part2_part1], "row")
transferFare_part2_part1 = Button("查看航班", @OpenUrl(transferUrl), "primary", "normal", "small")
alternativeAcard = Card([alternativeAHeader, alternativeAJourney, alternativeAConnection, alternativeAFare], "card", "column", "m")
alternativeAHeader = CardHeader(null, "2026-11-18 · 泰国越捷航空 · VZ3719 · 经济舱")
alternativeAJourney = Stack([alternativeADeparture, alternativeADuration, alternativeAArrival], "row", "s", "start", "between")
alternativeADeparture = BoldText("number", "23:45", "北京大兴", "text", "lg")
alternativeADuration = Card([alternativeADuration_part1], "clear", "column", "none")
alternativeADuration_part1 = Stack([alternativeADuration_part1_part1, alternativeADuration_part1_part2, alternativeADuration_part1_part3], "column", "xs", "stretch")
alternativeADuration_part1_part1 = Stack([alternativeADuration_part1_part1_part1], "row", "none", "center", "center")
alternativeADuration_part1_part1_part1 = Text("text", "5小时5分", null, null, "sm")
alternativeADuration_part1_part2 = Separator("horizontal")
alternativeADuration_part1_part3 = Stack([alternativeADuration_part1_part3_part1], "row", "none", "center", "center")
alternativeADuration_part1_part3_part1 = Text("text", "直飞", null, null, "sm")
alternativeAArrival = BoldText("number", "03:50", "曼谷素万那普", "text", "lg")
alternativeAConnection = TextContent("11/19 凌晨抵达；确认住宿能否衔接实际到达时间。", "small")
alternativeAFare = Stack([alternativeAFare_part1, alternativeAFare_part2], "row", "m", "center", "between")
alternativeAFare_part1 = BoldText("number", "¥791", "每人 · 单程经济舱", "text", "lg")
alternativeAFare_part2 = Buttons([alternativeAFare_part2_part1], "row")
alternativeAFare_part2_part1 = Button("查看航班", @OpenUrl(alternativeAUrl), "primary", "normal", "small")
alternativeBcard = Card([alternativeBHeader, alternativeBJourney, alternativeBConnection, alternativeBFare], "card", "column", "m")
alternativeBHeader = CardHeader(null, "2026-11-22 · 泰国越捷航空 · VZ3719 · 经济舱")
alternativeBJourney = Stack([alternativeBDeparture, alternativeBDuration, alternativeBArrival], "row", "s", "start", "between")
alternativeBDeparture = BoldText("number", "23:45", "北京大兴", "text", "lg")
alternativeBDuration = Card([alternativeBDuration_part1], "clear", "column", "none")
alternativeBDuration_part1 = Stack([alternativeBDuration_part1_part1, alternativeBDuration_part1_part2, alternativeBDuration_part1_part3], "column", "xs", "stretch")
alternativeBDuration_part1_part1 = Stack([alternativeBDuration_part1_part1_part1], "row", "none", "center", "center")
alternativeBDuration_part1_part1_part1 = Text("text", "5小时5分", null, null, "sm")
alternativeBDuration_part1_part2 = Separator("horizontal")
alternativeBDuration_part1_part3 = Stack([alternativeBDuration_part1_part3_part1], "row", "none", "center", "center")
alternativeBDuration_part1_part3_part1 = Text("text", "直飞", null, null, "sm")
alternativeBArrival = BoldText("number", "03:50", "曼谷素万那普", "text", "lg")
alternativeBConnection = TextContent("11/23 凌晨抵达；确认住宿能否衔接实际到达时间。", "small")
alternativeBFare = Stack([alternativeBFare_part1, alternativeBFare_part2], "row", "m", "center", "between")
alternativeBFare_part1 = BoldText("number", "¥791", "每人 · 单程经济舱", "text", "lg")
alternativeBFare_part2 = Buttons([alternativeBFare_part2_part1], "row")
alternativeBFare_part2_part1 = Button("查看航班", @OpenUrl(alternativeBUrl), "primary", "normal", "small")
sourceNote = TextContent("上方同日比较为 mock；灵活日期组沿用 2026-11-10 的历史示例报价。历史链接只对应各卡所列日期，行李、退改、库存及结算金额以重新查询为准。", "small")
directUrl = "https://outfliggys.m.taobao.com/app/trip/rx-iflight-eco/pages/ota?priceType=total&tripType=1&searchSegments=%5B%7B%22arrAirportCode%22%3A%22BKK%22%2C%22arrCityCode%22%3A%22BKK%22%2C%22depAirportCode%22%3A%22PKX%22%2C%22depCityCode%22%3A%22BJS%22%2C%22depDate%22%3A%222026-11-27%22%7D%5D&selectedSegments=%5B%7B%22arrAirportCode%22%3A%22BKK%22%2C%22arrCityCode%22%3A%22BKK%22%2C%22depAirportCode%22%3A%22PKX%22%2C%22depCityCode%22%3A%22BJS%22%2C%22depDate%22%3A%222026-11-27%2023%3A45%3A00%22%2C%22journeySeq%22%3A1%2C%22marketingFlightNo%22%3A%22VZ3719%22%7D%5D&depCityCode=BJS&arrCityCode=BKK&depCityName=%E5%8C%97%E4%BA%AC&arrCityName=%E6%9B%BC%E8%B0%B7&leaveDate=2026-11-27&aiAction=jump_url&pcOtaMode=1&pcTripType=0&pcLeaveFlightNo=VZ3719&fpt=flp%28729%29flap%28129%29ai2c(sk.clawhub)&spm=181.45774641.traffic.3&_pc_redirect=true"
transferUrl = "https://outfliggys.m.taobao.com/app/trip/rx-iflight-eco/pages/ota?priceType=total&tripType=1&searchSegments=%5B%7B%22arrAirportCode%22%3A%22BKK%22%2C%22arrCityCode%22%3A%22BKK%22%2C%22depAirportCode%22%3A%22PKX%22%2C%22depCityCode%22%3A%22BJS%22%2C%22depDate%22%3A%222026-11-26%22%7D%5D&selectedSegments=%5B%7B%22arrAirportCode%22%3A%22CTU%22%2C%22arrCityCode%22%3A%22CTU%22%2C%22depAirportCode%22%3A%22PKX%22%2C%22depCityCode%22%3A%22BJS%22%2C%22depDate%22%3A%222026-11-26%2007%3A25%3A00%22%2C%22journeySeq%22%3A1%2C%22marketingFlightNo%22%3A%22MU6641%22%7D%2C%7B%22arrAirportCode%22%3A%22BKK%22%2C%22arrCityCode%22%3A%22BKK%22%2C%22depAirportCode%22%3A%22TFU%22%2C%22depCityCode%22%3A%22CTU%22%2C%22depDate%22%3A%222026-11-26%2015%3A05%3A00%22%2C%22journeySeq%22%3A1%2C%22marketingFlightNo%22%3A%22MU5035%22%7D%5D&depCityCode=BJS&arrCityCode=BKK&depCityName=%E5%8C%97%E4%BA%AC&arrCityName=%E6%9B%BC%E8%B0%B7&leaveDate=2026-11-26&aiAction=jump_url&pcOtaMode=1&pcTripType=0&pcLeaveFlightNo=MU6641%2CMU5035&fpt=flp%28721%29flap%28202%29ai2c(sk.clawhub)&spm=181.45774641.traffic.2&_pc_redirect=true"
alternativeAUrl = "https://outfliggys.m.taobao.com/app/trip/rx-iflight-eco/pages/ota?priceType=total&tripType=1&searchSegments=%5B%7B%22arrAirportCode%22%3A%22BKK%22%2C%22arrCityCode%22%3A%22BKK%22%2C%22depAirportCode%22%3A%22PKX%22%2C%22depCityCode%22%3A%22BJS%22%2C%22depDate%22%3A%222026-11-18%22%7D%5D&selectedSegments=%5B%7B%22arrAirportCode%22%3A%22BKK%22%2C%22arrCityCode%22%3A%22BKK%22%2C%22depAirportCode%22%3A%22PKX%22%2C%22depCityCode%22%3A%22BJS%22%2C%22depDate%22%3A%222026-11-18%2023%3A45%3A00%22%2C%22journeySeq%22%3A1%2C%22marketingFlightNo%22%3A%22VZ3719%22%7D%5D&depCityCode=BJS&arrCityCode=BKK&depCityName=%E5%8C%97%E4%BA%AC&arrCityName=%E6%9B%BC%E8%B0%B7&leaveDate=2026-11-18&aiAction=jump_url&pcOtaMode=1&pcTripType=0&pcLeaveFlightNo=VZ3719&fpt=flp%28791%29flap%28191%29ai2c(sk.clawhub)&spm=181.45774641.traffic.6&_pc_redirect=true"
alternativeBUrl = "https://outfliggys.m.taobao.com/app/trip/rx-iflight-eco/pages/ota?priceType=total&tripType=1&searchSegments=%5B%7B%22arrAirportCode%22%3A%22BKK%22%2C%22arrCityCode%22%3A%22BKK%22%2C%22depAirportCode%22%3A%22PKX%22%2C%22depCityCode%22%3A%22BJS%22%2C%22depDate%22%3A%222026-11-22%22%7D%5D&selectedSegments=%5B%7B%22arrAirportCode%22%3A%22BKK%22%2C%22arrCityCode%22%3A%22BKK%22%2C%22depAirportCode%22%3A%22PKX%22%2C%22depCityCode%22%3A%22BJS%22%2C%22depDate%22%3A%222026-11-22%2023%3A45%3A00%22%2C%22journeySeq%22%3A1%2C%22marketingFlightNo%22%3A%22VZ3719%22%7D%5D&depCityCode=BJS&arrCityCode=BKK&depCityName=%E5%8C%97%E4%BA%AC&arrCityName=%E6%9B%BC%E8%B0%B7&leaveDate=2026-11-22&aiAction=jump_url&pcOtaMode=1&pcTripType=0&pcLeaveFlightNo=VZ3719&fpt=flp%28791%29flap%28191%29ai2c(sk.clawhub)&spm=181.45774641.traffic.7&_pc_redirect=true"
```
