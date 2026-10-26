import Foundation

/// Finite feed/lifecycle fixtures, kept outside the 25 composition variants.
enum ReviewStreamingPrograms {
  static let modal = """
    $open=true
    root=Stack([
      TextContent("Streamed presentation"),
      Modal("Streaming details",$open,[TextContent("The stream is still receiving content.")])
    ])
    """
  static let tabs = """
    root=Tabs([
      TabItem("a","First",[TextContent("The first pane arrives before the other panes.")]),
      TabItem("b","Second",[TextContent("The second pane grows as more text arrives.")]),
      TabItem("c","Third",[TextContent("The third pane completes the streamed response.")])
    ])
    """
  static func lifecycle(language: ReviewLanguage) -> String { """
    $show=false
    $count=10
    root=Stack([$show?TextContent("\(language.text("前置内容已到达"))"):null,tabs,details,pages,
      TextContent("Count: "+$count),Button("Add two",@Set($count,$count+2),"secondary"),
      Button("Show prefix",@Set($show,true),"secondary"),table],"column","m")
    tabs=Tabs([a,b])
    a=TabItem("a","\(language.text("方案一 · 完整的中文长标题"))",[TextContent("First panel content")])
    b=TabItem("b","\(language.text("方案二 · 另一个完整的中文标题"))",[TextContent("Second panel content")])
    details=Accordion([itemA])
    itemA=AccordionItem("one","Stable details",[TextContent("Detail one content")])
    pages=Carousel([[pageA],[pageB]])
    pageA=Card([TextContent("Page A")])
    pageB=Card([TextContent("Page B")])
    table=Table([Col("Rows",["Row 1","Row 2","Row 3","Row 4","Row 5","Row 6","Row 7","Row 8","Row 9","Row 10","Row 11"])])
    """ }
  static func patch(stage: Int, language: ReviewLanguage) -> String {
    let count = stage == 2 ? 1 : 36
    let values = (1...count).map { "\"Row \($0)\"" }.joined(separator: ",")
    return """
      tabs=Tabs([a,b,c])
      c=TabItem("c","\(language.text("方案三 · 后续追加的完整标题"))",[TextContent("Third panel content")])
      details=Accordion([itemA,itemB])
      itemB=AccordionItem("two","New details",[TextContent("Detail two content")])
      pages=Carousel([[pageA],[pageB],[pageZero]])
      pageZero=Card([TextContent("New leading page")])
      table=Table([Col("Rows",[\(values)])])
      """
  }
  static let gallery = """
    root=Stack([TextContent("Gallery lifecycle"),photos])
    photos=ImageGallery([{src:"/detail.jpg",alt:"Photo A"},{src:"/object.jpg",alt:"Photo B"}])
    """
  static let galleryAppend = """
    photos=ImageGallery([{src:"/detail.jpg",alt:"Photo A"},{src:"/object.jpg",alt:"Photo B"},{src:"/detail.jpg?third=1",alt:"Photo C"}])
    """
}

extension ReviewStreamingPrograms {
  /// A focused layout regression, outside the six authored task scenes.
  static let resizingCarousel = """
    $expanded=false
    detail=$expanded?"这是一段在组件挂载后增长的中文说明，用于验证标题、正文和操作区的真实测量高度。内容变化后，后续区段仍应从完整卡片下方开始，不应与价格、按钮重叠。保留足够的阅读空间，让换行由实际容器宽度决定。":"简短的初始说明。"
    root=Stack([
      CompositeCardBlock([a,b,c],"carousel",true),
      InlineHeader("Following section"),
      TextContent("The section stays below the complete carousel."),
      Button("Grow details",@Set($expanded,!$expanded),"secondary")
    ],"column","l")
    a=CompositeCardItem("a",IconText(Icon("book"),"soft","m","一段可以完整阅读的长标题与内容","辅助信息应在实际宽度中自然换行。",true),[Text("text",detail)],{price:BoldText("number","100"),button:Button("First action")})
    b=CompositeCardItem("b",IconText(Icon("clock"),"soft","m","第二张卡片标题","较短的辅助信息",true),[Text("text",detail+detail)],{price:BoldText("number","200"),button:Button("Second action")})
    c=CompositeCardItem("c",IconText(Icon("image"),"soft","m","第三张卡片，用来检查切页后的边界","辅助信息在这里也可能比前两页更长一些。",true),[Text("text",detail)],{price:BoldText("number","300"),button:Button("Third action")})
    """
}