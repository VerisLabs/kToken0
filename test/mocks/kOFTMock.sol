// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

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
}
