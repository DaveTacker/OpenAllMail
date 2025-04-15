# Open All Mail for WoW Classic (Turtle WoW)

A lightweight World of Warcraft Classic addon designed to quickly open all mail, retrieve items, and collect gold from your mailbox. Tailored for WoW Classic version 1.12, specifically compatible with the Turtle WoW private server.

## Features

- Adds an "Open All" button to the Mail Frame UI.
- Automatically iterates through your inbox, opening each mail one by one.
- Takes all attached items from opened mail.
- Collects any gold attached to opened mail.
- Provides feedback in the chat window about the process.

## Usage

1. Open your mailbox in-game.
2. Click the "Open All" button located near the bottom of the mail frame.
3. The addon will process each mail sequentially.

## Compatibility

- **World of Warcraft Version:** 1.12.x (Classic)
- **Server:** Optimized for Turtle WoW, but should work on other Classic 1.12 servers.

## Installation

1. Download the latest release of `OpenAllMail` and unzip it.
2. Exit World of Warcraft completely.
3. Navigate to your World of Warcraft installation directory.
4. Go into the `Interface\AddOns\` folder. If the `AddOns` folder doesn't exist, create it.
5. Place the `OpenAllMail` folder inside the `AddOns` directory.
6. Launch World of Warcraft.
7. At the character selection screen, make sure "OpenAllMail" is enabled in the AddOns list.

## Development Notes

- This addon attempts to follow best practices for WoW Classic addon development.
- It avoids global namespace pollution and uses a local table `OpenAllMail` for its functions and variables.
- The button is created dynamically when the mail frame is shown. 
