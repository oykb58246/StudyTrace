import { AiService } from './ai.service';

function createService() {
  const prisma = {
    aiUsageLog: {
      count: jest.fn().mockResolvedValue(0),
      create: jest.fn().mockResolvedValue({}),
    },
  };
  const configValues: Record<string, string> = {
    AI_DAILY_LIMIT: '50',
    BLUEHEART_API_KEY: 'test-key',
    BLUEHEART_BASE_URL: 'https://api-ai.vivo.com.cn/v1/chat/completions',
    BLUEHEART_MODEL: 'Doubao-Seed-2.0-mini',
    VIVO_IMAGE_MODEL: 'Doubao-Seedream-5.0-lite',
    VIVO_IMAGE_SIZE_DEFAULT: '2K',
  };
  const config = {
    get: jest.fn((key: string) => configValues[key]),
  };
  const vivo = {
    postJson: jest.fn(),
    trace: jest.fn(
      (
        abilityName: string,
        endpoint: string,
        requestId: string,
        _startedAt: number,
        success: boolean,
        options: Record<string, unknown> = {},
      ) => ({
        abilityName,
        endpoint,
        requestId,
        success,
        durationMs: 0,
        ...options,
      }),
    ),
  };
  return {
    service: new AiService(prisma as any, config as any, vivo as any),
    prisma,
    config,
    vivo,
  };
}

describe('AiService image integrations', () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('repairs assistant_turn image requests when the model returns empty actions', async () => {
    const fetchSpy = jest.spyOn(global, 'fetch').mockResolvedValue({
      ok: true,
      text: async () =>
        JSON.stringify({
          choices: [
            {
              message: {
                content:
                  '{"schemaVersion":2,"reply":"抱歉，您输入的内容无法识别，请提供清晰的中文或明确的需求，我会为您操作StudyTrace App。","actions":[]}',
              },
            },
          ],
        }),
    } as Response);
    const { service } = createService();

    const result = await service.chat('user-1', {
      input: '帮我生成一张适合放进学习笔记的二叉树遍历图解，把前序、中序、后序放在一张清晰的笔记配图里',
      purpose: 'assistant_turn',
    });
    const content = JSON.parse(result.content);

    expect(fetchSpy).toHaveBeenCalled();
    expect(content.schemaVersion).toBe(2);
    expect(content.reply).toContain('生成');
    expect(content.actions).toHaveLength(1);
    expect(content.actions[0]).toMatchObject({
      actionId: 'act_1',
      type: 'media.generate_image',
    });
    expect(content.actions[0].sourceText).toContain('适合放进学习笔记');
  });

  it('sends required vivo query params for sync image generation', async () => {
    const { service, vivo } = createService();
    vivo.postJson.mockResolvedValue({
      code: 0,
      trace_id: 'task_sync_image',
      data: {
        images: [{ url: 'https://img.example.com/note-diagram.png' }],
        finish_reason: 'stop',
      },
    });

    const result = await service.submitImageTask('user-1', {
      prompt: '二叉树遍历学习图解',
    });

    expect(vivo.postJson).toHaveBeenCalledWith(
      '/api/v1/image_generation',
      expect.objectContaining({
        model: 'Doubao-Seedream-5.0-lite',
        prompt: '二叉树遍历学习图解',
        parameters: { size: '2K' },
      }),
      expect.objectContaining({
        module: 'aigc',
        request_id: expect.any(String),
        system_time: expect.any(String),
      }),
    );
    expect(result).toMatchObject({
      taskId: 'task_sync_image',
      status: 'succeeded',
      imagesUrl: ['https://img.example.com/note-diagram.png'],
      auditStatus: 'stop',
    });
  });
});
