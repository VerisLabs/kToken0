// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";

/// @title DeploymentManager
/// @notice Utility for managing JSON-based deployment configurations and outputs for kToken project
/// @dev Handles reading network configs and writing deployment addresses
abstract contract DeploymentManager is Script {
    using stdJson for string;

    struct NetworkConfig {
        string network;
        uint256 chainId;
        string deploymentType; // "hub" or "spoke"
        address existingKToken; // For mainnet hub deployments
        RoleAddresses roles;
        LayerZeroConfig layerZero;
    }

    struct RoleAddresses {
        address owner;
        address admin;
        address emergencyAdmin;
    }

    struct LayerZeroConfig {
        address lzEndpoint;
        uint16 lzEid;
    }

    struct DeploymentOutput {
        uint256 chainId;
        string network;
        uint256 timestamp;
        ContractAddresses contracts;
    }

    struct ContractAddresses {
        address kToken0;
        address kOFT;
        address kOFTAdapter;
        address kOFTImplementation;
        address kOFTAdapterImplementation;
    }

    /// @notice Gets the current network name from foundry context
    /// @return network Network name (mainnet, sepolia, localhost, etc.)
    function getCurrentNetwork() internal view returns (string memory) {
        uint256 chainId = block.chainid;

        if (chainId == 1) return "mainnet";
        if (chainId == 11_155_111) return "sepolia";
        if (chainId == 31_337) return "localhost";
        if (chainId == 137) return "polygon";
        if (chainId == 42_161) return "arbitrum";
        if (chainId == 10) return "optimism";
        if (chainId == 56) return "bsc";
        if (chainId == 250) return "fantom";
        if (chainId == 43114) return "avalanche";

        // Fallback to localhost for unknown chains
        return "localhost";
    }

    function isProduction() internal view returns (bool) {
        bool isProd = vm.envOr("PRODUCTION", false);
        return isProd;
    }

    /// @notice Reads network configuration from JSON file
    /// @return config Network configuration struct
    function readNetworkConfig() internal view returns (NetworkConfig memory config) {
        string memory network = getCurrentNetwork();
        string memory configPath = string.concat("deployments/config/", network, ".json");

        require(vm.exists(configPath), string.concat("Config file not found: ", configPath));

        string memory json = vm.readFile(configPath);

        config.network = json.readString(".network");
        config.chainId = json.readUint(".chainId");
        config.deploymentType = json.readString(".deploymentType");

        // Read existing kToken (for hub deployments)
        // Default to address(0) if not specified
        config.existingKToken = address(0);

        // Parse role addresses
        config.roles.owner = json.readAddress(".roles.owner");
        config.roles.admin = json.readAddress(".roles.admin");
        config.roles.emergencyAdmin = json.readAddress(".roles.emergencyAdmin");

        // Parse LayerZero config
        config.layerZero.lzEndpoint = json.readAddress(".layerZero.lzEndpoint");
        config.layerZero.lzEid = uint16(json.readUint(".layerZero.lzEid"));

        return config;
    }


    /// @notice Reads existing deployment addresses from output JSON
    /// @return output Deployment output struct with contract addresses
    function readDeploymentOutput() internal view returns (DeploymentOutput memory output) {
        string memory network = getCurrentNetwork();
        string memory outputPath = string.concat("deployments/output/", network, "/addresses.json");

        if (!vm.exists(outputPath)) {
            // Return empty struct if file doesn't exist
            output.network = network;
            output.chainId = block.chainid;
            return output;
        }

        string memory json = vm.readFile(outputPath);

        output.chainId = json.readUint(".chainId");
        output.network = json.readString(".network");
        output.timestamp = json.readUint(".timestamp");

        // Parse contract addresses (check if keys exist before reading)
        if (json.keyExists(".contracts.kToken0")) {
            output.contracts.kToken0 = json.readAddress(".contracts.kToken0");
        }

        if (json.keyExists(".contracts.kOFT")) {
            output.contracts.kOFT = json.readAddress(".contracts.kOFT");
        }

        if (json.keyExists(".contracts.kOFTAdapter")) {
            output.contracts.kOFTAdapter = json.readAddress(".contracts.kOFTAdapter");
        }

        if (json.keyExists(".contracts.kOFTImplementation")) {
            output.contracts.kOFTImplementation = json.readAddress(".contracts.kOFTImplementation");
        }

        if (json.keyExists(".contracts.kOFTAdapterImplementation")) {
            output.contracts.kOFTAdapterImplementation = json.readAddress(".contracts.kOFTAdapterImplementation");
        }

        return output;
    }

    /// @notice Writes a single contract address to deployment output
    /// @param contractName Name of the contract
    /// @param contractAddress Address of the deployed contract
    function writeContractAddress(string memory contractName, address contractAddress) internal {
        string memory network = getCurrentNetwork();
        string memory outputPath = string.concat("deployments/output/", network, "/addresses.json");

        // Read existing output or create new
        DeploymentOutput memory output = readDeploymentOutput();
        output.chainId = block.chainid;
        output.network = network;
        output.timestamp = block.timestamp;

        // Update the specific contract address
        if (keccak256(bytes(contractName)) == keccak256(bytes("kToken0"))) {
            output.contracts.kToken0 = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kOFT"))) {
            output.contracts.kOFT = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kOFTAdapter"))) {
            output.contracts.kOFTAdapter = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kOFTImplementation"))) {
            output.contracts.kOFTImplementation = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kOFTAdapterImplementation"))) {
            output.contracts.kOFTAdapterImplementation = contractAddress;
        }

        // Write to JSON file
        string memory json = _serializeDeploymentOutput(output);
        vm.writeFile(outputPath, json);

        console.log(string.concat(contractName, " address written to: "), outputPath);
    }

    /// @notice Serializes deployment output to JSON string
    /// @param output Deployment output struct
    /// @return JSON string representation
    function _serializeDeploymentOutput(DeploymentOutput memory output) private pure returns (string memory) {
        string memory json = "{";
        json = string.concat(json, '"chainId":', vm.toString(output.chainId), ",");
        json = string.concat(json, '"network":"', output.network, '",');
        json = string.concat(json, '"timestamp":', vm.toString(output.timestamp), ",");
        json = string.concat(json, '"contracts":{');

        json = string.concat(json, '"kToken0":"', vm.toString(output.contracts.kToken0), '",');
        json = string.concat(json, '"kOFT":"', vm.toString(output.contracts.kOFT), '",');
        json = string.concat(json, '"kOFTAdapter":"', vm.toString(output.contracts.kOFTAdapter), '",');
        json = string.concat(json, '"kOFTImplementation":"', vm.toString(output.contracts.kOFTImplementation), '",');
        json = string.concat(json, '"kOFTAdapterImplementation":"', vm.toString(output.contracts.kOFTAdapterImplementation), '"');
        json = string.concat(json, "}}");

        return json;
    }

    /// @notice Validates that required addresses are not zero
    /// @param config Network configuration to validate
    function validateConfig(NetworkConfig memory config) internal pure {
        require(config.roles.owner != address(0), "Missing owner address");
        require(config.roles.admin != address(0), "Missing admin address");
        require(config.roles.emergencyAdmin != address(0), "Missing emergencyAdmin address");
        require(config.layerZero.lzEndpoint != address(0), "Missing LayerZero endpoint address");
        require(config.layerZero.lzEid != 0, "Missing LayerZero EID");
    }

    /// @notice Validates that required deployment outputs are not zero
    /// @param existing Deployment output to validate
    function validateDeployments(DeploymentOutput memory existing) internal pure {
        require(existing.contracts.kToken0 != address(0), "kToken0 not deployed");
        require(existing.contracts.kOFT != address(0), "kOFT not deployed");
        require(existing.contracts.kOFTAdapter != address(0), "kOFTAdapter not deployed");
    }

    /// @notice Logs deployment configuration for verification
    /// @param config Network configuration
    function logConfig(NetworkConfig memory config) internal pure {
        console.log("=== DEPLOYMENT CONFIGURATION ===");
        console.log("Network:", config.network);
        console.log("Chain ID:", config.chainId);
        console.log("Owner:", config.roles.owner);
        console.log("Admin:", config.roles.admin);
        console.log("Emergency Admin:", config.roles.emergencyAdmin);
        console.log("LayerZero Endpoint:", config.layerZero.lzEndpoint);
        console.log("LayerZero EID:", config.layerZero.lzEid);
        console.log("===============================");
    }

    /// @notice Logs deployment output for verification
    /// @param output Deployment output
    function logDeployment(DeploymentOutput memory output) internal pure {
        console.log("=== DEPLOYMENT OUTPUT ===");
        console.log("Network:", output.network);
        console.log("Chain ID:", output.chainId);
        console.log("Timestamp:", output.timestamp);
        console.log("kToken0:", output.contracts.kToken0);
        console.log("kOFT:", output.contracts.kOFT);
        console.log("kOFTAdapter:", output.contracts.kOFTAdapter);
        console.log("kOFT Implementation:", output.contracts.kOFTImplementation);
        console.log("kOFTAdapter Implementation:", output.contracts.kOFTAdapterImplementation);
        console.log("========================");
    }
}
