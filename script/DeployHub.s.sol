// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import { kOFTAdapter } from "../src/kOFTAdapter.sol";
import { kToken0 } from "../src/kToken0.sol";

import { DeploymentManager } from "./DeploymentManager.s.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { console2 } from "forge-std/Script.sol";

/// @title DeployHub
/// @notice Deploys kToken0 + kOFTAdapter for mainnet (hub) deployment
/// @dev This is used for the mainnet hub where tokens are locked/released via kOFTAdapter
contract DeployHub is DeploymentManager {
    kToken0 public token;
    kOFTAdapter public koftAdapter;

    string public name;
    string public symbol;
    uint8 public decimals;

    function run() public {
        // Read network configuration
        NetworkConfig memory config = readNetworkConfig();
        validateConfig(config);
        logConfig(config);

        // Token configuration
        name = "kUSD Token";
        symbol = "kUSD";
        decimals = 6; // USDC decimals

        vm.startBroadcast();

        // Check if we should use existing kToken or deploy new one
        if (config.existingKToken != address(0)) {
            // Use existing kToken
            console2.log("=== Using Existing kToken (Hub) ===");
            token = kToken0(config.existingKToken);
            console2.log("Using existing kToken at:", address(token));
        } else {
            // Deploy new kToken0
            console2.log("=== Deploying kToken0 (Hub) ===");
            token = new kToken0(
                config.roles.owner,
                config.roles.admin,
                config.roles.emergencyAdmin,
                msg.sender, // temporary kOFT
                name,
                symbol,
                decimals
            );
            console2.log("kToken0 deployed at:", address(token));
        }

        // Step 2: Deploy kOFTAdapter (Hub uses adapter for locking/releasing)
        console2.log("=== Deploying kOFTAdapter (Hub) ===");
        kOFTAdapter adapterImplementation = new kOFTAdapter(address(token), config.layerZero.lzEndpoint);
        bytes memory adapterData = abi.encodeWithSelector(kOFTAdapter.initialize.selector, config.roles.owner);
        ERC1967Proxy adapterProxy = new ERC1967Proxy(address(adapterImplementation), adapterData);
        koftAdapter = kOFTAdapter(address(adapterProxy));
        console2.log("kOFTAdapter implementation:", address(adapterImplementation));
        console2.log("kOFTAdapter proxy deployed at:", address(koftAdapter));

        // Step 3: Grant kOFTAdapter the MINTER_ROLE on kToken0
        console2.log("=== Granting MINTER_ROLE to kOFTAdapter ===");
        token.grantMinterRole(address(koftAdapter));
        console2.log("kOFTAdapter granted MINTER_ROLE on kToken0");

        // Step 4: Remove MINTER_ROLE from owner for security
        try token.revokeMinterRole(config.roles.owner) {
            console2.log("Removed MINTER_ROLE from owner");
        } catch {
            console2.log("Owner did not have MINTER_ROLE or revocation failed");
        }

        // Write all deployment addresses
        writeContractAddress("kToken0", address(token));
        writeContractAddress("kOFTAdapter", address(koftAdapter));
        writeContractAddress("kOFTAdapterImplementation", address(adapterImplementation));

        // Summary
        console2.log("=== Hub Deployment Summary ===");
        console2.log("Network: Hub (Mainnet)");
        if (config.existingKToken != address(0)) {
            console2.log("kToken0: (existing)", address(token));
        } else {
            console2.log("kToken0: (new)", address(token));
        }
        console2.log("kOFTAdapter:", address(koftAdapter));
        console2.log("LayerZero Endpoint:", config.layerZero.lzEndpoint);
        console2.log("LayerZero EID:", config.layerZero.lzEid);
        console2.log("Owner:", config.roles.owner);
        console2.log("Admin:", config.roles.admin);
        console2.log("Emergency Admin:", config.roles.emergencyAdmin);
        console2.log("Architecture: Hub - Tokens locked/released via kOFTAdapter");

        vm.stopBroadcast();
    }
}
