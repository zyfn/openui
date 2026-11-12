// Published SDK baseline; client adoption and older captures have separate identities.
export const sdkBaseline = {
  label: "RC20",
  tag: "0.1.1-rc.20",
  revision: "b8ea283916b9630ce8590338c8f8dc5b71fd75e4",
  publishedOn: "2026-11-12",
  url: "https://github.com/zyfn/openui/releases/tag/0.1.1-rc.20",
} as const;
export const sdkSource = (path: string) =>
  `https://github.com/zyfn/openui/blob/${sdkBaseline.revision}/packages/swift-ui/${path}`;
