const histograms = new Map<string, number[]>();

export const metrics = {
  timer: (name: string) => {
    const start = performance.now();
    return () => {
      const list = histograms.get(name) ?? [];
      list.push(performance.now() - start);
      histograms.set(name, list);
    };
  },
};
