# Filters over a Claude Code session transcript (JSON Lines). The format is
# internal to Claude Code and can change between versions.
# Use: jq -L <this directory> 'include "transcript"; <filter>' <transcript>

def _text: if type == "string" then . elif type == "array" then (map(select(.type == "text") | .text) | join("\n")) else "" end;

# A message the user typed while the agent was working: recorded as an attachment, not a user entry.
def _human_queued: .type == "attachment" and .attachment.type == "queued_command" and ((.attachment.origin | tostring) | test("\"kind\":\"human\""));

# System-injected text starts with "<"; slash commands keep their <command-...> wrapper here.
def _own: length > 0 and ((startswith("<") | not) or startswith("<command-"));

def _render: if startswith("<command-") then ([(capture("<command-name>(?<n>[^<]*)</command-name>").n), (capture("<command-args>(?<a>[^<]*)</command-args>").a)] | map(select(. != null and . != "")) | join(" ")) else . end;

def _flat: gsub("\\s*\n\\s*"; " ⏎ ");

# One object per user message, slash command or answer to a choice question, in order.
def user_messages:
  input_line_number as $l
  | if _human_queued then {line: $l, ts: .timestamp, kind: "message", text: (.attachment.prompt | _text)}
    elif .type == "user" and (.isCompactSummary | not) and (.isMeta | not) then
      {line: $l, ts: .timestamp}
      + (if (.toolUseResult | type) == "object" and (.toolUseResult.answers | type) == "object"
         then {kind: "choice", text: (.toolUseResult.answers | to_entries | map("Q: \(.key[0:80]) A: \(.value)") | join("\n"))}
         else {kind: "message", text: (.message.content | _text)} end)
    else empty end
  | select(.text | _own)
  | .text |= _render;

# Cut a user_messages object to 2,000 characters and mark the cut.
def cut_text: if (.text | length) > 2000 then .text = .text[0:2000] + " [truncated: transcript line \(.line)]" else . end;

# Run with -n. The agent's latest replies before the user's latest message: the text after
# the last earlier user message that got a reply (normally the previous one), so two user
# messages in a row still yield the replies before them. Prints the last reply's timestamp
# and line, then the text joined, keeping the last 2,000 characters.
def last_replies:
  reduce (inputs | input_line_number as $l
          | select(.type == "assistant" or _human_queued
                   or (.type == "user" and (.isMeta | not) and (.isCompactSummary | not) and (.message.content | _text | _own)))
          | {e: ., l: $l}) as $x
    ({cur: [], last: []};
     if $x.e.type == "assistant" then .cur += [$x.e.message.content[]? | select(.type == "text") | {ts: $x.e.timestamp, line: $x.l, text: .text}]
     elif (.cur | length) > 0 then .last = .cur | .cur = []
     else . end)
  | .last
  | if length == 0 then empty
    else (map(.text) | join("\n")) as $r
    | .[-1].ts + " (transcript line \(.[-1].line))\n"
      + (if ($r | length) > 2000 then "[truncated: transcript line \(.[0].line)] " + $r[-2000:] else $r end)
    end;

# One line per entry before transcript line $before: user (U), agent text (A) and
# messages from other sessions (P); tool calls and tool output are left out.
def view($before):
  input_line_number as $l
  | select($l < $before)
  | .timestamp as $ts
  | if .type == "assistant" then (.message.content[]? | select(.type == "text") | "[\($l) \($ts) A] \(.text | _flat)")
    elif .type == "user" or .type == "attachment" then
      ([user_messages] | first) as $u
      | if $u then "[\($l) \($ts) U] \($u.text | _flat)"
        else ((.message.content // .attachment.prompt // "") | _text) as $t
        | select($t | test("<cross-session-message"))
        | "[\($l) \($ts) P] \($t | _flat)"
        end
    else empty end;
