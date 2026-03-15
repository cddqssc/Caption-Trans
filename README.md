<p align="center"><a href="https://github.com/cddqssc/Caption-Trans"><img src="assets/images/app_icon.png" alt="Caption Trans" width="100" /></a></p>
<h3 align="center">Caption Translator</h3>
<p align="center">
  <a href="https://mit-license.org/"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
</p>
<p align="center">
  <a href="README.md"><img alt="English" src="https://img.shields.io/badge/English-d9d9d9"></a>
  <a href="README_zh.md"><img alt="中文(简体)" src="https://img.shields.io/badge/中文(简体)-d9d9d9"></a>
</p>

# What is Caption Trans?
Import videos, extract subtitles, and use AI to translate them into the target language.
Supports: Google Gemini (tested), OpenAI, DeepSeek, Ollama, and other OpenAI-compatible API services.

# Download
Supports macOS (Apple Silicon) and Windows.

Please go to [Releases](https://github.com/cddqssc/Caption-Trans/releases) to download.

## ⚠️ How to open on macOS
1. Double-click the app. It will be blocked by the system because it has not been signed with an Apple developer certificate.
2. Go to **System Settings** > **Privacy & Security**.
3. Scroll down to the Security section and click **"Open Anyway"** next to the app's block message.
4. Enter your Mac password and click **"Open"**. 
*(You only need to do this once.)*

# App Screenshot
<img src="screenshots/screenshot_en.jpg" alt="App Screenshot" width="500">

# Tips
Currently, only the Gemini API has been tested. **gemini-2.5-flash-lite** is recommended.

It balances speed and quality, and the price is relatively low. It can also translate sensitive content.

For models above Gemini 3, translating sensitive content may return an empty result, and the price is higher.

# License
[MIT License](LICENSE)

