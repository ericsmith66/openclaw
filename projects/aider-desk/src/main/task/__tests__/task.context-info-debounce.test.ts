import debounce from 'lodash/debounce';
import { describe, expect, it, vi } from 'vitest';

import { Task } from '@/task';

describe('Task - updateContextInfo debouncing', () => {
  it('coalesces burst calls into one underlying context/token update and ORs flags', async () => {
    vi.useFakeTimers();

    const task = Object.create(Task.prototype) as any;

    task.pendingContextInfoUpdate = {
      checkContextFilesIncluded: false,
      checkRepoMapIncluded: false,
    };
    task.contextInfoUpdateWaiters = [];
    task.sendRequestContextInfo = vi.fn(async () => undefined);
    task.updateAgentEstimatedTokens = vi.fn(async () => undefined);
    task.resolveContextInfoUpdateWaiters = function () {
      while (this.contextInfoUpdateWaiters.length) {
        const resolve = this.contextInfoUpdateWaiters.shift();
        resolve?.();
      }
    };

    task.debouncedUpdateContextInfo = debounce(async () => {
      const { checkContextFilesIncluded, checkRepoMapIncluded } = task.pendingContextInfoUpdate;
      task.pendingContextInfoUpdate = {
        checkContextFilesIncluded: false,
        checkRepoMapIncluded: false,
      };

      try {
        await task.sendRequestContextInfo();
        await task.updateAgentEstimatedTokens(checkContextFilesIncluded, checkRepoMapIncluded);
      } finally {
        task.resolveContextInfoUpdateWaiters();
      }
    }, 500);

    const p1 = task.updateContextInfo(false, false);
    const p2 = task.updateContextInfo(true, false);
    const p3 = task.updateContextInfo(false, true);

    await vi.advanceTimersByTimeAsync(500);
    await Promise.all([p1, p2, p3]);

    expect(task.sendRequestContextInfo).toHaveBeenCalledTimes(1);
    expect(task.updateAgentEstimatedTokens).toHaveBeenCalledTimes(1);
    expect(task.updateAgentEstimatedTokens).toHaveBeenCalledWith(true, true);
  });
});
