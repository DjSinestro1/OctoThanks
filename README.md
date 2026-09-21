# OctoThanks

OctoThanks automatically whispers a thank-you to a player who gives you a buff
lasting longer than two minutes. Short buffs and healing-over-time effects such
as Renew are ignored.

By default, it rotates through eight friendly thank-you messages and avoids
repeating the same line twice in a row. Use `/ot message default` to restore the
rotation, or `/ot message <text>` to use one fixed custom message.

It listens for the Vanilla 1.12 friendly-player spell event and, when Nampower
is available, also uses `AURA_CAST_ON_SELF` for caster-aware detection.

Commands:

- `/ot on` or `/ot off`
- `/ot message Thanks for the buff!`
- `/ot message Thanks for %s!` (the `%s` becomes the spell name)
- `/ot cooldown 60`
- `/ot delay 1`
- `/ot group on` or `/ot group off`

The default cooldown is 60 seconds per player and the default delay is 1 second.
When Nampower is available, duration-aware aura events are used so only buffs
strictly longer than 120 seconds can trigger a thank-you.
