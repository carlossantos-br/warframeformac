<p align="center"><img src="assets/icon.png" width="160" alt="Warframe for Mac"></p>

<h1 align="center">Warframe for Mac</h1>

<p align="center">Play Warframe on Apple Silicon Macs. One command and you're in.</p>

---

## Install

You need an **Apple Silicon** Mac (M1 or newer), **macOS 14** or newer and about **60 GB free**.

Open **Terminal** and paste:

```bash
git clone https://github.com/carlossantos-br/warframeformac.git
cd warframeformac
./install.sh
```

When it finishes, **Warframe for Mac** opens by itself (it is also in Launchpad, Spotlight and `~/Applications`).
The first time: accept the Warframe EULA, let the launcher download the game (~50 GB) and click **Play**. After that, just open the app and play.

> No `git`? macOS offers to install the developer tools the first time you use it. Or download the ZIP (green **Code → Download ZIP** button), unzip it and run `bash install.sh` inside the folder.

## What the installer does

- Downloads **Wine** built for the Mac ([Sikarugir](https://github.com/Sikarugir-App), with Apple's **D3DMetal**) from its official releases and verifies the checksums.
- Downloads the **official Warframe installer** (`content.warframe.com`) and installs the launcher.
- Applies settings that work: borderless full screen (switch away and back with Mission Control/F3), launcher rendering flags (no black window), Wine logging off.
- Creates the **Warframe for Mac** app. If Warframe is already open, it asks before restarting it; otherwise it clears any Wine process left stuck by a previous session before starting.

Nothing in the game is modified: it is the official Warframe client running in Wine, exactly like on Windows, with your normal account.

## Wired Xbox One controller

macOS does not recognize the original wired Xbox One controller in Wine games. That is what **[xboxoneformac](https://github.com/carlossantos-br/xboxoneformac)** is for, and it is made to work together with this project:

```bash
git clone https://github.com/carlossantos-br/xboxoneformac.git
cd xboxoneformac
./install.sh
```

It also keeps the Mac from turning off the display while you play with just the controller. (Bluetooth controllers already work without any of this.)

## Tips

- **Performance:** on 8 GB Macs, use low graphics and a lower resolution in the game, and quit Chrome while playing.
- **Stuck?** Open the app again and choose **Restart**: it closes the game and anything left over from Wine and starts clean.
- **Something broke?** Run `./install.sh` again. It rebuilds Wine and does **not** download the game again; your game settings are kept.
- The macOS warning about "apps for Intel" is expected: Wine runs through Rosetta 2.
- Where everything lives: `~/Library/Application Support/WarframeForMac` (Wine in `Warframe.app`, game in `Game`).

## Uninstall

```bash
./uninstall.sh              # removes the app, Wine and the game
./uninstall.sh --keep-game  # removes the app and Wine, keeps the ~50 GB of game files
```

---

Not affiliated with or endorsed by Digital Extremes. Warframe is a trademark of Digital Extremes Ltd. This project only automates installing the official game client; it does not modify the game or touch your account. Wine wrapper by the [Sikarugir](https://github.com/Sikarugir-App) project. Licensed under the [MIT License](LICENSE).
