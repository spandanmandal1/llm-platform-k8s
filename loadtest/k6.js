// Ramp concurrent users until requests queue, so KEDA has a reason to add a replica.
// Run: make load   (k6 runs in Docker and pushes p50/p95 into Prometheus for the dashboard)
import http from 'k6/http';
import { check } from 'k6';

const BASE = __ENV.BASE_URL || 'http://localhost:8080';
const PROMPTS = [
  'Explain what a Kubernetes liveness probe is in two sentences.',
  'Give three reasons a pod can be stuck in Pending.',
  'What does a Terraform state lock prevent? One paragraph.',
  'Summarise blue-green deployment in two sentences.',
];

export const options = {
  scenarios: {
    ramp: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '1m', target: 1 },   // baseline: one user
        { duration: '30s', target: 6 },  // more users than one replica has slots (2)
        { duration: '3m', target: 6 },   // hold: queue builds, KEDA scales 1 -> 2
        { duration: '30s', target: 0 },
      ],
    },
  },
  thresholds: { checks: ['rate>0.99'] },
};

export default function () {
  const body = JSON.stringify({
    messages: [{ role: 'user', content: PROMPTS[__ITER % PROMPTS.length] }],
    max_tokens: 64,
    temperature: 0,
  });
  const res = http.post(`${BASE}/v1/chat/completions`, body, {
    headers: { 'Content-Type': 'application/json' },
    timeout: '120s',
    tags: { name: 'chat' },
  });
  check(res, { 'status 200': (r) => r.status === 200 });
}
