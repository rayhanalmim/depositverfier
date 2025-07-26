// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/EthereumVerifier.sol";
import "../src/BscVerifier.sol";
import "../src/SolanaVerifier.sol";
import "../src/DepositHelper.sol";

contract VerifierTest is Test {
    EthereumVerifier ethVerifier;
    BscVerifier bscVerifier;
    SolanaVerifier solVerifier;
    DepositHelper depositHelper;
    
    address owner = address(0x1);
    address oracleAddress = address(0x2);
    address user = address(0x3);
    
    address usdtEth = address(0x4);
    address usdtBsc = address(0x5);
    address usdtSol = address(0x6);
    
    address depositAddressEth = address(0x7);
    address depositAddressBsc = address(0x8);
    address depositAddressSol = address(0x9);
    
    function setUp() public {
        // Deploy contracts
        vm.startPrank(owner);
        
        ethVerifier = new EthereumVerifier();
        bscVerifier = new BscVerifier();
        solVerifier = new SolanaVerifier();
        
        depositHelper = new DepositHelper(
            usdtEth, depositAddressEth,
            usdtBsc, depositAddressBsc,
            usdtSol, depositAddressSol
        );
        
        // Set verifiers in deposit helper
        depositHelper.setVerifiers(
            address(ethVerifier),
            address(bscVerifier),
            address(solVerifier)
        );
        
        // Set oracle addresses
        ethVerifier.setOracleAddress(oracleAddress);
        bscVerifier.setOracleAddress(oracleAddress);
        solVerifier.setOracleAddress(oracleAddress);
        
        vm.stopPrank();
    }
    
    function testEthereumVerifierSetup() public {
        // Test that the owner is set correctly
        vm.prank(owner);
        ethVerifier.transferOwnership(user);
        
        // Try to set oracle address as non-owner (should fail)
        vm.expectRevert("Only owner can call this function");
        ethVerifier.setOracleAddress(address(0x10));
        
        // Try to set oracle address as owner
        vm.prank(user);
        ethVerifier.setOracleAddress(address(0x10));
    }
    
    function testBscVerifierSetup() public {
        // Test that the owner is set correctly
        vm.prank(owner);
        bscVerifier.transferOwnership(user);
        
        // Try to set oracle address as non-owner (should fail)
        vm.expectRevert("Only owner can call this function");
        bscVerifier.setOracleAddress(address(0x10));
        
        // Try to set oracle address as owner
        vm.prank(user);
        bscVerifier.setOracleAddress(address(0x10));
    }
    
    function testSolanaVerifierSetup() public {
        // Test that the owner is set correctly
        vm.prank(owner);
        solVerifier.transferOwnership(user);
        
        // Try to set oracle address as non-owner (should fail)
        vm.expectRevert("Only owner can call this function");
        solVerifier.setOracleAddress(address(0x10));
        
        // Try to set oracle address as owner
        vm.prank(user);
        solVerifier.setOracleAddress(address(0x10));
    }
    
    function testEthereumVerification() public {
        bytes32 txHash = keccak256(abi.encodePacked("test_eth_tx"));
        address from = address(0x100);
        address to = depositAddressEth;
        uint256 value = 0;
        bool success = true;
        address token = usdtEth;
        uint256 amount = 100 * 10**6; // 100 USDT with 6 decimals
        
        // Add transaction receipt as oracle
        vm.prank(oracleAddress);
        ethVerifier.addTransactionReceipt(
            txHash,
            from,
            to,
            value,
            success,
            token,
            amount
        );
        
        // Verify the transaction using the deposit helper
        vm.prank(owner);
        bool verified = depositHelper.verifyDeposit(txHash, amount, DepositHelper.Network.ETHEREUM);
        
        // Check that the verification was successful
        assertTrue(verified);
        
        // Check that the transaction is marked as verified
        assertTrue(depositHelper.verifiedTransactions(txHash));
    }
    
    function testBscVerification() public {
        bytes32 txHash = keccak256(abi.encodePacked("test_bsc_tx"));
        address from = address(0x100);
        address to = depositAddressBsc;
        uint256 value = 0;
        uint256 blockNumber = 1000;
        uint256 timestamp = block.timestamp;
        bool success = true;
        address token = usdtBsc;
        uint256 amount = 100 * 10**6; // 100 USDT with 6 decimals
        
        // Add transaction receipt as oracle
        vm.prank(oracleAddress);
        bscVerifier.addTransactionReceipt(
            txHash,
            from,
            to,
            value,
            blockNumber,
            timestamp,
            success,
            token,
            amount
        );
        
        // Verify the transaction using the deposit helper
        vm.prank(owner);
        bool verified = depositHelper.verifyDeposit(txHash, amount, DepositHelper.Network.BSC);
        
        // Check that the verification was successful
        assertTrue(verified);
        
        // Check that the transaction is marked as verified
        assertTrue(depositHelper.verifiedTransactions(txHash));
    }
    
    function testSolanaVerification() public {
        bytes32 txHash = keccak256(abi.encodePacked("test_sol_tx"));
        bytes32 signature = keccak256(abi.encodePacked("sol_signature"));
        bytes32 sourceAccount = keccak256(abi.encodePacked("source_account"));
        bytes32 destinationAccount = keccak256(abi.encodePacked("destination_account"));
        bytes32 mint = keccak256(abi.encodePacked("usdt_mint"));
        uint64 amount = 100_000_000; // 100 USDT with 6 decimals
        uint64 slot = 1000;
        uint64 timestamp = uint64(block.timestamp);
        bool success = true;
        
        // Map the Solana mint to Ethereum USDT address
        vm.prank(owner);
        solVerifier.addTokenMapping(mint, usdtSol);
        
        // Map the Solana destination account to Ethereum deposit address
        vm.prank(owner);
        solVerifier.addAddressMapping(destinationAccount, depositAddressSol);
        
        // Add transaction as oracle
        vm.prank(oracleAddress);
        solVerifier.addSolanaTransaction(
            txHash,
            signature,
            sourceAccount,
            destinationAccount,
            mint,
            amount,
            slot,
            timestamp,
            success
        );
        
        // Verify the transaction using the deposit helper
        vm.prank(owner);
        bool verified = depositHelper.verifyDeposit(txHash, amount * 10**12, DepositHelper.Network.SOLANA);
        
        // Check that the verification was successful
        assertTrue(verified);
        
        // Check that the transaction is marked as verified
        assertTrue(depositHelper.verifiedTransactions(txHash));
    }
    
    function testFailedVerification() public {
        bytes32 txHash = keccak256(abi.encodePacked("test_failed_tx"));
        
        // Try to verify a non-existent transaction
        vm.prank(owner);
        vm.expectRevert("Transaction verification failed");
        depositHelper.verifyDeposit(txHash, 100 * 10**6, DepositHelper.Network.ETHEREUM);
    }
    
    function testDoubleVerificationPrevention() public {
        bytes32 txHash = keccak256(abi.encodePacked("test_double_tx"));
        address from = address(0x100);
        address to = depositAddressEth;
        uint256 value = 0;
        bool success = true;
        address token = usdtEth;
        uint256 amount = 100 * 10**6; // 100 USDT with 6 decimals
        
        // Add transaction receipt as oracle
        vm.prank(oracleAddress);
        ethVerifier.addTransactionReceipt(
            txHash,
            from,
            to,
            value,
            success,
            token,
            amount
        );
        
        // Verify the transaction
        vm.prank(owner);
        bool verified = depositHelper.verifyDeposit(txHash, amount, DepositHelper.Network.ETHEREUM);
        assertTrue(verified);
        
        // Try to verify the same transaction again
        vm.prank(owner);
        vm.expectRevert("Transaction already verified");
        depositHelper.verifyDeposit(txHash, amount, DepositHelper.Network.ETHEREUM);
    }
} 