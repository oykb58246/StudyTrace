import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMe(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { profile: true },
    });
    if (!user) throw new NotFoundException('用户不存在');
    return this.serialize(user);
  }

  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const profile = await this.prisma.userProfile.upsert({
      where: { userId },
      create: {
        userId,
        nickname: dto.nickname?.trim() || '学习者',
        avatarEmoji: dto.avatarEmoji?.trim() || '🎓',
        avatarImageUrl: dto.avatarImageUrl?.trim() || null,
        bio: dto.bio ?? '好好学习，天天向上',
      },
      update: {
        ...(dto.nickname !== undefined ? { nickname: dto.nickname.trim() } : {}),
        ...(dto.avatarEmoji !== undefined ? { avatarEmoji: dto.avatarEmoji.trim() } : {}),
        ...(dto.avatarImageUrl !== undefined ? { avatarImageUrl: dto.avatarImageUrl.trim() || null } : {}),
        ...(dto.bio !== undefined ? { bio: dto.bio } : {}),
      },
    });
    return profile;
  }

  async deleteMe(userId: string) {
    await this.prisma.user.delete({ where: { id: userId } });
    return { ok: true };
  }

  private serialize(user: {
    id: string;
    username: string;
    email: string | null;
    createdAt: Date;
    profile: unknown;
  }) {
    return {
      id: user.id,
      username: user.username,
      email: user.email,
      profile: user.profile,
      createdAt: user.createdAt,
    };
  }
}
