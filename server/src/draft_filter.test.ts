import { describe, it, expect } from 'bun:test';
import { newDraft, draftPool, sharedDeckFilter, startDraft, cancelDraft, DRAFT_DECKS, VANILLA_DRAFT_DECKS, type DraftRoom, type DraftDeps } from './draft';

const VANILLA = new Set(VANILLA_DRAFT_DECKS);

function deps(): DraftDeps {
  return { sendTo: () => {}, isBot: () => false, connected: () => true, log: () => {} };
}

describe('draft deck filter', () => {
  it('keeps the 15 vanilla decks first in the list', () => {
    expect(VANILLA_DRAFT_DECKS.length).toBe(15);
    expect(VANILLA_DRAFT_DECKS).not.toContain('Cobalt Deck');
    expect(VANILLA_DRAFT_DECKS).not.toContain('Lilac Deck');
  });

  it('only vanilla from either player wins', () => {
    expect(sharedDeckFilter(['vanilla', 'both'])).toBe('vanilla');
    expect(sharedDeckFilter(['both', 'vanilla'])).toBe('vanilla');
    expect(sharedDeckFilter(['vanilla', 'new'])).toBe('vanilla');
    expect(sharedDeckFilter(['new', 'both'])).toBe('new');
    expect(sharedDeckFilter(['both', 'both'])).toBe('both');
  });

  it('missing or junk fields keep the old behaviour', () => {
    expect(sharedDeckFilter([])).toBe('both');
    expect(sharedDeckFilter([undefined, undefined])).toBe('both');
    expect(sharedDeckFilter(['x', 7, null])).toBe('both');
    for (let i = 0; i < 50; i++) {
      const seed = 'old' + i;
      expect(newDraft(seed, [0, 1], 2, 5).pool).toEqual(draftPool(seed, 5));
      expect(newDraft(seed, [0, 1], 2, 7).pool).toEqual(draftPool(seed, 7, DRAFT_DECKS));
    }
  });

  it('a vanilla pool never holds an Overhaul deck', () => {
    for (let i = 0; i < 300; i++) {
      for (const size of [5, 7]) {
        const pool = newDraft('v' + i, [0, 1], 2, size, 'vanilla').pool;
        expect(pool.length).toBe(size);
        expect(new Set(pool).size).toBe(size);
        for (const d of pool) expect(VANILLA.has(d)).toBe(true);
      }
    }
  });

  it('a new-decks pool uses every new deck first and tops up with vanilla', () => {
    for (let i = 0; i < 100; i++) {
      const five = newDraft('n' + i, [0, 1], 2, 5, 'new').pool;
      for (const d of five) expect(VANILLA.has(d)).toBe(false);
      const seven = newDraft('n' + i, [0, 1], 2, 7, 'new').pool;
      expect(seven.length).toBe(7);
      expect(new Set(seven).size).toBe(7);
      expect(seven.filter(d => !VANILLA.has(d)).length).toBe(5);
    }
  });

  it('startDraft builds one shared vanilla pool when one seat sent vanilla', () => {
    for (const filters of [['vanilla', undefined], [undefined, 'vanilla'], ['both', 'vanilla']]) {
      const room: DraftRoom = { code: 'T', ranked: true, rankedSeed: 'seed-' + filters.join(), settings: {} };
      const d = startDraft(room, deps(), room.rankedSeed, filters);
      for (const x of d.pool) expect(VANILLA.has(x)).toBe(true);
      cancelDraft(room, true);
    }
  });
});
