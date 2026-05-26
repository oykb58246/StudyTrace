import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';

type Bucket = {
  count: number;
  resetAt: number;
};

@Injectable()
export class RateLimitGuard implements CanActivate {
  private static readonly buckets = new Map<string, Bucket>();

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<{
      ip?: string;
      path?: string;
      route?: { path?: string };
      headers?: Record<string, string | string[] | undefined>;
      user?: { userId?: string };
    }>();
    const routePath = request.path ?? request.route?.path ?? '';
    const rule = this.ruleFor(routePath);
    if (!rule) return true;

    const now = Date.now();
    const identity =
      request.user?.userId ??
      this.headerValue(request.headers?.['x-forwarded-for']) ??
      request.ip ??
      'unknown';
    const key = `${rule.name}:${identity}`;
    const current = RateLimitGuard.buckets.get(key);
    const bucket =
      current && current.resetAt > now
        ? current
        : { count: 0, resetAt: now + rule.windowMs };

    bucket.count += 1;
    RateLimitGuard.buckets.set(key, bucket);
    if (bucket.count > rule.max) {
      throw new HttpException('请求过于频繁，请稍后再试', HttpStatus.TOO_MANY_REQUESTS);
    }
    return true;
  }

  private ruleFor(path: string) {
    if (path.includes('login') || path.includes('register')) {
      return { name: 'auth', max: 20, windowMs: 15 * 60 * 1000 };
    }
    if (path.startsWith('/ai') || path.includes('chat') || path.includes('ocr')) {
      return { name: 'ai', max: 120, windowMs: 60 * 60 * 1000 };
    }
    return null;
  }

  private headerValue(value: string | string[] | undefined) {
    if (Array.isArray(value)) return value[0];
    return value?.split(',')[0]?.trim();
  }
}
