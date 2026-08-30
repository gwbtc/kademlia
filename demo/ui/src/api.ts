import Urbit from '@urbit/http-api';
import type { DemoEvent } from './types';

const desk = window.desk || 'kademlia-demo';
const client = new Urbit('', '', desk);
client.ship = window.ship || '';
client.verbose = import.meta.env.DEV;

export type EventListener = (event: DemoEvent) => void;

export async function subscribe(listener: EventListener): Promise<number> {
  return client.subscribe({
    app: 'kademlia-demo',
    path: '/events',
    event: (event: DemoEvent) => listener(event),
    quit: () => window.setTimeout(() => subscribe(listener), 1_000),
    err: (error: unknown) => console.error('Kademlia Lab subscription failed', error)
  });
}

export async function unsubscribe(id: number): Promise<void> {
  await client.unsubscribe(id);
}

export async function command(json: Record<string, unknown>): Promise<void> {
  await client.poke({
    app: 'kademlia-demo',
    mark: 'kademlia-demo-command',
    json
  });
}
