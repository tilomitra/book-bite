import crypto from 'crypto';
import { supabase } from '../config/supabase';

/**
 * Reading pass: every account can open 5 books in full. Sharing an invite code adds 5 more to both
 * sides: the friend who joins with the code, and the owner of the code (up to MAX_FRIENDS friends).
 * Subscribers ($9/month, StoreKit) read without limit; the app checks that on device.
 */
export const FREE_BOOKS = 5;
export const BOOKS_PER_INVITE = 5;
/** Friends whose joining still earns the code's owner more books. Limits farming with fake accounts. */
export const MAX_FRIENDS = 20;
/** Only new accounts can use a code: "install the app and add the code" */
export const REDEEM_WINDOW_DAYS = 30;

/** No 0/O, 1/I/L: codes are read aloud and typed by hand */
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 6;
const CODE_PATTERN = /^[A-HJ-NP-Z2-9]{6}$/;

export function generateInviteCode(randomBytes: (size: number) => Buffer = crypto.randomBytes): string {
  // 31 symbols: reject bytes >= 248 (8 x 31) so every symbol is equally likely
  let code = '';
  while (code.length < CODE_LENGTH) {
    for (const byte of randomBytes(CODE_LENGTH * 2)) {
      if (byte < 248 && code.length < CODE_LENGTH) code += CODE_ALPHABET[byte % CODE_ALPHABET.length];
    }
  }
  return code;
}

/** Upper-cases and drops spaces, dashes and a "BOOKBITE" prefix; null if it can't be a code */
export function normalizeInviteCode(input: unknown): string | null {
  if (typeof input !== 'string') return null;
  const code = input.toUpperCase().replace(/[^A-Z0-9]/g, '').replace(/^BOOKBITE/, '');
  return CODE_PATTERN.test(code) ? code : null;
}

export function bookLimit(friendsJoined: number, joinedWithCode: boolean): number {
  return FREE_BOOKS
    + BOOKS_PER_INVITE * Math.min(Math.max(0, friendsJoined), MAX_FRIENDS)
    + (joinedWithCode ? BOOKS_PER_INVITE : 0);
}

export type RedeemError = 'invalid_code' | 'own_code' | 'already_joined' | 'account_too_old';

export const REDEEM_ERROR_MESSAGES: Record<RedeemError, string> = {
  invalid_code: "That code doesn't match anyone's invite. Check it and try again.",
  own_code: "That's your own code. Send it to a friend instead.",
  already_joined: 'You already used a friend\'s code. Each account can use one.',
  account_too_old: `Invite codes are for new accounts, in their first ${REDEEM_WINDOW_DAYS} days.`
};

/** Why `redeemer` can't use `ownerId`'s code, or null if they can */
export function redeemProblem(opts: {
  redeemerId: string;
  redeemerCreatedAt: string | Date | undefined;
  ownerId: string | null;
  alreadyJoined: boolean;
  now?: Date;
}): RedeemError | null {
  if (!opts.ownerId) return 'invalid_code';
  if (opts.ownerId === opts.redeemerId) return 'own_code';
  if (opts.alreadyJoined) return 'already_joined';
  if (!isNewAccount(opts.redeemerCreatedAt, opts.now)) return 'account_too_old';
  return null;
}

/** Accounts can use a code in their first REDEEM_WINDOW_DAYS days. Unknown creation date counts as new. */
export function isNewAccount(createdAt: string | Date | undefined, now: Date = new Date()): boolean {
  if (!createdAt) return true;
  return now.getTime() - new Date(createdAt).getTime() <= REDEEM_WINDOW_DAYS * 24 * 60 * 60 * 1000;
}

/** Link a friend opens: the invite page, which sends them to the App Store and opens the app with the code */
export function inviteUrl(code: string): string {
  const base = (process.env.PUBLIC_BASE_URL || 'https://book-bite.onrender.com').replace(/\/$/, '');
  return `${base}/invite/${code}`;
}

export interface ReadingPassStatus {
  freeBooks: number;
  booksPerInvite: number;
  limit: number;
  unlockedBookIds: string[];
  invite: {
    code: string;
    url: string;
    friendsJoined: number;
    maxFriends: number;
    joinedWithCode: boolean;
    canJoinWithCode: boolean;
  };
}

interface PassUser {
  id: string;
  created_at?: string;
}

export class RedeemFailure extends Error {
  constructor(public readonly code: RedeemError) {
    super(REDEEM_ERROR_MESSAGES[code]);
  }
}

export class ReadingPassService {
  async status(user: PassUser): Promise<ReadingPassStatus> {
    const [code, friendsJoined, joinedWithCode, unlockedBookIds] = await Promise.all([
      this.codeFor(user.id),
      this.friendsJoined(user.id),
      this.joinedWithCode(user.id),
      this.unlockedBookIds(user.id)
    ]);
    return {
      freeBooks: FREE_BOOKS,
      booksPerInvite: BOOKS_PER_INVITE,
      limit: bookLimit(friendsJoined, joinedWithCode),
      unlockedBookIds,
      invite: {
        code,
        url: inviteUrl(code),
        friendsJoined,
        maxFriends: MAX_FRIENDS,
        joinedWithCode,
        canJoinWithCode: !joinedWithCode && isNewAccount(user.created_at)
      }
    };
  }

  /** Unlocks books in order while books are left. Also syncs books a guest opened before signing in. */
  async unlock(user: PassUser, bookIds: string[]): Promise<ReadingPassStatus> {
    const [friendsJoined, joinedWithCode] = await Promise.all([
      this.friendsJoined(user.id),
      this.joinedWithCode(user.id)
    ]);
    const { error } = await supabase.rpc('unlock_books', {
      p_user_id: user.id,
      p_book_ids: bookIds,
      p_limit: bookLimit(friendsJoined, joinedWithCode)
    });
    if (error) throw new Error(`Failed to unlock books: ${error.message}`);
    return this.status(user);
  }

  async redeem(user: PassUser, rawCode: unknown): Promise<ReadingPassStatus> {
    const code = normalizeInviteCode(rawCode);
    if (!code) throw new RedeemFailure('invalid_code');

    const [{ data: owner, error: ownerError }, alreadyJoined] = await Promise.all([
      supabase.from('referral_codes').select('user_id').eq('code', code).maybeSingle(),
      this.joinedWithCode(user.id)
    ]);
    if (ownerError) throw new Error(`Failed to look up invite code: ${ownerError.message}`);

    const problem = redeemProblem({
      redeemerId: user.id,
      redeemerCreatedAt: user.created_at,
      ownerId: owner?.user_id ?? null,
      alreadyJoined
    });
    if (problem) throw new RedeemFailure(problem);

    const { error } = await supabase.from('referrals').insert({
      referrer_id: owner!.user_id,
      referred_id: user.id,
      code
    });
    // Unique referred_id: a second request that raced this one
    if (error?.code === '23505') throw new RedeemFailure('already_joined');
    if (error) throw new Error(`Failed to redeem invite code: ${error.message}`);

    console.log(JSON.stringify({ event: 'invite_redeemed', referrer: owner!.user_id, referred: user.id }));
    return this.status(user);
  }

  /** The user's code, made on first request. Retries on the rare clash with an existing code. */
  private async codeFor(userId: string): Promise<string> {
    const { data, error } = await supabase.from('referral_codes').select('code').eq('user_id', userId).maybeSingle();
    if (error) throw new Error(`Failed to load invite code: ${error.message}`);
    if (data?.code) return data.code;

    for (let attempt = 0; attempt < 5; attempt++) {
      const code = generateInviteCode();
      const { error: insertError } = await supabase.from('referral_codes').insert({ user_id: userId, code });
      if (!insertError) return code;
      if (insertError.code !== '23505') throw new Error(`Failed to create invite code: ${insertError.message}`);
      // Either the code is taken or a parallel request made this user's code: re-read before retrying
      const { data: existing } = await supabase.from('referral_codes').select('code').eq('user_id', userId).maybeSingle();
      if (existing?.code) return existing.code;
    }
    throw new Error('Failed to create invite code');
  }

  private async friendsJoined(userId: string): Promise<number> {
    const { count, error } = await supabase
      .from('referrals')
      .select('id', { count: 'exact', head: true })
      .eq('referrer_id', userId);
    if (error) throw new Error(`Failed to count invites: ${error.message}`);
    return count ?? 0;
  }

  private async joinedWithCode(userId: string): Promise<boolean> {
    const { count, error } = await supabase
      .from('referrals')
      .select('id', { count: 'exact', head: true })
      .eq('referred_id', userId);
    if (error) throw new Error(`Failed to check invite: ${error.message}`);
    return (count ?? 0) > 0;
  }

  private async unlockedBookIds(userId: string): Promise<string[]> {
    const { data, error } = await supabase
      .from('book_unlocks')
      .select('book_id')
      .eq('user_id', userId)
      .order('created_at', { ascending: true })
      .limit(1000);
    if (error) throw new Error(`Failed to load unlocked books: ${error.message}`);
    return (data ?? []).map((row) => row.book_id as string);
  }
}
