import { useState } from "react";
import { ArrowUpRight, ArrowRight } from "lucide-react";
import { sdkBaseline, sdkSource } from "./baseline";

const source = `root = Stack([intro, details, actions], "column", "xl")
intro = TextContent("先看对象，再决定下一步。")
details = Card([CardHeader("对象名称", "必要的说明")])
actions = Buttons([Button("继续了解", @ToAssistant("继续了解"))])`;
const stages = [
  {
    title: "导出契约",
    term: "Library / Schema",
    owner: "客户端实际注册库",
    description:
      "注册库将组件定义与原生实现配对。宿主从实际使用的库导出 prompt、spec 和 schema：Agent 据此选择合法组件，共享核心据此理解生成结果。生成库可以是渲染库的子集。",
    decision:
      "先让模型知道能表达什么，也让渲染器知道每个参数意味着什么。改变主题不需要改变语言；调整生成库则需要重新导出契约。",
    example:
      "组件名 · 位置参数 · 槽位类型\n绑定与动作语义\n实际库 → prompt / spec / schema",
    link: "GenUILib/ComponentLibrary.swift",
  },
  {
    title: "组织回答",
    term: "Declarative UI",
    owner: "服务端 / Agent",
    description:
      "Agent 组织事实、对象、关系与下一步意图，输出声明式 OpenUI Lang。模型选择章节、卡片、字段和动作；字号、对比度、触控区域由 SDK 的既有规则落实。",
    decision:
      "同一段声明可以适应不同空间。示例应教会信息组织，真实价格、链接与库存仍要来自当前工具结果。",
    example: source,
    link: "SDK-REFERENCE.zh-CN.md",
  },
  {
    title: "解析与求值",
    term: "Language Runtime",
    owner: "OpenUILang / 共享语言核心",
    description:
      "每个分片进入同一套解析与求值流程，产生可供呈现的值、引用、绑定和动作。此时后文可能尚未到达：一段文字已成立，另一个具名对象仍未解析。",
    decision:
      "共享核心保留表达式、引用、字符串、绑定与动作的语义，原生侧消费类型化结果。呈现就绪信息帮助判断此刻可显示什么，它不成为 Agent 需要填写的新参数；语言兼容与 UI 排版分别维护。",
    example:
      "intro 已解析：可以继续阅读\ndetails 尚未到达：保留原槽位\n后续引用解析后：更新原位置",
    link: "ARCHITECTURE.md",
  },
  {
    title: "原生呈现",
    term: "Layout / Presentation",
    owner: "OpenUIState / SwiftUI 组件",
    description:
      "OpenUIState 将语言状态投影给原生树。组件读取统一的主题、空间与就绪状态：父级分配宽度，文字在列内增长，图片在资源可用后更新自己的区域。",
    decision:
      "解析成功、布局可确定、资源已加载是不同条件。每次分片更新都要保留已挂载内容的身份与已有状态。",
    example:
      "Theme → 语义样式\nPresentation → 原生几何与动效\n布局就绪 + 稳定身份 → 持续呈现",
    link: "UI-DESIGN.md",
  },
  {
    title: "产生交互",
    term: "State / ActionEvent",
    owner: "组件上下文与当前程序",
    description:
      "输入与选择写回当前字段状态，提交读取最新值。动作带上当前对象、formName、formState 和动作上下文；就绪、校验、来源版本及操作意图共同决定能否触发。",
    decision:
      "控件看起来可点与动作可以执行需要一致。滚动、预览、选择和提交有各自作用域，旧界面的回调不能操作新回答。",
    example:
      "当前选择 → 字段状态\n校验与来源检查 → ActionEvent\n继续对话时保留选择与对象上下文",
    link: "Context/ComponentContext.swift",
  },
  {
    title: "回到宿主",
    term: "Host Integration",
    owner: "客户端与服务端",
    description:
      "宿主负责资源权限、消息生命周期、外部导航与业务执行，将继续对话所需的上下文送回 Agent。SDK 提供事件与消息封装，真实执行结果再成为下一次回答的输入。",
    decision:
      "本地状态改变、动作已发出、业务成功分别确认。当前客户端依赖和实际导出决定接入状态，发布了一个 SDK 版本不能替代端到端验收。",
    example:
      "ActionEvent → 宿主处理\nbuildMessage / parseMessage → 既有消息通道\n真实结果 → 后续回答",
    link: "README.md#6-交互围绕一个明确任务",
  },
];

export function WorkingPrinciple() {
  const [stage, setStage] = useState(0);
  const selected = stages[stage];
  return (
    <section className="section" id="principle">
      <div className="chapter-heading">
        <p className="eyebrow">01 / HOW THE SYSTEM WORKS</p>
        <h2>从一段语言，到一个可以行动的界面。</h2>
        <p>
          生成式界面同时发生两件事：内容仍在抵达，用户已经开始阅读。系统需要把声明、状态与呈现连起来，让一份尚未完整的回答逐步成为可靠的界面。
        </p>
      </div>
      <div className="pipeline" aria-label="OpenUI 工作原理">
        <div className="pipeline-steps" role="group" aria-label="选择系统环节">
          {stages.map((item, index) => (
            <button
              key={item.title}
              aria-pressed={stage === index}
              aria-controls="pipeline-detail"
              onClick={() => setStage(index)}
            >
              <span className="pipeline-number">
                {String(index + 1).padStart(2, "0")}
              </span>
              <b>{item.title}</b>
              <small>{item.term}</small>
              {index < stages.length - 1 && (
                <ArrowRight size={14} aria-hidden="true" />
              )}
            </button>
          ))}
        </div>
        <article
          id="pipeline-detail"
          className="pipeline-detail"
          aria-live="polite"
        >
          <div className="pipeline-copy">
            <p className="eyebrow">{selected.owner}</p>
            <h3>{selected.title}</h3>
            <p>{selected.description}</p>
            <p>{selected.decision}</p>
            <a
              className="text-link"
              href={sdkSource(
                selected.link.startsWith("GenUILib/") ||
                  selected.link.startsWith("Context/")
                  ? "Sources/OpenUISwiftUI/" + selected.link
                  : selected.link,
              )}
              target="_blank"
              rel="noreferrer"
            >
              查看对应实现与说明 <ArrowUpRight size={14} />
            </a>
          </div>
          <pre className="pipeline-code">{selected.example}</pre>
        </article>
        <p className="pipeline-loop">
          每个分片持续更新同一份程序与呈现；用户动作通过宿主回到下一次生成。图中环节可点选，属于架构说明，不是一次真实
          Agent 执行追踪。
        </p>
      </div>
      <div className="article-note">
        <b>契约在前，呈现可以演进。</b>
        <p>
          OpenUILang 负责语言语义，OpenUISwiftUI
          负责原生体验。主题、布局与交互可以在 SDK
          内改进；既有组件名称、位置参数、绑定和动作保持兼容。Map、MapPoint、SVG
          已包含在{" "}
          <a href={sdkBaseline.url} target="_blank" rel="noreferrer">
            {sdkBaseline.label}
          </a>{" "}
          的默认注册库中。
        </p>
      </div>
    </section>
  );
}

const designLayers = [
  {
    term: "Design Tokens & Semantic Styles",
    title: "共享的值，明确的职责",
    text: "颜色、字体、间距与圆角通过主题共享。TextStyles 再把完整的字号、字重、颜色和行距映射到正文、辅助说明、对象名、数值与操作槽位。同样 14pt，可以是紧凑主文字，也可以是辅助信息。",
    lesson:
      "文字显得杂乱时，先检查角色映射。直接把全局颜色调浅或把所有文字缩小，会同时改变原本正确的位置。",
    href: "#scale",
    label: "观察视觉尺度",
  },
  {
    term: "Layout & Composition",
    title: "空间规则先于内容长短",
    text: "Stack 定义排列与对齐，Card 同时具有可分配的布局单元与可选表面，集合根据阅读宽度分列。原生几何由 OpenUIPresentation 管理；测量算法与平台策略有自己的职责。",
    lesson:
      "图片随文字长大、透明 Card 出现缩进，都需要回到宽度分配和内边距规则。增加外层容器可能改变父级看到的布局项。",
    href: "#composition",
    label: "观察容器与边界",
  },
  {
    term: "Component Anatomy & State",
    title: "一个组件包含外观，也包含行为",
    text: "内容槽位、布局约束、选择状态、加载与失败、焦点和动作共同构成组件契约。Composite 的 header、body、footer 有明确分工；Form 的字段与提交属于同一任务。",
    lesson:
      "按钮的强调程度、可见尺寸和触控范围分别处理。pending、performing 与 disabled 也分别处理，流式等待不应被画成一次业务禁用。",
    href: "#components",
    label: "查阅组件契约",
  },
  {
    term: "Incremental Rendering",
    title: "增量运行时，兑现连续性的规则",
    text: "结构就绪、值就绪、资源就绪与交互资格分别判断。稳定的 statement、key 和呈现作用域保留已有视图；图片、查询与异步回调有消息级生命周期。",
    lesson:
      "前文闪动或整段重播，往往涉及身份和生命周期。持续增长的回答需要维护同一棵呈现树，单独增加淡入动画解决不了这一点。",
    href: "#streaming",
    label: "观察增量呈现",
  },
  {
    term: "Interaction & Host Contract",
    title: "一个动作，带回完整上下文",
    text: "组件维护当前字段并产生事件，宿主负责后续消息、资源权限、导航与真实业务。表单的最新值和选中的对象，要与点击文案一起到达 Agent。",
    lesson:
      "“按钮已经响应”只证明了一段链路。商品事实、预订入口和任务执行的真实性，需要工具数据与宿主处理共同成立。",
    href: "#integration",
    label: "查看交互闭环",
  },
  {
    term: "Verification & Governance",
    title: "让规则拥有可追溯的证据",
    text: "主题和契约从代码导出，示例保留唯一来源。解析测试、原生几何、手势验证、视觉审阅和业务端到端检查各自证明一部分事实，并记录对应版本。",
    lesson:
      "一张截图无法证明流式连续性，Web 预览也无法替代 SwiftUI 手势验收。已发布基线、历史截图与未来方案需要分别标明。",
    href: "#frontiers",
    label: "查看仍需攻克的问题",
  },
];
export function SystemDesign() {
  return (
    <section className="section" id="system">
      <div className="split system-intro">
        <div className="article-copy">
          <p className="eyebrow">02 / DESIGN SYSTEM AND RUNTIME</p>
          <h2>把设计写成共同的规则。</h2>
          <p>
            Design System 定义共享的视觉与交互规则，Rendering Runtime
            负责让这些规则在持续变化的程序中生效，Host Integration
            将界面接入资源、消息和真实业务。三者通过明确的契约协作。
          </p>
        </div>
        <div className="system-thesis">
          <p>
            在设计系统中，Tokens
            提供可共享的设计决策，语义样式将值映射到职责，组件落实具体外观与行为，Patterns
            组织多个组件共同完成任务。增量运行时进一步处理内容未到齐、资源未完成和用户已开始操作的时间关系。
          </p>
          <p>
            下方按六个职责面展开：视觉与语义、空间与组合、组件状态、增量运行时、宿主闭环，以及贯穿它们的验证与维护。每个问题找到自己的归属，同类修复才能覆盖一个组件家族，避免把某张截图的补丁变成默认规则。
          </p>
        </div>
      </div>
      <div className="design-layers">
        {designLayers.map((layer, index) => (
          <article key={layer.term}>
            <div className="layer-heading">
              <span className="layer-index">
                {String(index + 1).padStart(2, "0")}
              </span>
              <div>
                <p className="eyebrow">{layer.term}</p>
                <h3>{layer.title}</h3>
              </div>
            </div>
            <div className="layer-copy">
              <p>{layer.text}</p>
              <p className="layer-lesson">{layer.lesson}</p>
              <a className="text-link" href={layer.href}>
                {layer.label}
                <ArrowRight size={14} />
              </a>
            </div>
          </article>
        ))}
      </div>
      <p className="system-conclusion">
        共享不等于所有东西长得一样。连续讲述、对象比较、数据图表和局部提交各自保留合适的信息结构；它们共享文字角色、空间关系、状态语义与可信的数据边界。
      </p>
    </section>
  );
}

export function ReadinessMatrix() {
  return (
    <div className="readiness-explainer">
      <h3>同一条流，不同的呈现时机。</h3>
      <p>
        Readiness
        描述某种行为需要的条件。一个数字已经可解析，不代表它已经写完；一个 SVG
        文档已经可用，也不代表 WebKit 已经把它显示出来。
      </p>
      <div
        className="article-table-wrap"
        role="region"
        aria-label="RC20 组件就绪策略表，可横向滚动"
        tabIndex={0}
      >
        <table className="article-table">
          <caption>RC20 的就绪策略与当前边界</caption>
          <thead>
            <tr>
              <th>内容类型</th>
              <th>何时可以继续呈现</th>
              <th>仍需守住的边界</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <th>TextContent</th>
              <td>安全的阅读前缀可持续增长。</td>
              <td>后方引用未解析时，保留已读内容与源顺序。</td>
            </tr>
            <tr>
              <th>图片与图文卡</th>
              <td>布局角色与宽度可确定后建立媒体区域，资源到达时替换内容。</td>
              <td>未知横排贡献项可能影响宽度，不能先猜一幅完整页面。</td>
            </tr>
            <tr>
              <th>折线与柱形</th>
              <td>按图形语义消费已确认分类和数值。</td>
              <td>半截数字不进入已提交数据，缺失值不补零。</td>
            </tr>
            <tr>
              <th>比例类图形</th>
              <td>占比所需数据与总量可确认后呈现。</td>
              <td>持续改变的暂时总量会产生错误比例，不能一律逐点播放。</td>
            </tr>
            <tr>
              <th>字段与按钮</th>
              <td>所属范围、字段与动作就绪，并通过当前来源和校验检查。</td>
              <td>可操作资格独立判断，旧呈现的回调不能影响新程序。</td>
            </tr>
            <tr>
              <th>SVG</th>
              <td>完整文档通过校验后交给隔离的 WebKit 视图。</td>
              <td>
                <a href="#frontier-svg">渲染就绪反馈仍待补齐</a>，不写成 RC20
                已完成能力。
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  );
}

export function HostIntegration() {
  return (
    <section className="section" id="integration">
      <div className="split">
        <div className="article-copy">
          <p className="eyebrow">07 / FROM INTENT TO EXECUTION</p>
          <h2>一次点击，回到完整的上下文。</h2>
          <p>
            用户选择的是某个对象、某组条件和某种意图。SDK
            的交互设计需要保留这三者，宿主才能把下一步交给正确的工具或 Agent。
          </p>
          <p>
            Form
            收集同一任务的值，提交时读取最新选择；即时筛选可以直接使用本地状态。纯展示商品、单个跳转和表单提交的职责分别成立，外观不替代作用域。
          </p>
        </div>
        <div className="integration-detail">
          <h3>把组件连接成任务的，是信息结构。</h3>
          <p>
            商品的名称、图片、短介绍、属性、价格口径与入口对应同一个对象。推荐理由表达判断，工具返回字段表达事实；Tag
            承担短属性，长前提留给正文。
          </p>
          <p>
            这类组合属于 Patterns。标准用例教会 Agent
            怎样组织一次比较、收集一组偏好或补全一份计划；当前价格、库存与交通数据仍要来自这次查询。SDK
            不从商品名或 case 编号猜测布局，也不替内容补造事实。
          </p>
        </div>
      </div>
      <div className="handoff-chain">
        <span>当前对象与选择</span>
        <ArrowRight size={15} />
        <span>校验与 ActionEvent</span>
        <ArrowRight size={15} />
        <span>宿主消息 / 业务处理</span>
        <ArrowRight size={15} />
        <span>真实结果与后续回答</span>
      </div>
      <p className="micro">
        既有 buildMessage／parseMessage 可以承载消息上下文。SDK
        发出事件、客户端传递了值、Agent
        实际收到条件、业务真正成功，需要各自的证据；不由一个按钮的视觉反馈一并宣告。
      </p>
    </section>
  );
}
