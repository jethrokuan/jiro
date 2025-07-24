# CLAUDE.md

## Project Overview

This is `jiro`, an Emacs Lisp package. The repository contains a single Emacs Lisp file (`jiro.el`) that provides the main package functionality.

## Development

### Package Structure
- `jiro.el` - Main package file containing the core functionality
- Package requires Emacs 24.3 or later
- Uses lexical binding

### Testing and Development Commands
Since this is an Emacs package, development typically involves:
- Loading the package in Emacs: `M-x load-file RET jiro.el RET`
- Testing functionality interactively within Emacs
- Package installation via `M-x package-install-file RET jiro.el RET`
