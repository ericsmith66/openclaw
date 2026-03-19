import { describe, expect, it } from 'vitest';

import { getOllamaAiderMapping } from '../ollama';

describe('PRD-0050 - Ollama Aider prefix', () => {
  it('should return ollama/ prefix for Aider CLI compatibility', () => {
    const mapping = getOllamaAiderMapping(
      {
        id: 'provider-1',
        name: 'Ollama Provider',
        provider: {
          provider: 'ollama',
          baseUrl: 'http://localhost:11434',
        },
      } as any,
      'qwen3',
    );

    expect(mapping.modelName).toBe('ollama/qwen3');
    expect(mapping.modelName).not.toContain('ollama_chat');
  });

  it('should work with various model names', () => {
    const models = ['qwen3', 'codellama', 'llama2', 'mistral'];

    for (const modelId of models) {
      const mapping = getOllamaAiderMapping(
        {
          id: 'provider-1',
          name: 'Ollama Provider',
          provider: {
            provider: 'ollama',
          },
        } as any,
        modelId,
      );

      expect(mapping.modelName).toBe(`ollama/${modelId}`);
    }
  });
});
