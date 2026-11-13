import React, { useEffect, useRef, useState } from "react";
import L from "leaflet";
import { Maximize2, X, MapPin } from "lucide-react";
import "leaflet/dist/leaflet.css";
const places = [
  {
    name: "苏堤",
    description: "西湖西侧长堤，可任选一段步行",
    lat: 30.242637,
    lng: 120.134544,
  },
  {
    name: "德寿宫",
    description: "上城区宫苑遗址博物馆",
    lat: 30.2412,
    lng: 120.16862,
  },
];
type Place = { name: string; description: string; lat: number; lng: number };
export default function MapSpecimen({ points = places }: { points?: Place[] }) {
  const container = useRef<HTMLDivElement>(null);
  const cards = useRef<HTMLDivElement>(null);
  const map = useRef<L.Map | null>(null);
  const markers = useRef<L.Marker[]>([]);
  const [selected, setSelected] = useState(0);
  const [full, setFull] = useState(false);
  const [tiles, setTiles] = useState(true);
  useEffect(() => {
    if (!container.current) return;
    const instance = L.map(container.current, {
      scrollWheelZoom: false,
      zoomControl: false,
    }).setView([30.243, 120.151], 13);
    map.current = instance;
    L.control.zoom({ position: "bottomright" }).addTo(instance);
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution:
        '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      maxZoom: 18,
    })
      .on("tileerror", () => setTiles(false))
      .addTo(instance);
    markers.current = points.map((p, i) =>
      L.marker([p.lat, p.lng], {
        icon: L.divIcon({
          className: "map-marker",
          html: `<span>${i + 1}</span>`,
          iconSize: [34, 34],
          iconAnchor: [17, 17],
        }),
      })
        .addTo(instance)
        .on("click", () => setSelected(i)),
    );
    if (points.length)
      instance.fitBounds(
        L.latLngBounds(points.map((p) => [p.lat, p.lng] as [number, number])),
        { maxZoom: 14, padding: [25, 25] },
      );
    return () => {
      instance.remove();
      map.current = null;
    };
  }, [JSON.stringify(points)]);
  useEffect(() => {
    const p = points[selected];
    if (p) map.current?.panTo([p.lat, p.lng]);
    markers.current.forEach((m, i) =>
      m.getElement()?.classList.toggle("selected", i === selected),
    );
  }, [selected, JSON.stringify(points)]);
  useEffect(() => {
    const element = container.current;
    if (!element) return;
    const observer = new ResizeObserver((entries) => {
      if (
        entries.some(
          (entry) =>
            entry.contentRect.width > 0 && entry.contentRect.height > 0,
        )
      )
        map.current?.invalidateSize();
    });
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  useEffect(() => {
    const t = setTimeout(() => map.current?.invalidateSize(), 100);
    return () => clearTimeout(t);
  }, [full]);
  useEffect(() => {
    const strip = cards.current;
    const card = strip?.querySelector<HTMLElement>('[aria-pressed="true"]');
    if (strip && card) {
      strip.scrollTo({
        left: card.offsetLeft - (strip.clientWidth - card.clientWidth) / 2,
        behavior: "auto",
      });
    }
  }, [selected, full]);
  useEffect(() => {
    if (!full) return;
    const handle = (e: KeyboardEvent) => {
      if (e.key === "Escape") setFull(false);
    };
    document.addEventListener("keydown", handle);
    const original = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = original;
      document.removeEventListener("keydown", handle);
    };
  }, [full]);
  return (
    <div
      className={full ? "map-shell expanded" : "map-shell"}
      role={full ? "dialog" : undefined}
      aria-modal={full || undefined}
      aria-label="地点地图"
    >
      <div className="map-canvas" ref={container} />
      <button
        className="map-expand"
        aria-label={full ? "关闭地图" : "展开地图"}
        onClick={() => setFull(!full)}
      >
        {full ? <X size={18} /> : <Maximize2 size={18} />}
      </button>
      <div className="map-place-cards" ref={cards}>
        {points.map((p, i) => (
          <button
            key={p.name}
            aria-pressed={selected === i}
            onClick={() => setSelected(i)}
          >
            <span className="map-number">{i + 1}</span>
            <span>
              <b>{p.name}</b>
              <small>{p.description}</small>
            </span>
          </button>
        ))}
      </div>
      {!tiles && (
        <p className="map-network">底图暂未加载；地点坐标与选择仍可查看。</p>
      )}
    </div>
  );
}
