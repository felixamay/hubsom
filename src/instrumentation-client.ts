/**
 * Dev-only guard for a Next.js / React Turbopack bug:
 * `performance.measure` throws when RSC profiling ends with a negative
 * timestamp (e.g. after `redirect()` / `notFound()` aborts a component).
 * @see https://github.com/vercel/next.js/issues/86060
 */
if (process.env.NODE_ENV === "development") {
  const perf = globalThis.performance;
  if (perf && typeof perf.measure === "function") {
    const original = perf.measure.bind(perf);
    perf.measure = ((...args: Parameters<Performance["measure"]>) => {
      try {
        return original(...args);
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        if (
          message.includes("negative time stamp") ||
          message.includes("cannot be negative")
        ) {
          return undefined as unknown as PerformanceMeasure;
        }
        throw err;
      }
    }) as Performance["measure"];
  }
}
