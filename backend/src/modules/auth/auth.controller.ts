import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';
import { CurrentUser, CurrentUserPayload } from '../../common/current-user.decorator';
import { JwtAuthGuard } from '../../common/jwt-auth.guard';
import { RateLimitGuard } from '../../common/rate-limit.guard';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { LogoutDto } from './dto/logout.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { RegisterDto } from './dto/register.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  @UseGuards(RateLimitGuard)
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Post('login')
  @UseGuards(RateLimitGuard)
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @Post('refresh')
  refresh(@Body() dto: RefreshTokenDto) {
    return this.auth.refresh(dto);
  }

  @Post('logout')
  @UseGuards(JwtAuthGuard)
  logout(@CurrentUser() user: CurrentUserPayload, @Body() dto: LogoutDto) {
    return this.auth.logout(user.userId, dto.refreshToken);
  }

  @Post('delete-account')
  @UseGuards(JwtAuthGuard)
  deleteAccount(@CurrentUser() user: CurrentUserPayload, @Req() request: Request) {
    const auth = request.headers.authorization ?? '';
    const accessToken = auth.startsWith('Bearer ') ? auth.slice(7) : undefined;
    return this.auth.deleteAccount(user.userId, accessToken);
  }
}
