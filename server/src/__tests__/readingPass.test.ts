import {
  bookLimit, generateInviteCode, normalizeInviteCode, redeemProblem, isNewAccount,
  FREE_BOOKS, MAX_FRIENDS
} from '../services/readingPass';
import { invitePage } from '../services/invitePage';

describe('reading pass', () => {
  it('gives 5 free books, 5 per friend up to the cap, and 5 for joining with a code', () => {
    expect(bookLimit(0, false)).toBe(FREE_BOOKS);
    expect(bookLimit(0, true)).toBe(10);
    expect(bookLimit(3, true)).toBe(25);
    expect(bookLimit(MAX_FRIENDS + 10, false)).toBe(FREE_BOOKS + 5 * MAX_FRIENDS);
    expect(bookLimit(-1, false)).toBe(FREE_BOOKS);
  });

  it('makes 6-character codes without look-alike characters', () => {
    for (let i = 0; i < 200; i++) {
      const code = generateInviteCode();
      expect(code).toMatch(/^[A-HJ-NP-Z2-9]{6}$/);
    }
    // Bytes >= 248 are skipped, so a stream of 255s then 0s still gives a valid code
    let call = 0;
    const bytes = (size: number) => Buffer.alloc(size, call++ === 0 ? 255 : 0);
    expect(generateInviteCode(bytes)).toBe('AAAAAA');
  });

  it('normalizes what people type or paste', () => {
    expect(normalizeInviteCode('abc234')).toBe('ABC234');
    expect(normalizeInviteCode(' ab c-234 ')).toBe('ABC234');
    expect(normalizeInviteCode('BOOKBITE-ABC234')).toBe('ABC234');
    expect(normalizeInviteCode('ABC10O')).toBeNull();
    expect(normalizeInviteCode('ABC23')).toBeNull();
    expect(normalizeInviteCode(42)).toBeNull();
  });

  it('allows one code per new account, never your own', () => {
    const now = new Date('2026-10-30T12:00:00Z');
    const base = { redeemerId: 'friend', redeemerCreatedAt: '2026-10-29T00:00:00Z', ownerId: 'owner', alreadyJoined: false, now };
    expect(redeemProblem(base)).toBeNull();
    expect(redeemProblem({ ...base, ownerId: null })).toBe('invalid_code');
    expect(redeemProblem({ ...base, ownerId: 'friend' })).toBe('own_code');
    expect(redeemProblem({ ...base, alreadyJoined: true })).toBe('already_joined');
    expect(redeemProblem({ ...base, redeemerCreatedAt: '2026-08-01T00:00:00Z' })).toBe('account_too_old');
    expect(isNewAccount(undefined, now)).toBe(true);
  });

  it('renders the invite page with the code', () => {
    const html = invitePage('ABC234');
    expect(html).toContain('ABC234');
    expect(html).toContain('bookbite://invite/ABC234');
    expect(html).not.toContain('<script>');
  });
});
