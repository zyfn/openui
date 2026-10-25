import Foundation

/// Six complete, authored examples. Localization belongs to this review app;
/// SDK components and caller-supplied programs are never translated here.
enum ReviewScenePrograms {
  static var ids: [String] { ReviewCatalog.scenarios.flatMap(\.variants).map(\.id) }

  static func program(_ id: String, english: Bool = false) -> ReviewProgram? {
    func text(_ chinese: String, _ translated: String) -> String { english ? translated : chinese }
    func q(_ chinese: String, _ translated: String) -> String {
      let data = try! JSONSerialization.data(withJSONObject: [text(chinese, translated)], options: [.withoutEscapingSlashes])
      return String(String(data: data, encoding: .utf8)!.dropFirst().dropLast())
    }
    let title: String
    let source: String
    switch id {
    case "scene-explore":
      title = text("探索一座城市", "Explore a city")
      source = """
        $place="gallery"
        root=Stack([
          InlineHeader(\(q("从街区走进展馆", "From the neighborhood to the gallery")),\(q("半日漫步 · 示例路线", "Half-day walk · Sample route"))),
          TagBlock([\(q("步行", "On foot")),\(q("艺术", "Art")),\(q("留点空白", "Take your time"))],"sm"),
          ListBlock([
            ListItem(\(q("先看人物与光影", "Figures and light")),\(q("从轮廓开始，再走近看细节。", "Start with the silhouette, then look closer.")),{src:"/detail.jpg",alt:\(q("雕塑照片", "Sculpture photograph"))},\(q("查看资料", "View source")),@OpenUrl("https://www.metmuseum.org/art/collection")),
            ListItem(\(q("再读器物的纹理", "Texture and material")),\(q("一件小物，也有值得停留的故事。", "Small objects have stories worth pausing for.")),{src:"/object.jpg",alt:\(q("器物照片", "Object photograph"))})
          ],"image"),
          Map([{id:"gallery",title:\(q("第一处展馆", "First gallery")),lat:30.245,lng:120.164,imageSrc:"/detail.jpg"},{id:"collection",title:\(q("第二处收藏", "Second collection")),lat:30.251,lng:120.172,imageSrc:"/object.jpg"}],[],$place,"regular","gcj02"),
          TextContent(\(q("地点、路线与照片用于组件组合演示。", "Places, routes and photos are sample content.")),"small")
        ],"column","l")
        """
    case "scene-itinerary":
      title = text("安排一天行程", "Plan your day")
      source = """
        root=Stack([
          InlineHeader(\(q("两天，慢一点走", "Two days, at your own pace"))),
          OverviewCardBlock([
            OverviewCardItem("days",IconText(Icon("calendar"),"neutral","m",\(q("行程", "Trip"))),MetricIndicatorInline("2",\(q("天", "days")))),
            OverviewCardItem("stops",IconText(Icon("map-pin"),"neutral","m",\(q("停留", "Stops"))),MetricIndicatorInline("4",\(q("处", "places"))))
          ]),
          Tabs([
            TabItem("day1",\(q("第一天", "Day 1")),[
              InlineHeader(\(q("街区与展馆", "Neighborhoods and galleries"))),
              Steps([StepsItem("09:30",\(q("走一段街区", "Walk through the neighborhood"))),StepsItem("11:00",\(q("留时间看展", "Take time for an exhibition"))),StepsItem("14:00",\(q("坐下来休息", "Stop for a break")))])
            ]),
            TabItem("day2",\(q("第二天", "Day 2")),[
              InlineHeader(\(q("沿水边散步", "A walk by the water"))),
              Steps([StepsItem("10:00",\(q("看一组收藏", "Explore a collection"))),StepsItem("13:30",\(q("沿水边慢走", "Follow the waterfront")))]),
              Map([{id:"start",title:\(q("起点", "Start")),lat:30.245,lng:120.164},{id:"end",title:\(q("终点", "Finish")),lat:30.251,lng:120.172}],[[{lat:30.245,lng:120.164},{lat:30.251,lng:120.172}]],null,"compact","gcj02",{})
            ])
          ]),
          TextCallout("neutral",\(q("留一点余地", "Leave some room")),\(q("先确定想看的，再给临时发现留时间。", "Choose what matters and leave time for discoveries.")))
        ],"column","l")
        """
    case "scene-compare":
      title = text("比较几个方案", "Compare your options")
      source = """
        $choice="easy"
        root=Stack([
          InlineHeader(\(q("选一个适合今天的节奏", "Choose a pace for today")),\(q("示例方案 · 同一组数据，不同的表达", "Sample options · One dataset, different views"))),
          Table([Col(\(q("方案", "Option")),[\(q("轻松", "Easy")),\(q("充实", "Full")),\(q("深入", "In depth"))]),Col(\(q("停留", "Stops")),[2,4,3],"number"),Col(\(q("预算", "Budget")),[120,240,180],"number")]),
          BarChart([\(q("轻松", "Easy")),\(q("充实", "Full")),\(q("深入", "In depth"))],[Series(\(q("预算", "Budget")),[120,240,180])],"grouped"),
          ListBlock([ListItem(\(q("轻松", "Easy")),\(q("两处停留，留足休息时间。", "Two stops, with plenty of time to rest.")),null,null,@Set($choice,"easy")),ListItem(\(q("充实", "Full")),\(q("多走几处，内容更丰富。", "More stops and more variety.")),null,null,@Set($choice,"full"))]),
          TextContent($choice=="easy"?\(q("当前选择：轻松", "Selected: Easy")):\(q("当前选择：充实", "Selected: Full")),"small-heavy")
        ],"column","l")
        """
    case "scene-preferences":
      title = text("设置偏好与条件", "Set your preferences")
      source = """
        $saved=false
        root=Stack([
          InlineHeader(\(q("按你的习惯来", "Make it work for you"))),
          Form("preferences",Buttons([Button(\(q("保存偏好", "Save preferences")),@Set($saved,true))]),[
            FormControl(\(q("称呼", "Name")),Input("name",\(q("怎么称呼你", "What should we call you?")),"text")),
            FormControl(\(q("兴趣", "Interests")),CheckBoxGroup("interests",[CheckBoxItem(\(q("艺术", "Art")),null,"art"),CheckBoxItem(\(q("街区", "Neighborhoods")),null,"streets"),CheckBoxItem(\(q("自然", "Nature")),null,"nature")],null,{art:true})),
            FormControl(\(q("节奏", "Pace")),Select("pace",[SelectItem("easy",\(q("轻松", "Easy"))),SelectItem("full",\(q("充实", "Full")))],\(q("选择节奏", "Choose a pace")),null,"easy")),
            FormControl(\(q("日期", "Date")),DatePicker("date","single",null,"2026-10-25")),
            FormControl(\(q("预算区间", "Budget range")),Slider("budget","continuous",0,1000,50,[200,600],\(q("预算", "Budget")))),
            FormControl(\(q("补充说明", "Notes")),TextArea("notes",\(q("还有什么想法", "Anything else?")),2))
          ]),
          Callout("success",\(q("已保存", "Saved")),\(q("偏好保留在本次示例中。", "Preferences are saved for this example.")),$saved)
        ],"column","l")
        """
    case "scene-reading":
      title = text("阅读一份资料", "Read and explore")
      source = """
        root=Stack([
          InlineHeader(\(q("从一处细节读进去", "Start with a detail"))),
          ListBlock([ListItem(\(q("人物与光影", "Figures and light")),\(q("先看整体，再观察表面的起伏。", "Look at the whole, then the surface.")),{src:"/detail.jpg",alt:\(q("雕塑", "Sculpture"))}),ListItem(\(q("材质与时间", "Material and time")),\(q("从纹理寻找使用留下的痕迹。", "Look for traces of use in the texture.")),{src:"/object.jpg",alt:\(q("器物", "Object"))})],"image"),
          Separator(),
          InlineHeader(\(q("换一个观察角度", "Another perspective"))),
          TextContent(\(q("轮廓、纹理和光线，是理解一件作品的三个入口。", "Shape, texture and light offer three ways into an object."))),
          ImageGallery([{src:"/detail.jpg",alt:\(q("人物细节", "Figure detail"))},{src:"/object.jpg",alt:\(q("器物细节", "Object detail"))}]),
          EntityList([{left:\(q("照片来源", "Photo source")),right:"The Met Open Access"}]),
          ListBlock([ListItem(\(q("查看馆藏资料", "Explore the collection")),"metmuseum.org",null,null,@OpenUrl("https://www.metmuseum.org/art/collection"))])
        ],"column","l")
        """
    case "scene-budget":
      title = text("查看预算与数据", "Understand your budget")
      source = """
        root=Stack([
          InlineHeader(\(q("钱花在哪里", "Where the budget goes")),\(q("两日预算 · 示例数据", "Two-day budget · Sample data"))),
          Stack([MetricIndicatorInline("¥640",\(q("总预算", "Total budget"))),MetricIndicatorInline("¥320",\(q("每日均额", "Daily average")))],"row","l","start","between",true),
          Separator(),
          InlineHeader(\(q("费用构成", "Breakdown"))),
          PieChart([\(q("交通", "Transport")),\(q("餐饮", "Food")),\(q("门票", "Admission")),\(q("其他", "Other"))],[120,240,180,100],"donut"),
          InlineHeader(\(q("每天的安排", "Day by day"))),
          BarChart([\(q("第一天", "Day 1")),\(q("第二天", "Day 2"))],[Series(\(q("餐饮", "Food")),[120,120]),Series(\(q("体验", "Activities")),[160,140])],"grouped"),
          Table([Col(\(q("项目", "Category")),[\(q("交通", "Transport")),\(q("餐饮", "Food")),\(q("门票", "Admission")),\(q("其他", "Other"))]),Col(\(q("金额", "Amount")),[120,240,180,100],"number")])
        ],"column","l")
        """
    default: return nil
    }
    return ReviewProgram(id: id, title: title, source: source)
  }
}
