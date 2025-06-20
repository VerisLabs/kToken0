// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { kOFTAdapter } from "../src/kOFTAdapter.sol";

contract kOFTAdapterV2 is kOFTAdapter {
    constructor(address lzEndpoint_, uint8 decimals_) kOFTAdapter(lzEndpoint_, decimals_) { }

    function isV2() public pure returns (bool) {
        return true;
    }
}
