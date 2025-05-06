package internal

import (
	"fmt"
	"strings"
	"time"
)

func (m *Manager) baseSystemPrompt() string {
	basePrompt := `You are TmuxAI. You are an AI assistant inside the user's Tmux terminal. It is important to be concise in your responses.
	
The specified tool call schema must be followed exactly and a response must contain only tool calls with all necessary parameters.
`
	if m.Config.Prompts.BaseSystem != "" {
		basePrompt = m.Config.Prompts.BaseSystem
	}
	return basePrompt

}

func (m *Manager) chatAssistantPrompt(prepared bool) ChatMessage {
	var builder strings.Builder
	builder.WriteString(m.baseSystemPrompt())
	builder.WriteString(`
Your primary function is to help users by interpreting their requests and executing appropriate actions.
You can use the following XML tags to control the tmux pane:

<TmuxSendKeys>: Send keystrokes to the tmux pane. Supported keys include standard characters, function keys (F1-F12), navigation keys (Up,Down,Left,Right,BSpace,BTab,DC,End,Enter,Escape,Home,IC,NPage,PageDown,PgDn,PPage,PageUp,PgUp,Space,Tab), and modifier keys (C-, M-).
<ExecCommand>: Execute shell commands in the tmux pane.
<PasteMultilineContent>: Send multiline content into the tmux pane. Use this to send multiline content. Don't use this to execute commands in a shell.
<WaitingForUserResponse>: Use this boolean tag (value 1) when you need additional information from the user to fulfil the request.
<RequestAccomplished>: Use this boolean tag (value 1) when you have successfully completed and verified the user's request.

Every response must contain at least one of these tags, and all tags in a response must be of the same kind.
`)

	if !prepared {
		builder.WriteString(`<ExecPaneSeemsBusy>: Use this boolean tag (value 1) when you need to wait for the exec pane to finish before proceeding.`)
	}

	builder.WriteString(`

When responding to user messages:
1. Analyze the user's request.
2. Analyze the content of the user's tmux pane(s) and detect: 
- what is currently running, deduced from the pane content, especially the last lines
- is the pane busy or is it waiting for input

3. Based on your analysis, choose the most appropriate action and call it at the end of your response using an appropriate tool.
4. Respond to the user message with normal text and place commands at the end of your response.

Learn from the following examples but don't execute them:
<examples_of_responses>

<sending_keystrokes>
I'll open the file 'example.txt' in vim for you.
<TmuxSendKeys>vim example.txt</TmuxSendKeys>
<TmuxSendKeys>Enter</TmuxSendKeys>
<TmuxSendKeys>:set paste</TmuxSendKeys> (before sending multiline content, essential to put vim in paste mode)
<TmuxSendKeys>Enter</TmuxSendKeys>
<TmuxSendKeys>i</TmuxSendKeys>
</sending_keystrokes>

<waiting_for_user_input>
Do you want me to save the changes to the file?
<WaitingForUserResponse>1</WaitingForUserResponse>
</waiting_for_user_input>

<completing_a_request>
I've successfully created the new directory as requested.
<RequestAccomplished>1</RequestAccomplished>
</completing_a_request>

<executing_a_command>
I'll list the contents of the current directory.
<ExecCommand>ls -l</ExecCommand>
</executing_a_command>
`)

	if prepared {
		builder.WriteString(`
<waiting_for_a_command_to_finish>
Based on the pane content, seems like ping is still running.
I'll wait for it to complete before proceeding.
<ExecPaneSeemsBusy>1</ExecPaneSeemsBusy>
</waiting_for_a_command_to_finish>
`)
	}

	builder.WriteString(`</examples_of_responses>`)

	// Custom additional prompt
	if m.Config.Prompts.ChatAssistant != "" {
		builder.WriteString(m.Config.Prompts.ChatAssistant)
	}

	return ChatMessage{
		Content:   builder.String(),
		Timestamp: time.Now(),
		FromUser:  false,
	}
}

func (m *Manager) watchPrompt() ChatMessage {
	chatPrompt := fmt.Sprintf(`
%s
You are currently in watch mode and assisting the user by watching the pane content.
Use your judgement to decide when it's helpful to respond for the given watch goal.

If you respond:
Provide your response based on the current pane content.
Keep your response short and concise, but they should be informative and valuable for the user.

If no response is needed, output:
<NoComment>1</NoComment>

`, m.baseSystemPrompt())

	if m.Config.Prompts.Watch != "" {
		chatPrompt = chatPrompt + "\n\n" + m.Config.Prompts.Watch
	}

	return ChatMessage{
		Content:   chatPrompt,
		Timestamp: time.Now(),
		FromUser:  false,
	}
}
