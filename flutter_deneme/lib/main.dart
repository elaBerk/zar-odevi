import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DiceThrowScreen(),
  ));
}
// deneme test 2
class DiceThrowScreen extends StatefulWidget {
  const DiceThrowScreen({super.key});

  @override
  State<DiceThrowScreen> createState() => _DiceThrowScreenState();
}

class _DiceThrowScreenState extends State<DiceThrowScreen>
    with TickerProviderStateMixin {
  // ─── 1. FIRLATMA YAY-YERÇEKİMİ CONTROLLER ───────────────────────────────
  late AnimationController _throwController;
  late Animation<double> _heightAnimation;   // dikey konum (0.0 → 1.0)

  // ─── 2. 3D DÖNÜŞ CONTROLLER ──────────────────────────────────────────────
  late AnimationController _rotationController;
  late Animation<double> _rotationX;         // x ekseninde dönüş açısı
  late Animation<double> _rotationZ;         // z ekseninde dönüş açısı

  // ─── 3. GÖLGE CONTROLLER ─────────────────────────────────────────────────
  late AnimationController _shadowController;
  late Animation<double> _shadowScale;       // gölge boyutu (1.0 → 0.2 → 1.0)
  late Animation<double> _shadowOpacity;     // gölge opaklığı

  final Random _random = Random();
  int _diceValue = 1;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    // ─── 1. FIRLATMA CONTROLLER ───────────────────────────────────────────
    // Toplam süre: 900ms  (yukarı çıkış: 350ms, düşüş+bounce: 550ms)
    _throwController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Fırlatma yayı: 0→1 yüksek noktada, sonra bounce ile 0'a
    _heightAnimation = TweenSequence<double>([
      // Yukarı çıkış — easeOut (hız giderek yavaşlar)
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 38, // %38 zaman dilimi
      ),
      // Düşüş — easeIn (yerçekimi etkisi, giderek hızlanır)
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.08)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 42, // %42 zaman dilimi
      ),
      // İlk bounce: yerden hafifçe sekme
      TweenSequenceItem(
        tween: Tween(begin: 0.08, end: 0.22)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      // Bounce inerken
      TweenSequenceItem(
        tween: Tween(begin: 0.22, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
    ]).animate(_throwController);

    // ─── 2. DÖNÜŞ CONTROLLER ─────────────────────────────────────────────
    // Havadayken sürekli dönsün, throw bittikten kısa süre sonra durur
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );

    // X ekseni: 0 → 2π × rastgele çarpan (gerçekçi sapma)
    // Değer throw başında hesaplanır; burada placeholder
    _rotationX = Tween<double>(begin: 0.0, end: 4 * pi)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_rotationController);

    // Z ekseni biraz daha az dönsün (sapma ekseni)
    _rotationZ = Tween<double>(begin: 0.0, end: 2.5 * pi)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_rotationController);

    // ─── 3. GÖLGE CONTROLLER ─────────────────────────────────────────────
    // Throw ile eşlenmiş: aynı süre, aynı zamansal ağırlıklar
    _shadowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Zar yükselirken gölge küçülür (1.0→0.15),
    // inerken büyür (0.15→1.0), bounce'da hafif titrer
    _shadowScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.15)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.6)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
    ]).animate(_shadowController);

    // Gölge opaklığı: yüksekte soluk, yerde tam görünür
    _shadowOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 0.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.1, end: 0.6)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 62,
      ),
    ]).animate(_shadowController);

    // Listener: animasyon bitince durumu temizle
    _throwController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isAnimating = false);
      }
    });
  }

  /// Zarı fırlat — tüm 3 controller'ı sıfırla ve başlat
  void _throwDice() {
    if (_isAnimating) return;

    // Yeni rastgele değer seç
    setState(() {
      _diceValue = _random.nextInt(6) + 1;
      _isAnimating = true;
    });

    // X ve Z için rastgele dönüş miktarı yeniden ata
    final double newRotX =
        (3 + _random.nextDouble() * 3) * pi; // 3π – 6π arası
    final double newRotZ =
        (2 + _random.nextDouble() * 2) * pi; // 2π – 4π arası

    _rotationX = Tween<double>(begin: 0.0, end: newRotX)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_rotationController);

    _rotationZ = Tween<double>(begin: 0.0, end: newRotZ)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_rotationController);

    // Tüm controller'ları sıfırla ve birlikte başlat
    _throwController.reset();
    _rotationController.reset();
    _shadowController.reset();

    _throwController.forward();
    _rotationController.forward();
    _shadowController.forward();
  }

  @override
  void dispose() {
    _throwController.dispose();
    _rotationController.dispose();
    _shadowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double maxHeight = 220.0; // zarın çıkacağı maksimum yükseklik (px)
    const double diceSize = 80.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── ANİMASYON ALANI ─────────────────────────────────────────
            SizedBox(
              height: maxHeight + diceSize + 40,
              child: AnimatedBuilder(
                // Tüm 3 controller'ı tek bir AnimatedBuilder'da dinle
                animation: Listenable.merge([
                  _throwController,
                  _rotationController,
                  _shadowController,
                ]),
                builder: (context, child) {
                  // Mevcut dikey offset hesabı
                  final double yOffset =
                      _heightAnimation.value * maxHeight;

                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // ── 3. GÖLGE ──────────────────────────────────────
                      Positioned(
                        bottom: 0,
                        child: Opacity(
                          opacity: _shadowOpacity.value,
                          child: Transform.scale(
                            scale: _shadowScale.value,
                            child: Container(
                              width: diceSize * 1.2,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius:
                                    BorderRadius.circular(diceSize * 0.6),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── 1 + 2. ZAR: yükseklik + 3D dönüş ─────────────
                      Positioned(
                        bottom: yOffset + 14, // gölgenin üstünden başla
                        child: Transform(
                          // ── 3D PERSPEKTİF MATRİSİ ──────────────────
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // perspektif derinliği
                            ..rotateX(_rotationX.value)
                            ..rotateZ(_rotationZ.value),
                          alignment: Alignment.center,
                          child: _DiceFace(
                            value: _diceValue,
                            size: diceSize,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // ── FIRLATMA BUTONU ──────────────────────────────────────────
            GestureDetector(
              onTap: _throwDice,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: _isAnimating
                      ? Colors.white24
                      : const Color(0xFFE94560),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isAnimating
                      ? []
                      : [
                          BoxShadow(
                            color: const Color(0xFFE94560).withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: Text(
                  _isAnimating ? 'Atılıyor...' : 'Zar At 🎲',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ZAR YÜZEYİ WİDGET'I ──────────────────────────────────────────────────────
class _DiceFace extends StatelessWidget {
  final int value;
  final double size;

  const _DiceFace({required this.value, required this.size});

  // Her yüz için nokta konumları (normalize 0.0–1.0 grid)
  static const Map<int, List<Offset>> _dotPositions = {
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.25, 0.25), Offset(0.75, 0.75)],
    3: [Offset(0.25, 0.25), Offset(0.5, 0.5), Offset(0.75, 0.75)],
    4: [
      Offset(0.25, 0.25),
      Offset(0.75, 0.25),
      Offset(0.25, 0.75),
      Offset(0.75, 0.75)
    ],
    5: [
      Offset(0.25, 0.25),
      Offset(0.75, 0.25),
      Offset(0.5, 0.5),
      Offset(0.25, 0.75),
      Offset(0.75, 0.75)
    ],
    6: [
      Offset(0.25, 0.2),
      Offset(0.75, 0.2),
      Offset(0.25, 0.5),
      Offset(0.75, 0.5),
      Offset(0.25, 0.8),
      Offset(0.75, 0.8)
    ],
  };

  @override
  Widget build(BuildContext context) {
    final dots = _dotPositions[value] ?? [];
    final double dotR = size * 0.09;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(4, 4),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFD8D8D8)],
        ),
      ),
      child: Stack(
        children: dots.map((pos) {
          return Positioned(
            left: pos.dx * size - dotR,
            top: pos.dy * size - dotR,
            child: Container(
              width: dotR * 2,
              height: dotR * 2,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                shape: BoxShape.circle,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}