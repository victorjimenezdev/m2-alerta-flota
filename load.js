import http from 'k6/http';
import exec from 'k6/execution';
import { check, sleep } from 'k6';

export const options = {
  scenarios: { fleet: { executor: 'shared-iterations', vus: 10, iterations: 1000, maxDuration: '30s', gracefulStop: '0s' } },
  thresholds: { checks: ['rate==1'], http_req_failed: ['rate==0'], iterations: ['count==1000'] },
};

export default function () {
  const index = exec.scenario.iterationInTest;
  const emergency = index === 999;
  const event = {
    type: emergency ? 'Emergency' : 'Position',
    vehicle_plate: 'ABC-' + String(index % 100).padStart(3, '0'),
    coordinates: { latitude: 3.45, longitude: -76.53 },
    status: emergency ? 'PANIC' : 'OK',
  };
  const sent = new Date().toISOString();
  const response = http.post(__ENV.ENDPOINT || 'http://127.0.0.1:8082/events', JSON.stringify(event),
    { headers: { 'Content-Type': 'application/json' } });
  if (emergency) console.log('final_emergency_request ' + sent + ' id=' + response.body);
  check(response, { 'status 200': r => r.status === 200 });
  sleep(0.24);
}
