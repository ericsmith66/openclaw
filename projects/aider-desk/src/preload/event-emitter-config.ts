import { EventEmitter } from 'events';

/**
 * PRD-0060: Increase max listeners for complex IPC + multi-agent workflows.
 *
 * Node.js defaults to 10 listeners per event and emits noisy false-positive
 * `MaxListenersExceededWarning` warnings in legitimate scenarios (multiple tasks,
 * file watchers, IPC channels).
 */
export const configureEventEmitterMaxListeners = (): void => {
  EventEmitter.defaultMaxListeners = 100;
};
