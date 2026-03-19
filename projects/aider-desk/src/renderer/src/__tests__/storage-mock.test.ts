import { describe, expect, it } from 'vitest';

describe('PRD-0070 - Web Storage mocks', () => {
  it('should define localStorage and sessionStorage', () => {
    expect(localStorage).toBeDefined();
    expect(sessionStorage).toBeDefined();
  });

  it('should implement the Storage API', () => {
    localStorage.setItem('key', 'value');
    expect(localStorage.getItem('key')).toBe('value');

    localStorage.removeItem('key');
    expect(localStorage.getItem('key')).toBeNull();

    localStorage.setItem('a', '1');
    localStorage.setItem('b', '2');
    expect(localStorage.length).toBe(2);
    expect(localStorage.key(0)).not.toBeNull();

    localStorage.clear();
    expect(localStorage.length).toBe(0);
  });

  it('should keep localStorage and sessionStorage independent', () => {
    localStorage.setItem('local', '1');
    sessionStorage.setItem('session', '2');

    expect(localStorage.getItem('session')).toBeNull();
    expect(sessionStorage.getItem('local')).toBeNull();
  });
});
