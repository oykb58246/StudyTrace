import { Module } from '@nestjs/common';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { VivoGatewayService } from './vivo-gateway.service';

@Module({
  controllers: [AiController],
  providers: [AiService, VivoGatewayService],
  exports: [AiService, VivoGatewayService],
})
export class AiModule {}
