import Foundation

// Fixed ordinary DSL programs. All layout and interaction use the shipped SDK.
extension ReviewPrograms {
  static let layout: [ReviewProgram] = [
    .init(
      id: "adaptive-card", title: "卡片动态布局",
      source: """
        $layout="row"
        $wrap=false
        $detail="先看一处细节。"
        root=Stack([
          TextContent("通用卡片，动态组合", "large-heavy"),
          Stack([
            Button("横向排列",Action([@Set($layout,"row"),@Set($wrap,false)]),"secondary"),
            Button("纵向排列",@Set($layout,"column"),"secondary"),
            Button("允许换行",Action([@Set($layout,"row"),@Set($wrap,true)]),"secondary"),
            Button("展开说明",@Set($detail,"图像与说明来自同一个通用容器。文字变长时自然换行，卡片高度跟随内容增长。模型可以选择横向、纵向或允许换行的排列，而不需要为每一种内容新增组件。"),"secondary")
          ],"row","s","start","start",true),
          Card([
            Image("通用卡片图片","https://sdk-fixture.invalid/detail.jpg"),
            Stack([TextContent("同一张卡片","large-heavy"),TextContent($detail)],"column","s")
          ],"card",$layout,"m","start","start",$wrap)
        ],"column","l")
        """),
    .init(
      id: "adaptive-images", title: "动态文案与缩略图",
      source: """
        $detail="看一处细节。"
        root=Stack([
          Stack([TextContent("让图片跟随内容", "large-heavy"),TextContent("同一行文字变化后，重新排版。", "small")],"column","s"),
          Buttons([Button("展开文字",@Set($detail,"留意人物的姿态、凿刻的痕迹，以及光线如何改变空间。换一个角度，观察石面的细节，再把自己的发现记下来。文字自然换行，图片不会用固定高度撑开这一行。"),"secondary"),Button("收起文字",@Set($detail,"看一处细节。"),"secondary")]),
          ListBlock([ListItem("内容会变化",$detail,{src:"https://sdk-fixture.invalid/detail.jpg",alt:"自适应缩略图"})],"image"),
          InlineHeader("不同长度也能自然排列"),
          ListBlock([
            ListItem("留意石刻的构图","图像提供直观印象，文字补充值得观察的细节。",{src:"https://sdk-fixture.invalid/detail.jpg",alt:"石刻行缩略图"}),
            ListItem("读一件器物的纹理","较长的标题和说明也应该保持对齐与舒适的阅读宽度。",{src:"https://sdk-fixture.invalid/object.jpg",alt:"器物行缩略图"})
          ],"image")
        ],"column","l")
        """),
    .init(
      id: "composition", title: "发现内容与图文阅读",
      source: """
        $focus="stone"
        $expanded=false
        $saved="none"
        stone={title:"石刻中的结构与光影",subtitle:"留意人物的姿态、凿刻的痕迹，以及光线如何改变空间。",src:"https://sdk-fixture.invalid/detail.jpg",alt:"石刻照片",category:"空间与造型",duration:"约 8 分钟",note:"先退后一步看人物之间的关系，再走近观察衣纹和手势。石面的起伏接住了光，也留下了当时凿刻的顺序。",question:"哪一处阴影，让原本平面的石壁有了深度？"}
        vessel={title:"器物上的纹理与时间",subtitle:"从材质、比例和使用痕迹，理解物件与日常生活的关系。",src:"https://sdk-fixture.invalid/object.jpg",alt:"器物照片",category:"材质与日常",duration:"约 6 分钟",note:"先看轮廓，再看表面。光滑的边缘、细小的缺口和层层叠起的纹理，让一件安静的物品留下了被使用的线索。",question:"如果不看说明，你会猜它曾经怎样被拿起和使用？"}
        current=$focus=="stone"?stone:vessel
        root=Stack([
          Stack([TextContent("从一处细节，开始探索", "large-heavy"),TextContent("石刻与器物 · 给好奇心留一点时间", "small")],"column","s"),
          ImageBlock(current.src, current.alt),
          Stack([
            TagBlock([current.category,current.duration],"sm"),
            TextContent(current.title,"large"),
            TextContent(current.subtitle)
          ],"column","s"),
          Buttons([
            Button("看石刻",@Set($focus,"stone"),$focus=="stone"?"primary":"secondary","normal","small"),
            Button("看器物",@Set($focus,"vessel"),$focus=="vessel"?"primary":"secondary","normal","small")
          ]),
          Separator(),
          InlineHeader("值得仔细看的两件事", "先看整体，再从一个局部深入。"),
          ListBlock([
            ListItem(stone.title,stone.subtitle,{src:stone.src,alt:stone.alt},"展开介绍",Action([@Set($focus,"stone"),@Set($expanded,true)])),
            ListItem(vessel.title,vessel.subtitle,{src:vessel.src,alt:vessel.alt},"展开介绍",Action([@Set($focus,"vessel"),@Set($expanded,true)]))
          ],"image"),
          Card([
            CardHeader("当前观察："+current.category,current.question),
            $expanded?MarkDownRenderer(current.note,"clear"):TextContent("带着一个问题，再看一遍眼前的细节。","small"),
            Buttons([
              Button($expanded?"收起观察笔记":"展开观察笔记",@Set($expanded,!$expanded),"tertiary"),
              Button($saved==$focus?"已加入阅读清单":"加入阅读清单",@Set($saved,$focus),"secondary")
            ])
          ],"sunk"),
          $saved==$focus?TextContent("阅读清单已保留："+current.title,"small"):null,
          Button("按兴趣继续探索",@ToAssistant("继续探索"),"tertiary")
        ],"column","l")
        """),
  ]
  static let structure: [ReviewProgram] = [
    .init(
      id: "content", title: "内容与信息层级",
      source: """
        root=Stack([
          Stack([
            TextContent("本周，留一点时间给自己", "large-heavy"),
            TextContent("阅读、记录，让一个想法慢慢成形。", "small"),
          ],"column","s"),
          OverviewCardBlock([
            OverviewCardItem("reading", IconText(Icon("file"), "neutral", "m", "阅读"), MetricIndicatorInline("3", "篇内容")),
            OverviewCardItem("ideas", IconText(Icon("image"), "neutral", "m", "灵感"), MetricIndicatorInline("8", "条记录"))
          ]),
          InlineHeader("值得花时间的事", "从一个感兴趣的方向开始。"),
          ListBlock([
            ListItem("读完，一篇真正感兴趣的文章", "给自己一段不被打断的时间。留下一个问题，比记住每个细节更有意思。", null, "开始阅读", @ToAssistant("阅读建议")),
            ListItem("把零散想法，连成一条线", "翻开最近的记录，找到它们反复提及的那个主题。", null, "整理笔记", @ToAssistant("整理建议"))
          ],"number","small"),
          Accordion([AccordionItem("details", "安排之前，再看看这些", [
            MarkDownRenderer("### 保持一点余地\\n先确定一件值得投入的事，再给临时的发现留出空间。\\n\\n完成之后，用一句话记下：今天，什么让你换了一个角度？","clear")
          ])]),
          TextCallout("neutral", "一个小提醒", "留出空白，也是安排的一部分。")
        ], "column", "l")
        """),
    .init(
      id: "reading-tools", title: "摘要、进度与内容卡片",
      source: """
        root=Stack([
          InlineHeader("把线索整理清楚","同一个场景混合使用摘要、列表、标签与进度。"),
          TagBlock(["已整理","待阅读"]),
          EntityList([{left:"主题",right:"观察与记录"},{left:"当前进度",right:"2 / 3"}],"default"),
          Steps([StepsItem("观察","先理解整体"),StepsItem("记录","留下关键细节"),StepsItem("回顾","把线索串起来")]),
          SnippetCardBlock([SnippetCardItem("notes",IconText(Icon("file"),"neutral","m","记录"),BoldText("number","12"))]),
          ContextCardBlock([ContextCardItem("context","给想法留一点空间","一句摘要建立上下文，更多细节可以在需要时继续阅读。")]),
          MetricIndicatorWithStrikethrough("48","当前数量","52"),
          CodeBlock("swift","let observation = \\\"留意一处细节\\\"")
        ],"column","l")
        """),
    .init(
      id: "carousel", title: "多元素轮播分页",
      source: """
        $variant="card"
        root=Stack([Buttons([Button("卡片样式",@Set($variant,"card"),"secondary"),Button("浅底样式",@Set($variant,"sunk"),"secondary")]),Carousel([
          [TextContent("第一页标题", "large-heavy"), TextContent("同页正文")],
          [TextContent("第二页标题", "large-heavy"), TextContent("第二页正文"),
            ImageText("https://sdk-fixture.invalid/object.jpg","竖排显式图片尺寸","保留显式尺寸",null,false,"vertical",96),
            Stack([Icon("utensils-crossed"),Icon("soup"),Icon("wheat")],"row","m","baseline")]
        ],$variant)])
        """),
  ]
}
