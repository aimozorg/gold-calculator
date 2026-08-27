import 'package:flutter/material.dart';
import 'package:gold_calculator_engine/gold_calculator_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/subscription_service.dart';
import 'services/supabase_service.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
    await SupabaseService.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  }
  runApp(const GoldCalculatorApp());
}

enum CalcMode { sale, buy, exchange, melted }

enum AppTab { calculator, history, settings }

class HistoryItem {
  final DateTime time;
  final String title;
  final String value;
  final String detail;

  const HistoryItem({required this.time, required this.title, required this.value, required this.detail});
}

class GoldCalculatorApp extends StatelessWidget {
  const GoldCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ماشین حساب طلافروش',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Vazirmatn',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC58B2A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7F4),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFC58B2A), width: 1.5),
          ),
        ),
      ),
      home: const AppGate(),
    );
  }
}

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      // Local UI preview remains available without credentials.
      return SubscriptionGate.localPreview();
    }
    return StreamBuilder<AuthState>(
      stream: SupabaseService.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (SupabaseService.auth.currentUser == null) return const AuthScreen();
        return const SubscriptionGate();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool signUp = false;
  bool loading = false;
  String? error;

  Future<void> submit() async {
    setState(() { loading = true; error = null; });
    try {
      if (signUp) {
        await SupabaseService.auth.signUp(email: email.text.trim(), password: password.text);
      } else {
        await SupabaseService.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      }
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (e) {
      setState(() => error = 'خطای غیرمنتظره: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.workspace_premium_rounded, size: 50),
                  const SizedBox(height: 12),
                  Text(signUp ? 'ساخت حساب' : 'ورود به حساب', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                  const SizedBox(height: 18),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ایمیل')),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'رمز عبور')),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'در حال پردازش…' : (signUp ? 'ثبت‌نام' : 'ورود'))),
                  const SizedBox(height: 8),
                  TextButton(onPressed: loading ? null : () => setState(() => signUp = !signUp), child: Text(signUp ? 'قبلاً حساب ساخته‌ام' : 'حساب ندارم؛ ثبت‌نام می‌کنم')),
                ]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SubscriptionGate extends StatefulWidget {
  final bool preview;
  const SubscriptionGate({super.key}) : preview = false;
  const SubscriptionGate.localPreview({super.key}) : preview = true;
  @override State<SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<SubscriptionGate> {
  late Future<SubscriptionState> state;
  @override
  void initState() {
    super.initState();
    state = widget.preview ? Future.value(const SubscriptionState(active: true, plan: 'پیش‌نمایش')) : SubscriptionService(SupabaseService.client).current();
  }

  void refresh() => setState(() => state = SubscriptionService(SupabaseService.client).current());

  @override
  Widget build(BuildContext context) => FutureBuilder<SubscriptionState>(
    future: state,
    builder: (context, snap) {
      if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final s = snap.data!;
      if (!s.active) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.lock_outline, size: 54),
                        const SizedBox(height: 12),
                        const Text('اشتراک فعال نیست', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        const Text('برای استفاده از ماشین‌حساب حرفه‌ای باید اشتراک فعال داشته باشید.', textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton.icon(onPressed: widget.preview ? null : refresh, icon: const Icon(Icons.refresh), label: const Text('بررسی دوباره اشتراک')),
                        const SizedBox(height: 8),
                        if (!widget.preview) TextButton(onPressed: () => SupabaseService.auth.signOut(), child: const Text('خروج از حساب')),
                      ],),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return CalculatorHome(plan: s.plan, onDeactivate: () {});
    },
  );
}

class CalculatorHome extends StatefulWidget {
  final String plan;
  final VoidCallback onDeactivate;

  const CalculatorHome({super.key, required this.plan, required this.onDeactivate});

  @override
  State<CalculatorHome> createState() => _CalculatorHomeState();
}

class _CalculatorHomeState extends State<CalculatorHome> {
  final engine = GoldCalculationEngine(rules: EngineRules.mvp1405());
  CalcMode mode = CalcMode.sale;
  AppTab tab = AppTab.calculator;

  final rate18 = TextEditingController(text: '5187000');
  final rate24 = TextEditingController(text: '6916000');
  final mesghal = TextEditingController(text: '21800000');

  final weight = TextEditingController(text: '5.32');
  final purity = TextEditingController(text: '750');
  final labor = TextEditingController(text: '12');
  final profit = TextEditingController(text: '7');
  final discount = TextEditingController(text: '500000');
  final budget = TextEditingController(text: '80000000');

  final buyWeight = TextEditingController(text: '5.00');
  final buyPurity = TextEditingController(text: '750');
  final buyFactor = TextEditingController(text: '0.98');
  final buyDeduction = TextEditingController(text: '0');
  final buyFee = TextEditingController(text: '0');

  final oldWeight = TextEditingController(text: '4.00');
  final oldPurity = TextEditingController(text: '750');
  final newWeight = TextEditingController(text: '3.20');
  final newPurity = TextEditingController(text: '750');

  final meltedWeight = TextEditingController(text: '10.00');
  final meltedPurity = TextEditingController(text: '995');
  final meltLoss = TextEditingController(text: '0');
  final meltFee = TextEditingController(text: '0');

  final conversionWeight = TextEditingController(text: '10');
  final conversionFrom = TextEditingController(text: '750');
  final conversionTo = TextEditingController(text: '995');

  final List<HistoryItem> history = [];

  String resultTotal = '—';
  String resultMetal = '—';
  String resultLabor = '—';
  String resultProfit = '—';
  String resultTax = '—';
  String resultSecondary = '—';
  String status = 'آماده محاسبه';
  String currentStore = 'گالری طلای پارسیان';
  String defaultLabor = '12';
  String defaultProfit = '7';
  bool haptic = true;
  bool showWarnings = true;

  @override
  void dispose() {
    for (final c in [
      rate18, rate24, mesghal, weight, purity, labor, profit, discount, budget,
      buyWeight, buyPurity, buyFactor, buyDeduction, buyFee,
      oldWeight, oldPurity, newWeight, newPurity,
      meltedWeight, meltedPurity, meltLoss, meltFee,
      conversionWeight, conversionFrom, conversionTo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String money(Rational v) => '${_group(v.roundHalfUp().toString())} تومان';

  String grams(Rational v) => '${v.toDecimalString(scale: 3)} گرم';

  String _group(String s) {
    final neg = s.startsWith('-');
    final raw = neg ? s.substring(1) : s;
    final parts = <String>[];
    for (var i = raw.length; i > 0; i -= 3) {
      final start = (i - 3).clamp(0, raw.length);
      parts.add(raw.substring(start, i));
    }
    final joined = parts.reversed.join(',');
    return neg ? '-$joined' : joined;
  }

  Rational r(String text) => Rational.parse(text.replaceAll(',', '').trim());

  RateInput manual18() => RateInput(value: r(rate18.text), basis: PriceBasis.per18k, timestamp: DateTime.now());

  SaleInput saleInput() => SaleInput(
        grossWeight: r(weight.text),
        purity: r(purity.text),
        rate: manual18(),
        labor: LaborInput(mode: LaborMode.percent, rate: percent(r(labor.text).toDecimalString())),
        profit: ProfitInput(mode: ProfitMode.percentOfGoldPlusLabor, rate: percent(r(profit.text).toDecimalString())),
        taxRules: EngineRules.mvp1405().taxRuleSet,
        discount: DiscountInput(value: r(discount.text), mode: DiscountMode.fixed, scope: DiscountScope.total),
        roundingUnit: 1,
        timestamp: DateTime.now(),
      );

  void calculate() {
    try {
      switch (mode) {
        case CalcMode.sale:
          _calculateSale();
          return;
        case CalcMode.buy:
          _calculateBuy();
          return;
        case CalcMode.exchange:
          _calculateExchange();
          return;
        case CalcMode.melted:
          _calculateMelted();
          return;
      }
    } catch (e) {
      setState(() => status = e.toString());
    }
  }

  void _calculateSale() {
    final now = DateTime.now();
    final x = engine.calculateSale(saleInput());
    _setResult(
      total: money(x.finalTotal),
      metal: money(x.metalValue),
      labor: money(x.laborAmount),
      profit: money(x.profitAmount),
      tax: money(x.taxAmount),
      secondary: 'مالیات‌پذیر: ${money(x.taxBase)}',
      statusText: 'فروش • نرخ دستی • ${_time(now)}',
      historyTitle: 'فروش طلا',
      detail: '${r(weight.text).toDecimalString()} گرم • عیار ${r(purity.text).toDecimalString()}',
    );
  }

  void _calculateBuy() {
    final now = DateTime.now();
    final x = engine.calculateBuy(
      BuyInput(
        weight: r(buyWeight.text),
        purity: r(buyPurity.text),
        rate: manual18(),
        buyFactor: r(buyFactor.text),
        deductionMode: DeductionMode.fixed,
        deduction: r(buyDeduction.text),
        feeMode: FeeMode.fixed,
        fee: r(buyFee.text),
        timestamp: now,
      ),
    );
    _setResult(
      total: money(x.offerPrice),
      metal: money(x.baseValue),
      labor: '—',
      profit: '—',
      tax: '—',
      secondary: 'کسر: ${money(x.deductionAmount + x.feeAmount)}',
      statusText: 'خرید از مشتری • ${_time(now)}',
      historyTitle: 'خرید از مشتری',
      detail: '${r(buyWeight.text).toDecimalString()} گرم • ضریب خرید ${r(buyFactor.text).toDecimalString()}',
    );
  }

  void _calculateExchange() {
    final now = DateTime.now();
    final oldItem = BuyInput(
      weight: r(oldWeight.text),
      purity: r(oldPurity.text),
      rate: manual18(),
      buyFactor: r(buyFactor.text),
      timestamp: now,
    );
    final newItem = saleInput().copyWith(
      grossWeight: r(newWeight.text),
      purity: r(newPurity.text),
      discount: const DiscountInput(),
    );
    final x = engine.calculateExchange(ExchangeInput(oldItems: [oldItem], newItems: [newItem]));
    final direction = x.cashDifference > Rational.zero ? 'مشتری پرداخت می‌کند' : x.cashDifference < Rational.zero ? 'مشتری دریافت می‌کند' : 'تسویه صفر';
    _setResult(
      total: money(x.cashDifference.abs()),
      metal: money(x.oldCredit),
      labor: money(x.newTotal),
      profit: '—',
      tax: '—',
      secondary: direction,
      statusText: 'تعویض • ${_time(now)}',
      historyTitle: 'تعویض طلا',
      detail: '${r(oldWeight.text).toDecimalString()} گرم قدیم ← ${r(newWeight.text).toDecimalString()} گرم جدید',
    );
  }

  void _calculateMelted() {
    final now = DateTime.now();
    final x = engine.calculateMelted(
      MeltedInput(
        weight: r(meltedWeight.text),
        purity: r(meltedPurity.text),
        rate: RateInput(value: r(rate24.text), basis: PriceBasis.per24k, timestamp: now),
        feeMode: FeeMode.fixed,
        fee: r(meltFee.text),
        lossPercent: percent(r(meltLoss.text).toDecimalString()),
        lossEnabled: r(meltLoss.text) > Rational.zero,
        timestamp: now,
      ),
    );
    _setResult(
      total: money(x.finalTotal),
      metal: money(x.metalValue),
      labor: '—',
      profit: '—',
      tax: '—',
      secondary: 'وزن خالص: ${grams(x.adjustedWeight)}',
      statusText: 'آبشده • ${_time(now)}',
      historyTitle: 'محاسبه آبشده',
      detail: '${r(meltedWeight.text).toDecimalString()} گرم • عیار ${r(meltedPurity.text).toDecimalString()}',
    );
  }

  void _setResult({
    required String total,
    required String metal,
    required String labor,
    required String profit,
    required String tax,
    required String secondary,
    required String statusText,
    required String historyTitle,
    required String detail,
  }) {
    setState(() {
      resultTotal = total;
      resultMetal = metal;
      resultLabor = labor;
      resultProfit = profit;
      resultTax = tax;
      resultSecondary = secondary;
      status = statusText;
      history.insert(0, HistoryItem(time: DateTime.now(), title: historyTitle, value: total, detail: detail));
      if (history.length > 50) history.removeLast();
    });
  }

  void reverseByBudget() {
    try {
      if (mode != CalcMode.sale) {
        setState(() => status = 'محاسبه معکوس بودجه فعلاً برای حالت فروش فعال است.');
        return;
      }
      final x = engine.solveWeightForTarget(input: saleInput(), target: r(budget.text));
      setState(() => status = 'با بودجه ${_group(r(budget.text).roundHalfUp().toString())} تومان ≈ ${x.value.toDecimalString(scale: 3)} گرم');
    } catch (e) {
      setState(() => status = e.toString());
    }
  }

  void convertPurity() {
    try {
      final x = engine.convertPurity(
        weight: r(conversionWeight.text),
        fromPurity: r(conversionFrom.text),
        toPurity: r(conversionTo.text),
      );
      _showMessage('خروجی تبدیل: ${grams(x.convertedWeight)} • طلای خالص: ${grams(x.pureWeight)}');
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void saveSettings() {
    setState(() {
      currentStore = currentStore.trim().isEmpty ? 'فروشگاه طلا' : currentStore.trim();
      labor.text = defaultLabor;
      profit.text = defaultProfit;
    });
    _showMessage('تنظیمات ذخیره شد.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _time(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: _appBar(),
        body: IndexedStack(
          index: tab.index,
          children: [
            _calculatorPage(),
            _historyPage(),
            _settingsPage(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab.index,
          onDestinationSelected: (i) => setState(() => tab = AppTab.values[i]),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'ماشین حساب'),
            NavigationDestination(icon: Icon(Icons.history), label: 'تاریخچه'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
        title: Row(children: [
          const Icon(Icons.balance_outlined, color: Color(0xFFC58B2A)),
          const SizedBox(width: 8),
          const Text('ماشین‌حساب طلافروش', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: const Color(0xFFE9F8EF), borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              const Icon(Icons.wifi_off_outlined, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              Text('آفلاین', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'deactivate') widget.onDeactivate();
              if (value == 'history') setState(() => tab = AppTab.history);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'history', child: Text('تاریخچه محاسبات')),
              PopupMenuItem(value: 'deactivate', child: Text('قفل نمایشی اشتراک')),
            ],
            child: const Padding(padding: EdgeInsets.all(12), child: CircleAvatar(radius: 17, child: Text('پ'))),
          ),
        ],
      );

  Widget _calculatorPage() => SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: c.maxWidth),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _rateStrip(),
                const SizedBox(height: 14),
                _modeTabs(),
                const SizedBox(height: 14),
                Wrap(spacing: 14, runSpacing: 14, children: [
                  SizedBox(width: c.maxWidth > 980 ? (c.maxWidth - 14) / 2 : c.maxWidth, child: _inputCard()),
                  SizedBox(width: c.maxWidth > 980 ? (c.maxWidth - 14) / 2 : c.maxWidth, child: _resultCard()),
                ]),
                const SizedBox(height: 14),
                _quickActions(),
              ]),
            ),
          ),
        ),
      );

  Widget _rateStrip() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.wifi_off_outlined), SizedBox(width: 8), Text('کاملاً آفلاین')]),
              SizedBox(width: 190, child: _field('قیمت ۱۸ عیار', rate18, suffix: 'تومان')),
              SizedBox(width: 190, child: _field('قیمت ۲۴ عیار', rate24, suffix: 'تومان')),
              SizedBox(width: 190, child: _field('مظنه', mesghal, suffix: 'تومان')),
              Chip(label: Text(widget.plan == 'آزمایشی' ? 'اشتراک آزمایشی' : 'اشتراک ${widget.plan}')),
            ],
          ),
        ),
      );

  Widget _modeTabs() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<CalcMode>(
          segments: const [
            ButtonSegment(value: CalcMode.sale, label: Text('فروش طلا'), icon: Icon(Icons.shopping_bag_outlined)),
            ButtonSegment(value: CalcMode.buy, label: Text('خرید از مشتری'), icon: Icon(Icons.handshake_outlined)),
            ButtonSegment(value: CalcMode.exchange, label: Text('تعویض'), icon: Icon(Icons.sync_alt)),
            ButtonSegment(value: CalcMode.melted, label: Text('آبشده'), icon: Icon(Icons.water_drop_outlined)),
          ],
          selected: {mode},
          onSelectionChanged: (s) => setState(() {
            mode = s.first;
            status = 'آماده محاسبه';
          }),
        ),
      );

  Widget _field(String label, TextEditingController c, {String? suffix}) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      );

  Widget _inputCard() {
    switch (mode) {
      case CalcMode.sale:
        return _card(
          title: 'فروش طلا',
          icon: Icons.shopping_bag_outlined,
          children: [
            _twoFields(_field('وزن', weight, suffix: 'گرم'), _field('عیار', purity)),
            const SizedBox(height: 10),
            _twoFields(_field('اجرت', labor, suffix: '%'), _field('سود', profit, suffix: '%')),
            const SizedBox(height: 10),
            _field('تخفیف', discount, suffix: 'تومان'),
            const SizedBox(height: 12),
            _actionRow(),
          ],
        );
      case CalcMode.buy:
        return _card(
          title: 'خرید از مشتری',
          icon: Icons.handshake_outlined,
          children: [
            _twoFields(_field('وزن', buyWeight, suffix: 'گرم'), _field('عیار', buyPurity)),
            const SizedBox(height: 10),
            _twoFields(_field('ضریب خرید', buyFactor), _field('کسر ثابت', buyDeduction, suffix: 'تومان')),
            const SizedBox(height: 10),
            _field('کارمزد/کسر نهایی', buyFee, suffix: 'تومان'),
            const SizedBox(height: 12),
            _actionRow(),
          ],
        );
      case CalcMode.exchange:
        return _card(
          title: 'تعویض',
          icon: Icons.sync_alt,
          children: [
            const Align(alignment: Alignment.centerRight, child: Text('طلای قدیمی مشتری', style: TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(height: 8),
            _twoFields(_field('وزن قدیمی', oldWeight, suffix: 'گرم'), _field('عیار قدیمی', oldPurity)),
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerRight, child: Text('طلای جدید', style: TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(height: 8),
            _twoFields(_field('وزن جدید', newWeight, suffix: 'گرم'), _field('عیار جدید', newPurity)),
            const SizedBox(height: 12),
            _actionRow(),
          ],
        );
      case CalcMode.melted:
        return _card(
          title: 'آبشده',
          icon: Icons.water_drop_outlined,
          children: [
            _twoFields(_field('وزن', meltedWeight, suffix: 'گرم'), _field('عیار', meltedPurity)),
            const SizedBox(height: 10),
            _twoFields(_field('کسری ذوب', meltLoss, suffix: '%'), _field('هزینه', meltFee, suffix: 'تومان')),
            const SizedBox(height: 12),
            const Text('در این حالت قیمت ۲۴ عیارِ واردشده در نوار بالا استفاده می‌شود.', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            _actionRow(),
          ],
        );
    }
  }

  Widget _twoFields(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

  Widget _actionRow() => Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: _clearCurrentMode, icon: const Icon(Icons.delete_outline), label: const Text('پاک کردن'))),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: FilledButton.icon(onPressed: calculate, icon: const Icon(Icons.calculate), label: const Text('محاسبه'))),
      ]);

  Widget _card({required String title, required IconData icon, required List<Widget> children}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Icon(icon, color: const Color(0xFFC58B2A)), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 16),
            ...children,
          ]),
        ),
      );

  Widget _resultCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: const [Icon(Icons.receipt_long_outlined), SizedBox(width: 8), Text('نتیجه محاسبه', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
            const Divider(height: 24),
            _line('ارزش طلای پایه', resultMetal),
            _line('اجرت / مبلغ جدید', resultLabor),
            _line('سود', resultProfit),
            _line('مالیات', resultTax),
            _line('توضیح', resultSecondary),
            const Divider(),
            const Text('مبلغ نهایی', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(resultTotal, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            Text(status, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            if (mode == CalcMode.sale) ...[
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: reverseByBudget, icon: const Icon(Icons.swap_horiz), label: const Text('محاسبه معکوس'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: () => _showMessage('اشتراک‌گذاری در نسخه انتشار متصل می‌شود.'), icon: const Icon(Icons.share_outlined), label: const Text('اشتراک‌گذاری'))),
              ]),
              const SizedBox(height: 10),
              _field('بودجه هدف برای محاسبه معکوس', budget, suffix: 'تومان'),
            ],
          ]),
        ),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [Expanded(child: Text(label)), Flexible(child: Text(value, textAlign: TextAlign.left, style: const TextStyle(fontWeight: FontWeight.w700)))]),
      );

  Widget _quickActions() => Wrap(spacing: 10, runSpacing: 10, children: [
        _quick(Icons.swap_vert, 'تبدیل عیار', convertPurity),
        _quick(Icons.price_change_outlined, 'مظنه ↔ گرم', () => _showMessage('تبدیل مظنه با نرخ دستی در نسخه بعدی تکمیل می‌شود.')),
        _quick(Icons.scale_outlined, 'محاسبه وزن', reverseByBudget),
        _quick(Icons.percent, 'محاسبه اجرت', () => _showMessage('اجرت را در حالت فروش وارد کنید؛ محاسبه معکوس هم از همان‌جا در دسترس است.')),
        _quick(Icons.history, 'تاریخچه', () => setState(() => tab = AppTab.history)),
        _quick(Icons.tune, 'تنظیمات مغازه', () => setState(() => tab = AppTab.settings)),
      ]);

  Widget _quick(IconData icon, String label, VoidCallback onTap) => SizedBox(
        width: 168,
        child: Card(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Icon(icon), const SizedBox(width: 8), Expanded(child: Text(label, overflow: TextOverflow.ellipsis))])),
          ),
        ),
      );

  Widget _historyPage() => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: history.isEmpty
              ? const Center(child: Text('هنوز محاسبه‌ای ثبت نشده است.'))
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const Expanded(child: Text('تاریخچه محاسبات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                    TextButton.icon(onPressed: () => setState(() => history.clear()), icon: const Icon(Icons.delete_sweep_outlined), label: const Text('پاک کردن')),
                  ]),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final h = history[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${i + 1}')),
                            title: Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${h.detail}\n${h.time.day}/${h.time.month} • ${_time(h.time)}'),
                            isThreeLine: true,
                            trailing: Text(h.value, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
        ),
      );

  Widget _settingsPage() => Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('تنظیمات مغازه', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  TextField(
                    controller: TextEditingController(text: currentStore),
                    onChanged: (v) => currentStore = v,
                    decoration: const InputDecoration(labelText: 'نام مغازه'),
                  ),
                  const SizedBox(height: 12),
                  _twoFields(_field('اجرت پیش‌فرض', TextEditingController(text: defaultLabor), suffix: '%'), _field('سود پیش‌فرض', TextEditingController(text: defaultProfit), suffix: '%')),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(value: haptic, onChanged: (v) => setState(() => haptic = v), title: const Text('بازخورد لمسی')),
                  SwitchListTile.adaptive(value: showWarnings, onChanged: (v) => setState(() => showWarnings = v), title: const Text('هشدار ورودی‌های غیرعادی')),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: saveSettings, icon: const Icon(Icons.save_outlined), label: const Text('ذخیره تنظیمات'))),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Column(children: [
                const ListTile(title: Text('وضعیت اشتراک', style: TextStyle(fontWeight: FontWeight.w700)), trailing: Chip(label: Text('فعال'))),
                ListTile(leading: const Icon(Icons.workspace_premium_outlined), title: Text('پلن فعلی: ${widget.plan}'), subtitle: const Text('در نسخه واقعی به Supabase/پرداخت متصل خواهد شد.')),
                ListTile(leading: const Icon(Icons.wifi_off_outlined), title: const Text('محاسبات آفلاین'), subtitle: Text(showWarnings ? 'فعال • بدون وابستگی به API قیمت' : 'فعال')),
              ]),
            ),
          ],
        ),
      );

  void _clearCurrentMode() {
    setState(() {
      switch (mode) {
        case CalcMode.sale:
          weight.text = '0';
          discount.text = '0';
          break;
        case CalcMode.buy:
          buyWeight.text = '0';
          buyDeduction.text = '0';
          buyFee.text = '0';
          break;
        case CalcMode.exchange:
          oldWeight.text = '0';
          newWeight.text = '0';
          break;
        case CalcMode.melted:
          meltedWeight.text = '0';
          meltLoss.text = '0';
          meltFee.text = '0';
          break;
      }
      resultTotal = '—';
      resultMetal = '—';
      resultLabor = '—';
      resultProfit = '—';
      resultTax = '—';
      resultSecondary = '—';
      status = 'ورودی‌ها پاک شدند';
    });
  }
}

extension on SaleInput {
  SaleInput copyWith({Rational? grossWeight, Rational? purity, DiscountInput? discount}) => SaleInput(
        grossWeight: grossWeight ?? this.grossWeight,
        purity: purity ?? this.purity,
        stoneWeight: stoneWeight,
        rate: rate,
        labor: labor,
        profit: profit,
        commission: commission,
        taxRules: taxRules,
        discount: discount ?? this.discount,
        roundingMode: roundingMode,
        roundingUnit: roundingUnit,
        timestamp: timestamp,
      );
}
