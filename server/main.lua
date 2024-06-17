local cache = {}

-- Funkcja do dodawania wiadomosci do czatu
local function addMessage(source, message)
    TriggerClientEvent('chat:addMessage', source, message)
end

-- Funkcja ustawiajaca dane w cache
local function setCache(key, value, ttl, isGlobal, source)
    key = string.lower(key)
    if ttl and ttl < 30 and ttl ~= 0 then
        addMessage(source, { args = { '^1ERROR', 'Minimalny czas TTL wynosi 30 sekund' } })
        return false, "Minimalny czas TTL wynosi 30 sekund"
    end

    local expirationTime = nil
    local ttlString = nil

    if ttl and ttl ~= 0 then
        expirationTime = os.time() + ttl
        ttlString = ttl .. ' sekund'
    else
        ttlString = 'trwale'
    end

    TimeMessage(source)

    if cache[key] then
        addMessage(source, { args = { '^1ERROR', 'Klucz ' .. key .. ' juz istnieje w pamieci podrecznej' } })
        return false, "Klucz juz istnieje w pamieci podrecznej"
    end

    cache[key] = { value = value, expiration = expirationTime, ttl = ttl, isGlobal = isGlobal }

    local cacheType = isGlobal and "globalny" or "lokalny"

    addMessage(source, { args = { '^2CACHE', 'Ustawiono ' .. cacheType .. ' cache dla klucza:' } })
    addMessage(source, { args = { '^2CACHE', 'Klucz: ' .. key } })
    addMessage(source, { args = { '^2CACHE', 'Wartosc: ' .. value } })
    addMessage(source, { args = { '^2CACHE', 'Czas do automatycznego usuniecia: ' .. ttlString } })

    if isGlobal then
        twitterWood('CACHE LOG' .."\n" .."\n".. GetPlayerName(source).. ' UTWORZYL KLUCZ' .."\n".. 'NAZAWA KLUCZA: ' ..key.. "\n" .. 'WARTOSC: ' ..value)
        MySQL.Async.execute('REPLACE INTO lnd_cache (`key`, `value`, `creation_time`) VALUES (?, ?, NOW())', {
            key, value
        }, function(rowsAffected)
            if rowsAffected > 0 then
                -- przeniesienie wyzej wiadomosci do global 
            else
                addMessage(source, { args = { '^1ERROR', 'Wystapil blad podczas ustawiania globalnego cache' } })
            end
        end)
    end

    -- Zwrocenie danych
    local returnData = { key = key, value = value, ttl = ttlString }
    print("Cache set successfully: " .. json.encode(returnData))
    return true, returnData
end




function refreshCache(source)
    MySQL.Async.fetchAll('SELECT `key`, `value`, `creation_time`, `updated_at` FROM lnd_cache', {}, function(result)
        if result then
            for _, row in ipairs(result) do
                local key = row.key
                local value = row.value
                local ttl = row.ttl or 0
                local expiration = ttl > 0 and (os.time() + ttl) or nil
                cache[key] = { value = value, expiration = expiration, ttl = ttl, isGlobal = true, creation_time = row.creation_time, updated_at = row.updated_at }
            end
            addMessage(source, { args = { '^1CACHE', 'Cache zostal odswiezony' } }) 
        else
            addMessage(source, { args = { '^1ERROR', 'Wystapil blad podczas odswiezania cache' } }) 
        end
    end)
end


local function getCache(key, source)
    key = string.lower(key)
    refreshCache(source)
    local entry = cache[key]
    if entry then
        if entry.expiration and os.time() > entry.expiration then
            removeCacheAfterTTL(key, source)
            addMessage(source, { args = { '^1ERROR', 'Klucz ' .. key .. ' nie zostal znaleziony lub wygasl' } })
            return
        end
        addMessage(source, { args = { '^3INFO', 'Nazwa: ' .. key } })
        addMessage(source, { args = { '^3INFO', 'Wartosc: ' .. entry.value } })
        local ttlMessage = (entry.expiration and (entry.expiration - os.time()) .. ' sekund' or 'Trwale')
        addMessage(source, { args = { '^3INFO', 'TTL: ' .. ttlMessage } })
        addMessage(source, { args = { '^3INFO', 'Globalny: ' .. (entry.isGlobal and 'true' or 'false') } })
        return
    end

    MySQL.Async.fetchAll('SELECT `value`, `creation_time`, `updated_at` FROM lnd_cache WHERE `key` = ?', { key }, function(result)
        if result[1] then
            local row = result[1]
            local ttl = row.ttl or 0
            if ttl > 0 and ttl < os.time() then
                removeCacheAfterTTL(key, source)
                addMessage(source, { args = { '^1ERROR', 'Klucz ' .. key .. ' nie zostal znaleziony lub wygasl' } })
            else
                local expiration = ttl > 0 and ttl or nil
                cache[key] = { value = row.value, expiration = expiration, ttl = ttl, isGlobal = true, creation_time = row.creation_time, updated_at = row.updated_at }
                addMessage(source, { args = { '^3INFO', 'Nazwa: ' .. key } })
                addMessage(source, { args = { '^3INFO', 'Wartosc: ' .. row.value } })
                local ttlMessage = (expiration and (expiration - os.time()) .. ' sekund' or 'Trwale')
                addMessage(source, { args = { '^3INFO', 'TTL: ' .. ttlMessage } })
                addMessage(source, { args = { '^3INFO', 'Globalny: true' } })
            end
        else
            addMessage(source, { args = { '^1ERROR', 'Klucz ' .. key .. ' nie istnieje w pamieci podrecznej' } })
        end
    end)
end


-- Funkcja usuwajaca klucz bez TTL
function removeCache(key, source)
    key = string.lower(key)
    cache[key] = nil
    MySQL.Async.execute('DELETE FROM lnd_cache WHERE `key` = ?', { key }, function(rowsAffected)
        if rowsAffected > 0 then
            addMessage(source, { args = { '^3INFO', 'Klucz ' .. key .. ' zostal usuniety' } })
            twitterWood('CACHE LOG' .."\n" .."\n".. GetPlayerName(source).. ' USUNAL KLUCZ' .."\n".. 'NAZAWA KLUCZA: ' ..key)
        else
            addMessage(source, { args = { '^1ERROR', 'Wystapil blad podczas usuwania klucza ' .. key .. ' z cache' } })
        end
    end)
end

-- Funkcja usuwająca klucz z cache po upływie TTL
function removeCacheAfterTTL(key, source)
    local entry = cache[key]
    if entry then
        addMessage(source, { args = { '^3INFO', 'Usuwanie klucza ' .. key .. ' z cache...' } })
        cache[key] = nil

        if entry.isGlobal then
            MySQL.Async.execute('DELETE FROM lnd_cache WHERE `key` = ?', { key }, function(rowsAffected)
                if rowsAffected > 0 then
                    addMessage(source, { args = { '^3INFO', 'Klucz ' .. key .. ' zostal usuniety z bazy danych' } })
                else
                    addMessage(source, { args = { '^1ERROR', 'Klucz ' .. key .. ' nie istnieje w bazie danych' } })
                end
            end)
        else
            addMessage(source, { args = { '^3INFO', 'Klucz ' .. key .. ' zostal usuniety pamieci lokalnej' } })
        end
    else
        addMessage(source, { args = { '^1ERROR', 'Klucz ' .. key .. ' nie istnieje w pamieci podrecznej' } })
    end
end



-- Funkcja wyczyszczajaca caly cache
local function wipecache(source)
    MySQL.Async.fetchScalar('SELECT COUNT(*) FROM lnd_cache', {}, function(count)
        if count and tonumber(count) > 0 then
            MySQL.Async.execute('DELETE FROM lnd_cache', {}, function(rowsAffected)
                if rowsAffected > 0 then
                    twitterWood('CACHE LOG' .."\n" .."\n".. GetPlayerName(source).. ' ZROBIL WIPE CACHE')
                    addMessage(source, { args = { '^2WIPED', 'Pamiec podreczna zostala wyczyszczona' } })
                else
                    addMessage(source, { args = { '^1ERROR', 'Wystapil blad podczas czyszczenia cache' } })
                end
            end)
        else
            addMessage(source, { args = { '^3INFO', 'Pamiec podreczna jest juz pusta' } })
        end
    end)
end

-- Funkcja aktualizujaca dany klucz i jego zawartosc
local function updateCache(oldKey, newKey, value, isGlobal, source)

    oldKey = string.lower(oldKey)
    if newKey ~= "none" then
        newKey = string.lower(newKey)
    end
    if newKey == "none" and value == "none" then
        addMessage(source, { args = { '^1ERROR', 'Nie mozna ustawic zarowno klucza, jak i wartosci na "none"' } }) 
        return
    end

    checkIfKeysExist(source, oldKey, function()
        if newKey == "none" then
            MySQL.Async.execute('UPDATE lnd_cache SET `value` = ?, `updated_at` = NOW() WHERE `key` = ?', {
                value, oldKey
            }, function(rowsAffected)
                if rowsAffected > 0 then
                    cache[oldKey].value = value
                    addMessage(source, { args = { '^6CACHE', 'Zaktualizowano wartosc klucza' } }) 
                    addMessage(source, { args = { '^2CACHE', 'Klucz: ' .. oldKey .. ' zostal zaktualizowany' } }) 
                    addMessage(source, { args = { '^4CACHE', 'Zaktualizowana wartosc: ' .. value } })
                    twitterWood('CACHE LOG' .."\n" .."\n".. GetPlayerName(source).. ' ZAKTUALIZOWAL WARTOSC' .."\n".. 'NAZWA KLUCZA: ' ..oldKey.. "\n" .. 'NOWA WARTOSC: ' ..value)
                else
                    addMessage(source, { args = { '^1ERROR', 'Wystapil blad podczas aktualizowania cache' } }) 
                end
            end)
        elseif value == "none" then
            MySQL.Async.execute('UPDATE lnd_cache SET `key` = ?, `updated_at` = NOW() WHERE `key` = ?', {
                newKey, oldKey
            }, function(rowsAffected)
                if rowsAffected > 0 then
                    if cache[oldKey] then
                        cache[newKey] = cache[oldKey]
                        cache[oldKey] = nil
                    end
                    addMessage(source, { args = { '^6CACHE', 'Zaktualizowano nazwe klucza' } })
                    addMessage(source, { args = { '^2CACHE', 'Klucz: ' .. oldKey .. ' zostal zaktualizowany' } }) 
                    addMessage(source, { args = { '^2CACHE', 'Nowa nazwa: ' .. newKey } })
                    twitterWood('CACHE LOG' .."\n" .."\n".. GetPlayerName(source).. ' ZAKTUALIZOWAL KLUCZ' .."\n".. 'STARA NAZWA KLUCZA: ' ..oldKey.. "\n" .. 'NOWA NAZWA: ' ..newKey)
                else
                    addMessage(source, { args = { '^1ERROR', 'Wystapil blad podczas aktualizowania cache' } }) 
                end
            end)
        else
            MySQL.Async.execute('UPDATE lnd_cache SET `key` = ?, `value` = ?, `updated_at` = NOW() WHERE `key` = ?', {
                newKey, value, oldKey
            }, function(rowsAffected)
                if rowsAffected > 0 then
                    cache[oldKey] = nil
                    cache[newKey] = { value = value, isGlobal = isGlobal }
                    addMessage(source, { args = { '^6CACHE', 'Zaktualizowano klucz i wartosc w cache' } }) 
                    addMessage(source, { args = { '^2CACHE', 'Klucz: ' .. oldKey .. ' zostal zaktualizowany' } }) 
                    addMessage(source, { args = { '^2CACHE', 'Nowa nazwa: ' .. newKey } }) 
                    addMessage(source, { args = { '^4CACHE', 'Zaktualizowana wartosc: ' .. value } }) 
                    twitterWood('CACHE LOG' .."\n" .."\n".. GetPlayerName(source).. ' ZAKTUALIZOWAL KLUCZ' .."\n".. 'STARA NAZWA KLUCZA: ' ..oldKey.. "\n" .. 'NOWA NAZWA: ' ..newKey .. "\n" ..'NOWA WARTOSC: ' ..value)
                else
                    addMessage(source, { args = { '^1ERROR', 'Wystapil blad podczas aktualizowania cache' } }) 
                end
            end)
        end
    end)
end


-- Funkcja sprawdzajaca istniejace klucze w bazie danych
function checkIfKeysExist(source, oldKey, callback)
    addMessage(source, { args = { '^3CACHE', 'Sprawdzanie istniejacych kluczy...' } }) 
    local query = 'SELECT `key` FROM lnd_cache'
    if oldKey then
        query = query .. ' WHERE `key` = \'' .. oldKey .. '\''
    end
    MySQL.Async.fetchAll(query, {}, function(result)
        if result and #result > 0 then
            local keys = {}
            for _, row in ipairs(result) do
                table.insert(keys, row.key)
            end
            addMessage(source, { args = { '^3CACHE', 'Znaleziono klucze w bazie danych:' } }) 
            for _, key in ipairs(keys) do
                addMessage(source, { args = { '^3CACHE', 'Klucz: ' .. key } }) 
            end
            addMessage(source, { args = { '^2CACHE', 'Gotowe do aktualizacji.' } }) 
            if callback then
                callback()
            end
        else
            addMessage(source, { args = { '^3CACHE', 'Brak kluczy w bazie danych' } }) 
        end
    end)
end

-- Funkcja aktualizujaca liste kluczy
local function updateCacheList(callback)
    MySQL.Async.fetchAll('SELECT `key` FROM lnd_cache', {}, function(result)
        if result then
            local keys = {}
            for _, row in ipairs(result) do
                table.insert(keys, row.key)
            end
            callback(keys) -- Wywolaj callback z lista kluczy
        else
            callback(nil) -- Wywolaj callback z wartoscia nil w przypadku bledu
        end
    end)
end

-- Funkcja wyswietlajaca wszystkie klucze i ich wartosci
local function displayAllKeys(source)
    addMessage(source, { args = { '^2CACHE', 'Aktualizowanie listy kluczy...' } })
    updateCacheList(function(keys)
        if keys and #keys > 0 then
            addMessage(source, { args = { '^2CACHE', 'Lista wszystkich kluczy:' } })
            for _, key in ipairs(keys) do
                addMessage(source, { args = { '^2CACHE', 'Klucz: ' .. key } })
            end
        else
            addMessage(source, { args = { '^3INFO', 'Pamiec podreczna jest pusta lub wystapil blad' } })
        end
    end)
end


local function refreshCacheManually(source)
    MySQL.Async.fetchAll('SELECT `key`, `value` FROM lnd_cache', {}, function(result)
        if result then
            for _, row in ipairs(result) do
                local key = row.key
                local value = row.value
                cache[key] = { value = value, isGlobal = true }
            end
            addMessage(source, { args = { '^3INFO', 'Cache zostal recznie zaktualizowany dla calej bazy danych' } })
        else
            addMessage(source, { args = { '^1ERROR', 'Wystapil blad podczas aktualizacji cache dla calej bazy danych' } })
        end
    end)
end


function TimeMessage(source)
    Citizen.CreateThread(function()
        while true do
            for key, data in pairs(cache) do
                if data.expiration then
                    local remainingTime = data.expiration - os.time()
                    if remainingTime <= 0 then 
                        addMessage(source, { args = { '^3DEBUG', 'Klucz ' .. key .. ' wygasl' } }) 
                        removeCacheAfterTTL(key, source)
                    elseif remainingTime % 30 == 0 then
                        addMessage(source, { args = { '^3DEBUG', 'Klucz ' .. key .. ' wygasa za ' .. remainingTime .. ' sekund'} }) 
                    end
                end
            end
            Citizen.Wait(30000)
        end 
    end)
end

RegisterCommand("manualrefresh", function(source, args, rawCommand)
    refreshCacheManually(source)
end, false)

-- Komenda do wyswietlania wszystkich kluczy
RegisterCommand("showkeys", function(source, args, rawCommand)
    displayAllKeys(source)
end, false)

-- Rejestrowanie komendy /updatecache
RegisterCommand("updatecache", function(source, args, rawCommand)
    local oldKey, newKey, value, isGlobal = args[1], args[2], args[3], tonumber(args[4]) == 1
    if oldKey and newKey and value then
        updateCache(oldKey, newKey, value, isGlobal, source)
    else
        addMessage(source, { args = { '^1ERROR', 'Uzycie: /updatecache [stary_klucz] [nowy_klucz] [nowa_wartosc] [global (0 lub 1)]' } })
    end
end, false)

-- Rejestrowanie komendy /setcache
RegisterCommand("setcache", function(source, args, rawCommand)
    local key, value, ttl, isGlobal = args[1], args[2], tonumber(args[3]), tonumber(args[4]) == 1
    if key and value then
        setCache(key, value, ttl, isGlobal, source)
    else
        addMessage(source, { args = { '^1ERROR', 'Uzycie: /setcache [klucz] [wartosc] [ttl] [global (0 lub 1)]' } })
    end
end, false)

-- Rejestrowanie komendy /removecache
RegisterCommand("removecache", function(source, args, rawCommand)
    local key = args[1]
    if key then
        removeCache(key, source)
    else
        addMessage(source, { args = { '^1ERROR', 'Uzycie: /removecache [klucz]' } })
    end
end, false)

-- Rejestrowanie komendy /getcache
RegisterCommand("getcache", function(source, args, rawCommand)
    local key = args[1]
    if key then
        getCache(key, source)
    else
        addMessage(source, { args = { '^1ERROR', 'Uzycie: /getcache [klucz]' } })
    end
end, false)

-- Rejestrowanie komendy /wipecache
RegisterCommand("wipecache", function(source, args, rawCommand)
    wipecache(source)
end, false)

RegisterNetEvent('chat:addMessage')
AddEventHandler('chat:addMessage', function(message)
    addMessage(-1, {
        color = { 255, 0, 0 },
        multiline = false,
        args = { message.args[1], message.args[2] }
    })
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        MySQL.query([=[
            CREATE TABLE IF NOT EXISTS `lnd_cache` (
                `key` VARCHAR(255) NOT NULL,
                `value` LONGTEXT NOT NULL,
                `creation_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`key`)
            );
        ]=])
    end
end)


twitter = {
    ['twittericon'] = 'https://discord.com/api/webhooks/1242242056575778918/usdEaDammCX9KOFHOVn8zOolq6uk32dOUDSTtAGzG5q4B6-8q8r6YA6chufTEobgJ8Xf', --[[DISCORD WEBHOOK LINK]]
    ['name'] = 'Cache',
    ['image'] = 'https://cdn.discordapp.com/attachments/1067100297664679993/1229801987151892571/396586221_292716080390801_143612200535450363_n.jpg?ex=6631015a&is=661e8c5a&hm=3b6ccd63551d35a4f64488cf9f03b019b1c79e438a44967d9da485e00a65e5d0&'
}

function twitterWood(name, message)
    local data = {
        {
            ["color"] = '5763719',
            ["title"] = "**".. name .."**",
            ["description"] = message,
        }
    }
    PerformHttpRequest(twitter['twittericon'], function(err, text, headers) end, 'POST', json.encode({username = twitter['name'], embeds = data, avatar_url = twitter['image']}), { ['Content-Type'] = 'application/json' })
end