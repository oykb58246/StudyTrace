import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomBytes } from 'crypto';
import * as argon2 from 'argon2';
import { PrismaService } from '../../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(dto: RegisterDto) {
    const passwordHash = await argon2.hash(dto.password);
    try {
      const user = await this.prisma.user.create({
        data: {
          username: dto.username.trim(),
          email: dto.email?.trim().toLowerCase() || null,
          passwordHash,
          profile: {
            create: {
              nickname: dto.nickname?.trim() || '学习者',
            },
          },
        },
        include: { profile: true },
      });

      return this.issueTokenPair(user.id, user.username, this.serializeUser(user));
    } catch (error) {
      if (this.isUniqueError(error)) {
        throw new ConflictException('用户名或邮箱已被注册');
      }
      throw error;
    }
  }

  async login(dto: LoginDto) {
    const identifier = dto.identifier.trim();
    const user = await this.prisma.user.findFirst({
      where: {
        OR: [
          { username: identifier },
          { email: identifier.toLowerCase() },
        ],
      },
      include: { profile: true },
    });

    if (!user || !(await argon2.verify(user.passwordHash, dto.password))) {
      throw new UnauthorizedException('账号或密码错误');
    }

    return this.issueTokenPair(user.id, user.username, this.serializeUser(user));
  }

  async refresh(dto: RefreshTokenDto) {
    const tokenHash = this.hashToken(dto.refreshToken);
    const saved = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: { include: { profile: true } } },
    });

    if (!saved || saved.revokedAt || saved.expiresAt.getTime() <= Date.now()) {
      throw new UnauthorizedException('刷新凭据无效或已过期');
    }

    await this.prisma.refreshToken.update({
      where: { id: saved.id },
      data: { revokedAt: new Date() },
    });

    return this.issueTokenPair(
      saved.user.id,
      saved.user.username,
      this.serializeUser(saved.user),
    );
  }

  async logout(userId: string, refreshToken?: string) {
    if (refreshToken) {
      await this.prisma.refreshToken.updateMany({
        where: {
          userId,
          tokenHash: this.hashToken(refreshToken),
          revokedAt: null,
        },
        data: { revokedAt: new Date() },
      });
      return { ok: true };
    }
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { ok: true };
  }

  async deleteAccount(userId: string, accessToken?: string) {
    await this.prisma.$transaction([
      this.prisma.refreshToken.updateMany({
        where: { userId, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
      this.prisma.user.delete({ where: { id: userId } }),
    ]);
    void accessToken;
    return { ok: true };
  }

  private async issueTokenPair(userId: string, username: string, user: unknown) {
    const accessToken = await this.jwt.signAsync({ sub: userId, username });
    const refreshToken = randomBytes(48).toString('base64url');
    const days = Number(this.config.get('REFRESH_TOKEN_DAYS') ?? 30);
    const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);

    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: this.hashToken(refreshToken),
        expiresAt,
      },
    });

    return { user, accessToken, refreshToken };
  }

  private hashToken(token: string) {
    return createHash('sha256').update(token).digest('hex');
  }

  private serializeUser(user: {
    id: string;
    username: string;
    email: string | null;
    createdAt: Date;
    profile?: unknown;
  }) {
    return {
      id: user.id,
      username: user.username,
      email: user.email,
      profile: user.profile,
      createdAt: user.createdAt,
    };
  }

  private isUniqueError(error: unknown) {
    return typeof error === 'object' && error !== null && (error as { code?: string }).code === 'P2002';
  }
}
