// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { kToken0 } from "../../src/kToken0.sol";
import { kOFT } from "../../src/kOFT.sol";
import { kOFTAdapter } from "../../src/kOFTAdapter.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

/// @title DeploymentHelper
/// @notice Helper contract for deploying kToken contracts in tests using the same patterns as deployment scripts
contract DeploymentHelper is Test {
    struct DeploymentResult {
        kToken0 token;
        kOFT koft;
        kOFTAdapter koftAdapter;
        address kOFTImplementation;
        address kOFTAdapterImplementation;
    }

    /// @notice Deploys all kToken contracts using the same pattern as DeployAll.s.sol
    /// @param owner The owner address
    /// @param admin The admin address
    /// @param emergencyAdmin The emergency admin address
    /// @param lzEndpoint The LayerZero endpoint address
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param decimals Token decimals
    /// @return result Deployment result with all contract addresses
    function deployAllContracts(
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
            owner, // temporary kOFT
            name,
            symbol,
            decimals
        );

        // Deploy kOFT implementation
        kOFT implementation = new kOFT(lzEndpoint, result.token);
        result.kOFTImplementation = address(implementation);

        // Deploy kOFT proxy
        bytes memory data = abi.encodeWithSelector(kOFT.initialize.selector, owner);
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        result.koft = kOFT(address(proxy));

        // Grant kOFT the MINTER_ROLE on kToken0 and remove from owner
        result.token.grantMinterRole(address(result.koft));
        
        // Remove MINTER_ROLE from owner (if owner has it)
        try result.token.revokeMinterRole(owner) {
            // Successfully removed
        } catch {
            // Owner did not have MINTER_ROLE or revocation failed
        }

        // Deploy kOFTAdapter implementation
        kOFTAdapter adapterImplementation = new kOFTAdapter(address(result.token), lzEndpoint);
        result.kOFTAdapterImplementation = address(adapterImplementation);

        // Deploy kOFTAdapter proxy
        bytes memory adapterData = abi.encodeWithSelector(kOFTAdapter.initialize.selector, owner);
        ERC1967Proxy adapterProxy = new ERC1967Proxy(address(adapterImplementation), adapterData);
        result.koftAdapter = kOFTAdapter(address(adapterProxy));

        return result;
    }

    /// @notice Deploys only kToken0 contract
    /// @param owner The owner address
    /// @param admin The admin address
    /// @param emergencyAdmin The emergency admin address
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param decimals Token decimals
    /// @return token The deployed kToken0 contract
    function deployKToken0(
        address owner,
        address admin,
        address emergencyAdmin,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public returns (kToken0 token) {
        token = new kToken0(
            owner,
            admin,
            emergencyAdmin,
            address(this), // temporary kOFT
            name,
            symbol,
            decimals
        );
    }

    /// @notice Deploys kOFT contract for an existing kToken0
    /// @param lzEndpoint The LayerZero endpoint address
    /// @param token The existing kToken0 contract
    /// @param owner The owner address
    /// @return koft The deployed kOFT contract
    /// @return implementation The kOFT implementation address
    function deployKOFT(
        address lzEndpoint,
        kToken0 token,
        address owner
    ) public returns (kOFT koft, address implementation) {
        // Deploy kOFT implementation
        implementation = address(new kOFT(lzEndpoint, token));

        // Deploy kOFT proxy
        bytes memory data = abi.encodeWithSelector(kOFT.initialize.selector, owner);
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        koft = kOFT(address(proxy));

        // Grant kOFT the MINTER_ROLE on kToken0
        token.grantMinterRole(address(koft));

        // Remove MINTER_ROLE from owner (if owner has it)
        try token.revokeMinterRole(owner) {
            // Successfully removed
        } catch {
            // Owner did not have MINTER_ROLE or revocation failed
        }
    }

    /// @notice Deploys kOFTAdapter contract for an existing kToken0
    /// @param lzEndpoint The LayerZero endpoint address
    /// @param token The existing kToken0 contract
    /// @param owner The owner address
    /// @return koftAdapter The deployed kOFTAdapter contract
    /// @return implementation The kOFTAdapter implementation address
    function deployKOFTAdapter(
        address lzEndpoint,
        kToken0 token,
        address owner
    ) public returns (kOFTAdapter koftAdapter, address implementation) {
        // Deploy kOFTAdapter implementation
        implementation = address(new kOFTAdapter(address(token), lzEndpoint));

        // Deploy kOFTAdapter proxy
        bytes memory data = abi.encodeWithSelector(kOFTAdapter.initialize.selector, owner);
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        koftAdapter = kOFTAdapter(address(proxy));
    }

    /// @notice Sets up cross-chain peers between two kOFT contracts
    /// @param koft1 First kOFT contract
    /// @param eid1 Endpoint ID for first chain
    /// @param koft2 Second kOFT contract
    /// @param eid2 Endpoint ID for second chain
    function setupKOFTPeers(
        kOFT koft1,
        uint32 eid1,
        kOFT koft2,
        uint32 eid2
    ) public {
        koft1.setPeer(eid2, bytes32(uint256(uint160(address(koft2)))));
        koft2.setPeer(eid1, bytes32(uint256(uint160(address(koft1)))));
    }

    /// @notice Sets up cross-chain peers between two kOFTAdapter contracts
    /// @param adapter1 First kOFTAdapter contract
    /// @param eid1 Endpoint ID for first chain
    /// @param adapter2 Second kOFTAdapter contract
    /// @param eid2 Endpoint ID for second chain
    function setupAdapterPeers(
        kOFTAdapter adapter1,
        uint32 eid1,
        kOFTAdapter adapter2,
        uint32 eid2
    ) public {
        adapter1.setPeer(eid2, bytes32(uint256(uint160(address(adapter2)))));
        adapter2.setPeer(eid1, bytes32(uint256(uint160(address(adapter1)))));
    }
}
