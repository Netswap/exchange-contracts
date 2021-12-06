// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface INetswapPair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

pragma solidity =0.6.12;

// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)

library SafeMathNetswap {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}


pragma solidity >=0.5.0;

interface INetswapFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeRate() external view returns (uint);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

pragma solidity >=0.5.0;



library NetswapLibrary {
    using SafeMathNetswap for uint;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'NetswapLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'NetswapLibrary: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'966d65068a6a30f10fd1fa814258637a34e059081d79daa94f3e2b6cec48e810' // init code hash
            ))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = INetswapPair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'NetswapLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'NetswapLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint feeRate) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'NetswapLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'NetswapLibrary: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(1000 - feeRate);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut, uint feeRate) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'NetswapLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'NetswapLibrary: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(1000 - feeRate);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path, uint feeRate) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'NetswapLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, feeRate);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path, uint feeRate) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'NetswapLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, feeRate);
        }
    }
}

pragma solidity >=0.6.0;

// helper methods for interacting with ERC20 tokens and sending Metis that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferMetis(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: METIS_TRANSFER_FAILED');
    }
}

pragma solidity >=0.6.2;

interface INetswapRouter {
    function factory() external pure returns (address);
    function Metis() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityMetis(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountMetis, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityMetis(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountMetis);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityMetisWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountMetis);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactMetisForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactMetis(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForMetis(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapMetisForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external view returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external view returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

pragma solidity >=0.6.2;


interface INetswapRouter02 is INetswapRouter {
    function removeLiquidityMetisSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline
    ) external returns (uint amountMetis);
    function removeLiquidityMetisWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountMetis);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactMetisForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForMetisSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapMining() external pure returns (address);
}


pragma solidity >=0.5.0;

interface IERC20Netswap {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

interface ISwapMining {
    function swap(address account, address input, address output, uint256 amount) external returns (bool);
}

contract Ownable {
    address private _owner;

    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function isOwner(address account) public view returns (bool) {
        return account == _owner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }


    modifier onlyOwner() {
        require(isOwner(msg.sender), "Ownable: caller is not the owner");
        _;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}


pragma solidity =0.6.12;

contract NetswapRouter is INetswapRouter02, Ownable {
    using SafeMathNetswap for uint;

    address public immutable override factory;
    address public immutable override Metis;
    address public override swapMining;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'NetswapRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _Metis) public {
        factory = _factory;
        Metis = _Metis;
    }

    function setSwapMining(address _swapMininng) public onlyOwner {
        swapMining = _swapMininng;
    }

    receive() external payable {}

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (INetswapFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            INetswapFactory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = NetswapLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = NetswapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'NetswapRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = NetswapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'NetswapRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = NetswapLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = INetswapPair(pair).mint(to);
    }
    function addLiquidityMetis(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountMetis, uint liquidity) {
        (amountToken, amountMetis) = _addLiquidity(
            token,
            Metis,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountMetisMin
        );
        address pair = NetswapLibrary.pairFor(factory, token, Metis);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        // safe transfer Metis from router to pair
        TransferHelper.safeTransfer(Metis, pair, amountMetis);
        liquidity = INetswapPair(pair).mint(to);
        // refund dust metis, if any
        if (msg.value > amountMetis) TransferHelper.safeTransferMetis(msg.sender, msg.value - amountMetis);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = NetswapLibrary.pairFor(factory, tokenA, tokenB);
        INetswapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = INetswapPair(pair).burn(to);
        (address token0,) = NetswapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'NetswapRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'NetswapRouter: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityMetis(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountMetis) {
        (amountToken, amountMetis) = removeLiquidity(
            token,
            Metis,
            liquidity,
            amountTokenMin,
            amountMetisMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        TransferHelper.safeTransferMetis(to, amountMetis);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = NetswapLibrary.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
        INetswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityMetisWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountMetis) {
        address pair = NetswapLibrary.pairFor(factory, token, Metis);
        uint value = approveMax ? uint(-1) : liquidity;
        INetswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountMetis) = removeLiquidityMetis(token, liquidity, amountTokenMin, amountMetisMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityMetisSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountMetis) {
        (, amountMetis) = removeLiquidity(
            token,
            Metis,
            liquidity,
            amountTokenMin,
            amountMetisMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20Netswap(token).balanceOf(address(this)));
        TransferHelper.safeTransferMetis(to, amountMetis);
    }
    function removeLiquidityMetisWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountMetisMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountMetis) {
        address pair = NetswapLibrary.pairFor(factory, token, Metis);
        uint value = approveMax ? uint(-1) : liquidity;
        INetswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountMetis = removeLiquidityMetisSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountMetisMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = NetswapLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            if (swapMining != address(0)) {
                ISwapMining(swapMining).swap(msg.sender, input, output, amountOut);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? NetswapLibrary.pairFor(factory, output, path[i + 2]) : _to;
            INetswapPair(NetswapLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = NetswapLibrary.getAmountsOut(factory, amountIn, path, INetswapFactory(factory).feeRate());
        require(amounts[amounts.length - 1] >= amountOutMin, 'NetswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, NetswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = NetswapLibrary.getAmountsIn(factory, amountOut, path, INetswapFactory(factory).feeRate());
        require(amounts[0] <= amountInMax, 'NetswapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, NetswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    function swapExactMetisForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == Metis, 'NetswapRouter: INVALID_PATH');
        amounts = NetswapLibrary.getAmountsOut(factory, msg.value, path, INetswapFactory(factory).feeRate());
        require(amounts[amounts.length - 1] >= amountOutMin, 'NetswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        // safe transfer metis from router to pair
        TransferHelper.safeTransfer(Metis, NetswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }
    function swapTokensForExactMetis(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == Metis, 'NetswapRouter: INVALID_PATH');
        amounts = NetswapLibrary.getAmountsIn(factory, amountOut, path, INetswapFactory(factory).feeRate());
        require(amounts[0] <= amountInMax, 'NetswapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, NetswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        TransferHelper.safeTransferMetis(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForMetis(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == Metis, 'NetswapRouter: INVALID_PATH');
        amounts = NetswapLibrary.getAmountsOut(factory, amountIn, path, INetswapFactory(factory).feeRate());
        require(amounts[amounts.length - 1] >= amountOutMin, 'NetswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, NetswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        TransferHelper.safeTransferMetis(to, amounts[amounts.length - 1]);
    }
    function swapMetisForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == Metis, 'NetswapRouter: INVALID_PATH');
        amounts = NetswapLibrary.getAmountsIn(factory, amountOut, path, INetswapFactory(factory).feeRate());
        require(amounts[0] <= msg.value, 'NetswapRouter: EXCESSIVE_INPUT_AMOUNT');
        // safe transfer metis from router to pair
        TransferHelper.safeTransfer(Metis, NetswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
        // refund dust metis, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferMetis(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = NetswapLibrary.sortTokens(input, output);
            INetswapPair pair = INetswapPair(NetswapLibrary.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20Netswap(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = NetswapLibrary.getAmountOut(amountInput, reserveInput, reserveOutput, INetswapFactory(factory).feeRate());
            }
            if (swapMining != address(0)) {
                ISwapMining(swapMining).swap(msg.sender, input, output, amountOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? NetswapLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, NetswapLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20Netswap(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20Netswap(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'NetswapRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactMetisForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == Metis, 'NetswapRouter: INVALID_PATH');
        uint amountIn = msg.value;
        // safe transfer metis from router to pair
        TransferHelper.safeTransfer(Metis, NetswapLibrary.pairFor(factory, path[0], path[1]), amountIn);
        uint balanceBefore = IERC20Netswap(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20Netswap(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'NetswapRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForMetisSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == Metis, 'NetswapRouter: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, NetswapLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20Netswap(Metis).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'NetswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferMetis(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return NetswapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        view
        virtual
        override
        returns (uint amountOut)
    {
        return NetswapLibrary.getAmountOut(amountIn, reserveIn, reserveOut, INetswapFactory(factory).feeRate());
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        view
        virtual
        override
        returns (uint amountIn)
    {
        return NetswapLibrary.getAmountIn(amountOut, reserveIn, reserveOut, INetswapFactory(factory).feeRate());
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return NetswapLibrary.getAmountsOut(factory, amountIn, path, INetswapFactory(factory).feeRate());
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return NetswapLibrary.getAmountsIn(factory, amountOut, path, INetswapFactory(factory).feeRate());
    }
}