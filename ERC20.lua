-- ERC20 Extension for MoneyMoney
-- Fetches all token balances from a given list of ETH addresses (using Etherscan)
--
-- Username: ETH addresses (comma seperated)
-- Password: Etherscan API Key

-- MIT License

-- Copyright (c) 2018 aaronk6

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
  version = 1.03,
  description = "Include your ERC20 token balances in MoneyMoney by providing your ETH addresses (in the username field, comma seperated) and your Etherscan API Key (in the password field)",
  url = "https://api.etherscan.io/api",
  services = { "ERC20 Tokens" }
}

local ethAddresses
local etherscanApiKey
local connection = Connection()
local currency = "EUR" -- fixme: make dynamik if MM enables input field

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "ERC20 Tokens"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
  ethAddresses = username:gsub("%s+", "")
  etherscanApiKey = password
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
  local tokenInfos = {}

  for address in string.gmatch(ethAddresses, '([^,]+)') do
    for _, contract in ipairs(requestContractAddressesForEthAddress(address)) do

      if (tokenInfos[contract] == nil) then
        tokenInfos[contract] = requestTokenInfo(contract)
      end

      if tokenInfos[contract] ~= nil then
        local info = tokenInfos[contract]
        local quantity = requestTokenBalance(address, contract) / info["divisor"]

        s[#s+1] = {
          name = info["name"] .. " · " .. address:lower(),
          currency = nil,
          market = "Etherscan",
          quantity = quantity,
          price = info["price"] * currencyPrice
        }
      end
    end
  end

  return {securities = s}
end

function EndSession ()
end

function queryAPI(params)

  params["apikey"] = etherscanApiKey

  local connection = Connection()
  local content = connection:request("GET", url .. '?' .. httpBuildQuery(params))

  return JSON(content):dictionary()["result"]
end

function requestContractAddressesForEthAddress(ethAddress)

  -- No API method for this (as of Mar 11, 2018), therefore using web scraping

  local connection = Connection()
  local html = HTML(connection:get("https://etherscan.io/address/" .. ethAddress))
  local elements = html:xpath("//ul[@id='balancelist']/li/a")
  local addresses = {}

  elements:each(function (index, element)
    local href = element:attr('href')
    local address = string.match(href, "^%/token%/(0x[0-9a-fA-F]+)")
    table.insert(addresses, address)
  end)

  return addresses
end

function requestTokenInfo(contractAddress)

  -- No API method for this (as of Mar 11, 2018), therefore using web scraping

  local connection = Connection()
  local html = HTML(connection:get("https://etherscan.io/token/" .. contractAddress))
  local name = html:xpath("//*[@id='address']"):text()
  local summary = html:xpath("//*[@id='ContentPlaceHolder1_divSummary']"):text()
  local decimals = tonumber(string.match(summary, "Decimals:%s+([%d,]+)"))
  local price_fmt = string.match(summary, "Price:%s+([^%s]+)")

  -- If the price is unknown, we'll ignore the token
  if price_fmt == nil or price_fmt == "-" then return nil end

  return {
    name = name,
    price = tonumber(string.match(price_fmt, "$([%d,.]+)")),
    divisor = math.pow(10, decimals)
  }
end

function requestTokenBalance(address, contract)
  return queryAPI({
    module = "account",
    action = "tokenbalance",
    address = address,
    contractaddress = contract
  })
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

function httpBuildQuery(params)
  local str = ''
  for key, value in pairs(params) do
    str = str .. key .. "=" .. value .. "&"
  end
  return str.sub(str, 1, -2)
end

-- http://lua-users.org/wiki/SimpleRound
function round(num, places)
  local mult = 10^(places or 0)
  return math.floor(num * mult + 0.5) / mult
end
