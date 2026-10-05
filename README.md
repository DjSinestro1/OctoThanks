# OctoThanks

OctoThanks automatically thanks a player who gives you a buff
lasting longer than two minutes. Short buffs and healing-over-time effects such
as Renew are ignored.

By default, it rotates through 28 friendly thank-you messages and avoids
repeating the same line twice in a row. Use `/ot message default` to restore the
rotation, or `/ot message <text>` to use one fixed custom message.

The extra replies use playful British/Cockney, modern US street, retro jive-style,
Australian, New Zealand, South African, Irish, and Canadian phrasing.

It listens for the Vanilla 1.12 friendly-player spell event and, when Nampower
is available, also uses `AURA_CAST_ON_SELF` for caster-aware detection.

The addon includes an in-game options window at `/ot gui` and a minimap button.
Settings are saved automatically. The default reply delay is five seconds.

Commands:

- `/ot on` or `/ot off`
- `/ot mode whisper` (default; private thanks to the buff caster)
- `/ot mode say` (nearby players can hear it)
- `/ot channel whisper` (private thanks to the buff caster)
- `/ot mode emote` (built-in THANK emote directed at the buff caster)
- `/ot gui` (open the options window; the minimap button does the same)
- `/ot message Thanks for the buff!`
- `/ot message Thanks for %s!` (the `%s` becomes the spell name)
- `/ot cooldown 60`
- `/ot delay 5`
- `/ot group on` or `/ot group off`
- `/ot groupwhisper on` or `/ot groupwhisper off`
- `/ot emotes thank` or `/ot emotes random`
- `/ot ignore add|remove|list|clear <spell name or spell ID>`

The default cooldown is 60 seconds per player and the default delay is 5 seconds.
The selected mode is saved across reloads and logouts. Existing installations
without a saved channel now default to whisper. An explicitly selected SAY,
WHISPER, or EMOTE setting is preserved; the addon never resets a valid choice.
Emote choices are also saved. `mode` and `channel` are interchangeable; use
`/ot mode say` or `/ot mode whisper` to return to text replies.
Emote mode uses the game's fixed thank-you or optional random positive emotes,
not the 28 phrases or custom text.
It passes the caster's name to DoEmote without changing your target. Targeted
delivery still needs in-game testing; range/client restrictions may prevent the
intended result. Failed requests do not trigger chat fallback or retries.
Changing mode cancels pending replies.
When Nampower is available, duration-aware aura events are used so only buffs
strictly longer than 120 seconds can trigger a thank-you.
