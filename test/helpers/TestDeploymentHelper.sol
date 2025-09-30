// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { kToken0 } from "../../src/kToken0.sol";
import { kOFT } from "../../src/kOFT.sol";
import { kOFTAdapter } from "../../src/kOFTAdapter.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

/// @title TestDeploymentHelper
/// @notice Helper contract for deploying kToken contracts in tests using our deployment scripts
contract TestDeploymentHelper is Test {
    struct DeploymentResult {
        kToken0 token;
        kOFT koft;
        kOFTAdapter koftAdapter;
        address kOFTImplementation;
        address kOFTAdapterImplementation;
    }

    /// @notice Deploys hub contracts (kToken0 + kOFTAdapter) using our deployment pattern
    /// @param owner The owner address
    /// @param admin The admin address
    /// @param emergencyAdmin The emergency admin address
    /// @param lzEndpoint The LayerZero endpoint address
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param decimals Token decimals
    /// @return result Deployment result with all contract addresses
    function deployHubContracts(
        address owner,
        address admin,
        address emergencyAdmin,
        address lzEndpoint,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public returns (DeploymentResult memory result) {
        // Deploy kToken0 with deployer as temporary kOFT
        result.token = new kToken0(
            owner,
            admin,
            emergencyAdmin,
            address(this), // temporary kOFT
            name,
            symbol,
            decimals
        );

        // Deploy kOFTAdapter
        kOFTAdapter adapterImplementation = new kOFTAdapter(address(result.token), lzEndpoint);
        bytes memory adapterData = abi.encodeWithSelector(kOFTAdapter.initialize.selector, owner);
        ERC1967Proxy adapterProxy = new ERC1967Proxy(address(adapterImplementation), adapterData);
        result.koftAdapter = kOFTAdapter(address(adapterProxy));
        result.kOFTAdapterImplementation = address(adapterImplementation);

        // Grant kOFTAdapter the MINTER_ROLE on kToken0
        vm.prank(owner);
        result.token.grantMinterRole(address(result.koftAdapter));

        // Remove MINTER_ROLE from owner for security
        try result.token.revokeMinterRole(owner) {
            // Successfully removed
        } catch {
            // Owner didn't have MINTER_ROLE or revocation failed
        }
    }

    /// @notice Deploys spoke contracts (kToken0 + kOFT) using our deployment pattern
    /// @param owner The owner address
    /// @param admin The admin address
    /// @param emergencyAdmin The emergency admin address
    /// @param lzEndpoint The LayerZero endpoint address
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param decimals Token decimals
    /// @return result Deployment result with all contract addresses
    function deploySpokeContracts(
        address owner,
        address admin,
        address emergencyAdmin,
        address lzEndpoint,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public returns (DeploymentResult memory result) {
        // Deploy kToken0 with deployer as temporary kOFT
        result.token = new kToken0(
            owner,
            admin,
            emergencyAdmin,
            address(this), // temporary kOFT
            name,
            symbol,
            decimals
        );

        // Deploy kOFT
        kOFT implementation = new kOFT(lzEndpoint, result.token);
        bytes memory data = abi.encodeWithSelector(kOFT.initialize.selector, owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        result.koft = kOFT(address(proxy));
        result.kOFTImplementation = address(implementation);

        // Grant kOFT the MINTER_ROLE on kToken0
        vm.prank(owner);
        result.token.grantMinterRole(address(result.koft));

        // Remove MINTER_ROLE from owner for security
        try result.token.revokeMinterRole(owner) {
            // Successfully removed
        } catch {
            // Owner didn't have MINTER_ROLE or revocation failed
        }
    }

    /// @notice Deploys hub contracts using existing kToken
    /// @param existingToken The existing kToken address
    /// @param owner The owner address
    /// @param lzEndpoint The LayerZero endpoint address
    /// @return result Deployment result with kOFTAdapter
    function deployHubWithExistingToken(
        address existingToken,
        address owner,
        address lzEndpoint
    ) public returns (DeploymentResult memory result) {
        // Use existing kToken
        result.token = kToken0(existingToken);

        // Deploy kOFTAdapter
        kOFTAdapter adapterImplementation = new kOFTAdapter(existingToken, lzEndpoint);
        bytes memory adapterData = abi.encodeWithSelector(kOFTAdapter.initialize.selector, owner);
        ERC1967Proxy adapterProxy = new ERC1967Proxy(address(adapterImplementation), adapterData);
        result.koftAdapter = kOFTAdapter(address(adapterProxy));
        result.kOFTAdapterImplementation = address(adapterImplementation);

        // Grant kOFTAdapter the MINTER_ROLE on existing kToken
        vm.prank(owner);
        result.token.grantMinterRole(address(result.koftAdapter));

        // Remove MINTER_ROLE from owner for security
        try result.token.revokeMinterRole(owner) {
            // Successfully removed
        } catch {
            // Owner didn't have MINTER_ROLE or revocation failed
        }
    }

    /// @notice Sets up cross-chain peers for kOFT contracts
    /// @param localOFT The local kOFT contract
    /// @param remoteOFT The remote kOFT contract
    /// @param localEid The local endpoint ID
    /// @param remoteEid The remote endpoint ID
    function setupKOFTPeers(
        kOFT localOFT,
        kOFT remoteOFT,
        uint32 localEid,
        uint32 remoteEid
    ) public {
        // Set peers
        vm.prank(localOFT.owner());
        localOFT.setPeer(remoteEid, bytes32(uint256(uint160(address(remoteOFT)))));
        
        vm.prank(remoteOFT.owner());
        remoteOFT.setPeer(localEid, bytes32(uint256(uint160(address(localOFT)))));
    }

    /// @notice Sets up cross-chain peers for kOFTAdapter contracts
    /// @param localAdapter The local kOFTAdapter contract
    /// @param remoteAdapter The remote kOFTAdapter contract
    /// @param localEid The local endpoint ID
    /// @param remoteEid The remote endpoint ID
    function setupAdapterPeers(
        kOFTAdapter localAdapter,
        kOFTAdapter remoteAdapter,
        uint32 localEid,
        uint32 remoteEid
    ) public {
        // Set peers
        vm.prank(localAdapter.owner());
        localAdapter.setPeer(remoteEid, bytes32(uint256(uint160(address(remoteAdapter)))));
        
        vm.prank(remoteAdapter.owner());
        remoteAdapter.setPeer(localEid, bytes32(uint256(uint160(address(localAdapter)))));
    }
}
