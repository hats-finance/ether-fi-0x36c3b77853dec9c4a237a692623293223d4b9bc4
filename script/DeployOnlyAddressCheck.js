//const ethers = require('ethers');
const fs = require('fs');
const ethers = require('ethers');
require('dotenv').config();

function print(str) {
  console.log(str)
}

function getContractNames() {
  const contracts = fs.readFileSync('contracts.json',
    { encoding: 'utf8', flag: 'r' });
  var arr = JSON.parse(contracts);
  return arr
}

function getABI(fileName) {
  abiDirectory = "../release/abis"
  const files = fs.readdirSync(abiDirectory)
  var arr = []
  retval = ""
  for (const file of files) {
    if (String(fileName + ".json").toLowerCase() == String(file).toLowerCase()) {
      abi = fs.readFileSync(abiDirectory + "/" + file,
        { encoding: 'utf8', flag: 'r' });
      retval = abi
      break
    }
  }
  return retval
}

async function callMethod(contractAddress, abi, functionName, args, network) {
  let provider = new ethers.providers.EtherscanProvider(network, process.env.ETHERSCAN_API_KEY)
  let contract = new ethers.Contract(contractAddress, abi, provider);
  return await contract[functionName](...args).catch((err) => {
    console.log("ERROR CALLING METHOD " + functionName)
  })
}

function writeConfigFile() {
  contracts = getContractNames()
  jsonConfig = {}

  for (contract of contracts) { //create empty array for each contract
    arr = []
    jsonConfig[contract] = { arr };
  }
  contracts.forEach(contract => {
    abi = getABI(contract)
    abi = JSON.parse(abi)
    methods = []
    for (let i = 0; i < abi.length; i++) {
      method = abi[i]
      if (method["type"] != undefined && method["stateMutability"] != undefined) {
        if (method["type"] == "function" && method["stateMutability"] == "view" &&
          method["inputs"].length == 0 && method["outputs"].length == 1 && method["outputs"][0]["type"] == "address") { //check if returns address
          methodSubstring = ContractSubstring(method["name"], contracts)
          if (methodSubstring != "") {
            methods.push({
              "methodName": method["name"],
              "value": methodSubstring,
              "isReference": true
            })
          }
        }
      }
    }
    jsonConfig[contract] = methods
  })
  const filePath = 'addressConfig.json';
  if (!fs.existsSync(filePath)) {
    fs.writeFileSync(filePath, JSON.stringify(jsonConfig));
  } else {
    console.log('File already exists');
  }
}

function ContractSubstring(method, contracts) {
  for (contract of contracts) {
    if (method.toLowerCase() == contract.toLowerCase()) return contract
  }
  for (contract of contracts) {
    meth = method.toLowerCase()
    con = contract.toLowerCase()
    if (meth.includes(con) || con.includes(meth)) {
      return contract
    }
  }
  return ""
}

async function checkFunctionAddress(network) {
  //read file
  const file = fs.readFileSync('addressConfig.json',
    { encoding: 'utf8', flag: 'r' });
  var contract_Methods = JSON.parse(file);
  contracts = getContractNames()
  contract_address = {}
  addressProvider = ""

  if (network == "homestead") addressProvider = process.env.MAINNET_ADDRESS_PROVIDER
  else if (network == "goerli") addressProvider = process.env.GOERLI_ADDRESS_PROVIDER
  addressProviderABI = getABI("AddressProvider")
  addyProviderFunName = "getContractAddress"

  for (contract of contracts) { //populate map of contract addresses
    var addy = await callMethod(addressProvider, addressProviderABI, addyProviderFunName, [contract], network)
    contract_address[contract] = addy
  }
  for (contract of contracts) {
    methods = contract_Methods[contract]
    for (method of methods) {
      if (method["value"] != "" && method["isReference"] == true) {
        address = await callMethod(contract_address[contract], getABI(contract), method["methodName"], [], network)
        if (address != contract_address[method["value"]]) {
          print("contract:" + contract + " method:" + method["methodName"] + " address:" + address + " correct address:" + contract_address[method["value"]])
        }
      }
    }
  }
}

async function main() {
  const args = process.argv;
  network = "homestead"
  if (args.length > 2) {
    network = args[2]
    console.log(network)
  }
  //writeConfigFile()
  checkFunctionAddress(network)
}

main()
