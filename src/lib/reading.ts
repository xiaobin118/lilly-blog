// Rough reading-time estimate: CJK chars ~400/min, latin words ~200/min.
export function estimateReadTime(body: string): number {
  const cjk = (body.match(/[一-鿿]/g) ?? []).length;
  const latin = (body.replace(/[一-鿿]/g, ' ').match(/[A-Za-z0-9_]+/g) ?? []).length;
  return Math.max(1, Math.round(cjk / 400 + latin / 200));
}
