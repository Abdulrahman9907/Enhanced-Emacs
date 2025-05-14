# Enhanced Emacs

An Emacs configuration package that helps detect and fix Betty style violations in C code.

## Overview

This package provides real-time highlighting of Betty style violations, navigation between errors, and integration with the official Betty style checker. It's designed to help students and developers write Betty-compliant C code more efficiently.

## Features

- **Enhanced line numbering**: Display line numbers with customized styling and highlighting for the current line
- **Real-time violation highlighting**: Immediately see Betty style violations with red highlighting
- **Violation navigation**: Quickly jump between style errors in your code
- **Integration with Betty checker**: Run the official Betty program directly from Emacs
- **Interactive fixes**: Delete spaces/tabs violations with a single command
- **Customizable**: Enable/disable features as needed

## Installation

1. Copy the provided code into your Emacs configuration file (`~/.emacs`, `~/.emacs.d/init.el`, or similar)
2. Ensure the `betty` executable is in your PATH or set the correct path in the configuration:
   ```elisp
   (setq betty-program-path "/path/to/betty")
   ```
3. Restart Emacs or evaluate the configuration

### Keyboard Shortcuts

| Shortcut | Description |
|----------|-------------|
| `C-c n`  | Move to next style violation |
| `C-c p`  | Move to previous style violation |
| `C-c c`  | Count total violations in buffer |
| `C-c d`  | Delete spaces/tabs violations |
| `C-c u`  | Undo deletion of violations |
| `C-c x`  | Toggle violation highlighting |
| `C-c b`  | Run Betty checker (toggle panel) |
| `C-c l`  | Show shortcuts legend |

### Visual Indicators

- **Line numbering**: Customized line numbers with current line highlighting (gold on dark background)
- **Red highlighting**: Indicates a Betty style violation
- **integrated betty checker**: Click "Betty checker (C-c b)" in the mode line to run the Betty checker
- **Minibuffer hints**: Shows help text when cursor is over a violation

### Violation Types Detected

The configuration highlights common Betty style violations including:
- Leading and trailing whitespace
- Tab characters
- Missing spaces after commas
- `return(...)` usage (should be `return (...)`
- Incorrect semicolon spacing


## Notes

- This configuration uses Emacs' text property system for highlighting, making it efficient and responsive
- The integration with the official Betty checker provides the most accurate results
- Automatic cleanup tools should be used with caution; manual review is recommended

## Additional Tips

- Use `C-c l` to display the shortcuts legend when needed
- The Betty output panel shows clickable line references for easy navigation
- Violations can be Deleted manually or semi-automatically with `C-c d`

Enjoy writing Betty-compliant code with less effort!
