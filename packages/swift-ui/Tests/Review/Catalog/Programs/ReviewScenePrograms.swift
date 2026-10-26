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
      request = t("11 月 5 日两个人在巴黎玩一天。想看艺术、逛左岸，别太赶；吃饭和预算也帮我安排。", "We have one day in Paris on 5 November. Art, a slow Left Bank afternoon, somewhere to eat—and a budget for two?")
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
          TextContent(\(q("上午留给卢浮宫，午餐后沿左岸散步，傍晚去铁塔附近登船。", "The Louvre in the morning, a Left Bank walk after lunch, then a Seine cruise at dusk."))),
          InlineHeader(\(q("值得停留的三个地方", "Three places worth your time"))),
          Stack([
                Image(\(q("卢浮宫", "The Louvre")),"/paris-louvre-day.jpg"),
                Stack([
                  TextContent(\(q("卢浮宫", "The Louvre")),"small-heavy"),
                  TagBlock([\(q("09:30", "09:30")),\(q("非 EEA 成人票", "Non-EEA adult fare"))],"sm"),
                  TextContent(\(q("法国王宫旧址；从玻璃金字塔入馆，重点看德农馆。", "A former royal palace. Enter by the glass pyramid and focus on the Denon wing.")),"small"),
                  Stack([BoldText("number","€64",null,"text","lg"),Buttons([Button(\(q("订", "Book")),@OpenUrl("https://ticket.louvre.fr/en"),"primary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"row","m","stretch","start",false),
          Separator(),
          Stack([
                Image(\(q("圣日耳曼街区", "Saint-Germain-des-Prés")),"/paris-cafe.jpg"),
                Stack([
                  TextContent(\(q("圣日耳曼街区", "Saint-Germain-des-Prés")),"small-heavy"),
                  TagBlock([\(q("14:00", "14:00")),\(q("左岸", "Left Bank")),\(q("免费", "Free"))],"sm"),
                  TextContent(\(q("从圣日耳曼教堂出发，沿咖啡馆与书店密集的街道步行。", "Walk from the church through streets lined with cafés and bookshops.")),"small"),
                  Stack([BoldText("number","€0",null,"text","lg"),Buttons([Button(\(q("查看", "View")),@OpenUrl("https://parisjetaime.com/eng/article/a-walk-in-saint-germain-des-pres-a925"),"secondary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"row","m","stretch","start",false),
          Separator(),
          Stack([
                Image(\(q("塞纳河观光游船", "Seine sightseeing cruise")),"/paris-cruise.jpg"),
                Stack([
                  TextContent(\(q("塞纳河观光游船", "Seine sightseeing cruise")),"small-heavy"),
                  TagBlock([\(q("17:30", "17:30")),\(q("1 小时", "1 hour")),\(q("语音导览", "Audio guide"))],"sm"),
                  TextContent(\(q("从 Port de la Bourdonnais 登船，沿塞纳河经过市中心地标。", "Board at Port de la Bourdonnais for a one-hour route past central landmarks.")),"small"),
                  Stack([BoldText("number","€36",null,"text","lg"),Buttons([Button(\(q("订", "Book")),@OpenUrl("https://www.bateauxparisiens.com/en/cruise-tours/guided-tour.html"),"primary",null,"small")])],"row","s","center","between",false)
                ],"column","s","stretch","between",false)
              ],"row","m","stretch","start",false),
          TextCallout("neutral",\(q("衔接建议", "Getting between stops")),\(q("卢浮宫后在市中心午餐，再步行到圣日耳曼。去游船码头安排公共交通，抵达后再按实际班次登船。", "Have lunch after the Louvre, then walk to Saint-Germain. Use public transport to reach the cruise pier and confirm the next departure."))),
          InlineHeader(\(q("在左岸吃午餐", "Lunch on the Left Bank"))),
          ListBlock([
            ListItem("Les Deux Magots",\(q("圣日耳曼广场 6 号的文学咖啡馆，也提供正餐；到店看当天菜单。", "A literary café and restaurant at 6 Place Saint-Germain-des-Prés. Check the menu when you arrive.")),{src:"/paris-cafe.jpg",alt:\(q("巴黎咖啡馆氛围示意", "Paris café atmosphere illustration"))})
          ],"image"),
          InlineHeader(\(q("路线，一眼看清", "Get your bearings"))),
          Map([
            {id:"louvre",title:\(q("卢浮宫", "The Louvre")),lat:48.8606,lng:2.3376,imageSrc:"/paris-louvre-day.jpg",subtitle:\(q("艺术与宫殿", "Art and a royal palace")),icon:"building.columns"},
            {id:"germain",title:\(q("圣日耳曼", "Saint-Germain")),lat:48.8539,lng:2.3332,imageSrc:"/paris-cafe.jpg",subtitle:\(q("咖啡馆与左岸散步", "Cafés and Left Bank walks")),icon:"cup.and.saucer"},
            {id:"cruise",title:\(q("塞纳河游船码头", "Seine cruise pier")),lat:48.86039,lng:2.29353,imageSrc:"/paris-cruise.jpg",subtitle:"Port de la Bourdonnais",icon:"ferry"},
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
        request: t("帮我们两个人规划 11 月 5–6 日巴黎两天一晚，从伦敦飞过去。航班、酒店、每天去哪儿和总预算一起看看。", "Could you plan Paris for two, 5–6 November? We’ll fly from London. Compare flights and one hotel night, then show each day and the total cost."))
    case "scene-shopping":
      title = t("选购一台旅行相机", "Choose a camera")
      request = t("想买台轻便的旅行相机，拍街景和人像。连配件不超过 ¥7,500，你会选哪套？", "I want a light travel camera for streets and portraits. Which kit would you pick under ¥7,500, including the essentials?")
      source = """
        camera=5200
        extras=400
        total=camera+extras
        root=Stack([
          TextContent(\(q("把预算花在愿意带出门的相机上", "A camera worth taking with you")),"large-heavy"),
          TextContent(\(q("¥7,500 包含相机与配件。优先比较两套轻便的 APS-C 变焦组合，把重量、取景方式和剩余预算放在一起看。", "With ¥7,500 for a camera and essentials, compare two compact APS-C zoom kits by carry weight, framing and the money left over."))),
          CompositeCardBlock([
            CompositeCardItem("light",
              ImageTextLarge("/camera-light.jpg","Nikon Z50 · NIKKOR Z DX 16–50mm","Nikon Z50 · 16–50mm",null,true),
              [TagBlock([\(q("优先推荐", "Recommended")),"DX / APS-C","395 g"],"sm"),Text("text",\(q("20.9MP 机身配可收纳的 16–50mm 变焦，适合一天只带一支镜头。", "20.9MP body with a retracting 16–50mm zoom: one lens for an unhurried day out.")),null,"text","xs")],
              {price:BoldText("number","¥5,200",null,"text","lg"),button:Button(\(q("查看商品", "View product")),@OpenUrl("https://www.nikonusa.com/p/z-50/1632"),"primary",null,"small")}
            ),
            CompositeCardItem("portrait",
              ImageTextLarge("/camera-dark.jpg","Sony α6400 · E PZ 16–50mm","Sony α6400 · 16–50mm",null,true),
              [TagBlock(["APS-C","403 g",\(q("快速对焦", "Fast autofocus"))],"sm"),Text("text",\(q("24.2MP 机身与电动变焦；更适合想拍运动中的人物与街景。", "24.2MP body and power zoom, with strong autofocus for moving people and street scenes.")),null,"text","xs")],
              {price:BoldText("number","¥6,800",null,"text","lg"),button:Button(\(q("查看商品", "View product")),@OpenUrl("https://electronics.sony.com/imaging/interchangeable-lens-cameras/aps-c/p/ilce6400-b"),"primary",null,"small")}
            )
          ],"carousel",true),
          InlineHeader(\(q("两套差在哪里", "The practical difference"))),
          Table([
            Col(\(q("你更在意", "Your priority")),[
              \(q("机身重量", "Body weight")),
              \(q("传感器", "Sensor")),
              \(q("日常取景", "Everyday framing"))
            ]),
            Col("Nikon Z50",[
              "395 g",
              "20.9MP DX",
              \(q("手动变焦", "Manual zoom"))
            ]),
            Col("Sony α6400",[
              "403 g",
              "24.2MP APS-C",
              \(q("电动变焦", "Power zoom"))
            ])
          ]),
          InlineHeader(\(q("把必要配件也算进去", "Include the essentials"))),
          Stack([
            OverviewCardItem("0",Text("text",\(q("合计 ¥", "Total ¥"))+total,null,"text","lg")),
            OverviewCardItem("1",Text("text",\(q("剩余 ¥", "Left ¥"))+(7500-total),null,"text","lg"))
          ],"row","s","stretch","start",false),
          EntityList([
            {left:\(q("推荐套装", "Recommended kit")),right:"¥"+camera,rightVariant:"number"},
            {left:\(q("电池与存储卡预留", "Battery and storage allowance")),right:"¥"+extras,rightVariant:"number"}
          ],"small"),
          TextCallout("neutral",\(q("推荐先试握 Z50", "Handle the Z50 first")),\(q("两台机身都在预算内；把 16–50mm 装上实拍几分钟，再决定握持与对焦哪个更合手。", "Both bodies fit the budget. Try each with its 16–50mm lens before deciding which grip and focusing experience you prefer.")))
        ],"column","l")
        """
      sources = [
        .init(url: "https://www.nikonusa.com/p/z-50/1632", title: "Nikon Z50 specifications", sourceName: "Nikon"),
        .init(url: "https://www.sony.com/electronics/support/e-mount-body/ilce-6400/specifications",
          title: "Sony α6400 specifications", sourceName: "Sony"),
      ]
    case "scene-spending":
      title = t("分析消费与预算", "Spending review")
      request = t("这是我 8–10 月的账单：房租每月 ¥3,000，餐饮 1500/1500/1800，交通 500/400/600，其他 600/900/1200。哪里涨了？11 月想控制在 ¥6,000。", "Here’s my Aug–Oct ledger. Rent was ¥3,000 monthly; food 1500/1500/1800, transport 500/400/600, other 600/900/1200. What went up, and can November stay under ¥6,000?")
      source = """
        $period="october"
        food=$period=="quarter"?4800:1800
        transport=$period=="quarter"?1500:600
        home=$period=="quarter"?9000:3000
        other=$period=="quarter"?2700:1200
        total=food+transport+home+other
        root=Stack([
          TextContent(\(q("花费增加，主要不在房租", "Spending rose, but rent stayed flat")),"large-heavy"),
          TextContent(\(q("10 月比 9 月多花 ¥800；住房没有变化，增量来自餐饮、交通和其他消费。", "October was ¥800 above September. Housing stayed flat; food, transport and other spending account for the increase."))),
          TagBlock([\(q("8–10 月", "Aug–Oct")),\(q("3 个月", "3 months")),\(q("4 类支出", "4 categories"))],"sm"),
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
            Button(\(q("只看 10 月", "October only")),@Set($period,"october"),$period=="october"?"primary":"secondary",null,"small"),
            Button(\(q("看三个月合计", "Three-month total")),@Set($period,"quarter"),$period=="quarter"?"primary":"secondary",null,"small")
          ]),
          TextContent("¥"+total,"large-heavy"),
          PieChart([
            \(q("住房", "Home")),
            \(q("餐饮", "Food")),
            \(q("交通", "Transport")),
            \(q("其他", "Other"))
          ],[home,food,transport,other],"donut"),
          InlineHeader(\(q("11 月，先试一份 ¥6,000 的计划", "Try a ¥6,000 plan for November"))),
          BarChart([\(q("住房", "Home")),\(q("餐饮", "Food")),\(q("交通", "Transport")),\(q("其他", "Other"))],[
            Series(\(q("10 月实际", "October")),[3000,1800,600,1200]),
            Series(\(q("11 月计划", "November plan")),[3000,1500,500,1000])
          ],"grouped",null,"¥",230),
          TextCallout("neutral",\(q("从 ¥6,600 到 ¥6,000", "From ¥6,600 to ¥6,000")),\(q("住房保持 ¥3,000；餐饮少 ¥300，交通少 ¥100，其他消费少 ¥200。月底按真实账单再调整。", "Keep housing at ¥3,000. Trim food by ¥300, transport by ¥100 and other spending by ¥200; revisit the plan against the next statement.")))
        ],"column","l")
        """
      sources = [
      ]
    case "scene-gathering":
      title = t("组织一次朋友聚会", "An evening together")
      request = t("11 月 7 日晚六个人聚一聚，17:00–21:00。找个能坐下聊天的地方，安排晚餐，人均别超过 ¥260。", "Six friends together on 7 November, 17:00–21:00. Find somewhere we can talk over dinner and keep it under ¥260 each.")
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
          TagBlock([\(q("6 人", "6 people")),\(q("4 小时", "4 hours")),\(q("上限 ¥260/人", "Up to ¥260 each"))],"sm"),
          InlineHeader(\(q("选一个能坐下来的地方", "A place to settle in"))),
          CompositeCardBlock([
            CompositeCardItem(
              "offer-0",
              ImageTextLarge("/venue-daylight.jpg",\(q("临窗共享长桌", "Window-side shared table")),\(q("临窗共享长桌", "Window-side shared table")),null,true),
              [TagBlock([\(q("自然采光", "Natural light")), \(q("共享长桌", "Shared table"))],"sm"),Text("text",\(q("六人共享长桌，可自带餐食。", "A shared table for six; bring your own food.")),null,"text","xs")],
              {price:BoldText("number","¥480",null,"text","lg"),button:Button(\(q("预订", "Book")),Action([@Set($venue,"studio"),@ToAssistant(\(q("预览购买：六人长桌空间四小时", "Preview purchase: Four-hour table space for six")),{reviewPurchase:true,item:\(q("六人长桌空间四小时", "Four-hour table space for six")),price:"¥480"})]),"primary",null,"small")}
            ),
            CompositeCardItem(
              "offer-1",
              ImageTextLarge("/venue-private.jpg",\(q("安静独立包间", "Quiet private room")),\(q("安静独立包间", "Quiet private room")),null,true),
              [TagBlock([\(q("独立包间", "Private room")), \(q("安静私密", "Quiet and private"))],"sm"),Text("text",\(q("六人独立空间，适合安静聊天。", "A private space for six, with room to talk.")),null,"text","xs")],
              {price:BoldText("number","¥720",null,"text","lg"),button:Button(\(q("预订", "Book")),Action([@Set($venue,"private"),@ToAssistant(\(q("预览购买：六人独立空间四小时", "Preview purchase: Four-hour private space for six")),{reviewPurchase:true,item:\(q("六人独立空间四小时", "Four-hour private space for six")),price:"¥720"})]),"primary",null,"small")}
            )
          ],"carousel",true),
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
          Stack([BoldText("number","¥"+perPerson,\(q("人均", "per person")),"text","lg"),BoldText("number","¥"+total,\(q("六人合计", "for six")),"text","lg")],"row","l","center","between",false),
          SingleStackedBarChart([
            \(q("场地", "Venue")),
            \(q("餐食", "Dinner")),
            \(q("耗材与余量", "Supplies and buffer"))
          ],[space,food,extras]),
          TextContent(\(q("按当前场地方案，人均低于 ¥260。预订前确认人数、饮食要求、外带规则和离场时间。", "The current plan stays below ¥260 each. Confirm the guest count, dietary needs, outside-food rules and closing time before booking.")),"small")
        ],"column","l")
        """
      sources = [
      ]
    case "scene-learning":
      title = t("图文学习一段历史", "Liangzhu history")
      request = t("从玉琮和玉璧讲讲良渚吧。我想看图和馆藏出处，也想知道哪些是证据，哪些还只是推测。", "Teach me Liangzhu through jade cong and bi. Show the objects and museum sources, and separate what we can observe from what we infer.")
      source = """
        root=Stack([
          TextContent(\(q("良渚，藏在玉里的秩序", "Liangzhu, a world held in jade")),"large-heavy"),
          TagBlock([\(q("新石器时代", "Neolithic")),\(q("玉器", "Jade")),\(q("馆藏阅读", "Collection study"))],"sm"),
          TextContent(\(q("看形状、比工艺，再区分证据与推断。", "Look at form and workmanship, then separate evidence from interpretation."))),
          ImageGallery([
            {src:"/liangzhu-cong.jpg",alt:\(q("玉琮全貌", "Cong · full object")),details:\(q("玉琮 · 约公元前 2400 年", "Cong · about 2400 BCE"))},
            {src:"/liangzhu-bi.jpg",alt:\(q("玉璧全貌", "Bi · full object")),details:\(q("玉璧 · 公元前三千纪中叶", "Bi · mid-third millennium BCE"))}
          ]),
          TextContent(\(q("点击图片查看全貌并切换。馆藏记录：[玉琮](https://www.metmuseum.org/art/collection/search/72376) · [玉璧](https://www.metmuseum.org/art/collection/search/49371)", "Tap an image to view it in full and switch between objects. Collection records: [Cong](https://www.metmuseum.org/art/collection/search/72376) · [Bi](https://www.metmuseum.org/art/collection/search/49371)")),"small"),
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
          BarChart([\(q("馆藏高度", "Object height"))],[Series(\(q("良渚玉琮", "Liangzhu cong")),[25.4]),Series(\(q("清代仿古琮", "Qing archaistic cong")),[12.7])],"grouped",null,"cm",220),
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
