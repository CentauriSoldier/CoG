local rand = math.random;
local rawtype = rawtype;

local function getAndValidateDiceCount(nDiceCount)
    return  (rawtype(nDice) == "number" and
            nDice > 0 and nDice % 2 == 0) and nDice or 0;
end

local function selectionSort(a, b)
    return a.chance < b.chance
end

local roll = {
    xD2 = function(nDiceCountInput)
        local nRoll = 0;
        local nDiceCount = getAndValidateDiceCount(nDiceCountInput);

        for x = 1, nDiceCount do
            nRoll = nRoll + rand(1, 2);
        end

        return nRoll;
    end,
    xD4 = function(nDiceCountInput)
        local nRoll = 0;
        local nDiceCount = getAndValidateDiceCount(nDiceCountInput);

        for x = 1, nDiceCount do
            nRoll = nRoll + rand(1, 4);
        end

        return nRoll;
    end,
    xD6 = function(nDiceCountInput)
        local nRoll = 0;
        local nDiceCount = getAndValidateDiceCount(nDiceCountInput);

        for x = 1, nDiceCount do
            nRoll = nRoll + rand(1, 6);
        end

        return nRoll;
    end,
    xD8 = function(nDiceCountInput)
        local nRoll = 0;
        local nDiceCount = getAndValidateDiceCount(nDiceCountInput);

        for x = 1, nDiceCount do
            nRoll = nRoll + rand(1, 8);
        end

        return nRoll;
    end,
    xD10 = function(nDiceCountInput)
        local nRoll = 0;
        local nDiceCount = getAndValidateDiceCount(nDiceCountInput);

        for x = 1, nDiceCount do
            nRoll = nRoll + rand(1, 10);
        end

        return nRoll;
    end,
    xD12 = function(nDiceCountInput)
        local nRoll = 0;
        local nDiceCount = getAndValidateDiceCount(nDiceCountInput);

        for x = 1, nDiceCount do
            nRoll = nRoll + rand(1, 12);
        end

        return nRoll;
    end,
    xD20 = function(nDiceCountInput)
        local nRoll = 0;
        local nDiceCount = getAndValidateDiceCount(nDiceCountInput);

        for x = 1, nDiceCount do
            nRoll = nRoll + rand(1, 20);
        end

        return nRoll;
    end,
    xD100 = function(nDiceCountInput)
        local nRoll = 0;
        local nDiceCount = getAndValidateDiceCount(nDiceCountInput);

        for x = 1, nDiceCount do
            nRoll = nRoll + rand(1, 100);
        end

        return nRoll;
    end,
    xDX = function(nSidesInput, nDiceCountInput)
        local nRoll = 0;
        local nDiceCount = getAndValidateDiceCount(nDiceCountInput);
        local nSides = (rawtype(nSidesInput) == "number" and nSidesInput > 0 and nSidesInput % 2 == 0)
                        and nSidesInput or 2;

        for x = 1, nDiceCount do
            nRoll = nRoll + rand(1, nSides);
        end

        return nRoll;
    end,
    percentage = function(nSuccess)
        return math.random(1, 100) <= nSuccess;
    end,
    --this takes a table with numeric indices and whose numeric values add to x
    selection = function(tInput)
        local nRet              = -1;
        local nTotalValue       = 0;
        local nCumulativeValues = 0;

        -- Create a table to store the indexed chances and get the total value
       local tIndexedChances = {};
       for nIndex, nChance in ipairs(tInput) do
           nTotalValue = nTotalValue + nChance;
           table.insert(tIndexedChances, { index = nIndex, chance = nChance });
       end

       -- Sort the table based on the chances
       table.sort(tIndexedChances, selectionSort);

        -- Perform the roll and determine the winner
        local nRoll = math.random(1, nTotalValue);

        for _, tItem in ipairs(tIndexedChances) do
            nCumulativeValues = nCumulativeValues + tItem.chance;

            if (nRoll <= nCumulativeValues) then
                nRet = tItem.index;
                break;
            end

        end

       return nRet;
    end,
};


return roll;
