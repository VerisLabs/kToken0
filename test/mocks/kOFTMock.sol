// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IKToken } from "../../src/interfaces/IKToken.sol";
import { kOFT } from "../../src/kOFT.sol";

contract kOFTMock is kOFT {
    address public minter;

    modifier onlyMinter() {
        require(msg.sender == minter, "Not minter");
        _;
    }

    constructor(address lzEndpoint_, uint8 decimals_) kOFT(lzEndpoint_, decimals_) {
        minter = msg.sender;
    }

    function setMinter(address _minter) external {
        require(msg.sender == minter, "Not minter");
        minter = _minter;
    }

    function exposedCredit(address to, uint256 amount, uint32 srcEid) external onlyMinter returns (uint256) {
        return _credit(to, amount, srcEid);
    }

    function exposedDebit(
        address from,
        uint256 amount,
        uint256 minAmount,
        uint32 dstEid
    )
        external
        onlyMinter
        returns (uint256, uint256)
    {
        return _debit(from, amount, minAmount, dstEid);
    }

    function initializeMock(address initialMinter) external reinitializer(2) {
        minter = initialMinter;
    }

    // Expose the storage getter for testing
    function getkOFTStorage() external view returns (IKToken) {
        // keccak256(abi.encode(uint256(keccak256("kToken.storage.kOFT")) - 1)) & ~bytes32(uint256(0xff))
        bytes32 location = 0x587644eb4c3fc73ac10d93e63726f81712536f856733fbd55e29cec63353dd00;
        IKToken tokenContract;
        assembly {
            tokenContract := sload(location)
        }
        return tokenContract;
    }
}
