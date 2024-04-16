-- TriviaBot
-- by Hexarobi

local SCRIPT_VERSION = "0.12"

---
--- Auto Updater
---

local auto_update_config = {
    source_url="https://raw.githubusercontent.com/hexarobi/stand-lua-triviabot/main/TriviaBot.lua",
    script_relpath=SCRIPT_RELPATH,
    verify_file_begins_with="--",
    dependencies= {
        {
            name = "Question Set: Easy (Teen & Celebrity)",
            source_url = "https://raw.githubusercontent.com/hexarobi/stand-lua-triviabot/main/resources/TriviaBot/questions/Easy (Teen & Celebrity).tsv",
            script_relpath = "resources/TriviaBot/questions/Easy (Teen & Celebrity).tsv",
        },
        {
            name = "Question Set: Hard (All)",
            source_url = "https://raw.githubusercontent.com/hexarobi/stand-lua-triviabot/main/resources/TriviaBot/questions/Hard (All).tsv",
            script_relpath = "resources/TriviaBot/questions/Hard (All).tsv",
        },
    },
}

util.ensure_package_is_installed("lua/auto-updater")
local auto_updater = require("auto-updater")
if auto_updater == true then
    auto_updater.run_auto_update(auto_update_config)
end

---
--- Dependencies
---

util.require_natives("3095a")
--local inspect = require("inspect")

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
    ask_full_categories = false,
    use_team_chat = false,
    reward_correct_answers = true,
    show_answers_in_status = false,
    allow_chat_command_start = true,
    tick_handler_delay = 1000,
    -- Experimental
    log_answers_in_database = false,
}

local function debug_log(message)
    if config.debug then
        util.log("[TriviaBot] "..message)
    end
end

---
--- Data
---

local triviabot = {}
triviabot.state = {
    is_game_running = false
}
local menus = {}

local diacritics = {
    ["à"] = "a",
    ["á"] = "a",
    ["â"] = "a",
    ["ã"] = "a",
    ["ä"] = "a",
    ["ç"] = "c",
    ["è"] = "e",
    ["é"] = "e",
    ["ê"] = "e",
    ["ë"] = "e",
    ["ì"] = "i",
    ["í"] = "i",
    ["î"] = "i",
    ["ï"] = "i",
    ["ñ"] = "n",
    ["ò"] = "o",
    ["ó"] = "o",
    ["ô"] = "o",
    ["õ"] = "o",
    ["ö"] = "o",
    ["ù"] = "u",
    ["ú"] = "u",
    ["û"] = "u",
    ["ü"] = "u",
    ["ý"] = "y",
    ["ÿ"] = "y",
    ["À"] = "A",
    ["Á"] = "A",
    ["Â"] = "A",
    ["Ã"] = "A",
    ["Ä"] = "A",
    ["Ç"] = "C",
    ["È"] = "E",
    ["É"] = "E",
    ["Ê"] = "E",
    ["Ë"] = "E",
    ["Ì"] = "I",
    ["Í"] = "I",
    ["Î"] = "I",
    ["Ï"] = "I",
    ["Ñ"] = "N",
    ["Ò"] = "O",
    ["Ó"] = "O",
    ["Ô"] = "O",
    ["Õ"] = "O",
    ["Ö"] = "O",
    ["Ù"] = "U",
    ["Ú"] = "U",
    ["Û"] = "U",
    ["Ü"] = "U",
    ["Ý"] = "Y"
}

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
--- User Database
---

local db
if config.log_answers_in_database then
    db = require("file_database")
    db.set_name("triviabot")
end
local user_db = {}

user_db.load_user = function(pid)
    local player_name = players.get_name(pid)
    local user_data = db.load_data(player_name)
    return user_db.apply_default_user_data(user_data)
end

user_db.save_user = function(pid, user_data)
    db.save_data(players.get_name(pid), user_data)
end

user_db.apply_default_user_data = function(user_data)
    if user_data == nil then user_data = {} end
    if user_data.num_correct_answers == nil then user_data.num_correct_answers = 0 end
    if user_data.total_winnings == nil then user_data.total_winnings = 0 end
    if user_data.first_answer_at == nil then user_data.first_answer_at = util.current_unix_time_seconds() end
    return user_data
end

user_db.log_players_score = function(pid, value)
    if not config.log_answers_in_database then return end
    local user_data = user_db.load_user(pid)
    user_db.apply_default_user_data(user_data)
    user_data.num_correct_answers = user_data.num_correct_answers + 1
    user_data.total_winnings = user_data.total_winnings + value
    user_db.save_user(pid, user_data)
end

---
--- Question Set Files
---

local question_sets = {}
local question_set_directory = filesystem.scripts_dir().."resources/TriviaBot/questions"
filesystem.mkdirs(question_set_directory)

local function count_lines_in_file(filepath)
    local f = io.open(filepath, "r")
    local count = 1
    for line in f:lines() do
        if count % 10000 == 0 then util.yield() end
        count = count + 1
    end
    f:close()
    return count
end

local function build_headers(line)
    local headers = {}
    local column_names = string.split(line, "\t")
    for column_number, column_name in column_names do
        headers[column_name] = column_number
    end
    return headers
end

local function read_question_cell(question_parts, headers, column_header, default_value)
    if headers[column_header] == nil then
        if default_value then
            return default_value
        else
            error("No column found in file: "..column_header)
        end
    end
    return question_parts[headers[column_header]] or ""
end

local function read_questions_file(filepath)
    local questions_rows = {}
    local f = io.open(filepath, "r")
    local count = 1
    for line in f:lines() do
        table.insert(questions_rows, line)
        if count % 10000 == 0 then util.yield() end
        count = count + 1
    end
    f:close()
    return questions_rows
end

local function build_question_file_loading_message(count, total_lines)
    local message = count
    if total_lines ~= nil then
        message = count.."/"..total_lines
        local percentage = math.floor((count / total_lines) * 100)
        if percentage >= 0 and percentage <= 100 then
            message = message .. " [".. percentage .."%]"
        end
    end
    return message
end

triviabot.build_question_from_line = function(line, headers)
    local question_parts = string.split(line, "\t")
    return {
        --title=read_question_cell(question_parts, headers, 'title'),
        value=tonumber(read_question_cell(question_parts, headers, 'value', 100)),
        category=triviabot.clean_quotes(read_question_cell(question_parts, headers, 'category', "")),
        --comments=read_question_cell(question_parts, headers, 'comments'),
        correct_answer=triviabot.clean_quotes(read_question_cell(question_parts, headers, 'answer')),
        raw_question=triviabot.clean_quotes(read_question_cell(question_parts, headers, 'question')),
        --air_date=read_question_cell(question_parts, headers, 'air_date'),
        --notes=read_question_cell(question_parts, headers, 'notes'),
    }
end

triviabot.load_questions_from_file = function(filepath, filename)
    local questions = {}
    local headers = {}
    local count = 1

    menus.status.menu_name = "Status"
    menus.status.value = "Loading Questions"
    menus.clue.menu_name = filename
    menus.clue.value = "Reading File..."

    local question_rows = read_questions_file(filepath)
    local total_lines = #question_rows
    for _, line in question_rows do
        if count == 1 then
            headers = build_headers(line)
        else
            table.insert(questions, triviabot.build_question_from_line(line, headers))
            if count % 10000 == 0 then
                menus.clue.value = build_question_file_loading_message(count, total_lines)
                util.yield(10)
            end
        end
        count = count + 1
    end
    menus.clue.value = build_question_file_loading_message(count, total_lines)
    debug_log("Loaded question set "..filename.." "..count.." questions")
    return questions
end

triviabot.build_question_sets = function()
    question_sets = {}
    for _, filepath in ipairs(filesystem.list_files(question_set_directory)) do
        if not filesystem.is_dir(filepath) then
            local _, filename, ext = string.match(filepath, "(.-)([^\\/]-%.?)[.]([^%.\\/]*)$")
            local question_set = { name=filename, file=filepath, has_loaded=false, }
            table.insert(question_sets, question_set)
        end
    end
end

---
--- Game Functions
---

triviabot.start_game = function()
    if triviabot.state.is_game_running then return end
    debug_log("Starting game")
    triviabot.state.is_game_running = true
    triviabot.state.num_questions_asked = 0
    triviabot.state.incorrect_answers = 0
    triviabot.state.scores = {}
    triviabot.fetch_next_question()
    return true
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
    user_db.log_players_score(pid, score)
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

triviabot.repeat_question = function()
    triviabot.send_message(triviabot.state.question.clue)
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
    triviabot.refresh_status_menu()
    debug_log(
            "Question "..triviabot.state.num_questions_asked.."/"..config.question_limit.."/"..config.missed_questions_shutoff
                    .." "..question.clue
                    .." Answers:['"..table.concat(question.correct_answers, "', '").."']"
    )
end

triviabot.extend_correct_answers = function(question, correct_answer)
    -- Force answer to lowercase
    correct_answer = correct_answer:lower()
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

triviabot.get_current_question_set = function()
    return question_sets[config.question_set_index]
end

triviabot.ensure_question_set_has_loaded = function(question_set)
    if question_set.is_loaded ~= true then
        if question_set.is_loading == true then error("Cannot trigger load again while already loading") end
        question_set.is_loading = true
        question_set.questions = triviabot.load_questions_from_file(question_set.file, question_set.name)
        question_set.is_loaded = true
        question_set.is_loading = false
    end
end

triviabot.fetch_question_jeopardy = function()
    local question = triviabot.get_random_question_from_current_question_set()
    if question.value == nil or question.value <= 0 then question.value = 2000 end
    question.clue = question.category.." for $"..question.value..": "..question.raw_question
    triviabot.handle_loaded_question(question)
end

triviabot.get_random_question_from_current_question_set = function()
    local question_set = triviabot.get_current_question_set()
    triviabot.ensure_question_set_has_loaded(question_set)
    if config.ask_full_categories and triviabot.state.last_question_index then
        local last_question = question_set.questions[triviabot.state.last_question_index]
        local next_index = triviabot.state.last_question_index + 1
        local next_question = question_set.questions[next_index]
        if last_question.category ~= "" and next_question and last_question.category == next_question.category then
            triviabot.state.last_question_index = next_index
            return next_question
        end
    end
    local question_index = math.random(1, #question_set.questions)
    if config.ask_full_categories then
        question_index = triviabot.find_first_question_index_of_category(question_set, question_index)
    end
    local question = question_set.questions[question_index]
    triviabot.state.last_question_index = question_index
    return question
end

triviabot.find_first_question_index_of_category = function(question_set, question_index)
    if question_set.questions[question_index] and question_set.questions[question_index].category ~= "" then
        while question_set.questions[question_index] and question_set.questions[question_index - 1]
                and question_set.questions[question_index].category == question_set.questions[question_index - 1].category do
            question_index = question_index - 1
        end
    end
    return question_index
end

triviabot.clean_quotes = function(text)
    local quoted_text = text:match("^\"(.*)\"$")
    if quoted_text then
        text = quoted_text:gsub('""', '"')
    end
    text = text:gsub('\\"', "\""):gsub('\\', "\'")
    return text
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
--- Build Question Sets
---

triviabot.build_question_sets()
local question_set_selections = {}
for index, question_set in question_sets do
    table.insert(question_set_selections, {index, question_set.name})
end

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
            expected="NINE"
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
        {
            original='The Turn of the Screw',
            expected='Turn of the Screw',
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
    if triviabot.get_current_question_set().is_loading == true then return end
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

menus.play_trivia = menu.my_root():toggle("Play Trivia", {"triviagame"}, "Check to start a round of trivia questions. When unchecked the game will end after the next question.", function(toggle, chat_type)
    --if (chat_type & CLICK_FLAG_CHAT == 0) and not config.allow_chat_command_start then return end
    --util.toast("Chatted ", TOAST_ALL)
    triviabot.state.is_game_on = toggle
    if not triviabot.start_game() then
        util.toast("Cannot start a game right now")
    end
end)

menu.my_root():divider("Game Status")
menus.status = menu.my_root():readonly("Status", "No Game Running")
menus.clue = menu.my_root():readonly("")

menu.my_root():divider("Actions")
menu.my_root():action("Repeat Question", {}, "", function()
    if not triviabot.state.is_game_running then return end
    if triviabot.state.question == nil then
        util.toast("Cannot repeat question until a new question has been asked")
        return
    end
    triviabot.repeat_question()
end)
menu.my_root():action("Ask Next Question", {}, "", function()
    if not triviabot.state.is_game_running then return end
    if triviabot.state.question ~= nil then
        util.toast("Cannot ask another question until the current question is done")
        return
    end
    triviabot.ask_next_question()
end)

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
settings_menu:toggle("Ask Full Categories", {}, "Ask all questions in the category (usually 5) before finding a new random category", function(on)
    config.ask_full_categories = on
end, config.ask_full_categories)

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
