import Foundation
import OpenUISwiftUI

/// Authored personal-agent tasks. Data, copy and purchase demonstrations belong
/// to the review app; every page uses the public SDK and ordinary OpenUI Lang.
enum ReviewScenePrograms {
  static var ids: [String] { ReviewCatalog.scenarios.flatMap(\.variants).map(\.id) }

  static func program(_ id: String, english: Bool = false) -> ReviewProgram? {
    func t(_ zh: String, _ en: String) -> String { english ? en : zh }
    func q(_ zh: String, _ en: String) -> String {
      let data = try! JSONSerialization.data(withJSONObject: [t(zh, en)], options: [.withoutEscapingSlashes])
      return String(String(data: data, encoding: .utf8)!.dropFirst().dropLast())
    }
    let title: String
    let source: String
    let sources: [CardSource]
    switch id {
    case "scene-day-trip":
      title = t("规划一次一日游", "A day in Paris")
      source = """
        $afternoon="walk"
        $place="louvre"
        activity=$afternoon=="cruise"?90:60
        total=80+20+40+activity
        root=Stack([
          TextContent(\(q("巴黎，把一天过得刚刚好", "Paris, a day with room to breathe")),"large-heavy"),
          TextContent(\(q("上午看艺术，下午走进左岸，傍晚回到塞纳河。两个人，不赶场。", "Art in the morning, the Left Bank after lunch and the Seine toward evening. A day for two, without rushing."))),
          ContextCardBlock([
            ContextCardItem("feature",\(q("从卢浮宫开始", "Begin at the Louvre")),\(q("先选想看的展厅，把午餐和沿途发现也留进行程。", "Pick a few galleries, then leave time for lunch and the city between stops.")),null,"/paris-louvre.jpg",\(q("从卢浮宫开始", "Begin at the Louvre")))
          ]),
          TagBlock([
            \(q("11 月 5 日 · 周四", "Thursday 5 November")),
            \(q("2 位成人", "2 adults")),
            \(q("步行 + 公共交通", "Walking + transit"))
          ],"sm"),
          InlineHeader(\(q("一天的节奏", "Your day, at a glance"))),
          Steps([
            StepsItem("09:30–12:00",\(q("卢浮宫：选两三个重点展厅，提前到入口。", "The Louvre: choose two or three galleries and allow time at the entrance."))),
            StepsItem("12:00–13:30",\(q("午餐与杜乐丽花园：参观结束后先休息。", "Lunch and the Tuileries: take a proper break after the museum."))),
            StepsItem("13:30–16:00",\(q("圣日耳曼：过河逛书店，在咖啡馆坐一会儿。", "Saint-Germain: cross the river for bookshops and a café."))),
            StepsItem("16:30–18:00",$afternoon=="cruise"?\(q("塞纳河游船：预留到码头、候船与登船时间。", "Seine cruise: allow time to reach the pier, queue and board.")):\(q("塞纳河步行：走到喜欢的地方就停，不再增加远处景点。", "A Seine walk: stop where you like, without adding another distant sight.")))
          ]),
          InlineHeader(\(q("下午，留一点选择", "Leave a choice for the afternoon"))),
          Buttons([
            Button(\(q("沿河散步", "Walk by the Seine")),@Set($afternoon,"walk"),"secondary"),
            Button(\(q("换成游船", "Take a river cruise")),@Set($afternoon,"cruise"),"secondary")
          ]),
          Map([
            {id:"louvre",title:\(q("卢浮宫", "The Louvre")),lat:48.8606,lng:2.3376,imageSrc:"/paris-louvre.jpg",subtitle:\(q("艺术与宫殿", "Art and a royal palace")),icon:"building.columns"},
            {id:"germain",title:\(q("圣日耳曼", "Saint-Germain")),lat:48.8539,lng:2.3332,imageSrc:"/paris-cafe.jpg",subtitle:\(q("咖啡馆与左岸散步", "Cafés and Left Bank walks")),icon:"cup.and.saucer"}
          ],[],$place,"regular","wgs84"),
          InlineHeader(\(q("当天预算", "Budget for two")),\(q("均为示例分配，非门票报价", "Illustrative allocations, not ticket quotations"))),
          TextContent("€"+total,"large-heavy"),
          Table([
            Col(\(q("项目", "Item")),[
              \(q("午餐与咖啡", "Lunch and coffee")),
              \(q("市内交通", "Local transport")),
              \(q("参观与体验", "Visits and activities")),
              \(q("机动余量", "Flexibility"))
            ]),
            Col(\(q("两人合计 €", "Total for two €")),[
              80,
              20,
              activity,
              40
            ])
          ]),
          Card([
            CardHeader(\(q("参观与体验预订", "Visits and activities")),\(q("按当前选择打包预览；示例商品", "Preview the current selection; demonstration offer"))),
            TextContent("€"+activity,"small-heavy"),
            Buttons([
              Button(\(q("预览预订", "Preview booking")),@ToAssistant(\(q("预览购买：当天参观与体验", "Preview purchase: Day visits and activities")),{reviewPurchase:true,item:\(q("当天参观与体验", "Day visits and activities")),price:"€"+activity}),"primary")
            ])
          ]),
          TextContent(\(q("不含住宿和往返巴黎的交通。地图仅标地点；时段是建议安排，未计算实时交通。卢浮宫参观信息见下方。", "Excludes accommodation and travel to Paris. Map markers are locations, not live routing; timings are suggestions. See Louvre visitor information below.")),"small"),
          ListBlock([
            ListItem(\(q("卢浮宫 · 预约与开放信息", "Louvre · time slots and opening")),\(q("www.louvre.fr", "www.louvre.fr")),null,null,@OpenUrl("https://www.louvre.fr/en/visit")),
            ListItem(\(q("左岸街区指南", "Left Bank walking guide")),\(q("parisjetaime.com", "parisjetaime.com")),null,null,@OpenUrl("https://parisjetaime.com/eng/article/a-walk-in-saint-germain-des-pres-a925"))
          ])
        ],"column","l")
        """
      sources = [
        .init(url: "https://www.louvre.fr/en/visit", title: t("卢浮宫参观信息", "Louvre visitor information"), sourceName: "Louvre"),
        .init(url: "https://parisjetaime.com/eng/article/a-walk-in-saint-germain-des-pres-a925", title: t("左岸步行指南", "Left Bank walking guide"), sourceName: "Paris je t’aime"),
      ]
    case "scene-two-day-trip":
      title = t("规划一次两日游", "Two days, one night")
      source = """
        $stay="central"
        $flight="early"
        hotel=$stay=="central"?220:160
        flights=$flight=="early"?320:380
        total=hotel+flights+160+80+100+60
        root=Stack([
          TextContent(\(q("巴黎，两天一晚", "Paris, two days and one night")),"large-heavy"),
          TextContent(\(q("从伦敦出发，两位成人。上午抵达、次日傍晚返程，把有限的时间留给艺术、街区和河岸。", "From London for two adults. Arrive in the morning and return the following evening, leaving time for art, neighborhoods and the river."))),
          TagBlock([
            \(q("11 月 5–6 日", "5–6 November")),
            \(q("2 天 · 1 晚", "2 days · 1 night")),
            \(q("报价均为演示数据", "All quotes are illustrative"))
          ],"sm"),
          Tabs([
            TabItem("day1",\(q("第一天 · 艺术与左岸", "Day 1 · Art and the Left Bank")),[
              ImageBlock("/paris-louvre.jpg",\(q("第一天下午 · 卢浮宫", "Day 1 afternoon · the Louvre"))),
              Steps([
                StepsItem("08:00–11:30",\(q("出发、飞行与市区接驳。中午先到酒店寄存行李。", "Departure, flight and city transfer. Leave your bags at the hotel before lunch."))),
                StepsItem("14:00–17:00",\(q("卢浮宫与杜乐丽花园：预约下午时段，不安排跨城往返。", "Louvre and Tuileries: an afternoon entry, with no cross-city detour."))),
                StepsItem("18:00–20:00",\(q("圣日耳曼晚餐与散步，回酒店休息。", "Dinner and a walk in Saint-Germain, then back to the hotel.")))
              ])
            ]),
            TabItem("day2",\(q("第二天 · 地标与河岸", "Day 2 · Landmarks and the Seine")),[
              ImageBlock("/paris-eiffel.jpg",\(q("第二天 · 埃菲尔铁塔一带", "Day 2 · around the Eiffel Tower"))),
              Steps([
                StepsItem("09:00–11:30",\(q("退房寄存行李，再去铁塔周边与河岸；登塔需另行安排预约。", "Check out and store your bags, then visit the tower area and riverbank. An ascent needs a separate booking."))),
                StepsItem("12:00–14:30",\(q("午餐与左岸闲逛，14:30 前取回行李。", "Lunch and a Left Bank walk; collect your bags by 14:30."))),
                StepsItem("15:00–20:00",\(q("前往机场，给值机和安检留出余量；傍晚航班返程。", "Transfer to the airport with check-in and security time before the evening return flight.")))
              ])
            ])
          ]),
          InlineHeader(\(q("往返交通", "Return travel"))),
          Card([
            CardHeader(\(q("伦敦 ⇄ 巴黎 · 两人往返机票", "London ⇄ Paris · return flights for two")),\(q("11 月 5 日上午抵达 / 6 日傍晚返程", "Morning arrival on 5 Nov / evening return on 6 Nov"))),
            Buttons([
              Button(\(q("基础票 · €320", "Basic · €320")),@Set($flight,"early"),"secondary"),
              Button(\(q("含托运行李 · €380", "With checked bags · €380")),@Set($flight,"baggage"),"secondary")
            ]),
            TextContent("€"+flights,"small-heavy"),
            TextContent(\(q("两种方案使用相同示例时段，区别在行李；机场接驳另列。无真实航班、余票或承运人。", "Both options use the same illustrative timings and differ by baggage. Airport transfers are separate. No live flight, inventory or carrier is represented.")),"small"),
            Buttons([
              Button(\(q("预览机票", "Preview flights")),@ToAssistant(\(q("预览购买：两人往返机票", "Preview purchase: Return flights for two")),{reviewPurchase:true,item:\(q("两人往返机票", "Return flights for two")),price:"€"+flights}),"primary")
            ])
          ]),
          InlineHeader(\(q("住一晚，比较位置与总价", "One night: compare location and total price"))),
          Table([
            Col(\(q("住宿方案", "Stay")),[
              \(q("A · 中心区", "A · central")),
              \(q("B · 外围近交通站", "B · near outer transit"))
            ]),
            Col(\(q("一晚 €", "One night €")),[
              220,
              160
            ]),
            Col(\(q("取舍", "Trade-off")),[
              \(q("步行衔接，少折返", "Walking connections, fewer detours")),
              \(q("节省 €60，进城更久", "Save €60, longer city access"))
            ])
          ]),
          Card([
            CardHeader(\(q("一间双人房 · 一晚", "One double room · one night")),\(q("11 月 5 日入住，6 日退房；虚构住宿方案", "Check in 5 Nov, out 6 Nov; fictional stays"))),
            Buttons([
              Button(\(q("选择中心区", "Choose central")),@Set($stay,"central"),"secondary"),
              Button(\(q("选择外围", "Choose outer transit")),@Set($stay,"outer"),"secondary")
            ]),
            TextContent("€"+hotel,"small-heavy"),
            TextContent($stay=="central"?\(q("当前方案：取行李后直达机场接驳点，市区步行衔接。", "Current plan: walk between central stops, then collect bags before the airport transfer.")):\(q("当前方案：每天多留出进出市区时间，第二天提前结束街区散步。", "Current plan: allow extra city-access time each day and shorten the second afternoon walk."))),
            Buttons([
              Button(\(q("预览住宿", "Preview stay")),@ToAssistant(\(q("预览购买：双人房一晚", "Preview purchase: Double room for one night")),{reviewPurchase:true,item:\(q("双人房一晚", "Double room for one night")),price:"€"+hotel}),"primary")
            ])
          ]),
          InlineHeader(\(q("把两天放在一张地图上", "Your two days on the map"))),
          Map([
            {id:"louvre",title:\(q("卢浮宫", "The Louvre")),lat:48.8606,lng:2.3376,imageSrc:"/paris-louvre.jpg",subtitle:\(q("艺术与宫殿", "Art and a royal palace")),icon:"building.columns"},
            {id:"germain",title:\(q("圣日耳曼", "Saint-Germain")),lat:48.8539,lng:2.3332,imageSrc:"/paris-cafe.jpg",subtitle:\(q("咖啡馆与左岸散步", "Cafés and Left Bank walks")),icon:"cup.and.saucer"},
            {id:"eiffel",title:\(q("埃菲尔铁塔", "Eiffel Tower")),lat:48.8584,lng:2.2945,imageSrc:"/paris-eiffel.jpg",subtitle:\(q("塞纳河与城市天际线", "The Seine and skyline")),icon:"mappin.and.ellipse"}
          ],[],null,"regular","wgs84"),
          InlineHeader(\(q("费用合计", "Trip total")),\(q("两人总额，随机票与住宿选择更新", "Total for two, updated by flight and stay choices"))),
          TextContent("€"+total,"large-heavy"),
          Table([
            Col(\(q("项目", "Item")),[
              \(q("机票", "Flights")),
              \(q("一晚住宿", "One-night stay")),
              \(q("餐饮", "Food")),
              \(q("机场与市内交通", "Airport and local transport")),
              \(q("参观预留", "Visits allowance")),
              \(q("机动余量", "Flexibility"))
            ]),
            Col(\(q("两人合计 €", "Total for two €")),[
              flights,
              hotel,
              160,
              80,
              100,
              60
            ])
          ]),
          Card([
            CardHeader(\(q("参观门票预留", "Visits allowance")),\(q("按实际预约选择场馆；这里不提供票价承诺", "Choose actual visits when booking; no ticket-price claim"))),
            MetricIndicatorInline("€100",\(q("两人预算上限", "budget cap for two"))),
            Buttons([
              Button(\(q("预览参观预约", "Preview visit booking")),@ToAssistant(\(q("预览购买：两人参观预约", "Preview purchase: Visits for two")),{reviewPurchase:true,item:\(q("两人参观预约", "Visits for two")),price:"€100"}),"primary")
            ])
          ]),
          ListBlock([
            ListItem(\(q("卢浮宫 · 参观与预约", "Louvre · visiting and booking")),\(q("www.louvre.fr", "www.louvre.fr")),null,null,@OpenUrl("https://www.louvre.fr/en/visit")),
            ListItem(\(q("铁塔 · 登塔信息", "Eiffel Tower · visiting information")),\(q("www.toureiffel.paris", "www.toureiffel.paris")),null,null,@OpenUrl("https://www.toureiffel.paris/en"))
          ])
        ],"column","l")
        """
      sources = [
        .init(url: "https://www.louvre.fr/en/visit", title: t("卢浮宫参观信息", "Louvre visitor information"), sourceName: "Louvre"),
        .init(url: "https://www.toureiffel.paris/en", title: t("铁塔官方信息", "Eiffel Tower information"), sourceName: "Tour Eiffel"),
      ]
    case "scene-shopping":
      title = t("选购一台旅行相机", "Choose a travel camera")
      source = """
        $kit="light"
        camera=$kit=="light"?5200:6800
        extras=$kit=="light"?400:600
        total=camera+extras
        root=Stack([
          TextContent(\(q("旅行相机，先选愿意随身带的", "A travel camera you will actually carry")),"large-heavy"),
          TextContent(\(q("预算 ¥7,500，以街景、人像和日常记录为主。建议先选轻量套装，把余量留给电池、存储卡和出门拍摄。", "A ¥7,500 budget for streets, portraits and everyday memories. Start with the lighter kit and leave room for batteries, storage and getting out to shoot."))),
          TagBlock([
            \(q("两套虚构商品用于演示", "Two fictional demonstration kits")),
            \(q("所有金额均为人民币", "All amounts in CNY"))
          ],"sm"),
          InlineHeader(\(q("差异在这里", "The differences that matter"))),
          Table([
            Col(\(q("比较项", "Compare")),[
              \(q("套装价格", "Kit price")),
              \(q("随身重量", "Carry weight")),
              \(q("镜头配置", "Lens")),
              \(q("更适合", "Best suited to"))
            ]),
            Col(\(q("A · 轻装出发", "A · travel light")),[
              "¥5,200",
              \(q("约 480 g", "about 480 g")),
              \(q("小型标准变焦", "Compact standard zoom")),
              \(q("全天随身、城市漫步", "All-day carrying, city walks"))
            ]),
            Col(\(q("B · 人像进阶", "B · portraits")),[
              "¥6,800",
              \(q("约 720 g", "about 720 g")),
              \(q("大光圈定焦", "Fast prime")),
              \(q("人像与弱光拍摄", "Portraits and lower light"))
            ])
          ]),
          Card([
            Stack([
              Icon("camera"),
              TextContent(\(q("A · 轻装出发套装", "A · travel-light kit")),"small-heavy")
            ],"row","s"),
            TextContent(\(q("¥5,200", "¥5,200")),"large-heavy"),
            TextContent(\(q("轻便机身与小型变焦镜头。旅途中少换镜头，拿起来就能拍。", "A light body and compact zoom. Fewer lens changes and less to carry."))),
            Buttons([
              Button(\(q("纳入预算", "Use in budget")),@Set($kit,"light"),"secondary"),
              Button(\(q("购买套装 A", "Buy kit A")),@ToAssistant(\(q("预览购买：轻装出发相机套装", "Preview purchase: Travel-light camera kit")),{reviewPurchase:true,item:\(q("轻装出发相机套装", "Travel-light camera kit")),price:"¥5,200"}),"primary")
            ])
          ]),
          Card([
            Stack([
              Icon("camera"),
              TextContent(\(q("B · 人像进阶套装", "B · portrait kit")),"small-heavy")
            ],"row","s"),
            TextContent(\(q("¥6,800", "¥6,800")),"large-heavy"),
            TextContent(\(q("更偏向人像与夜晚街景。接受多带一些重量，也需要适应用脚步调整取景。", "For portraits and evening streets. More to carry, with framing adjusted by moving rather than zooming."))),
            Buttons([
              Button(\(q("纳入预算", "Use in budget")),@Set($kit,"portrait"),"secondary"),
              Button(\(q("购买套装 B", "Buy kit B")),@ToAssistant(\(q("预览购买：人像进阶相机套装", "Preview purchase: Portrait camera kit")),{reviewPurchase:true,item:\(q("人像进阶相机套装", "Portrait camera kit")),price:"¥6,800"}),"primary")
            ])
          ]),
          InlineHeader(\(q("把配件也算进去", "Include the essentials"))),
          TextContent("¥"+total,"large-heavy"),
          Table([
            Col(\(q("预算项", "Budget item")),[
              \(q("相机套装", "Camera kit")),
              \(q("电池与存储卡预留", "Battery and storage allowance")),
              \(q("预算剩余", "Budget remaining"))
            ]),
            Col(\(q("金额 ¥", "CNY")),[
              camera,
              extras,
              7500-total
            ])
          ]),
          Card([
            CardHeader(\(q("配件组合", "Accessory bundle")),\(q("按当前套装匹配的演示预算", "Illustrative allocation for the selected kit"))),
            TextContent("¥"+extras,"small-heavy"),
            Buttons([
              Button(\(q("购买配件", "Buy accessories")),@ToAssistant(\(q("预览购买：备用电池与存储卡", "Preview purchase: Spare battery and storage")),{reviewPurchase:true,item:\(q("备用电池与存储卡", "Spare battery and storage")),price:"¥"+extras}),"primary")
            ])
          ]),
          TextCallout("neutral",\(q("我的建议", "My recommendation")),\(q("优先 A。只有当你明确更常拍人像、愿意带更重的设备时，再为 B 多花预算。实际购买前确认握持、镜头兼容与保修。", "Start with A. Choose B when portraits matter enough to justify its extra weight and cost. Before a real purchase, check handling, lens compatibility and warranty."))),
          TextContent(\(q("产品、规格和价格均为虚构数据，用于展示比较与购买动作；不是品牌评测或实时报价。", "Products, specifications and prices are fictional, illustrating comparisons and purchase actions; this is not a brand review or live quotation.")),"small")
        ],"column","l")
        """
      sources = [
      ]
    case "scene-spending":
      title = t("分析消费与预算", "Understand spending")
      source = """
        $period="october"
        food=$period=="quarter"?4800:1800
        transport=$period=="quarter"?1500:600
        home=$period=="quarter"?9000:3000
        other=$period=="quarter"?2700:1200
        total=food+transport+home+other
        root=Stack([
          TextContent(\(q("花费增加，主要不在房租", "Spending rose, but rent stayed flat")),"large-heavy"),
          TextContent(\(q("这份示例账单里，10 月比 9 月多花 ¥800：餐饮增加 ¥300、其他消费增加 ¥300、交通增加 ¥200。先调整前两项，不必把所有日常开销一起压缩。", "In this sample ledger, October rose ¥800 over September: food and other spending rose ¥300 each, and transport rose ¥200. Start with the first two rather than cutting every part of daily life."))),
          TextContent(\(q("虚构账单 · 2026 年 8–10 月 · 不包含收入、资产或负债", "Synthetic ledger · August–October 2026 · excludes income, assets and debt")),"small"),
          InlineHeader(\(q("三个月的变化", "Three months in view")),\(q("点选数据查看分类金额", "Tap a point to inspect category amounts"))),
          BarChart([
            \(q("8 月", "Aug")),
            \(q("9 月", "Sep")),
            \(q("10 月", "Oct"))
          ],[
            Series(\(q("住房", "Home")),[3000, 3000, 3000]),
            Series(\(q("餐饮", "Food")),[1500, 1500, 1800]),
            Series(\(q("交通", "Transport")),[500, 400, 600]),
            Series(\(q("其他", "Other")),[600, 900, 1200])
          ],"stacked"),
          Buttons([
            Button(\(q("看 10 月", "October")),@Set($period,"october"),"secondary"),
            Button(\(q("看三个月合计", "Three-month total")),@Set($period,"quarter"),"secondary")
          ]),
          TextContent("¥"+total,"large-heavy"),
          PieChart([
            \(q("住房", "Home")),
            \(q("餐饮", "Food")),
            \(q("交通", "Transport")),
            \(q("其他", "Other"))
          ],[home,food,transport,other],"donut"),
          Table([
            Col(\(q("分类", "Category")),[
              \(q("住房", "Home")),
              \(q("餐饮", "Food")),
              \(q("交通", "Transport")),
              \(q("其他", "Other"))
            ]),
            Col(\(q("当前范围 ¥", "Selected range CNY")),[
              home,
              food,
              transport,
              other
            ])
          ]),
          InlineHeader(\(q("把变化落实到记录", "A closer look at the ledger"))),
          Table([
            Col(\(q("日期", "Date")),[
              "10-08",
              "10-12",
              "10-19"
            ]),
            Col(\(q("记录", "Record")),[
              \(q("朋友聚餐", "Dinner with friends")),
              \(q("出行打车", "Taxi journey")),
              \(q("家居用品", "Home supplies"))
            ]),
            Col(\(q("金额 ¥", "CNY")),[
              280,
              86,
              320
            ])
          ]),
          TextContent(\(q("以上为 10 月记录节选，不等于当月全部交易；切换范围不会改变原始记录。", "These are selected October transactions, not a full-month reconciliation. Range selection does not change the underlying records.")),"small"),
          InlineHeader(\(q("11 月，先试一份 ¥6,000 的计划", "Try a ¥6,000 plan for November"))),
          Table([
            Col(\(q("分类", "Category")),[
              \(q("住房", "Home")),
              \(q("餐饮", "Food")),
              \(q("交通", "Transport")),
              \(q("其他", "Other"))
            ]),
            Col(\(q("10 月实际 ¥", "October actual CNY")),[
              3000,
              1800,
              600,
              1200
            ]),
            Col(\(q("11 月计划 ¥", "November plan CNY")),[
              3000,
              1500,
              500,
              1000
            ])
          ]),
          TextCallout("neutral",\(q("比 10 月少 ¥600", "¥600 below October")),\(q("餐饮少 ¥300，交通少 ¥100，其他少 ¥200。先保留住房预算，月底再根据实际情况调整。", "Reduce food by ¥300, transport by ¥100 and other spending by ¥200. Keep the housing allocation and review against actual spending at month-end."))),
          TextContent(\(q("本页使用虚构账单，不连接银行账户，也不发起扣款。", "This page uses a synthetic ledger. It does not connect to a bank account or initiate payments.")),"small")
        ],"column","l")
        """
      sources = [
      ]
    case "scene-gathering":
      title = t("组织一次朋友聚会", "Plan an evening with friends")
      source = """
        $venue="studio"
        space=$venue=="studio"?480:720
        food=720
        extras=120
        total=space+food+extras
        perPerson=total/6
        root=Stack([
          TextContent(\(q("六个人，一个不用赶场的周六", "Six friends, one unhurried Saturday")),"large-heavy"),
          TextContent(\(q("11 月 7 日，17:00–21:00。晚餐、聊天和桌游放在同一处，预算控制在每人 ¥260 以内。", "7 November, 17:00–21:00. Dinner, conversation and board games in one place, within ¥260 per person."))),
          ContextCardBlock([
            ContextCardItem("feature",\(q("先吃饭，再慢慢聊", "Dinner first, conversation after")),\(q("六个人共享一桌，活动只安排一个。留出自然聊天的时间，不把聚会排成任务清单。", "One shared table and one activity. Leave room for conversation rather than filling the evening with a checklist.")),null,"/paris-breakfast.jpg",\(q("先吃饭，再慢慢聊", "Dinner first, conversation after")))
          ]),
          TextContent(\(q("场地与套餐为虚构示例；照片仅作氛围参考，不代表实际商家。", "Venues and packages are fictional; imagery sets the mood and does not identify a real vendor.")),"small"),
          InlineHeader(\(q("先选一个舒服的地方", "Choose a place to settle in"))),
          Table([
            Col(\(q("场地", "Venue")),[
              \(q("A · 共享工作室", "A · shared studio")),
              \(q("B · 独立包间", "B · private room"))
            ]),
            Col(\(q("场地费 ¥", "Venue CNY")),[
              480,
              720
            ]),
            Col(\(q("主要取舍", "Trade-off")),[
              \(q("有大桌，自备餐食", "Large table; bring food")),
              \(q("更私密，场地费高 ¥240", "More private; ¥240 more"))
            ])
          ]),
          Card([
            CardHeader(\(q("四小时场地 · 六人", "Four-hour space · six guests")),\(q("周六 17:00–21:00；交通位置预订前确认", "Saturday 17:00–21:00; confirm access before booking"))),
            Buttons([
              Button(\(q("选共享工作室", "Shared studio")),@Set($venue,"studio"),"secondary"),
              Button(\(q("选独立包间", "Private room")),@Set($venue,"private"),"secondary")
            ]),
            TextContent("¥"+space,"small-heavy"),
            Buttons([
              Button(\(q("预览场地预订", "Preview venue booking")),@ToAssistant(\(q("预览购买：聚会场地四小时", "Preview purchase: Four-hour gathering venue")),{reviewPurchase:true,item:\(q("聚会场地四小时", "Four-hour gathering venue")),price:"¥"+space}),"primary")
            ])
          ]),
          InlineHeader(\(q("晚上的安排", "How the evening unfolds"))),
          Steps([
            StepsItem("17:00–17:30",\(q("到场、放东西、布置餐桌。第一位到的人负责与场地交接。", "Arrive and set the table. The first guest handles the venue handover."))),
            StepsItem("17:30–19:00",\(q("共享晚餐。素食与过敏需求提前单独确认。", "Shared dinner. Confirm vegetarian needs and allergies in advance."))),
            StepsItem("19:00–20:30",\(q("桌游或聊天，想休息的人不必参与每一轮。", "Board games or conversation, with room to sit out a round."))),
            StepsItem("20:30–21:00",\(q("收拾、分装剩余食物，确认物品带齐后离开。", "Tidy up, pack leftovers and check belongings before leaving.")))
          ]),
          Card([
            CardHeader(\(q("六人共享晚餐", "Shared dinner for six")),\(q("主食、蔬菜、蛋白质与无酒精饮品；示例套餐", "Mains, vegetables, protein and soft drinks; sample package"))),
            TextContent(\(q("¥720", "¥720")),"small-heavy"),
            Buttons([
              Button(\(q("预览餐食下单", "Preview food order")),@ToAssistant(\(q("预览购买：六人共享晚餐", "Preview purchase: Shared dinner for six")),{reviewPurchase:true,item:\(q("六人共享晚餐", "Shared dinner for six")),price:"¥720"}),"primary")
            ])
          ]),
          InlineHeader(\(q("选完方案，费用一起更新", "Costs follow your venue choice"))),
          TextContent("¥"+total,"large-heavy"),
          TextContent("¥"+perPerson+\(q(" / 人", " per person")),"small-heavy"),
          Table([
            Col(\(q("费用", "Cost")),[
              \(q("场地", "Venue")),
              \(q("晚餐", "Dinner")),
              \(q("耗材与机动余量", "Supplies and flexibility"))
            ]),
            Col(\(q("合计 ¥", "Total CNY")),[
              space,
              720,
              120
            ])
          ]),
          TextCallout("neutral",\(q("出发前，确认三件事", "Three things to confirm")),\(q("人数是否变动；是否有过敏或饮食禁忌；场地是否允许外带餐食，以及最晚离场时间。", "Guest count; allergies or dietary requirements; whether outside food is allowed and when the venue must be vacated.")))
        ],"column","l")
        """
      sources = [
      ]
    case "scene-learning":
      title = t("图文学习一段历史", "Learn through objects")
      source = """
        root=Stack([
          TextContent(\(q("一块玉，为什么能讲出一个时代？", "What can a piece of jade tell us?")),"large-heavy"),
          TextContent(\(q("从良渚玉琮开始，看形制、工艺与社会，再分清我们知道什么、还有什么不能确定。", "Begin with a Liangzhu cong: its form, workmanship and social setting, then separate evidence from what remains uncertain."))),
          ImageBlock("/liangzhu-cong.jpg",\(q("良渚文化玉琮，约公元前 2400 年；大都会艺术博物馆，2004.52", "Liangzhu jade cong, about 2400 BCE; The Met, 2004.52"))),
          TextContent(\(q("图 1 · 这件玉琮属于新石器时代良渚文化。器身外方内圆，转角处有抽象面纹。[1]", "Fig. 1 · A Neolithic Liangzhu cong. Its squared exterior encloses a round tube; abstract masks mark the corners.[1]")),"small"),
          InlineHeader(\(q("先看形状，再问用途", "Look at the form, then ask about its use"))),
          TextContent(\(q("把目光沿着转角向下移动：重复的纹饰让器物有了节奏。钻孔、打磨与抛光都需要投入工时，这种投入帮助我们理解它为什么珍贵。", "Follow the corners down the object and notice the repeated motifs. Boring, grinding and polishing required substantial labor: part of the reason such objects mattered."))),
          ListBlock([
            ListItem(\(q("轮廓：外方内圆", "Form: squared outside, round within")),\(q("先辨认器形；不要仅凭这个形状，就断言史前人有某套确定的宇宙观。", "Identify the form before attaching a definite prehistoric cosmology to it.")),null,null,null),
            ListItem(\(q("证据：工艺与出土环境", "Evidence: craft and archaeological context")),\(q("精细加工与墓葬环境支持身份、地位或仪式用途的解释；具体意义仍有不确定性。[1][3]", "Workmanship and burial contexts support interpretations involving status or ritual, while precise meanings remain uncertain.[1][3]")),null,null,null)
          ]),
          InlineHeader(\(q("琮与璧，放在一起看", "Compare a cong and a bi"))),
          ListBlock([
            ListItem(\(q("玉琮 · 方形器身中的圆孔", "Cong · a round bore in a squared body")),\(q("约公元前 2400 年，高 25.4 cm。先看转角与层叠的纹饰。[1]", "About 2400 BCE, 25.4 cm high. Notice the corners and repeated motifs.[1]")),{src:"/liangzhu-cong.jpg",alt:\(q("玉琮 · 方形器身中的圆孔", "Cong · a round bore in a squared body"))},null,@OpenUrl("https://www.metmuseum.org/art/collection/search/72376")),
            ListItem(\(q("玉璧 · 带孔的圆盘", "Bi · a disk with a central opening")),\(q("公元前三千纪中叶，直径约 15.6 cm。形式与玉琮不同，不能直接当作同一种器物。[2]", "Mid-third millennium BCE, about 15.6 cm across. Its disk form differs from a cong.[2]")),{src:"/liangzhu-bi.jpg",alt:\(q("玉璧 · 带孔的圆盘", "Bi · a disk with a central opening"))},null,@OpenUrl("https://www.metmuseum.org/art/collection/search/49371"))
          ],"image"),
          Table([
            Col(\(q("观察轴", "Look for")),[
              \(q("外形", "Form")),
              \(q("工艺", "Workmanship")),
              \(q("解释边界", "Limits of interpretation"))
            ]),
            Col(\(q("玉琮", "Cong")),[
              \(q("方形外壁、圆孔", "Squared walls, round bore")),
              \(q("钻孔、纹饰与抛光", "Boring, carving and polishing")),
              \(q("常与身份、仪式联系", "Often linked to status or ritual"))
            ]),
            Col(\(q("玉璧", "Bi")),[
              \(q("扁平圆盘、中央孔", "Flat disk, central hole")),
              \(q("切割、研磨与抛光", "Cutting, grinding and polishing")),
              \(q("具体用途仍需结合出土证据", "Specific uses require context"))
            ])
          ]),
          InlineHeader(\(q("一个容易看错的地方", "An easy mistake to make"))),
          ImageBlock("/object.jpg",\(q("清代仿古玉琮；大都会艺术博物馆，21.175.114", "Qing-dynasty archaistic jade cong; The Met, 21.175.114"))),
          TextContent(\(q("这件也是“琮”，但它是清代仿古玉器，不是良渚出土物。相似的形制可以跨越数千年；认年代，要看记录和考古信息。[4]", "This is also a cong, but it is a Qing-dynasty archaistic object, not a Liangzhu find. Similar forms can span millennia: dating needs collection and archaeological evidence.[4]"))),
          Separator(),
          InlineHeader(\(q("现在，试着自己解释", "Try explaining it yourself"))),
          TextContent(\(q("如果看到一件没有标签的玉琮，哪些能靠眼睛观察，哪些必须查资料才能判断？", "If you encountered an unlabeled cong, what could you observe directly, and what would require research?"))),
          TextContent(\(q("能观察：形状、纹饰与表面痕迹。需查证：年代、出土地、材质鉴定与具体用途。把观察和推断分开，比背一个结论更重要。", "Observable: form, decoration and surface marks. To research: date, findspot, material identification and use. Separate observation from inference."))),
          InlineHeader(\(q("资料与图片出处", "Sources and image credits"))),
          ListBlock([
            ListItem(\(q("[1] 良渚玉琮 · 馆藏记录", "[1] Liangzhu cong · collection record")),\(q("www.metmuseum.org", "www.metmuseum.org")),null,null,@OpenUrl("https://www.metmuseum.org/art/collection/search/72376")),
            ListItem(\(q("[2] 良渚玉璧 · 馆藏记录", "[2] Liangzhu bi · collection record")),\(q("www.metmuseum.org", "www.metmuseum.org")),null,null,@OpenUrl("https://www.metmuseum.org/art/collection/search/49371")),
            ListItem(\(q("[3] 良渚文化 · 研究介绍", "[3] The Liangzhu culture · research introduction")),\(q("asia-archive.si.edu", "asia-archive.si.edu")),null,null,@OpenUrl("https://asia-archive.si.edu/learn/ancient-chinese-jades/the-liangzhu-culture/")),
            ListItem(\(q("[4] 清代仿古玉琮 · 馆藏记录", "[4] Qing archaistic cong · collection record")),\(q("www.metmuseum.org", "www.metmuseum.org")),null,null,@OpenUrl("https://www.metmuseum.org/art/collection/search/42751"))
          ]),
          TextContent(\(q("根据馆方网页整理的固定讲解范例，不是现场搜索结果。图片为馆方开放获取资料；精确来源见记录。", "An authored explanation based on museum webpages, not a live search response. Images are museum Open Access assets; precise sources are recorded.")),"small")
        ],"column","l")
        """
      sources = [
        .init(url: "https://www.metmuseum.org/art/collection/search/72376", title: t("良渚玉琮", "Liangzhu cong"), sourceName: "The Met"),
        .init(url: "https://www.metmuseum.org/art/collection/search/49371", title: t("良渚玉璧", "Liangzhu bi"), sourceName: "The Met"),
        .init(url: "https://asia-archive.si.edu/learn/ancient-chinese-jades/the-liangzhu-culture/", title: t("良渚文化", "The Liangzhu culture"), sourceName: "Smithsonian"),
        .init(url: "https://www.metmuseum.org/art/collection/search/42751", title: t("清代仿古玉琮", "Qing archaistic cong"), sourceName: "The Met"),
      ]
    default: return nil
    }
    return ReviewProgram(id: id, title: title, source: source, sources: sources)
  }
}
