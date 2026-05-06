import fs from "node:fs/promises";
import path from "node:path";
import {
  Presentation,
  PresentationFile,
  FileBlob,
  column,
  row,
  grid,
  layers,
  panel,
  text,
  image,
  shape,
  rule,
  fill,
  fixed,
  fr,
  auto,
  hug,
  wrap,
} from "file:///C:/Users/17367/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";

const OUT_DIR = "output";
const PREVIEW_DIR = path.join(OUT_DIR, "ppt_previews");
const TEMPLATE = "策划方案.pptx";
const BACKUP = "策划方案_原模板备份.pptx";
const EXPORT = "策划方案_StudyTrace_完整策划稿.pptx";

await fs.mkdir(OUT_DIR, { recursive: true });
try {
  await fs.access(BACKUP);
} catch {
  await fs.copyFile(TEMPLATE, BACKUP);
}
await fs.rm(PREVIEW_DIR, { recursive: true, force: true });
await fs.mkdir(PREVIEW_DIR, { recursive: true });

const W = 1920;
const H = 1080;
const C = {
  ink: "#172033",
  muted: "#64748B",
  blue: "#2563EB",
  blue2: "#38BDF8",
  cyan: "#06B6D4",
  green: "#10B981",
  amber: "#F59E0B",
  red: "#EF4444",
  bg: "#F7FAFF",
  soft: "#EAF1FB",
  line: "#D9E2F1",
  dark: "#0B1220",
  white: "#FFFFFF",
  violet: "#7C3AED",
};

async function dataUrl(file) {
  const ext = path.extname(file).toLowerCase();
  const mime = ext === ".jpg" || ext === ".jpeg" ? "image/jpeg" : "image/png";
  const bytes = await fs.readFile(file);
  return `data:${mime};base64,${bytes.toString("base64")}`;
}

const logoDataUrl = await dataUrl(path.resolve("logo", "logo黑透明.png"));
const whiteLogoDataUrl = await dataUrl(path.resolve("logo", "logo白透明.png"));
const appIconDataUrl = await dataUrl(path.resolve("logo", "app图标.png"));
const splineDataUrl = await dataUrl(path.resolve("assets", "Backgrounds", "Spline.png"));
const screenshots = {
  home: await dataUrl(path.resolve("output", "app_screenshots", "home.png")),
  logs: await dataUrl(path.resolve("output", "app_screenshots", "logs.png")),
  calendar: await dataUrl(path.resolve("output", "app_screenshots", "calendar.png")),
  tasks: await dataUrl(path.resolve("output", "app_screenshots", "tasks.png")),
  archive: await dataUrl(path.resolve("output", "app_screenshots", "archive.png")),
  ai: await dataUrl(path.resolve("output", "app_screenshots", "ai_assistant.png")),
  stats: await dataUrl(path.resolve("output", "app_screenshots", "statistics.png")),
  timer: await dataUrl(path.resolve("output", "app_screenshots", "timer.png")),
  flashcards: await dataUrl(path.resolve("output", "app_screenshots", "flashcards.png")),
};

const deck = Presentation.create({ slideSize: { width: W, height: H } });

function add(slide, node) {
  slide.compose(node, {
    frame: { left: 0, top: 0, width: W, height: H },
    baseUnit: 8,
  });
}

function t(value, opts = {}) {
  return text(value, {
    name: opts.name,
    width: opts.width ?? fill,
    height: opts.height ?? hug,
    style: {
      fontFamily: "Microsoft YaHei",
      fontSize: opts.size ?? 26,
      bold: opts.bold ?? false,
      color: opts.color ?? C.ink,
      lineHeight: opts.lineHeight ?? 1.14,
    },
  });
}

function small(label, color = C.muted, width = fill) {
  return t(label, { size: 18, color, width });
}

function footer(page) {
  return row({ name: `footer-${page}`, width: fill, height: hug, gap: 16, align: "center" }, [
    rule({ width: fixed(80), stroke: C.blue, weight: 3 }),
    small("StudyTrace 学迹", C.muted, wrap(210)),
    small(String(page).padStart(2, "0"), C.muted, fixed(44)),
  ]);
}

function titleStack(kicker, title, subtitle) {
  return column({ width: fill, height: hug, gap: 12 }, [
    t(kicker, { size: 19, bold: true, color: C.blue, width: fill }),
    t(title, { size: 50, bold: true, color: C.ink, width: fill }),
    subtitle
      ? t(subtitle, { size: 22, color: C.muted, width: wrap(1320), lineHeight: 1.18 })
      : rule({ width: fixed(160), stroke: C.blue, weight: 5 }),
  ]);
}

function chip(label, color = C.blue) {
  return panel(
    {
      width: hug,
      height: hug,
      padding: { x: 18, y: 8 },
      fill: C.white,
      stroke: color,
      borderRadius: 999,
    },
    t(label, { size: 17, bold: true, color, width: hug }),
  );
}

function metric(label, value, color = C.blue) {
  return column({ width: fill, height: hug, gap: 8 }, [
    t(value, { size: 44, bold: true, color, width: fill }),
    small(label, C.muted, fill),
  ]);
}

function bulletList(items, color = C.blue, size = 24) {
  return column(
    { width: fill, height: hug, gap: 14 },
    items.map((item) =>
      row({ width: fill, height: hug, gap: 14, align: "center" }, [
        shape({ width: fixed(14), height: fixed(14), fill: color, radius: 999 }),
        t(item, { size, color: C.ink, width: fill }),
      ]),
    ),
  );
}

function screenshotSlot(title, subtitle, accent = C.blue, shotDataUrl = null) {
  return panel(
    {
      width: fill,
      height: fill,
      padding: shotDataUrl ? 12 : { x: 18, y: 14 },
      fill: C.white,
      stroke: "#CAD7EC",
      borderRadius: 26,
    },
    shotDataUrl
      ? image({ dataUrl: shotDataUrl, width: fill, height: fill, fit: "contain", alt: title })
      : column({ width: fill, height: fill, gap: 6 }, [
          row({ width: fill, height: fixed(16), gap: 7 }, [
            shape({ width: fixed(10), height: fixed(10), fill: accent, radius: 99 }),
            shape({ width: fixed(10), height: fixed(10), fill: "#CBD5E1", radius: 99 }),
            shape({ width: fixed(10), height: fixed(10), fill: "#E2E8F0", radius: 99 }),
          ]),
          shape({ width: fill, height: fixed(6), fill: "#E8EEF8", radius: 99 }),
          shape({ width: fill, height: fixed(6), fill: "#EEF4FB", radius: 99 }),
          column(
            { width: fill, height: fill, gap: 8, align: "center", justify: "center" },
            [
              t(title, { size: 24, bold: true, color: C.ink, width: fill }),
              small(subtitle, C.muted, fill),
            ],
          ),
        ]),
  );
}

function phoneMock(title, subtitle, color = C.blue, shotDataUrl = null, boxWidth = fill, boxHeight = fill) {
  return panel(
    {
      width: boxWidth,
      height: boxHeight,
      padding: { x: 16, y: 18 },
      fill: "#111827",
      borderRadius: 42,
    },
    panel(
      { width: fill, height: fill, padding: 0, fill: "#F8FAFC", borderRadius: 28 },
      shotDataUrl
        ? image({ dataUrl: shotDataUrl, width: fill, height: fill, fit: "contain", alt: title })
        : column({ width: fill, height: fill, gap: 12, padding: 18 }, [
            row({ width: fill, height: fixed(18), gap: 8 }, [
              shape({ width: fixed(12), height: fixed(12), fill: color, radius: 99 }),
              shape({ width: fixed(12), height: fixed(12), fill: "#CBD5E1", radius: 99 }),
              shape({ width: fixed(12), height: fixed(12), fill: "#E2E8F0", radius: 99 }),
            ]),
            shape({ width: fill, height: fixed(12), fill: "#E8EEF8", radius: 99 }),
            shape({ width: fill, height: fixed(12), fill: "#EEF4FB", radius: 99 }),
            column({ width: fill, height: fill, justify: "center", gap: 10 }, [
              t(title, { size: 24, bold: true, color: C.ink, width: fill }),
              small(subtitle, C.muted, fill),
            ]),
          ]),
    ),
  );
}

function compactSlot(title, subtitle, accent = C.blue) {
  return panel(
    {
      width: fill,
      height: fill,
      padding: 18,
      fill: C.white,
      stroke: "#CAD7EC",
      borderRadius: 24,
    },
    column({ width: fill, height: fill, gap: 10, justify: "center" }, [
      shape({ width: fixed(34), height: fixed(8), fill: accent, radius: 99 }),
      t(title, { size: 24, bold: true, color: C.ink, width: fill }),
      small(subtitle, C.muted, fill),
    ]),
  );
}

function labeledShot(title, subtitle, accent, shotDataUrl) {
  return column({ width: fill, height: fill, gap: 8 }, [
    row({ width: fill, height: hug, gap: 9, align: "center" }, [
      shape({ width: fixed(10), height: fixed(10), fill: accent, radius: 99 }),
      t(title, { size: 21, bold: true, color: C.ink, width: fill }),
    ]),
    t(subtitle, { size: 14, color: C.muted, width: fill }),
    panel(
      { width: fill, height: fill, padding: 8, fill: C.white, stroke: "#D8E3F4", borderRadius: 22 },
      image({ dataUrl: shotDataUrl, width: fill, height: fill, fit: "contain", alt: title }),
    ),
  ]);
}

function sectionSlide(part, title, subtitle, chips = []) {
  const slide = deck.slides.add();
  add(
    slide,
    layers({ width: fill, height: fill }, [
      shape({ width: fill, height: fill, fill: C.dark }),
      image({ dataUrl: splineDataUrl, width: fill, height: fill, fit: "cover", opacity: 0.22, alt: "abstract background" }),
      column({ width: fill, height: fill, padding: { x: 110, y: 90 }, justify: "center", gap: 26 }, [
        t(part, { size: 31, bold: true, color: C.blue2, width: fill }),
        t(title, { size: 78, bold: true, color: C.white, width: fill }),
        t(subtitle, { size: 29, color: "#C7D7EF", width: wrap(1220) }),
        row({ width: fill, height: hug, gap: 16 }, chips.map(([label, color]) => chip(label, color))),
      ]),
    ]),
  );
}

function normalSlide(kicker, title, subtitle, body, page) {
  const slide = deck.slides.add();
  add(
    slide,
    column({ width: fill, height: fill, padding: { x: 88, y: 64 }, gap: 28 }, [
      titleStack(kicker, title, subtitle),
      body,
      footer(page),
    ]),
  );
}

function slideCover() {
  const slide = deck.slides.add();
  add(
    slide,
    layers({ width: fill, height: fill }, [
      shape({ width: fill, height: fill, fill: C.bg }),
      grid(
        {
          width: fill,
          height: fill,
          padding: { x: 92, y: 70 },
          columns: [fr(1.05), fr(0.95)],
          rows: [auto, fr(1), auto],
          columnGap: 70,
        },
        [
          row({ columnSpan: 2, width: fill, height: hug, justify: "between", align: "center" }, [
            image({ dataUrl: logoDataUrl, width: fixed(230), height: fixed(64), fit: "contain", alt: "StudyTrace logo" }),
            t("第三届中国高校计算机大赛 AIGC创新赛", { size: 20, bold: true, color: C.muted, width: wrap(520) }),
          ]),
          column({ width: fill, height: fill, justify: "center", gap: 26 }, [
            t("StudyTrace 学迹", { size: 88, bold: true, color: C.ink, width: fill }),
            t("大学生课程任务管理与 AI 学习助手 App", { size: 34, color: C.blue, bold: true, width: fill }),
            t("基于 Flutter 与大模型能力，构建“记录—执行—分析—复盘”的智能学习闭环。", { size: 27, color: C.muted, width: wrap(900) }),
            row({ width: fill, height: hug, gap: 14 }, [
              chip("课程任务管理", C.blue),
              chip("AI 学习助手", C.green),
              chip("本地优先", C.cyan),
            ]),
          ]),
          panel(
            { width: fill, height: fixed(650), padding: 28, fill: C.white, stroke: "#D8E3F4", borderRadius: 46 },
            grid({ width: fill, height: fill, columns: [fr(1.05), fr(0.95)], gap: 18 }, [
              phoneMock("首页 Dashboard", "学习概览", C.blue, screenshots.home),
              column({ width: fill, height: fill, gap: 18 }, [
                screenshotSlot("AI 学习助手", "生成日志 / 拆解任务", C.cyan, screenshots.ai),
                screenshotSlot("知识闪卡", "点击翻转 / 前后浏览", C.green, screenshots.flashcards),
              ]),
            ]),
          ),
          row({ columnSpan: 2, width: fill, height: hug, justify: "between" }, [
            t("团队策划方案", { size: 22, bold: true, color: C.ink, width: wrap(300) }),
            t("成员 A / B / C / D 联合汇报", { size: 20, color: C.muted, width: wrap(430) }),
          ]),
        ],
      ),
    ]),
  );
}

function slideContents() {
  const items = [
    ["01", "作品价值与需求洞察", "团队、简介、用户痛点、设计理念、前景"],
    ["02", "界面设计与交互体验", "宣传海报、视觉体系、核心界面、关键流程"],
    ["03", "技术实现与创新点", "Flutter 架构、客户端落地、可行性与 Demo"],
    ["04", "大模型应用说明", "双引擎能力、Prompt 机制、多模态输入"],
    ["05", "总结与未来展望", "社会价值、扩展路径、比赛亮点收束"],
  ];
  normalSlide(
    "/ CONTENTS",
    "目录",
    "四位成员的策划内容被组织成一条完整汇报线：先说明价值，再展示体验，最后证明技术和 AI 能力。",
    grid({ width: fill, height: fill, columns: [fr(0.85), fr(1.15)], columnGap: 64 }, [
      panel(
        { width: fill, height: fill, padding: 34, fill: C.white, stroke: "#D8E3F4", borderRadius: 34 },
        column({ width: fill, height: fill, gap: 24, justify: "center" }, [
          image({ dataUrl: appIconDataUrl, width: fixed(170), height: fixed(170), fit: "contain", alt: "StudyTrace app icon" }),
          t("一份完整作品策划稿", { size: 34, bold: true, color: C.ink, width: wrap(620) }),
          t("覆盖产品价值、UI 交互、客户端实现和大模型应用能力。", { size: 23, color: C.muted, width: wrap(620) }),
        ]),
      ),
      column({ width: fill, height: fill, gap: 18 }, items.map(([no, title, desc], i) =>
        row({ width: fill, height: fixed(100), gap: 22, align: "center" }, [
          panel(
            { width: fixed(76), height: fixed(76), fill: i === 2 ? C.blue : C.soft, borderRadius: 22 },
            t(no, { size: 28, bold: true, color: i === 2 ? C.white : C.blue, width: fill }),
          ),
          column({ width: fill, height: hug, gap: 8 }, [
            t(title, { size: 28, bold: true, color: C.ink, width: fill }),
            small(desc, C.muted, fill),
          ]),
        ]),
      )),
    ]),
    2,
  );
}

function slideTeam() {
  const people = [
    ["成员 A", "产品经理", "统筹 PPT 逻辑、作品简介、设计理念、前景评估", C.blue],
    ["成员 B", "UI 与交互设计", "宣传海报、界面设计、核心交互流程", C.cyan],
    ["成员 C", "前端 / 客户端开发", "Flutter 架构、功能落地、可行性与 Demo", C.green],
    ["成员 D", "大模型 / 后端开发", "蓝心与 DeepSeek 应用、Prompt 与多模态机制", C.amber],
  ];
  normalSlide(
    "01-1 / TEAM",
    "团队介绍与分工",
    "团队采用产品、设计、客户端与 AI 引擎四线协作，让策划稿同时覆盖应用价值、体验呈现与技术可行性。",
    grid({ width: fill, height: fill, columns: [fr(1), fr(1)], rows: [fr(1), fr(1)], gap: 22 }, people.map(([name, role, desc, color]) =>
      panel(
        { width: fill, height: fill, padding: 30, fill: C.white, stroke: "#D8E3F4", borderRadius: 28 },
        column({ width: fill, height: fill, gap: 14, justify: "center" }, [
          row({ width: fill, height: hug, gap: 16, align: "center" }, [
            panel({ width: fixed(62), height: fixed(62), fill: color, borderRadius: 999 }, t(name.slice(-1), { size: 30, bold: true, color: C.white, width: fill })),
            column({ width: fill, height: hug, gap: 5 }, [
              t(name, { size: 28, bold: true, color: C.ink, width: fill }),
              t(role, { size: 21, bold: true, color, width: fill }),
            ]),
          ]),
          rule({ width: fixed(190), stroke: color, weight: 4 }),
          t(desc, { size: 22, color: C.muted, width: fill }),
        ]),
      ),
    )),
    3,
  );
}

function slideIntro() {
  normalSlide(
    "01-2 / OVERVIEW",
    "作品简介",
    "StudyTrace 面向大学生日常学习管理，帮助用户把零散任务、学习记录、复盘报告和 AI 辅助能力收束到一个移动端闭环。",
    grid({ width: fill, height: fill, columns: [fr(0.95), fr(1.05)], columnGap: 58 }, [
      column({ width: fill, height: fill, gap: 22, justify: "center" }, [
        t("一句话定位", { size: 28, bold: true, color: C.blue, width: fill }),
        t("大学生课程任务管理与 AI 学习助手 App", { size: 44, bold: true, color: C.ink, width: wrap(780) }),
        t("通过学习日志、课程任务、日历记录和学习统计沉淀学习轨迹，再由大模型生成结构化建议、风险提醒与知识闪卡。", { size: 25, color: C.muted, width: wrap(780) }),
        row({ width: fill, height: hug, gap: 16 }, [chip("记录", C.blue), chip("执行", C.green), chip("分析", C.amber), chip("复盘", C.cyan)]),
      ]),
      panel(
        { width: fill, height: fill, padding: 34, fill: C.white, stroke: "#D8E3F4", borderRadius: 36 },
        grid({ width: fill, height: fill, columns: [fr(1), fr(1)], rows: [fr(1), fr(1)], gap: 18 }, [
          screenshotSlot("任务管理", "课程作业 / 实验报告 / 项目开发", C.blue, screenshots.tasks),
          screenshotSlot("学习记录", "日志沉淀 / 问题反思 / 下一步计划", C.green, screenshots.logs),
          screenshotSlot("AI 助手", "生成日志 / 任务拆解 / 风险提醒", C.amber, screenshots.ai),
          screenshotSlot("知识闪卡", "自动生成问答卡片", C.cyan, screenshots.flashcards),
        ]),
      ),
    ]),
    4,
  );
}

function slidePainPoints() {
  const pains = [
    ["任务分散", "课程作业、实验报告、论文阅读分布在不同渠道，截止时间容易遗漏。"],
    ["记录断层", "学习过程常常只留下结果，没有沉淀问题、思考和下一步计划。"],
    ["复盘困难", "周报和总结依赖手写整理，难以从长期数据里发现风险。"],
    ["AI 割裂", "通用聊天工具能回答问题，却很难进入个人学习数据闭环。"],
  ];
  normalSlide(
    "01-3 / PAIN POINTS",
    "用户背景与学习痛点",
    "目标用户是课程任务密集、需要持续复盘的大学生。StudyTrace 把高频学习行为转成可追踪、可分析的数据资产。",
    grid({ width: fill, height: fill, columns: [fr(1), fr(1)], rows: [fr(1), fr(1)], gap: 22 }, pains.map(([name, desc], i) =>
      panel(
        { width: fill, height: fill, padding: 30, fill: C.white, stroke: "#D8E3F4", borderRadius: 28 },
        column({ width: fill, height: fill, gap: 12, justify: "center" }, [
          t(`0${i + 1}`, { size: 26, bold: true, color: [C.blue, C.green, C.amber, C.red][i], width: fill }),
          t(name, { size: 34, bold: true, color: C.ink, width: fill }),
          t(desc, { size: 22, color: C.muted, width: fill }),
        ]),
      ),
    )),
    5,
  );
}

function slideDesignIdea() {
  normalSlide(
    "01-4 / DESIGN CONCEPT",
    "作品设计理念",
    "核心理念是“学习印记端侧化”：把学习过程先沉淀在本地，再按需调用大模型生成反馈，兼顾效率与隐私。",
    grid({ width: fill, height: fill, columns: [fr(1), fr(1.05)], columnGap: 62 }, [
      column({ width: fill, height: fill, gap: 28, justify: "center" }, [
        metric("不只管理任务，而是沉淀学习轨迹", "Trace", C.blue),
        metric("不只调用 AI，而是进入学习流程", "Loop", C.green),
        metric("不只生成文本，而是回写本地模型", "Data", C.cyan),
      ]),
      panel(
        { width: fill, height: fill, padding: 34, fill: C.white, stroke: "#D8E3F4", borderRadius: 36 },
        column({ width: fill, height: fill, gap: 28, justify: "center" }, [
          t("设计原则", { size: 30, bold: true, color: C.blue, width: fill }),
          bulletList([
            "本地优先：任务、日志、周报等学习资料优先存在本机。",
            "闭环优先：每个 AI 输出都能回到任务、日志、闪卡等模块。",
            "低打扰：Dashboard、日历、统计页用于快速扫读状态。",
            "可扩展：为端侧大模型、云同步、通知提醒保留路径。",
          ], C.blue, 24),
        ]),
      ),
    ]),
    6,
  );
}

function slideValue() {
  normalSlide(
    "01-5 / VALUE",
    "应用价值与前景评估",
    "StudyTrace 的价值集中在高频学习管理、过程复盘和个性化 AI 辅助，适合从个人学习工具扩展到课程学习管理场景。",
    grid({ width: fill, height: fill, columns: [fr(1), fr(1), fr(1)], gap: 22 }, [
      panel({ width: fill, height: fill, padding: 28, fill: C.white, stroke: "#D8E3F4", borderRadius: 30 }, column({ width: fill, height: fill, gap: 16, justify: "center" }, [
        t("用户价值", { size: 32, bold: true, color: C.blue, width: fill }),
        t("降低任务遗漏和复盘成本，让学生看到自己的学习节奏和风险。", { size: 24, color: C.ink, width: fill }),
      ])),
      panel({ width: fill, height: fill, padding: 28, fill: C.white, stroke: "#D8E3F4", borderRadius: 30 }, column({ width: fill, height: fill, gap: 16, justify: "center" }, [
        t("社会价值", { size: 32, bold: true, color: C.green, width: fill }),
        t("用 AI 帮助学习者形成自我管理习惯，提升长期学习质量。", { size: 24, color: C.ink, width: fill }),
      ])),
      panel({ width: fill, height: fill, padding: 28, fill: C.white, stroke: "#D8E3F4", borderRadius: 30 }, column({ width: fill, height: fill, gap: 16, justify: "center" }, [
        t("发展前景", { size: 32, bold: true, color: C.cyan, width: fill }),
        t("后续可扩展课程协作、学期报告、多端同步与端侧模型能力。", { size: 24, color: C.ink, width: fill }),
      ])),
    ]),
    7,
  );
}

function slideCompetition() {
  const rows = [
    ["普通待办", "强", "弱", "弱", "弱"],
    ["笔记工具", "中", "强", "弱", "中"],
    ["通用 AI 聊天", "弱", "弱", "强", "弱"],
    ["StudyTrace", "强", "强", "强", "强"],
  ];
  normalSlide(
    "01-6 / ADVANTAGE",
    "竞品对比与核心优势",
    "StudyTrace 的差异点不是单个功能，而是把任务、记录、统计和 AI 复盘组合为学习场景专用闭环。",
    grid({ width: fill, height: fill, columns: [fr(1.1), fr(0.9)], columnGap: 52 }, [
      panel(
        { width: fill, height: fill, padding: 28, fill: C.white, stroke: "#D8E3F4", borderRadius: 32 },
        column({ width: fill, height: fill, gap: 12 }, [
          row({ width: fill, height: fixed(54), gap: 8 }, ["产品类型", "任务管理", "学习记录", "AI 辅助", "复盘闭环"].map((h, i) =>
            t(h, { size: i === 0 ? 18 : 17, bold: true, color: C.blue, width: i === 0 ? fixed(150) : fill }),
          )),
          ...rows.map((r, idx) =>
            row({ width: fill, height: fixed(70), gap: 8, align: "center" }, r.map((cell, i) =>
              panel(
                { width: i === 0 ? fixed(150) : fill, height: fill, padding: { x: 8, y: 8 }, fill: idx === 3 ? "#EAF3FF" : "#F8FAFC", borderRadius: 14 },
                t(cell, { size: 19, bold: idx === 3 || i === 0, color: idx === 3 ? C.blue : C.ink, width: fill }),
              ),
            )),
          ),
        ]),
      ),
      column({ width: fill, height: fill, gap: 22, justify: "center" }, [
        t("核心优势", { size: 31, bold: true, color: C.blue, width: fill }),
        bulletList([
          "学习场景专用，而不是通用效率工具。",
          "AI 结果可保存、可追踪、可复用。",
          "端侧数据沉淀，隐私边界更清晰。",
          "Flutter 跨平台，便于移动端和 Web 展示。",
        ], C.green, 24),
      ]),
    ]),
    8,
  );
}

function slidePoster() {
  const slide = deck.slides.add();
  add(
    slide,
    grid(
      {
        width: fill,
        height: fill,
        padding: { x: 88, y: 64 },
        rows: [auto, fr(1), auto],
        columns: [fr(0.9), fr(1.1)],
        columnGap: 58,
      },
      [
        titleStack("02-1 / POSTER", "作品宣传海报", "海报要让评委一眼看到核心卖点：大学生学习闭环 + AI 助手 + 本地学习轨迹。"),
        panel(
          { width: fill, height: fill, padding: 34, fill: C.dark, borderRadius: 42, rowSpan: 2 },
          layers({ width: fill, height: fill }, [
            image({ dataUrl: splineDataUrl, width: fill, height: fill, fit: "cover", opacity: 0.2, alt: "poster background" }),
            column({ width: fill, height: fill, padding: 24, justify: "center", gap: 26 }, [
              image({ dataUrl: whiteLogoDataUrl, width: fixed(220), height: fixed(72), fit: "contain", alt: "logo" }),
              t("把学习过程\n变成可复盘的轨迹", { size: 54, bold: true, color: C.white, width: fill }),
              t("任务管理 · AI 周报 · 风险提醒 · 知识闪卡", { size: 26, color: "#DDEBFF", width: fill }),
              row({ width: fill, height: hug, gap: 14 }, [chip("记录", C.blue2), chip("执行", C.green), chip("分析", C.amber), chip("复盘", C.cyan)]),
            ]),
          ]),
        ),
        column({ width: fill, height: fill, gap: 24, justify: "center" }, [
          t("海报文案", { size: 30, bold: true, color: C.blue, width: fill }),
          bulletList([
            "主标题：把学习过程变成可复盘的轨迹",
            "副标题：面向大学生的 AIGC 学习管理 App",
            "卖点：任务管理、AI 周报、风险提醒、知识闪卡",
            "图片：右侧放 App 首页或 AI 助手真实截图",
          ], C.blue, 24),
        ]),
        footer(9),
      ],
    ),
  );
}

function slideVisualSystem() {
  normalSlide(
    "02-2 / VISUAL SYSTEM",
    "UI 视觉体系",
    "界面采用 Material Design 3 与 vivo 蓝主题方向，强调清爽、可扫读、低干扰，适合高频学习工具。",
    grid({ width: fill, height: fill, columns: [fr(1), fr(1)], columnGap: 58 }, [
      column({ width: fill, height: fill, gap: 26, justify: "center" }, [
        t("视觉关键词", { size: 30, bold: true, color: C.blue, width: fill }),
        bulletList([
          "浅色背景 + 高对比标题，降低学习场景阅读压力。",
          "蓝 / 青 / 绿作为功能状态色，暗示效率、AI 与成长。",
          "卡片化信息层级，适合任务、日志、统计等重复内容。",
          "支持深色模式与主题切换，提升不同环境下的可用性。",
        ], C.blue, 23),
      ]),
      panel(
        { width: fill, height: fill, padding: 34, fill: C.white, stroke: "#D8E3F4", borderRadius: 36 },
        column({ width: fill, height: fill, gap: 28, justify: "center" }, [
          row({ width: fill, height: fixed(92), gap: 18 }, [
            shape({ width: fixed(92), height: fixed(92), fill: C.blue, radius: 24 }),
            shape({ width: fixed(92), height: fixed(92), fill: C.cyan, radius: 24 }),
            shape({ width: fixed(92), height: fixed(92), fill: C.green, radius: 24 }),
            shape({ width: fixed(92), height: fixed(92), fill: C.amber, radius: 24 }),
          ]),
          screenshotSlot("首页视觉与组件", "vivo 蓝主题、GlassCard、BadgePill", C.blue, screenshots.home),
        ]),
      ),
    ]),
    10,
  );
}

function slideScreens() {
  normalSlide(
    "02-3 / INTERFACE",
    "核心界面展示",
    "真实手机竖屏截图展示信息架构完整性和移动端界面完成度。",
    row({ width: fill, height: fill, gap: 18, align: "center", justify: "center" }, [
      phoneMock("首页 Dashboard", "任务进度 / AI 入口 / 最近记录", C.blue, screenshots.home, fixed(238), fixed(560)),
      phoneMock("AI 学习助手", "日志生成 / 任务拆解 / 风险提醒", C.cyan, screenshots.ai, fixed(238), fixed(560)),
      phoneMock("任务管理", "搜索筛选 / 子任务 / 状态切换", C.green, screenshots.tasks, fixed(238), fixed(560)),
      phoneMock("学习日历", "月历标记 / 当日详情", C.amber, screenshots.calendar, fixed(238), fixed(560)),
      phoneMock("学习统计", "饼图 / 柱状图 / 完成率", C.red, screenshots.stats, fixed(238), fixed(560)),
      phoneMock("知识闪卡", "问答卡片 / 点击翻转", C.violet, screenshots.flashcards, fixed(238), fixed(560)),
    ]),
    11,
  );
}

function slideTimerFlow() {
  const steps = [
    ["专注计时", "选择 25/45/60 分钟并开始学习"],
    ["完成弹窗", "记录本次学习主题与时长"],
    ["AI 生成", "生成课程、内容、问题、收获、计划"],
    ["一键保存", "写入学习日志并进入后续周报分析"],
  ];
  normalSlide(
    "02-4 / INTERACTION FLOW",
    "交互流程一：番茄钟到 AI 学习日志",
    "核心体验是让用户在学习结束的自然节点完成记录，减少事后补日志的负担。",
    grid({ width: fill, height: fill, columns: [fr(1.05), fr(0.95)], columnGap: 58 }, [
      column({ width: fill, height: fill, gap: 10, justify: "center" }, steps.map(([name, desc], i) =>
        row({ width: fill, height: fixed(106), gap: 18, align: "center" }, [
          shape({ width: fixed(22), height: fixed(22), fill: [C.blue, C.green, C.amber, C.cyan][i], radius: 999 }),
          column({ width: fill, height: fill, justify: "center", gap: 4 }, [
            t(`${i + 1}. ${name}`, { size: 27, bold: true, color: C.ink, width: fill }),
            t(desc, { size: 17, color: C.muted, width: fill }),
          ]),
        ]),
      )),
      panel({ width: fill, height: fill, padding: 28, fill: C.white, stroke: "#D8E3F4", borderRadius: 36 }, grid({ width: fill, height: fill, columns: [fr(1), fr(1)], gap: 18 }, [
        phoneMock("番茄钟页面", "开始 / 暂停 / 重置", C.green, screenshots.timer),
        phoneMock("学习记录", "AI 日志保存后进入记录", C.blue, screenshots.logs),
      ])),
    ]),
    12,
  );
}

function slideTaskFlow() {
  normalSlide(
    "02-5 / INTERACTION FLOW",
    "交互流程二：AI 任务拆解到任务列表",
    "复杂任务通过自然语言输入生成子任务和安排，再一键进入任务管理，形成从计划到执行的路径。",
    grid({ width: fill, height: fill, columns: [fr(0.95), fr(1.05)], columnGap: 58 }, [
      panel(
        { width: fill, height: fill, padding: 30, fill: C.white, stroke: "#D8E3F4", borderRadius: 36 },
        column({ width: fill, height: fill, gap: 24, justify: "center" }, [
          t("示例输入", { size: 26, bold: true, color: C.blue, width: fill }),
          t("“下周五前完成操作系统实验报告和答辩 PPT”", { size: 34, bold: true, color: C.ink, width: fill }),
          rule({ width: fixed(240), stroke: C.blue, weight: 5 }),
          bulletList([
            "识别课程与截止时间",
            "拆解为资料整理、实验复现、报告撰写、PPT 制作",
            "按天生成安排并写入任务列表",
          ], C.green, 24),
        ]),
      ),
      grid({ width: fill, height: fill, columns: [fr(1), fr(1)], rows: [fr(1), fr(1)], gap: 18 }, [
        screenshotSlot("输入复杂任务", "自然语言 / 语音输入", C.blue, screenshots.ai),
        screenshotSlot("任务列表展示", "状态与子任务进度", C.green, screenshots.tasks),
        screenshotSlot("日历视图", "任务和记录进入月视图", C.cyan, screenshots.calendar),
        screenshotSlot("归档沉淀", "按课程回看学习材料", C.amber, screenshots.archive),
      ]),
    ]),
    13,
  );
}

function slideTechSection() {
  sectionSlide("PART 03", "技术实现与创新点", "用 Flutter 跨平台客户端和 AI 服务层，证明作品具备真实落地能力。", [
    ["Flutter 3.x", C.blue2],
    ["本地 JSON", C.green],
    ["Demo 可演示", C.amber],
  ]);
}

function slideArchitecture() {
  const layersData = [
    ["UI 表现层", "首页 / 任务 / 日历 / AI 助手 / 闪卡", C.blue],
    ["状态管理层", "MVVM + ChangeNotifier 统一驱动页面刷新", C.cyan],
    ["业务服务层", "周报生成、AI 学习服务、凭据安全存储", C.green],
    ["数据模型层", "任务、日志、周报、AI 结果、用户资料", C.amber],
    ["存储与外部能力", "SharedPreferences 本地 JSON + 蓝心 / DeepSeek API", C.red],
  ];
  normalSlide(
    "03-1 / ARCHITECTURE",
    "Flutter 客户端架构",
    "客户端采用清晰分层：页面只负责展示，状态与业务逻辑下沉到 Controller 与 Service。",
    grid({ width: fill, height: fill, columns: [fr(1), fr(1)], columnGap: 58 }, [
      column({ width: fill, height: fill, gap: 18 }, layersData.map(([name, desc, color]) =>
        panel(
          { width: fill, height: fixed(104), padding: { x: 24, y: 18 }, fill: C.white, stroke: "#D8E3F4", borderRadius: 22 },
          row({ width: fill, height: fill, gap: 18, align: "center" }, [
            shape({ width: fixed(10), height: fill, fill: color, radius: 99 }),
            column({ width: fill, height: hug, gap: 6 }, [
              t(name, { size: 26, bold: true, color: C.ink, width: fill }),
              small(desc, C.muted, fill),
            ]),
          ]),
        ),
      )),
      column({ width: fill, height: fill, gap: 24, justify: "center" }, [
        t("技术关键词", { size: 30, bold: true, color: C.blue, width: fill }),
        grid({ width: fill, height: hug, columns: [fr(1), fr(1)], gap: 14 }, [
          chip("Flutter 3.x", C.blue),
          chip("Material Design 3", C.cyan),
          chip("MVVM", C.green),
          chip("SharedPreferences", C.amber),
          chip("flutter_secure_storage", C.red),
          chip("Mock 回退", C.violet),
        ]),
        t("架构为后续端侧大模型、云同步和多端适配预留接口，避免功能堆叠导致后续难以扩展。", { size: 23, color: C.muted, width: wrap(720) }),
      ]),
    ]),
    15,
  );
}

function slideClientLanding() {
  const modules = [
    ["首页", "学习概览、连续打卡、AI 入口"],
    ["任务", "筛选、编辑、子任务"],
    ["记录", "日志、课程筛选、历史沉淀"],
    ["日历", "任务和日志月视图"],
    ["统计", "课程分布和 7 天趋势"],
    ["闪卡", "AI 生成问答复盘"],
  ];
  normalSlide(
    "03-2 / IMPLEMENTATION",
    "客户端功能落地",
    "目前客户端已形成从任务创建、学习执行、数据记录到复盘分析的完整闭环，核心页面均可进入演示流程。",
    grid({ width: fill, height: fill, columns: [fr(0.9), fr(1.1)], columnGap: 56 }, [
      panel(
        { width: fill, height: fill, padding: 28, fill: C.white, stroke: "#D8E3F4", borderRadius: 36 },
        grid({ width: fill, height: fill, columns: [fr(1), fr(1)], rows: [fr(1), fr(1)], gap: 14 }, [
          screenshotSlot("首页", "学习概览、连续打卡、AI 入口", C.blue, screenshots.home),
          screenshotSlot("AI 助手", "日志生成、任务拆解、风险提醒", C.cyan, screenshots.ai),
          screenshotSlot("任务", "筛选、编辑、子任务", C.green, screenshots.tasks),
          screenshotSlot("统计", "课程分布和 7 天趋势", C.red, screenshots.stats),
        ]),
      ),
      grid({ width: fill, height: fill, columns: [fr(1), fr(1)], rows: [fr(1), fr(1), fr(1)], gap: 18 }, modules.map(([name, desc], i) =>
        panel({ width: fill, height: fill, padding: 22, fill: C.white, stroke: "#D8E3F4", borderRadius: 24 }, column({ width: fill, height: fill, justify: "center", gap: 8 }, [
          t(String(i + 1).padStart(2, "0"), { size: 18, bold: true, color: [C.blue, C.cyan, C.green, C.amber, C.red, C.violet][i], width: fill }),
          t(name, { size: 28, bold: true, color: C.ink, width: fill }),
          small(desc, C.muted, fill),
        ])),
      )),
    ]),
    16,
  );
}

function slideTechInnovation() {
  normalSlide(
    "03-3 / INNOVATION",
    "功能与性能创新点",
    "创新点集中在学习过程数据化、AI 输出结构化、移动端能力融合和稳定演示机制。",
    grid({ width: fill, height: fill, columns: [fr(1), fr(1)], rows: [fr(1), fr(1)], gap: 22 }, [
      panel({ width: fill, height: fill, padding: 28, fill: C.white, stroke: "#D8E3F4", borderRadius: 28 }, column({ width: fill, height: fill, gap: 12, justify: "center" }, [
        t("学习印记端侧化", { size: 30, bold: true, color: C.blue, width: fill }),
        t("任务、日志、周报、闪卡优先沉淀在本地，为隐私保护和端侧模型扩展打基础。", { size: 23, color: C.ink, width: fill }),
      ])),
      panel({ width: fill, height: fill, padding: 28, fill: C.white, stroke: "#D8E3F4", borderRadius: 28 }, column({ width: fill, height: fill, gap: 12, justify: "center" }, [
        t("AI 输出结构化", { size: 30, bold: true, color: C.green, width: fill }),
        t("大模型结果映射到现有数据模型，不停留在聊天文本，能被后续页面继续使用。", { size: 23, color: C.ink, width: fill }),
      ])),
      panel({ width: fill, height: fill, padding: 28, fill: C.white, stroke: "#D8E3F4", borderRadius: 28 }, column({ width: fill, height: fill, gap: 12, justify: "center" }, [
        t("智能输入融合", { size: 30, bold: true, color: C.cyan, width: fill }),
        t("结合语音输入、OCR、图片理解，让任务创建和知识提取更贴近移动端真实场景。", { size: 23, color: C.ink, width: fill }),
      ])),
      panel({ width: fill, height: fill, padding: 28, fill: C.white, stroke: "#D8E3F4", borderRadius: 28 }, column({ width: fill, height: fill, gap: 12, justify: "center" }, [
        t("稳定演示机制", { size: 30, bold: true, color: C.amber, width: fill }),
        t("无 API Key 时自动 Mock，真机能力加容错，保证比赛现场演示链路稳定。", { size: 23, color: C.ink, width: fill }),
      ])),
    ]),
    17,
  );
}

function slideFeasibilityDemo() {
  const flow = [
    "首页展示学习概览",
    "AI 生成学习日志",
    "AI 拆解复杂任务",
    "生成分析周报",
    "运行风险提醒",
    "进入知识闪卡复盘",
  ];
  normalSlide(
    "03-4 / FEASIBILITY",
    "可行性论证与 Demo 路径",
    "项目已完成 40 个任务，具备从首页到 AI 助手再到复盘功能的连续演示链路。",
    grid({ width: fill, height: fill, columns: [fr(1), fr(1)], columnGap: 58 }, [
      panel(
        { width: fill, height: fill, padding: 34, fill: "#0F172A", borderRadius: 34 },
        column({ width: fill, height: fill, gap: 22, justify: "center" }, [
          t("40 个任务完成", { size: 46, bold: true, color: C.white, width: fill }),
          t("基础架构、核心页面、AIGC 能力、DeepSeek & 智能输入、知识闪卡等阶段均已进入可演示状态。", { size: 25, color: "#CBD5E1", width: fill }),
          rule({ width: fixed(260), stroke: C.blue2, weight: 5 }),
          t("结论：不是单纯策划方案，而是具备可运行 Demo 和持续扩展路径的客户端作品。", { size: 25, bold: true, color: C.white, width: fill }),
        ]),
      ),
      column({ width: fill, height: fill, gap: 16, justify: "center" }, flow.map((item, i) =>
        row({ width: fill, height: fixed(72), gap: 16, align: "center" }, [
          shape({ width: fixed(20), height: fixed(20), fill: i < 3 ? C.blue : C.green, radius: 999 }),
          t(`${i + 1}. ${item}`, { size: 25, bold: i === 0 || i === flow.length - 1, color: C.ink, width: fill }),
        ]),
      )),
    ]),
    18,
  );
}

function slideAiSection() {
  normalSlide(
    "04-1 / MODEL APPLICATIONS",
    "第四部分：大模型应用说明",
    "蓝心大模型与 DeepSeek 共同支撑对话、图片理解、OCR、学习分析和风险预测。",
    grid({ width: fill, height: fill, columns: [fr(1), fr(1), fr(1)], rows: [fr(1), fr(1)], gap: 20 }, [
      labeledShot("AI 学习助手", "生成日志 / 拆解任务 / 风险提醒", C.blue, screenshots.ai),
      labeledShot("拍照记录学习", "移动端拍照入口", C.cyan, screenshots.home),
      labeledShot("学习记录", "自然语言转结构化记录", C.green, screenshots.logs),
      labeledShot("学习统计", "课程分布 / 趋势 / 完成率", C.amber, screenshots.stats),
      labeledShot("专注计时", "番茄钟后生成日志", C.red, screenshots.timer),
      labeledShot("知识闪卡", "日志转问答卡片", C.violet, screenshots.flashcards),
    ]),
    19,
  );
}

function slideAiApplications() {
  normalSlide(
    "04-1 / MODEL APPLICATIONS",
    "大模型具体应用场景",
    "AI 能力贯穿输入、生成、分析、预警和复盘五类场景，形成面向学习管理的模型应用组合。",
    grid({ width: fill, height: fill, columns: [fr(1), fr(1), fr(1)], rows: [fr(1), fr(1)], gap: 20 }, [
      screenshotSlot("AI 流式对话", "token-by-token 响应 / Markdown", C.blue),
      screenshotSlot("图片理解", "拍照 / 选图 / Vision 分析", C.cyan),
      screenshotSlot("OCR 提取", "题目和笔记内容识别", C.green),
      screenshotSlot("学习日志生成", "自然语言转结构化记录", C.amber),
      screenshotSlot("周报与风险", "7 维分析 / 风险等级", C.red),
      screenshotSlot("知识闪卡", "日志转问答卡片", C.violet),
    ]),
    20,
  );
}

function slideModelEngines() {
  const engines = [
    ["蓝心大模型", "Chat Completions / Vision / OCR", "适合图片理解、文字识别和智能对话。", C.blue],
    ["DeepSeek", "Chat Completions / JSON 输出", "适合结构化学习日志、任务拆解、分析周报。", C.green],
  ];
  normalSlide(
    "04-2 / DUAL ENGINE",
    "蓝心 / DeepSeek 双引擎能力图",
    "双引擎设计让作品既能展示多模态能力，也能保障核心文本分析与结构化输出稳定。",
    grid({ width: fill, height: fill, columns: [fr(1), fr(1)], columnGap: 42 }, engines.map(([name, caps, desc, color]) =>
      panel(
        { width: fill, height: fill, padding: 36, fill: C.white, stroke: "#D8E3F4", borderRadius: 36 },
        column({ width: fill, height: fill, gap: 24, justify: "center" }, [
          t(name, { size: 44, bold: true, color, width: fill }),
          t(caps, { size: 25, bold: true, color: C.ink, width: fill }),
          rule({ width: fixed(240), stroke: color, weight: 5 }),
          t(desc, { size: 24, color: C.muted, width: fill }),
          bulletList([
            "API Key 安全存储",
            "模型可切换",
            "未配置时使用 Mock 演示模式",
          ], color, 21),
        ]),
      ),
    )),
    20,
  );
}

function slideAiMechanism() {
  const steps = [
    ["用户输入", "文本 / 语音 / 图片 / OCR 结果"],
    ["Prompt 约束", "明确角色、字段、输出格式和风险维度"],
    ["模型调用", "蓝心或 DeepSeek Chat Completions"],
    ["JSON 解析", "映射为日志、任务、周报、风险、闪卡模型"],
    ["页面回写", "预览编辑、一键保存、后续复盘"],
  ];
  normalSlide(
    "04-3 / TECH MECHANISM",
    "AI 技术机制拆解",
    "通过结构化 Prompt 和 JSON 输出约束，把大模型回答转化为 App 可继续消费的数据。",
    grid({ width: fill, height: fill, columns: [fr(0.96), fr(1.04)], columnGap: 56 }, [
      column({ width: fill, height: fill, gap: 16, justify: "center" }, steps.map(([name, desc], i) =>
        row({ width: fill, height: fixed(86), gap: 16, align: "center" }, [
          panel({ width: fixed(58), height: fixed(58), fill: [C.blue, C.cyan, C.green, C.amber, C.red][i], borderRadius: 999 }, t(String(i + 1), { size: 24, bold: true, color: C.white, width: fill })),
          column({ width: fill, height: hug, gap: 5 }, [
            t(name, { size: 27, bold: true, color: C.ink, width: fill }),
            small(desc, C.muted, fill),
          ]),
        ]),
      )),
      panel(
        { width: fill, height: fill, padding: 34, fill: "#0F172A", borderRadius: 34 },
        column({ width: fill, height: fill, gap: 20, justify: "center" }, [
          t("Prompt 机制重点", { size: 32, bold: true, color: C.blue2, width: fill }),
          t("1. 明确学习场景与输出目标\n2. 限制为固定 JSON 字段\n3. 根据任务/日志上下文生成建议\n4. 解析失败时保留 Mock 回退和容错提示", { size: 25, color: C.white, width: fill, lineHeight: 1.25 }),
        ]),
      ),
    ]),
    21,
  );
}

function slideSummary() {
  const slide = deck.slides.add();
  add(
    slide,
    layers({ width: fill, height: fill }, [
      shape({ width: fill, height: fill, fill: C.bg }),
      grid(
        {
          width: fill,
          height: fill,
          padding: { x: 94, y: 76 },
          columns: [fr(1), fr(1)],
          rows: [fr(1), auto],
          columnGap: 66,
        },
        [
          column({ width: fill, height: fill, gap: 26, justify: "center" }, [
            t("总结与未来展望", { size: 68, bold: true, color: C.ink, width: fill }),
            t("StudyTrace 将学习过程从“零散记录”转化为“可追踪、可分析、可复盘”的个人学习资产。", { size: 29, color: C.muted, width: wrap(820) }),
            row({ width: fill, height: hug, gap: 14 }, [
              chip("应用价值", C.blue),
              chip("交互完整", C.green),
              chip("技术可行", C.amber),
              chip("AI 深度", C.cyan),
            ]),
          ]),
          panel(
            { width: fill, height: fill, padding: 34, fill: C.white, stroke: "#D8E3F4", borderRadius: 38 },
            column({ width: fill, height: fill, gap: 22, justify: "center" }, [
              t("后续方向", { size: 30, bold: true, color: C.blue, width: fill }),
              bulletList([
                "接入端侧大模型，提升隐私保护和离线能力。",
                "恢复本地通知，支持任务截止提醒。",
                "扩展云同步和多端数据迁移。",
                "形成学期报告、课程复盘和学习小组能力。",
              ], C.blue, 24),
            ]),
          ),
          row({ columnSpan: 2, width: fill, height: hug, justify: "between", align: "center" }, [
            image({ dataUrl: logoDataUrl, width: fixed(190), height: fixed(54), fit: "contain", alt: "StudyTrace logo" }),
            t("THANK YOU", { size: 24, bold: true, color: C.muted, width: wrap(240) }),
          ]),
        ],
      ),
    ]),
  );
}

slideCover();
slideContents();
slideTeam();
slideIntro();
slidePainPoints();
slideDesignIdea();
slideValue();
slideCompetition();
slidePoster();
slideVisualSystem();
slideScreens();
slideTimerFlow();
slideTaskFlow();
slideTechSection();
slideArchitecture();
slideClientLanding();
slideTechInnovation();
slideFeasibilityDemo();
slideAiSection();
slideModelEngines();
slideAiMechanism();
slideSummary();

const pptx = await PresentationFile.exportPptx(deck);
await pptx.save(EXPORT);
await pptx.save(TEMPLATE);

const previewPaths = [];
for (let i = 0; i < deck.slides.count; i += 1) {
  const slide = deck.slides.getItem(i);
  const blob = await deck.export({ slide, format: "png" });
  const buffer = Buffer.from(await blob.arrayBuffer());
  const previewPath = path.join(PREVIEW_DIR, `slide_${String(i + 1).padStart(2, "0")}.png`);
  await fs.writeFile(previewPath, buffer);
  previewPaths.push(previewPath);
}

const imported = await PresentationFile.importPptx(await FileBlob.load(EXPORT));
const importedPreviewPaths = [];
for (let i = 0; i < imported.slides.count; i += 1) {
  const blob = await imported.export({ slide: imported.slides.getItem(i), format: "png" });
  const buffer = Buffer.from(await blob.arrayBuffer());
  const previewPath = path.join(PREVIEW_DIR, `imported_slide_${String(i + 1).padStart(2, "0")}.png`);
  await fs.writeFile(previewPath, buffer);
  importedPreviewPaths.push(previewPath);
}

const report = {
  sourceTemplate: TEMPLATE,
  backup: BACKUP,
  export: EXPORT,
  overwrittenTemplate: TEMPLATE,
  slideCount: deck.slides.count,
  importedSlideCount: imported.slides.count,
  previews: previewPaths,
  importedPreviews: importedPreviewPaths,
};
await fs.writeFile(path.join(OUT_DIR, "studytrace_ppt_report.json"), JSON.stringify(report, null, 2), "utf8");
console.log(JSON.stringify(report, null, 2));
