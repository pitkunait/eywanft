pragma solidity 0.8.0;

interface IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}

interface ISynthesis {
        function getRepresentation(address _rtoken)
        external
        view
        returns (address);
}

interface IPancakePair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function factory() external view returns (address);
}

contract FrontHelper {
    
    struct TokenInfo {
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        uint256 balance;
    }

    struct LpInfo {
        address lp;
        address token0;
        address token1;
    }

    struct PoolInfo {
        address token0;
        bool token0Synth;
        address token1;
        bool token1Synth;
        uint112 reserve0;
        uint112 reserve1;
    }
    
    struct PoolsInfo {
        TokenInfo token0;
        TokenInfo token1;
        TokenInfo pair;
        PoolInfo pool;
    }
    
    struct Call {
        address target;
        bytes callData;
    }


    function aggregate(Call[] memory calls)
        public
        returns (uint256 blockNumber, bytes[] memory returnData)
    {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(
                calls[i].callData
            );
            require(success);
            returnData[i] = ret;
        }
    }


    function balances(address target, address[] calldata tokens)
        external
        view
        returns (uint256[] memory)
    {
        uint256 numberOfTokens = tokens.length;
        uint256[] memory balances = new uint256[](numberOfTokens);

        for (uint256 i = 0; i < numberOfTokens; i++) {
            balances[i] = IERC20(tokens[i]).balanceOf(target);
        }

        return balances;
    }


    function tokenInfo(address target, IERC20 token)
        public
        view
        returns (TokenInfo memory)
    {
        return
            TokenInfo({
                name: token.name(),
                symbol: token.symbol(),
                decimals: token.decimals(),
                totalSupply: token.totalSupply(),
                balance: token.balanceOf(target)
            });
    }


    function tokensInfo(address target, address[] calldata tokens)
        external
        view
        returns (TokenInfo[] memory)
    {
        uint256 numberOfTokens = tokens.length;
        TokenInfo[] memory tokensInfo = new TokenInfo[](numberOfTokens);

        for (uint256 i = 0; i < numberOfTokens; i++) {
            tokensInfo[i] = tokenInfo(target, IERC20(tokens[i]));
        }

        return tokensInfo;
    }


    function lpTokensInfo(address[] calldata _pairs)
        external
        view
        returns (LpInfo[] memory)
    {
        uint256 numberOfPairs = _pairs.length;
        LpInfo[] memory lpInfo = new LpInfo[](numberOfPairs);
        for (uint256 i = 0; i < numberOfPairs; i++) {
            if(isContract(_pairs[i])){
                (bool success,) = _pairs[i].staticcall(abi.encodeWithSelector(IPancakePair.factory.selector));
                if (success) {
                    lpInfo[i] = LpInfo({
                        lp: _pairs[i],
                        token0: IPancakePair(_pairs[i]).token0(),
                        token1: IPancakePair(_pairs[i]).token1()
                    });
                }
            }
        }

        return lpInfo;
    }


    function poolsInfo(address target, address[] memory pairAddress, address synthesis)
        public
        view
        returns (
            PoolsInfo[] memory
        )
    {
        
        PoolsInfo[] memory pools = new PoolsInfo[](pairAddress.length);
            
        for(uint256 i = 0; i < pairAddress.length; i++ ){
            require(isContract(pairAddress[i]), "non contract call");
            (bool success,) = pairAddress[i].staticcall(abi.encodeWithSelector(IPancakePair.factory.selector));
            require(success, "failed to identify the origin of the pool");
            IPancakePair pancakePair = IPancakePair(pairAddress[i]);
    
            (uint112 reserve0, uint112 reserve1, ) = pancakePair.getReserves();
    
            address token0Address = pancakePair.token0();
            address token1Address = pancakePair.token1();
    
            pools[i].pair = tokenInfo(target, IERC20(pairAddress[i]));
            pools[i].token0 = tokenInfo(target, IERC20(token0Address));
            pools[i].token1 = tokenInfo(target, IERC20(token1Address));
            
            bool isSynth0;
            bool isSynth1;
            
            if(ISynthesis(synthesis).getRepresentation(token0Address) != address(0)){
                isSynth0 = true;
            }
            if(ISynthesis(synthesis).getRepresentation(token1Address) != address(0)){
                isSynth1 = true;
            }
            
            pools[i].pool = PoolInfo({
                token0: token0Address,
                token0Synth: isSynth0,
                token1: token1Address,
                token1Synth: isSynth1 ,
                reserve0: reserve0,
                reserve1: reserve1
            });
        }
        
        return  pools;
        
    }


function poolInfo(address target, address pairAddress,  address synthesis)
        public
        view
        returns (
            TokenInfo memory token0,
            TokenInfo memory token1,
            TokenInfo memory pair,
            PoolInfo memory pool
        )
    {
        require(isContract(pairAddress), "non contract call");
        (bool success,) = pairAddress.staticcall(abi.encodeWithSelector(IPancakePair.factory.selector));
        require(success, "failed to identify the origin of the pool");

        IPancakePair pancakePair = IPancakePair(pairAddress);

        (uint112 reserve0, uint112 reserve1, ) = pancakePair.getReserves();

        address token0Address = pancakePair.token0();
        address token1Address = pancakePair.token1();
        
        bool isSynth0;
        bool isSynth1;
        
        if(ISynthesis(synthesis).getRepresentation(token0Address) != address(0)){
            isSynth0 = true;
        }
        if(ISynthesis(synthesis).getRepresentation(token1Address) != address(0)){
            isSynth1 = true;
        }

        pair = tokenInfo(target, IERC20(pairAddress));
        token0 = tokenInfo(target, IERC20(token0Address));
        token1 = tokenInfo(target, IERC20(token1Address));
        pool = PoolInfo({
            token0: token0Address,
            token0Synth: isSynth0,
            token1: token1Address,
            token1Synth: isSynth1,
            reserve0: reserve0,
            reserve1: reserve1
        });
    }
    
    

    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}