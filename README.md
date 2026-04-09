## 🎵 Flutter Music Player
A custom-built music player app developed in Flutter that allows users to search and stream audio from YouTube.

### 🚀 Features
- 🔍 Search songs dynamically
- ▶️ Stream audio using just\_audio
- 📃 Queue system (add/remove songs)
- ⏯ Play / Pause / Stop controls
- ⏭ Auto-play next song
- 📊 Real-time progress slider
- 🖼 Thumbnail display

### 🛠 Tech Stack
- Flutter
- just\_audio
- HTTP API

### ⚠️ Note
This project uses a third-party API to fetch audio URLs. Availability depends on the API.

Ensure the Full URL endpoint in `main.lib` is `http://bardi.fsc-clan.eu/search?query=$query`

In case of using a different API to fetch audio streams, change the said endpoint to the one for your desired API.

