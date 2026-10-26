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
          TextContent(\(q("2026 年 11 月 5 日", "5 November 2026")),"small"),
          Stack([
            OverviewCardItem("party",IconText(Icon("users"),"neutral","m",\(q("2 人", "2 people")),null,true,"vertical")),
            OverviewCardItem("duration",IconText(Icon("calendar-days"),"neutral","m",\(q("1 天", "1 day")),null,true,"vertical")),
            OverviewCardItem("places",IconText(Icon("map-pin"),"neutral","m",\(q("3 处景点", "3 places")),null,true,"vertical"))
          ],"row","s","stretch","start",false),
          TextContent(\(q("上午看艺术，午后逛左岸，傍晚到铁塔附近乘船；把参观和休息串成一条路线。", "Art in the morning, the Left Bank after lunch, then a cruise near the tower. Keep time for breaks between visits."))),
          InlineHeader(\(q("值得停留的三个地方", "Three places worth your time"))),
          Stack([
                Image(\(q("卢浮宫", "The Louvre")),"/paris-louvre.jpg"),
                Stack([
                  TextContent(\(q("卢浮宫", "The Louvre")),"small-heavy"),
                  TagBlock([\(q("艺术", "Art")),\(q("博物馆", "Museum"))],"sm"),
                  TextContent(\(q("法国国王昔日的宫殿，馆藏横跨近一万年的艺术史。", "The former palace of the kings of France, with collections encompassing nearly 10,000 years of art history.")),"small"),
                  Stack([BoldText("number","€64",\(q("非 EEA 成人 €32 × 2", "Non-EEA adults €32 × 2")),"text","lg"),Buttons([Button(\(q("订", "Book")),@OpenUrl("https://ticket.louvre.fr/en"),"primary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"row","m","stretch","start",false),
          Separator(),
          Stack([
                Image(\(q("圣日耳曼街区", "Saint-Germain-des-Prés")),"/paris-cafe.jpg"),
                Stack([
                  TextContent(\(q("圣日耳曼街区", "Saint-Germain-des-Prés")),"small-heavy"),
                  TagBlock([\(q("左岸", "Left Bank")),\(q("免费", "Free"))],"sm"),
                  TextContent(\(q("双叟与花神咖啡馆曾是巴黎文学和艺术界的聚会场所。", "Les Deux Magots and Café de Flore were meeting spots for the Paris literary and artistic world.")),"small"),
                  Stack([BoldText("number","€0",\(q("公共街区免费", "Free public streets")),"text","lg"),Buttons([Button(\(q("详情", "Details")),@OpenUrl("https://parisjetaime.com/eng/article/a-walk-in-saint-germain-des-pres-a925"),"primary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"row","m","stretch","start",false),
          Separator(),
          Stack([
                Image(\(q("塞纳河观光游船", "Seine sightseeing cruise")),"/paris-eiffel.jpg"),
                Stack([
                  TextContent(\(q("塞纳河观光游船", "Seine sightseeing cruise")),"small-heavy"),
                  TagBlock([\(q("Bateaux Parisiens", "Bateaux Parisiens")),\(q("1 小时", "1 hour")),\(q("语音导览", "Audio guide"))],"sm"),
                  TextContent(\(q("一小时塞纳河观光游船，含语音导览。", "Duration: 1 hour. Included: Audio guides.")),"small"),
                  Stack([BoldText("number","€36",\(q("€18 × 2 位成人", "€18 × 2 adults")),"text","lg"),Buttons([Button(\(q("订", "Book")),@OpenUrl("https://www.bateauxparisiens.com/en/cruise-tours/guided-tour.html"),"primary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"row","m","stretch","start",false),
          TextCallout("neutral",\(q("衔接建议", "Getting between stops")),\(q("卢浮宫后在市中心午餐，再步行到圣日耳曼。去游船码头安排公共交通，抵达后再按实际班次登船。", "Have lunch after the Louvre, then walk to Saint-Germain. Use public transport to reach the cruise pier and confirm the next departure."))),
          InlineHeader(\(q("吃饭，也留一点从容", "Make time for a proper break"))),
          ListBlock([
            ListItem(\(q("左岸午餐", "Lunch on the Left Bank")),\(q("参观后在圣日耳曼附近用餐；先看当天菜单，避免为了吃饭再跨城。", "Choose a place near Saint-Germain after sightseeing. Check the day's menu and avoid another cross-city trip.")),{src:"/paris-breakfast.jpg",alt:\(q("餐食示意", "Illustrative meal"))}),
            ListItem(\(q("双叟咖啡馆 · Les Deux Magots", "Les Deux Magots · café break")),\(q("圣日耳曼广场的文学咖啡馆，适合街区散步后坐下来。餐饮从当天预算中支出，按实际点单计费。", "A literary café on Place Saint-Germain-des-Prés. Take a break after your walk; food and drinks come from the day's budget and are charged as ordered.")),{src:"/paris-cafe.jpg",alt:\(q("咖啡馆氛围示意，非商家实景", "Illustrative café atmosphere, not a venue photograph"))})
          ],"image"),
          InlineHeader(\(q("路线，一眼看清", "Get your bearings"))),
          Map([
            {id:"louvre",title:\(q("卢浮宫", "The Louvre")),lat:48.8606,lng:2.3376,imageSrc:"/paris-louvre.jpg",subtitle:\(q("艺术与宫殿", "Art and a royal palace")),icon:"building.columns"},
            {id:"germain",title:\(q("圣日耳曼", "Saint-Germain")),lat:48.8539,lng:2.3332,imageSrc:"/paris-cafe.jpg",subtitle:\(q("咖啡馆与左岸散步", "Cafés and Left Bank walks")),icon:"cup.and.saucer"},
            {id:"cruise",title:\(q("塞纳河游船码头", "Seine cruise pier")),lat:48.86039,lng:2.29353,imageSrc:"/paris-eiffel.jpg",subtitle:"Port de la Bourdonnais",icon:"ferry"},
            {id:"deux-magots",title:"Les Deux Magots",lat:48.85389,lng:2.33306,imageSrc:"/paris-cafe.jpg",subtitle:"6 place Saint-Germain-des-Prés",icon:"cup.and.saucer"}
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
          TextContent(\(q("艺术、左岸、塞纳河，两人预算 €240。先确认卢浮宫时段；门票参考 10 月 26 日官网价，餐饮交通为估算，不含住宿及往返交通。", "Art, the Left Bank and the Seine: €240 for two. Confirm your Louvre slot first. Tickets use 26 Oct published rates; meals and transport are estimates, excluding accommodation and travel to Paris.")),"small")
        ],"column","l")
        """
      sources = [
        .init(url: "https://www.louvre.fr/en/visit", title: t("卢浮宫参观信息", "Louvre visitor information"), sourceName: "Louvre"),
        .init(url: "https://parisjetaime.com/eng/article/a-walk-in-saint-germain-des-pres-a925", title: t("左岸步行指南", "Left Bank walking guide"), sourceName: "Paris je t’aime"),
      ]
    case "scene-two-day-trip":
      let fixtureID = english ? "paris-fewshot-en" : "paris-fewshot-zh"
      guard let fixture = ReviewCatalog.importedPrograms().first(where: { $0.id == fixtureID }) else {
        preconditionFailure("Missing generated Paris few-shot fixture")
      }
      return ReviewProgram(id: id, title: t("规划一次两日游", "Two days in Paris"), source: fixture.source,
        request: t("帮两位成人安排 11 月 5 日从伦敦出发、6 日返回的巴黎两天一晚，包含机票、酒店、每日景点和预算。", "Plan two days and one night in Paris for two adults, leaving London on 5 November and returning on 6 November. Include flights, stays, daily places and a budget."))
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
            OverviewCardItem("0",Text("text",\(q("合计 ¥", "Total ¥"))+total,null,"text","lg")),
            OverviewCardItem("1",Text("text",\(q("剩余 ¥", "Left ¥"))+(7500-total),null,"text","lg"))
          ],"row","s","stretch","start",false),
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
          TextContent(\(q("2026 年 8–10 月 · 示例账单", "August–October 2026 · sample ledger")),"small"),
          TagBlock([\(q("3 个月", "3 months")),\(q("4 类支出", "4 categories"))],"sm"),
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
          TextContent(\(q("11 月 7 日 · 周六 17:00–21:00", "7 November · Saturday 17:00–21:00")),"small"),
          Stack([
            OverviewCardItem("0",Text("text",\(q("6 人", "6 people")),null,"text","lg")),
            OverviewCardItem("1",Text("text",\(q("4 小时", "4 hours")),null,"text","lg")),
            OverviewCardItem("2",Text("text",\(q("上限 ¥260/人", "Max ¥260/person")),null,"text","lg"))
          ],"row","s","stretch","start",false),
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
            OverviewCardItem("0",Text("text",\(q("人均 ¥", "Each ¥"))+perPerson,null,"text","lg")),
            OverviewCardItem("1",Text("text",\(q("合计 ¥", "Total ¥"))+total,null,"text","lg"))
          ],"row","s","stretch","start",false),
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
          TextContent(\(q("良渚，藏在玉里的秩序", "Liangzhu, a world held in jade")),"large-heavy"),
          TagBlock([\(q("新石器时代", "Neolithic")),\(q("玉器", "Jade")),\(q("馆藏阅读", "Collection study"))],"sm"),
          TextContent(\(q("看形状、比工艺，再区分证据与推断。", "Look at form and workmanship, then separate evidence from interpretation."))),
          Stack([
            Stack([
              Image(\(q("玉琮全貌", "Cong · full object")),"/liangzhu-cong.jpg"),
              TextContent(\(q("[玉琮](https://www.metmuseum.org/art/collection/search/72376)", "[Cong](https://www.metmuseum.org/art/collection/search/72376)")),"small-heavy"),
              TextContent(\(q("约公元前 2400 年 · 高 25.4 cm", "About 2400 BCE · 25.4 cm high")),"small")
            ],"column","xs"),
            Stack([
              Image(\(q("玉璧全貌", "Bi · full object")),"/liangzhu-bi.jpg"),
              TextContent(\(q("[玉璧](https://www.metmuseum.org/art/collection/search/49371)", "[Bi](https://www.metmuseum.org/art/collection/search/49371)")),"small-heavy"),
              TextContent(\(q("公元前三千纪中叶 · 约 15.6 cm", "Mid-third millennium BCE · about 15.6 cm")),"small")
            ],"column","xs")
          ],"row","m","start","start",false),
          InlineHeader(\(q("一眼分清琮与璧", "Cong and bi, at a glance"))),
          Table([
            Col(\(q("观察", "Look for")),[\(q("外形", "Form")),\(q("中部", "Center")),\(q("纹饰", "Decoration"))]),
            Col(\(q("玉琮", "Cong")),[\(q("方形器身", "Squared body")),\(q("贯穿圆孔", "Round bore")),\(q("转角面纹", "Corner masks"))]),
            Col(\(q("玉璧", "Bi")),[\(q("扁平圆盘", "Flat disk")),\(q("中央开孔", "Central opening")),\(q("此件表面简洁", "Plain surface here"))])
          ]),
          TextContent(\(q("工艺与材料支持身份或仪式用途的解释，但确切含义仍不明确。[1][2]", "Workmanship and material suggest status or ritual; the precise meanings remain uncertain.[1][2]")),"small"),
          Separator(),
          VisualCardBlock([VisualCardItem(BoldText("text",\(q("同形，不同时代", "Same form, another era")),\(q("清代仿古玉琮", "An archaistic cong from the Qing dynasty")),"text","lg"),"qing","/object.jpg",Tag(\(q("清代", "Qing dynasty")),null,"sm"),\(q("同形，不同时代", "Same form, another era")))],"grid",true,@OpenUrl("https://www.metmuseum.org/art/collection/search/42751")),
          InlineHeader(\(q("两件玉琮，有多高？", "How tall are the two cong?"))),
          HorizontalBarChart([\(q("良渚玉琮", "Liangzhu cong")),\(q("清代仿古琮", "Qing archaistic cong"))],[Series(\(q("高度（cm）", "Height (cm)")),[25.4,12.7])],"grouped","cm"),
          TextContent(\(q("仅比较这两件馆藏的高度，不代表各时代玉器的平均尺寸。[1][4]", "Heights of these two collection objects only, not period averages.[1][4]")),"small"),
          TextContent(\(q("形似，不等于同时代；先看器物，再查出处。", "Similar form does not mean the same date. Look closely, then check the record.")),"small-heavy"),
          TextContent(\(q("图像与数据：The Met Open Access。图注和延伸阅读图卡链接到馆藏记录。", "Images and measurements: The Met Open Access. Captions and the further-reading card link to collection records.")),"small")
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
