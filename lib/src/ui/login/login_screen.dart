import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' hide Image, LinearGradient, RadialGradient;

import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/rive_safe_widget.dart';
import '../shell/app_shell.dart';

enum _CtaState {
  idle,
  loading,
  error,
  success,
  confetti,
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _sheetController;
  late final Animation<Offset> _sheetOffset;
  final ValueNotifier<int> _pageIndex = ValueNotifier<int>(0);
  final ValueNotifier<double> _pageProgress = ValueNotifier<double>(0);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  _CtaState _ctaState = _CtaState.idle;
  bool _isRegisterMode = false;

  bool get _isOnLoginPage => _pageIndex.value == 1;

  void _handlePageScroll() {
    if (!_pageController.hasClients) {
      return;
    }
    final progress =
        (_pageController.page ?? _pageController.initialPage.toDouble())
            .clamp(0.0, 1.0);
    _pageProgress.value = progress;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController()..addListener(_handlePageScroll);
    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _sheetOffset = Tween<Offset>(
      begin: const Offset(0, 1.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _sheetController,
        curve: Curves.easeOutBack,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _sheetController.forward();
      }
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageScroll);
    _pageController.dispose();
    _sheetController.dispose();
    _pageIndex.dispose();
    _pageProgress.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handlePrimaryAction() async {
    if (_ctaState == _CtaState.loading || _ctaState == _CtaState.confetti) {
      return;
    }

    if (!_isOnLoginPage) {
      await _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 440),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    setState(() => _ctaState = _CtaState.loading);
    await Future<void>.delayed(const Duration(milliseconds: 820));
    if (!mounted) {
      return;
    }

    setState(() => _ctaState = _CtaState.success);
    await Future<void>.delayed(const Duration(milliseconds: 460));
    if (!mounted) {
      return;
    }

    setState(() => _ctaState = _CtaState.confetti);
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const AppShell(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.shell,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const RepaintBoundary(child: _SplashBackground()),
            if (_ctaState == _CtaState.confetti)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(child: _ConfettiBurst()),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: _sheetOffset,
                child: ValueListenableBuilder<double>(
                  valueListenable: _pageProgress,
                  builder: (context, progress, _) {
                    final sheetHeight = lerpDouble(356, 520, progress)!;
                    final buttonBottom = lerpDouble(28, 52, progress)!;

                    return SizedBox(
                      key: const Key('welcome_bottom_sheet'),
                      height: sheetHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFCFCFF),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(34),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x33191B2A),
                                      blurRadius: 36,
                                      offset: Offset(0, -10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    const SizedBox(height: 18),
                                    Expanded(
                                      child: PageView(
                                        controller: _pageController,
                                        onPageChanged: (index) {
                                          _pageIndex.value = index;
                                        },
                                        physics: const ClampingScrollPhysics(),
                                        children: [
                                          const _LandingPage(),
                                          _LoginPage(
                                            emailController: _emailController,
                                            passwordController:
                                                _passwordController,
                                            isRegisterMode: _isRegisterMode,
                                            onToggleMode: () {
                                              setState(() => _isRegisterMode =
                                                  !_isRegisterMode);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 18,
                            bottom: buttonBottom,
                            child: ValueListenableBuilder<int>(
                              valueListenable: _pageIndex,
                              builder: (context, pageIndex, _) {
                                return _PrimaryActionButton(
                                  key: ValueKey('primary_button_${pageIndex}_$_isRegisterMode'),
                                  progress: progress,
                                  isLoginPage: pageIndex == 1,
                                  isRegisterMode: _isRegisterMode,
                                  state: _ctaState,
                                  onTap: _handlePrimaryAction,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xFFF7F8FB),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: -10,
                  left: -150,
                  child: _BackdropBlob(
                    size: 360,
                    color: const Color(0xFF53C6FF).withValues(alpha: 0.88),
                  ),
                ),
                Positioned(
                  top: 44,
                  right: -120,
                  child: _BackdropBlob(
                    size: 320,
                    color: const Color(0xFF2DE2D3).withValues(alpha: 0.72),
                  ),
                ),
                Positioned(
                  bottom: 110,
                  right: -70,
                  child: _BackdropBlob(
                    size: 340,
                    color: const Color(0xFFFF5C8A).withValues(alpha: 0.80),
                  ),
                ),
                Positioned(
                  bottom: 214,
                  left: 86,
                  child: _BackdropBlob(
                    size: 250,
                    color: const Color(0xFFA05BFF).withValues(alpha: 0.48),
                  ),
                ),
                Positioned(
                  bottom: 84,
                  left: 126,
                  child: _BackdropBlob(
                    size: 238,
                    color: const Color(0xFFFFB36C).withValues(alpha: 0.46),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.18),
                    const Color(0xFFF7F8FB).withValues(alpha: 0.62),
                  ],
                  stops: const [0.0, 0.52, 1.0],
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: 0.14,
                child: SafeRiveAsset(
                  asset: AppAssets.shapes,
                  artboard: 'Shapes',
                  animations: ['Animation 19'],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.78),
                  radius: 1.02,
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackdropBlob extends StatelessWidget {
  const _BackdropBlob({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 58, sigmaY: 58),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _LandingPage extends StatelessWidget {
  const _LandingPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 30, 26, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Image.asset(
            'logo/logo黑透明.png',
            height: 48,
            key: const Key('landing_logo'),
            fit: BoxFit.fitHeight,
          ),
          const SizedBox(height: 16),
          const Text(
            '学习周报助手',
            key: Key('landing_title'),
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 20,
              height: 1.04,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '管理课程任务、记录学习过程、自动生成学习周报。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  color: AppColors.body.withValues(alpha: 0.72),
                ),
          ),
        ],
      ),
    );
  }
}

class _LoginPage extends StatefulWidget {
  const _LoginPage({
    required this.emailController,
    required this.passwordController,
    required this.isRegisterMode,
    required this.onToggleMode,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isRegisterMode;
  final VoidCallback onToggleMode;

  @override
  State<_LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<_LoginPage> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final isRegister = widget.isRegisterMode;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 30, 26, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRegister ? '创建账号' : '登录',
            key: ValueKey('auth_title_$isRegister'),
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isRegister ? '注册新账号，开始管理学习。' : '登录以继续使用学迹。',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  color: AppColors.body.withValues(alpha: 0.72),
                ),
          ),
          const SizedBox(height: 22),
          if (isRegister)
            TextFormField(
              key: const Key('signup_username_field'),
              controller: widget.emailController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '用户名',
                suffixIcon: Icon(Icons.person_outline_rounded),
              ),
            )
          else
            TextFormField(
              key: const Key('login_email_field'),
              controller: widget.emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '用户名 / 邮箱',
                suffixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
          const SizedBox(height: 16),
          TextFormField(
            key: ValueKey(isRegister ? 'signup_password_field' : 'login_password_field'),
            controller: widget.passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: '密码',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: widget.onToggleMode,
            child: Text(
              isRegister ? '已有账号？去登录' : '没有账号？去注册',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF7040F2),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    super.key,
    required this.progress,
    required this.isLoginPage,
    required this.isRegisterMode,
    required this.state,
    required this.onTap,
  });

  final double progress;
  final bool isLoginPage;
  final bool isRegisterMode;
  final _CtaState state;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return _AnimatedPrimaryActionButton(
      progress: progress,
      isLoginPage: isLoginPage,
      isRegisterMode: isRegisterMode,
      state: state,
      onTap: onTap,
    );
  }
}

class _AnimatedPrimaryActionButton extends StatefulWidget {
  const _AnimatedPrimaryActionButton({
    required this.progress,
    required this.isLoginPage,
    required this.isRegisterMode,
    required this.state,
    required this.onTap,
  });

  final double progress;
  final bool isLoginPage;
  final bool isRegisterMode;
  final _CtaState state;
  final Future<void> Function() onTap;

  @override
  State<_AnimatedPrimaryActionButton> createState() =>
      _AnimatedPrimaryActionButtonState();
}

class _AnimatedPrimaryActionButtonState
    extends State<_AnimatedPrimaryActionButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;
  late final Animation<double> _shineOffset;
  late final AnimationController _errorController;
  late final Animation<double> _errorSlide;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _pressScale = Tween<double>(
      begin: 1,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
    _shineOffset = Tween<double>(
      begin: -1.4,
      end: 1.6,
    ).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
    _errorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _errorSlide = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -7.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -7.0, end: 5.0), weight: 1.5),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: 0.0), weight: 1.5),
    ]).animate(
      CurvedAnimation(parent: _errorController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _errorController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AnimatedPrimaryActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == _CtaState.error && oldWidget.state != _CtaState.error) {
      _errorController.forward(from: 0);
    }
  }

  bool get _isWidgetTest {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    return bindingName.contains('TestWidgetsFlutterBinding');
  }

  Future<void> _handleTap() async {
    if (widget.state == _CtaState.loading ||
        widget.state == _CtaState.confetti) {
      return;
    }
    if (_isWidgetTest) {
      await widget.onTap();
      return;
    }
    await _pressController.forward(from: 0);
    if (mounted) {
      await _pressController.reverse();
    }
    await widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.state == _CtaState.loading;
    final isError = widget.state == _CtaState.error;
    final isSuccess =
        widget.state == _CtaState.success || widget.state == _CtaState.confetti;
    final backgroundGradient = isError
        ? const LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [Color(0xFFF05A5A), Color(0xFFB11F45)],
          )
        : const LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: [Color(0xFFEF6850), Color(0xFF8B2192)],
          );

    return AnimatedBuilder(
      animation: Listenable.merge([_pressController, _errorController]),
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(_errorSlide.value, 0),
          child: Transform.scale(
            scale: _pressScale.value,
            child: Material(
              key: const Key('splash_primary_button'),
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _handleTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: lerpDouble(138, 176, widget.progress)!,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: backgroundGradient,
                    boxShadow: [
                      BoxShadow(
                        color: (isError
                                ? const Color(0x66E84E69)
                                : const Color(0x33F77D8E))
                            .withValues(
                          alpha: 0.22 - _pressController.value * 0.08,
                        ),
                        blurRadius: 20 - _pressController.value * 6,
                        offset: Offset(0, 12 - _pressController.value * 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Align(
                          alignment: Alignment(_shineOffset.value, 0),
                          child: Container(
                            width: 34,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.28),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                width: 90 + widget.progress * 28,
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    if (!isLoading && !isError)
                                      Opacity(
                                        opacity: 1 - widget.progress,
                                        child: const Text(
                                          '开始使用',
                                          maxLines: 1,
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    if (!isLoading && !isError)
                                      Opacity(
                                        opacity: widget.progress,
                                        child: Text(
                                          widget.isRegisterMode ? '注册' : '登录',
                                          maxLines: 1,
                                          overflow: TextOverflow.fade,
                                          softWrap: false,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    if (isLoading)
                                      Text(
                                        widget.isRegisterMode ? '注册中...' : '登录中...',
                                        maxLines: 1,
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    if (isError)
                                      const Text(
                                        '请完整填写',
                                        maxLines: 1,
                                        overflow: TextOverflow.fade,
                                        softWrap: false,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: ExcludeSemantics(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: isSuccess
                                        ? const SafeRiveAsset(
                                            key: ValueKey('cta_success_icon'),
                                            asset: AppAssets.check,
                                            artboard: 'check_artboard',
                                            animations: ['Check'],
                                            width: 20,
                                            height: 20,
                                          )
                                        : isError
                                            ? _RiveStatusIcon(
                                                key: ValueKey(
                                                  'cta_status_${widget.state.name}',
                                                ),
                                                state: widget.state,
                                              )
                                            : isLoading
                                                ? const SafeRiveAsset(
                                                    key: ValueKey('cta_loading_icon'),
                                                    asset: AppAssets.button,
                                                    artboard: 'main',
                                                    animations: ['active'],
                                                    width: 20,
                                                    height: 20,
                                                  )
                                                : const Icon(
                                                    Icons.arrow_forward_rounded,
                                                    key: ValueKey('cta_arrow_icon'),
                                                    color: Colors.white,
                                                    size: 18,
                                                  ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RiveStatusIcon extends StatefulWidget {
  const _RiveStatusIcon({
    super.key,
    required this.state,
  });

  final _CtaState state;

  @override
  State<_RiveStatusIcon> createState() => _RiveStatusIconState();
}

class _RiveStatusIconState extends State<_RiveStatusIcon> {
  SMITrigger? _checkTrigger;
  SMITrigger? _errorTrigger;
  SMITrigger? _resetTrigger;
  _CtaState? _lastTriggeredState;

  @override
  void didUpdateWidget(covariant _RiveStatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncState();
  }

  void _handleInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1',
    );
    if (controller == null) {
      return;
    }
    artboard.addController(controller);
    final checkInput = controller.findInput<bool>('Check');
    final errorInput = controller.findInput<bool>('Error');
    final resetInput = controller.findInput<bool>('Reset');
    if (checkInput is SMITrigger) {
      _checkTrigger = checkInput;
    }
    if (errorInput is SMITrigger) {
      _errorTrigger = errorInput;
    }
    if (resetInput is SMITrigger) {
      _resetTrigger = resetInput;
    }
    _syncState(force: true);
  }

  void _syncState({bool force = false}) {
    if (!force && _lastTriggeredState == widget.state) {
      return;
    }
    if (widget.state == _CtaState.error) {
      _errorTrigger?.fire();
      _lastTriggeredState = widget.state;
      return;
    }
    if (widget.state == _CtaState.success ||
        widget.state == _CtaState.confetti) {
      _checkTrigger?.fire();
      _lastTriggeredState = widget.state;
      return;
    }
    _resetTrigger?.fire();
    _lastTriggeredState = widget.state;
  }

  @override
  Widget build(BuildContext context) {
    return SafeRiveAsset(
      asset: AppAssets.check,
      artboard: 'check_artboard',
      width: 20,
      height: 20,
      onInit: _handleInit,
    );
  }
}

class _ConfettiBurst extends StatefulWidget {
  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst> {
  SMITrigger? _explosionTrigger;

  void _handleInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1',
    );
    if (controller == null) {
      return;
    }
    artboard.addController(controller);
    final trigger = controller.findInput<bool>('Trigger explosion');
    if (trigger is SMITrigger) {
      _explosionTrigger = trigger;
      _explosionTrigger?.fire();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeRiveAsset(
      asset: AppAssets.confetti,
      artboard: 'Main',
      fit: BoxFit.cover,
      onInit: _handleInit,
    );
  }
}
