-- TriviaBot
-- by Hexarobi

local SCRIPT_VERSION = "0.9"

-- Auto Updater from https://github.com/hexarobi/stand-lua-auto-updater
local status, auto_updater = pcall(require, "auto-updater")
if not status then
    if not async_http.have_access() then
        util.toast("Failed to install auto-updater. Internet access is disabled. To enable automatic updates, please stop the script then uncheck the `Disable Internet Access` option.")
    else
        local auto_update_complete = nil util.toast("Installing auto-updater...", TOAST_ALL)
        async_http.init("raw.githubusercontent.com", "/hexarobi/stand-lua-auto-updater/main/auto-updater.lua",
                function(raw_result, raw_headers, raw_status_code)
                    local function parse_auto_update_result(result, headers, status_code)
                        local error_prefix = "Error downloading auto-updater: "
                        if status_code ~= 200 then util.toast(error_prefix..status_code, TOAST_ALL) return false end
                        if not result or result == "" then util.toast(error_prefix.."Found empty file.", TOAST_ALL) return false end
                        filesystem.mkdir(filesystem.scripts_dir() .. "lib")
                        local file = io.open(filesystem.scripts_dir() .. "lib\\auto-updater.lua", "wb")
                        if file == nil then util.toast(error_prefix.."Could not open file for writing.", TOAST_ALL) return false end
                        file:write(result) file:close() util.toast("Successfully installed auto-updater lib", TOAST_ALL) return true
                    end
                    auto_update_complete = parse_auto_update_result(raw_result, raw_headers, raw_status_code)
                end, function() util.toast("Error downloading auto-updater lib. Update failed to download.", TOAST_ALL) end)
        async_http.dispatch() local i = 1 while (auto_update_complete == nil and i < 40) do util.yield(250) i = i + 1 end
        if auto_update_complete == nil then error("Error downloading auto-updater lib. HTTP Request timeout") end
        auto_updater = require("auto-updater")
    end
end
if auto_updater == true then error("Invalid auto-updater lib. Please delete your Stand/Lua Scripts/lib/auto-updater.lua and try again") end

---
--- Auto Updater
---

local auto_update_config = {
    source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-triviabot/main/TriviaBot.lua",
    script_relpath=SCRIPT_RELPATH,
    verify_file_begins_with="--",
    dependencies= {
        {
            name = "Question Set: Kids & Teens",
            source_url = "https://raw.githubusercontent.com/hexarobi/stand-lua-triviabot/main/resources/TriviaBot/kids_teen.tsv",
            script_relpath = "resources/TriviaBot/kids_teen.tsv",
        },
        {
            name = "Question Set: Full Seasons 1-35",
            source_url = "https://raw.githubusercontent.com/hexarobi/stand-lua-triviabot/main/resources/TriviaBot/master_season1-35.tsv",
            script_relpath = "resources/TriviaBot/master_season1-35.tsv",
        },
    },
}
auto_updater.run_auto_update(auto_update_config)

---
--- Dependencies
---

util.require_natives("3095a")
--local inspect = require("inspect")

---
--- Question Set Files
---

local question_sets = {
    -- Files from https://www.kaggle.com/datasets/prondeau/350000-jeopardy-questions?resource=download
    {
        name = "Kids & Teens",
        file = filesystem.scripts_dir().."resources/TriviaBot/kids_teen.tsv",
        num_questions = 20800
    },
    {
        name = "Full: Seasons 1-35",
        file = filesystem.scripts_dir().."resources/TriviaBot/master_season1-35.tsv",
        num_questions = 349642
    },
}

local question_set_selections = {}
for index, question_set in question_sets do
    table.insert(question_set_selections, {index, question_set.name})
end

---
--- Config
---

local config = {
    debug = false,
    question_limit = 0,
    missed_questions_shutoff = 5,
    time_to_answer = 50,
    delay_between_questions = 70,
    question_set_index = 1,
    use_team_chat = false,
    reward_correct_answers = true,
    show_answers_in_status = false,
    allow_chat_command_start = true,
    tick_handler_delay = 1000,
}

local menus = {}

local diacritics = {}
diacritics["à"] = "a"
diacritics["á"] = "a"
diacritics["â"] = "a"
diacritics["ã"] = "a"
diacritics["ä"] = "a"
diacritics["ç"] = "c"
diacritics["è"] = "e"
diacritics["é"] = "e"
diacritics["ê"] = "e"
diacritics["ë"] = "e"
diacritics["ì"] = "i"
diacritics["í"] = "i"
diacritics["î"] = "i"
diacritics["ï"] = "i"
diacritics["ñ"] = "n"
diacritics["ò"] = "o"
diacritics["ó"] = "o"
diacritics["ô"] = "o"
diacritics["õ"] = "o"
diacritics["ö"] = "o"
diacritics["ù"] = "u"
diacritics["ú"] = "u"
diacritics["û"] = "u"
diacritics["ü"] = "u"
diacritics["ý"] = "y"
diacritics["ÿ"] = "y"
diacritics["À"] = "A"
diacritics["Á"] = "A"
diacritics["Â"] = "A"
diacritics["Ã"] = "A"
diacritics["Ä"] = "A"
diacritics["Ç"] = "C"
diacritics["È"] = "E"
diacritics["É"] = "E"
diacritics["Ê"] = "E"
diacritics["Ë"] = "E"
diacritics["Ì"] = "I"
diacritics["Í"] = "I"
diacritics["Î"] = "I"
diacritics["Ï"] = "I"
diacritics["Ñ"] = "N"
diacritics["Ò"] = "O"
diacritics["Ó"] = "O"
diacritics["Ô"] = "O"
diacritics["Õ"] = "O"
diacritics["Ö"] = "O"
diacritics["Ù"] = "U"
diacritics["Ú"] = "U"
diacritics["Û"] = "U"
diacritics["Ü"] = "U"
diacritics["Ý"] = "Y"

local number_words = {
    {1, "one"},
    {2, "two"},
    {3, "three"},
    {4, "four"},
    {5, "five"},
    {6, "six"},
    {7, "seven"},
    {8, "eight"},
    {9, "nine"},
    {10, "ten"},
}

---
--- State
---

local triviabot = {}
triviabot.state = {
    is_game_running = false
}

---
--- Functions
---

local function debug_log(message)
    if config.debug then
        util.log("[TriviaBot] "..message)
    end
end

triviabot.start_game = function()
    if triviabot.state.is_game_running then return end
    debug_log("Starting game")
    triviabot.state.is_game_running = true
    triviabot.state.num_questions_asked = 0
    triviabot.state.incorrect_answers = 0
    triviabot.state.scores = {}
    --if triviabot.state.num_questions > 1 then
    --    triviabot.send_message("Starting a round of "..triviabot.state.num_questions.." trivia questions!")
    --end
    triviabot.fetch_next_question()
end

triviabot.ask_next_question = function()
    if not triviabot.state.is_game_running then return end
    if triviabot.state.question ~= nil then return end
    triviabot.fetch_next_question()
end

triviabot.handle_correct_answer = function(pid)
    debug_log("Correct answer from "..PLAYER.GET_PLAYER_NAME(pid))
    triviabot.add_player_score(pid, triviabot.state.question.value)
    local message = "That's right, "..PLAYER.GET_PLAYER_NAME(pid).."!"
    message = message .. " The answer was: "..triviabot.state.question.correct_answer.."."
    message = message .. " You've got $"..triviabot.get_player_score(pid)
    triviabot.send_message(message)
    if config.reward_correct_answers then
        menu.trigger_commands("rp" .. players.get_name(pid))
    end
    -- Reset incorrect answers count
    triviabot.state.incorrect_answers = 0
    triviabot.complete_question()
end

triviabot.add_player_score = function(pid, score)
    if triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)] == nil then triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)] = 0 end
    triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)] = triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)] + score
    debug_log("New score for "..PLAYER.GET_PLAYER_NAME(pid).." $"..triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)])
end

triviabot.get_player_score = function(pid)
    if triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)] == nil then triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)] = 0 end
    return triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)]
end

triviabot.handle_expired_answer_time = function()
    triviabot.send_message("Time's up!! The answer was: "..triviabot.state.question.correct_answer)
    triviabot.state.incorrect_answers = triviabot.state.incorrect_answers + 1
    triviabot.complete_question()
end

triviabot.complete_question = function()
    triviabot.state.question = nil

    -- Missed Questions Shutoff
    if config.missed_questions_shutoff > 0 and triviabot.state.incorrect_answers > config.missed_questions_shutoff then
        debug_log("Game End: "..triviabot.state.incorrect_answers.." incorrect answers reached.")
        triviabot.complete_game()

    -- Question Limit Shutoff
    elseif config.question_limit > 0 and triviabot.state.num_questions_asked >= config.question_limit then
        debug_log("Game End: "..triviabot.state.num_questions_asked.." questions asked.")
        triviabot.complete_game()

    -- Play box is no longer checked
    elseif triviabot.state.is_game_on ~= true then
        debug_log("Game End: Play Game toggle is no longer checked")
        triviabot.complete_game()

    -- Else queue next question
    else
        triviabot.state.next_question_time = util.current_time_millis() + (config.delay_between_questions * 1000)
    end
end

triviabot.complete_game = function()
    if triviabot.state.num_questions_asked == nil or triviabot.state.num_questions_asked > 1 then
        local scores_message = "That's the end of the game. To play again say !trivia"
        if triviabot.state.scores and #triviabot.state.scores > 0 then
            local scores_messages = {}
            for player_name, score in triviabot.state.scores do
                table.insert(scores_messages, player_name..": $"..score)
            end
            if scores_messages then
                scores_message = scores_message.." Final Scores: \n"..table.concat(scores_messages, "\n")
            end
        end
        triviabot.send_message(scores_message)
    end
    triviabot.state.is_game_running = false
end

triviabot.handle_loaded_question = function(question)
    if triviabot.state.question ~= nil then
        util.toast("Cannot load new question, already have one in play.")
        return
    end
    triviabot.state.question = question
    triviabot.send_message(triviabot.state.question.clue)
    triviabot.state.question.correct_answers = {triviabot.state.question.correct_answer}
    triviabot.extend_correct_answers(triviabot.state.question, triviabot.state.question.correct_answer)
    triviabot.state.question.asked_time = util.current_time_millis()
    triviabot.state.question.expiration_time = util.current_time_millis() + (config.time_to_answer * 1000)
    if triviabot.state.num_questions_asked == nil then triviabot.state.num_questions_asked = 0 end
    triviabot.state.num_questions_asked = triviabot.state.num_questions_asked + 1
    debug_log(
        "Question "..triviabot.state.num_questions_asked.."/"..config.question_limit.."/"..config.missed_questions_shutoff
                .." #"..question.index_number.." "..question.clue
                .." Answers:['"..table.concat(question.correct_answers, "', '").."']"
    )
end

triviabot.extend_correct_answers = function(question, correct_answer)
    -- Add answer
    triviabot.add_correct_answer(question, correct_answer)
    -- Remove "a ", "an ", "the ", "to " prefixes
    triviabot.add_correct_answer(question, correct_answer:gsub("^a ", ''))
    triviabot.add_correct_answer(question, correct_answer:gsub("^an ", ''))
    triviabot.add_correct_answer(question, correct_answer:gsub("^the ", ''))
    triviabot.add_correct_answer(question, correct_answer:gsub("^to ", ''))
    -- remove plural s from long enough answers
    if #correct_answer > 5 then
        triviabot.add_correct_answer(question, correct_answer:gsub("s$", ''))
    end
    -- replace ampersand with "and"
    triviabot.add_correct_answer(question, correct_answer:gsub(" & ", ' and '))
    -- parts in parens are optional
    triviabot.add_correct_answer(question, correct_answer:gsub('%b()', ''):gsub('^%s*(.-)%s*$', '%1'))
    -- Remove any special characters
    triviabot.add_correct_answer(question, correct_answer:gsub('[%p%c]', ''))
    -- replace dashes with spaces
    triviabot.add_correct_answer(question, correct_answer:gsub('-', ' '))
    -- replace number words with numerics, and vice-versa
    for _, number_word in number_words do
        triviabot.add_correct_answer(question, correct_answer:gsub(number_word[2], number_word[1]))
        triviabot.add_correct_answer(question, correct_answer:gsub(number_word[1], number_word[2]))
    end
    -- Remove diacritcs
    triviabot.add_correct_answer(question, correct_answer:gsub("[%z\1-\127\194-\244][\128-\191]*", diacritics))

end

-- Phase 2 applies to each result from phase 1, more detailed
triviabot.extend_correct_answers_phase_2 = function(question, correct_answer)
    if correct_answer == nil or correct_answer == "" then return end
end

triviabot.add_correct_answer = function(question, answer)
    if answer == nil or answer == "" then return end
    if not triviabot.is_in(answer, question.correct_answers) then
        table.insert(question.correct_answers, answer)
        -- Also check for extensions on newly added answer
        triviabot.extend_correct_answers(question, answer)
    end
end

triviabot.is_in = function(needle, haystack)
    for _, haystack_item in pairs(haystack) do
        if needle == haystack_item then
            return true
        end
    end
    return false
end

triviabot.send_message = function(message)
    chat.send_message(message, config.use_team_chat, true, true)
end

triviabot.fetch_next_question = function()
    if triviabot.state.question ~= nil then return end
    triviabot.fetch_question_jeopardy()
end

triviabot.fetch_question_jeopardy = function()
    local question_set = question_sets[config.question_set_index]
    local index_number = math.random(1, question_set.num_questions)
    local question_line = triviabot.get_nth_line(question_set.file, index_number)
    local question_parts = string.split(question_line, "\t")
    local question = {
        index_number=index_number,
        round=question_parts[1],
        value=tonumber(question_parts[2]),
        daily_double=question_parts[3],
        category=triviabot.clean_quotes(question_parts[4]),
        comments=question_parts[5],
        correct_answer=triviabot.clean_quotes(question_parts[7]),
        raw_question=triviabot.clean_quotes(question_parts[6]),
        air_date=question_parts[8],
        notes=question_parts[9],
    }
    if question.value == nil or question.value <= 0 then question.value = 2000 end
    question.clue = question.category.." for $"..question.value..": "..question.raw_question
    triviabot.handle_loaded_question(question)
end

triviabot.clean_quotes = function(text)
    return text:gsub('\\"', "\""):gsub('\\', "\'")
end

triviabot.get_nth_line = function(fileName, n)
    local f = io.open(fileName, "r")
    local count = 1

    for line in f:lines() do
        if count == n then
            f:close()
            return line
        end
        count = count + 1
    end

    f:close()
    error("Not enough lines in file!")
end

triviabot.check_answer = function(pid, given_answer)
    if triviabot.state.question == nil then return end
    if triviabot.is_answer_in_correct_answers(triviabot.state.question, given_answer) then
        triviabot.handle_correct_answer(pid)
    end
end

triviabot.is_answer_in_correct_answers = function(question, given_answer)
    if question.clue == given_answer then return end -- Ignore the clue itself as a potential answer
    --debug_log("Checking for answer `"..given_answer.."` in [`"..table.concat(question.correct_answers, "`, `").."`]")
    for _, correct_answer in question.correct_answers do
        -- Add an escape character (%) before any non-alphanumeric character to avoid pattern matching in answers
        correct_answer = correct_answer:gsub("([^%w])", "%%%1")
        if string.find(given_answer:lower(), correct_answer:lower()) then
            return true
        end
    end
    return false
end

triviabot.handle_update_tick = function()
    if triviabot.state.next_tick_time == nil or util.current_time_millis() > triviabot.state.next_tick_time then
        triviabot.state.next_tick_time = util.current_time_millis() + config.tick_handler_delay
        triviabot.answer_time_tick()
        triviabot.next_question_tick()
        triviabot.refresh_status_menu()
    end
end

triviabot.time_left_to_answer = function()
    if triviabot.state.question.expiration_time == nil then return end
    local time = math.floor((triviabot.state.question.expiration_time - util.current_time_millis()) / 1000)
    if time < 0 then time = 0 end
    return time
end

triviabot.answer_time_tick = function()
    if triviabot.state.question == nil then return end
    if triviabot.state.question.expiration_time ~= nil and triviabot.state.question.expiration_time < util.current_time_millis() then
        triviabot.handle_expired_answer_time()
    end
end

triviabot.time_until_next_question = function()
    if triviabot.state.next_question_time == nil then return 0 end
    local time = math.floor((triviabot.state.next_question_time - util.current_time_millis()) / 1000)
    if time < 0 then time = 0 end
    return time
end

triviabot.next_question_tick = function()
    if triviabot.state.is_game_running
        and triviabot.state.next_question_time ~= nil and triviabot.state.next_question_time < util.current_time_millis() then
        triviabot.ask_next_question()
    end
end

---
--- Chat Handler
---

chat.on_message(function(pid, reserved, message_text, is_team_chat, networked, is_auto)
    triviabot.check_answer(pid, message_text)
end)

---
--- Tests
---

triviabot.test_extend_correct_answers = function()
    local test_cases = {
        {
            original="the CIA",
            expected="CIA"
        },
        {
            original="the CIA (Central Intelligence Agency)",
            expected="CIA"
        },
        {
            original="(Pablo) Picaso",
            expected="Picaso"
        },
        {
            original="one",
            expected="1"
        },
        {
            original="9",
            expected="nine"
        },
        {
            original="Pokémon",
            expected="Pokemon"
        },
        {
            original="the St. Lawrence (Canada & the U.S.)",
            expected="st lawrence"
        },
        {
            original='O-B-S-O-L-E-T-E',
            not_expected='o and b for s while olete',
        },
        {
            original='Lewis & Clark',
            expected='lewis and clark',
        },
    }
    local counter = {
        run = 0,
        passed = 0,
        failed = 0,
    }
    for _, test_case in test_cases do
        counter.run = counter.run + 1
        local question = {
            correct_answer=test_case.original,
            correct_answers={},
        }
        triviabot.extend_correct_answers(question, question.correct_answer)
        if test_case.expected ~= nil then
            if not triviabot.is_answer_in_correct_answers(question, test_case.expected) then
                util.toast("Test Failed: "..test_case.expected.." not found in ["..table.concat(question.correct_answers, ", ").."]", TOAST_ALL)
                counter.failed = counter.failed + 1
            else
                counter.passed = counter.passed + 1
            end
        end
        if test_case.not_expected ~= nil then
            if triviabot.is_answer_in_correct_answers(question, test_case.not_expected) then
                util.toast("Test Failed: "..test_case.not_expected.." unexpectedly found in ["..table.concat(question.correct_answers, ", ").."]", TOAST_ALL)
                counter.failed = counter.failed + 1
            else
                counter.passed = counter.passed + 1
            end
        end
    end
    util.toast("Tests Completed. Run:"..counter.run.." Passed:"..counter.passed.." Failed:"..counter.failed, TOAST_ALL)
end

---
--- Rebuild Status Menu
---

triviabot.refresh_status_menu = function()
    if triviabot.state.is_game_running == false then
        menus.play_trivia.value = false
        menus.status.value = "No Game Running"
        menus.clue.menu_name = ""
        menus.clue.value = ""
        return
    end
    if triviabot.state.question == nil then
        menus.status.menu_name = "Next Question In"
        menus.status.value = tostring(triviabot.time_until_next_question())
        menus.clue.menu_name = "Remaining Questions"
        if config.question_limit > 0 then
            menus.clue.value = (triviabot.state.question_limit - triviabot.state.num_questions_asked)
        elseif config.missed_questions_shutoff > 0 then
            menus.clue.value = "At Least "..(config.missed_questions_shutoff - triviabot.state.incorrect_answers)
        else
            menus.clue.value = "Unlimited"
        end
    else
        menus.status.menu_name = "Time To Answer"
        menus.status.value = tostring(triviabot.time_left_to_answer())
        menus.clue.menu_name = triviabot.state.question.clue
        menus.clue.value = ""
        if config.show_answers_in_status then
            menus.clue.value = menus.clue.value.." Answer: "..triviabot.state.question.correct_answer
        end
    end
end


---
--- Main Menu
---

menus.play_trivia = menu.my_root():toggle("Play Trivia", {"trivgame"}, "Check to start a round of trivia questions. When unchecked the game will end after the next question.", function(toggle)
    triviabot.state.is_game_on = toggle
    if not triviabot.start_game() then
        util.toast("Cannot start a game right now")
    end
end)

menu.my_root():divider("Game Status")
menus.status= menu.my_root():readonly("Status", "No Game Running")
menus.clue = menu.my_root():readonly("")

---
--- Settings Menu
---

menu.my_root():divider("Options")
local settings_menu = menu.my_root():list("Settings")
settings_menu:list_select("Question Set", {}, "Select which question set to draw from", question_set_selections, config.question_set_index, function(value)
    config.question_set_index = value
end)
settings_menu:slider("Question Limit", {"triviaquestionlimit"}, "A hard limit to the number of questions to be asked. 0 means no limit.", 0, 100, config.question_limit, 1, function(value)
    config.question_limit = value
end)
settings_menu:slider("Missed Question Shutoff", {"triviamissedquestionshutoff"}, "End the game once this many questions have been missed in a row. 0 means no limit.", 0, 100, config.missed_questions_shutoff, 1, function(value)
    config.missed_questions_shutoff = value
end)

settings_menu:toggle("Reward Correct Answers", {}, "Use Stand's RP command to reward correct answers", function(on)
    config.reward_correct_answers = on
end, config.reward_correct_answers)
settings_menu:toggle("Use Team Chat", {}, "Send trivia bot chat into team chat only. Answers will still be accepted in any chat.", function(on)
    config.use_team_chat = on
end, config.use_team_chat)
settings_menu:toggle("Show Answers In Status", {}, "Include the answer in the question status help menu.", function(on)
    config.show_answers_in_status = on
end, config.show_answers_in_status)

settings_menu:toggle("Allow Chat Command Start", {}, "Allow !trivia chat command to start a game of trivia. Friendly chat commands must be enabled under Online>Chat>Commands", function(on)
    config.allow_chat_command_start = on
end, config.allow_chat_command_start)
settings_menu:action("Chat Command to Play Trivia", {"trivia"}, "Alternative way to start a game. This is here to support chat commands.", function()
    if config.allow_chat_command_start then
        menus.play_trivia.value = true
        triviabot.start_game()
    end
end, nil, nil, COMMANDPERM_FRIENDLY)

settings_menu:divider("Delays")
settings_menu:slider("Answer Time", {"triviaanswertime"}, "Amount of time given to answer a question, in seconds.", 10, 120, config.time_to_answer, 1, function(value)
    config.time_to_answer = value
end)
settings_menu:slider("Question Time", {"triviaquestiontime"}, "Delay after an answer before the next question is asked, in seconds", 10, 3800, config.delay_between_questions, 1, function(value)
    config.delay_between_questions = value
end)


settings_menu:divider("Debug")
settings_menu:toggle("Debug Mode", {}, "When on, will include details of activity in logs", function(on)
    config.debug = on
end, config.debug)
local test_cases_menu = settings_menu:list("Test Cases")
test_cases_menu:action("Extend Correct Answers", {"cleananswer"}, "Test the answer cleaning algorithm", function()
    triviabot.test_extend_correct_answers()
end)

---
--- About Menu
---

local about_menu = menu.my_root():list("About TriviaBot")
about_menu:divider("TriviaBot")
about_menu:readonly("Version", SCRIPT_VERSION)
about_menu:action("Check for Update", {}, "The script will automatically check for updates at most daily, but you can manually check using this option anytime.", function()
    auto_update_config.check_interval = 0
    if auto_updater.run_auto_update(auto_update_config) then
        util.toast("No updates found")
    end
end)
about_menu:hyperlink("Github Source", "https://github.com/hexarobi/stand-lua-triviabot", "View source files on Github")
about_menu:hyperlink("Discord", "https://discord.gg/RF4N7cKz", "Open Discord Server")

---
--- Runtime
---

util.create_tick_handler(triviabot.handle_update_tick)
