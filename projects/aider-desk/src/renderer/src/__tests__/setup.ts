import '@testing-library/jest-dom';
import { beforeEach, vi } from 'vitest';

import { globalMockApi } from './mocks/api';

// PRD-0070: Provide `localStorage` + `sessionStorage` in the JSDOM test environment.
// JSDOM omits Web Storage by default; many renderer components rely on it.
class StorageMock implements Storage {
  private store: Map<string, string> = new Map();

  get length(): number {
    return this.store.size;
  }

  clear(): void {
    this.store.clear();
  }

  getItem(key: string): string | null {
    return this.store.get(key) ?? null;
  }

  setItem(key: string, value: string): void {
    this.store.set(key, String(value));
  }

  removeItem(key: string): void {
    this.store.delete(key);
  }

  key(index: number): string | null {
    const keys = Array.from(this.store.keys());
    return keys[index] ?? null;
  }
}

const localStorageMock = new StorageMock();
const sessionStorageMock = new StorageMock();

Object.defineProperty(window, 'localStorage', { value: localStorageMock, writable: true });
Object.defineProperty(window, 'sessionStorage', { value: sessionStorageMock, writable: true });
Object.defineProperty(globalThis, 'localStorage', { value: localStorageMock, writable: true });
Object.defineProperty(globalThis, 'sessionStorage', { value: sessionStorageMock, writable: true });

// Test isolation: each test starts with empty storage.
beforeEach(() => {
  localStorageMock.clear();
  sessionStorageMock.clear();
});

// Mock focus-trap-react
vi.mock('focus-trap-react', () => ({
  FocusTrap: ({ children }: { children: React.ReactNode }) => children,
}));

// Mock react-i18next
vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, options?: { provider?: string }) => options?.provider || key,
    i18n: {
      changeLanguage: vi.fn(),
    },
  }),
  initReactI18next: {
    type: '3rdParty',
    init: vi.fn(),
  },
  Trans: ({ children }: { children: React.ReactNode }) => children,
}));

// Mock Electron APIs for renderer process
Object.defineProperty(window, 'electron', {
  value: {
    showSaveDialog: vi.fn(() => Promise.resolve({ canceled: false, filePath: '/mock/path' })),
    showOpenDialog: vi.fn(() => Promise.resolve({ canceled: false, filePaths: ['/mock/path'] })),
  },
  writable: true,
});

// Mock ApplicationAPI for renderer process
Object.defineProperty(window, 'api', {
  value: globalMockApi,
  writable: true,
});
