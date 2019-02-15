# ERC20-MoneyMoney

Fetches all available ERC20 balances for one or many ETH addresses from the Ethplorer API and returns them as securities

![MoneyMoney Screenshot with ERC20 extension installed](Screenshot.png)

## Installation

### Download Signed Extension

You can get a signed version of this extension from

* my [GitHub releases](https://github.com/aaronk6/ERC20-MoneyMoney/releases/latest) page, or
* the [MoneyMoney Extensions](https://moneymoney-app.com/extensions/) page

Once downloaded, move `ERC20.lua` to your MoneyMoney Extensions folder.

### Account Setup in MoneyMoney

* Add a new account of type “ERC20”
* Enter one or more ETH addresses
* Enter your Ethplorer API Key

**Note:** You can can use the API key called `freekey` if you don’t have your own, but this will be slow when requesting multiple addresses.

## Known Issues and Limitations

* Always assumes EUR as base currency

