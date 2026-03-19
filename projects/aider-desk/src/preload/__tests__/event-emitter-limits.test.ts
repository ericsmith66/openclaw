import { EventEmitter } from 'events';

import { describe, expect, it, vi } from 'vitest';

import { configureEventEmitterMaxListeners } from '../event-emitter-config';

describe('PRD-0060 - EventEmitter max listeners', () => {
  it('should set EventEmitter.defaultMaxListeners to 100', () => {
    configureEventEmitterMaxListeners();
    expect(EventEmitter.defaultMaxListeners).toBe(100);
  });

  it('should not emit MaxListenersExceededWarning with 50 listeners', () => {
    configureEventEmitterMaxListeners();
    const emitter = new EventEmitter();
    const warnSpy = vi.spyOn(process, 'emitWarning');

    for (let i = 0; i < 50; i++) {
      emitter.on('test', () => {});
    }

    const warningCalls = warnSpy.mock.calls.filter((call) => {
      const message = String(call[0] ?? '');
      return message.includes('MaxListenersExceededWarning');
    });

    expect(warningCalls).toHaveLength(0);
  });
});
