// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { kOFTAdapter } from "../../src/kOFTAdapter.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract kOFTAdapterMock is kOFTAdapter {
    address public minter;

    modifier onlyMinter() {
        require(msg.sender == minter, "Not minter");
        _;
    }

    constructor(address lzEndpoint_, uint8 decimals_) kOFTAdapter(lzEndpoint_, decimals_) {
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

    function getkOFTAdapterStorage() external view returns (IERC20) {
        // keccak256(abi.encode(uint256(keccak256("kToken.storage.kOFTAdapter")) - 1)) & ~bytes32(uint256(0xff))
        bytes32 location = 0xc3cb0ef2eb152f0b1a817a5752040bce18ae72a8f914bcbf52be9c234c7ca300;
        IERC20 tokenContract;
        assembly {
            tokenContract := sload(location)
        }
        return tokenContract;
    }
}
