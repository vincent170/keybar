# KeyBar - User Guide
KeyBar is a macOS tool that lives in your toolbar that tracks your typing stats (including WPM, accuracy, consistency and more) in real time, without tracking what you type.

## 1. What does KeyBar do?
KeyBar watches your keyboard activity across your entire system and turns it into:
- A live WPM counter, displayed on the top toolbar
- Session stats (toggle time)
- Daily trends
- Accuracy and consistency
KeyBar does **not** log, store or transmit any of the characters you type. It **only records when a key was pressed and wheter it was backspace**, not what the key actually was. There is **no network activity** and all user data lives locally in `UserDefaults`.

## 2. Installation
Installation is pretty straightforward. However, since I did not pay Apple's $99/month subscription Apple Developer certification, this tool will trigger a Gatekeeper warning.
1. Click on the releases section on the right bar
2. Download the latest version of the app
3. Move the app from the Downloads folder of your Mac to the Applications folder
4. Open the app
5. It will trigger a Gatekeeper warning as mentioned before so go to System Settings > Privacy & Security > Allow KeyBar to open (at the bottom)
6. Enable the permissions by pressing following the setup (press '+' in the settings and click on KeyBar) -> there's two and the second one will appear when you click on the icon in the menu bar
7. Boom, that's it. KeyBar has been officially installed on your Mac!

## 3. Using KeyBar
Click on the WPM counter on your tool bar (at the top). This will open a UI. Here are all of the stats and you can scroll through it. There is also Settings, which allows you to change what is displayed on the toolbar, sensitivity and also you can pause the program without quitting it.

## 4. Settings
Open Settings via the gear icon on the top right.
 
**Menu Bar Display Elements**
- Show Keyboard Icon
- Show Live WPM
- Show Accuracy % (not working yet)
- Show Trend Emoji
 
**Live WPM Sensitivity**
A slider from *Smooth* to *Responsive*.
- **Smooth (left):** the live WPM number changes gradually, less jumpy per keystroke, but takes a moment to reflect a real change in pace.
- **Responsive (right):** reacts almost instantly to a change in typing speed, at the cost of being visibly jumpier from keystroke to keystroke.
Default is around 60% but it's really up to you how you like it.
 
**Data Management**
- **Clear All Saved History** permanently deletes all daily records, chart data, and resets all counters. This cannot be undone.

## 5. Metrics
| Metric | How it's calculated |
|---|---|
| **Live WPM** | Based on the interval between your two most recent keystrokes and lightly smoothed |
| **Session WPM** | Characters typed in the selected timeframe ÷ 5 ÷ active typing minutes, excluding idle gaps |
| **Accuracy** | Non backspace keystrokes ÷ total keystrokes, within the timeframe |
| **Consistency** | Based on how much your speed varies across 5 second buckets within the timeframe. Steadier pace scores higher |
| **CPM** | Characters per minute — always WPM × 5 |

A 'word' is defined as 5 characters, the conventional definition used by every typing tool (typing.com, WPM tests etc). This does not count dictionary words however I may add that functionality soon.

## 6. Privacy

Privacy is one of the top priorities. To ensure that your personal data is not misused, KeyBar:
- Runs locally with zero network requests
- Only stores counts, timestamps and backspaces
- Saves data to `UserDefaults`, which can be found in `/Library/Preferences/` on your Mac and **only on your Mac**
- Data can be fully wiped via *Clear All Saved History* in the top bar or by deleting the app

I have also posted the code publicly on GitHub so you can verify this yourself. See `KeystrokeMonitor.swift` for more information.

## 7. Common errors

**'Input Monitoring Required' screen won't go away**
Quit and relaunch KeyBar after granting Accessibility permission. Some permission changes don't propagate to a currently running process.
 
**macOS says KeyBar 'cannot be opened because it is from an unidentified developer'**
This is expected. Go to Privacy and Security in Settings and enable the app.
 
**Stats seem stuck at 0**
Check you haven't hit Pause. Check Accessibility permission is actually still enabled (macOS occasionally revokes it after an OS update).
 
**Long Distance / Compare tabs are empty**
They need at least one full day of typing activity logged before they show anything.
 
**Live WPM feels too jumpy or too laggy**
Adjust the sensitivity slider in Settings (explained before)

## 8. Uninstalling

We're sad to see you go! If you have any advice or inquiries, I would love to take your opinion. Feel free to email me at VincentHao100@hotmail.com. However if you must uninstall the program:
1. Quit KeyBar (You can do this via the App in Toolbar)
2. Delete KeyBar.app from the Applications folder
3. Remove saved data: `defaults delete com.yourbundleid.KeyBar`
4. Remove Accessibility permissions granted to KeyBar in System Settings



