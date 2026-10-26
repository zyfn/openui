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
    let request: String
    let source: String
    let sources: [CardSource]
    switch id {
    case "scene-day-trip":
      title = t("规划一次一日游", "One day in Paris")
      request = t("11 月 5 日我们两个人在巴黎玩一天。想轻松一点，看看艺术、逛街区，也帮我安排吃饭、交通和预算。", "We have one day in Paris on 5 November. Plan an unhurried day for two adults with art, a neighborhood walk, places to eat, transport and a clear budget.")
      source = """
        $place="louvre"
        activity=64+36
        total=80+20+40+activity
        root=Stack([
          TextContent(\(q("巴黎，一天也能从容", "Paris, at your own pace")),"large-heavy"),
          TextContent(\(q("2026 年 11 月 5 日 · 2 位成人 · 示例预算", "5 November 2026 · 2 adults · sample budget")),"small"),
          TextContent(\(q("上午看艺术，午后逛左岸，傍晚到铁塔附近乘船；把参观和休息串成一条路线。", "Art in the morning, the Left Bank after lunch, then a cruise near the tower. Keep time for breaks between visits."))),
          InlineHeader(\(q("值得停留的三个地方", "Three places worth your time"))),
          Card([
                Image(\(q("卢浮宫", "The Louvre")),"/paris-louvre.jpg"),
                Stack([
                  TextContent(\(q("卢浮宫", "The Louvre")),"small-heavy"),
                  TagBlock([\(q("艺术 · 建议 2–3 小时", "Art · allow 2–3 hours"))],"sm"),
                  TextContent(\(q("先看重点展厅，不追求一次走完。按非 EEA 成人票预算，优惠资格另核。", "Choose a few galleries. Budget uses the non-EEA adult rate; check discount eligibility.")),"small"),
                  Stack([BoldText("number","€64",\(q("€32 × 2 位成人", "€32 × 2 adults")),"text","lg"),Buttons([Button(\(q("预订门票", "Book tickets")),@ToAssistant(\(q("预览预订：卢浮宫", "Preview booking: The Louvre")),{reviewPurchase:true,item:\(q("卢浮宫", "The Louvre")),price:"€64"}),"primary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"card","row","m","stretch","start",false),
          Card([
                Image(\(q("圣日耳曼街区", "Saint-Germain-des-Prés")),"/paris-cafe.jpg"),
                Stack([
                  TextContent(\(q("圣日耳曼街区", "Saint-Germain-des-Prés")),"small-heavy"),
                  TagBlock([\(q("街区散步 · 建议 1–2 小时", "Neighborhood walk · 1–2 hours"))],"sm"),
                  TextContent(\(q("过河逛书店和街巷，午餐与咖啡另计。公共街区无需门票预约。", "Explore bookshops and side streets. Food is separate; no admission booking is needed.")),"small"),
                  Stack([BoldText("number","€0",\(q("公共街区免费", "Free public streets")),"text","lg"),Buttons([Button(\(q("安排参观", "Plan visit")),@ToAssistant(\(q("安排参观：圣日耳曼街区", "Plan visit: Saint-Germain-des-Prés")),{reviewPurchase:false,item:\(q("圣日耳曼街区", "Saint-Germain-des-Prés")),price:"€0"}),"primary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"card","row","m","stretch","start",false),
          Card([
                Image(\(q("塞纳河观光游船", "Seine sightseeing cruise")),"/paris-eiffel.jpg"),
                Stack([
                  TextContent(\(q("塞纳河观光游船", "Seine sightseeing cruise")),"small-heavy"),
                  TagBlock([\(q("Bateaux Parisiens · 约 1 小时", "Bateaux Parisiens · about 1 hour"))],"sm"),
                  TextContent(\(q("从铁塔附近码头登船，看河岸地标。按官网网络票价预算，班次与库存待确认。", "Board near the Eiffel Tower. Budget uses the published online fare; confirm departures and availability.")),"small"),
                  Stack([BoldText("number","€36",\(q("€18 × 2 位成人", "€18 × 2 adults")),"text","lg"),Buttons([Button(\(q("预订门票", "Book tickets")),@ToAssistant(\(q("预览预订：塞纳河观光游船", "Preview booking: Seine sightseeing cruise")),{reviewPurchase:true,item:\(q("塞纳河观光游船", "Seine sightseeing cruise")),price:"€36"}),"primary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"card","row","m","stretch","start",false),
          TextCallout("neutral",\(q("衔接建议", "Getting between stops")),\(q("卢浮宫后在市中心午餐，再步行到圣日耳曼。去游船码头安排公共交通，抵达后再按实际班次登船。", "Have lunch after the Louvre, then walk to Saint-Germain. Use public transport to reach the cruise pier and confirm the next departure."))),
          InlineHeader(\(q("路线，一眼看清", "Get your bearings"))),
          Map([
            {id:"louvre",title:\(q("卢浮宫", "The Louvre")),lat:48.8606,lng:2.3376,imageSrc:"/paris-louvre.jpg",subtitle:\(q("艺术与宫殿", "Art and a royal palace")),icon:"building.columns"},
            {id:"germain",title:\(q("圣日耳曼", "Saint-Germain")),lat:48.8539,lng:2.3332,imageSrc:"/paris-cafe.jpg",subtitle:\(q("咖啡馆与左岸散步", "Cafés and Left Bank walks")),icon:"cup.and.saucer"}
          ],[],$place,"regular","wgs84"),
          InlineHeader(\(q("这一天，预算怎么分", "Where the day’s budget goes"))),
          Stack([
            BoldText("number","€"+total,\(q("两人当天合计", "total for two")),"text","lg"),
            TextContent(\(q("含 €40 机动余量", "Includes €40 flexibility")),"small")
          ],"row","s","center","between",true),
          PieChart([
            \(q("餐饮", "Food")),
            \(q("交通", "Transport")),
            \(q("体验", "Activities")),
            \(q("余量", "Flexibility"))
          ],[
            80,
            20,
            activity,
            40
          ],"donut"),
          EntityList([
            {left:\(q("午餐与咖啡", "Lunch and coffee")),right:"€80",rightVariant:"number"},
            {left:\(q("市内交通", "Local transport")),right:"€20",rightVariant:"number"},
            {left:\(q("参观与体验", "Visits and activities")),right:"€"+activity,rightVariant:"number"},
            {left:\(q("机动余量", "Flexibility")),right:"€40",rightVariant:"number"}
          ],"small"),
          TextContent(\(q("门票按 2026-10-26 官网价计算，适用资格与时段须确认；餐饮交通为估算，不含住宿和往返交通。按钮仅演示预约，不实际下单。", "Ticket rates checked on 26 Oct 2026; confirm eligibility and availability. Food and transport are estimates. Accommodation and travel to Paris are excluded. Buttons preview bookings only.")),"small")
        ],"column","l")
        """
      sources = [
        .init(url: "https://www.louvre.fr/en/visit", title: t("卢浮宫参观信息", "Louvre visitor information"), sourceName: "Louvre"),
        .init(url: "https://parisjetaime.com/eng/article/a-walk-in-saint-germain-des-pres-a925", title: t("左岸步行指南", "Left Bank walking guide"), sourceName: "Paris je t’aime"),
      ]
    case "scene-two-day-trip":
      title = t("规划一次两日游", "Two days in Paris")
      request = t("帮两位成人安排 11 月 5 日从伦敦出发、6 日返回的巴黎两天一晚。包含机票、酒店对比、每天的行程和总预算。", "Plan two days and one night in Paris for two adults, leaving London on 5 November and returning on 6 November. Include flights, a hotel comparison, a daily itinerary and a total budget.")
      source = """
        $stay="central"
        hotel=$stay=="central"?220:160
        outbound=150
        inbound=170
        flights=outbound+inbound
        visits=64+47+36
        total=hotel+flights+160+80+visits+60
        root=Stack([
          TextContent(\(q("巴黎，两天一晚", "Paris, two days and one night")),"large-heavy"),
          TextContent(\(q("5–6 Nov 2026 · 2 位成人 · 1 晚 · 示例报价", "5–6 Nov 2026 · 2 adults · 1 night · sample offers")),"small"),
          TextContent(\(q("第一天以卢浮宫和左岸为主；第二天集中在铁塔与塞纳河，下午留给返程。", "Spend day one at the Louvre and on the Left Bank. Keep day two around the tower and Seine, leaving the afternoon for your flight."))),
          InlineHeader(\(q("按天看景点", "Places to visit each day"))),
          Tabs([
            TabItem("day1",\(q("第一天 · 艺术与左岸", "Day 1 · Art and the Left Bank")),[
              TextContent(\(q("抵达后先寄存行李、午餐，再预约下午的卢浮宫时段。晚餐放在左岸。", "Store your bags and have lunch after arrival, then choose an afternoon Louvre slot. Stay on the Left Bank for dinner.")),"small"),
              Card([
                Image(\(q("卢浮宫", "The Louvre")),"/paris-louvre.jpg"),
                Stack([
                  TextContent(\(q("卢浮宫", "The Louvre")),"small-heavy"),
                  TagBlock([\(q("艺术 · 建议 2–3 小时", "Art · allow 2–3 hours"))],"sm"),
                  TextContent(\(q("先看重点展厅，不追求一次走完。按非 EEA 成人票预算，优惠资格另核。", "Choose a few galleries. Budget uses the non-EEA adult rate; check discount eligibility.")),"small"),
                  Stack([BoldText("number","€64",\(q("€32 × 2 位成人", "€32 × 2 adults")),"text","lg"),Buttons([Button(\(q("预订门票", "Book tickets")),@ToAssistant(\(q("预览预订：卢浮宫", "Preview booking: The Louvre")),{reviewPurchase:true,item:\(q("卢浮宫", "The Louvre")),price:"€64"}),"primary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"card","row","m","stretch","start",false),
              Card([
                Image(\(q("圣日耳曼街区", "Saint-Germain-des-Prés")),"/paris-cafe.jpg"),
                Stack([
                  TextContent(\(q("圣日耳曼街区", "Saint-Germain-des-Prés")),"small-heavy"),
                  TagBlock([\(q("街区散步 · 建议 1–2 小时", "Neighborhood walk · 1–2 hours"))],"sm"),
                  TextContent(\(q("过河逛书店和街巷，午餐与咖啡另计。公共街区无需门票预约。", "Explore bookshops and side streets. Food is separate; no admission booking is needed.")),"small"),
                  Stack([BoldText("number","€0",\(q("公共街区免费", "Free public streets")),"text","lg"),Buttons([Button(\(q("安排参观", "Plan visit")),@ToAssistant(\(q("安排参观：圣日耳曼街区", "Plan visit: Saint-Germain-des-Prés")),{reviewPurchase:false,item:\(q("圣日耳曼街区", "Saint-Germain-des-Prés")),price:"€0"}),"primary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"card","row","m","stretch","start",false)
            ]),
            TabItem("day2",\(q("第二天 · 铁塔与塞纳河", "Day 2 · Tower and Seine")),[
              Card([
                Image(\(q("埃菲尔铁塔 · 二层", "Eiffel Tower · second floor")),"/paris-eiffel.jpg"),
                Stack([
                  TextContent(\(q("埃菲尔铁塔 · 二层", "Eiffel Tower · second floor")),"small-heavy"),
                  TagBlock([\(q("电梯登塔 · 建议 1.5–2 小时", "By elevator · allow 1.5–2 hours"))],"sm"),
                  TextContent(\(q("选择电梯到二层，不含顶层。按 25 岁以上成人票计算，预留安检时间。", "Elevator access to the second floor, not the summit. Rate is for adults over 24; allow time for security.")),"small"),
                  Stack([BoldText("number","€47",\(q("€23.50 × 2 位成人", "€23.50 × 2 adults")),"text","lg"),Buttons([Button(\(q("预订门票", "Book tickets")),@ToAssistant(\(q("预览预订：埃菲尔铁塔 · 二层", "Preview booking: Eiffel Tower · second floor")),{reviewPurchase:true,item:\(q("埃菲尔铁塔 · 二层", "Eiffel Tower · second floor")),price:"€47"}),"primary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"card","row","m","stretch","start",false),
              Card([
                Image(\(q("塞纳河观光游船", "Seine sightseeing cruise")),"/paris-eiffel.jpg"),
                Stack([
                  TextContent(\(q("塞纳河观光游船", "Seine sightseeing cruise")),"small-heavy"),
                  TagBlock([\(q("Bateaux Parisiens · 约 1 小时", "Bateaux Parisiens · about 1 hour"))],"sm"),
                  TextContent(\(q("从铁塔附近码头登船，看河岸地标。按官网网络票价预算，班次与库存待确认。", "Board near the Eiffel Tower. Budget uses the published online fare; confirm departures and availability.")),"small"),
                  Stack([BoldText("number","€36",\(q("€18 × 2 位成人", "€18 × 2 adults")),"text","lg"),Buttons([Button(\(q("预订门票", "Book tickets")),@ToAssistant(\(q("预览预订：塞纳河观光游船", "Preview booking: Seine sightseeing cruise")),{reviewPurchase:true,item:\(q("塞纳河观光游船", "Seine sightseeing cruise")),price:"€36"}),"primary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"card","row","m","stretch","start",false),
              TextCallout("neutral",\(q("18:30 返程，下午留给机场", "18:30 flight: keep the afternoon clear")),\(q("午餐后取行李，计划 15:00 前出发去机场；按实际航班与交通情况提前调整。", "Collect your bags after lunch and plan to leave for the airport by 15:00; adjust for the actual flight and traffic.")))
            ])
          ]),
          InlineHeader(\(q("往返航班示例", "Sample return flights"))),
          Card([
            Stack([
              TextContent(\(q("去程 · 伦敦 → 巴黎", "Outbound · London → Paris")),"small-heavy"),
              TextContent(\(q("11.05 周四", "Thu 5 Nov")),"small")
            ],"row","s","center","between",false),
            Stack([
              Stack([
                TextContent("08:00","large-heavy"),
                TextContent(\(q("希思罗", "Heathrow")),"small")
              ],"column","xs"),
              Stack([
                TextContent("1h20m","small"),
                Icon("arrow-right"),
                TextContent(\(q("直飞", "Nonstop")),"small")
              ],"column","xs","center"),
              Stack([
                TextContent("10:20","large-heavy"),
                TextContent(\(q("戴高乐", "Charles de Gaulle")),"small")
              ],"column","xs"),
              Stack([
                TextContent("€"+outbound,"large"),
                Buttons([Button(\(q("预订", "Book")),@ToAssistant(\(q("预览购买：去程 · 伦敦 → 巴黎机票", "Preview purchase: Outbound · London → Paris flight")),{reviewPurchase:true,item:\(q("去程 · 伦敦 → 巴黎机票", "Outbound · London → Paris flight")),price:"€"+outbound}),"primary",null,"small")])
              ],"column","xs")
            ],"row","s","center","between",false),
            TagBlock([\(q("2人单程", "One way · 2 adults")),\(q("含随身行李", "Cabin bag included"))],"sm")
          ],"card","column","s"),
          Card([
            Stack([
              TextContent(\(q("返程 · 巴黎 → 伦敦", "Return · Paris → London")),"small-heavy"),
              TextContent(\(q("11.06 周五", "Fri 6 Nov")),"small")
            ],"row","s","center","between",false),
            Stack([
              Stack([
                TextContent("18:30","large-heavy"),
                TextContent(\(q("戴高乐", "Charles de Gaulle")),"small")
              ],"column","xs"),
              Stack([
                TextContent("1h20m","small"),
                Icon("arrow-right"),
                TextContent(\(q("直飞", "Nonstop")),"small")
              ],"column","xs","center"),
              Stack([
                TextContent("18:50","large-heavy"),
                TextContent(\(q("希思罗", "Heathrow")),"small")
              ],"column","xs"),
              Stack([
                TextContent("€"+inbound,"large"),
                Buttons([Button(\(q("预订", "Book")),@ToAssistant(\(q("预览购买：返程 · 巴黎 → 伦敦机票", "Preview purchase: Return · Paris → London flight")),{reviewPurchase:true,item:\(q("返程 · 巴黎 → 伦敦机票", "Return · Paris → London flight")),price:"€"+inbound}),"primary",null,"small")])
              ],"column","xs")
            ],"row","s","center","between",false),
            TagBlock([\(q("2人单程", "One way · 2 adults")),\(q("含随身行李", "Cabin bag included"))],"sm")
          ],"card","column","s"),
          TextContent(\(q("起降均为当地时间，巴黎比伦敦快 1 小时；两段行程分别显示两人单程总价。", "Times are local, with Paris one hour ahead of London. Each leg shows a one-way total for two.")),"small"),
          InlineHeader(\(q("住一晚，选位置还是选余量", "A stay that suits your priorities"))),
          Card([
            Image(\(q("左岸 · 花园双人房", "Left Bank · garden double")),"/stay-central.jpg"),
            Stack([
              TextContent(\(q("左岸 · 花园双人房", "Left Bank · garden double")),"small-heavy"),
              TagBlock([\(q("花园景观", "Garden view")),\(q("含早餐", "Breakfast included"))],"sm"),
              TextContent(\(q("示例房源，适合以左岸为中心步行游览。", "Sample stay for a trip centered on the Left Bank.")),"small"),
              Stack([BoldText("number","€220",null,"text","lg"),Buttons([Button(\(q("预订", "Book")),Action([@Set($stay,"central"),@ToAssistant(\(q("预览购买：左岸双人房一晚 · 演示房源 A", "Preview purchase: Left Bank double · sample stay A")),{reviewPurchase:true,item:\(q("左岸双人房一晚 · 演示房源 A", "Left Bank double · sample stay A")),price:"€220"})]),"primary",null,"small")])],"row","s","center","between",false)
            ],"column","s","stretch","between",false)
          ],"card","row","m","stretch","start",false),
          Card([
            Image(\(q("近交通站 · 舒适双人房", "Transit-side · comfort double")),"/stay-transit.jpg"),
            Stack([
              TextContent(\(q("近交通站 · 舒适双人房", "Transit-side · comfort double")),"small-heavy"),
              TagBlock([\(q("城景房", "City view")),\(q("大床", "King bed"))],"sm"),
              TextContent(\(q("示例房源，住宿少花 €60，需安排市区接驳。", "Sample stay: save €60 and allow for city transfers.")),"small"),
              Stack([BoldText("number","€160",null,"text","lg"),Buttons([Button(\(q("预订", "Book")),Action([@Set($stay,"outer"),@ToAssistant(\(q("预览购买：近交通站双人房一晚 · 演示房源 B", "Preview purchase: Transit-side double · sample stay B")),{reviewPurchase:true,item:\(q("近交通站双人房一晚 · 演示房源 B", "Transit-side double · sample stay B")),price:"€160"})]),"primary",null,"small")])],"row","s","center","between",false)
            ],"column","s","stretch","between",false)
          ],"card","row","m","stretch","start",false),
          TextContent($stay=="central"?\(q("已选左岸方案：步行衔接，减少市区折返。", "Left Bank selected: walking connections and fewer detours.")):\(q("已选近交通站方案：省 €60，第二天提前结束市区散步。", "Transit-side selected: save €60 and finish the second afternoon walk earlier.")),"small"),
          InlineHeader(\(q("主要停留点", "Your anchor points"))),
          Map([
            {id:"louvre",title:\(q("卢浮宫", "The Louvre")),lat:48.8606,lng:2.3376,imageSrc:"/paris-louvre.jpg",subtitle:\(q("艺术与宫殿", "Art and a royal palace")),icon:"building.columns"},
            {id:"germain",title:\(q("圣日耳曼", "Saint-Germain")),lat:48.8539,lng:2.3332,imageSrc:"/paris-cafe.jpg",subtitle:\(q("咖啡馆与左岸散步", "Cafés and Left Bank walks")),icon:"cup.and.saucer"},
            {id:"eiffel",title:\(q("埃菲尔铁塔", "Eiffel Tower")),lat:48.8584,lng:2.2945,imageSrc:"/paris-eiffel.jpg",subtitle:\(q("塞纳河与城市天际线", "The Seine and skyline")),icon:"mappin.and.ellipse"}
          ],[],null,"regular","wgs84"),
          InlineHeader(\(q("一笔预算，看清全部", "The whole trip in one budget"))),
          Stack([
            BoldText("number","€"+total,\(q("两人旅行合计", "trip total for two")),"text","lg"),
            TextContent(\(q("随住宿方案更新", "Updates with your stay")),"small")
          ],"row","s","center","between",true),
          PieChart([
            \(q("机票", "Flights")),
            \(q("住宿", "Stay")),
            \(q("餐饮", "Food")),
            \(q("接驳与交通", "Transfers")),
            \(q("参观", "Visits")),
            \(q("余量", "Flexibility"))
          ],[
            flights,
            hotel,
            160,
            80,
            visits,
            60
          ],"donut"),
          EntityList([
            {left:\(q("往返机票", "Return flights")),right:"€"+flights,rightVariant:"number"},
            {left:\(q("一晚住宿", "One-night stay")),right:"€"+hotel,rightVariant:"number"},
            {left:\(q("餐饮", "Food")),right:"€160",rightVariant:"number"},
            {left:\(q("机场与市内交通", "Airport and local transport")),right:"€80",rightVariant:"number"},
            {left:\(q("景点门票", "Attraction tickets")),right:"€"+visits,rightVariant:"number"},
            {left:\(q("机动余量", "Flexibility")),right:"€60",rightVariant:"number"}
          ],"small"),
          TextContent(\(q("门票参考 2026-10-26 官网价；航班酒店为演示报价，餐饮交通为估算，照片为示意。按钮仅预览，不实际下单。", "Tickets use published rates checked on 26 Oct 2026. Flights and hotels are sample offers; food and transport are estimates. Photos are illustrative and buttons preview bookings only.")),"small")
        ],"column","l")
        """
      sources = [
        .init(url: "https://www.louvre.fr/en/visit", title: t("卢浮宫参观信息", "Louvre visitor information"), sourceName: "Louvre"),
        .init(url: "https://www.toureiffel.paris/en", title: t("铁塔官方信息", "Eiffel Tower information"), sourceName: "Tour Eiffel"),
      ]
    case "scene-shopping":
      title = t("选购一台旅行相机", "Choose a camera")
      request = t("想买一台轻便的旅行相机，主要拍街景和人像。总预算 7500 元，包含必要配件，帮我比较取舍并推荐。", "Help me choose a lightweight camera for travel, street photography and portraits. My total budget is ¥7,500, including the essentials. Compare the trade-offs and recommend a kit.")
      source = """
        $kit="light"
        camera=$kit=="light"?5200:6800
        extras=$kit=="light"?400:600
        total=camera+extras
        root=Stack([
          TextContent(\(q("把预算花在愿意带出门的相机上", "A camera worth taking with you")),"large-heavy"),
          TextContent(\(q("¥7,500 预算，主要拍街景、人像与旅行日常。我会先选轻量套装：少一点负担，才更可能随身带着。", "Start with the lighter kit: a standard zoom covers everyday travel and leaves room for the essentials."))),
          CompositeCardBlock([
            CompositeCardItem("light",
              ImageTextLarge("/camera-light.jpg",\(q("A · 轻装出发套装", "A · travel-light kit")),\(q("A · 轻装出发套装", "A · travel-light kit")),null,true),
              [TagBlock([\(q("优先推荐", "First choice")), \(q("少换镜头", "Fewer lens changes"))],"sm"),Text("text",\(q("轻量机身与标准变焦，适合全天随身。", "Light body and standard zoom for all-day carrying.")),null,"text","xs")],
              {price:BoldText("number","¥5,200",null,"text","lg"),button:Button(\(q("购买", "Buy")),Action([@Set($kit,"light"),@ToAssistant(\(q("预览购买：轻装出发相机套装", "Preview purchase: Travel-light camera kit")),{reviewPurchase:true,item:\(q("轻装出发相机套装", "Travel-light camera kit")),price:"¥5,200"})]),"primary",null,"small")}
            ),
            CompositeCardItem("portrait",
              ImageTextLarge("/camera-dark.jpg",\(q("B · 人像进阶套装", "B · portrait kit")),\(q("B · 人像进阶套装", "B · portrait kit")),null,true),
              [TagBlock([\(q("更重一些", "More to carry")), \(q("定焦取景", "Prime-lens framing"))],"sm"),Text("text",\(q("机身与大光圈定焦，偏向人像与夜景。", "Body and fast prime for portraits and evening scenes.")),null,"text","xs")],
              {price:BoldText("number","¥6,800",null,"text","lg"),button:Button(\(q("购买", "Buy")),Action([@Set($kit,"portrait"),@ToAssistant(\(q("预览购买：人像进阶相机套装", "Preview purchase: Portrait camera kit")),{reviewPurchase:true,item:\(q("人像进阶相机套装", "Portrait camera kit")),price:"¥6,800"})]),"primary",null,"small")}
            )
          ],"carousel",true),
          InlineHeader(\(q("不用比较每个参数，先看取舍", "Compare the trade-offs"))),
          Table([
            Col(\(q("你更在意", "Your priority")),[
              \(q("轻装与便利", "Lightness and convenience")),
              \(q("人像与弱光", "Portraits and low light")),
              \(q("初次使用", "Getting started"))
            ]),
            Col(\(q("A · 轻装", "A · light")),[
              \(q("更适合全天随身", "Better for carrying all day")),
              \(q("够用，保留预算", "An everyday starting point")),
              \(q("变焦更灵活", "Flexible zoom framing"))
            ]),
            Col(\(q("B · 人像", "B · portrait")),[
              \(q("需要接受额外重量", "Accept the extra weight")),
              \(q("值得为明确需求投入", "For a specific creative need")),
              \(q("需要适应定焦构图", "Learn to frame with a prime"))
            ])
          ]),
          InlineHeader(\(q("把必要配件也算进去", "Include the essentials"))),
          Stack([
            BoldText("number","¥"+total,\(q("相机与配件合计", "camera and essentials")),"text","lg"),
            TextContent("¥"+(7500-total)+\(q(" 预算余量", " remaining")),"small-heavy")
          ],"row","s","center","between",true),
          EntityList([
            {left:\(q("当前套装", "Selected kit")),right:"¥"+camera,rightVariant:"number"},
            {left:\(q("电池与存储卡预留", "Battery and storage allowance")),right:"¥"+extras,rightVariant:"number"}
          ],"small"),
          TextCallout("neutral",\(q("选 A，把余量留给出门拍摄", "Choose A and leave room to get out and shoot")),\(q("只有当你明确更常拍人像，并接受额外重量时，再选择 B。购买前亲手试握，核对镜头兼容与保修。", "Choose B when portraits are a clear priority and you accept the extra weight. Before buying, check handling, lens compatibility and warranty."))),
          TextContent(\(q("两套商品、规格与价格为虚构演示。器材照片仅作示意，不表示照片中的真实品牌或型号具有上述规格。配件为预算预留，不是独立报价。", "Fictional kits and prices. Stock photos do not identify the described models. Confirm lens compatibility, warranty and actual bundle contents.")),"small")
        ],"column","l")
        """
      sources = [
      ]
    case "scene-spending":
      title = t("分析消费与预算", "Spending review")
      request = t("帮我分析这份 8–10 月示例账单：住房每月 3000；餐饮分别 1500、1500、1800；交通 500、400、600；其他 600、900、1200。解释变化，再给下个月安排一份 6000 元预算。", "Review this sample spending ledger for August, September and October. Housing was ¥3,000 each month; food ¥1,500, ¥1,500, ¥1,800; transport ¥500, ¥400, ¥600; other spending ¥600, ¥900, ¥1,200. Explain the changes and propose a ¥6,000 budget for next month.")
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
      title = t("组织一次朋友聚会", "An evening together")
      request = t("11 月 7 日周六 17:00–21:00 想组织六个朋友聚会。比较一下场地，安排共享晚餐和晚上的活动，人均控制在 260 元以内。", "Organize a relaxed gathering for six friends on Saturday 7 November, from 17:00 to 21:00. Compare places, arrange a shared dinner and an evening plan, and keep the cost within ¥260 per person.")
      source = """
        $venue="studio"
        space=$venue=="studio"?480:720
        food=720
        extras=120
        total=space+food+extras
        perPerson=total/6
        root=Stack([
          TextContent(\(q("六个人，围着一张桌子", "Six friends around one table")),"large-heavy"),
          TextContent(\(q("11 月 7 日 · 周六 17:00–21:00 · 每人不超过 ¥260", "7 November · Saturday 17:00–21:00 · up to ¥260 each")),"small"),
          InlineHeader(\(q("选一个能坐下来的地方", "A place to settle in"))),
          CompositeCardBlock([
            CompositeCardItem(
              "offer-0",
              ImageTextLarge("/venue-daylight.jpg",\(q("A · 明亮长桌空间", "A · daylight table space")),\(q("A · 明亮长桌空间", "A · daylight table space")),null,true),
              [TagBlock([\(q("自然采光", "Natural light")), \(q("共享长桌", "Shared table"))],"sm"),Text("text",\(q("六人共享长桌，可自带餐食。", "A shared table for six; bring your own food.")),null,"text","xs")],
              {price:BoldText("number","¥480",null,"text","lg"),button:Button(\(q("预订", "Book")),Action([@Set($venue,"studio"),@ToAssistant(\(q("预览购买：六人长桌空间四小时", "Preview purchase: Four-hour table space for six")),{reviewPurchase:true,item:\(q("六人长桌空间四小时", "Four-hour table space for six")),price:"¥480"})]),"primary",null,"small")}
            ),
            CompositeCardItem(
              "offer-1",
              ImageTextLarge("/venue-private.jpg",\(q("B · 独立用餐空间", "B · private dining space")),\(q("B · 独立用餐空间", "B · private dining space")),null,true),
              [TagBlock([\(q("独立包间", "Private room")), \(q("安静私密", "Quiet and private"))],"sm"),Text("text",\(q("六人独立空间，适合安静聊天。", "A private space for six, with room to talk.")),null,"text","xs")],
              {price:BoldText("number","¥720",null,"text","lg"),button:Button(\(q("预订", "Book")),Action([@Set($venue,"private"),@ToAssistant(\(q("预览购买：六人独立空间四小时", "Preview purchase: Four-hour private space for six")),{reviewPurchase:true,item:\(q("六人独立空间四小时", "Four-hour private space for six")),price:"¥720"})]),"primary",null,"small")}
            )
          ],"grid",true),
          InlineHeader(\(q("共享晚餐，不用各点各的", "One dinner to share"))),
          Card([
            ImageBlock("/gathering-table.jpg",\(q("六人共享餐食", "Shared dinner for six"))),
            TextContent(\(q("六人共享餐食", "Shared dinner for six")),"small-heavy"),
            TagBlock([\(q("共享菜单", "Sharing menu")), \(q("含饮品", "Drinks included"))],"sm"),
            TextContent(\(q("主食、蔬菜与饮品，六个人一起分享。", "Mains, vegetables and drinks to share between six."))),
            Stack([TextContent("¥720","large-heavy"),Buttons([Button(\(q("预订餐食", "Order dinner")),@ToAssistant(\(q("预览购买：六人共享晚餐", "Preview purchase: Shared dinner for six")),{reviewPurchase:true,item:\(q("六人共享晚餐", "Shared dinner for six")),price:"¥720"}),"primary",null,"small")])],"row","s","center","between",false)
          ]),
          InlineHeader(\(q("四小时，有松有紧", "Four hours, with room to breathe"))),
          Steps([
            StepsItem("17:00",\(q("到场、布置餐桌，第一位到的人完成场地交接。", "Arrive, set the table and hand over the venue to the first guest."))),
            StepsItem("17:30",\(q("一起吃饭，聊天不设议程。", "Dinner together, with no agenda for the conversation."))),
            StepsItem("19:00",\(q("桌游或聊天，想休息的人不必参与每一轮。", "Board games or more conversation; sitting out a round is fine."))),
            StepsItem("20:30",\(q("收拾、分装剩余食物，21:00 前离场。", "Tidy up, pack leftovers and leave by 21:00.")))
          ]),
          InlineHeader(\(q("选完场地，人均费用一起更新", "The split follows your venue choice"))),
          Stack([
            BoldText("number","¥"+perPerson,\(q("每人分摊", "per person")),"text","lg"),
            BoldText("number","¥"+total,\(q("六人合计", "total for six")),"text","lg")
          ],"row","s","center","between",true),
          SingleStackedBarChart([
            \(q("场地", "Venue")),
            \(q("餐食", "Dinner")),
            \(q("耗材与余量", "Supplies and buffer"))
          ],[space,food,extras]),
          EntityList([
            {left:\(q("场地", "Venue")),right:"¥"+space,rightVariant:"number"},
            {left:\(q("共享晚餐", "Shared dinner")),right:"¥720",rightVariant:"number"},
            {left:\(q("耗材与机动余量", "Supplies and flexibility")),right:"¥120",rightVariant:"number"}
          ],"small"),
          TextContent(\(q("场地、套餐、条件与价格均为虚构示例；图片只展示对应空间与用餐氛围。真实预订前确认人数、饮食要求、外带规则与离场时间。", "Venues, packages, terms and prices are fictional. Photos illustrate spaces and dining. Before a real booking, confirm guests, dietary needs, outside-food rules and closing time.")),"small")
        ],"column","l")
        """
      sources = [
      ]
    case "scene-learning":
      title = t("图文学习一段历史", "Liangzhu history")
      request = t("从玉琮和玉璧给我讲讲良渚历史，结合图片和馆藏资料，区分能观察到的证据与尚不能确定的解释，并给出出处。", "Teach me about Liangzhu history through jade cong and bi. Use images and collection records, explain what we can observe and what remains uncertain, and include sources.")
      source = """
        root=Stack([
          TextContent(\(q("一块玉，为什么能讲出一个时代？", "What can a piece of jade tell us?")),"large-heavy"),
          TextContent(\(q("从良渚玉琮开始，看形制、工艺与社会，再分清我们知道什么、还有什么不能确定。", "Begin with a Liangzhu cong: its form, workmanship and social setting, then separate evidence from what remains uncertain."))),
          Image(\(q("良渚文化玉琮，约公元前 2400 年；大都会艺术博物馆，2004.52", "Liangzhu jade cong, about 2400 BCE; The Met, 2004.52")),"/liangzhu-cong.jpg"),
          TextContent(\(q("图 1 · 这件玉琮属于新石器时代良渚文化。器身外方内圆，转角处有抽象面纹。[1]", "Fig. 1 · A Neolithic Liangzhu cong. Its squared exterior encloses a round tube; abstract masks mark the corners.[1]")),"small"),
          InlineHeader(\(q("先看形状，再问用途", "Form, craft and use"))),
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
          Image(\(q("清代仿古玉琮；大都会艺术博物馆，21.175.114", "Qing-dynasty archaistic jade cong; The Met, 21.175.114")),"/object.jpg"),
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
          TextContent(\(q("根据馆方网页整理的固定讲解范例，不是现场搜索结果。图片为馆方开放获取资料；精确来源见记录。", "Authored from museum records, not a live search. Images are museum Open Access assets; sources are linked above.")),"small")
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
    return ReviewProgram(id: id, title: title, source: source, sources: sources, request: request)
  }
}
