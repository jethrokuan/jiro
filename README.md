# jiro

`jiro` provides a read-only view using magit-section for jujutsu projects. It is a very unambitious project, providing a nicer view for `jj diff` and `jj status`.

## Features

- **Project-specific buffers**: Each jujutsu project gets its own buffer named after the project folder
- **Collapsible file diffs**: File sections start collapsed and can be expanded with TAB
- **Navigate to source**: Press RET on diff lines to jump to the corresponding file and line
- **Refresh support**: Press `g` to refresh the current project's status
- **Difftastic integration**: Uses difftastic for enhanced diff rendering

## Main commands

- `jiro-status`: Pop up a read-only buffer showing jj status and diff with magit-section formatting

The buffer displays:
1. Current jujutsu status information
2. Collapsible magit-sections for each file diff
3. Syntax-highlighted diffs using difftastic

## Key bindings

In jiro buffers:
- `g`: Refresh the current project's status
- `RET`: Navigate to the file and line under cursor
- `TAB`: Toggle section visibility

## Configuration

- `jiro-jj-executable`: Path to the jj executable (default: "jj")
- `jiro-diff-tool`: Diff tool for jj diff --tool option (default: "difft" for difftastic)
