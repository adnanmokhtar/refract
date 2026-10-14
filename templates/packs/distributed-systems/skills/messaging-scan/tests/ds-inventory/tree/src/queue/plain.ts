const reports = new Queue('reports', { connection, defaultJobOptions: { attempts: 4, removeOnFail: true } });
export async function kick() { await reports.add('daily', {}, { delay: 1000 }); }
const w = new Worker('reports', path.join(__dirname, 'render.js'), { connection, maxStalledCount: 3 });
