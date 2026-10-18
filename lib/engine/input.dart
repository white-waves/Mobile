import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Міст до системної клавіатури: поле вводу малює сама гра пікселями,
// а текст набирається в невидимому TextField.
class InputRequest {
  final String initial;
  final bool obscure;
  final int maxLength;
  final bool upperCase;
  final TextInputType keyboard;
  final TextInputAction action;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  InputRequest({
    required this.initial,
    required this.onChanged,
    required this.onSubmitted,
    this.obscure = false,
    this.maxLength = 64,
    this.upperCase = false,
    this.keyboard = TextInputType.text,
    this.action = TextInputAction.next,
  });
}

class TextInputBridge {
  final TextEditingController controller = TextEditingController();
  final FocusNode focus = FocusNode();
  final ValueNotifier<InputRequest?> request = ValueNotifier(null);

  void open(InputRequest r) {
    // Скидаємо і текст, і "composing" клавіатури, щоб набране в попередньому
    // полі не перетекло в нове.
    controller.value = TextEditingValue(
      text: r.initial,
      selection: TextSelection.collapsed(offset: r.initial.length),
      composing: TextRange.empty,
    );
    request.value = r;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  void close() {
    focus.unfocus();
    request.value = null;
    restoreImmersive();
  }

  bool get isOpen => request.value != null;
}

// Одне постійне невидиме поле: клавіатура завжди прив'язана до нього,
// а набраний текст іде тому полю гри, що зараз у фокусі.
class HiddenTextInput extends StatelessWidget {
  final TextInputBridge bridge;

  const HiddenTextInput({super.key, required this.bridge});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      width: 200,
      height: 40,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0,
          child: Material(
            type: MaterialType.transparency,
            child: ValueListenableBuilder<InputRequest?>(
              valueListenable: bridge.request,
              builder: (context, r, _) => TextField(
                controller: bridge.controller,
                focusNode: bridge.focus,
                readOnly: r == null,
                obscureText: r?.obscure ?? false,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: r?.obscure ?? false ? TextInputType.visiblePassword : r?.keyboard ?? TextInputType.text,
                textInputAction: r?.action ?? TextInputAction.done,
                textCapitalization: r?.upperCase ?? false ? TextCapitalization.characters : TextCapitalization.none,
                inputFormatters: [LengthLimitingTextInputFormatter(r?.maxLength ?? 64)],
                onChanged: (text) => bridge.request.value?.onChanged(text),
                onSubmitted: (_) => bridge.request.value?.onSubmitted(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Гра на весь екран: ховаємо рядок стану й навігацію. Клавіатура їх
// повертає, тож після неї (і коли панелі з'являються самі) ховаємо знову.
void restoreImmersive() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
}

void keepImmersive(TextInputBridge bridge) {
  restoreImmersive();
  SystemChrome.setSystemUIChangeCallback((overlaysVisible) async {
    if (!overlaysVisible || bridge.isOpen) return;
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!bridge.isOpen) restoreImmersive();
  });
}
