import Foundation

// Fixed ordinary DSL programs. All layout and interaction use the shipped SDK.
extension ReviewPrograms {
  static let structuredData: [ReviewProgram] = [
    .init(
      id: "rich-table", title: "多元素表格",
      source: """
        imageNote="用缩略图辅助识别，短文字说明值得关注的细节。"
        metricNote="把主要数值与单位放在一起，比较时保留相同口径。"
        chartNote="用紧凑图形比较数量，点选数据查看对应说明。"
        diagramNote="用矢量图解释关系，说明文字保持简短。"
        root=Stack([
          TextContent("不同信息，清晰比较", "large-heavy"),
          TextContent("图文、数值与趋势各有位置。点按类别查看说明，表格专注阅读。", "small"),
          Table([
            Col("类别",[
              Popover(Stack([Icon("image"),TextContent("图文信息","small-heavy")],"column","xs"),Stack([TextContent("图文信息","small-heavy"),TextContent(imageNote)],"column","s"),"图文信息说明"),
              Popover(Stack([Icon("clock"),TextContent("数值摘要","small-heavy")],"column","xs"),Stack([TextContent("数值摘要","small-heavy"),TextContent(metricNote)],"column","s"),"数值摘要说明"),
              Popover(Stack([Icon("chart-bar-increasing"),TextContent("数据图表","small-heavy")],"column","xs"),Stack([TextContent("数据图表","small-heavy"),TextContent(chartNote)],"column","s"),"数据图表说明"),
              Popover(Stack([Icon("route"),TextContent("结构示意","small-heavy")],"column","xs"),Stack([TextContent("结构示意","small-heavy"),TextContent(diagramNote)],"column","s"),"结构示意说明")
            ]),
            Col("说明",[TextContent(imageNote,"small"),TextContent(metricNote,"small"),TextContent(chartNote,"small"),TextContent(diagramNote,"small")]),
            Col("预览",[
              Stack([Image("石刻细节","/detail.jpg"),TextContent("从整体读到细节","small"),Tag("值得细看")],"column","s"),
              Stack([MetricIndicatorInline("45","分钟停留"),MetricIndicatorWithStrikethrough("80","参考票价","100")],"column","s"),
              BarChart(["一","二","三"],[Series("趋势",[2,4,3])],"grouped",null,null,130),
              SVG("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 180 72'><path d='M20 52 Q90 -4 160 28' fill='none' stroke='#6b8caa' stroke-width='3' stroke-dasharray='6 5'/><circle cx='20' cy='52' r='8' fill='#3a6ee8'/><circle cx='160' cy='28' r='8' fill='#2d8a7c'/></svg>",null,"两处线索的关系示意")
            ])
          ]),
          TextContent("轻量内容可自由组合；地图与完整详情放在表格之外。","small")
        ],"column","l")
        """),
    .init(
      id: "tables", title: "表格的窄屏适配",
      source: """
        root=Stack([
          Stack([TextContent("两种节奏", "large-heavy"),TextContent("简短信息直接比较，较宽的数据可横向查看。", "small")],"column","s"),
          Table([Col("方案",["轻松","充实"]),Col("每日安排",[2,4],"number"),Col("建议",["留出空白","多一点探索"])]),
          InlineHeader("更多维度"),
          Table([Col("内容",["阅读","创作","整理","归档与回顾：整理完以后再继续"]),Col("数量",[2,4,3,1],"number"),Col("时长",["30 分钟","1 小时","20 分钟","10 分钟"]),Col("方式",["独立完成","一起讨论","独立完成","回顾笔记"]),Col("备注",["先从喜欢的内容开始","给新想法留出空间","保留一个重要线索","把新发现整理成可以继续阅读的线索，较长的说明应完整显示。"])]) ,
          InlineHeader("分页浏览"),
          Table([Col("记录",["记录 01","记录 02","记录 03","记录 04","记录 05","记录 06","记录 07","记录 08","记录 09","记录 10",Stack([Icon("wheat"),TextContent("记录 11")],"row","s")])])
        ],"column","l")
        """),
  ]
  static let charts: [ReviewProgram] = [
    .init(
      id: "data", title: "数据与图表",
      source: """
        slices=[Slice("阅读",9.5),Slice("创作",9.5),Slice("整理",3)]
        root=Stack([
          Stack([
            TextContent("一周的专注时间", "large-heavy"),
            TextContent("周一至周五 · 留下投入，也看见节奏。", "small"),
          ],"column","s"),
          Stack([
            MetricIndicatorInline("22", "小时投入"),
            MetricIndicatorInline("5", "专注日")
          ],"row","l","start","between",true),
          Separator(),
          InlineHeader("每天的投入", "阅读与创作 · 小时"),
          BarChart(["周一","周二","周三","周四","周五"],[Series("阅读",[1,2,1.5,3,2]),Series("创作",[2,1,2.5,1,3])],"grouped",null,null,220),
          Card([
            CardHeader("时间花在哪里", "阅读和创作各占 9.5 小时，其余留给整理。"),
            PieChart(slices.props.category,slices.props.value,"donut"),
            Table([Col("方向",["阅读","创作","整理"]),Col("小时",[9.5,9.5,3],"number")])
          ])
        ],"column","l")
        """),
    .init(
      id: "chart-trends", title: "趋势、面积与多维比较",
      source: """
        root=Stack([
          InlineHeader("同一组数据，不同观察角度"),
          Card([CardHeader("趋势"),LineChart(["一","二","三"],[Series("阅读",[2,4,3])])]),
          Card([CardHeader("累积投入"),AreaChart(["一","二","三"],[Series("阅读",[2,4,3])])]),
          Card([CardHeader("方向比较"),RadarChart(["观察","记录","回顾"],[Series("本周",[3,5,4])])]),
          Card([CardHeader("横向比较"),HorizontalBarChart(["阅读","创作"],[Series("小时",[4,6])])])
        ],"column","l")
        """),
    .init(
      id: "chart-distributions", title: "分布、占比与相关性",
      source: """
        root=Stack([
          InlineHeader("从总体到单个观察值"),
          Card([CardHeader("占比"),RadialChart(["阅读","创作"],[40,60])]),
          Card([CardHeader("总量构成"),SingleStackedBarChart(["阅读","创作"],[40,60])]),
          Card([CardHeader("关系与分布"),ScatterChart([ScatterSeries("观察值",[Point(1,3),Point(2,5),Point(4,4)])],"时间","数量")])
        ],"column","l")
        """),
  ]
  static let spatial: [ReviewProgram] = [
    .init(
      id: "map", title: "地图与地点选择",
      source: """
        $place="first"
        $included="none"
        first={point:{id:"first",title:"地点一",lat:30.245,lng:120.164},src:"https://sdk-fixture.invalid/detail.jpg",alt:"石刻照片",description:"沿着人物与光线的关系，找一处值得停留的细节。",duration:"建议停留 45 分钟",note:"先在远处看整体，再靠近观察衣纹和凿刻。留一点时间，把最吸引你的一处记下来。"}
        second={point:{id:"second",title:"地点二",lat:30.251,lng:120.172},src:"https://sdk-fixture.invalid/object.jpg",alt:"器物照片",description:"从材质与纹理理解器物，说明自然换行，卡片高度跟随内容。",duration:"建议停留 30 分钟",note:"从轮廓、比例和表面痕迹出发，试着想象一件物品如何进入当时的日常生活。"}
        current=$place=="first"?first:second
        route=[{lat:30.245,lng:120.164},{lat:30.248,lng:120.168},{lat:30.251,lng:120.172}]
        root=Stack([
          Stack([TextContent("地图与地点", "large-heavy"),TextContent("两处线索，一段从容的午后。", "small")],"column","s"),
          Map([first.point,second.point],[route],$place,"regular","gcj02",{
            first:Card([Stack([
              ImageText(first.src,first.alt,"地点一详情",first.description,true,"horizontal",64),
              TextContent(first.duration+" · 慢慢观察","small")
            ],"column","s")]),
            second:Card([Stack([
              ImageText(second.src,second.alt,"地点二详情",second.description,true,"horizontal",64),
              TextContent(second.duration+" · 留意纹理","small")
            ],"column","s")])
          }),
          Tabs([
            TabItem("notes","观察线索",[
              TextContent("正在查看："+current.point.title,"small-heavy"),
              MarkDownRenderer(current.note,"clear"),
              EntityList([{left:"停留",right:current.duration},{left:"安排",right:"不赶时间，保留一点空白"}],"small")
            ]),
            TabItem("prepare","行前准备",[
              CompositeCardBlock([CompositeCardItem("prepare",null,[
                ListBlock([
                  ListItem("确认当天开放信息","出发前核对实际开放与预约要求。"),
                  ListItem("留出途中与休息时间","地图只展示给定路线，不替你作实时出行判断。")
                ],"number","small")
              ],{button:Button($included==$place?"已在当前计划中":"加入当前计划",@Set($included,$place),"secondary")})]),
              $included==$place?TextContent("计划已加入："+current.point.title,"small"):null
            ])
          ]),
          Button("选择地点二",@Set($place,"second"),"tertiary"),
          TextContent("示例坐标与路线用于交互展示，不代表真实导航建议。","small")
        ],"column","l")
        """),
    .init(
      id: "map-tabs", title: "地图按分组组合",
      source: """
        root=Stack([
          TextContent("两组地点", "large-heavy"),
          Tabs([
            TabItem("first","第一组",[
              Map([{id:"one",title:"第一处",lat:30.245,lng:120.164}],[],null,"compact","gcj02")
            ]),
            TabItem("second","第二组",[
              Map([{id:"two",title:"第二处",lat:30.251,lng:120.172}],[],null,"compact","gcj02")
            ])
          ])
        ],"column","l")
        """),
    .init(id: "map-places", title: "地点与默认信息卡", source: """
      $place="a"
      places=[
        {id:"a",title:"街角展馆",subtitle:"建筑与展陈 · 留意细节",imageSrc:"/detail.jpg",icon:"building.columns",lat:30.245,lng:120.164},
        {id:"b",title:"河畔书屋",subtitle:"在水边，留一点阅读时间",imageSrc:"/object.jpg",icon:"book.closed",lat:30.251,lng:120.172},
        {id:"c",title:"一处没有图片的地点",lat:30.248,lng:120.167}
      ]
      root=Stack([
        TextContent("把地点放回地图","large-heavy"),
        TextContent("点按图标，或横滑地点卡片。信息来自同一组地点。","small"),
        Map(places,[],$place,"regular","gcj02"),
        TextContent("当前地点："+$place,"small"),
        TextContent("坐标为 SDK 交互示例；没有提供评分、实时路线或开放信息。","small")
      ],"column","m")
      """),
  ]
}
