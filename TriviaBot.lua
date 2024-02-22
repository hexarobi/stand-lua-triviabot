-- TriviaBot
-- by Hexarobi

local SCRIPT_VERSION = "0.1"

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
    switch_to_branch=selected_branch,
    verify_file_begins_with="--",
}
auto_updater.run_auto_update(auto_update_config)

---
--- Dependencies
---

util.require_natives("3095a")
local htmlEntities = require("htmlEntities")

local config = {
    time_to_answer = 40000,
    delay_between_questions = 15000,
}

local triviabot = {}
triviabot.state = {}

local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

triviabot.post_question = function()
    if triviabot.state.question == nil then return end
    send_message(triviabot.state.question)
end

triviabot.handle_correct_answer = function(pid)
    chat.send_message("That's right, "..PLAYER.GET_PLAYER_NAME(pid).."! The answer was: "..htmlEntities.decode(triviabot.state.question.correct_answer), false, true, true)
    menu.trigger_commands("rp" .. players.get_name(pid))
    triviabot.complete_question()
end

triviabot.handle_expired_answer_time = function()
    chat.send_message("Time's up!! The answer was: "..htmlEntities.decode(triviabot.state.question.correct_answer), false, true, true)
    triviabot.complete_question()
end

triviabot.complete_question = function()
    triviabot.state.question = nil
    if triviabot.state.remaining_questions == nil then triviabot.state.remaining_questions = 1 end
    triviabot.state.remaining_questions = triviabot.state.remaining_questions - 1
    if triviabot.state.remaining_questions > 0 then
        util.yield(config.delay_between_questions)
        triviabot.fetch_question()
    end
end

triviabot.handle_loaded_question = function(question)
    if question.type == "boolean" then
        question.question = "True or False: "..question.question
    end
    if question.type == "multiple" then
        local possible_answers = question.incorrect_answers
        table.insert(possible_answers, question.correct_answer)
        question.question = question.question .. " " .. table.concat(shuffle(possible_answers), ", ")
    end
    util.toast(question.question)
    chat.send_message(htmlEntities.decode(question.question), false, true, true)
    question.asked_time = util.current_time_millis()
    question.expiration_time = util.current_time_millis() + config.time_to_answer
    util.yield(100)
    triviabot.state.question = question
    util.toast(question.correct_answer)
end

triviabot.fetch_question = function()
    async_http.init("https://opentdb.com/api.php?amount=1&category=9", "", function(result, headers, status_code)
        local response_object = soup.json.decode(result)
        util.log(result)
        local question = response_object["results"][1]
        triviabot.handle_loaded_question(question)
    end, function(foo)
        util.toast("Error fetching trivia question "..foo, TOAST_ALL)
    end)
    async_http.dispatch()
end

local function answer_time_tick()
    if triviabot.state.question == nil then return end
    if triviabot.state.question.expiration_time < util.current_time_millis() then
        triviabot.handle_expired_answer_time()
    end
end

---
--- Chat Handler
---

chat.on_message(function(pid, reserved, message_text, is_team_chat, networked, is_auto)
    if triviabot.state.question == nil then return end
    -- trim "a", "the" etc..
    -- check numeric words vs numerals
    if string.find(message_text:lower(), htmlEntities.decode(triviabot.state.question.correct_answer:lower())) then
        triviabot.handle_correct_answer(pid)
    end
end)

---
--- Menus
---

menu.my_root():action("Ask Trivia Question", {"trivia"}, "", function()
    if triviabot.state.question ~= nil then return end
    triviabot.state.remaining_questions = 10
    triviabot.fetch_question()
end)

---
--- Runtime
---

util.create_tick_handler(answer_time_tick)
