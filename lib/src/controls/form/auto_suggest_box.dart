import 'package:fluent_ui/fluent_ui.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum TextChangedReason {
  /// Whether the text in an [AutoSuggestBox] was changed by user input
  userInput,

  /// Whether the text in an [AutoSuggestBox] was changed because the user
  /// chose the suggestion
  suggestionChosen,
}

// TODO: Navigate through items using keyboard (https://github.com/bdlukaa/fluent_ui/issues/19)

/// An AutoSuggestBox provides a list of suggestions for a user to select
/// from as they type.
///
/// ![AutoSuggestBox Preview](https://docs.microsoft.com/en-us/windows/apps/design/controls/images/controls-autosuggest-expanded-01.png)
///
/// See also:
///
///   * <https://docs.microsoft.com/en-us/windows/apps/design/controls/auto-suggest-box>
///   * [TextBox], which is used by this widget to enter user text input
///   * [Overlay], which is used to show the popup
class AutoSuggestBox<T> extends StatefulWidget {
  /// Creates a fluent-styled auto suggest box.
  const AutoSuggestBox({
    Key? key,
    required this.items,
    this.controller,
    this.onChanged,
    this.onSelected,
    this.onAdd,
    this.trailingIcon,
    this.style,
    this.clearButtonEnabled = true,
    this.addButtonEnabled = true,
    this.placeholder,
  }) : super(key: key);

  final TextStyle? style;

  /// The list of items to display to the user to pick
  final List<T> items;

  /// The controller used to have control over what to show on
  /// the [TextBox].
  final TextEditingController? controller;

  /// Called when the text is updated
  final void Function(String text, TextChangedReason reason)? onChanged;

  /// Called when the user selected a value.
  final ValueChanged<T>? onSelected;

  /// Called when the user press add button.
  final Function(String)? onAdd;

  /// A widget displayed in the end of the [TextBox]
  ///
  /// Usually an [IconButton] or [Icon]
  final Widget? trailingIcon;

  /// Whether the close button is enabled
  ///
  /// Defauls to true
  final bool clearButtonEnabled;

  /// Whether the add button is enabled
  ///
  /// Defauls to true
  final bool addButtonEnabled;

  /// The placeholder
  final String? placeholder;

  @override
  _AutoSuggestBoxState<T> createState() => _AutoSuggestBoxState<T>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<T>('items', items));
    properties.add(ObjectFlagProperty<ValueChanged<T>?>(
      'onSelected',
      onSelected,
      ifNull: 'disabled',
    ));
  }

  static List defaultItemSorter<T>(String text, List items) {
    return items.where((element) {
      return element.toString().toLowerCase().contains(text.toLowerCase());
    }).toList();
  }
}

class _AutoSuggestBoxState<T> extends State<AutoSuggestBox<T>> {
  final FocusNode focusNode = FocusNode();
  OverlayEntry? _entry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _textBoxKey = GlobalKey();

  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? TextEditingController();
    controller.addListener(() {
      if (!mounted) return;
      if (controller.text.length < 2) setState(() {});
    });
    focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    focusNode.removeListener(_handleFocusChanged);
    if (widget.controller == null) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleFocusChanged() {
    final hasFocus = focusNode.hasFocus;
    if (!hasFocus) {
      _dismissOverlay();
    } else {
      if (_entry == null && !(_entry?.mounted ?? false)) {
        _insertOverlay();
      }
    }
    setState(() {});
  }

  void _insertOverlay() {
    _entry = OverlayEntry(builder: (context) {
      final context = _textBoxKey.currentContext;
      if (context == null) return const SizedBox.shrink();
      final box = _textBoxKey.currentContext!.findRenderObject() as RenderBox;
      final child = Positioned(
        width: box.size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, box.size.height + 0.8),
          child: SizedBox(
            width: box.size.width,
            child: _AutoSuggestBoxOverlay(
              controller: controller,
              items: widget.items,
              onSelected: (item) {
                widget.onSelected?.call(item);
                controller.text = item.toString();
                widget.onChanged?.call(item.toString(), TextChangedReason.userInput);
                _dismissOverlay();
              },
            ),
          ),
        ),
      );

      return child;
    });

    if (_textBoxKey.currentContext != null) {
      Overlay.of(context)?.insert(_entry!);
      if (mounted) setState(() {});
    }
  }

  void _dismissOverlay() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasFluentTheme(context));
    assert(debugCheckHasFluentLocalizations(context));

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextBox(
        key: _textBoxKey,
        controller: controller,
        focusNode: focusNode,
        // onFocusChange: (focused) {
        //   debugPrint('Focused!');
        // },
        placeholder: widget.placeholder,
        style: widget.style,
        headerStyle: widget.style,
        placeholderStyle: widget.style,
        clipBehavior: _entry != null ? Clip.none : Clip.antiAliasWithSaveLayer,
        suffix: Row(children: [
          if (widget.trailingIcon != null) widget.trailingIcon!,
          if (widget.addButtonEnabled && controller.text.isNotEmpty && (widget.onAdd != null))
            Padding(
              padding: const EdgeInsets.only(left: 2.0),
              child: IconButton(
                icon: const Icon(FluentIcons.add, color: Colors.grey,),
                onPressed: () {
                  if (widget.onAdd != null) {
                    widget.onAdd!(controller.text);
                  }
                },
              ),
            ),
          if (widget.clearButtonEnabled && controller.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2.0),
              child: IconButton(
                icon: const Icon(FluentIcons.clear, color: Colors.grey,),
                onPressed: () {
                  controller.clear();
                  focusNode.requestFocus();
                },
              ),
            ),
        ]),
        suffixMode: OverlayVisibilityMode.always,
        onChanged: (text) {
          widget.onChanged?.call(text, TextChangedReason.userInput);
          if (_entry == null && !(_entry?.mounted ?? false)) {
            _insertOverlay();
          }
        },
      ),
    );
  }
}

class _AutoSuggestBoxOverlay extends StatelessWidget {
  const _AutoSuggestBoxOverlay({
    Key? key,
    required this.items,
    required this.controller,
    required this.onSelected,
  }) : super(key: key);

  final List items;
  final TextEditingController controller;
  final ValueChanged onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final localizations = FluentLocalizations.of(context);
    return FocusScope(
      autofocus: true,
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 385,
        ),
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(4.0),
            ),
            side: BorderSide(
              color: theme.scaffoldBackgroundColor,
              width: 0.8,
            ),
          ),
          color: theme.micaBackgroundColor,
        ),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final items =
            AutoSuggestBox.defaultItemSorter(value.text, this.items);
            late Widget result;
            if (items.isEmpty) {
              result = Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: _AutoSuggestBoxOverlayTile(
                    text: localizations.noResultsFoundLabel),
              );
            } else {
              result = ListView(
                key: ValueKey<int>(items.length),
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 4.0),
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  return _AutoSuggestBoxOverlayTile(
                    text: '$item',
                    onSelected: () {
                      onSelected(item);
                    },
                  );
                }),
              );
            }
            return result;
          },
        ),
      ),
    );
  }
}

class _AutoSuggestBoxOverlayTile extends StatefulWidget {
  const _AutoSuggestBoxOverlayTile({
    Key? key,
    required this.text,
    this.onSelected,
  }) : super(key: key);

  final String text;
  final VoidCallback? onSelected;

  @override
  __AutoSuggestBoxOverlayTileState createState() =>
      __AutoSuggestBoxOverlayTileState();
}

class __AutoSuggestBoxOverlayTileState extends State<_AutoSuggestBoxOverlayTile>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 125),
    );
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return HoverButton(
      onPressed: widget.onSelected,
      margin: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
      builder: (context, states) => Stack(
        children: [
          Container(
            height: 40.0,
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6.0),
              color: ButtonThemeData.uncheckedInputColor(
                theme,
                states.isDisabled ? {ButtonStates.none} : states,
              ),
            ),
            alignment: Alignment.centerLeft,
            child: EntrancePageTransition(
              child: Text(
                widget.text,
                style: theme.typography.body,
              ),
              animation: Tween<double>(
                begin: 0.75,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: controller,
                curve: Curves.easeOut,
              )),
              vertical: true,
            ),
          ),
          if (states.isFocused)
            Positioned(
              top: 11.0,
              bottom: 11.0,
              left: 0.0,
              child: Container(
                width: 3.0,
                decoration: BoxDecoration(
                  color: theme.accentColor,
                  borderRadius: BorderRadius.circular(4.0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
