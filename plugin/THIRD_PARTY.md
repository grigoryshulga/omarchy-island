# Third-party code

`Security.js`, `Markup.js`, `Store.js` and the basis of `Detect.js` are copied from the installed Omarchy notification service, descended from Omapager. `Detect.js` is adapted to recognize bare six-digit codes, Russian keywords and hyphenated alphanumeric codes.

`IslandSlider.qml` is adapted from Omarchy `Ui/PanelSlider.qml`, preserving its interactions and applying the system corner policy.

`ClockModel.js` is copied from Omarchy’s clock panel to preserve its format ring, alternative formats and ISO week formatting.

`KeyboardLayoutModel.js` is adapted from Omarchy’s keyboard-layout widget: keyboard filtering and initial device selection follow its conventions, while Island shows full language names transiently.

`PowerModel.js` is copied from Omarchy’s power panel. Battery state follows UPower; profile selection uses the native Omarchy commands and their AC/battery persistence.

`WeatherModel.js` follows the location and unit conventions of Omarchy’s weather model. The weather backend uses the same native location file and Open-Meteo/Omarchy providers; the procedural braille scenes are original code. Weather data is provided by https://open-meteo.com/ and is attributed in the README.

`osd-bridge/Panel.qml` and `osd-bridge/OsdModel.js` are adapted from Omarchy’s OSD. Native progress and status messages are forwarded to Island, including close requests; the original interface is retained as a fallback when Island is unavailable.

`controls/lib/adapter.py`, `controls/IslandHost.qml`, `controls/IslandHiddenBarButton.qml` and `controls/IslandDisabledIpc.qml` are adapted from gshulga.dashboard's automatic panel embedding mechanism (MIT, copyright 2026 gshulga; license in `controls/ADAPTER-LICENSE`). Island generates disposable, fingerprinted adaptations of the installed Omarchy panels at runtime; no panel/model/service snapshots are bundled. Installed sources remain untouched. The adapter replaces window hosting and process-global hooks, preserves the original lifecycle, and applies Island's compact switches and natural sizing for optional Text labels to avoid Qt height binding loops. `controls/ControlKeyCatcher.qml` adapts Omarchy’s `PanelKeyCatcher` for equivalent H/J/K/L positions on a Russian keyboard layout; `controls/ControlSwitch.qml` adds Island styling to the native switch.


Sources: https://github.com/omacom/omarchy and https://github.com/omacom/omapager

Copyright (c) David Heinemeier Hansson
Copyright (c) 2026 Neil Jagdish Patel

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
