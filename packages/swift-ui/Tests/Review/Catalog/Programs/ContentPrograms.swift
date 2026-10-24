import Foundation

// Fixed ordinary DSL programs. All layout and interaction use the shipped SDK.
extension ReviewPrograms {
  static let reading: [ReviewProgram] = [
    .init(
      id: "progressive-reading", title: "摘要、展开与来源",
      source: """
        root=Stack([
          InlineHeader("从一处细节开始","观察、记录，再继续探索。"),
          ListBlock([ListItem("石刻的结构与光影","观察 12 分钟 · 先看人物姿态，再留意凿刻痕迹。",{src:"https://sdk-fixture.invalid/detail.jpg",alt:"摘要参考照片"},"打开资料页",@OpenUrl("https://you.ctrip.com/sight/hangzhou14/48020.html"))],"image"),
          Buttons([
            Button($expanded?"收起细节":"展开细节",@Set($expanded,!$expanded),"secondary"),
            Button("打开阅读视图",@Set($reader,true),"secondary")
          ]),
          Button("标记线索",@Set($marked,true),"tertiary"),
          TextContent($marked?"已标记":"未标记","small"),
          $expanded?MarkDownRenderer("### 完整观察说明\\n先从人物轮廓与空间关系看整体，再观察凿刻留下的痕迹。不同光照会改变线条的深浅，同一处细节可以换个角度继续观察。这段完整说明在独立的内容区自然换行，摘要中的参考照片和关键线索仍保留在原处。\\n\\n参考照片的出处保留在原始资料页中。这里展开固定的观察内容，不请求新的事实。","clear"):null,
          Modal("观察资料",$reader,[
            TextContent("更完整的阅读空间","large-heavy"),
            TextContent("从轮廓、姿态与空间关系开始，再留意材质和使用痕迹。完整说明单独阅读，结束后可以回到原来的摘要与本地选择。"),
            TextContent("固定参考内容，仅用于通用原生交互验收。","small")
          ]),
          TextContent("继续探索其他线索","small")
        ],"column","m")
        $expanded=false
        $reader=false
        $marked=false
        """),
    .init(
      id: "images", title: "图片与正文组合",
      source: """
        root=Stack([
          Stack([
            TextContent("从图像，读到更多细节", "large-heavy"),
            TextContent("固定离线图片，验证真实图文排版。", "small"),
          ],"column","s"),
          ImageBlock("/detail.jpg", "石刻照片"),
          InlineHeader("让图片和文字各有位置", "辅助说明保持简短，正文自然换行。"),
          ListBlock([
            ListItem("留意石刻的构图", "图像提供直观印象，文字补充值得观察的细节。", {src:"/detail.jpg",alt:"石刻细节"}),
            ListItem("读一件器物的纹理", "较长的标题和说明也应该保持对齐与舒适的阅读宽度。", {src:"/object.jpg",alt:"器物照片"})
          ],"image"),
          MarkDownRenderer("![Markdown 石刻照片](/detail.jpg)","clear"),
          InlineHeader("一起看两张图"),
          ImageGallery([{src:"/object.jpg",alt:"器物",details:"一件器物的形状与纹理"},{src:"/detail.jpg",alt:"石刻",details:"从局部观察细节"}])
        ],"column","l")
        """),
    .init(
      id: "media-text", title: "媒体、摘要与展开详情",
      source: """
        root=CompositeCardBlock([
          CompositeCardItem("reading",
            ImageTextLarge("https://sdk-fixture.invalid/detail.jpg", "横幅石刻照片", "从一处细节，读懂一件作品及其背后的故事", "观察、记录，然后继续探索。"),
            [Text("text", "**重点**：先看构图，再留意表面的纹理与光线。"),
             ImageText("https://sdk-fixture.invalid/object.jpg", "器物缩略图", "另一个观察角度", "*同一组内容*，保持简短。"),
             Accordion([AccordionItem("more", "展开观察方法", [
               Text("text", "完整说明保留在这里，可以反复展开和收起，不占据摘要的阅读空间。"),
               SVG("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 480 180'><rect width='480' height='180' rx='20' fill='#f1f5f9'/><path d='M48 132 Q160 20 244 94 T432 45' fill='none' stroke='#3977dd' stroke-width='6'/><circle cx='48' cy='132' r='10' fill='#3977dd'/><circle cx='432' cy='45' r='10' fill='#3977dd'/><text x='28' y='38' font-size='20' fill='#202124'>Explore at your pace</text></svg>",null,"节奏与路径示意"),
               WebView("<html><meta name='viewport' content='width=device-width,initial-scale=1'><body style='margin:0;padding:16px;font:16px -apple-system;background:#f3f4f6;border-radius:12px'><strong>Explore another perspective</strong><p>One detail can open a new direction.</p></body></html>",null,"延伸阅读")
             ])])],
            {price:BoldText("number", "12.8k", "+18%", "metric"),button:Button("打开来源了解更多",@OpenUrl("https://example.com/source"),"secondary")})
        ],"grid",true)
        """),
    .init(
      id: "media-states", title: "图片资源与可用状态",
      source: """
        $count=0
        photos=[
          {src:"/detail.jpg?gallery=0",alt:"参考照片一",details:"固定参考：石刻与光影"},
          {src:"/object.jpg?gallery=1",alt:"参考照片二",details:"固定参考：器物与纹理"},
          {src:"/detail.jpg?gallery=2",alt:"参考照片三",details:"固定参考：另一处细节"},
          {src:"/object.jpg?gallery=3",alt:"参考照片四"},
          {src:"/detail.jpg?gallery=4",alt:"参考照片五"},
          {src:"/object.jpg?gallery=5",alt:"参考照片六"},
          {src:"/detail.jpg?gallery=6",alt:"参考照片七"},
          {src:"/object.jpg?gallery=7",alt:"参考照片八"},
          {src:"/detail.jpg?gallery=8",alt:"参考照片九"}
        ]
        $visiblePhotos=photos
        root=Stack([
          TextContent("图片与内容各就其位","large-heavy"),
          TextContent("固定参考照片仅用于原生状态验收。","small"),
          Image("独立参考照片","/detail.jpg?slot=image"),
          ImageBlock("/detail.jpg?slot=block","正文参考照片"),
          ImageTextLarge("/object.jpg?slot=banner","横幅参考照片","观察作品的细节","这段摘要在图片不可用时仍应保留。"),
          ImageText("/object.jpg?slot=thumbnail","识别参考照片","识别对象","简短文字保持对齐。"),
          InlineHeader("参考图库"),
          ImageGallery($visiblePhotos),
          Buttons([
            Button("清空图库",@Set($visiblePhotos,[]),"tertiary"),
            Button("只看一张",@Set($visiblePhotos,[photos[0]]),"secondary"),
            Button("恢复图集",@Set($visiblePhotos,photos),"secondary")
          ]),
          TextContent("正文继续阅读","large-heavy"),
          TextContent("资源状态不会修改内容事实，也不会重置这里的本地选择。"),
          Button("保留本地选择",@Set($count,1),"secondary"),TextContent(""+$count)
        ],"column","l")
        """),
  ]
  static let actions: [ReviewProgram] = [
    .init(
      id: "action-layout", title: "内容卡片与操作层级",
      source: """
        $read=false
        $saved=false
        root=Stack([
          Stack([
            TextContent("给一处细节，多一点时间","large-heavy"),
            TextContent("观察札记 · 从整体到局部","small")
          ],"column","s"),
          CompositeCardBlock([
            CompositeCardItem("detail",Image("石刻参考照片","/detail.jpg"),[
              Text("text","光线经过，细节浮现","先看人物与空间的关系，再留意石面上的凿刻痕迹。相同的作品，换一个角度又是新的发现。")
            ],{button:Button("阅读介绍",@Set($read,true),"secondary")})
          ],"grid",true),
          $read?MarkDownRenderer("### 从整体到局部\\n目光先停在轮廓上，再沿着衣纹、手势与石面的起伏慢慢移动。光线照亮的地方和阴影里的细节，一起构成了作品的表情。\\n\\n不必一次看懂所有线索，记住最触动你的一处就好。","clear"):null,
          Separator(),
          TextContent("想继续看，或留到有空的时候。","small"),
          Buttons([
            Button("继续探索",@ToAssistant("继续探索")),
            Button($saved?"已收藏":"留待以后",@Set($saved,!$saved),"secondary"),
            Button("查看来源",@OpenUrl("https://example.com/source"),"tertiary")
          ])
        ],"column","l")
        """),
    .init(
      id: "action-sizes", title: "按钮尺寸、容器与显式覆盖",
      source: """
        $chosen="未操作"
        root=Stack([
          InlineHeader("同一套操作尺度","容器只提供默认密度，显式尺寸优先。"),
          Card([
            CardHeader("卡片中的操作"),
            Buttons([
              Button("内嵌操作",@Set($chosen,"内嵌")),
              Button("中号操作",@Set($chosen,"中号"),"primary","normal","medium")
            ]),
            Button("大号操作",@Set($chosen,"大号"),"secondary","normal","large")
          ]),
          Buttons([
            Button("独立操作",@Set($chosen,"独立")),
            Button("辅助操作",@Set($chosen,"辅助"),"secondary"),
            Button("文字操作",@Set($chosen,"文字"),"tertiary")
          ]),
          Buttons([
            Button("最小操作",@Set($chosen,"最小"),"secondary","normal","extra-small"),
            Button("小号操作",@Set($chosen,"小号"),"secondary","normal","small")
          ]),
          Card([Form("example",Buttons([Button("提交表单",@Set($chosen,"提交"))]),[
            FormControl("关键词",Input("keyword","输入内容"))
          ])]),
          TextContent($chosen,"small")
        ],"column","m")
        """),
    .init(
      id: "image-cards", title: "图文卡片与操作",
      source: """
        root=Stack([
          TextContent("图文内容与操作", "large-heavy"),
          Stack([
            ImageBlock("/detail.jpg","石刻照片"),
            InlineHeader("普通图文说明", "这一组内容只用于阅读，不承担点击操作。")
          ],"column","s"),
          Separator(),
          InlineHeader("可选择的视觉卡片", "图像、说明和操作属于同一项内容。"),
          VisualCardBlock([
            VisualCardItem(BoldText("text","石刻与光影","在结构与比例之间停留片刻"),"detail","/detail.jpg",Tag("空间"),"石刻照片"),
            VisualCardItem(BoldText("text","器物与纹理","观察材质留下的细节"),"object","/object.jpg",Tag("细节"),"器物照片")
          ],"carousel",true,@ToAssistant("继续介绍选中的内容")),
          InlineHeader("有独立操作的内容卡片"),
          CompositeCardBlock([
            CompositeCardItem("first",Image("石刻照片","/detail.jpg"),[Text("text","细节值得慢慢看","独立按钮保留自己的操作")],{button:Button("阅读介绍",@ToAssistant("阅读介绍"))}),
            CompositeCardItem("second",Image("器物照片","/object.jpg"),[Text("text","从一个线索开始","内容和操作保持清楚的关系")],{button:Button("查看资料",@ToAssistant("查看资料"))})
          ],"carousel",true,@ToAssistant("选择复合项"))
        ],"column","l")
        """),
  ]
}
