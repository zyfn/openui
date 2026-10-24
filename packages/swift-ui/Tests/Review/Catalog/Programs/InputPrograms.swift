import Foundation

// Fixed ordinary DSL programs. All layout and interaction use the shipped SDK.
extension ReviewPrograms {
  static let forms: [ReviewProgram] = [
    .init(
      id: "choices", title: "选择与表单",
      source: """
        root=Stack([
          Stack([
            TextContent("让内容更适合你", "large-heavy"),
            TextContent("选择感兴趣的方向和阅读方式。", "small"),
          ],"column","s"),
          Form("preferences", Buttons([Button("保存偏好", @ToAssistant("保存偏好"))]), [
            FormControl("你关注哪些方向？", OptionCards("topics", "multiple", [
              OptionCard("design", "设计与创作", "产品、视觉与表达", Icon("image")),
              OptionCard("technology", "科学与技术", "探索方法与新发现", Icon("search")),
              OptionCard("culture", "历史与文化", "理解事物的来处", Icon("globe")),
              OptionCard("daily", "日常与生活", "让每天更有条理", Icon("sun"))
            ], {required:true}, ["design"])),
            FormControl("阅读方式", RadioGroup("detail", [
              RadioItem("简要概览", "先看重要信息", "brief"),
              RadioItem("完整细节", "展开说明与相关资料", "full")
            ], "brief")),
            FormControl("补充偏好", Chips("extras", "multiple", [
              ChipItem("examples", "多举例子"), ChipItem("sources", "附上来源"),
              ChipItem("short", "简短一些"), ChipItem("unavailable", "暂不可用", null, true)
            ])),
            FormControl("希望保留什么？", CheckBoxGroup("keep", [
              CheckBoxItem("资料来源", "方便回到原始内容", "sources"),
              CheckBoxItem("自己的问题", "保留后续探索的方向", "questions")
            ], null, {sources:true}))
          ])
        ], "column", "l")
        """),
    .init(
      id: "controls", title: "输入、筛选与局部状态",
      source: """
        $showInfo=false
        root=Stack([
          InlineHeader("调整当前视图","控件组合在同一个表单内，交互只使用固定测试数据。"),
          Label("阅读偏好"),
          Form("controls",Buttons([Button("保存本地偏好",@Set($showInfo,true))]),[
            FormControl("补充说明",TextArea("notes","写下你的想法",3)),
            FormControl("内容范围",Select("scope",[SelectItem("all","全部内容"),SelectItem("saved","已收藏")],"选择范围",null,"all")),
            FormControl("阅读日期",DatePicker("reading-date","single",null,"2026-10-23")),
            FormControl("阅读时长",Slider("minutes","discrete",5,60,5,[20],"分钟")),
            SwitchGroup("preferences",[SwitchItem("显示补充说明","只影响当前视图","details",true)])
          ]),
          IconButton("查看提示",Icon("info"),@Set($showInfo,true),"secondary"),
          Callout("info","已更新","偏好只保留在本次预览。",$showInfo)
        ],"column","l")
        """),
    .init(
      id: "dialogs", title: "弹层与反馈",
      source: """
        $open=false
        $saved=false
        root=Stack([
          Stack([
            TextContent("操作与反馈", "large-heavy"),
            TextContent("打开详情后完成操作，观察状态反馈。", "small"),
          ],"column","s"),
          Button("打开详情", @Set($open,true)),
          Modal("查看详情",$open,[
            TextContent("内容与操作保持清晰的层级。"),
            Button("完成操作",Action([@Set($open,false),@Set($saved,true)]))
          ]),
          Callout("success","已完成","状态已经更新。",$saved)
        ],"column","l")
        """),
    .init(
      id: "editing", title: "编辑与保存",
      source: """
        root=Stack([
          Stack([
            TextContent("整理一份清单", "large-heavy"),
            TextContent("修改暂存在本地，点击保存后才提交。", "small"),
          ],"column","s"),
          EditableTable("items",[
            {type:"text",key:"title",header:"名称",width:170},
            {type:"number",key:"count",header:"数量",width:100},
            {type:"date-single",key:"date",header:"日期",width:150},
            {type:"select",key:"status",header:"状态",options:[{value:"todo",label:"待处理"},{value:"done",label:"已完成"}]},
            {type:"url",key:"url",header:"链接",width:190}
          ],[
            {id:"first",values:["Notebook",2,"2026-10-22","todo","https://example.com/one"]},
            {id:"second",values:["Pencil",3,"2026-10-23","done","https://example.com/two"]}
          ])
        ],"column","l")
        """),
  ]
}
