-- TriviaBot
-- by Hexarobi

local SCRIPT_VERSION = "0.6"

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
    questions_per_round = 10,
    time_to_answer = 50,
    delay_between_questions = 50,
    question_set_index = 1,
    use_team_chat = false,
    reward_correct_answers = true,
}

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

triviabot.start_game = function(num_questions)
    if triviabot.state.is_game_running then return end
    if num_questions == nil then num_questions = config.questions_per_round end
    triviabot.state.is_game_running = true
    triviabot.state.num_questions = num_questions
    triviabot.state.num_questions_asked = 0
    triviabot.state.scores = {}
    --if triviabot.state.num_questions > 1 then
    --    triviabot.send_message("Starting a round of "..triviabot.state.num_questions.." trivia questions!")
    --end
    triviabot.fetch_next_question()
end

triviabot.handle_correct_answer = function(pid)
    triviabot.add_player_score(pid, triviabot.state.question.value)
    local message = "That's right, "..PLAYER.GET_PLAYER_NAME(pid).."!"
    message = message .. " The answer was: "..triviabot.state.question.correct_answer.."."
    message = message .. " You've got $"..triviabot.get_player_score(pid)
    triviabot.send_message(message)
    if config.reward_correct_answers then
        menu.trigger_commands("rp" .. players.get_name(pid))
    end
    triviabot.complete_question()
end

triviabot.add_player_score = function(pid, score)
    if triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)] == nil then triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)] = 0 end
    triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)] = triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)] + score
end

triviabot.get_player_score = function(pid)
    if triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)] == nil then triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)] = 0 end
    return triviabot.state.scores[PLAYER.GET_PLAYER_NAME(pid)]
end

triviabot.handle_expired_answer_time = function()
    triviabot.send_message("Time's up!! The answer was: "..triviabot.state.question.correct_answer)
    triviabot.complete_question()
end

triviabot.complete_question = function()
    triviabot.state.question = nil
    if triviabot.state.num_questions_asked == nil or triviabot.state.num_questions_asked >= triviabot.state.num_questions then
        triviabot.complete_game()
    else
        local delay_time = config.delay_between_questions * 1000
        util.yield(delay_time)
        triviabot.fetch_next_question()
    end
end

triviabot.complete_game = function()
    if triviabot.state.num_questions > 1 then
        local scores_message = "That's the end of the game. To play again say !trivia"
        local scores_messages = {}
        for player_name, score in triviabot.state.scores do
            table.insert(scores_messages, player_name..": $"..score)
        end
        if scores_messages then
            scores_message = scores_message.." Final Scores: \n"..table.concat(scores_messages, "\n")
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
    util.log(
        "Trivia Question: #"..question.index_number.." "..question.clue
                .." Answers:['"..table.concat(question.correct_answers, "', '").."']"
    )
end

-- Phase 1 high level rules, each of these will be run through phase 2 to find additional variants
triviabot.extend_correct_answers = function(question, correct_answer)
    -- Run phase 2 on answer
    triviabot.extend_correct_answers_phase_2(question, correct_answer)
    -- Remove "a ", "an ", "the " prefixes
    triviabot.extend_correct_answers_phase_2(question, correct_answer:gsub("^a ", ''))
    triviabot.extend_correct_answers_phase_2(question, correct_answer:gsub("^an ", ''))
    triviabot.extend_correct_answers_phase_2(question, correct_answer:gsub("^the ", ''))
    -- parts in parens are optional
    triviabot.extend_correct_answers_phase_2(question, correct_answer:gsub('%b()', ''):gsub('^%s*(.-)%s*$', '%1'))
end

-- Phase 2 applies to each result from phase 1, more detailed
triviabot.extend_correct_answers_phase_2 = function(question, correct_answer)
    if correct_answer == nil or correct_answer == "" then return end
    -- Add answer
    triviabot.add_correct_answer(question, correct_answer)
    -- Remove "a ", "an ", "the " prefixes
    triviabot.add_correct_answer(question, correct_answer:gsub("^a ", ''))
    triviabot.add_correct_answer(question, correct_answer:gsub("^an ", ''))
    triviabot.add_correct_answer(question, correct_answer:gsub("^the ", ''))
    -- Remove any special characters
    triviabot.add_correct_answer(question, correct_answer:gsub('[%p%c]', ''))
    -- replace dashes with spaces
    triviabot.add_correct_answer(question, correct_answer:gsub('-', ' '))
    -- replace number words with numerics
    triviabot.add_correct_answer(question, correct_answer:gsub('one', '1'))
    triviabot.add_correct_answer(question, correct_answer:gsub('two', '2'))
    triviabot.add_correct_answer(question, correct_answer:gsub('three', '3'))
    triviabot.add_correct_answer(question, correct_answer:gsub('four', '4'))
    triviabot.add_correct_answer(question, correct_answer:gsub('five', '5'))
    triviabot.add_correct_answer(question, correct_answer:gsub('six', '6'))
    triviabot.add_correct_answer(question, correct_answer:gsub('seven', '7'))
    triviabot.add_correct_answer(question, correct_answer:gsub('eight', '8'))
    triviabot.add_correct_answer(question, correct_answer:gsub('nine', '9'))
    triviabot.add_correct_answer(question, correct_answer:gsub('ten', '10'))
    -- Remove diacritcs
    triviabot.add_correct_answer(question, correct_answer:gsub("[%z\1-\127\194-\244][\128-\191]*", diacritics))
end

triviabot.add_correct_answer = function(question, answer)
    if answer == nil or answer == "" then return end
    if not triviabot.is_in(answer, question.correct_answers) then
        table.insert(question.correct_answers, answer)
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
    if question.value <= 0 then question.value = 1000 end
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
    if triviabot.state.question.clue == given_answer then return end -- Ignore the clue itself as a potential answer
    for _, correct_answer in triviabot.state.question.correct_answers do
        if string.find(given_answer:lower(), correct_answer:lower()) then
            triviabot.handle_correct_answer(pid)
        end
    end
end


--triviabot.fetch_question_opentrivia = function()
--    async_http.init("https://opentdb.com/api.php?amount=1&category=9", "", function(result, headers, status_code)
--        local response_object = soup.json.decode(result)
--        util.log(result)
--        local question = response_object["results"][1]
--
--        question.correct_answer = htmlEntities.decode(question.correct_answer)
--        question.clue = htmlEntities.decode(question.clue)
--
--        if question.type == "boolean" then
--            question.clue = "True or False: "..question.clue
--        end
--        if question.type == "multiple" then
--            local possible_answers = question.incorrect_answers
--            table.insert(possible_answers, question.correct_answer)
--            question.clue = question.clue .. " " .. table.concat(shuffle(possible_answers), ", ")
--        end
--
--        triviabot.handle_loaded_question(question)
--    end, function(foo)
--        util.toast("Error fetching trivia question "..foo, TOAST_ALL)
--    end)
--    async_http.dispatch()
--end

local function answer_time_tick()
    if triviabot.state.question == nil then return end
    if triviabot.state.question.expiration_time ~= nil and triviabot.state.question.expiration_time < util.current_time_millis() then
        triviabot.handle_expired_answer_time()
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
            original="Pokémon",
            expected="Pokemon"
        }
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
        if not triviabot.is_in(test_case.expected, question.correct_answers) then
            util.toast("Test Failed: "..test_case.expected.." not found in ["..table.concat(question.correct_answers, ", ").."]", TOAST_ALL)
            counter.failed = counter.failed + 1
        else
            counter.passed = counter.passed + 1
        end
    end
    util.toast("Tests Completed. Run:"..counter.run.." Passed:"..counter.passed.." Failed:"..counter.failed, TOAST_ALL)
end

---
--- Menus
---

menu.my_root():action("Ask One Question", {"triviaquestion"}, "", function()
    triviabot.start_game(1)
end, nil, nil, COMMANDPERM_FRIENDLY)

menu.my_root():action("Play a game of trivia", {"trivia"}, "", function()
    triviabot.start_game()
end, nil, nil, COMMANDPERM_FRIENDLY)

---
--- Settings Menu
---

local settings_menu = menu.my_root():list("Settings")
settings_menu:list_select("Question Set", {}, "Select which question set to draw from", question_set_selections, config.question_set_index, function(value)
    config.question_set_index = value
end)
settings_menu:slider("Questions per game", {}, "How many questions should be asked per game", 1, 100, config.questions_per_round, 1, function(value)
    config.questions_per_round = value
end)
settings_menu:toggle("Reward Correct Answers", {}, "Use Stand's RP command to reward correct answers", function(on)
    config.reward_correct_answers = on
end, config.reward_correct_answers)
settings_menu:toggle("Use Team Chat", {}, "Send trivia bot chat into team chat only", function(on)
    config.use_team_chat = on
end, config.use_team_chat)

settings_menu:divider("Delays")
settings_menu:slider("Answer Time", {"triviaanswertime"}, "Amount of time given to answer a question, in seconds.", 1, 120, config.time_to_answer, 1, function(value)
    config.time_to_answer = value
end)
settings_menu:slider("Question Time", {"triviaanswertime"}, "Delay after an answer before the next question is asked, in seconds", 1, 360, config.delay_between_questions, 1, function(value)
    config.delay_between_questions = value
end)


settings_menu:divider("Debug")
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

util.create_tick_handler(answer_time_tick)
