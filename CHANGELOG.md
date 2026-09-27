# 1.4.0

- Adds optional targeted THANK emotes via /ot mode emote (channel is an alias).
- Preserves automatic SAY as the default and existing saved SAY/WHISPER choices.
- Emote mode persists across reloads and uses the existing filters, delay, and cooldown.
- Changing mode cancels pending replies. Failed emotes do not trigger chat fallback or retries.
- Targeted emote delivery still needs in-game testing on OctoWoW/Turtle.

# 1.3.0

- Added /ot channel say|whisper; say is now the default for settings without a channel.
- Added 20 slang-inspired replies, for 28 total, with no consecutive random repeat.
- Preserved existing custom messages, buff detection, delay, and per-player cooldown.
- Added automated channel, filter, cooldown, saved-setting, and message-rotation tests.
- New say behavior still needs an in-game check on the legacy client.
