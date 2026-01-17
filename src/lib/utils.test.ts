import { describe, it, expect } from 'vitest';
import { sleep, formatDate, safeJsonParse, randomString } from './utils';

describe('utils', () => {
  describe('sleep', () => {
    it('should resolve after specified time', async () => {
      const start = Date.now();
      await sleep(50);
      const elapsed = Date.now() - start;
      expect(elapsed).toBeGreaterThanOrEqual(45);
    });
  });

  describe('formatDate', () => {
    it('should format a Date object', () => {
      const date = new Date('2024-01-15');
      const formatted = formatDate(date);
      expect(formatted).toContain('2024');
      expect(formatted).toContain('January');
    });

    it('should format a date string', () => {
      const formatted = formatDate('2024-06-20');
      expect(formatted).toContain('June');
      expect(formatted).toContain('20');
    });
  });

  describe('safeJsonParse', () => {
    it('should parse valid JSON', () => {
      const result = safeJsonParse('{"name": "test"}', { name: '' });
      expect(result).toEqual({ name: 'test' });
    });

    it('should return fallback for invalid JSON', () => {
      const fallback = { error: true };
      const result = safeJsonParse('invalid', fallback);
      expect(result).toBe(fallback);
    });
  });

  describe('randomString', () => {
    it('should generate string of specified length', () => {
      const str = randomString(10);
      expect(str).toHaveLength(10);
    });

    it('should generate different strings', () => {
      const str1 = randomString(20);
      const str2 = randomString(20);
      expect(str1).not.toBe(str2);
    });
  });
});