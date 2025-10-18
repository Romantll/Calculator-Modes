import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; //must add with flutter pub add shared_preferences

void main() {
  runApp(const SnazzyCalculatorApp());
}

class SnazzyCalculatorApp extends StatefulWidget{
  const SnazzyCalculatorApp({super.key});

  @override
  State<SnazzyCalculatorApp> createState() => _SnazzyCalculatorAppState();
}

class _SnazzyCalculatorAppState extends State<SnazzyCalculatorApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState(){
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async{
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('theme_is_dark') ?? false;
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_is_dark', mode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context){
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
        onToggleTheme: () async{
          setState(() {
            _themeMode = 
                _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
          });
          await _saveTheme(_themeMode);
        },
        themeMode: _themeMode,
      ),
    );
  }
}

class CalculatorPage extends StatefulWidget{
  const CalculatorPage({super.key, required this.onToggleTheme, required this.themeMode});

  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage>{
  bool _showDebug = false;
  String _history = '';
  String _main = '0';

  double? _firstOperand;
  String? _operator;
  bool _isTypeingSecondOperand = false;
  bool _error = false;

  final List<String> _keys = const [
    'C', 'Del', '÷', 'x',
    '7', '8', '9', '-',
    '4', '5', '6', '+',
    '1', '2', '3', '=',
    '0', '.', '', '',
  ];

  void _onKeyTap(String key){
    HapticFeedback.lightImpact();
    print('Tapped: ' + key);
    if (_error && key != 'C'){
      print('Blocked input due to error state. Press C to Clear');
      return;
    }

    if (RegExp(r'^[0-9]$').hasMatch(key)){
      _appendDigit(key);
      print('MAIN after digit: $_main');
      return;
    }

    switch (key) {
      case '.':
        _appendDot();
        break;
      case 'Del':
        _deleteLast();
        break;
      case 'C':
        _clearAll();
        break;
      case '+':
      case '-':
      case 'x':
      case '÷':
        _selectOperator(key);
        break;
      case '=':
        _computeEquals();
        break;
      default:
        break;
    }
  }

  void _appendDigit(String d){
    setState(() {
      //Replace leading 0 unless building decimal
      if (_isTypeingSecondOperand && _main == '0'){
        _main = d;
        return;
      }
      if (_main == '0'){
        _main = d;
      } else {
        _main += d;
      }
     });
   }

  void _appendDot(){
    setState(() {
      //Only one dot per current operand
      if (_main.contains('.')) return;
      _main = _main.isEmpty ? '0.' : _main + '.';
    });
  }

  void _deleteLast() {
    setState(() {
      if(_main.isNotEmpty && _main != '0'){
        _main = _main.substring(0, _main.length - 1);
      }
      if (_main.isEmpty) _main = '0';
    });
  }

  void _clearAll() {
    setState(() {
      _history = '';
      _main = '0';
      _firstOperand = null;
      _operator = null;
      _isTypeingSecondOperand = false;
      _error = false;
    });
  }

  void _selectOperator(String op) {
    setState(() {
      final current = double.tryParse(_main) ?? 0.0;

      //If we chose operator but haven't type second operand
      if (_firstOperand != null && _isTypeingSecondOperand && (_main == '0' || _main.isEmpty)) {
        _operator = op;
        _history = '${_formatNumber(_firstOperand!)} $op';
        return;
      }

      _firstOperand = current;
      _operator = op;
      _history = '${_formatNumber(current)} $op';
      _main = '0';
      _isTypeingSecondOperand = true;
    });
  }

  void _computeEquals(){
    if (_firstOperand == null || _operator == null) return;

    final second = double.tryParse(_main) ?? 0.0;
    final first = _firstOperand!;
    double result;

    switch (_operator){
      case '+':
        result = first + second;
        break;
      case '-':
        result = first - second;
        break;
      case 'x':
        result = first * second;
        break;
      case '÷':
        //Error handling
        if (second == 0){
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot divide by zero')),
          );
          _showError('$first / 0');
          return;
        }
        result = first/second;
        break;
      default:
        return;
    }
  
    setState(() {
      _history = '${_formatNumber(first)} $_operator ${_formatNumber(second)} =';
      _main = _formatNumber(result);
      _firstOperand = null;
      _operator = null;
      _isTypeingSecondOperand = false;
    });
  }

  void _showError(String expression){
    setState(() {
      _history = '$expression =';
      _main = 'Error';
      _error = true;
    });
  }

  String _formatNumber(double value){
    if(value.isNaN ||  value.isInfinite) return value.toString();
    final asInt = value.toInt();
    if (value == asInt.toDouble()) return asInt.toString();
    //Trim trailing zeros
    var s = value.toStringAsFixed(10);
    s = s.replaceFirst(RegExp(r'\.0+$'), '');
    s = s.replaceFirst(RegExp(r'(\.\d*?)0+\$'), r'$1');
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snazzy Calculator'),
        actions: [
          IconButton(
            tooltip: 'Toggle ${widget.themeMode == ThemeMode.light ? 'Dark' : 'Light'} Mode',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.themeMode == ThemeMode.light
              ?Icons.dark_mode_outlined
              : Icons.light_mode_outlined,
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              //Debugging
              if (_showDebug)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('dbg MAIN: $_main', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      Text('op: ${_operator ?? '∅'} first: ${_firstOperand?.toString() ?? '∅'}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
                    ],
                  ),
                ),
              //History
              Text(
                _history,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 18,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              //Main Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  _main,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              //keypad
              Expanded(
                child: GridView.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: _keys
                    .where((k) => k.isNotEmpty)
                    .map((k) => _CalcButton(
                        label: k,
                        onTap: () => _onKeyTap(k),
                        isAccent: ['C', 'Del', '+', '-', 'x', '÷', '='].contains(k),
                    ))
                  .toList(),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _CalcButton extends StatelessWidget {
  const _CalcButton({
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.isAccent = false,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isAccent;

  @override 
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return FilledButton(
      onPressed: onTap,
      onLongPress: onLongPress,
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          isAccent ? cs.primaryContainer : cs.surfaceVariant,
        ),
        foregroundColor: WidgetStatePropertyAll(
          isAccent ? cs.onPrimaryContainer : cs.onSurface,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 16)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
    );
  }
}