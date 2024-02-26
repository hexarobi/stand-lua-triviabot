# TriviaBot
A Lua Script for Stand menu for GTA5. Ask Jeopardy-style questions within GTA.

![TriviaBot](https://i.imgur.com/GEp2wqv.jpeg)

# Example Chat
```
TriviaBot [ALL] SYNONYMS for $1000: This book of the Bible is a synonym of departure
Player [ALL] exodus
TriviaBot [ALL] That's right Player! The answer was: Exodus
```

# Features

* Support for multple question sets: Kids & Teens or Full (Seasons 1-35)
* Smart answer matching attempts to accept common rephrasings of the given answer (still not always perfect)
* General or Team Chat to avoid spamming the whole lobby
* Leaderboard tracking
* Optional reward players for correct answers
* Optionally extend rounds when correct answers are given
* Configure timing to answer a question, and before the next question

# Install
Option #1: Download the `TriviaBot.lua` file and save to your `Stand/Lua Scripts` folder. Any additional files should auto-download on first run. Internet access must be enabled before starting the script.

Option #2: Download [the project zip file](https://github.com/hexarobi/stand-lua-triviabot/archive/refs/heads/main.zip) and extract the contents of the `stand-lua-triviabot-main` folder into your `Stand/Lua Scripts` folder. Internet access is not required to be enabled with this option, but you will not recieve automated updates unless it is.

# How to Use
Run the script by going to `Stand > Lua Scripts > TriviaBot`.
Select the `Play Trivia` option to start a game. The game will continue until the question limit has been reached (default 5 questions). The box will be unchecked when the game is complete. If unchecked early, the game will end after the next question.

If the `Correct Answers Extend Game` option is on, then any correct answers within the last 3 questions of a game will extend the game by another 3 questions. This helps keep an active game keep going until people are done playing.

![Example Menu](https://i.imgur.com/iha3Ipz.png)
