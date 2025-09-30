// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { kOFT } from "../src/kOFT.sol";
import { kToken0 } from "../src/kToken0.sol";
import { IkToken } from "../src/vendor/KAM/interfaces/IkToken.sol";

contract kOFTV2 is kOFT {
    function version() public pure returns (string memory) {
        return "v2";
    }

    constructor(address lzEndpoint_, kToken0 token0_) kOFT(lzEndpoint_, token0_) { }
}
