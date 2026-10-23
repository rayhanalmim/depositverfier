// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/DepositHelper.sol";

contract DeployDepositHelper is Script {
    function run() external {
        // Private key for deployment - will use the one configured in the environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get USDT token addresses for each network from environment
        address usdtTokenAddressEth = vm.envAddress("USDT_TOKEN_ADDRESS_ETH");
        address usdtTokenAddressBsc = vm.envAddress("USDT_TOKEN_ADDRESS_BSC");
        address usdtTokenAddressSol = vm.envAddress("USDT_TOKEN_ADDRESS_SOL");
        
        // Get USDT deposit addresses for each network from environment
        address usdtDepositAddressEth = vm.envAddress("USDT_DEPOSIT_ADDRESS_ETH");
        address usdtDepositAddressBsc = vm.envAddress("USDT_DEPOSIT_ADDRESS_BSC");
        address usdtDepositAddressSol = vm.envAddress("USDT_DEPOSIT_ADDRESS_SOL");

        // Start broadcast using the deployer's private key
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the DepositHelper contract
        DepositHelper depositHelper = new DepositHelper(
            usdtTokenAddressEth, usdtDepositAddressEth,
            usdtTokenAddressBsc, usdtDepositAddressBsc,
            usdtTokenAddressSol, usdtDepositAddressSol
        );
        
        // Log the deployed contract address
        console.log("DepositHelper deployed at:", address(depositHelper));

        // End broadcast
        vm.stopBroadcast();
    }
} 