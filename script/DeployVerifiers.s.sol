// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/EthereumVerifier.sol";
import {BscVerifier} from "../src/BscVerifier.sol";
import {SolanaVerifier} from "../src/SolanaVerifier.sol";
import {DepositHelper} from "../src/DepositHelper.sol";

/**
 * @title DeployVerifiers
 * @notice Script for deploying the blockchain verifier contracts and setting them in the DepositHelper
 */
contract DeployVerifiers is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address depositHelperAddress = vm.envAddress("DEPOSIT_HELPER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the verifier contracts
        EthereumVerifier ethVerifier = new EthereumVerifier();
        console.log("Ethereum Verifier deployed at:", address(ethVerifier));
        
        BscVerifier bscVerifier = new BscVerifier();
        console.log("BSC Verifier deployed at:", address(bscVerifier));
        
        SolanaVerifier solVerifier = new SolanaVerifier();
        console.log("Solana Verifier deployed at:", address(solVerifier));
        
        // Set the verifiers in the DepositHelper
        if (depositHelperAddress != address(0)) {
            DepositHelper depositHelper = DepositHelper(depositHelperAddress);
            depositHelper.setVerifiers(
                address(ethVerifier), 
                address(bscVerifier), 
                address(solVerifier)
            );
            console.log("Verifiers set in DepositHelper contract");
        } else {
            console.log("DEPOSIT_HELPER_ADDRESS not set in environment, skipping verifier setup");
        }
        
        vm.stopBroadcast();
    }
}

/**
 * @title SetOracleAddresses
 * @notice Script for setting oracle addresses for all verifiers
 */
contract SetOracleAddresses is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address oracleAddress = vm.envAddress("ORACLE_ADDRESS");
        address ethVerifierAddress = vm.envAddress("ETH_VERIFIER_ADDRESS");
        address bscVerifierAddress = vm.envAddress("BSC_VERIFIER_ADDRESS");
        address solVerifierAddress = vm.envAddress("SOL_VERIFIER_ADDRESS");
        
        require(oracleAddress != address(0), "Oracle address must be set");
        
        vm.startBroadcast(deployerPrivateKey);
        
        if (ethVerifierAddress != address(0)) {
            EthereumVerifier ethVerifier = EthereumVerifier(ethVerifierAddress);
            ethVerifier.setOracleAddress(oracleAddress);
            console.log("Oracle address set for Ethereum Verifier");
        }
        
        if (bscVerifierAddress != address(0)) {
            BscVerifier bscVerifier = BscVerifier(bscVerifierAddress);
            bscVerifier.setOracleAddress(oracleAddress);
            console.log("Oracle address set for BSC Verifier");
        }
        
        if (solVerifierAddress != address(0)) {
            SolanaVerifier solVerifier = SolanaVerifier(solVerifierAddress);
            solVerifier.setOracleAddress(oracleAddress);
            console.log("Oracle address set for Solana Verifier");
        }
        
        vm.stopBroadcast();
    }
} 