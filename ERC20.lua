-- ERC20 Extension for MoneyMoney
-- Fetches all token balances from a given list of ETH addresses (using Ethplorer)
--
-- Username: ETH addresses (comma seperated)
-- Password: (anything, just don't leave it blank)

-- MIT License

-- Copyright (c) 2019 aaronk6

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.


WebBanking{
  version = 1.04,
  description = "Include your ERC20 token balances in MoneyMoney by providing your ETH addresses (comma seperated)",
  url = "https://api.ethplorer.io",
  services = { "ERC20 Tokens" }
}

local ethAddresses
local apiKey = ''
local isFirstApiRequest = true
local freeApiSleep = 6
local connection = Connection()
local currency = "EUR"

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "ERC20 Tokens"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
  ethAddresses = username:gsub("%s+", "")
  apiKey = password
end

function ListAccounts (knownAccounts)

  local account = {
    name = "ERC20",
    accountNumber = "ERC20 Tokens",
    currency = currency,
    portfolio = true,
    type = "AccountTypePortfolio"
  }

  return {account}
end

function RefreshAccount (account, since)

  local s = {}
  local currencyPrice = requestFiatPrice(currency)
  
  for address in string.gmatch(ethAddresses, '([^,]+)') do
    local res = queryAPI('/getAddressInfo/' .. address)

    if res["address"] then
      if res["tokens"] then

        for i, o in ipairs(res["tokens"]) do
          local info = o["tokenInfo"]

          if info["price"] and info["price"]["currency"] == "USD" then
            -- add to list if security
            s[#s+1] = createSecurity(address,
              info["name"], info["symbol"], o["balance"], info["decimals"], info["price"]["rate"], currencyPrice)
          else
            -- token doesn't have a price or price isn't in USD
            if info["price"] and info["symbol"] then
              print("Unexpected currency " .. info["price"]["currency"] .. " for " .. info["symbol"])
            elseif info["symbol"] then
              print("No price for " .. info["symbol"])
            else
              print("Unknown token")
            end
          end
        end

      else
        print("No token balances for address " .. address)
      end
    else
      print("Unexpected response from API")
    end

  end

  return {securities = s}
end

function EndSession ()
end

function createSecurity(address, name, symbol, balance, decimals, price, currencyPrice)

  local description = ""

  if symbol ~= name then
    description = " (" .. name .. ")"
  end
  
  return {
    name = symbol .. description .. " · " .. address:lower(),
    currency = nil,
    market = "Ethplorer",
    quantity = balance / math.pow(10, decimals),
    price = price * currencyPrice
  }
end

function queryAPI(route)

  if not isFirstApiRequest and apiKey == 'freekey' then
    -- see https://github.com/EverexIO/Ethplorer/wiki/Ethplorer-API
    print("Sleeping " .. freeApiSleep .. " seconds to avoid free API key rate limit")
    sleep(freeApiSleep)
  end

  local connection = Connection()
  local content = connection:request("GET", url .. route .. '?apiKey=' .. apiKey)

  isFirstApiRequest = false

  return JSON(content):dictionary()
end

function requestFiatPrice(symbol)
  local baseCurrency = 'USD'
  local connection = Connection()
  local xml

  if symbol == "EUR" then
    xml = connection:request("GET", "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")
    res = string.match(xml, "<Cube currency='" .. baseCurrency .. "' rate='([^']+)")
    value = round(1 / tonumber(res), 4)
  else
    error("Currency " .. symbol .. " is not supported")
  end

  print("1 " .. baseCurrency .. " = " .. value .. " " .. symbol)
  return value
end

function round(num, places)
  local mult = 10^(places or 0)
  return math.floor(num * mult + 0.5) / mult
end

function sleep(s)
  local ntime = os.time() + s
  repeat until os.time() > ntime
end
