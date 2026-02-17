
## kterm (formerly xterm.dart)

<p>
    <a href="https://github.com/lbp0200/kterm.dart/actions/workflows/ci.yml">
      <img alt="Actions" src="https://github.com/lbp0200/kterm.dart/actions/workflows/ci.yml/badge.svg">
    </a>
    <a href="https://pub.dev/packages/kterm">
      <img alt="Package version" src="https://img.shields.io/pub/v/kterm?color=blue&include_prereleases">
    </a>
    <img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/lbp0200/kterm.dart">
    <img alt="GitHub issues" src="https://img.shields.io/github/issues-raw/lbp0200/kterm.dart">
    <img alt="GitHub pull requests" src="https://img.shields.io/github/issues-pr/lbp0200/kterm.dart">
</p>


**kterm** is a fast and fully-featured terminal emulator for Flutter applications, with support for mobile and desktop platforms. It is a fork of xterm.dart with enhanced modern terminal features.

> This package requires Flutter version >=3.0.0

## Screenshots

<table>
  <tr>
    <td>
		<img width="200px" src="https://raw.githubusercontent.com/TerminalStudio/xterm.dart/master/media/demo-shell.png">
    </td>
    <td>
       <img width="200px" src="https://raw.githubusercontent.com/TerminalStudio/xterm.dart/master/media/demo-vim.png">
    </td>
  <tr>
  </tr>
    <td>
       <img width="200px" src="https://raw.githubusercontent.com/TerminalStudio/xterm.dart/master/media/demo-htop.png">
    </td>
    <td>
       <img width="200px" src="https://raw.githubusercontent.com/TerminalStudio/xterm.dart/master/media/demo-dialog.png">
    </td>
  </tr>
</table>

## Features

- 📦 **Works out of the box** No special configuration required.
- 🚀 **Fast** Renders at 60fps.
- 😀 **Wide character support** Supports CJK and emojis.
- ✂️ **Customizable** 
- ✔ **Frontend independent**: The terminal core can work without flutter frontend.

## kterm vs xterm.dart

kterm includes all xterm.dart features plus modern terminal enhancements:

- 🖥️ **Modern Key Support**: Full Kitty Keyboard Protocol implementation.
- 📚 **Progressive Enhancement**: Supports CSI > n u stack (push/pop) for nested terminal modes.
- 🔍 **Zero Ambiguity**: No more Tab vs Ctrl+I confusion in Neovim/Helix — modifier keys are always distinguishable.

**What's new in 3.0.0:**

- 📱 Enhanced support for **mobile** platforms.
- ⌨️ Integrates with Flutter's **shortcut** system.
- 🎨 Allows changing **theme** at runtime.
- 💪 Better **performance**. No tree rebuilds anymore.
- 🈂️ Works with **IMEs**.

## Getting Started

**1.** Add this to your package's pubspec.yaml file:

```yml
dependencies:
  ...
  kterm: ^3.2.6
```

**2.** Create the terminal:

```dart
import 'package:kterm/xterm.dart';
...
terminal = Terminal();
```

Listen to user interaction with the terminal by simply adding a `onOutput` callback:

```dart
terminal = Terminal();

terminal.onOutput = (output) {
  print('output: $output');
}
```

**3.** Create the view, attach the terminal to the view:

```dart
import 'package:kterm/flutter.dart';
...
child: TerminalView(terminal),
```

**4.** Write something to the terminal:

```dart
terminal.write('Hello, world!');
```

**Done!**

## More examples

- Write a simple terminal in ~100 lines of code:
  https://github.com/lbp0200/kterm.dart/blob/master/example/lib/main.dart

- Write a SSH client in ~100 lines of code with [dartssh2]:
  https://github.com/lbp0200/kterm.dart/blob/master/example/lib/ssh.dart

  <img width="400px" src="https://raw.githubusercontent.com/lbp0200/kterm.dart/master/media/example-ssh.png">

For a complete project built with kterm, check out [TerminalStudio].

## Features and bugs

Please file feature requests and bugs at the [issue tracker](https://github.com/lbp0200/kterm.dart/issues).

Contributions are always welcome!

## License

This project is licensed under an MIT license.

[dartssh2]: https://pub.dev/packages/dartssh2
[TerminalStudio]: https://github.com/TerminalStudio/studio