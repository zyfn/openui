// The published 0.18.1 library omits FollowUpBlock/Item from its registration.
// These adapters use its shipped native Web components and original contracts.
import React from "react";
import { defineComponent, useTriggerAction } from "@openuidev/react-lang";
import { openuiLibrary } from "@openuidev/react-ui/genui-lib";
import { FollowUpBlock as WebFollowUpBlock } from "@openuidev/react-ui/FollowUpBlock";
import { FollowUpItem as WebFollowUpItem } from "@openuidev/react-ui/FollowUpItem";
import { z } from "zod/v4";
import MapSpecimen from "./MapSpecimen";
const FollowUpItem = defineComponent({
  name: "FollowUpItem",
  description: "Clickable follow-up suggestion",
  props: z.object({ text: z.string() }),
  component: () => null,
});
const FollowUpBlock = defineComponent({
  name: "FollowUpBlock",
  description: "Follow-up suggestions at the end of a response",
  props: z.object({ items: z.array(FollowUpItem.ref) }),
  component: ({ props }) => {
    const trigger = useTriggerAction();
    return (
      <WebFollowUpBlock>
        {props.items.map((item: any, i: number) => (
          <WebFollowUpItem
            key={i}
            text={item.props.text}
            onClick={() => trigger(item.props.text)}
          />
        ))}
      </WebFollowUpBlock>
    );
  },
});
const MapPoint = defineComponent({
  name: "MapPoint",
  description: "Place record for Map",
  props: z.object({
    title: z.string(),
    lat: z.number(),
    lng: z.number(),
    imageSrc: z.string().optional(),
    url: z.string().optional(),
    description: z.string().optional(),
  }),
  component: () => null,
});
const MapView = defineComponent({
  name: "Map",
  description: "Web map adapter for SDK place coordinates",
  props: z.object({
    points: z.array(MapPoint.ref),
    crs: z.enum(["wgs84", "gcj02"]).optional(),
  }),
  component: ({ props }) =>
    props.crs === "gcj02" ? (
      <p className="micro">
        此 Web 标本只显示 WGS-84。GCJ-02 转换请在 Swift MapKit 宿主验证。
      </p>
    ) : (
      <MapSpecimen
        points={props.points.map((p: any) => ({
          name: p.props.title,
          description: p.props.description || "",
          lat: p.props.lat,
          lng: p.props.lng,
        }))}
      />
    ),
});
const SVG = defineComponent({
  name: "SVG",
  description: "Isolated Web preview of an inline SVG diagram",
  props: z.object({
    content: z.string().optional(),
    src: z.string().optional(),
    alt: z.string().optional(),
    height: z.number().optional(),
  }),
  component: ({ props }) => {
    const source = props.content;
    if (!source || props.src)
      return (
        <p className="micro">
          远程 SVG 资源请在原生宿主验证；此预览接受完整 inline content。
        </p>
      );
    const doc = new DOMParser().parseFromString(source, "image/svg+xml");
    const root = doc.documentElement;
    const box = (root.getAttribute("viewBox") || "")
      .trim()
      .split(/[\s,]+/)
      .map(Number);
    const active = Array.from(doc.querySelectorAll("*")).some(
      (el) =>
        [
          "script",
          "foreignobject",
          "iframe",
          "object",
          "embed",
          "audio",
          "video",
          "animate",
          "animatetransform",
          "set",
        ].includes(el.localName.toLowerCase()) ||
        Array.from(el.attributes).some(
          (a) =>
            a.name.toLowerCase().startsWith("on") ||
            (/(^|:)href$/.test(a.name) &&
              !a.value.startsWith("#") &&
              !a.value.startsWith("data:image/")),
        ),
    );
    if (
      source.length > 1_000_000 ||
      /<!DOCTYPE|<!ENTITY/i.test(source) ||
      doc.querySelector("parsererror") ||
      root.localName !== "svg" ||
      box.length !== 4 ||
      box.some((v) => !Number.isFinite(v)) ||
      box[2] <= 0 ||
      box[3] <= 0 ||
      active
    )
      return <p className="micro">需要有效的静态 SVG 和 viewBox。</p>;
    const html = `<!doctype html><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; script-src 'none'; base-uri 'none'"><style>html,body{margin:0;background:transparent;color:#303036;font-family:system-ui}svg{width:100%;height:100%;display:block}</style>${source}`;
    return (
      <iframe
        title={props.alt || "SVG 图解"}
        sandbox=""
        srcDoc={html}
        style={{ width: "100%", aspectRatio: `${box[2]}/${box[3]}`, border: 0 }}
      />
    );
  },
});
export const previewLibrary = openuiLibrary.extend({
  components: {
    add: [
      FollowUpBlock,
      FollowUpItem,
      {
        component: MapView,
        slots: ["Card.children", "TabItem.content", "AccordionItem.content"],
      },
      MapPoint,
      {
        component: SVG,
        slots: ["Card.children", "TabItem.content", "AccordionItem.content"],
      },
    ],
  },
});
