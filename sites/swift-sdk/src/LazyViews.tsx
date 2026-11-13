import { lazy, Suspense, type ComponentProps, type ComponentType } from "react";
import type * as Charts from "@openuidev/react-ui/Charts";
import type * as Dates from "@openuidev/react-ui/DatePicker";
import type * as Tables from "@openuidev/react-ui/EditableTable";

// Only the view is deferred; GenUI definitions, schemas and state hooks stay original.
function deferred<P extends object>(
  load: () => Promise<{ default: ComponentType<P> }>,
  label: string,
) {
  const Original = lazy(load);
  return function DeferredView(props: P) {
    return (
      <Suspense fallback={<p className="micro">{label}</p>}>
        <Original {...props} />
      </Suspense>
    );
  };
}
export const AreaChartCondensed = deferred<
  ComponentProps<typeof Charts.AreaChartCondensed>
>(
  () =>
    import("@guide/chart-source").then((module) => ({
      default: module.AreaChartCondensed,
    })),
  "加载图表…",
);
export const LineChartCondensed = deferred<
  ComponentProps<typeof Charts.LineChartCondensed>
>(
  () =>
    import("@guide/chart-source").then((module) => ({
      default: module.LineChartCondensed,
    })),
  "加载图表…",
);
export const BarChartCondensed = deferred<
  ComponentProps<typeof Charts.BarChartCondensed>
>(
  () =>
    import("@guide/chart-source").then((module) => ({
      default: module.BarChartCondensed,
    })),
  "加载图表…",
);
export const HorizontalBarChart = deferred<
  ComponentProps<typeof Charts.HorizontalBarChart>
>(
  () =>
    import("@guide/chart-source").then((module) => ({
      default: module.HorizontalBarChart,
    })),
  "加载图表…",
);
export const PieChart = deferred<ComponentProps<typeof Charts.PieChart>>(
  () =>
    import("@guide/chart-source").then((module) => ({
      default: module.PieChart,
    })),
  "加载图表…",
);
export const RadialChart = deferred<ComponentProps<typeof Charts.RadialChart>>(
  () =>
    import("@guide/chart-source").then((module) => ({
      default: module.RadialChart,
    })),
  "加载图表…",
);
export const RadarChart = deferred<ComponentProps<typeof Charts.RadarChart>>(
  () =>
    import("@guide/chart-source").then((module) => ({
      default: module.RadarChart,
    })),
  "加载图表…",
);
export const ScatterChart = deferred<
  ComponentProps<typeof Charts.ScatterChart>
>(
  () =>
    import("@guide/chart-source").then((module) => ({
      default: module.ScatterChart,
    })),
  "加载图表…",
);
export const SingleStackedBar = deferred<
  ComponentProps<typeof Charts.SingleStackedBar>
>(
  () =>
    import("@guide/chart-source").then((module) => ({
      default: module.SingleStackedBar,
    })),
  "加载图表…",
);
export const DatePicker = deferred<ComponentProps<typeof Dates.DatePicker>>(
  () =>
    import("@guide/date-picker-source").then((module) => ({
      default: module.DatePicker,
    })),
  "加载日期选择器…",
);
export const EditableTable = deferred<
  ComponentProps<typeof Tables.EditableTable>
>(
  () =>
    import("@guide/editable-table-source").then((module) => ({
      default: module.EditableTable,
    })),
  "加载表格…",
);
export const EditableTableChangesBar = deferred<
  ComponentProps<typeof Tables.EditableTableChangesBar>
>(
  () =>
    import("@guide/editable-table-source").then((module) => ({
      default: module.EditableTableChangesBar,
    })),
  "加载表格操作…",
);
