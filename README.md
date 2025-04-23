<br/>
<div align="center">
<a href="https://github.com/alvinunreal/tmuxai">
<img src="https://tmuxai.dev/gh.svg" alt="TmuxAI Logo" width="100%" style="border-radius: 10px">
</a>
<br/>
<br/>
<a href="https://tmuxai.dev/getting-started"><strong>Getting Started »</strong></a>
<br/>
<br/>
<a href="https://tmuxai.dev/screenshots">Screenshots |</a>
<a href="https://github.com/alvinunreal/tmuxai/issues/new?labels=bug&template=bug_report.md">Report Bug |</a>
<a href="https://github.com/alvinunreal/tmuxai/issues/new?labels=enhancement&template=feature_request.md">Request Feature</a>
</p>
</div>

## About The Project

![Product Screenshot](https://tmuxai.dev/shots/vim-docker-compose.png)
_use vim, create docker compose file for nginx and mysql and start both_

TmuxAI is an intelligent terminal assistant that lives inside your tmux sessions. Unlike other CLI AI tools, TmuxAI observes and understands the content of your tmux panes, providing assistance without requiring you to change your workflow or interrupt your terminal sessions.

Think of TmuxAI as a _pair programmer_ that sits beside you, watching your terminal environment exactly as you see it. It can understand what you're working on across multiple panes, help solve problems and execute commands on your behalf in a dedicated execution pane.

### Human-Inspired Interface

TmuxAI's design philosophy mirrors the way humans collaborate at the terminal. Just as a colleague sitting next to you would observe your screen, understand context from what's visible, and help accordingly, TmuxAI:

1. **Observes**: Reads the visible content in all your panes
2. **Communicates**: Uses a dedicated chat pane for interaction
3. **Acts**: Can execute commands in a separate execution pane (with your permission)

This approach provides powerful AI assistance while respecting your existing workflow and maintaining the familiar terminal environment you're already comfortable with.

## Installation

TmuxAI requires only tmux to be installed on your system. It's designed to work on Unix-based operating systems including Linux and macOS.

### Quick Install

The fastest way to install TmuxAI is using the installation script:

```bash
curl -fsSL https://get.tmuxai.dev | bash
```

This installs TmuxAI to `/usr/local/bin/tmuxai` by default. If you need to install to a different location or want to see what the script does before running it, you can view the source at [get.tmuxai.dev](https://get.tmuxai.dev).

### Homebrew

If you use Homebrew, you can install TmuxAI with:

```bash
brew tap alvinunreal/tmuxai
brew install tmuxai
```

### Manual Download

You can also download pre-built binaries from the [GitHub releases page](https://github.com/alvinunreal/tmuxai/releases).

After downloading, make the binary executable and move it to a directory in your PATH:

```bash
chmod +x ./tmuxai
sudo mv ./tmuxai /usr/local/bin/
```

## Post-Installation Setup

After installing TmuxAI, you need to configure your API key to start using it:

1. **Set the API Key**  
   TmuxAI uses the OpenRouter endpoint by default. Set your API key by adding the following to your shell configuration (e.g., `~/.bashrc`, `~/.zshrc`):

   ```bash
   export TMUXAI_OPENROUTER_API_KEY="your-api-key-here"
   ```

2. **Start TmuxAI**

   ```bash
   tmuxai
   ```

## TmuxAI Layout

TmuxAI is designed to operate within a single tmux window, with one instance of
TmuxAI running per window and organizes your workspace using the following pane structure:

1. **Chat Pane**: This is where you interact with the AI. It features a REPL-like interface with syntax highlighting, auto-completion, and readline shortcuts.

2. **Exec Pane**: TmuxAI selects (or creates) a pane where commands can be executed.

3. **Read-Only Panes**: All other panes in the current window serve as additional context. TmuxAI can read their content but does not interact with them.

## Observe Mode

TmuxAI operates by default in what's called "observe mode". Here's how the interaction flow works:

1. **User types a message** in the Chat Pane.

2. **TmuxAI captures context** from all visible panes in your current tmux window (excluding the Chat Pane itself). This includes:

   - Current command with arguments
   - Detected shell type
   - User's operating system
   - Current content of each pane

3. **TmuxAI processes your request** by sending user's message, the current pane context, and chat history to the AI.

4. **The AI responds** with information, which may include a suggested command to run.

5. **If a command is suggested**, TmuxAI will:

   - Check if the command matches whitelist or blacklist patterns
   - Ask for your confirmation (unless the command is whitelisted)
   - Execute the command in the designated Exec Pane if approved
   - Wait for the `wait_interval` (default: 5 seconds)
   - Capture the new output from all panes
   - Send the updated context back to the AI to continue helping you

6. **The conversation continues** until your task is complete.

## Prepare Mode

Prepare mode improves TmuxAI's ability to work with your terminal by customizing
your shell prompt and tracking command execution with better precision. This
enhancement eliminates the need for arbitrary wait intervals and provides the AI
with more detailed information about your commands and their results.

When you enable Prepare Mode, TmuxAI will:

1. **Detects your current shell** in the execution pane (supports bash, zsh, and fish)
2. **Customizes your shell prompt** to include special markers that TmuxAI can recognize
3. **Will track command execution history** including exit codes, and per-command outputs
4. **Will detect command completion** instead of using fixed wait time intervals

To activate Prepare Mode, simply use:

```
TmuxAI » /prepare
```

**Prepared Fish Example:**

```shell
$ function fish_prompt; set -l s $status; printf '%s@%s:%s[%s][%d]» ' $USER (hostname -s) (prompt_pwd) (date +"%H:%M") $s; end
username@hostname:~/r/tmuxai[21:05][0]»
```

## Watch Mode

Watch Mode transforms TmuxAI into a proactive assistant that continuously
monitors your terminal activity and provides suggestions based on what you're
doing.

### Activating Watch Mode

To enable Watch Mode, use the `/watch` command followed by a description of what you want TmuxAI to look for:

```
TmuxAI » /watch spot and suggest more efficient alternatives to my shell commands
```

When activated, TmuxAI will:

1. Start capturing the content of all panes in your current tmux window at regular intervals (`wait_interval` configuration)
2. Analyze content based on your specified watch goal and provide suggestions when appropriate

### Example Use Cases

Watch Mode is could be valuable for scenarios such as:

- **Learning shell efficiency**: Get suggestions for more concise commands as you work

  ```
  TmuxAI » /watch suggest more efficient alternatives to my shell commands
  ```

- **Detecting common errors**: Receive warnings about potential issues or mistakes

  ```
  TmuxAI » /watch flag commands that could expose sensitive data or weaken system security
  ```

- **Log Monitoring and Error Detection**: Have TmuxAI monitor log files or terminal output for errors

  ```
  TmuxAI » /watch monitor log output for errors, warnings, or critical issues and suggest fixes
  ```

## Squashing

As you work with TmuxAI, your conversation history grows, adding to the context
provided to the AI model with each interaction. Different AI models have
different context size limits and pricing structures based on token usage. To
manage this, TmuxAI implements a simple context management feature called
"squashing."

### What is Squashing?

Squashing is TmuxAI's built-in mechanism for summarizing chat history to manage
token usage.

In simple terms, when your context grows too large, TmuxAI condenses previous
messages into a more compact summary.

You can check your current context utilization at any time using the `/info` command:

```bash
TmuxAI » /info

Context
────────

Messages            15
Context Size~       16500 tokens
                    ████████░░ 82.5%
Max Size            20000 tokens
```

This example shows that the context is at 82.5% capacity (16,500 tokens out of 20,000). When the context size reaches 80% of the configured maximum (`max_context_size` in your config), TmuxAI automatically triggers squashing.

### Manual Squashing

If you'd like to manage your context before reaching the automatic threshold, you can trigger squashing manually with the `/squash` command:

```bash
TmuxAI » /squash
```

## Core Commands

| Command                     | Description                                                      |
| --------------------------- | ---------------------------------------------------------------- |
| `/info`                     | Display system information, pane details, and context statistics |
| `/clear`                    | Clear chat history.                                              |
| `/reset`                    | Clear chat history and reset all panes.                          |
| `/config`                   | View current configuration settings                              |
| `/config set <key> <value>` | Override configuration for current session                       |
| `/squash`                   | Manually trigger context summarization                           |
| `/prepare`                  | Initialize Prepared Mode for the Exec Pane                       |
| `/watch <description>`      | Enable Watch Mode with specified goal                            |
| `/exit`                     | Exit TmuxAI                                                      |

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

## License

Distributed under the Apache License. See [Apache License](https://github.com/alvinunreal/tmuxai/blob/main/LICENSE) for more information.
