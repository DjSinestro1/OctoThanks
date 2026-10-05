# 1.6.0

- Adds an in-game options window opened with `/ot gui` or the minimap button.
- Adds saved controls for enable/disable, whisper/say/emote mode, five-second reply delay, cooldown, group handling, and custom messages.
- Adds optional suppression of whispers to party/raid buff casters.
- Adds random positive emotes: Salute, Bow, Wave, Cheer, and Applaud.
- Adds an ignored-buff list that accepts spell names or spell IDs.
- Migrates the old implicit one-second delay to the new five-second default.
- Keeps slash commands available as a troubleshooting and accessibility fallback.

# 1.5.0

- Changes the default mode from SAY to WHISPER.
- Preserves an explicitly selected SAY, WHISPER, or EMOTE mode across reloads and logouts.
- Repairs installations whose saved mode was missing: they now initialize to WHISPER instead of SAY.
- Adds relog/default-mode regression coverage.

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
