import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter; // [ITER4] For glassmorphism blur
import 'package:flutter/services.dart'; // [ITER2 FIX] Haptics & debug support
import 'package:shared_preferences/shared_preferences.dart'; // [ITER3] Theme persistence

// [ITER3 NOTE] Run once: flutter pub add shared_preferences

void main() {
  runApp(const SnazzyCalculatorApp());
}

class SnazzyCalculatorApp extends StatefulWidget {
  const SnazzyCalculatorApp({super.key});

  @override
  State<SnazzyCalculatorApp> createState() => _SnazzyCalculatorAppState();
}

class _SnazzyCalculatorAppState extends State<SnazzyCalculatorApp> {
  ThemeMode _themeMode = ThemeMode.light;
  
  get _focusNode => null;

  @override
  void initState() {
    super.initState();
    _loadTheme(); // [ITER3] Load saved theme on launch
  }

  // [ITER3] Persist theme choice using SharedPreferences
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('theme_is_dark') ?? false;
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_is_dark', mode == ThemeMode.dark);
  }

  @override
  void dispose() {
    _focusNode.dispose(); // [ITER5]
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Snazzy Calculator',
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: CalculatorPage(
        onToggleTheme: () async {
          setState(() {
            _themeMode =
                _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
          });
          await _saveTheme(_themeMode); // [ITER3] Save theme on toggle
        },
        themeMode: _themeMode,
      ),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key, required this.onToggleTheme, required this.themeMode});

  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  // [ITER5] Keyboard focus node for hardware key support
  final FocusNode _focusNode = FocusNode(debugLabel: 'calc-focus');
  // [ITER2.1 DEBUG] Quick inline debug toggle
  bool _showDebug = false; // [ITER3] default off for cleaner UI
  String _history = '';
  String _main = '0'; // [ITER2.1 DEBUG] main display value

  // State for operations
  double? _firstOperand;
  String? _operator; // '+', '-', '×', '÷'
  bool _isTypingSecondOperand = false;
  bool _error = false; // when true, lock input except Clear

  // Use simple ASCII '-' for reliability across fonts & key handling
  final List<String> _keys = const [
    'C', 'Del', '÷', '×',
    '7', '8', '9', '-',
    '4', '5', '6', '+',
    '1', '2', '3', '=',
    '0', '.',
  ];

  void _onKeyTap(String key) {
    // [ITER2 FIX] Haptic + debug feedback to confirm tap registration
    HapticFeedback.lightImpact();
    // ignore: avoid_print
    print('Tapped: $key');

    // If we're in an error state, only Clear works
    if (_error && key != 'C') {
      // ignore: avoid_print
      print('Blocked input due to error state. Press C to clear.');
      return;
    }

    if (RegExp(r'^[0-9]$').hasMatch(key)) {
      _appendDigit(key);
      // ignore: avoid_print
      print('MAIN after digit: $_main');
      return;
    }

    switch (key) {
      case '.':
        _appendDot();
        // ignore: avoid_print
        print('MAIN after dot: $_main');
        break;
      case 'Del':
        _deleteLast();
        // ignore: avoid_print
        print('MAIN after del: $_main');
        break;
      case 'C':
        _clearAll();
        // ignore: avoid_print
        print('Cleared. MAIN=$_main');
        break;
      case '+':
      case '-':
      case '×':
      case '÷':
        _selectOperator(key);
        // ignore: avoid_print
        print('Selected op $key, FIRST=${_firstOperand?.toString() ?? 'null'}');
        break;
      case '=':
        _computeEquals();
        // ignore: avoid_print
        print('After equals, MAIN=$_main, HISTORY=$_history');
        break;
      default:
        break;
    }
  }

  void _appendDigit(String d) {
    setState(() {
      // Replace leading '0' unless we're building a decimal like '0.x'
      if (_isTypingSecondOperand && _main == '0') {
        _main = d;
        return;
      }
      if (_main == '0') {
        _main = d;
      } else {
        _main += d;
      }
    });
  }

  void _appendDot() {
    setState(() {
      // Only one dot per current operand
      if (_main.contains('.')) return;
      _main = _main.isEmpty ? '0.' : _main + '.';
    });
  }

  void _deleteLast() {
    setState(() {
      if (_main.isNotEmpty && _main != '0') {
        _main = _main.substring(0, _main.length - 1);
        if (_main.isEmpty) _main = '0';
      }
    });
  }

  void _clearAll() {
    setState(() {
      _history = '';
      _main = '0';
      _firstOperand = null;
      _operator = null;
      _isTypingSecondOperand = false;
      _error = false;
    });
  }

  void _selectOperator(String op) {
    setState(() {
      final current = double.tryParse(_main) ?? 0.0;

      // If we already chose an operator but haven't typed the second operand yet,
      // allow changing the operator (e.g., user tapped the wrong one)
      if (_firstOperand != null && _isTypingSecondOperand && (_main == '0' || _main.isEmpty)) {
        _operator = op;
        _history = '${_formatNumber(_firstOperand!)} $op';
        return;
      }

      _firstOperand = current;
      _operator = op;
      _history = '${_formatNumber(current)} $op';
      _main = '0';
      _isTypingSecondOperand = true;
    });
  }

  void _computeEquals() {
    if (_firstOperand == null || _operator == null) return;
    final second = double.tryParse(_main) ?? 0.0;
    final first = _firstOperand!;

    double result;
    switch (_operator) {
      case '+':
        result = first + second;
        break;
      case '-':
        result = first - second;
        break;
      case '×':
        result = first * second;
        break;
      case '÷':
        if (second == 0) {
          // [ITER3] Friendly error UI + state lock until Clear
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot divide by zero')),
          );
          _showError('$first / 0');
          return;
        }
        result = first / second;
        break;
      default:
        return;
    }

    setState(() {
      _history = '${_formatNumber(first)} $_operator ${_formatNumber(second)} =';
      _main = _formatNumber(result);
      _firstOperand = null;
      _operator = null;
      _isTypingSecondOperand = false;
    });
  }

  void _showError(String expression) {
    setState(() {
      _history = '$expression =';
      _main = 'Error';
      _error = true;
    });
  }

  String _formatNumber(double value) {
    if (value.isNaN || value.isInfinite) return value.toString();
    final asInt = value.toInt();
    if (value == asInt.toDouble()) return asInt.toString();
    var s = value.toStringAsFixed(10);
    s = s.replaceFirst(RegExp(r'\.0+\$'), '');
    s = s.replaceFirst(RegExp(r'(\.\d*?)0+\$'), r'$1');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // [ITER5] Ensure focus for keyboard input
    return Scaffold(
      appBar: AppBar(
        title: const Text('Snazzy Calculator'),
        actions: [
          IconButton(
            tooltip: 'Toggle ${widget.themeMode == ThemeMode.light ? 'Dark' : 'Light'} Mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.themeMode == ThemeMode.light
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
          ),
        ],
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode, // [ITER5] hardware keyboard
        autofocus: true, // [ITER5]
        onKey: (event) {
          if (event is! RawKeyDownEvent) return; // avoid repeats [ITER5]
          final keyLabel = event.logicalKey.keyLabel;
          // Map common keys to calculator taps [ITER5]
          if (RegExp(r'^[0-9]$').hasMatch(keyLabel)) {
            _onKeyTap(keyLabel);
            return;
          }
          switch (keyLabel) {
            case '+':
            case '-':
              _onKeyTap(keyLabel);
              return;
            case '*':
              _onKeyTap('×');
              return;
            case 'x':
            case 'X':
              _onKeyTap('×');
              return;
            case '/':
              _onKeyTap('÷');
              return;
            case '.':
            case ',':
              _onKeyTap('.');
              return;
            case 'Enter':
            case 'Numpad Enter':
              _onKeyTap('=');
              return;
            case 'Backspace':
              _onKeyTap('Del');
              return;
            case 'Escape':
              _onKeyTap('C');
              return;
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF0B1220)
                    : const Color(0xFFE8EEFF),
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF151B2D)
                    : const Color(0xFFD9E3FF),
              ],
            ),
          ),
          child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // [ITER2.1 DEBUG] Tiny on-screen debug row (toggle with _showDebug)
                if (_showDebug)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('dbg MAIN: $_main', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        Text('op: ${_operator ?? '∅'}  first: ${_firstOperand?.toString() ?? '∅'}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),

                // History
                Text(
                  _history,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                // [ITER4] Main display as frosted glass card
                // [ITER5] Tap to copy, AnimatedSwitcher on value change
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: _main)); // [ITER5]
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Result copied')), // [ITER5]
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.28),
                              Colors.white.withOpacity(0.08),
                            ],
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160), // [ITER5]
                          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child), // [ITER5]
                          child: Text(
                            _main,
                            key: ValueKey(_main), // [ITER5]
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Keypad — fixed count, no blanks
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1, // [ITER3] Slightly taller buttons for better tap targets
                    children: _keys
                        .map((k) => _CalcButton(
                              label: k,
                              onTap: () => _onKeyTap(k),
                              onLongPress: k == 'Del' ? _clearAll : null, // [ITER3] Long-press Del to Clear
                              isAccent: ['=', 'C'].contains(k) || ['+', '-', '×', '÷'].contains(k), // [ITER4] Accents on ops & key actions
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
            ),
          ),
        ),
      );
  }
}

class _CalcButton extends StatefulWidget {
  const _CalcButton({
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.isAccent = false,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress; // [ITER3] Optional long-press (e.g., Del => Clear)
  final bool isAccent;

  @override
  State<_CalcButton> createState() => _CalcButtonState();
}

class _CalcButtonState extends State<_CalcButton> {
  bool _pressed = false; // [ITER5]

  void _setPressed(bool v) => setState(() => _pressed = v); // [ITER5]

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // [ITER4] Glassmorphism button with press animation
    return Listener(
      onPointerDown: (_) => _setPressed(true), // [ITER5]
      onPointerUp: (_) => _setPressed(false),  // [ITER5]
      onPointerCancel: (_) => _setPressed(false), // [ITER5]
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90), // [ITER5]
        scale: _pressed ? 0.96 : 1.0, // [ITER5]
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Material(
              color: Colors.white.withOpacity(widget.isAccent ? 0.20 : 0.12),
              child: InkWell(
                onTap: () {
                  if (widget.label == '=') {
                    HapticFeedback.mediumImpact(); // [ITER5] stronger feedback on equals
                  }
                  widget.onTap();
                },
                onLongPress: widget.onLongPress,
                splashColor: cs.primary.withOpacity(0.15),
                highlightColor: cs.primary.withOpacity(0.06),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.28)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(widget.isAccent ? 0.30 : 0.18),
                        Colors.white.withOpacity(widget.isAccent ? 0.10 : 0.08),
                      ],
                    ),
                  ),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: widget.isAccent ? cs.onPrimaryContainer : cs.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
