// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

/// @title Multicall - Aggregate results from multiple read-only function calls

interface IERC20 {
    function balanceOf(address user) external view returns (uint256);
}

contract Multicall {
    address public metis = 0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000;
    struct Call {
        address target;
        bytes callData;
    }
    function aggregate(Call[] memory calls) public returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success);
            returnData[i] = ret;
        }
    }
    // Helper functions
    function getMetisBalance(address addr) public view returns(uint256 balance) {
        balance = IERC20(metis).balanceOf(addr);
    }
    function getCurrentBlockTimestamp() public view returns (uint256 timestamp) {
        timestamp = block.timestamp;
    }
    function isContract(address account) public view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
}