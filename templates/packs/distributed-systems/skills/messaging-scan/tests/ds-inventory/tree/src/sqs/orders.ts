const app = Consumer.create({ queueUrl: QUEUE_URL, batchSize: 10, handleMessage: async (m) => { await go(m); return m; } });
