// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { kOFTAdapter } from "../src/kOFTAdapter.sol";

contract kOFTAdapterV2 is kOFTAdapter {
    constructor(address token_, address lzEndpoint_) kOFTAdapter(token_, lzEndpoint_) { }

    function isV2() public pure returns (bool) {
        return true;
    }
}
