# Calendar libraries

These unmodified, pure-Python wheels contain the source code used by the isolated ICS helper. Python imports directly from the archives; no pip, virtual environment or runtime download is needed. Each wheel also carries its upstream metadata, source and license. Standalone license copies are in `licenses/`.

`lock.json` records the PyPI project, version, original download URL and SHA-256 for every artifact. Run `bin/vendor-calendars` from the repository root to verify them; `bin/vendor-calendars --restore` restores the exact locked files and license copies. Updating dependencies requires reviewing their dependency metadata, updating the lock and running the calendar tests. The current bundle supports Python 3.11 or later.

- **icalendar 7.3.0** — BSD-2-Clause; https://github.com/python-icalendar/icalendar
- **recurring-ical-events 3.8.2** — LGPL-3.0-or-later; https://github.com/niccokunzmann/python-recurring-ical-events
- **x-wr-timezone 2.0.1** — LGPL-3.0-or-later; https://github.com/niccokunzmann/x-wr-timezone
- **python-dateutil 2.9.0.post0** — Apache-2.0 / BSD-3-Clause; https://github.com/dateutil/dateutil
- **six 1.17.0** — MIT; https://github.com/benjaminp/six
- **tzdata 2026.6** — Apache-2.0, with IANA public-domain data; https://github.com/python/tzdata
- **click 8.3.0** — BSD-3-Clause; https://github.com/pallets/click
- **typing-extensions 4.15.0** — PSF-2.0; https://github.com/python/typing_extensions

The libraries are separate from Island's MIT-licensed code. To inspect or modify one, unpack its wheel with Python's `zipfile`, edit its Python source, and replace that wheel or point `load_libraries()` in `plugin/bin/calendar_ics.py` to the modified module directory. Island performs no runtime signature check that would prevent replacing a library. Keep upstream license notices when redistributing modifications.
