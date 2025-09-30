// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import { kToken0 } from "../src/kToken0.sol";
import { kOFT } from "../src/kOFT.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { DeploymentManager } from "./DeploymentManager.s.sol";
import { Script, console2 } from "forge-std/Script.sol";

/// @title DeploySpoke
/// @notice Deploys kToken0 + kOFT for spoke chain deployment
/// @dev This is used for spoke chains where tokens are burned/minted via kOFT
contract DeploySpoke is DeploymentManager {
    kToken0 public token;
    kOFT public koft;

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

        // Step 1: Deploy kToken0 with deployer as temporary kOFT
        console2.log("=== Deploying kToken0 (Spoke) ===");
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

        // Step 2: Deploy kOFT (Spoke uses kOFT for burning/minting)
        console2.log("=== Deploying kOFT (Spoke) ===");
        kOFT implementation = new kOFT(config.layerZero.lzEndpoint, token);
        bytes memory data = abi.encodeWithSelector(kOFT.initialize.selector, config.roles.owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        koft = kOFT(address(proxy));
        console2.log("kOFT implementation:", address(implementation));
        console2.log("kOFT proxy deployed at:", address(koft));

        // Step 3: Grant kOFT the MINTER_ROLE on kToken0
        console2.log("=== Granting MINTER_ROLE to kOFT ===");
        token.grantMinterRole(address(koft));
        console2.log("kOFT granted MINTER_ROLE on kToken0");

        // Step 4: Remove MINTER_ROLE from owner for security
        try token.revokeMinterRole(config.roles.owner) {
            console2.log("Removed MINTER_ROLE from owner");
        } catch {
            console2.log("Owner did not have MINTER_ROLE or revocation failed");
        }

        // Write all deployment addresses
        writeContractAddress("kToken0", address(token));
        writeContractAddress("kOFT", address(koft));
        writeContractAddress("kOFTImplementation", address(implementation));

        // Summary
        console2.log("=== Spoke Deployment Summary ===");
        console2.log("Network: Spoke Chain");
        console2.log("kToken0:", address(token));
        console2.log("kOFT:", address(koft));
        console2.log("LayerZero Endpoint:", config.layerZero.lzEndpoint);
        console2.log("LayerZero EID:", config.layerZero.lzEid);
        console2.log("Owner:", config.roles.owner);
        console2.log("Admin:", config.roles.admin);
        console2.log("Emergency Admin:", config.roles.emergencyAdmin);
        console2.log("Architecture: Spoke - Tokens burned/minted via kOFT");

        vm.stopBroadcast();
    }
}
