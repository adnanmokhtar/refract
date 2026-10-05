import request from 'supertest';
import { asAgent, bootApp, BootedApp } from './boot-app.e2e';

describe('admin (e2e)', () => {
  let booted: BootedApp;

  beforeAll(async () => {
    booted = await bootApp();
  });

  it('lets an admin list the agents of the tenant', async () => {
    await request(booted.app.getHttpServer()).get('/admin/agents').set(asAgent('tn_a', 'admin')).expect(200);
  });

  it('refuses the agent list to a non-admin agent', async () => {
    await request(booted.app.getHttpServer()).get('/admin/agents').set(asAgent('tn_a', 'agent')).expect(403);
  });

  it('refuses to disable an agent for a non-admin agent', async () => {
    await request(booted.app.getHttpServer()).post('/admin/agents/agent_tn_a/disable').set(asAgent('tn_a', 'agent')).expect(403);
  });

  it('refuses another agent profile to a non-admin agent', async () => {
    await request(booted.app.getHttpServer()).get('/admin/agents/agent_tn_a').set(asAgent('tn_a', 'agent')).expect(403);
  });
});
