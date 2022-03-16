// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "./NetswapMath.sol";
import "./BaseOracle.sol";

interface IERC20 {
    function decimals() external view returns(uint256);
}

contract LPOracle {
    using SafeMath for uint;
    using NetswapMath for uint;

    BaseOracle public base;
    address public USDT = 0xbB06DCA3AE6887fAbF931640f67cab3e3a16F4dC;
    address public USDC = 0xEA32A96608495e54156Ae48931A7c20f0dcc1a21;

    constructor(BaseOracle _base) public {
        base = _base;
    }

    /// @dev Return the value of the given input as USDT per unit, multiplied by 2**112.
  /// @param pair The Uniswap pair to check the value.
  function getUSDTPx(address pair) external view returns (uint) {
    address token0 = INetswapPair(pair).token0();
    address token1 = INetswapPair(pair).token1();
    require((token0 != USDT && token1 != USDC) || (token0 != USDC && token1 != USDT));
    uint totalSupply = INetswapPair(pair).totalSupply();
    (uint r0, uint r1, ) = INetswapPair(pair).getReserves();
    uint sqrtK = NetswapMath.sqrt(r0.mul(r1)).fdiv(totalSupply); // in 2**112
    address relative = USDT;
    if (token0 == USDT || token1 == USDC) {
        relative = USDC;
    }
    uint px0 = base.consult(token0, 10 ** (IERC20(token0).decimals()), relative); // in 2**112
    uint px1 = base.consult(token1, 10 ** (IERC20(token1).decimals()), relative); // in 2**112
    // fair token0 amt: sqrtK * sqrt(px1/px0)
    // fair token1 amt: sqrtK * sqrt(px0/px1)
    // fair lp price = 2 * sqrt(px0 * px1)
    // split into 2 sqrts multiplication to prevent uint overflow (note the 2**112)
    return sqrtK.mul(2).mul(NetswapMath.sqrt(px0)).div(2**56).mul(NetswapMath.sqrt(px1)).div(2**56);
  }
}