// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IKToken } from "../src/interfaces/IKToken.sol";
import { kOFT } from "../src/kOFT.sol";

contract kOFTV2 is kOFT {
    function version() public pure returns (string memory) {
        return "v2";
    }

    constructor(address lzEndpoint_, uint8 decimals_) kOFT(lzEndpoint_, decimals_) { }
}
