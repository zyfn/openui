import Foundation
import OpenUISwiftUI

/// Authored travel examples, not live model answers. All composition is ordinary
/// OpenUI Lang; photos, localized copy and sample budgets belong to this app.
enum ReviewScenePrograms {
  static var ids: [String] { ReviewCatalog.scenarios.flatMap(\.variants).map(\.id) }

  static func program(_ id: String, english: Bool = false) -> ReviewProgram? {
    func t(_ zh: String, _ en: String) -> String { english ? en : zh }
    func q(_ zh: String, _ en: String) -> String {
      let data = try! JSONSerialization.data(withJSONObject: [t(zh, en)], options: [.withoutEscapingSlashes])
      return String(String(data: data, encoding: .utf8)!.dropFirst().dropLast())
    }
    let louvre = "https://www.louvre.fr/en/visit"
    let eiffel = "https://www.toureiffel.paris/en"
    let marais = "https://parisjetaime.com/transport/quartier-du-marais-p1929"
    let germain = "https://parisjetaime.com/eng/article/a-walk-in-saint-germain-des-pres-a925"
    let places = """
      [{id:"louvre",title:\(q("卢浮宫", "The Louvre")),lat:48.8606,lng:2.3376,imageSrc:"/paris-louvre.jpg",subtitle:\(q("建筑、艺术与杜乐丽花园", "Art, architecture and the Tuileries")),icon:"building.columns"},
       {id:"eiffel",title:\(q("埃菲尔铁塔", "Eiffel Tower")),lat:48.8584,lng:2.2945,imageSrc:"/paris-eiffel.jpg",subtitle:\(q("塞纳河与城市天际线", "The Seine and the Paris skyline")),icon:"mappin.and.ellipse"},
       {id:"germain",title:\(q("圣日耳曼", "Saint-Germain-des-Prés")),lat:48.8539,lng:2.3332,imageSrc:"/paris-cafe.jpg",subtitle:\(q("咖啡馆、书店与左岸街区", "Cafés, bookshops and the Left Bank")),icon:"cup.and.saucer"}]
      """
    let officialLinks = """
      ListBlock([
        ListItem(\(q("卢浮宫参观信息", "Visiting the Louvre")),"louvre.fr",null,null,@OpenUrl("\(louvre)")),
        ListItem(\(q("埃菲尔铁塔官方信息", "Eiffel Tower visitor information")),"toureiffel.paris",null,null,@OpenUrl("\(eiffel)")),
        ListItem(\(q("左岸街区步行指南", "A walk through the Left Bank")),"parisjetaime.com",null,null,@OpenUrl("\(germain)"))
      ])
      """
    let title: String
    let source: String
    switch id {
    case "scene-explore":
      title = t("探索一座城市", "Explore a city")
      source = """
        $place="louvre"
        root=Stack([
          Stack([
            TextContent(\(q("巴黎", "Paris")),"large-heavy"),
            TextContent(\(q("在地标之间，也给街区留一点时间", "Make room for the city between its landmarks")),"small"),
            TextContent(\(q("第一次来，不必把每一站都排满。选一座博物馆，沿塞纳河走一段，再在左岸找家咖啡馆坐下来。这里把值得看的、怎么安排和去哪里查资料放在一起。", "For a first visit, start with one museum, follow the Seine and leave time for a café on the Left Bank. Here is a place to begin, a way to pace your days and the official sources to plan from.")))
          ],"column","s"),
          ContextCardBlock([ContextCardItem("art",\(q("艺术与博物馆", "Art & museums")),\(q("卢浮宫不必一次看完。先选一个主题，再给花园和河岸留出时间。", "Choose a theme at the Louvre, then leave room for the gardens and riverbank.")),null,"/paris-louvre.jpg",\(q("卢浮宫金字塔", "The Louvre Pyramid")))]),
          ContextCardBlock([ContextCardItem("left-bank",\(q("左岸生活", "Life on the Left Bank")),\(q("圣日耳曼的咖啡馆、书店与街巷，适合把行程慢下来。", "Cafés, bookshops and quieter streets in Saint-Germain invite a slower afternoon.")),null,"/paris-cafe.jpg",\(q("巴黎街角咖啡馆", "A Paris street café")))]),
          InlineHeader(\(q("给第一次到访的安排", "A first visit, with room to breathe"))),
          OverviewCardBlock([
            OverviewCardItem("days",IconText(Icon("calendar"),"neutral","m",\(q("建议安排", "Suggested stay"))),MetricIndicatorInline("2",\(q("天，从容开始", "days to get started")))),
            OverviewCardItem("focus",IconText(Icon("map-pin"),"neutral","m",\(q("这份指南", "This guide"))),MetricIndicatorInline("3",\(q("处主要停留", "places to start"))))
          ]),
          InlineHeader(\(q("先看两处地标", "Two landmarks to begin with"))),
          VisualCardBlock([
            VisualCardItem(BoldText("text",\(q("埃菲尔铁塔", "Eiffel Tower")),\(q("河岸、草坪与城市天际线", "Riverbanks, open lawns and the skyline")),"text","sm"),"eiffel","/paris-eiffel.jpg",Tag(\(q("城市地标", "Landmark")),null,"sm"),\(q("埃菲尔铁塔与塞纳河", "The Eiffel Tower and the Seine"))),
            VisualCardItem(BoldText("text",\(q("卢浮宫", "The Louvre")),\(q("从宫殿与金字塔开始", "Begin with the palace and pyramid")),"text","sm"),"louvre","/paris-louvre.jpg",Tag(\(q("艺术与建筑", "Art & architecture")),null,"sm"),\(q("卢浮宫金字塔", "The Louvre Pyramid")))
          ],"grid",false),
          InlineHeader(\(q("把吃饭也留进行程", "Leave time for the table"))),
          ListBlock([
            ListItem(\(q("早餐，不急着赶路", "A slow breakfast")),\(q("一杯咖啡和可颂，再决定今天从哪条街开始。", "Coffee and a croissant before choosing your first street.")),{src:"/paris-breakfast.jpg",alt:\(q("咖啡与可颂的氛围照片", "Coffee and croissant illustration"))}),
            ListItem(\(q("下午，坐进左岸街区", "An afternoon on the Left Bank")),\(q("把圣日耳曼与卢森堡花园放在同一段漫步里。", "Pair Saint-Germain with a walk toward the Luxembourg Gardens.")),{src:"/paris-cafe.jpg",alt:\(q("巴黎咖啡馆", "A Paris café"))},\(q("看街区指南", "Read the neighborhood guide")),@OpenUrl("\(germain)"))
          ],"image"),
          InlineHeader(\(q("这些地方在哪里", "Find your bearings"))),
          Map(\(places),[],$place,"regular","wgs84"),
          InlineHeader(\(q("官方资料", "Plan from official sources"))),
          \(officialLinks)
        ],"column","l")
        """
    case "scene-itinerary":
      title = t("安排一天行程", "Plan your days")
      source = """
        root=Stack([
          TextContent(\(q("巴黎，两天慢慢走", "Paris, two unhurried days")),"large-heavy"),
          TextContent(\(q("艺术、河岸与左岸咖啡。每天一个重点，其余时间留给路上。", "Art, riverbanks and Left Bank cafés. One anchor each day, with time for the way between."))),
          TagBlock([\(q("11 月 5–6 日", "5–6 November")),\(q("2 位成人", "2 adults")),\(q("步行 + 公共交通", "Walking + transit"))],"sm"),
          Tabs([
            TabItem("museum",\(q("第一天 · 艺术与左岸", "Day 1 · Art & the Left Bank")),[
              ImageBlock("/paris-louvre.jpg",\(q("卢浮宫", "The Louvre"))),
              Steps([
                StepsItem("09:30–12:00",\(q("卢浮宫：提前选定想看的部分，不追求走完所有展厅。", "The Louvre: choose a few galleries rather than trying to see everything."))),
                StepsItem("12:00–13:30",\(q("午餐与休息：先吃好，再继续下午的路。", "Lunch and a proper break before the afternoon."))),
                StepsItem("13:30–15:00",\(q("杜乐丽花园与河岸：让室内参观之后的节奏放松下来。", "The Tuileries and riverbank: a gentler pace after the museum."))),
                StepsItem("15:30–17:00",\(q("圣日耳曼：咖啡、书店，或者临时走进一家喜欢的店。", "Saint-Germain: coffee, bookshops or a shop that catches your eye.")))
              ]),
              TextCallout("info",\(q("参观前确认", "Before you visit")),\(q("卢浮宫周二闭馆；建议按官网预约入场时段。[1]", "The Louvre closes on Tuesdays; book a time slot through the official site.[1]")))
            ]),
            TabItem("river",\(q("第二天 · 地标与河岸", "Day 2 · Landmarks & the Seine")),[
              ImageBlock("/paris-eiffel.jpg",\(q("埃菲尔铁塔与河岸", "The Eiffel Tower and riverbank"))),
              Steps([
                StepsItem("09:30–11:30",\(q("埃菲尔铁塔一带：登塔与否都留足停留时间，门票以官网为准。", "Around the Eiffel Tower: allow time to linger, whether or not you go up. Check tickets on the official site."))),
                StepsItem("12:00–13:30",\(q("午餐：找一家愿意坐下来的餐馆，不为了打卡来回奔波。", "Lunch somewhere you want to sit, without crossing the city for a checklist."))),
                StepsItem("14:00–16:00",\(q("塞纳河岸：沿水边散步，把剩下的时间留给临时发现。", "Follow the Seine and leave the rest of the afternoon open.")))
              ]),
              ListBlock([ListItem(\(q("查看登塔与票务信息", "Eiffel Tower tickets and visitor information")),"toureiffel.paris",null,null,@OpenUrl("\(eiffel)"))])
            ])
          ]),
          InlineHeader(\(q("主要停留点", "Your anchor points"))),
          Map(\(places),[],null,"compact","wgs84"),
          TextContent(\(q("这是参观顺序与建议时段；地图标示地点，不代表已计算实时交通路线。", "These are suggested timings and stops; the map does not represent live routing.")),"small"),
          \(officialLinks)
        ],"column","l")
        """
    case "scene-compare":
      title = t("比较几个方案", "Compare your options")
      source = """
        $area="marais"
        root=Stack([
          TextContent(\(q("第一次住巴黎，选哪个街区？", "Where should you stay for a first visit?")),"large-heavy"),
          TextContent(\(q("把重点放在每天怎么度过。想兼顾散步、吃饭和探索，可以先看玛黑区；更喜欢左岸咖啡与书店，就看圣日耳曼。", "Think about how you want to spend your days. Start with Le Marais for wandering and variety, or Saint-Germain for cafés and bookshops on the Left Bank."))),
          ContextCardBlock([ContextCardItem("choice",\(q("先给一个建议", "A place to start")),\(q("两天行程，优先选位置合适、晚上也愿意散步的街区，再比较具体住宿。", "For two days, choose a well-placed neighborhood you will enjoy in the evening before comparing individual stays.")),"gray")]),
          InlineHeader(\(q("三个街区，三种氛围", "Three neighborhoods, three moods"))),
          Table([
            Col(\(q("街区", "Area")),[\(q("玛黑区", "Le Marais")),\(q("圣日耳曼", "Saint-Germain")),\(q("蒙马特", "Montmartre"))]),
            Col(\(q("适合的偏好", "Best for")),[\(q("历史街区、小店与餐饮", "Historic streets, shops and food")),\(q("咖啡馆、书店与左岸漫步", "Cafés, bookshops and Left Bank walks")),\(q("坡道、街景与高处视野", "Hillside streets and elevated views"))]),
            Col(\(q("选房时留意", "Check before booking")),[\(q("具体街道的夜间环境", "The evening atmosphere of the street")),\(q("预算与附近交通", "Budget and nearby transport")),\(q("坡度、台阶与进出路线", "Slopes, steps and access"))])
          ]),
          InlineHeader(\(q("更想把时间留给什么？", "What matters most to you?"))),
          ListBlock([
            ListItem(\(q("玛黑区 · 边逛边发现", "Le Marais · Wander and discover")),\(q("历史建筑、小店和用餐选择放在一起。", "Historic buildings, small shops and places to eat.")),null,null,@Set($area,"marais")),
            ListItem(\(q("圣日耳曼 · 坐下来感受左岸", "Saint-Germain · Settle into the Left Bank")),\(q("让咖啡馆和书店成为每天的一部分。", "Make cafés and bookshops part of each day.")),null,null,@Set($area,"germain")),
            ListItem(\(q("蒙马特 · 为街景多走一段", "Montmartre · Take the scenic way")),\(q("喜欢起伏的街道，也愿意考虑坡道和台阶。", "For hillside streets, with slopes and steps to consider.")),null,null,@Set($area,"montmartre"))
          ]),
          TextContent($area=="marais"?\(q("当前倾向：玛黑区", "Your preference: Le Marais")):$area=="germain"?\(q("当前倾向：圣日耳曼", "Your preference: Saint-Germain")):\(q("当前倾向：蒙马特", "Your preference: Montmartre")),"small-heavy"),
          InlineHeader(\(q("下一步看什么", "Before choosing a stay"))),
          ListBlock([ListItem(\(q("从地址核对实际交通", "Check transport from the actual address")),\(q("街区名称不能替代具体位置；确认最近车站与到站后的步行。", "A neighborhood name is not an address. Check the nearest station and the walk from it."))),ListItem(\(q("看取消条件和总价", "Compare total price and cancellation terms")),\(q("用相同日期、人数和房型比较，别只比较一晚起价。", "Compare the same dates, party size and room type, not just a headline nightly rate.")))]),
          ListBlock([ListItem(\(q("玛黑区官方介绍", "Le Marais guide")),"parisjetaime.com",null,null,@OpenUrl("\(marais)")),ListItem(\(q("圣日耳曼步行指南", "Saint-Germain walking guide")),"parisjetaime.com",null,null,@OpenUrl("\(germain)"))])
        ],"column","l")
        """
    case "scene-preferences":
      title = t("设置偏好与条件", "Set your preferences")
      source = """
        $saved=false
        root=Stack([
          TextContent(\(q("让两天行程更像你", "Make these two days yours")),"large-heavy"),
          TextContent(\(q("不用填一份长问卷。确定日期、兴趣和大致预算，就能先排出一个有余地的版本。", "Start with dates, interests and a rough budget. There is no need for a long questionnaire."))),
          Form("preferences",Buttons([Button(\(q("保存这次偏好", "Save these preferences")),@Set($saved,true))]),[
            FormControl(\(q("同行人数", "Travel party")),Select("party",[SelectItem("two",\(q("2 位成人", "2 adults"))),SelectItem("solo",\(q("独自出行", "Solo"))),SelectItem("family",\(q("亲友同行", "Family or friends")))],\(q("选择人数", "Choose your party")),null,"two")),
            FormControl(\(q("出发日期", "First day")),DatePicker("date","single",null,"2026-11-05")),
            FormControl(\(q("想把时间留给", "Make time for")),CheckBoxGroup("interests",[
              CheckBoxItem(\(q("艺术与建筑", "Art & architecture")),\(q("博物馆、宫殿和街道立面", "Museums, palaces and streetscapes")),"art",true),
              CheckBoxItem(\(q("街区与咖啡", "Neighborhoods & cafés")),\(q("小店、书店和坐下来的时间", "Small shops, bookshops and time to sit")),"streets",true),
              CheckBoxItem(\(q("花园与河岸", "Gardens & riverbanks")),\(q("在室内参观之间留一点户外时间", "Outdoor time between indoor visits")),"outdoors",false)
            ])),
            FormControl(\(q("旅行节奏", "Pace")),RadioGroup("pace",[RadioItem(\(q("从容一点", "Unhurried")),\(q("每天一个重点，允许临时改变主意", "One anchor per day, with room to change your mind")),"easy"),RadioItem(\(q("内容充实", "More to explore")),\(q("愿意多走一些，也保留休息时间", "More stops, while still making room for breaks")),"full")],null,"easy")),
            FormControl(\(q("每日每人预算", "Daily budget per person")),Slider("budget","continuous",50,250,10,[100,150],"EUR"),\(q("不含住宿；这里只用于规划范围，不是实时报价。", "Excludes accommodation. A planning range, not a live quote."))),
            FormControl(\(q("还有什么要照顾", "Anything we should allow for?")),TextArea("notes",\(q("例如少走台阶、预留午休，或特别想看的作品。", "Fewer steps, a midday break, or an artwork you would love to see.")),3))
          ]),
          Callout("success",\(q("偏好已保留", "Preferences saved")),\(q("这份示例只更新当前页面，不提交预订。", "This example updates the current page; it does not make a booking.")),$saved)
        ],"column","l")
        """
    case "scene-reading":
      title = t("阅读一份资料", "Read and explore")
      source = """
        root=Stack([
          TextContent(\(q("卢浮宫，不用看完才算来过", "The Louvre, without trying to see it all")),"large-heavy"),
          TextContent(\(q("先选一个主题，再为一件作品停留。宫殿本身、玻璃金字塔和展厅之间的光线，也都是参观的一部分。", "Choose a theme, then spend time with a work. The palace, the glass pyramid and the light between galleries are part of the visit too."))),
          ImageBlock("/paris-louvre.jpg",\(q("卢浮宫金字塔与宫殿外观", "The Louvre Pyramid and palace exterior"))),
          TagBlock([\(q("建筑", "Architecture")),\(q("艺术", "Art")),\(q("建议预留半天", "Allow half a day"))],"sm"),
          InlineHeader(\(q("先决定怎么走", "Choose a way in"))),
          Tabs([
            TabItem("palace",\(q("从建筑开始", "Begin with the building")),[
              TextContent(\(q("金字塔是主要入口。走进地下大厅后先看导览图，选定一条主线，再进入展厅，避免来回寻找入口。[1]", "The Pyramid is the main entrance. Begin with a museum map and one route before heading into the galleries.[1]"))),
              Steps([StepsItem(\(q("到达", "Arrive")),\(q("确认预约时段与对应入口", "Check your time slot and entrance"))),StepsItem(\(q("选择", "Choose")),\(q("用导览图确定这次最想看的部分", "Choose the part you most want to see"))),StepsItem(\(q("停留", "Linger")),\(q("给一件作品留出完整的观看时间", "Give one work your full attention")))])
            ]),
            TabItem("collection",\(q("从作品开始", "Begin with a work")),[
              TextContent(\(q("先看轮廓、材质和光线，再读说明。与其不停拍照，不如记住一个让你愿意再看一眼的细节。", "Look at form, material and light before reading the label. Keep one detail that makes you want to look again."))),
              ListBlock([ListItem(\(q("一个观察问题", "A question to take with you")),\(q("如果先不读说明，这件作品最先让你注意到什么？", "What catches your attention before you read the label?"))),ListItem(\(q("一条自己的笔记", "A note of your own")),\(q("用一句话留下感受，回去后再查资料。", "Keep a sentence about the experience and read more later.")))])
            ])
          ]),
          Separator(),
          InlineHeader(\(q("实用信息，单独看清楚", "Practical details"))),
          EntityList([{left:\(q("例行闭馆", "Weekly closure")),right:\(q("周二", "Tuesday"))},{left:\(q("入场", "Admission")),right:\(q("建议提前预约时段", "Book a time slot"))},{left:\(q("当天开放展厅", "Open galleries")),right:\(q("出发前核对官网", "Check before visiting"))}]),
          TextContent(\(q("开放安排和部分展厅可能调整，以官方参观页为准。[1]", "Opening arrangements and gallery availability can change; check the official visitor page.[1]")),"small"),
          ListBlock([ListItem(\(q("官方参观、入口与票务", "Official visiting, entrances and tickets")),"louvre.fr",null,null,@OpenUrl("\(louvre)"))])
        ],"column","l")
        """
    case "scene-budget":
      title = t("查看预算与数据", "Understand your budget")
      source = """
        root=Stack([
          TextContent(\(q("两个人，两天的巴黎预算", "Two people, two days in Paris")),"large-heavy"),
          TextContent(\(q("先把餐饮、体验和临时发现都留进预算。下面是 €480 的规划分配，不含住宿，不是门票或餐厅的实时报价。", "Make room for meals, activities and discoveries. This is a €480 planning allocation, excluding accommodation, not live ticket or restaurant pricing."))),
          Stack([MetricIndicatorInline("€480",\(q("两人合计", "Total for two"))),MetricIndicatorInline("€120",\(q("每日每人", "Per person, per day")))],"row","l","start","between",true),
          Separator(),
          InlineHeader(\(q("先看钱花在哪里", "Where the money goes"))),
          PieChart([\(q("餐饮", "Food")),\(q("参观体验", "Activities")),\(q("市内交通", "Transport")),\(q("机动余量", "Flexibility"))],[160,160,60,100],"donut"),
          Table([
            Col(\(q("项目", "Category")),[\(q("餐饮", "Food")),\(q("参观体验", "Activities")),\(q("市内交通", "Transport")),\(q("机动余量", "Flexibility"))]),
            Col(\(q("计划分配 €", "Allocation €")),[160,160,60,100],"number"),
            Col(\(q("包括什么", "Allow for")),[\(q("早餐、午晚餐和咖啡", "Breakfasts, meals and coffee")),\(q("按实际预约选择项目", "Activities you actually book")),\(q("按路线选择公共交通", "Transit suited to the route")),\(q("临时发现和计划变化", "Discoveries and changes"))])
          ]),
          InlineHeader(\(q("把节奏分到两天", "Spread it across the two days"))),
          BarChart([\(q("第一天", "Day 1")),\(q("第二天", "Day 2"))],[Series(\(q("餐饮", "Food")),[80,80]),Series(\(q("体验", "Activities")),[100,60]),Series(\(q("交通", "Transport")),[30,30]),Series(\(q("余量", "Flexibility")),[50,50])],"stacked"),
          ContextCardBlock([ContextCardItem("buffer",\(q("别把预算刚好用完", "Keep some room")),\(q("留 €100 机动余量。临时多坐一次车、延长一顿午餐，或者改变参观安排，都不用推倒重来。", "Keep €100 flexible so an extra ride, a longer lunch or a changed plan does not undo the whole budget.")),"gray")]),
          InlineHeader(\(q("付款前再核对", "Before paying"))),
          ListBlock([ListItem(\(q("票务与适用条件", "Tickets and eligibility")),\(q("以预约当天的官方价格与适用条件为准。", "Use the official price and eligibility rules for your visit.")),null,null,@OpenUrl("\(louvre)")),ListItem(\(q("这份预算的边界", "What this budget excludes")),\(q("不含住宿、城际交通和购物；可按个人偏好重新分配。", "Accommodation, intercity travel and shopping are excluded. Reallocate it to your priorities.")))])
        ],"column","l")
        """
    default: return nil
    }
    let sources: [CardSource] = [
      .init(url: louvre, title: t("卢浮宫参观信息", "Visiting the Louvre"), sourceName: "Louvre"),
      .init(url: eiffel, title: t("埃菲尔铁塔官方信息", "Eiffel Tower visitor information"), sourceName: "Tour Eiffel"),
      .init(url: germain, title: t("圣日耳曼步行指南", "Saint-Germain walking guide"), sourceName: "Paris je t’aime"),
    ]
    return ReviewProgram(id: id, title: title, source: source, sources: sources)
  }
}
